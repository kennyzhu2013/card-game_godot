import { afterEach, describe, expect, it } from 'vitest';
import WebSocket from 'ws';
import { createM3App, type M3App } from './app.js';
import type { Envelope } from './core/envelope.js';

interface TestClient {
  ws: WebSocket;
  messages: Envelope[];
  send(envelope: Envelope): void;
  close(): void;
}

describe('M3 multiplayer integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('syncs two clients through movement, deltas, and combat lock lifecycle', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const clientA = await connectClient(app.wsPort);
    const clientB = await connectClient(app.wsPort);

    clientA.send({ id: 1, op: 'auth.login', payload: { token: 'dev:a' }, ts: 1 });
    clientA.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 });
    clientB.send({ id: 1, op: 'auth.login', payload: { token: 'dev:b' }, ts: 1 });
    clientB.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 });
    await waitForOp(clientA.messages, 'world.entered');
    await waitForOp(clientB.messages, 'world.entered');

    const startedAt = Date.now() - 1000;
    clientA.send({
      id: 3,
      op: 'world.move',
      payload: { playerId: 'player-a', seq: 1, from: { x: 2, y: 2 }, to: { x: 3, y: 2 }, startedAt },
      ts: 3
    });
    await waitForSnapshotWithPlayer(clientB.messages, 'player-a', { x: 3, y: 2 });

    clientA.send({ id: 4, op: 'world.interact', payload: { entityId: 'tree-1', action: 'chop' }, ts: 4 });
    await waitForDelta(clientB.messages, 'tree-1', 'resource_depleted');

    const created = await adminFetch(app.adminPort, '/admin/shards/m3-dev/combat-locks/test', {
      method: 'POST',
      body: JSON.stringify({ center: { x: 3, y: 2 }, radius: 0 })
    });
    expect(created.status).toBe(200);
    const createdBody = await created.json() as { lock: { combatLockId: string } };
    await waitForOp(clientA.messages, 'combat.lock');

    clientA.send({
      id: 5,
      op: 'world.move',
      payload: { playerId: 'player-a', seq: 2, from: { x: 3, y: 2 }, to: { x: 4, y: 2 }, startedAt: Date.now() - 1000 },
      ts: 5
    });
    await waitForCorrection(clientA.messages, 'locked');

    clientB.send({
      id: 3,
      op: 'world.move',
      payload: { playerId: 'player-b', seq: 1, from: { x: 2, y: 2 }, to: { x: 2, y: 3 }, startedAt: Date.now() - 1000 },
      ts: 3
    });
    await waitForSnapshotSelf(clientB.messages, { x: 2, y: 3 });

    const closed = await adminFetch(app.adminPort, `/admin/combat-locks/${createdBody.lock.combatLockId}/close`, {
      method: 'POST',
      body: JSON.stringify({ result: 'victory' })
    });
    expect(closed.status).toBe(200);
    await waitForOp(clientA.messages, 'combat.unlock');

    clientA.close();
    clientB.close();
  });

  it('runs fog ooze prelude into combat lock and victory removal', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);

    client.send({ id: 1, op: 'auth.login', payload: { token: 'dev:ooze' }, ts: 1 });
    client.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 });
    await waitForOp(client.messages, 'world.entered');

    client.send({
      id: 3,
      op: 'world.move',
      payload: {
        playerId: 'player-ooze',
        seq: 1,
        from: { x: 2, y: 2 },
        to: { x: 10, y: 8 },
        startedAt: Date.now() - 10_000
      },
      ts: 3
    });
    await waitForSnapshotSelf(client.messages, { x: 10, y: 8 });

    const prelude = await waitForOp(client.messages, 'monster.combat_prelude', 3000);
    expect(prelude).toMatchObject({
      op: 'monster.combat_prelude',
      payload: {
        shardId: 'm3-dev',
        monsterId: 'wolf-1',
        monsterEntityIds: ['wolf-1'],
        leadTimeMs: 1500,
        escapeWindowMs: 1500
      }
    });

    const lock = await waitForOp(client.messages, 'combat.lock', 3000);
    const lockPayload = lock.payload as { lock: { combatLockId: string; participantPlayerIds: string[]; hostileEntityIds: string[] } };
    expect(lockPayload.lock).toMatchObject({
      participantPlayerIds: ['player-ooze'],
      hostileEntityIds: ['wolf-1']
    });

    const closed = await adminFetch(app.adminPort, `/admin/combat-locks/${lockPayload.lock.combatLockId}/close`, {
      method: 'POST',
      body: JSON.stringify({ result: 'victory' })
    });
    expect(closed.status).toBe(200);
    await waitForOp(client.messages, 'combat.unlock');
    await waitForDelta(client.messages, 'wolf-1', 'entity_removed');

    client.close();
  });

  it('keeps a same-species transformed player out of fog ooze chase and prelude', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);

    client.send({ id: 1, op: 'auth.login', payload: { token: 'dev:ooze' }, ts: 1 });
    client.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 });
    await waitForOp(client.messages, 'world.entered');

    const transformed = await adminFetch(app.adminPort, '/admin/shards/m3-dev/progression/player-ooze/test', {
      method: 'POST',
      body: JSON.stringify({
        patch: { transformedSpecies: 'ooze', transformationDepth: 1 },
        reason: 'd2-s8-same-species-e2e'
      })
    });
    expect(transformed.status).toBe(200);

    const startIndex = client.messages.length;
    client.send({
      id: 3,
      op: 'world.move',
      payload: {
        playerId: 'player-ooze',
        seq: 1,
        from: { x: 2, y: 2 },
        to: { x: 10, y: 8 },
        startedAt: Date.now() - 10_000
      },
      ts: 3
    });
    await waitForSnapshotSelf(client.messages, { x: 10, y: 8 });
    await waitForEntityState(client.messages, 'wolf-1', (state) => state.monsterState !== 'CHASE');
    await expectNoOpSince(client.messages, 'monster.combat_prelude', startIndex, 800);
    await expectNoOpSince(client.messages, 'combat.lock', startIndex, 800);

    client.close();
  });

  it('replays duplicate clientToken write results without repeating inventory side effects', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);

    client.send({ id: 1, op: 'auth.login', payload: { token: 'dev:d3s9-token' }, ts: 1, protocolVersion: 1 });
    client.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 });
    await waitForOp(client.messages, 'world.entered');

    const discard = {
      op: 'inventory.discard',
      payload: { itemId: 'moonlight_grass', amount: 1 },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'd3-s9-discard-once'
    };
    client.send({ id: 3, ...discard });
    const firstDelta = await waitForOp(client.messages, 'inventory.delta');
    client.send({ id: 4, ...discard, ts: 4 });
    const deltas = await waitForOpCount(client.messages, 'inventory.delta', 2);
    const replayedDelta = deltas[1];

    expect(firstDelta.id).toBe(3);
    expect(replayedDelta.id).toBe(3);
    expect(replayedDelta.payload).toEqual(firstDelta.payload);

    client.send({ id: 5, op: 'inventory.fetch', payload: {}, ts: 5, protocolVersion: 1 });
    const snapshot = await waitForEnvelope(client.messages, 'inventory.snapshot', 5);
    expect(inventoryAmount(snapshot, 'moonlight_grass')).toBe(2);

    client.close();
  });

  it('restores protocol fetch/list state after reconnect for the same player', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const first = await connectClient(app.wsPort);

    first.send({ id: 1, op: 'auth.login', payload: { token: 'dev:d3s9-reconnect' }, ts: 1, protocolVersion: 1 });
    first.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 });
    await waitForOp(first.messages, 'world.entered');
    first.send({ id: 3, op: 'inventory.discard', payload: { itemId: 'moonlight_grass', amount: 1 }, ts: 3, protocolVersion: 1, clientToken: 'd3-s9-reconnect-discard' });
    first.send({ id: 4, op: 'equipment.equip', payload: { slot: 'weapon', itemId: 'flame_sword' }, ts: 4, protocolVersion: 1, clientToken: 'd3-s9-reconnect-equip' });
    first.send({ id: 5, op: 'quest.accept', payload: { questId: 'mist-harbor-field-aid' }, ts: 5, protocolVersion: 1, clientToken: 'd3-s9-reconnect-quest' });
    first.send({
      id: 6,
      op: 'pathway.advance_request',
      payload: { pathwayId: 'tide_priestess', targetSequence: 8, potionItemId: 'moonlight_grass' },
      ts: 6,
      protocolVersion: 1,
      clientToken: 'd3-s9-reconnect-pathway'
    });
    first.send({ id: 7, op: 'skill.learn', payload: { skillId: 'mist-step', pathwaySource: 'tide_priestess' }, ts: 7, protocolVersion: 1, clientToken: 'd3-s9-reconnect-skill' });
    await waitForOps(first.messages, ['inventory.delta', 'equipment.snapshot', 'quest.delta', 'pathway.delta', 'skill.snapshot']);
    first.close();

    const second = await connectClient(app.wsPort);
    second.send({ id: 1, op: 'auth.login', payload: { token: 'dev:d3s9-reconnect' }, ts: 11, protocolVersion: 1 });
    second.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 12, protocolVersion: 1 });
    await waitForOp(second.messages, 'world.entered');
    second.send({ id: 3, op: 'inventory.fetch', payload: {}, ts: 13, protocolVersion: 1 });
    second.send({ id: 4, op: 'equipment.list', payload: {}, ts: 14, protocolVersion: 1 });
    second.send({ id: 5, op: 'quest.list', payload: {}, ts: 15, protocolVersion: 1 });
    second.send({ id: 6, op: 'pathway.list', payload: {}, ts: 16, protocolVersion: 1 });
    second.send({ id: 7, op: 'skill.equip_loadout', payload: { loadoutId: 'field', skills: ['mist-step'] }, ts: 17, protocolVersion: 1, clientToken: 'd3-s9-reconnect-loadout' });

    const inventory = await waitForEnvelope(second.messages, 'inventory.snapshot', 3);
    const equipment = await waitForEnvelope(second.messages, 'equipment.snapshot', 4);
    const quest = await waitForEnvelope(second.messages, 'quest.snapshot', 5);
    const pathway = await waitForEnvelope(second.messages, 'pathway.snapshot', 6);
    const skill = await waitForEnvelope(second.messages, 'skill.snapshot', 7);

    expect(inventoryAmount(inventory, 'moonlight_grass')).toBe(2);
    expect((equipment.payload as { equipped: { weapon?: string } }).equipped.weapon).toBe('flame_sword');
    expect(questStatus(quest, 'mist-harbor-field-aid')).toBe('active');
    expect(pathwaySequence(pathway, 'tide_priestess')).toBe(8);
    expect((skill.payload as { learned: string[]; activeLoadoutId: string }).learned).toContain('mist-step');
    expect((skill.payload as { activeLoadoutId: string }).activeLoadoutId).toBe('field');

    second.close();
  });
});

