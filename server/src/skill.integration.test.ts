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

describe('M3 skill protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('learns a skill and equips a loadout from server-authoritative state', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:skill-success');

    client.send({
      id: 3,
      op: 'skill.learn',
      payload: { skillId: 'mist-step', pathwaySource: 'tide_priestess' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'skill-learn-token-1'
    });
    const learnedDelta = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'skill.delta');
    expect(learnedDelta.payload).toMatchObject({
      ok: true,
      learnedAdded: ['mist-step']
    });
    const learnedSnapshot = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'skill.snapshot');
    expect(learnedSnapshot.payload).toMatchObject({
      ok: true,
      learned: ['mist-step'],
      loadouts: { default: [] },
      activeLoadoutId: 'default'
    });

    client.send({
      id: 4,
      op: 'skill.equip_loadout',
      payload: { loadoutId: 'field', skills: ['mist-step'] },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'skill-equip-token-1'
    });
    const equipDelta = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'skill.delta');
    expect(equipDelta.payload).toMatchObject({
      ok: true,
      activeLoadoutId: 'field'
    });
    const equipSnapshot = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'skill.snapshot');
    expect(equipSnapshot.payload).toMatchObject({
      ok: true,
      learned: ['mist-step'],
      loadouts: { field: ['mist-step'] },
      activeLoadoutId: 'field'
    });

    client.close();
  });

  it('rejects unknown skills and unloaded loadouts without mutating skill state', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client, 'dev:skill-errors');

    client.send({
      id: 3,
      op: 'skill.learn',
      payload: { skillId: 'missing-skill', pathwaySource: 'tide_priestess' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'skill-learn-missing'
    });
    const missing = await waitForMessage(client.messages, (message) => message.id === 3 && message.op === 'world.error');
    expect(missing.payload).toMatchObject({ code: 'SKILL_UNKNOWN', retryable: false });

    client.send({
      id: 4,
      op: 'skill.equip_loadout',
      payload: { loadoutId: 'field', skills: ['missing-skill'] },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'skill-equip-missing'
    });
    const prereq = await waitForMessage(client.messages, (message) => message.id === 4 && message.op === 'world.error');
    expect(prereq.payload).toMatchObject({ code: 'SKILL_PREREQ_NOT_MET', retryable: false });

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
