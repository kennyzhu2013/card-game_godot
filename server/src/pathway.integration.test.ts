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

describe('M3 pathway protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('lists owner pathway state and advances sequence with unlock event', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:pathway-success');

    client.send({ id: 3, op: 'pathway.list', payload: {}, ts: 3, protocolVersion: 1 });
    const snapshot = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'pathway.snapshot');
    expect(snapshot.payload).toMatchObject({
      ok: true,
      sequences: expect.arrayContaining([
        expect.objectContaining({
          pathwayId: 'tide_priestess',
          sequence: 9,
          sanity: 0,
          abnormalities: 0
        })
      ])
    });

    client.send({
      id: 4,
      op: 'pathway.advance_request',
      payload: {
        pathwayId: 'tide_priestess',
        targetSequence: 8,
        potionItemId: 'moonlight_grass',
        ritualSnapshotId: 'ritual-snapshot-1'
      },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'pathway-advance-token-1'
    });
    const delta = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'pathway.delta');
    expect(delta.payload).toMatchObject({
      ok: true,
      pathwayId: 'tide_priestess',
      sequence: 8,
      sanity: 12,
      abnormalities: 1,
      rewards: [
        expect.objectContaining({
          abilityId: 'mist-step',
          skillId: 'mist-step',
          pathwayId: 'tide_priestess',
          sequence: 8
        })
      ]
    });

    const unlock = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'pathway.unlock_event');
    expect(unlock.payload).toMatchObject({
      pathwayId: 'tide_priestess',
      sequence: 8,
      abilityIds: ['mist-step']
    });

    client.close();
  });

  it('rejects invalid pathway and invalid potion without mutating owner sequence', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:pathway-errors');

    client.send({
      id: 3,
      op: 'pathway.advance_request',
      payload: { pathwayId: 'unknown-pathway', targetSequence: 8, potionItemId: 'moonlight_grass' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'pathway-advance-unknown'
    });
    const unknown = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'world.error');
    expect(unknown.payload).toMatchObject({ code: 'PATHWAY_UNKNOWN', retryable: false });

    client.send({
      id: 4,
      op: 'pathway.advance_request',
      payload: { pathwayId: 'tide_priestess', targetSequence: 8, potionItemId: 'invalid_potion' },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'pathway-advance-invalid-potion'
    });
    const invalidPotion = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'world.error');
    expect(invalidPotion.payload).toMatchObject({ code: 'POTION_INVALID', retryable: false });

    client.send({ id: 5, op: 'pathway.list', payload: {}, ts: 5, protocolVersion: 1 });
    const snapshot = await waitForMessage(client.messages, (message) => message.id === 5 && message.op === 'pathway.snapshot');
    expect(snapshot.payload).toMatchObject({
      ok: true,
      sequences: expect.arrayContaining([
        expect.objectContaining({ pathwayId: 'tide_priestess', sequence: 9, sanity: 0 })
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
