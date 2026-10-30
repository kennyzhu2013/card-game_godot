import { describe, expect, it } from 'vitest';
import { SkillValidator, type SkillAbilityContract, type SkillCastInput } from './skillValidator.js';
import type { PlayerWorldState, WorldEntity } from './types.js';

const player: PlayerWorldState = {
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
  position: { x: 4, y: 2 },
  state: { friendly: true },
  version: 1
};

const healAbility: SkillAbilityContract = {
  abilityId: 'tide_priestess__seq9__heal_basic',
  pathwayId: 'tide_priestess',
  sequence: 9,
  worldCastable: true,
  worldTargetType: 'ally',
  worldRangeCells: 4,
  worldCooldownMs: 8000,
  costMp: 8,
  worldPollutionCost: 1,
  worldVfxId: 'vfx_tide_heal_v1',
  worldBroadcastScope: 'aoi_visible'
};

function castInput(overrides: Partial<SkillCastInput> = {}): SkillCastInput {
  return {
    caster: {
      player,
      pathwayId: 'tide_priestess',
      sequence: 9,
      mana: 20
    },
    abilityId: healAbility.abilityId,
    pathwayId: 'tide_priestess',
    sequence: 9,
    target: {
      targetType: 'ally',
      targetEntityId: ally.entityId
    },
    targetEntity: ally,
    now: 1000,
    clientToken: 'token-1',
    ...overrides
  };
}

describe('SkillValidator', () => {
  it('accepts an unlocked world-castable skill and records token plus cooldown on success', () => {
    const validator = new SkillValidator([healAbility]);

    const result = validator.validateCast(castInput());

    expect(result).toMatchObject({
      ok: true,
      abilityId: healAbility.abilityId,
      cooldownEndsAt: 9000,
      pollutionApplied: 1,
      manaApplied: 8
    });
    expect(validator.validateCast(castInput({ clientToken: 'token-1' }))).toMatchObject({
      ok: false,
      code: 'SKILL_CONTRACT_MISMATCH'
    });
    expect(validator.validateCast(castInput({ clientToken: 'token-2', now: 1100 }))).toMatchObject({
      ok: false,
      code: 'SKILL_COOLDOWN'
    });
  });

  it('rejects locked pathway or non-world-castable abilities before target checks', () => {
    const combatOnly: SkillAbilityContract = {
      ...healAbility,
      abilityId: 'tide_priestess__seq9__combat_only',
      worldCastable: false
    };
    const validator = new SkillValidator([healAbility, combatOnly]);

    expect(validator.validateCast(castInput({ caster: { player, pathwayId: 'ashen', sequence: 9, mana: 20 } }))).toMatchObject({
      ok: false,
      code: 'SKILL_PATHWAY_LOCKED'
    });
    expect(validator.validateCast(castInput({
      abilityId: combatOnly.abilityId,
      target: { targetType: 'enemy', targetEntityId: 'missing-monster' },
      targetEntity: undefined
    }))).toMatchObject({
      ok: false,
      code: 'SKILL_NOT_WORLD_CASTABLE'
    });
  });

  it('applies rate limit and clientToken replay checks before pathway validation', () => {
    const validator = new SkillValidator([healAbility]);

    expect(validator.validateCast(castInput({
      abilityId: 'missing__seq9__skill',
      pathwayId: 'missing',
      clientToken: 'rate-limited-token',
      rateLimit: { ok: false, resetMs: 450 }
    }))).toMatchObject({
      ok: false,
      code: 'SKILL_RATE_LIMITED',
      cooldownEndsAt: 1450
    });

    expect(validator.validateCast(castInput())).toMatchObject({ ok: true });
    expect(validator.validateCast(castInput({
      abilityId: 'missing__seq9__skill',
      pathwayId: 'missing',
      clientToken: 'token-1'
    }))).toMatchObject({
      ok: false,
      code: 'SKILL_CONTRACT_MISMATCH'
    });
  });

  it('allows advanced sequence players to cast lower-sequence world abilities', () => {
    const validator = new SkillValidator([healAbility]);

    expect(validator.validateCast(castInput({
      caster: { player, pathwayId: 'tide_priestess', sequence: 8, mana: 20 },
      sequence: 8
    }))).toMatchObject({
      ok: true,
      abilityId: healAbility.abilityId
    });
  });

  it('remaps out-of-control casts to the configured OOC world ability', () => {
    const oocAbility: SkillAbilityContract = {
      ...healAbility,
      abilityId: 'tide_priestess__seq9__ooc_surge',
      costMp: 0,
      worldPollutionCost: 2,
      worldVfxId: 'vfx_tide_ooc_surge_v1'
    };
    const validator = new SkillValidator([healAbility, oocAbility]);

    const result = validator.validateCast(castInput({
      caster: {
        player,
        pathwayId: 'tide_priestess',
        sequence: 9,
        mana: 20,
        sanity: 0,
        outOfControl: { active: true, worldAbilityId: oocAbility.abilityId }
      },
      clientToken: 'ooc-token-1'
    }));

    expect(result).toMatchObject({
      ok: true,
      abilityId: oocAbility.abilityId,
      pollutionApplied: 2,
      manaApplied: 0,
      vfxId: 'vfx_tide_ooc_surge_v1'
    });
  });

  it('rejects out-of-control casts when no OOC world ability is available', () => {
    const validator = new SkillValidator([healAbility]);

    expect(validator.validateCast(castInput({
      caster: {
        player,
        pathwayId: 'tide_priestess',
        sequence: 9,
        mana: 20,
        sanity: 0,
        outOfControl: { active: true }
      },
      clientToken: 'ooc-token-2'
    }))).toMatchObject({
      ok: false,
      code: 'SKILL_OUT_OF_CONTROL',
      cooldownEndsAt: 0
    });
  });

  it('rejects combat locks, wrong target type, missing targets, range, and mana failures with SKILL codes', () => {
    const validator = new SkillValidator([healAbility]);

    expect(validator.validateCast(castInput({
      caster: { player: { ...player, movementState: 'locked', combatLockId: 'lock-1' }, pathwayId: 'tide_priestess', sequence: 9, mana: 20 }
    }))).toMatchObject({ ok: false, code: 'SKILL_LOCKED_IN_COMBAT' });
    expect(validator.validateCast(castInput({ target: { targetType: 'enemy', targetEntityId: ally.entityId } }))).toMatchObject({
      ok: false,
      code: 'SKILL_INVALID_TARGET'
    });
    expect(validator.validateCast(castInput({ targetEntity: undefined }))).toMatchObject({
      ok: false,
      code: 'SKILL_TARGET_NOT_FOUND'
    });
    expect(validator.validateCast(castInput({ targetEntity: { ...ally, position: { x: 20, y: 20 } } }))).toMatchObject({
      ok: false,
      code: 'SKILL_OUT_OF_RANGE'
    });
    expect(validator.validateCast(castInput({ caster: { player, pathwayId: 'tide_priestess', sequence: 9, mana: 1 } }))).toMatchObject({
      ok: false,
      code: 'SKILL_INSUFFICIENT_MANA'
    });
  });
});
