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

describe('M3 shop protocol integration', () => {
  let app: M3App | undefined;

  afterEach(async () => {
    if (app) {
      await app.stop();
      app = undefined;
    }
  });

  it('lists shop offers, buys with gold, rejects out-of-stock buys, and sells back for gold', async () => {
    app = await createM3App({ port: 0, adminPort: 0, snapshotRateHz: 20, adminToken: 'test-admin-token' });
    const client = await connectClient(app.wsPort);
    await loginAndEnter(client);

    client.send({ id: 3, op: 'shop.list', payload: { shopEntityId: 'mist-harbor-general-store' }, ts: 3, protocolVersion: 1 });
    const snapshot = await waitForEnvelopeId(client.messages, 3);
    expect(snapshot).toMatchObject({
      op: 'shop.snapshot',
      payload: {
        ok: true,
        shopEntityId: 'mist-harbor-general-store',
        offers: expect.arrayContaining([expect.objectContaining({ itemId: 'harbor_charm', price: 6, stock: 1 })]),
        buybackPrices: expect.objectContaining({ harbor_charm: 3 })
      }
    });

    client.send({
      id: 4,
      op: 'shop.buy',
      payload: { shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1 },
      ts: 4,
      protocolVersion: 1,
      clientToken: 'shop-buy-token-1'
    });
    const bought = await waitForEnvelopeId(client.messages, 4);
    expect(bought).toMatchObject({
      op: 'shop.transaction_result',
      payload: { ok: true, shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1, goldDelta: -6 }
    });
    client.send({ id: 5, op: 'inventory.fetch', payload: {}, ts: 5, protocolVersion: 1 });
    const afterBuy = await waitForEnvelopeId(client.messages, 5);
    expect(afterBuy.payload).toMatchObject({
      gold: 19,
      items: expect.arrayContaining([expect.objectContaining({ itemId: 'harbor_charm', amount: 1 })])
    });

    client.send({
      id: 6,
      op: 'shop.buy',
      payload: { shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1 },
      ts: 6,
      protocolVersion: 1,
      clientToken: 'shop-buy-token-2'
    });
    const outOfStock = await waitForEnvelopeId(client.messages, 6);
    expect(outOfStock).toMatchObject({
      op: 'shop.transaction_result',
      payload: { ok: false, code: 'OUT_OF_STOCK', itemId: 'harbor_charm', amount: 1, goldDelta: 0 }
    });

    client.send({
      id: 7,
      op: 'shop.sell',
      payload: { shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1 },
      ts: 7,
      protocolVersion: 1,
      clientToken: 'shop-sell-token-1'
    });
    const sold = await waitForEnvelopeId(client.messages, 7);
    expect(sold).toMatchObject({
      op: 'shop.transaction_result',
      payload: { ok: true, shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1, goldDelta: 3 }
    });
    client.send({ id: 8, op: 'inventory.fetch', payload: {}, ts: 8, protocolVersion: 1 });
    const afterSell = await waitForEnvelopeId(client.messages, 8);
    expect(afterSell.payload).toMatchObject({ gold: 22 });
    expect((afterSell.payload as { items: Array<{ itemId: string }> }).items.some((item) => item.itemId === 'harbor_charm')).toBe(false);

    client.close();
  });
});

async function loginAndEnter(client: TestClient): Promise<void> {
  client.send({ id: 1, op: 'auth.login', payload: { token: 'dev:shop' }, ts: 1, protocolVersion: 1 });
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
