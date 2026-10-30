import type { GridPosition, PlayerWorldState, WorldDelta, WorldEntity } from './types.js';
import type { SkillBroadcastScope, SkillFailureCode, SkillValidationResult } from './skillValidator.js';

export type SkillPlanEffectName =
  | 'heal_target'
  | 'heal_aoe'
  | 'shield_target'
  | 'buff_target'
  | 'dispel_target'
  | 'curse_target'
  | 'reveal_aoe'
  | 'divine_query'
  | 'movement_blink'
  | 'channel_aoe'
  | 'narrate';

export type SkillEffectResult =
  | 'healed'
  | 'shielded'
  | 'buffed'
  | 'cursed'
  | 'dispelled'
  | 'moved'
  | 'revealed';

export interface SkillPlanEffect {
  effect: string;
  targetType: 'self' | 'ally' | 'enemy' | 'ground_point' | 'entity_id' | 'none';
  targetEntityId?: string;
  targetGroundPosition?: GridPosition;
  amount?: number;
  newState?: Record<string, unknown>;
}

export interface SkillExecutionPlan {
  abilityId: string;
  durationMs: number;
  channelMs?: number;
  effects: SkillPlanEffect[];
}

export interface SkillExecutorInput {
  caster: PlayerWorldState;
  validation: SkillValidationResult;
  targetEntity?: WorldEntity;
  targetGroundPosition?: GridPosition;
  clientToken: string;
  appliedAt: number;
}

export interface SkillCastAckPayload {
  abilityId: string | null;
  clientToken: string;
  ok: boolean;
  reason?: SkillFailureCode;
  cooldownEndsAt: number;
  pollutionApplied: number;
  manaApplied: number;
  channelStartedAt?: number;
  channelEndsAt?: number;
}

export interface SkillTargetEffectPayload {
  targetEntityId?: string;
  targetPlayerId?: string;
  targetGroundPosition?: GridPosition;
  effect: SkillEffectResult;
  amount?: number;
  newState?: Record<string, unknown>;
}

export interface WorldSkillResolvedPayload {
  abilityId: string;
  casterPlayerId: string;
  targets: SkillTargetEffectPayload[];
  appliedAt: number;
  vfxId: string;
  durationMs: number;
}

export interface WorldSkillBroadcastPayload {
  abilityId: string;
  casterPlayerId: string;
  casterPosition: GridPosition;
  vfxId: string;
  scope: SkillBroadcastScope;
  actor_visible?: boolean;
  actor_anonymized_label?: string;
  targetSummary?: {
    entityIds?: string[];
    groundPosition?: GridPosition;
  };
  appliedAt: number;
  durationMs: number;
}

export type SkillExecutorDelta = Pick<WorldDelta, 'targetEntityId' | 'type' | 'patch'>;

export type SkillExecutorResult =
  | {
      ok: true;
      ack: SkillCastAckPayload;
      resolved: WorldSkillResolvedPayload;
      broadcast: WorldSkillBroadcastPayload | null;
      deltas: SkillExecutorDelta[];
    }
  | {
      ok: false;
      ack: SkillCastAckPayload;
      resolved: null;
      broadcast: null;
      deltas: [];
    };

const ALLOWED_WORLD_EFFECTS = new Set<SkillPlanEffectName>([
  'heal_target',
  'heal_aoe',
  'shield_target',
  'buff_target',
  'dispel_target',
  'curse_target',
  'reveal_aoe',
  'divine_query',
  'movement_blink',
  'channel_aoe',
  'narrate'
]);

export class SkillExecutor {
  private readonly plans = new Map<string, SkillExecutionPlan>();

  constructor(plans: SkillExecutionPlan[]) {
    for (const plan of plans) {
      this.plans.set(plan.abilityId, structuredClone(plan));
    }
  }

  getPlanDurationMs(abilityId: string): number {
    return this.plans.get(abilityId)?.durationMs ?? 0;
  }

  getPlanChannelMs(abilityId: string): number {
    return this.plans.get(abilityId)?.channelMs ?? 0;
  }

