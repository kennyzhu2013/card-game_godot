import { gridDistance } from './aoiSystem.js';
import type { GridPosition, PlayerWorldState, WorldEntity } from './types.js';

export type SkillTargetType = 'self' | 'ally' | 'enemy' | 'ground_point' | 'entity_id' | 'none';
export type SkillBroadcastScope = 'self_only' | 'aoi_visible';

export type SkillFailureCode =
  | 'SKILL_PATHWAY_LOCKED'
  | 'SKILL_NOT_WORLD_CASTABLE'
  | 'SKILL_COOLDOWN'
  | 'SKILL_OUT_OF_RANGE'
  | 'SKILL_INVALID_TARGET'
  | 'SKILL_TARGET_NOT_FOUND'
  | 'SKILL_INSUFFICIENT_MANA'
  | 'SKILL_LOCKED_IN_COMBAT'
  | 'SKILL_OUT_OF_CONTROL'
  | 'SKILL_RATE_LIMITED'
  | 'SKILL_VALIDATION_FAILED'
  | 'SKILL_CONTRACT_MISMATCH'
  | 'SKILL_CHANNEL_INTERRUPTED';

export interface SkillAbilityContract {
  abilityId: string;
  pathwayId: string;
  sequence: number;
  worldCastable: boolean;
  worldTargetType: SkillTargetType;
  worldRangeCells: number;
  worldCooldownMs: number;
  costMp: number;
  worldPollutionCost: number;
  worldVfxId: string;
  worldBroadcastScope: SkillBroadcastScope;
}

export interface SkillCasterState {
  player: PlayerWorldState;
  pathwayId: string;
  sequence: number;
  mana: number;
  sanity?: number;
  outOfControl?: {
    active: boolean;
    worldAbilityId?: string;
  };
}

export interface SkillTargetInput {
  targetType: SkillTargetType;
  targetEntityId?: string;
  targetGroundPosition?: GridPosition;
}

export interface SkillRateLimitState {
  ok: boolean;
  resetMs?: number;
}

export interface SkillCastInput {
  caster: SkillCasterState;
  abilityId: string;
  pathwayId: string;
  sequence: number;
  target: SkillTargetInput;
  targetEntity?: WorldEntity;
  now: number;
  clientToken: string;
  rateLimit?: SkillRateLimitState;
}

export type SkillValidationResult =
  | {
      ok: true;
      abilityId: string;
      cooldownEndsAt: number;
      pollutionApplied: number;
      manaApplied: number;
      vfxId: string;
      broadcastScope: SkillBroadcastScope;
    }
  | {
      ok: false;
      code: SkillFailureCode;
      developerHint: string;
      cooldownEndsAt: number;
    };

export class SkillValidator {
  private readonly abilities = new Map<string, SkillAbilityContract>();
  private readonly consumedClientTokens = new Set<string>();
  private readonly cooldowns = new Map<string, number>();

  constructor(abilities: SkillAbilityContract[]) {
    for (const ability of abilities) {
      this.abilities.set(ability.abilityId, { ...ability });
    }
  }

