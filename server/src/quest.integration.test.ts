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

describe('M3 quest protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('accepts, advances objective progress from a server action, and turns in a quest', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:quest-success');

    client.send({ id: 3, op: 'quest.list', payload: {}, ts: 3, protocolVersion: 1 });
    const snapshot = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'quest.snapshot');
    expect(snapshot.payload).toMatchObject({
      ok: true,
      quests: expect.arrayContaining([
        expect.objectContaining({
          questId: 'mist-harbor-field-aid',
          status: 'available',
          objectives: [expect.objectContaining({ current: 0, required: 1 })]
        })
      ])
    });

    client.send({
      id: 4,
      op: 'quest.accept',
      payload: { questId: 'mist-harbor-field-aid' },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'quest-accept-token-1'
    });
    const accepted = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'quest.delta');
    expect(accepted.payload).toMatchObject({
      ok: true,
      questId: 'mist-harbor-field-aid',
      status: 'active',
      objectives: [expect.objectContaining({ current: 0, required: 1 })]
    });

    client.send({
      id: 5,
      op: 'quest.turn_in',
      payload: { questId: 'mist-harbor-field-aid' },
      ts: 5,
      protocolVersion: 1,
      clientToken: 'quest-turn-in-token-incomplete'
    });
    const incomplete = await waitForMessage(client.messages, (message) => message.id === 5 && message.op === 'world.error');
    expect(incomplete.payload).toMatchObject({ code: 'QUEST_OBJECTIVES_INCOMPLETE', retryable: false });

    client.send({
      id: 6,
      op: 'world.interact',
      payload: { entityId: 'tree-1', action: 'chop' },
      ts: 6,
      protocolVersion: 1,
      clientToken: 'quest-progress-token-1'
    });
    const progress = await waitForMessage(client.messages, (message) => message.id === 6 && message.op === 'quest.objective_progress');
    expect(progress.payload).toMatchObject({
      questId: 'mist-harbor-field-aid',
      objectiveIndex: 0,
      current: 1,
      required: 1,
      reason: 'material_collected'
    });
    const completed = await waitForMessage(client.messages, (message) => message.id === 6 && message.op === 'quest.delta');
    expect(completed.payload).toMatchObject({
      ok: true,
      questId: 'mist-harbor-field-aid',
      status: 'completed'
    });

    client.send({
      id: 7,
      op: 'quest.turn_in',
      payload: { questId: 'mist-harbor-field-aid' },
      ts: 7,
      protocolVersion: 1,
      clientToken: 'quest-turn-in-token-1'
    });
    const turnedIn = await waitForMessage(client.messages, (message) => message.id === 7 && message.op === 'quest.delta');
    expect(turnedIn.payload).toMatchObject({
      ok: true,
      questId: 'mist-harbor-field-aid',
      status: 'turned_in',
      rewards: {
        exp: expect.any(Number),
        gold: expect.any(Number),
        items: expect.any(Array)
      }
    });

    client.send({
      id: 8,
      op: 'quest.turn_in',
      payload: { questId: 'mist-harbor-field-aid' },
      ts: 8,
      protocolVersion: 1,
      clientToken: 'quest-turn-in-token-2'
    });
    const duplicate = await waitForMessage(client.messages, (message) => message.id === 8 && message.op === 'world.error');
    expect(duplicate.payload).toMatchObject({ code: 'QUEST_ALREADY_TURNED_IN', retryable: false });

    client.close();
  });

  it('rejects missing quests and inactive turn-ins without mutating the owner log', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:quest-errors');

    client.send({
      id: 3,
      op: 'quest.accept',
      payload: { questId: 'missing-quest' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'quest-accept-missing'
    });
    const missing = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'world.error');
    expect(missing.payload).toMatchObject({ code: 'QUEST_NOT_FOUND', retryable: false });

    client.send({
      id: 4,
      op: 'quest.turn_in',
      payload: { questId: 'mist-harbor-field-aid' },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'quest-turn-in-inactive'
    });
    const inactive = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'world.error');
    expect(inactive.payload).toMatchObject({ code: 'QUEST_NOT_ACTIVE', retryable: false });

    client.send({ id: 5, op: 'quest.list', payload: {}, ts: 5, protocolVersion: 1 });
    const snapshot = await waitForMessage(client.messages, (message) => message.id === 5 && message.op === 'quest.snapshot');
    expect(snapshot.payload).toMatchObject({
      ok: true,
      quests: expect.arrayContaining([
        expect.objectContaining({ questId: 'mist-harbor-field-aid', status: 'available' })
      ])
    });

    client.close();
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
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    const result = messages.find(predicate);
    if (result) {
      return result;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error('Timed out waiting for matching envelope');
}
