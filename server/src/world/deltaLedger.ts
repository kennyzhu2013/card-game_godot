import type { Clock } from '../core/time.js';
import type { Storage } from '../storage/storage.js';
import type { WorldDelta } from './types.js';

export interface DeltaLedgerScope {
  shardId: string;
  mapId: string;
}

export type DeltaAppendInput = Pick<WorldDelta, 'actorPlayerId' | 'targetEntityId' | 'type' | 'patch'>;

export class DeltaLedger {
  private nextVersion = 1;

  constructor(
    private readonly storage: Storage,
    private readonly clock: Clock,
    private readonly scope: DeltaLedgerScope
  ) {}

  async append(input: DeltaAppendInput): Promise<WorldDelta> {
    const version = this.nextVersion++;
    const delta: WorldDelta = {
      deltaId: `${this.scope.shardId}-delta-${version}`,
      shardId: this.scope.shardId,
      mapId: this.scope.mapId,
      actorPlayerId: input.actorPlayerId,
      targetEntityId: input.targetEntityId,
      type: input.type,
      patch: structuredClone(input.patch),
      createdAt: this.clock.now(),
      version
    };
    await this.storage.worldDeltas.append(delta);
    return delta;
  }
}