  execute(input: SkillExecutorInput): SkillExecutorResult {
    if (!input.validation.ok) {
      return rejected(input.clientToken, input.validation.code, input.validation.cooldownEndsAt);
    }

    const plan = this.plans.get(input.validation.abilityId);
    if (!plan || plan.effects.some((effect) => !ALLOWED_WORLD_EFFECTS.has(effect.effect as SkillPlanEffectName))) {
      return rejected(input.clientToken, 'SKILL_VALIDATION_FAILED', input.validation.cooldownEndsAt);
    }

    const effectResults: SkillTargetEffectPayload[] = [];
    const deltas: SkillExecutorDelta[] = [];

    for (const effect of plan.effects) {
      const applied = this.applyEffect(effect, input.targetEntity, input.targetGroundPosition);
      if (!applied.ok) {
        return rejected(input.clientToken, 'SKILL_VALIDATION_FAILED', input.validation.cooldownEndsAt);
      }
      if (applied.target) {
        effectResults.push(applied.target);
      }
      if (applied.delta) {
        deltas.push(applied.delta);
      }
    }

    const ack = acceptedAck(input.clientToken, input.validation);
    const resolved: WorldSkillResolvedPayload = {
      abilityId: input.validation.abilityId,
      casterPlayerId: input.caster.playerId,
      targets: effectResults,
      appliedAt: input.appliedAt,
      vfxId: input.validation.vfxId,
      durationMs: plan.durationMs
    };
    return {
      ok: true,
      ack,
      resolved,
      broadcast: input.validation.broadcastScope === 'self_only'
        ? null
        : this.buildBroadcast(input, plan, input.validation.broadcastScope),
      deltas
    };
  }

  private applyEffect(
    effect: SkillPlanEffect,
    targetEntity: WorldEntity | undefined,
    targetGroundPosition: GridPosition | undefined
  ): { ok: true; target?: SkillTargetEffectPayload; delta?: SkillExecutorDelta } | { ok: false } {
    if (effect.effect !== 'heal_target') {
      return { ok: true };
    }
    if (!targetEntity || effect.targetEntityId !== targetEntity.entityId) {
      return { ok: false };
    }
    const currentHp = numberOrDefault(targetEntity.state.hp, 0);
    const maxHp = numberOrDefault(targetEntity.state.maxHp, currentHp + numberOrDefault(effect.amount, 0));
    const amount = Math.max(0, numberOrDefault(effect.amount, 0));
    const hp = Math.min(maxHp, currentHp + amount);
    const state = { hp };
    return {
      ok: true,
      target: {
        targetEntityId: targetEntity.entityId,
        effect: 'healed',
        amount,
        newState: state
      },
      delta: {
        targetEntityId: targetEntity.entityId,
        type: 'state_changed',
        patch: {
          state,
          version: targetEntity.version + 1
        }
      }
    };
  }

  private buildBroadcast(
    input: SkillExecutorInput,
    plan: SkillExecutionPlan,
    scope: SkillBroadcastScope
  ): WorldSkillBroadcastPayload {
    const entityIds = plan.effects
      .map((effect) => effect.targetEntityId)
      .filter((entityId): entityId is string => typeof entityId === 'string' && entityId.length > 0);
    const groundPosition = input.targetGroundPosition ?? plan.effects.find((effect) => effect.targetGroundPosition)?.targetGroundPosition;
    const targetSummary = {
      ...(entityIds.length > 0 ? { entityIds } : {}),
      ...(groundPosition ? { groundPosition } : {})
    };
    return {
      abilityId: input.validation.ok ? input.validation.abilityId : '',
      casterPlayerId: input.caster.playerId,
      casterPosition: input.caster.position,
      vfxId: input.validation.ok ? input.validation.vfxId : '',
      scope,
      ...(Object.keys(targetSummary).length > 0 ? { targetSummary } : {}),
      appliedAt: input.appliedAt,
      durationMs: plan.durationMs
    };
  }
}

function acceptedAck(clientToken: string, validation: Extract<SkillValidationResult, { ok: true }>): SkillCastAckPayload {
  return {
    abilityId: validation.abilityId,
    clientToken,
    ok: true,
    cooldownEndsAt: validation.cooldownEndsAt,
    pollutionApplied: validation.pollutionApplied,
    manaApplied: validation.manaApplied
  };
}

function rejected(clientToken: string, reason: SkillFailureCode, cooldownEndsAt: number): Extract<SkillExecutorResult, { ok: false }> {
  return {
    ok: false,
    ack: {
      abilityId: null,
      clientToken,
      ok: false,
      reason,
      cooldownEndsAt,
      pollutionApplied: 0,
      manaApplied: 0
    },
    resolved: null,
    broadcast: null,
    deltas: []
  };
}

function numberOrDefault(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}
