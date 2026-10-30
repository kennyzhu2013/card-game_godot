import { afterEach, describe, expect, it } from 'vitest';
import WebSocket from 'ws';
import { createM3App, type M3App } from '../app.js';
import type { Envelope } from '../core/envelope.js';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import type { Storage } from '../storage/storage.js';
import type { ContentExtension, WorldEntity, WorldTemplate } from '../world/types.js';

describe('M3 WebSocket server', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('authenticates and enters one shard while preserving message order', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1 }));
    ws.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 }));

    await waitForOps(messages, ['auth.result', 'world.entered']);

    expect(messages).toEqual(expect.arrayContaining([
      expect.objectContaining({
        id: 1,
        op: 'auth.result',
        payload: expect.objectContaining({ playerId: 'player-one', sessionId: expect.any(String) })
      }),
      expect.objectContaining({
        id: 2,
        op: 'world.entered',
        payload: expect.objectContaining({
          shardId: 'm3-dev',
          mapId: 'mist-harbor-test',
          templateHash: expect.any(String),
          defaultAoiZoneId: expect.any(String),
          projectionContract: expect.objectContaining({
            coordinateSpace: 'm3-grid-to-godot-world',
            cellSize: 48
          }),
          meta: expect.objectContaining({
            mapId: 'mist-harbor-test'
          })
        })
      })
    ]));
    ws.close();
  });

  it('returns structured errors for malformed messages without closing the socket', async () => {
    app = await createM3App({ port: 0, adminPort: 0 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send('not-json');
    await waitForOps(messages, ['world.error']);

    expect(ws.readyState).toBe(WebSocket.OPEN);
    expect(messages[0]).toMatchObject({
      op: 'world.error',
      payload: { code: 'MALFORMED_MESSAGE', retryable: false }
    });
    ws.close();
  });

  it('negotiates protocol version on auth.login and rejects incompatible future versions', async () => {
    app = await createM3App({ port: 0, adminPort: 0 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({
      id: 1,
      op: 'auth.login',
      payload: { token: 'dev:one', clientProtocolVersion: 1 },
      ts: 1,
      protocolVersion: 1
    }));
    const auth = await waitForOp(messages, 'auth.result');
    expect(auth).toMatchObject({
      protocolVersion: 1,
      payload: expect.objectContaining({
        playerId: 'player-one',
        serverProtocolVersion: 1,
        featureFlags: expect.arrayContaining(['system.ping', 'auth.refresh'])
      })
    });

    ws.send(JSON.stringify({
      id: 2,
      op: 'auth.login',
      payload: { token: 'dev:one', clientProtocolVersion: 2 },
      ts: 2,
      protocolVersion: 2
    }));
    const mismatch = await waitForEnvelopeId(messages, 2);
    expect(mismatch).toMatchObject({
      id: 2,
      op: 'auth.result',
      protocolVersion: 1,
      payload: { ok: false, code: 'PROTOCOL_VERSION_MISMATCH' }
    });
    ws.close();
  });

  it('responds to system.ping with system.pong and updates heartbeat state', async () => {
    app = await createM3App({ port: 0, adminPort: 0 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    await waitForOp(messages, 'auth.result');

    ws.send(JSON.stringify({ id: 2, op: 'system.ping', payload: { tick: 42 }, ts: 2, protocolVersion: 1 }));
    const pong = await waitForOp(messages, 'system.pong');

    expect(pong).toMatchObject({
      id: 2,
      op: 'system.pong',
      protocolVersion: 1,
      payload: {
        tick: 42,
        serverTime: expect.any(Number),
        rttMs: expect.any(Number)
      }
    });
    expect(Number((pong.payload as { rttMs: number }).rttMs)).toBeGreaterThanOrEqual(0);
    ws.close();
  });

  it('uses per-op rate limit buckets and reports system.ratelimit without disconnecting', async () => {
    app = await createM3App({ port: 0, adminPort: 0 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    await waitForOp(messages, 'auth.result');

    for (let id = 2; id <= 14; id += 1) {
      ws.send(JSON.stringify({ id, op: 'system.ping', payload: { tick: id }, ts: id, protocolVersion: 1 }));
    }
    const limited = await waitForOp(messages, 'system.ratelimit');
    expect(limited).toMatchObject({
      op: 'system.ratelimit',
      payload: { op: 'system.ping', bucketRemaining: 0, resetMs: expect.any(Number) }
    });
    expect(ws.readyState).toBe(WebSocket.OPEN);

    ws.send(JSON.stringify({ id: 30, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 30, protocolVersion: 1 }));
    await waitForOp(messages, 'world.entered');
    ws.close();
  });

  it('uses progression-specific rate limit codes for subscribe floods', async () => {
    app = await createM3App({ port: 0, adminPort: 0 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(messages, ['auth.result', 'world.entered']);

    ws.send(JSON.stringify({ id: 3, op: 'progression.subscribe', payload: { shardId: 'm3-dev' }, ts: 3, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 4, op: 'progression.subscribe', payload: { shardId: 'm3-dev' }, ts: 4, protocolVersion: 1 }));

    const limited = await waitForOp(messages, 'system.ratelimit');
    expect(limited).toMatchObject({
      op: 'system.ratelimit',
      payload: {
        op: 'progression.subscribe',
        code: 'PROGRESSION_RATE_LIMITED',
        bucketRemaining: 0,
        resetMs: expect.any(Number)
      }
    });
    expect(ws.readyState).toBe(WebSocket.OPEN);
    ws.close();
  });

  it('returns an authoritative progression self_state when subscribed in-world', async () => {
    app = await createM3App({ port: 0, adminPort: 0 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(messages, ['auth.result', 'world.entered']);

    ws.send(JSON.stringify({ id: 3, op: 'progression.subscribe', payload: { shardId: 'm3-dev' }, ts: 3, protocolVersion: 1 }));
    const selfState = await waitForEnvelopeId(messages, 3);

    expect(selfState).toMatchObject({
      id: 3,
      op: 'progression.self_state',
      protocolVersion: 1,
      payload: {
        state: {
          playerId: 'player-one',
          level: 1,
          exp: 0,
          sequence: 9,
          sanity: 0,
          protocolVersion: 'v3',
          contentHash: expect.any(String)
        }
      }
    });
    ws.close();
  });

  it('pushes AOI progression changed and left messages for subscribed players only', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, aoiRadiusCells: 3 });
    const first = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const second = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const firstMessages: Envelope[] = [];
    const secondMessages: Envelope[] = [];
    first.on('message', (data) => firstMessages.push(JSON.parse(data.toString()) as Envelope));
    second.on('message', (data) => secondMessages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(first);
    await waitForOpen(second);
    first.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    first.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    second.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:two' }, ts: 1, protocolVersion: 1 }));
    second.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(firstMessages, ['auth.result', 'world.entered']);
    await waitForOps(secondMessages, ['auth.result', 'world.entered']);

    first.send(JSON.stringify({ id: 3, op: 'progression.subscribe', payload: { shardId: 'm3-dev' }, ts: 3, protocolVersion: 1 }));
    await waitForEnvelopeId(firstMessages, 3);
    await waitForProgressionAoiChanged(firstMessages, 'player-two');
    expect(secondMessages.some((message) => message.op === 'progression.aoi_visible_changed')).toBe(false);

    second.send(JSON.stringify({
      id: 4,
      op: 'world.move',
      payload: {
        playerId: 'player-two',
        seq: 1,
        from: { x: 2, y: 2 },
        to: { x: 10, y: 10 },
        startedAt: Date.now() - 7000
      },
      ts: 4,
      protocolVersion: 1
    }));

    await waitForProgressionAoiLeft(firstMessages, 'player-two');
    first.close();
    second.close();
  });

  it('persists progression through shard leave when the socket closes', async () => {
    app = await createM3App({ port: 0, adminPort: 0 });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(messages, ['auth.result', 'world.entered']);
    ws.close();
    await waitForClose(ws);

    const second = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const secondMessages: Envelope[] = [];
    second.on('message', (data) => secondMessages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(second);
    second.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    second.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(secondMessages, ['auth.result', 'world.entered']);
    second.send(JSON.stringify({ id: 3, op: 'progression.subscribe', payload: { shardId: 'm3-dev' }, ts: 3, protocolVersion: 1 }));

    expect(await waitForEnvelopeId(secondMessages, 3)).toMatchObject({
      op: 'progression.self_state',
      payload: {
        state: {
          playerId: 'player-one',
          protocolVersion: 'v3',
          contentHash: expect.any(String)
        }
      }
    });
    second.close();
  });

  it('broadcasts world delta and combat lock for Shoreline combat check interact', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, storage: createShorelineStorage() });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:webqa' }, ts: 1 }));
    ws.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 }));
    await waitForOps(messages, ['auth.result', 'world.entered']);

    ws.send(JSON.stringify({
      id: 3,
      op: 'world.move',
      payload: {
        playerId: 'player-webqa',
        seq: 1,
        from: { x: 2, y: 2 },
        to: { x: 4, y: 6 },
        startedAt: Date.now() - 3000
      },
      ts: 3
    }));
    await waitForPlayerPosition(messages, 'player-webqa', { x: 4, y: 6 });

    ws.send(JSON.stringify({ id: 4, op: 'world.interact', payload: { entityId: 'test-hostile-1', action: 'scout' }, ts: 4 }));
    await waitForDelta(messages, 'test_small_threat_scouted');
    ws.send(JSON.stringify({ id: 5, op: 'world.interact', payload: { entityId: 'test-hostile-1', action: 'combat_check' }, ts: 5 }));
    await waitForOps(messages, ['combat.lock']);

    expect(messages).toEqual(expect.arrayContaining([
      expect.objectContaining({
        op: 'world.delta',
        payload: expect.objectContaining({
          entity: expect.objectContaining({
            entityId: 'test-hostile-1',
            state: expect.objectContaining({
              status: 'combat_check_locked',
              routePhase: 'combat_check',
              routeAction: 'test_small_threat_combat_check',
              combatCheckBy: 'player-webqa'
            })
          })
        })
      }),
      expect.objectContaining({
        op: 'combat.lock',
        payload: {
          lock: expect.objectContaining({
            participantPlayerIds: ['player-webqa'],
            hostileEntityIds: ['test-hostile-1']
          })
        }
      })
    ]));
    ws.close();
  });

  it('broadcasts Shoreline aftermath delta when admin closes combat check lock with victory', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token', storage: createShorelineStorage() });
    const ws = new WebSocket(`ws://127.0.0.1:${app.wsPort}`);
    const messages: Envelope[] = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: 'auth.login', payload: { token: 'dev:webqa' }, ts: 1 }));
    ws.send(JSON.stringify({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 }));
    await waitForOps(messages, ['auth.result', 'world.entered']);

    ws.send(JSON.stringify({
      id: 3,
      op: 'world.move',
      payload: {
        playerId: 'player-webqa',
        seq: 1,
        from: { x: 2, y: 2 },
        to: { x: 4, y: 6 },
        startedAt: Date.now() - 3000
      },
      ts: 3
    }));
    await waitForPlayerPosition(messages, 'player-webqa', { x: 4, y: 6 });

    ws.send(JSON.stringify({ id: 4, op: 'world.interact', payload: { entityId: 'test-hostile-1', action: 'scout' }, ts: 4 }));
    await waitForDelta(messages, 'test_small_threat_scouted');
    ws.send(JSON.stringify({ id: 5, op: 'world.interact', payload: { entityId: 'test-hostile-1', action: 'combat_check' }, ts: 5 }));
    const lockMessage = await waitForOp(messages, 'combat.lock');
    const lock = (lockMessage.payload as { lock?: { combatLockId?: string } }).lock;
    expect(lock?.combatLockId).toEqual(expect.any(String));

    const closed = await fetch(`http://127.0.0.1:${app.adminPort}/admin/combat-locks/${lock?.combatLockId}/close`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer test-admin-token',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ result: 'victory' })
    });
    expect(closed.status).toBe(200);
    expect(await closed.json()).toMatchObject({
      result: 'victory',
      delta: {
        targetEntityId: 'test-hostile-1',
        type: 'state_changed',
        patch: {
          state: {
            status: 'pollution_read_ready',
            routePhase: 'pollution_read',
            routeAction: 'test_small_threat_pollution_read_ready',
            combatResult: 'victory'
          }
        }
      }
    });

    await waitForOps(messages, ['combat.unlock']);
    await waitForDelta(messages, 'test_small_threat_pollution_read_ready');
    expect(messages).toEqual(expect.arrayContaining([
      expect.objectContaining({
        op: 'world.delta',
        payload: expect.objectContaining({
          entity: expect.objectContaining({
            entityId: 'test-hostile-1',
            state: expect.objectContaining({
              status: 'pollution_read_ready',
              routePhase: 'pollution_read',
              routeAction: 'test_small_threat_pollution_read_ready',
              combatResult: 'victory'
            })
          })
        })
      })
    ]));
    ws.close();
  });
});

