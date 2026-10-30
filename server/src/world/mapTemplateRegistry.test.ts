import { describe, expect, it } from 'vitest';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import type { Storage } from '../storage/storage.js';
import type { WorldTemplate } from './types.js';
import { MapTemplateRegistry } from './mapTemplateRegistry.js';

describe('MapTemplateRegistry', () => {
  it('lists the canonical Mist Harbor template and validates its hash', async () => {
    const registry = new MapTemplateRegistry(createMemoryStorage());

    const maps = await registry.list();
    expect(maps.map((map) => map.mapId)).toEqual(['mist-harbor-test']);

    const template = await registry.load('mist-harbor-test');
    expect(template.mapId).toBe('mist-harbor-test');
    expect(registry.hash(template)).toBe(template.templateHash);
    expect(() => registry.validate(template)).not.toThrow();
    expect(template.meta).toMatchObject({
      mapId: 'mist-harbor-test',
      templateHash: registry.hash(template),
      displayName: 'Mist Harbor Test',
      layers: ['surface'],
      defaultLayer: 'surface',
      recommendedAoiZoneId: 'default',
      contentRevision: 2,
      serverVisibleIdNamespace: ''
    });
    expect(template.regions).toEqual([]);
    expect(template.portals).toEqual([]);
    expect(template.defaultAoiZoneId).toBe('default');
    expect(template.aoiZones).toEqual([
      {
        zoneId: 'default',
        playersRadiusCells: 30,
        entitiesRadiusCells: 30,
        combatLocksRadiusCells: 6,
        deltaMode: 'full'
      }
    ]);
    expect(template.monsterSpawns).toEqual([
      {
        spawnId: 'wolf-1',
        monsterId: 'fog_ooze',
        position: { x: 8, y: 8 },
        initialState: 'patrol',
        active: true,
        storyVisibleId: 'wolf-1'
      }
    ]);
    expect(template.entities.map((entity) => entity.entityId)).not.toContain('wolf-1');
    expect(template.entities.map((entity) => entity.entityId)).toEqual(
      expect.arrayContaining(['tree-1', 'ore-1', 'crate-1'])
    );
    expect(maps[0]).toMatchObject({
      mapId: 'mist-harbor-test',
      templateHash: registry.hash(template),
      displayName: 'Mist Harbor Test',
      layers: ['surface'],
      defaultLayer: 'surface',
      recommendedAoiZoneId: 'default'
    });
  });

  it('normalizes legacy templates with default meta, regions, portals, and AOI zones', async () => {
    const registry = new MapTemplateRegistry(createLegacyTemplateStorage({
      mapId: 'legacy-map',
      templateHash: 'legacy-map-v1',
      width: 12,
      height: 12,
      spawn: { x: 1, y: 1 },
      blocked: [],
      entities: []
    } as unknown as WorldTemplate));

    const template = await registry.load('legacy-map');

    expect(template.meta).toMatchObject({
      mapId: 'legacy-map',
      templateHash: 'legacy-map-v1',
      displayName: 'Legacy Map',
      layers: ['surface'],
      defaultLayer: 'surface',
      recommendedAoiZoneId: 'default',
      contentRevision: 1,
      serverVisibleIdNamespace: ''
    });
    expect(template.regions).toEqual([]);
    expect(template.portals).toEqual([]);
    expect(template.defaultAoiZoneId).toBe('default');
    expect(template.monsterSpawns).toEqual([]);
    expect(template.aoiZones).toEqual([
      {
        zoneId: 'default',
        playersRadiusCells: 30,
        entitiesRadiusCells: 30,
        combatLocksRadiusCells: 6,
        deltaMode: 'full'
      }
    ]);
  });

  it('rejects region schema errors during template validation', async () => {
    const registry = new MapTemplateRegistry(createLegacyTemplateStorage({
      mapId: 'legacy-map',
      templateHash: 'legacy-map-v1',
      width: 12,
      height: 12,
      spawn: { x: 1, y: 1 },
      blocked: [],
      entities: [],
      meta: {
        mapId: 'legacy-map',
        templateHash: 'legacy-map-v1',
        displayName: 'Legacy Map',
        layers: ['surface'],
        defaultLayer: 'surface',
        recommendedAoiZoneId: 'default',
        contentRevision: 1,
        serverVisibleIdNamespace: 'm2-'
      },
      regions: [
        {
          regionId: 'bad-region',
          name: 'Bad Region',
          layer: 'surface',
          bounds: { x: 11, y: 11, width: 4, height: 4 }
        }
      ],
      aoiZones: [
        {
          zoneId: 'default',
          playersRadiusCells: 30,
          entitiesRadiusCells: 30,
          combatLocksRadiusCells: 6,
          deltaMode: 'full'
        }
      ],
      defaultAoiZoneId: 'default'
    } as unknown as WorldTemplate));

    await expect(registry.load('legacy-map')).rejects.toThrow('INVALID_WORLD_TEMPLATE:legacy-map:out_of_bounds:region:bad-region');
  });

  it('rejects portal schema errors during template validation', async () => {
    const registry = new MapTemplateRegistry(createLegacyTemplateStorage({
      mapId: 'legacy-map',
      templateHash: 'legacy-map-v1',
      width: 12,
      height: 12,
      spawn: { x: 1, y: 1 },
      blocked: [],
      entities: [],
      meta: {
        mapId: 'legacy-map',
        templateHash: 'legacy-map-v1',
        displayName: 'Legacy Map',
        layers: ['surface'],
        defaultLayer: 'surface',
        recommendedAoiZoneId: 'default',
        contentRevision: 1,
        serverVisibleIdNamespace: 'm2-'
      },
      regions: [],
      portals: [
        {
          portalId: 'bad-portal',
          fromMapId: 'legacy-map',
          fromPosition: { x: 1, y: 1 },
          toMapId: 'legacy-map',
          toShardSelector: 'fixed',
          toPosition: { x: 2, y: 2 },
          toFacing: 'east',
          cooldownMs: 0,
          visibility: 'always'
        }
      ],
      aoiZones: [
        {
          zoneId: 'default',
          playersRadiusCells: 30,
          entitiesRadiusCells: 30,
          combatLocksRadiusCells: 6,
          deltaMode: 'full'
        }
      ],
      monsterSpawns: [],
      defaultAoiZoneId: 'default'
    } as WorldTemplate));

    await expect(registry.load('legacy-map')).rejects.toThrow('INVALID_WORLD_TEMPLATE:legacy-map:invalid_portal:bad-portal:cooldown');
  });

  it('rejects monster spawn schema errors during template validation', async () => {
    const outOfBoundsRegistry = new MapTemplateRegistry(createLegacyTemplateStorage(createLegacyTemplate({
      monsterSpawns: [
        {
          spawnId: 'bad-spawn',
          monsterId: 'fog_ooze',
          position: { x: 12, y: 1 },
          active: true
        }
      ]
    })));
    await expect(outOfBoundsRegistry.load('legacy-map')).rejects.toThrow('INVALID_WORLD_TEMPLATE:legacy-map:out_of_bounds:monster_spawn:bad-spawn');

    const duplicateRegistry = new MapTemplateRegistry(createLegacyTemplateStorage(createLegacyTemplate({
      monsterSpawns: [
        {
          spawnId: 'same-spawn',
          monsterId: 'fog_ooze',
          position: { x: 2, y: 2 },
          active: true
        },
        {
          spawnId: 'same-spawn',
          monsterId: 'fog_ooze',
          position: { x: 3, y: 2 },
          active: true
        }
      ]
    })));
    await expect(duplicateRegistry.load('legacy-map')).rejects.toThrow('INVALID_WORLD_TEMPLATE:legacy-map:duplicate_monster_spawn:same-spawn');

    const entityCollisionRegistry = new MapTemplateRegistry(createLegacyTemplateStorage(createLegacyTemplate({
      entities: [
        { entityId: 'tree-1', type: 'resource', position: { x: 2, y: 2 }, state: { kind: 'tree' }, version: 1 }
      ],
      monsterSpawns: [
        {
          spawnId: 'tree-1',
          monsterId: 'fog_ooze',
          position: { x: 3, y: 2 },
          active: true
        }
      ]
    })));
    await expect(entityCollisionRegistry.load('legacy-map')).rejects.toThrow('INVALID_WORLD_TEMPLATE:legacy-map:duplicate_world_subject:tree-1');
  });

  it('keeps the legacy m3-test map id as an alias without listing it as canonical', async () => {
    const registry = new MapTemplateRegistry(createMemoryStorage());

    const aliasTemplate = await registry.load('m3-test');
    expect(aliasTemplate.mapId).toBe('mist-harbor-test');
    expect((await registry.list()).map((map) => map.mapId)).not.toContain('m3-test');
  });

  it('throws the existing UNKNOWN_WORLD_TEMPLATE code for unknown map ids', async () => {
    const registry = new MapTemplateRegistry(createMemoryStorage());

    await expect(registry.load('missing-map')).rejects.toThrow('UNKNOWN_WORLD_TEMPLATE:missing-map');
  });
});

