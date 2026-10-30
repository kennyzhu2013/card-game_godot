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

describe('M3 inventory protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('fetches an owner snapshot, applies discard delta, and rejects excessive discard', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client);

    client.send({ id: 3, op: 'inventory.fetch', payload: {}, ts: 3, protocolVersion: 1 });
    const snapshot = await waitForEnvelopeId(client.messages, 3);
    expect(snapshot).toMatchObject({
      op: 'inventory.snapshot',
      payload: {
        ok: true,
        capacity: expect.any(Number),
        gold: expect.any(Number),
        items: expect.arrayContaining([
          expect.objectContaining({ itemId: 'moonlight_grass', type: 'material', amount: 3 })
        ])
      }
    });

    client.send({
      id: 4,
      op: 'inventory.discard',
      payload: { itemId: 'moonlight_grass', amount: 2 },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'discard-token-1'
    });
    const delta = await waitForEnvelopeId(client.messages, 4);
    expect(delta).toMatchObject({
      op: 'inventory.delta',
      payload: { ok: true, changes: [{ itemId: 'moonlight_grass', before: 3, after: 1 }] }
    });

    client.send({
      id: 5,
      op: 'inventory.discard',
      payload: { itemId: 'moonlight_grass', amount: 5 },
      ts: 5,
      protocolVersion: 1,
      clientToken: 'discard-token-2'
    });
    const rejected = await waitForEnvelopeId(client.messages, 5);
    expect(rejected).toMatchObject({
      op: 'world.error',
      payload: { code: 'INSUFFICIENT_AMOUNT', retryable: false }
    });

    client.close();
  });
});

async function loginAndEnter(client: TestClient): Promise<void> {
  client.send({ id: 1, op: 'auth.login', payload: { token: 'dev:inventory' }, ts: 1, protocolVersion: 1 });
  client.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 });
  await waitForOp(client.messages, 'world.entered');
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

async function waitForEnvelopeId(messages: Envelope[], id: number, timeoutMs = 1500): Promise<Envelope> {
  return waitFor(() => messages.find((message) => message.id === id), `envelope id ${id}`, timeoutMs);
}

async function waitForOp(messages: Envelope[], op: string, timeoutMs = 1500): Promise<Envelope> {
  return waitFor(() => messages.find((message) => message.op === op), `op ${op}`, timeoutMs);
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
