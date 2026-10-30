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

describe('M3 weekly reset protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('broadcasts weekly.reset to all active shard players with respawned spawn ids', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const first = await connectClient(app.wsPort);
    const second = await connectClient(app.wsPort);
    await loginAndEnter(first, 'dev:weekly-a');
    await loginAndEnter(second, 'dev:weekly-b');

    const response = await adminFetch(app.adminPort, '/admin/shards/m3-dev/weekly-reset/test', {
      method: 'POST',
      body: JSON.stringify({})
    });
    expect(response.status).toBe(200);
    const body = await response.json() as { reset: { resetId: string; respawnedSpawnIds: string[] } };
    expect(body.reset.respawnedSpawnIds.length).toBeGreaterThan(0);

    const firstReset = await waitForOp(first.messages, 'weekly.reset');
    const secondReset = await waitForOp(second.messages, 'weekly.reset');
    for (const reset of [firstReset, secondReset]) {
      expect(reset.payload).toMatchObject({
        resetId: body.reset.resetId,
        mapId: 'mist-harbor-test',
        serverTime: expect.any(Number),
        nextResetAt: expect.any(Number),
        respawnedSpawnIds: body.reset.respawnedSpawnIds
      });
    }

    first.close();
    second.close();
  });
});

async function loginAndEnter(client: TestClient, token: string): Promise<void> {
  client.send({ id: 1, op: 'auth.login', payload: { token }, ts: 1, protocolVersion: 1 });
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

async function adminFetch(adminPort: number, path: string, init: RequestInit): Promise<Response> {
  return fetch(`http://127.0.0.1:${adminPort}${path}`, {
    ...init,
    headers: {
      authorization: 'Bearer test-admin-token',
      'content-type': 'application/json',
      ...(init.headers ?? {})
    }
  });
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
