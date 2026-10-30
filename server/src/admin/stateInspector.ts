import type { Session, Storage } from '../storage/storage.js';
import type { CombatLockZone, WorldDelta } from '../world/types.js';
import type { ProgressionPatchInput, ProgressionPatchResult, WeeklyResetResult, WorldShard, WorldShardInspection } from '../world/worldShard.js';

export type AdminCombatLockCloseResult = 'victory' | 'defeat' | 'cancelled';

export interface StateInspectorEvents {
  onCombatLockCreated?: (lock: CombatLockZone) => void;
  onCombatLockClosed?: (result: {
    lock: CombatLockZone;
    entity?: unknown;
    delta?: WorldDelta;
    interestedPlayerIds?: string[];
  }) => void;
  onWeeklyReset?: (result: WeeklyResetResult) => void;
}

export class StateInspector {
  constructor(
    private readonly storage: Storage,
    private readonly shards: Map<string, WorldShard>,
    private readonly events: StateInspectorEvents = {}
  ) {}

  async listSessions(): Promise<Session[]> {
    return this.storage.sessions.listActive();
  }

  inspectShard(shardId: string): WorldShardInspection | undefined {
    return this.shards.get(shardId)?.inspectState();
  }

  async listDeltas(shardId: string): Promise<WorldDelta[]> {
    return this.storage.worldDeltas.list(shardId);
  }

  listCombatLocks(shardId: string): CombatLockZone[] | undefined {
    return this.shards.get(shardId)?.listCombatLocks();
  }

  async patchProgression(
    shardId: string,
    playerId: string,
    patch: ProgressionPatchInput['patch'],
    reason: string
  ): Promise<ProgressionPatchResult | undefined> {
    return this.shards.get(shardId)?.patchProgression({ playerId, patch, reason });
  }

  createTestCombatLock(shardId: string, input: { center: { x: number; y: number }; radius?: number }): CombatLockZone | undefined {
    const lock = this.shards.get(shardId)?.createCombatLock(input).lock;
    if (lock) {
      this.events.onCombatLockCreated?.(lock);
    }
    return lock;
  }

  async triggerWeeklyReset(shardId: string): Promise<WeeklyResetResult | undefined> {
    const result = await this.shards.get(shardId)?.triggerWeeklyReset();
    if (result) {
      this.events.onWeeklyReset?.(result);
    }
    return result;
  }

  async closeCombatLock(combatLockId: string, combatResult: AdminCombatLockCloseResult): Promise<{ lock: CombatLockZone; result: string; entity?: unknown; delta?: WorldDelta } | undefined> {
    for (const shard of this.shards.values()) {
      const result = await shard.closeCombatLock(combatLockId, combatResult);
      if (result.ok) {
        this.events.onCombatLockClosed?.({
          lock: result.lock,
          entity: result.entity,
          delta: result.delta,
          interestedPlayerIds: result.interestedPlayerIds
        });
        return { lock: result.lock, result: combatResult, entity: result.entity, delta: result.delta };
      }
    }
    return undefined;
  }
}
