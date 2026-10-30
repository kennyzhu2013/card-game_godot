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

describe('M3 chat protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('broadcasts say to current shard, whisper to two endpoints, and party chat to party members', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const alpha = await connectClient(app.wsPort);
    const beta = await connectClient(app.wsPort);
    const spectator = await connectClient(app.wsPort);
    await loginAndEnter(alpha, 'dev:chat-a');
    await loginAndEnter(beta, 'dev:chat-b');
    await loginOnly(spectator, 'dev:chat-c');

    const sayStart = [alpha.messages.length, beta.messages.length, spectator.messages.length];
    alpha.send({
      id: 3,
      op: 'chat.say',
      payload: { text: 'Shard tide report' },
      ts: 3,
      protocolVersion: 1,
      clientToken: 'chat-say-token-1'
    });
    await waitForChat(alpha.messages, sayStart[0], 'say', 'player-chat-a', 'Shard tide report');
    await waitForChat(beta.messages, sayStart[1], 'say', 'player-chat-a', 'Shard tide report');
    await expectNoChatSince(spectator.messages, sayStart[2], 250);

    const whisperStart = [alpha.messages.length, beta.messages.length, spectator.messages.length];
    alpha.send({
      id: 4,
      op: 'chat.whisper',
      payload: { targetPlayerId: 'player-chat-b', text: 'Private harbor route' },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'chat-whisper-token-1'
    });
    await waitForChat(alpha.messages, whisperStart[0], 'whisper', 'player-chat-a', 'Private harbor route');
    await waitForChat(beta.messages, whisperStart[1], 'whisper', 'player-chat-a', 'Private harbor route');
    await expectNoChatSince(spectator.messages, whisperStart[2], 250);

    const partyStart = [alpha.messages.length, beta.messages.length, spectator.messages.length];
    alpha.send({
      id: 5,
      op: 'chat.party',
      payload: { partyId: 'party-alpha', text: 'Party rendezvous' },
      ts: 5,
      protocolVersion: 1,
      clientToken: 'chat-party-token-1'
    });
    await waitForChat(alpha.messages, partyStart[0], 'party', 'player-chat-a', 'Party rendezvous');
    await waitForChat(beta.messages, partyStart[1], 'party', 'player-chat-a', 'Party rendezvous');
    await expectNoChatSince(spectator.messages, partyStart[2], 250);

    alpha.close();
    beta.close();
    spectator.close();
  });
});

async function loginAndEnter(client: TestClient, token: string): Promise<void> {
  client.send({ id: 1, op: 'auth.login', payload: { token }, ts: 1, protocolVersion: 1 });
  client.send({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 2, protocolVersion: 1 });
  await waitForOp(client.messages, 'world.entered');
}

async function loginOnly(client: TestClient, token: string): Promise<void> {
  client.send({ id: 1, op: 'auth.login', payload: { token }, ts: 1, protocolVersion: 1 });
  await waitForOp(client.messages, 'auth.result');
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

async function waitForChat(messages: Envelope[], startIndex: number, channel: string, fromPlayerId: string, text: string): Promise<Envelope> {
  return waitFor(() => messages.slice(startIndex).find((message) => {
    const payload = message.payload as { channel?: string; playerId?: string; text?: string };
    return message.op === 'chat.message' && payload.channel === channel && payload.playerId === fromPlayerId && payload.text === text;
  }), `chat ${channel}:${text}`, 1500);
}

async function expectNoChatSince(messages: Envelope[], startIndex: number, timeoutMs: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, timeoutMs));
  expect(messages.slice(startIndex).some((message) => message.op === 'chat.message')).toBe(false);
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
