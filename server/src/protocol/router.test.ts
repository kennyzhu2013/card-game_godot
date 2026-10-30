import { describe, expect, it } from 'vitest';
import { ServerOps } from './ops.js';
import { ProtocolRouter } from './router.js';

describe('ProtocolRouter', () => {
  it('dispatches a known op to its handler', async () => {
    const router = new ProtocolRouter({ now: () => 5000 });
    router.register('world.enter', async ({ payload }) => ({ op: ServerOps.WorldEntered, payload }));

    const response = await router.dispatch({
      sessionId: 'session-1',
      envelope: { id: 7, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 10 }
    });

    expect(response).toEqual([{ id: 7, op: 'world.entered', payload: { shardId: 'm3-dev' }, ts: 5000, protocolVersion: 0 }]);
  });

  it('returns structured error for unknown op', async () => {
    const router = new ProtocolRouter({ now: () => 6000 });
    const response = await router.dispatch({
      sessionId: 'session-1',
      envelope: { id: 8, op: 'unknown.op', payload: {}, ts: 10 }
    });

    expect(response[0]).toMatchObject({
      id: 8,
      op: ServerOps.WorldError,
      payload: { code: 'UNKNOWN_OP', retryable: false },
      ts: 6000
    });
  });

  it('converts handler errors into retryable structured errors', async () => {
    const router = new ProtocolRouter({ now: () => 7000 });
    router.register('world.move', async () => {
      throw new Error('storage unavailable');
    });

    const response = await router.dispatch({
      sessionId: 'session-1',
      envelope: { id: 9, op: 'world.move', payload: {}, ts: 10 }
    });

    expect(response[0]).toMatchObject({
      id: 9,
      op: ServerOps.WorldError,
      payload: { code: 'HANDLER_ERROR', retryable: true, message: 'storage unavailable' },
      ts: 7000
    });
  });
});