  validateCast(input: SkillCastInput): SkillValidationResult {
    if (input.rateLimit && !input.rateLimit.ok) {
      const resetMs = Math.max(0, input.rateLimit.resetMs ?? 0);
      return rejected('SKILL_RATE_LIMITED', `${input.abilityId} exceeded world skill rate limits`, input.now + resetMs);
    }
    if (!input.clientToken || this.consumedClientTokens.has(input.clientToken)) {
      return rejected('SKILL_CONTRACT_MISMATCH', `${input.abilityId} received a replayed or missing clientToken`);
    }

    const effectiveAbilityId = this.resolveEffectiveAbilityId(input);
    if (!effectiveAbilityId.ok) {
      return effectiveAbilityId;
    }

    const ability = this.abilities.get(effectiveAbilityId.value);
    if (!ability) {
      return this.isCasterOutOfControl(input.caster)
        ? rejected('SKILL_OUT_OF_CONTROL', `Out-of-control world ability ${effectiveAbilityId.value} is unavailable`)
        : rejected('SKILL_PATHWAY_LOCKED', `Player cannot cast ${input.abilityId}`);
    }
    if (!this.isAbilityUnlocked(input, ability)) {
      return rejected('SKILL_PATHWAY_LOCKED', `Player cannot cast ${effectiveAbilityId.value}`);
    }
    if (!ability.worldCastable) {
      return rejected('SKILL_NOT_WORLD_CASTABLE', `${ability.abilityId} is not world castable`);
    }

    const cooldownKey = this.cooldownKey(input.caster.player.playerId, ability.abilityId);
    const cooldownEndsAt = this.cooldowns.get(cooldownKey) ?? 0;
    if (cooldownEndsAt > input.now) {
      return rejected('SKILL_COOLDOWN', `${ability.abilityId} is cooling down`, cooldownEndsAt);
    }
    if (input.caster.player.movementState === 'locked' || input.caster.player.combatLockId !== null) {
      return rejected('SKILL_LOCKED_IN_COMBAT', `${input.caster.player.playerId} is locked in combat`);
    }
    if (input.target.targetType !== ability.worldTargetType) {
      return rejected('SKILL_INVALID_TARGET', `${ability.abilityId} requires ${ability.worldTargetType} target`);
    }

    const targetPosition = this.resolveTargetPosition(input, ability);
    if (!targetPosition.ok) {
      return targetPosition;
    }
    if (gridDistance(input.caster.player.position, targetPosition.value) > ability.worldRangeCells) {
      return rejected('SKILL_OUT_OF_RANGE', `${ability.abilityId} target is outside range ${ability.worldRangeCells}`);
    }
    if (input.caster.mana < ability.costMp) {
      return rejected('SKILL_INSUFFICIENT_MANA', `${ability.abilityId} requires ${ability.costMp} mana`);
    }

    const nextCooldownEndsAt = input.now + ability.worldCooldownMs;
    this.consumedClientTokens.add(input.clientToken);
    this.cooldowns.set(cooldownKey, nextCooldownEndsAt);
    return {
      ok: true,
      abilityId: ability.abilityId,
      cooldownEndsAt: nextCooldownEndsAt,
      pollutionApplied: ability.worldPollutionCost,
      manaApplied: ability.costMp,
      vfxId: ability.worldVfxId,
      broadcastScope: ability.worldBroadcastScope
    };
  }

  private isAbilityUnlocked(input: SkillCastInput, ability: SkillAbilityContract): boolean {
    return input.pathwayId === ability.pathwayId
      && input.caster.pathwayId === ability.pathwayId
      && input.sequence <= ability.sequence
      && input.caster.sequence <= ability.sequence;
  }

  private resolveEffectiveAbilityId(
    input: SkillCastInput
  ): { ok: true; value: string } | Extract<SkillValidationResult, { ok: false }> {
    if (!this.isCasterOutOfControl(input.caster)) {
      return { ok: true, value: input.abilityId };
    }

    const worldAbilityId = input.caster.outOfControl?.worldAbilityId;
    if (!worldAbilityId) {
      return rejected('SKILL_OUT_OF_CONTROL', `${input.caster.player.playerId} has no out-of-control world ability`);
    }
    return { ok: true, value: worldAbilityId };
  }

  private isCasterOutOfControl(caster: SkillCasterState): boolean {
    return caster.outOfControl?.active === true
      || (typeof caster.sanity === 'number' && caster.sanity <= 0);
  }

  private resolveTargetPosition(
    input: SkillCastInput,
    ability: SkillAbilityContract
  ): { ok: true; value: GridPosition } | Extract<SkillValidationResult, { ok: false }> {
    if (ability.worldTargetType === 'self' || ability.worldTargetType === 'none') {
      return { ok: true, value: input.caster.player.position };
    }
    if (ability.worldTargetType === 'ground_point') {
      if (!input.target.targetGroundPosition) {
        return rejected('SKILL_INVALID_TARGET', `${ability.abilityId} requires targetGroundPosition`);
      }
      return { ok: true, value: input.target.targetGroundPosition };
    }
    if (!input.target.targetEntityId) {
      return rejected('SKILL_INVALID_TARGET', `${ability.abilityId} requires targetEntityId`);
    }
    if (!input.targetEntity || input.targetEntity.entityId !== input.target.targetEntityId) {
      return rejected('SKILL_TARGET_NOT_FOUND', `${input.target.targetEntityId} is not available to the caster`);
    }
    return { ok: true, value: input.targetEntity.position };
  }

  private cooldownKey(playerId: string, abilityId: string): string {
    return `${playerId}:${abilityId}`;
  }
}

function rejected(code: SkillFailureCode, developerHint: string, cooldownEndsAt = 0): Extract<SkillValidationResult, { ok: false }> {
  return { ok: false, code, developerHint, cooldownEndsAt };
}
