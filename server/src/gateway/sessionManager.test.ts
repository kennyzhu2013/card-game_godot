import { describe, expect, it } from 'vitest';
import { ManualClock } from '../core/time.js';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import { SessionManager } from './sessionManager.js';

describe('SessionManager', () => {
  it('moves connected sessions through authenticated and in_world states', async () => {
    const clock = new ManualClock(1000);
    const manager = new SessionManager(createMemoryStorage(), clock);
    const session = await manager.create('socket-1', '127.0.0.1');

    await manager.authenticate(session.sessionId, 'account-1', 'player-1');
    await manager.enterWorld(session.sessionId, 'm3-dev');

    expect(await manager.get(session.sessionId)).toMatchObject({
      state: 'in_world',
      accountId: 'account-1',
      playerId: 'player-1',
      shardId: 'm3-dev',
      lastHeartbeatAt: 1000
    });
  });

  it('finds reconnectable sessions inside grace window', async () => {
    const clock = new ManualClock(1000);
    const manager = new SessionManager(createMemoryStorage(), clock);
    const session = await manager.create('socket-1', '127.0.0.1');
    await manager.authenticate(session.sessionId, 'account-1', 'player-1');
    await manager.disconnect(session.sessionId);
    clock.advance(30000);

    const reclaimed = await manager.findReconnectable('account-1', 'player-1', 60000);
    expect(reclaimed?.sessionId).toBe(session.sessionId);
  });

  it('switches an in-world session to a different shard while preserving the player identity', async () => {
    const clock = new ManualClock(1000);
    const manager = new SessionManager(createMemoryStorage(), clock);
    const session = await manager.create('socket-1', '127.0.0.1');
    await manager.authenticate(session.sessionId, 'account-1', 'player-1');
    await manager.enterWorld(session.sessionId, 'm3-dev');

    const switched = await manager.switchShard(session.sessionId, 'm3-event');

    expect(switched).toMatchObject({
      sessionId: session.sessionId,
      shardId: 'm3-event',
      state: 'in_world',
      playerId: 'player-1'
    });
    expect(await manager.get(session.sessionId)).toMatchObject({
      shardId: 'm3-event',
      state: 'in_world'
    });
  });

  it('rejects invalid lifecycle transitions and disconnect is idempotent', async () => {
    const clock = new ManualClock(1000);
    const manager = new SessionManager(createMemoryStorage(), clock);
    const session = await manager.create('socket-1', '127.0.0.1');

    await expect(manager.enterWorld(session.sessionId, 'm3-dev')).rejects.toThrow('SESSION_NOT_AUTHENTICATED');
    await manager.disconnect(session.sessionId);
    await manager.disconnect(session.sessionId);

    expect(await manager.get(session.sessionId)).toMatchObject({ state: 'disconnected', disconnectedAt: 1000 });
  });
});
