import { afterEach, describe, expect, it } from 'vitest';
import WebSocket from 'ws';
import { ManualClock } from '../core/time.js';
import { ClientOps, ServerOps } from '../protocol/ops.js';
import { DevAuthService } from './auth.js';
import { PerOpRateLimiter } from './rateLimiter.js';
import { SessionManager } from './sessionManager.js';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import { MapTemplateRegistry } from '../world/mapTemplateRegistry.js';
import { ShardRegistry } from '../world/shardRegistry.js';
import { createM3WebSocketGateway } from './wsServer.js';
import type { Storage } from '../storage/storage.js';
import type { WorldTemplate } from '../world/types.js';
import type { WorldShard } from '../world/worldShard.js';

describe('M3 WebSocket protocol extensions', () => {
  const cleanups: Array<() => Promise<void>> = [];

  afterEach(async () => {
    while (cleanups.length > 0) {
      await cleanups.pop()?.();
    }
  });

  it('lists shards and maps, then transfers a player between shards', async () => {
    const { gateway, wsPort } = await createGatewayHarness({ includeEventMap: false });
    cleanups.push(() => gateway.stop());

    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`);
    const messages: Array<Record<string, unknown>> = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Record<string, unknown>));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: ClientOps.AuthLogin, payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 2, op: ClientOps.WorldEnter, payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(messages, [ServerOps.AuthResult, ServerOps.WorldEntered]);
    const entered = await waitForEnvelopeId(messages, 2);
    expect(entered).toMatchObject({
      op: ServerOps.WorldEntered,
      payload: expect.objectContaining({
        shardId: 'm3-dev',
        mapId: 'mist-harbor-test',
        templateHash: expect.any(String),
        defaultAoiZoneId: expect.any(String),
        projectionContract: expect.objectContaining({
          coordinateSpace: 'm3-grid-to-godot-world',
          origin: expect.objectContaining({ x: expect.any(Number), y: expect.any(Number) }),
          cellSize: 48
        }),
        meta: expect.objectContaining({
          mapId: 'mist-harbor-test',
          templateHash: expect.any(String)
        }),
        regions: expect.any(Array),
        portals: expect.any(Array),
        aoiZones: expect.any(Array)
      })
    });

    ws.send(JSON.stringify({ id: 3, op: ClientOps.WorldListShards, payload: {}, ts: 3, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 4, op: ClientOps.WorldListMaps, payload: {}, ts: 4, protocolVersion: 1 }));

    const shardList = await waitForEnvelopeId(messages, 3);
    const mapList = await waitForEnvelopeId(messages, 4);
    expect(shardList).toMatchObject({
      op: ServerOps.WorldShardList,
      payload: { ok: true, shards: expect.arrayContaining([expect.objectContaining({ shardId: 'm3-dev' }), expect.objectContaining({ shardId: 'm3-eventless' })]) }
    });
    expect(mapList).toMatchObject({
      op: ServerOps.WorldMapList,
      payload: { ok: true, maps: expect.arrayContaining([expect.objectContaining({ mapId: 'mist-harbor-test' })]) }
    });

    ws.send(JSON.stringify({
      id: 5,
      op: ClientOps.WorldTransfer,
      payload: {
        playerId: 'player-one',
        fromShardId: 'm3-dev',
        toShardId: 'm3-eventless',
        toPosition: { x: 6, y: 6 },
        portalId: 'mist-port'
      },
      ts: 5,
      protocolVersion: 1,
      clientToken: 'transfer-token-1'
    }));

    const transfer = await waitForEnvelopeId(messages, 5);
    expect(transfer).toMatchObject({
      op: ServerOps.WorldTransferAck,
      payload: {
        ok: true,
        playerId: 'player-one',
        fromShardId: 'm3-dev',
        toShardId: 'm3-eventless',
        toMapId: 'mist-harbor-test',
        toPosition: { x: 6, y: 6 },
        snapshot: expect.objectContaining({
          shardId: 'm3-eventless',
          templateHash: expect.any(String),
          defaultAoiZoneId: expect.any(String),
          projectionContract: expect.objectContaining({
            coordinateSpace: 'm3-grid-to-godot-world',
            cellSize: 48
          }),
          self: expect.objectContaining({
            playerId: 'player-one',
            position: { x: 6, y: 6 }
          })
        })
      }
    });

    ws.close();
  });

  it('pushes world.aoi_delta for event-mode visibility changes', async () => {
    const { gateway, wsPort, clock } = await createGatewayHarness({ includeEventMap: true });
    cleanups.push(() => gateway.stop());

    const first = new WebSocket(`ws://127.0.0.1:${wsPort}`);
    const second = new WebSocket(`ws://127.0.0.1:${wsPort}`);
    const firstMessages: Array<Record<string, unknown>> = [];
    const secondMessages: Array<Record<string, unknown>> = [];
    first.on('message', (data) => firstMessages.push(JSON.parse(data.toString()) as Record<string, unknown>));
    second.on('message', (data) => secondMessages.push(JSON.parse(data.toString()) as Record<string, unknown>));

    await waitForOpen(first);
    await waitForOpen(second);
    first.send(JSON.stringify({ id: 1, op: ClientOps.AuthLogin, payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    first.send(JSON.stringify({ id: 2, op: ClientOps.WorldEnter, payload: { shardId: 'm3-eventless' }, ts: 2, protocolVersion: 1 }));
    second.send(JSON.stringify({ id: 1, op: ClientOps.AuthLogin, payload: { token: 'dev:two' }, ts: 1, protocolVersion: 1 }));
    second.send(JSON.stringify({ id: 2, op: ClientOps.WorldEnter, payload: { shardId: 'm3-eventless' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(firstMessages, [ServerOps.AuthResult, ServerOps.WorldEntered]);
    await waitForOps(secondMessages, [ServerOps.AuthResult, ServerOps.WorldEntered]);
    await waitForAoiEvent(firstMessages, 'player_enter', 'player-two');

    clock.advance(2000);
    second.send(JSON.stringify({
      id: 3,
      op: ClientOps.WorldMove,
      payload: {
        playerId: 'player-two',
        seq: 1,
        from: { x: 2, y: 2 },
        to: { x: 6, y: 2 },
        startedAt: 1000
      },
      ts: 3,
      protocolVersion: 1
    }));

    const moved = await waitForEnvelopeId(secondMessages, 3);
    expect(moved).toMatchObject({
      op: ServerOps.WorldSnapshot,
      payload: {
        self: expect.objectContaining({
          playerId: 'player-two',
          position: { x: 6, y: 2 }
        })
      }
    });

    const aoiDelta = await waitForAoiEvent(firstMessages, 'player_leave', 'player-two');
    expect(aoiDelta).toMatchObject({
      op: ServerOps.WorldAoiDelta,
      payload: {
        shardId: 'm3-eventless',
        events: expect.arrayContaining([
          expect.objectContaining({
            type: 'player_leave',
            subjectId: 'player-two'
          })
        ])
      }
    });

    first.close();
    second.close();
  });

  it('routes monster.evade through the authoritative shard and returns monster.evade_ack', async () => {
    const { gateway, wsPort, clock, shard } = await createGatewayHarness({ includeEventMap: false });
    cleanups.push(() => gateway.stop());

    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`);
    const messages: Array<Record<string, unknown>> = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Record<string, unknown>));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: ClientOps.AuthLogin, payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 2, op: ClientOps.WorldEnter, payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(messages, [ServerOps.AuthResult, ServerOps.WorldEntered]);

    clock.advance(5000);
    const move = await shard.movePlayer({
      playerId: 'player-one',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 11, y: 8 },
      startedAt: 1000
    });
    expect(move.ok).toBe(true);
    await shard.tickMonsters(clock.now());
    clock.advance(100);
    await shard.tickMonsters(clock.now());
    clock.advance(100);
    await shard.tickMonsters(clock.now());

    ws.send(JSON.stringify({
      id: 3,
      op: ClientOps.MonsterEvade,
      payload: { shardId: 'm3-dev', monsterId: 'wolf-1', evadeKind: 'stealth' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'monster-token-1'
    }));

    const ack = await waitForEnvelopeId(messages, 3);
    expect(ack).toMatchObject({
      id: 3,
      op: ServerOps.MonsterEvadeAck,
      payload: {
        ok: true,
        code: 'EVADED',
        reason: expect.any(String)
      }
    });
    expect(shard.createSnapshotFor('player-one').entities.find((entity) => entity.entityId === 'wolf-1')).toMatchObject({
      state: expect.objectContaining({
        monsterState: 'PATROL',
        pendingPrelude: false
      })
    });

    ws.close();
  });

  it('broadcasts monster aggro changes and combat preludes from snapshot ticks', async () => {
    const { gateway, wsPort, clock, shard } = await createGatewayHarness({ includeEventMap: false });
    cleanups.push(() => gateway.stop());

    const ws = new WebSocket(`ws://127.0.0.1:${wsPort}`);
    const messages: Array<Record<string, unknown>> = [];
    ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Record<string, unknown>));

    await waitForOpen(ws);
    ws.send(JSON.stringify({ id: 1, op: ClientOps.AuthLogin, payload: { token: 'dev:one' }, ts: 1, protocolVersion: 1 }));
    ws.send(JSON.stringify({ id: 2, op: ClientOps.WorldEnter, payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 }));
    await waitForOps(messages, [ServerOps.AuthResult, ServerOps.WorldEntered]);

    clock.advance(5000);
    const move = await shard.movePlayer({
      playerId: 'player-one',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 11, y: 8 },
      startedAt: 1000
    });
    expect(move.ok).toBe(true);

    const aggro = await waitForOp(messages, ServerOps.MonsterAggroChanged, 1500);
    expect(aggro).toMatchObject({
      op: ServerOps.MonsterAggroChanged,
      payload: {
        shardId: 'm3-dev',
        monsterId: 'wolf-1',
        fromState: 'PATROL',
        toState: 'ALERT',
        threat: 35,
        towardsPlayerId: 'player-one',
        tick: expect.any(Number)
      }
    });

    const prelude = await waitForOp(messages, ServerOps.MonsterCombatPrelude, 1500);
    expect(prelude).toMatchObject({
      op: ServerOps.MonsterCombatPrelude,
      payload: {
        shardId: 'm3-dev',
        monsterId: 'wolf-1',
        monsterEntityIds: ['wolf-1'],
        leadTimeMs: 1500,
        escapeWindowMs: 1500
      }
    });

    ws.close();
  });
});

async function createGatewayHarness({ includeEventMap }: { includeEventMap: boolean }): Promise<{
  gateway: Awaited<ReturnType<typeof createM3WebSocketGateway>>;
  wsPort: number;
  clock: ManualClock;
  shard: WorldShard;
}> {
  const clock = new ManualClock(1000);
  const storage = createMemoryStorage();
  const template = await storage.worldTemplates.load('m3-test');
  const templates = new Map<string, WorldTemplate>([[template.mapId, template]]);
  if (includeEventMap) {
    const eventTemplate = createEventTemplate(template);
    templates.set(eventTemplate.mapId, eventTemplate);
  }

  storage.worldTemplates = {
    async list(): Promise<WorldTemplate[]> {
      return [...templates.values()].map((value) => clone(value));
    },
    async load(mapId: string): Promise<WorldTemplate> {
      const found = templates.get(mapId);
      if (!found) {
        throw new Error(`UNKNOWN_WORLD_TEMPLATE:${mapId}`);
      }
      return clone(found);
    }
  };

  const templateRegistry = new MapTemplateRegistry(storage);
  const shardRegistry = new ShardRegistry({
    storage,
    clock,
    templateRegistry,
    defaultsByMap: {
      'm3-test': {
        aoiRadiusCells: 3,
        maxMoveCellsPerSecond: 3,
        combatLockRadiusCells: 3
      },
      'm3-eventless': {
        aoiRadiusCells: 3,
        maxMoveCellsPerSecond: 3,
        combatLockRadiusCells: 3
      }
    }
  });
  await shardRegistry.spawn({ shardId: 'm3-dev', mapId: 'm3-test' });
  await shardRegistry.spawn({ shardId: 'm3-eventless', mapId: includeEventMap ? 'm3-eventless' : 'm3-test' });

  const sessions = new SessionManager(storage, clock);
  const rateLimiter = new PerOpRateLimiter({
    default: { maxMessages: 30, windowMs: 1000 },
    ops: {}
  });

  const gateway = await createM3WebSocketGateway({
    port: 0,
    clock,
    auth: new DevAuthService(),
    storage,
    sessions,
    shard: shardRegistry.get('m3-dev')!,
    shardRegistry,
    templateRegistry,
    rateLimiter,
    snapshotRateHz: 20
  });

  return { gateway, wsPort: gateway.wsPort, clock, shard: shardRegistry.get('m3-dev')! };
}

function createEventTemplate(template: WorldTemplate): WorldTemplate {
  return {
    ...clone(template),
    mapId: 'm3-eventless',
    templateHash: 'm3-eventless-v1',
    meta: {
      ...clone(template.meta),
      mapId: 'm3-eventless',
      templateHash: 'm3-eventless-v1',
      displayName: 'M3 Eventless',
      recommendedAoiZoneId: 'tight',
      contentRevision: 2
    },
    aoiZones: [
      {
        zoneId: 'tight',
        playersRadiusCells: 3,
        entitiesRadiusCells: 3,
        combatLocksRadiusCells: 3,
        deltaMode: 'event'
      }
    ],
    defaultAoiZoneId: 'tight'
  };
}

async function waitForOpen(ws: WebSocket): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    ws.once('open', resolve);
    ws.once('error', reject);
  });
}

async function waitForOps(messages: Array<Record<string, unknown>>, ops: string[], timeoutMs = 1000): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (ops.every((op) => messages.some((message) => message.op === op))) {
      return;
    }
    await delay(10);
  }
  throw new Error(`Timed out waiting for ops: ${ops.join(', ')}`);
}

