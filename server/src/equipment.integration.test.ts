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

describe('M3 equipment protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('lists, equips, and unequips the owner weapon slot authoritatively', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client);

    client.send({ id: 3, op: 'equipment.list', payload: {}, ts: 3, protocolVersion: 1 });
    const initial = await waitForEnvelopeId(client.messages, 3);
    expect(initial).toMatchObject({
      op: 'equipment.snapshot',
      payload: { ok: true, equipped: { trinkets: [] }, loadouts: expect.any(Object) }
    });

    client.send({
      id: 4,
      op: 'equipment.equip',
      payload: { slot: 'weapon', itemId: 'flame_sword' },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'equip-token-1'
    });
    const equipped = await waitForEnvelopeId(client.messages, 4);
    expect(equipped).toMatchObject({
      op: 'equipment.snapshot',
      payload: { ok: true, equipped: { weapon: 'flame_sword', trinkets: [] } }
    });

    client.send({
      id: 5,
      op: 'equipment.unequip',
      payload: { slot: 'weapon' },
      ts: 5,
      protocolVersion: 1,
      clientToken: 'equip-token-2'
    });
    const unequipped = await waitForEnvelopeId(client.messages, 5);
    expect(unequipped.op).toBe('equipment.snapshot');
    const payload = unequipped.payload as { equipped?: { weapon?: string } };
    expect(payload.equipped?.weapon).toBeUndefined();

    client.close();
  });
});

async function loginAndEnter(client: TestClient): Promise<void> {
  client.send({ id: 1, op: 'auth.login', payload: { token: 'dev:equipment' }, ts: 1, protocolVersion: 1 });
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