function createLegacyTemplate(overrides: Partial<WorldTemplate> & Record<string, unknown> = {}): WorldTemplate {
  return {
    mapId: 'legacy-map',
    templateHash: 'legacy-map-v1',
    width: 12,
    height: 12,
    spawn: { x: 1, y: 1 },
    blocked: [],
    entities: [],
    meta: {
      mapId: 'legacy-map',
      templateHash: 'legacy-map-v1',
      displayName: 'Legacy Map',
      layers: ['surface'],
      defaultLayer: 'surface',
      recommendedAoiZoneId: 'default',
      contentRevision: 1,
      serverVisibleIdNamespace: 'm2-'
    },
    regions: [],
    portals: [],
    aoiZones: [
      {
        zoneId: 'default',
        playersRadiusCells: 30,
        entitiesRadiusCells: 30,
        combatLocksRadiusCells: 6,
        deltaMode: 'full'
      }
    ],
    defaultAoiZoneId: 'default',
    ...overrides
  } as WorldTemplate;
}

function createLegacyTemplateStorage(template: WorldTemplate): Storage {
  const clone = structuredClone(template);
  return {
    sessions: {} as Storage['sessions'],
    playerStates: {} as Storage['playerStates'],
    playerProgressionStates: {} as Storage['playerProgressionStates'],
    worldTemplates: {
      async list(): Promise<WorldTemplate[]> {
        return [structuredClone(clone)];
      },
      async load(mapId: string): Promise<WorldTemplate> {
        if (mapId !== clone.mapId) {
          throw new Error(`UNKNOWN_WORLD_TEMPLATE:${mapId}`);
        }
        return structuredClone(clone);
      }
    },
    shardMetas: {} as Storage['shardMetas'],
    worldDeltas: {} as Storage['worldDeltas']
  } as Storage;
}