async function waitForOp(messages: Envelope[], op: string, timeoutMs = 1000): Promise<Envelope> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const match = messages.find((message) => message.op === op);
    if (match) {
      return match;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for op: ${op}`);
}

async function waitForEnvelopeId(messages: Envelope[], id: number, timeoutMs = 1000): Promise<Envelope> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const match = messages.find((message) => message.id === id);
    if (match) {
      return match;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for envelope id: ${id}`);
}

function waitForOpen(ws: WebSocket): Promise<void> {
  return new Promise((resolve, reject) => {
    ws.once('open', () => resolve());
    ws.once('error', reject);
  });
}

function waitForClose(ws: WebSocket): Promise<void> {
  return new Promise((resolve, reject) => {
    if (ws.readyState === WebSocket.CLOSED) {
      resolve();
      return;
    }
    ws.once('close', () => resolve());
    ws.once('error', reject);
  });
}

async function waitForOps(messages: Envelope[], ops: string[], timeoutMs = 1000): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (ops.every((op) => messages.some((message) => message.op === op))) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for ops: ${ops.join(', ')}`);
}

async function waitForPlayerPosition(messages: Envelope[], playerId: string, position: { x: number; y: number }, timeoutMs = 1000): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (messages.some((message) => {
      if (message.op !== 'world.snapshot') {
        return false;
      }
      const payload = message.payload as { self?: { playerId?: string; position?: { x?: number; y?: number } } };
      return payload.self?.playerId === playerId
        && payload.self.position?.x === position.x
        && payload.self.position?.y === position.y;
    })) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for ${playerId} at ${position.x},${position.y}`);
}

