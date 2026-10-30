import { afterEach, describe, expect, it } from 'vitest';
import WebSocket from 'ws';
import { createM3App, type M3App } from './app.js';
import type { Envelope } from './core/envelope.js';

describe('M3 local load smoke', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('serves snapshots to ten local clients in one shard', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20 });
    const clients = await Promise.all(Array.from({ length: 10 }, async (_unused, index) => connectClient(app!.wsPort, index + 1)));

    for (const client of clients) {
      client.send({ id: 1, op: 'auth.login', payload: { token: `dev:p${client.index}` }, ts: 1 });
      client.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2 });
    }
    await Promise.all(clients.map((client) => waitForOp(client.messages, 'world.entered')));

    for (const client of clients) {
      client.send({
        id: 3,
        op: 'world.move',
        payload: {
          playerId: `player-p${client.index}`,
          seq: 1,
          from: { x: 2, y: 2 },
          to: { x: 3, y: 2 },
          startedAt: Date.now() - 1000
        },
        ts: 3
      });
    }

    await Promise.all(clients.map((client) => waitForOp(client.messages, 'world.snapshot')));

    for (const client of clients) {
      expect(client.messages.some((message) => message.op === 'world.snapshot')).toBe(true);
      client.close();
    }
  });
});

interface TestClient {
  index: number;
  messages: Envelope[];
  send(envelope: Envelope): void;
  close(): void;
}

async function connectClient(port: number, index: number): Promise<TestClient> {
  const ws = new WebSocket(`ws://127.0.0.1:${port}`);
  const messages: Envelope[] = [];
  ws.on('message', (data) => messages.push(JSON.parse(data.toString()) as Envelope));
  await new Promise<void>((resolve, reject) => {
    ws.once('open', () => resolve());
    ws.once('error', reject);
  });
  return {
    index,
    messages,
    send(envelope: Envelope): void {
      ws.send(JSON.stringify(envelope));
    },
    close(): void {
      ws.close();
    }
  };
}

async function waitForOp(messages: Envelope[], op: string, timeoutMs = 1500): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (messages.some((message) => message.op === op)) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Timed out waiting for ${op}`);
}
