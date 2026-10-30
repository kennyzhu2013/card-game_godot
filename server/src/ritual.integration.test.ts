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

describe('M3 ritual protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('starts, feeds, progresses, and resolves a ritual request', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:ritual-success');

    client.send({
      id: 3,
      op: 'ritual.start',
      payload: {
        altarEntityId: 'mist-altar-1',
        ritualId: 'fog_lattice_focus',
        expectedMaterials: [{ itemId: 'moonlight_grass', amount: 1 }]
      },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'ritual-token-1'
    });

    const started = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'ritual.progress');
    expect(started.payload).toMatchObject({
      requestId: expect.stringMatching(/^ritual-/),
      phase: 'drawing',
      progress: expect.any(Number),
      pollutionPressure: expect.any(Number)
    });
    const requestId = (started.payload as { requestId: string }).requestId;

    client.send({
      id: 4,
      op: 'ritual.feed',
      payload: { requestId, itemId: 'moonlight_grass', amount: 1 },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'ritual-token-2'
    });

    const channeling = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'ritual.progress');
    expect(channeling.payload).toMatchObject({ requestId, phase: 'channeling', progress: 1 });

    const result = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'ritual.result');
    expect(result.payload).toMatchObject({
      ok: true,
      requestId,
      effect: {
        ritualId: 'fog_lattice_focus',
        type: 'world_focus'
      },
      consumed: [{ itemId: 'moonlight_grass', amount: 1 }]
    });

    client.close();
  });

  it('interrupts an active ritual when the owner attacks', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:ritual-interrupt');

    client.send({
      id: 3,
      op: 'ritual.start',
      payload: {
        altarEntityId: 'mist-altar-1',
        ritualId: 'fog_lattice_focus',
        expectedMaterials: [{ itemId: 'moonlight_grass', amount: 1 }]
      },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'ritual-token-3'
    });
    const started = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'ritual.progress');
    const requestId = (started.payload as { requestId: string }).requestId;

    client.send({
      id: 4,
      op: 'combat.action',
      payload: { combatLockId: 'ritual-ambush', action: 'attack', targetId: 'altar-threat' },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'ritual-attack-token'
    });

    const interrupted = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'ritual.interrupted');
    expect(interrupted.payload).toMatchObject({ requestId, reason: 'attacked' });

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
