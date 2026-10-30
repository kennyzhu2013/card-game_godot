import { describe, expect, it } from 'vitest';
import { SkillExecutor, type SkillExecutionPlan } from './skillExecutor.js';
import type { SkillValidationResult } from './skillValidator.js';
import type { PlayerWorldState, WorldEntity } from './types.js';

const caster: PlayerWorldState = {
  playerId: 'caster-1',
  displayName: 'Caster',
  position: { x: 2, y: 2 },
  facing: 'south',
  movementState: 'idle',
  combatLockId: null,
  lastMoveSeq: 1,
  updatedAt: 1000
};

const ally: WorldEntity = {
  entityId: 'ally-1',
  type: 'npc',
  position: { x: 3, y: 2 },
  state: { hp: 10, maxHp: 20 },
  version: 1
};

const validated: Extract<SkillValidationResult, { ok: true }> = {
  ok: true,
  abilityId: 'tide_priestess__seq9__heal_basic',
  cooldownEndsAt: 9000,
  pollutionApplied: 1,
  manaApplied: 8,
  vfxId: 'vfx_tide_heal_v1',
  broadcastScope: 'aoi_visible'
};

const healPlan: SkillExecutionPlan = {
  abilityId: validated.abilityId,
  durationMs: 800,
  effects: [
    {
      effect: 'heal_target',
      targetType: 'entity_id',
      amount: 6,
      targetEntityId: ally.entityId
    }
  ]
};

describe('SkillExecutor', () => {
  it('returns failure ack without mana, pollution, deltas, or broadcast when validation fails', () => {
    const executor = new SkillExecutor([healPlan]);
    const failed: Extract<SkillValidationResult, { ok: false }> = {
      ok: false,
      code: 'SKILL_OUT_OF_RANGE',
      developerHint: 'too far',
      cooldownEndsAt: 0
    };

    const result = executor.execute({
      caster,
      validation: failed,
      targetEntity: ally,
      targetGroundPosition: undefined,
      clientToken: 'token-1',
      appliedAt: 1000
    });

    expect(result).toMatchObject({
      ok: false,
      ack: {
        ok: false,
        abilityId: null,
        clientToken: 'token-1',
        reason: 'SKILL_OUT_OF_RANGE',
        cooldownEndsAt: 0,
        pollutionApplied: 0,
        manaApplied: 0
      },
      resolved: null,
      broadcast: null,
      deltas: []
    });
  });

  it('applies an allowed plan effect into state delta, resolved payload, and AOI broadcast payload', () => {
    const executor = new SkillExecutor([healPlan]);

    const result = executor.execute({
      caster,
      validation: validated,
      targetEntity: ally,
      targetGroundPosition: undefined,
      clientToken: 'token-1',
      appliedAt: 1000
    });

    expect(result.ok).toBe(true);
    expect(result.ack).toMatchObject({
      abilityId: validated.abilityId,
      clientToken: 'token-1',
      ok: true,
      cooldownEndsAt: 9000,
      pollutionApplied: 1,
      manaApplied: 8
    });
    expect(result.deltas).toEqual([
      {
        targetEntityId: ally.entityId,
        type: 'state_changed',
        patch: {
          state: { hp: 16 },
          version: 2
        }
      }
    ]);
    expect(result.resolved).toMatchObject({
      abilityId: validated.abilityId,
      casterPlayerId: caster.playerId,
      appliedAt: 1000,
      vfxId: 'vfx_tide_heal_v1',
      durationMs: 800,
      targets: [
        {
          targetEntityId: ally.entityId,
          effect: 'healed',
          amount: 6,
          newState: { hp: 16 }
        }
      ]
    });
    expect(result.broadcast).toMatchObject({
      abilityId: validated.abilityId,
      casterPlayerId: caster.playerId,
      casterPosition: caster.position,
      vfxId: 'vfx_tide_heal_v1',
      scope: 'aoi_visible',
      targetSummary: { entityIds: [ally.entityId] },
      appliedAt: 1000,
      durationMs: 800
    });
  });

  it('rejects unsupported plan effects without charging mana or pollution', () => {
    const executor = new SkillExecutor([{
      ...healPlan,
      effects: [{ effect: 'advance_sequence', targetType: 'self' }]
    }]);

    const result = executor.execute({
      caster,
      validation: validated,
      targetEntity: ally,
      targetGroundPosition: undefined,
      clientToken: 'token-1',
      appliedAt: 1000
    });

    expect(result).toMatchObject({
      ok: false,
      ack: {
        ok: false,
        reason: 'SKILL_VALIDATION_FAILED',
        pollutionApplied: 0,
        manaApplied: 0
      },
      resolved: null,
      broadcast: null,
      deltas: []
    });
  });
});