async function connectClient(port: number): Promise<TestClient> {
  const ws = new WebSocket(`ws://127.0.0.1:${port}`);
  const messages: Envelope[] = [];
  ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));
  await new Promise<void>((resolve, reject) => {
    ws.once('open', () => resolve());
    ws.once('error', reject);
  });
  return {
    ws,
    messages,
    send(envelope: Envelope): void {
      ws.send(JSON.stringify(envelope));
    },
    close(): void {
      ws.close();
    }
  };
}

async function waitForOp(messages: Envelope[], op: string, timeoutMs?: number): Promise<Envelope> {
  return waitFor(() => messages.find((message) => message.op === op), `op ${op}`, timeoutMs);
}

async function waitForOps(messages: Envelope[], ops: string[], timeoutMs?: number): Promise<void> {
  for (const op of ops) {
    await waitForOp(messages, op, timeoutMs);
  }
}

async function waitForOpCount(messages: Envelope[], op: string, count: number, timeoutMs?: number): Promise<Envelope[]> {
  return waitFor(() => {
    const matches = messages.filter((message) => message.op === op);
    return matches.length >= count ? matches : undefined;
  }, `${count} ${op} messages`, timeoutMs);
}

async function waitForEnvelope(messages: Envelope[], op: string, id: number, timeoutMs?: number): Promise<Envelope> {
  return waitFor(() => messages.find((message) => message.op === op && message.id === id), `${op}#${id}`, timeoutMs);
}

