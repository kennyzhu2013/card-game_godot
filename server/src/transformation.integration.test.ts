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

describe('M3 transformation protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('starts disguise state and exposes the owner when suspicion accumulates', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:transformation-owner');

    client.send({
      id: 3,
      op: 'transformation.start',
      payload: { speciesId: 'mist-wolf', depth: 'disguise' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'transformation-start-token-1'
    });
    const started = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'transformation.state');
    expect(started.payload).toMatchObject({
      active: true,
      speciesId: 'mist-wolf',
      depth: 'disguise',
      suspicions: { 'mist-harbor-guard': 0 },
      reputations: { 'mist-wolf': 0 }
    });
    expect(Number((started.payload as Record<string, unknown>).remainingMs)).toBeGreaterThan(0);

    client.send({
      id: 4,
      op: 'transformation.feed',
      payload: { itemId: 'moonlight_grass', amount: 1 },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'transformation-feed-token-1'
    });
    const suspicion = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'transformation.suspicion_changed');
    expect(suspicion.payload).toMatchObject({
      npcId: 'mist-harbor-guard',
      before: 0,
      after: 50,
      reason: 'consumed'
    });
    const fedState = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'transformation.state');
    expect(fedState.payload).toMatchObject({
      active: true,
      speciesId: 'mist-wolf',
      depth: 'disguise',
      suspicions: { 'mist-harbor-guard': 50 }
    });

    client.send({
      id: 5,
      op: 'transformation.feed',
      payload: { itemId: 'moonlight_grass', amount: 1 },
      ts: 5,
      protocolVersion: 1,
      clientToken: 'transformation-feed-token-2'
    });
    const exposed = await waitForMessage(client.messages, (message) => message.id === 5 && message.op === 'transformation.exposed');
    expect(exposed.payload).toMatchObject({
      speciesId: 'mist-wolf',
      reason: 'suspicion_overflow'
    });
    const exposedState = await waitForMessage(client.messages, (message) => message.id === 5 && message.op === 'transformation.state');
    expect(exposedState.payload).toMatchObject({
      active: false,
      suspicions: { 'mist-harbor-guard': 100 },
      reputations: { 'mist-wolf': -1 }
    });

    client.close();
  });

  it('rejects unknown species and inactive feed without mutating owner state', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:transformation-errors');

    client.send({
      id: 3,
      op: 'transformation.start',
      payload: { speciesId: 'unknown-species', depth: 'disguise' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'transformation-start-unknown'
    });
    const unknown = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'world.error');
    expect(unknown.payload).toMatchObject({ code: 'SPECIES_UNKNOWN', retryable: false });

    client.send({
      id: 4,
      op: 'transformation.feed',
      payload: { itemId: 'moonlight_grass', amount: 1 },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'transformation-feed-inactive'
    });
    const inactive = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'world.error');
    expect(inactive.payload).toMatchObject({ code: 'TRANSFORMATION_NOT_ACTIVE', retryable: false });

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
