import { describe, expect, it } from 'vitest';
import { gridDistance } from './aoiSystem.js';
import { MonsterAiSystem, type MonsterAiConfig, type TransformationOracle } from './monsterAiSystem.js';
import type { MonsterRuntime } from './monsterRuntime.js';
import { MonsterTemplateRegistry } from './monsterTemplateRegistry.js';
import type { Direction, GridPosition, MonsterSpawn, PlayerWorldState } from './types.js';

describe('MonsterAiSystem', () => {
  it('keeps PATROL movement inside the configured patrol radius', () => {
    const system = createSystem();
    const anchor = { x: 10, y: 10 };
    let monsters = [system.spawn(createSpawn(anchor), 0)];
    const visited = new Set<string>();

    for (let now = 2_000; now <= 18_000; now += 2_000) {
      const result = system.tick(monsters, [], now);
      monsters = result.monsters;
      const monster = monsters[0];
      visited.add(`${monster.position.x},${monster.position.y}`);

      expect(monster.state).toBe('PATROL');
      expect(gridDistance(monster.position, anchor)).toBeLessThanOrEqual(3);
    }

    expect(visited.size).toBeGreaterThan(1);
  });

  it('raises threat and enters ALERT when a player is inside sense radius', () => {
    const system = createSystem({ threatGainPerTick: 40 });
    const monster = system.spawn(createSpawn({ x: 10, y: 10 }), 0);
    const player = createPlayer({ x: 12, y: 10 });

    const result = system.tick([monster], [player], 1_000);

    expect(result.monsters[0].state).toBe('ALERT');
    expect(result.monsters[0].threat.get(player.playerId)).toBe(40);
    expect(result.aggroEvents).toEqual([
      expect.objectContaining({
        monsterId: result.monsters[0].entityId,
        fromState: 'PATROL',
        toState: 'ALERT',
        threat: 40,
        towardsPlayerId: player.playerId
      })
    ]);
  });

  it('does not enter CHASE when transformed same-species immunity applies', () => {
    const transformedOracle: TransformationOracle = {
      isSameSpecies: (_player, template) => template.speciesId === 'ooze'
    };
    const system = createSystem({ threatGainPerTick: 100 }, transformedOracle);
    const monster = system.spawn(createSpawn({ x: 10, y: 10 }), 0);
    const player = createPlayer({ x: 12, y: 10 }, 'west', 'same-species-player');

    const result = system.tick([monster], [player], 1_000);

    expect(result.monsters[0].state).toBe('PATROL');
    expect(result.monsters[0].threat.get(player.playerId) ?? 0).toBe(0);
    expect(result.aggroEvents).toEqual([]);
  });

  it('emits combat lock request and prelude when CHASE reaches combat radius', () => {
    const system = createSystem();
    const player = createPlayer({ x: 11, y: 10 }, 'west');
    const monster = chasingMonster(system, player.playerId, { x: 10, y: 10 });

    const result = system.tick([monster], [player], 2_000);

    expect(result.monsters[0].state).toBe('CHASE');
    expect(result.combatLockRequests).toEqual([
      expect.objectContaining({
        center: { x: 10, y: 10 },
        hostileEntityIds: [monster.entityId]
      })
    ]);
    expect(result.preludes).toEqual([
      expect.objectContaining({
        monsterId: monster.entityId,
        monsterEntityIds: [monster.entityId],
        leadTimeMs: 1500,
        escapeWindowMs: 1500,
        targetPlayerId: player.playerId
      })
    ]);
  });

  it('accepts stealth evade during prelude and resets CHASE to PATROL', () => {
    const system = createSystem();
    const player = createPlayer({ x: 12, y: 10 }, 'east');
    const monster = chasingMonster(system, player.playerId, { x: 10, y: 10 });
    const tick = system.tick([monster], [player], 2_000);

    const result = system.attemptEvade(tick.monsters[0], player, {
      evadeKind: 'stealth',
      now: 2_500
    });

    expect(result.ack).toEqual(expect.objectContaining({ ok: true }));
    expect(result.monster.state).toBe('PATROL');
    expect(result.monster.threat.get(player.playerId) ?? 0).toBe(0);
    expect(result.monster.position).toEqual(result.monster.patrolAnchor);
  });

  it('rejects evade when the player is still facing the monster', () => {
    const system = createSystem();
    const player = createPlayer({ x: 12, y: 10 }, 'west');
    const monster = chasingMonster(system, player.playerId, { x: 10, y: 10 });
    const tick = system.tick([monster], [player], 2_000);

    const result = system.attemptEvade(tick.monsters[0], player, {
      evadeKind: 'stealth',
      now: 2_500
    });

    expect(result.ack).toEqual(expect.objectContaining({
      ok: false,
      code: 'NOT_ELIGIBLE'
    }));
    expect(result.monster.state).toBe('CHASE');
    expect(result.monster.threat.get(player.playerId)).toBe(80);
  });

  it('leashes CHASE monsters back to anchor outside leash radius', () => {
    const system = createSystem({ leashRadiusCells: 5 });
    const player = createPlayer({ x: 21, y: 10 }, 'west');
    const monster = chasingMonster(system, player.playerId, { x: 20, y: 10 });
    monster.patrolAnchor = { x: 10, y: 10 };

    const result = system.tick([monster], [player], 2_000);

    expect(result.monsters[0].state).toBe('PATROL');
    expect(result.monsters[0].position).toEqual({ x: 10, y: 10 });
    expect(result.monsters[0].threat.get(player.playerId) ?? 0).toBe(0);
    expect(result.aggroEvents).toEqual([
      expect.objectContaining({
        monsterId: monster.entityId,
        fromState: 'CHASE',
        toState: 'PATROL',
        threat: 0,
        towardsPlayerId: player.playerId
      })
    ]);
  });
});

function createSystem(
  overrides: Partial<MonsterAiConfig> = {},
  transformationOracle: TransformationOracle = { isSameSpecies: () => false }
): MonsterAiSystem {
  return new MonsterAiSystem({
    templates: new MonsterTemplateRegistry(),
    transformationOracle,
    config: {
      threatGainPerTick: 25,
      leashRadiusCells: 8,
      preludeLeadTimeMs: 1500,
      evadeWindowMs: 1500,
      ...overrides
    }
  });
}

function createSpawn(position: GridPosition): MonsterSpawn {
  return {
    spawnId: 'fog_ooze_spawn',
    monsterId: 'fog_ooze',
    position,
    active: true
  };
}

function chasingMonster(system: MonsterAiSystem, playerId: string, position: GridPosition): MonsterRuntime {
  const monster = system.spawn(createSpawn(position), 0);
  monster.state = 'CHASE';
  monster.position = { ...position };
  monster.facing = 'east';
  monster.threat.set(playerId, 80);
  return monster;
}

function createPlayer(position: GridPosition, facing: Direction = 'west', playerId = 'player-a'): PlayerWorldState {
  return {
    playerId,
    displayName: playerId,
    position,
    facing,
    movementState: 'idle',
    combatLockId: null,
    lastMoveSeq: 0,
    updatedAt: 0
  };
}