async function waitForSnapshotWithPlayer(messages: Envelope[], playerId: string, position: { x: number; y: number }): Promise<void> {
  await waitFor(() => messages.some((message) => {
    if (message.op !== 'world.snapshot') {
      return false;
    }
    const payload = message.payload as { players?: Array<{ playerId: string; position: { x: number; y: number } }> };
    return payload.players?.some((player) => player.playerId === playerId && player.position.x === position.x && player.position.y === position.y);
  }), `snapshot containing ${playerId}`);
}

async function waitForSnapshotSelf(messages: Envelope[], position: { x: number; y: number }): Promise<void> {
  await waitFor(() => messages.some((message) => {
    if (message.op !== 'world.snapshot') {
      return false;
    }
    const payload = message.payload as { self?: { position: { x: number; y: number } } };
    return payload.self?.position.x === position.x && payload.self.position.y === position.y;
  }), `self snapshot at ${position.x},${position.y}`);
}

async function waitForDelta(messages: Envelope[], targetEntityId: string, type: string): Promise<void> {
  await waitFor(() => messages.some((message) => {
    if (message.op !== 'world.delta') {
      return false;
    }
    const payload = message.payload as { delta?: { targetEntityId: string; type: string } };
    return payload.delta?.targetEntityId === targetEntityId && payload.delta.type === type;
  }), `delta ${type}:${targetEntityId}`);
}