async function waitForDelta(messages: Envelope[], routeAction: string, timeoutMs = 1000): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (messages.some((message) => {
      if (message.op !== 'world.delta') {
        return false;
      }
      const payload = message.payload as { delta?: { patch?: { state?: { routeAction?: string } } } };
      return payload.delta?.patch?.state?.routeAction === routeAction;
    })) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for route action delta ${routeAction}`);
}

async function waitForProgressionAoiChanged(messages: Envelope[], playerId: string, timeoutMs = 1000): Promise<Envelope> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const match = messages.find((message) => {
      if (message.op !== 'progression.aoi_visible_changed') {
        return false;
      }
      const payload = message.payload as { playerId?: string; projection?: { playerId?: string } };
      return payload.playerId === playerId && payload.projection?.playerId === playerId;
    });
    if (match) {
      return match;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for progression AOI changed ${playerId}`);
}

async function waitForProgressionAoiLeft(messages: Envelope[], playerId: string, timeoutMs = 1000): Promise<Envelope> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const match = messages.find((message) => {
      if (message.op !== 'progression.aoi_visible_left') {
        return false;
      }
      const payload = message.payload as { playerId?: string };
      return payload.playerId === playerId;
    });
    if (match) {
      return match;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for progression AOI left ${playerId}`);
}

function createShorelineStorage(): Storage {
  const base = createMemoryStorage();
  const extraEntity: WorldEntity = {
    entityId: 'test-hostile-1',
    type: 'npc',
    position: { x: 5, y: 6 },
    state: {
      storyRole: 'test_small_threat',
      encounterRole: 'followup_check',
      hostile: true,
      status: 'waiting'
    },
    version: 1
  };
  const extensions: ContentExtension[] = [
    {
      extensionId: 'test-hostile-scout',
      scope: 'interaction_actions',
      triggers: [{ entityIdPattern: 'test-hostile-1', action: 'scout' }],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'scouted',
            routeAction: 'test_small_threat_scouted',
            scoutedBy: '$actorPlayerId'
          }
        },
        { type: 'emit_delta', params: { type: 'state_changed' } }
      ]
    },
    {
      extensionId: 'test-hostile-combat-check',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'test-hostile-1',
          action: 'combat_check',
          preconditions: { status: 'scouted', routeAction: 'test_small_threat_scouted' }
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'combat_check_locked',
            routePhase: 'combat_check',
            routeAction: 'test_small_threat_combat_check',
            combatCheckBy: '$actorPlayerId'
          }
        },
        { type: 'emit_delta', params: { type: 'state_changed' } },
        {
          type: 'lock_combat',
          params: { combatLockId: 'test_small_threat_followup', radius: 2 }
        }
      ]
    },
    {
      extensionId: 'test-hostile-combat-close',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'test-hostile-1',
          action: 'combat_close',
          preconditions: {
            status: 'combat_check_locked',
            routeAction: 'test_small_threat_combat_check',
            combatResult: 'victory'
          }
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'pollution_read_ready',
            routePhase: 'pollution_read',
            routeAction: 'test_small_threat_pollution_read_ready',
            combatResult: '$combatResult'
          }
        },
        { type: 'emit_delta', params: { type: 'state_changed' } }
      ]
    }
  ];

  return {
    ...base,
    worldTemplates: {
      async list(): Promise<WorldTemplate[]> {
        const templates = await base.worldTemplates.list();
        return templates.map((template) => augmentTemplate(template, extraEntity, extensions));
      },
      async load(mapId: string): Promise<WorldTemplate> {
        const template = await base.worldTemplates.load(mapId);
        return augmentTemplate(template, extraEntity, extensions);
      }
    }
  };
}

function augmentTemplate(template: WorldTemplate, extraEntity: WorldEntity, extensions: ContentExtension[]): WorldTemplate {
  return {
    ...structuredClone(template),
    entities: [...template.entities.map((entity) => structuredClone(entity)), structuredClone(extraEntity)],
    contentExtensions: [
      ...(template.contentExtensions ?? []).map((extension) => structuredClone(extension)),
      ...extensions.map((extension) => structuredClone(extension))
    ]
  };
}
