import type { CombatLockZone } from '../world/types.js';

export interface CombatActionInput {
  playerId: string;
  action: string;
  targetId?: string;
}

export interface CombatActionRecord extends CombatActionInput {
  submittedAt: number;
}

export interface CombatStatePayload {
  combatLockId: string;
  participantPlayerIds: string[];
  hostileEntityIds: string[];
  actionCount: number;
  updatedAt: number;
}

export class CombatInstance {
  readonly actions: CombatActionRecord[] = [];

  constructor(private readonly lock: CombatLockZone) {}

  submitAction(input: CombatActionInput, now: number): CombatStatePayload {
    this.actions.push({ ...input, submittedAt: now });

    return {
      combatLockId: this.lock.combatLockId,
      participantPlayerIds: [...this.lock.participantPlayerIds],
      hostileEntityIds: [...this.lock.hostileEntityIds],
      actionCount: this.actions.length,
      updatedAt: now
    };
  }
}