async function waitForEntityState(messages: Envelope[], entityId: string, predicate: (state: Record<string, unknown>) => boolean): Promise<void> {
  await waitFor(() => messages.some((message) => {
    if (message.op !== 'world.snapshot') {
      return false;
    }
    const payload = message.payload as { entities?: Array<{ entityId: string; state: Record<string, unknown> }> };
    const entity = payload.entities?.find((candidate) => candidate.entityId === entityId);
    return entity ? predicate(entity.state) : false;
  }), `entity state ${entityId}`);
}

async function expectNoOpSince(messages: Envelope[], op: string, startIndex: number, timeoutMs: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, timeoutMs));
  expect(messages.slice(startIndex).some((message) => message.op === op)).toBe(false);
}

async function waitForCorrection(messages: Envelope[], reason: string): Promise<void> {
  await waitFor(() => messages.some((message) => {
    if (message.op !== 'world.correction') {
      return false;
    }
    const payload = message.payload as { reason?: string };
    return payload.reason === reason;
  }), `correction ${reason}`);
}

async function waitFor<T>(probe: () => T | undefined | false, label: string, timeoutMs = 1500): Promise<T> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const result = probe();
    if (result) {
      return result;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for ${label}`);
}

function adminFetch(port: number, path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`http://127.0.0.1:${port}${path}`, {
    ...init,
    headers: {
      Authorization: 'Bearer test-admin-token',
      'Content-Type': 'application/json',
      ...init.headers
    }
  });
}

function inventoryAmount(snapshot: Envelope, itemId: string): number {
  const payload = snapshot.payload as { items?: Array<{ itemId: string; amount: number }> };
  return payload.items?.find((item) => item.itemId === itemId)?.amount ?? 0;
}

function questStatus(snapshot: Envelope, questId: string): string {
  const payload = snapshot.payload as { quests?: Array<{ questId: string; status: string }> };
  return payload.quests?.find((quest) => quest.questId === questId)?.status ?? '';
}

function pathwaySequence(snapshot: Envelope, pathwayId: string): number {
  const payload = snapshot.payload as { sequences?: Array<{ pathwayId: string; sequence: number }> };
  return payload.sequences?.find((pathway) => pathway.pathwayId === pathwayId)?.sequence ?? 0;
}
