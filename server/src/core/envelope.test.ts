import { describe, expect, it } from 'vitest';
import { decodeEnvelope, encodeEnvelope, validateEnvelope } from './envelope.js';

describe('envelope', () => {
  it('round trips a valid JSON envelope', () => {
    const buffer = encodeEnvelope({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 100 });

    expect(decodeEnvelope(buffer)).toEqual({ id: 1, op: 'auth.login', payload: { token: 'dev:one' }, ts: 100, protocolVersion: 0 });
  });

  it('round trips protocol v1 header fields without breaking legacy envelopes', () => {
    const v1 = {
      id: 3,
      op: 'world.interact',
      payload: { entityId: 'tree-1', action: 'chop' },
      ts: 150,
      protocolVersion: 1,
      clientToken: 'token-abc123',
      shardId: 'm3-dev'
    };

    expect(decodeEnvelope(encodeEnvelope(v1))).toEqual(v1);
    expect(validateEnvelope({ id: 4, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 151 })).toEqual({
      ok: true,
      value: { id: 4, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 151, protocolVersion: 0 }
    });
  });

  it('round trips a valid MessagePack envelope', () => {
    const buffer = encodeEnvelope({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 125 }, 'msgpack');

    expect(decodeEnvelope(buffer, 'msgpack')).toEqual({ id: 2, op: 'world.enter', payload: { shardId: 'm3-dev' }, ts: 125, protocolVersion: 0 });
  });

  it('rejects malformed envelopes', () => {
    expect(validateEnvelope({ id: '1', op: 'auth.login', payload: {}, ts: 100 }).ok).toBe(false);
    expect(validateEnvelope({ id: 1, op: '', payload: {}, ts: 100 }).ok).toBe(false);
    expect(validateEnvelope({ id: 1, op: 'auth.login', payload: {}, ts: -1 }).ok).toBe(false);
    expect(validateEnvelope({ id: 1, op: 'auth.login', ts: 100 }).ok).toBe(false);
    expect(validateEnvelope({ id: 1, op: 'auth.login', payload: {}, ts: 100, protocolVersion: '1' }).ok).toBe(false);
    expect(validateEnvelope({ id: 1, op: 'auth.login', payload: {}, ts: 100, clientToken: '' }).ok).toBe(false);
    expect(validateEnvelope({ id: 1, op: 'auth.login', payload: {}, ts: 100, shardId: '' }).ok).toBe(false);
  });
});
