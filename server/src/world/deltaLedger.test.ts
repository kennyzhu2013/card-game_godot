import { describe, expect, it } from 'vitest';
import { ManualClock } from '../core/time.js';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import { DeltaLedger } from './deltaLedger.js';

describe('DeltaLedger', () => {
  it('assigns increasing versions per shard and stores deltas', async () => {
    const storage = createMemoryStorage();
    const clock = new ManualClock(5000);
    const ledger = new DeltaLedger(storage, clock, { shardId: 'm3-dev', mapId: 'm3-test' });

    const first = await ledger.append({ actorPlayerId: 'p1', targetEntityId: 'tree-1', type: 'resource_depleted', patch: { depleted: true } });
    clock.advance(100);
    const second = await ledger.append({ actorPlayerId: 'p1', targetEntityId: 'ore-1', type: 'resource_depleted', patch: { depleted: true } });

    expect(first).toMatchObject({ version: 1, createdAt: 5000 });
    expect(second).toMatchObject({ version: 2, createdAt: 5100 });
    expect((await storage.worldDeltas.list('m3-dev')).map((delta) => delta.version)).toEqual([1, 2]);
  });
});
