import { describe, expect, it } from 'vitest';
import { MonsterPackRegistry } from './monsterPackRegistry.js';
import { MonsterTemplateRegistry } from './monsterTemplateRegistry.js';
import type { MonsterRuntime, MonsterRuntimeState } from './monsterRuntime.js';
import type { GridPosition, MonsterTemplate } from './types.js';

describe('MonsterPackRegistry', () => {
  it('raises guard allies inside call radius when a scout enters ALERT', () => {
    const registry = createRegistry({ maxConcurrentMembers: 3 });
    const scout = createRuntime('ooze-scout-a', 'fog_ooze_scout', { x: 10, y: 10 }, 'ALERT');
    const nearGuard = createRuntime('ooze-guard-near', 'fog_ooze_guard', { x: 14, y: 10 }, 'PATROL');
    const farGuard = createRuntime('ooze-guard-far', 'fog_ooze_guard', { x: 20, y: 10 }, 'PATROL');
    const otherScout = createRuntime('ooze-scout-b', 'fog_ooze_scout', { x: 12, y: 10 }, 'PATROL');
    registry.registerMany([scout, nearGuard, farGuard, otherScout]);

    const result = registry.callAllies(scout.entityId, 1_000);

    expect(stateOf(result, nearGuard.entityId)).toBe('ALERT');
    expect(memberOf(result, nearGuard.entityId).lastTransitionAt).toBe(1_000);
    expect(stateOf(result, farGuard.entityId)).toBe('PATROL');
    expect(stateOf(result, otherScout.entityId)).toBe('PATROL');
    expect(stateOf(result, scout.entityId)).toBe('ALERT');
  });

  it('demotes CHASE members beyond maxConcurrentMembers back to PATROL', () => {
    const registry = createRegistry({ maxConcurrentMembers: 2 });
    const first = createRuntime('ooze-guard-a', 'fog_ooze_guard', { x: 10, y: 10 }, 'CHASE', 100);
    const second = createRuntime('ooze-guard-b', 'fog_ooze_guard', { x: 11, y: 10 }, 'CHASE', 200);
    const extra = createRuntime('ooze-guard-c', 'fog_ooze_guard', { x: 12, y: 10 }, 'CHASE', 300);
    registry.registerMany([extra, second, first]);

    const result = registry.enforceMaxConcurrent('shoreline_ooze_pack', 2_000);

    expect(stateOf(result, first.entityId)).toBe('CHASE');
    expect(stateOf(result, second.entityId)).toBe('CHASE');
    expect(stateOf(result, extra.entityId)).toBe('PATROL');
    expect(memberOf(result, extra.entityId).lastTransitionAt).toBe(2_000);
  });
});

function createRegistry(overrides: Partial<MonsterTemplate['pack']> = {}): MonsterPackRegistry {
  return new MonsterPackRegistry({
    templates: new MonsterTemplateRegistry([
      createTemplate('fog_ooze_scout', 'scout', overrides),
      createTemplate('fog_ooze_guard', 'guard', overrides)
    ])
  });
}

function createTemplate(
  monsterId: string,
  role: MonsterTemplate['pack']['role'],
  overrides: Partial<MonsterTemplate['pack']>
): MonsterTemplate {
  const template = new MonsterTemplateRegistry().loadSync('fog_ooze');
  return {
    ...template,
    monsterId,
    templateHash: `${monsterId}-v1`,
    pack: {
      ...template.pack,
      role,
      ...overrides
    }
  };
}

function createRuntime(
  entityId: string,
  templateId: string,
  position: GridPosition,
  state: MonsterRuntimeState,
  lastTransitionAt = 0
): MonsterRuntime {
  return {
    entityId,
    spawnId: `${entityId}-spawn`,
    templateId,
    position,
    facing: 'south',
    state,
    hp: 70,
    threat: new Map(),
    patrolAnchor: { ...position },
    patrolTargetIndex: 0,
    lastTransitionAt,
    lastTickAt: lastTransitionAt,
    combatLockId: null,
    packMembers: [],
    pendingPrelude: null
  };
}

function stateOf(members: MonsterRuntime[], entityId: string): MonsterRuntimeState {
  return memberOf(members, entityId).state;
}

function memberOf(members: MonsterRuntime[], entityId: string): MonsterRuntime {
  const member = members.find((candidate) => candidate.entityId === entityId);
  expect(member).toBeDefined();
  return member as MonsterRuntime;
}
