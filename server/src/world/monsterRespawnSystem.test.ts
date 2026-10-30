import { describe, expect, it } from 'vitest';
import { gridDistance } from './aoiSystem.js';
import { MonsterRespawnSystem } from './monsterRespawnSystem.js';
import { MonsterTemplateRegistry } from './monsterTemplateRegistry.js';
import type { GridPosition, MonsterSpawn, MonsterTemplate } from './types.js';

describe('MonsterRespawnSystem', () => {
  it('waits for respawn timer before emitting entity_spawned within scatter radius', () => {
    const template = createTemplate({
      respawn: {
        timerMs: 60_000,
        scatterRadiusCells: 2,
        weeklyOnlyOnReset: false
      }
    });
    const system = createSystem([template]);
    const spawn = createSpawn({ x: 10, y: 10 });

    system.schedule(spawn, 1_000);

    expect(system.tick(60_999)).toEqual([]);

    const [respawn] = system.tick(61_000);

    expect(respawn.spawn).toEqual(spawn);
    expect(respawn.runtime.spawnId).toBe(spawn.spawnId);
    expect(respawn.runtime.templateId).toBe(spawn.monsterId);
    expect(respawn.runtime.state).toBe('PATROL');
    expect(respawn.runtime.hp).toBe(template.stats.maxHp);
    expect(gridDistance(respawn.runtime.position, spawn.position)).toBeLessThanOrEqual(2);
    expect(respawn.delta).toMatchObject({
      shardId: 'm3-dev',
      mapId: 'mist-harbor-test',
      actorPlayerId: 'system',
      targetEntityId: respawn.runtime.entityId,
      type: 'entity_spawned',
      patch: {
        spawnId: spawn.spawnId,
        monsterId: spawn.monsterId,
        state: 'PATROL',
        position: respawn.runtime.position
      },
      createdAt: 61_000
    });

    expect(system.tick(62_000)).toEqual([]);
  });

  it('keeps weekly-only respawns pending until weeklyReset is triggered', () => {
    const template = createTemplate({
      respawn: {
        timerMs: 1,
        scatterRadiusCells: 1,
        weeklyOnlyOnReset: true
      }
    });
    const system = createSystem([template]);
    const spawn = createSpawn({ x: 6, y: 4 });

    system.schedule(spawn, 0);

    expect(system.tick(120_000)).toEqual([]);

    const [respawn] = system.weeklyReset(120_000);

    expect(respawn.runtime.spawnId).toBe(spawn.spawnId);
    expect(respawn.runtime.state).toBe('PATROL');
    expect(gridDistance(respawn.runtime.position, spawn.position)).toBeLessThanOrEqual(1);
    expect(respawn.delta).toMatchObject({
      type: 'entity_spawned',
      targetEntityId: respawn.runtime.entityId,
      createdAt: 120_000
    });
    expect(system.weeklyReset(121_000)).toEqual([]);
  });
});

function createSystem(templates: MonsterTemplate[]): MonsterRespawnSystem {
  return new MonsterRespawnSystem({
    templates: new MonsterTemplateRegistry(templates),
    shardId: 'm3-dev',
    mapId: 'mist-harbor-test'
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

function createTemplate(overrides: Partial<MonsterTemplate>): MonsterTemplate {
  const template = new MonsterTemplateRegistry().loadSync('fog_ooze');
  return {
    ...template,
    ...overrides,
    stats: {
      ...template.stats,
      ...overrides.stats
    },
    respawn: {
      ...template.respawn,
      ...overrides.respawn
    }
  };
}
