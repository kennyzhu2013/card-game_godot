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

describe('M3 forge protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('runs an nl forge request through progress to a fixed weapon result', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:forge-success');

    client.send({
      id: 3,
      op: 'forge.request',
      payload: {
        stationEntityId: 'mist-forge-1',
        mode: 'nl',
        prompt: 'shape a small fog blade',
        inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
      },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'forge-token-1'
    });

    const progress = await waitForMessages(client.messages, (message) => message.id === 3 && message.op === 'forge.progress', 3);
    expect(progress.map((message) => (message.payload as { phase?: string }).phase)).toEqual(['planning', 'shaping', 'tempering']);

    const result = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'forge.result');
    expect(result.payload).toMatchObject({
      ok: true,
      requestId: expect.stringMatching(/^forge-/),
      weapon: {
        itemId: 'forged_fog_blade',
        type: 'weapon'
      },
      consumed: [{ itemId: 'moonlight_grass', amount: 1 }]
    });

    client.close();
  });

  it('rejects insufficient forge inputs without mutating inventory', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:forge-reject');

    client.send({
      id: 3,
      op: 'forge.request',
      payload: {
        stationEntityId: 'mist-forge-1',
        mode: 'nl',
        prompt: 'overdraw ore',
        inputs: [{ itemId: 'mist_iron_ore', amount: 99 }]
      },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'forge-token-2'
    });

    const result = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'forge.result');
    expect(result.payload).toMatchObject({
      ok: false,
      code: 'FORGE_INPUTS_INSUFFICIENT',
      refunded: []
    });

    client.send({ id: 4, op: 'inventory.fetch', payload: {}, ts: 4, protocolVersion: 1 });
    const snapshot = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'inventory.snapshot');
    expect(snapshot.payload).toMatchObject({
      ok: true,
      items: expect.arrayContaining([
        expect.objectContaining({ itemId: 'mist_iron_ore', amount: 2 })
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