async function waitForEnvelopeId(messages: Array<Record<string, unknown>>, id: number, timeoutMs = 1000): Promise<Record<string, unknown>> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const match = messages.find((message) => message.id === id);
    if (match) {
      return match;
    }
    await delay(10);
  }
  throw new Error(`Timed out waiting for envelope id: ${id}`);
}

async function waitForOp(messages: Array<Record<string, unknown>>, op: string, timeoutMs = 1000): Promise<Record<string, unknown>> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const match = messages.find((message) => message.op === op);
    if (match) {
      return match;
    }
    await delay(10);
  }
  throw new Error(`Timed out waiting for op: ${op}`);
}

async function waitForAoiEvent(
  messages: Array<Record<string, unknown>>,
  type: string,
  subjectId: string,
  timeoutMs = 1000
): Promise<Record<string, unknown>> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const match = messages.find((message) => {
      if (message.op !== ServerOps.WorldAoiDelta) {
        return false;
      }
      const payload = message.payload as { events?: Array<{ type?: string; subjectId?: string }> };
      return payload.events?.some((event) => event.type === type && event.subjectId === subjectId) ?? false;
    });
    if (match) {
      return match;
    }
    await delay(10);
  }
  const seen = messages
    .filter((message) => message.op === ServerOps.WorldAoiDelta)
    .map((message) => (message.payload as { events?: unknown[] }).events ?? []);
  throw new Error(`Timed out waiting for AOI event ${type}:${subjectId}; seen=${JSON.stringify(seen)}`);
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function clone<T>(value: T): T {
  return structuredClone(value);
}
