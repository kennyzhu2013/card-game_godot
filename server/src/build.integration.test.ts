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

describe('M3 build protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('runs place_request through progress and result, rejects occupied positions, and broadcasts world_alteration to shard players', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const builder = await connectClient(app.wsPort);
    const observer = await connectClient(app.wsPort);
    await loginAndEnter(builder, 'dev:build-owner');
    await loginAndEnter(observer, 'dev:build-observer');

    builder.send({
      id: 3,
      op: 'build.place_request',
      payload: {
        workbenchEntityId: 'mist-build-bench-1',
        blueprintId: 'fog_lattice',
        dslSource: 'place fog_lattice',
        position: { x: 6, y: 4 },
        facing: 'east',
        inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
      },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'build-token-1'
    });

    const progress = await waitForMessages(builder.messages, (message) => message.id === 3 && message.op === 'build.progress', 3);
    expect(progress.map((message) => (message.payload as { phase?: string }).phase)).toEqual(['foundation', 'frame', 'finishing']);

    const result = await waitForMessage(builder.messages, (message) => message.id === 3 && message.op === 'build.result');
    expect(result.payload).toMatchObject({
      ok: true,
      requestId: expect.stringMatching(/^build-/),
      structureEntityId: expect.stringMatching(/^build-structure-/),
      deltas: expect.any(Array)
    });

    const structureEntityId = (result.payload as { structureEntityId: string }).structureEntityId;
    const builderAlteration = await waitForMessage(builder.messages, (message) => message.op === 'build.world_alteration');
    const observerAlteration = await waitForMessage(observer.messages, (message) => message.op === 'build.world_alteration');
    for (const alteration of [builderAlteration, observerAlteration]) {
      expect(alteration.payload).toMatchObject({
        structureEntityId,
        mapId: 'mist-harbor-test',
        position: { x: 6, y: 4 },
        visualId: 'fog_lattice',
        ownerPlayerId: 'player-build-owner'
      });
    }

    builder.send({
      id: 4,
      op: 'build.place_request',
      payload: {
        workbenchEntityId: 'mist-build-bench-1',
        blueprintId: 'fog_lattice',
        position: { x: 6, y: 4 },
        facing: 'east',
        inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
      },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'build-token-2'
    });

    const occupied = await waitForMessage(builder.messages, (message) => message.id === 4 && message.op === 'build.result');
    expect(occupied.payload).toMatchObject({
      ok: false,
      code: 'POSITION_BLOCKED',
      refunded: [{ itemId: 'moonlight_grass', amount: 1 }]
    });

    builder.close();
    observer.close();
  });
});

async function loginAndEnter(client: TestClient, token: string): Promise<void> {
  client.send({ id: 1, op: 'auth.login', payload: { token }, ts: 1, protocolVersion: 1 });
  client.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 });
  await waitForMessage(client.messages, (message) => message.op === 'world.entered');
}

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

async function waitForMessage(messages: Envelope[], predicate: (message: Envelope) => boolean, timeoutMs = 1500): Promise<Envelope> {
  return waitFor(() => messages.find(predicate), 'matching envelope', timeoutMs);
}

async function waitForMessages(messages: Envelope[], predicate: (message: Envelope) => boolean, count: number, timeoutMs = 1500): Promise<Envelope[]> {
  return waitFor(() => {
    const matches = messages.filter(predicate);
    return matches.length >= count ? matches.slice(0, count) : undefined;
  }, `${count} matching envelopes`, timeoutMs);
}

async function waitFor<T>(probe: () => T | undefined | false, label: string, timeoutMs: number): Promise<T> {
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
