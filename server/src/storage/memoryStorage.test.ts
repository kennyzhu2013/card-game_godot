import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { createMemoryStorage } from './memoryStorage.js';

describe('memory storage', () => {
  it('stores active sessions and recently disconnected sessions', async () => {
    const storage = createMemoryStorage();
    await storage.sessions.upsert({
      sessionId: 's1',
      socketId: 'socket-1',
      accountId: 'account-1',
      playerId: 'player-1',
      shardId: 'm3-dev',
      ip: '127.0.0.1',
      state: 'in_world',
      lastHeartbeatAt: 100,
      createdAt: 50
    });
    await storage.sessions.markDisconnected('s1', 200);

    expect(await storage.sessions.get('s1')).toMatchObject({ state: 'disconnected', disconnectedAt: 200 });
    expect(await storage.sessions.findRecentDisconnected('account-1', 'player-1', 1000, 250)).toMatchObject({ sessionId: 's1' });
    expect(await storage.sessions.findRecentDisconnected('account-1', 'player-1', 20, 250)).toBeUndefined();
  });

  it('stores player state by player id without exposing mutable references', async () => {
    const storage = createMemoryStorage();
    const state = {
      playerId: 'player-1',
      displayName: 'Player 1',
      position: { x: 2, y: 2 },
      facing: 'south' as const,
      movementState: 'idle' as const,
      combatLockId: null,
      lastMoveSeq: 1,
      updatedAt: 100
    };
    await storage.playerStates.upsert(state);
    state.position.x = 99;

    expect(await storage.playerStates.get('player-1')).toMatchObject({ position: { x: 2, y: 2 } });
  });

  it('stores player progression state by player id without exposing mutable references', async () => {
    const storage = createMemoryStorage();
    const state = {
      playerId: 'player-1',
      level: 1,
      exp: 25,
      expToNextLevel: 100,
      skillPoints: 0,
      pathway: 'unselected' as const,
      sequence: 9,
      sanity: 0,
      isOutOfControl: false,
      recoveryQuestId: null,
      transformationDepth: 0 as const,
      transformedSpecies: null,
      transformExpiresAt: null,
      speciesReputation: { slime: 2 },
      identityVisibleInAoi: true,
      aoiActorLabel: 'Player',
      aoiActorVariantId: 'player',
      protocolVersion: 'v3' as const,
      updatedAt: 100,
      contentHash: 'hash-1'
    };
    await storage.playerProgressionStates.upsert(state);
    state.speciesReputation.slime = 99;

    expect(await storage.playerProgressionStates.get('player-1')).toMatchObject({
      exp: 25,
      speciesReputation: { slime: 2 }
    });
  });

  it('loads the Mist Harbor test map template with M3-2 landmarks', async () => {
    const storage = createMemoryStorage();
    const template = await storage.worldTemplates.load('mist-harbor-test');
    const legacyAlias = await storage.worldTemplates.load('m3-test');
    const landmarks = (template as {
      landmarks?: Array<{ landmarkId: string; role: string; position: { x: number; y: number } }>;
    }).landmarks ?? [];

    expect(template).toMatchObject({
      mapId: 'mist-harbor-test',
      templateHash: 'mist-harbor-test-v1',
      spawn: { x: 2, y: 2 }
    });
    expect(legacyAlias.mapId).toBe('mist-harbor-test');
    expect(template.blocked).toEqual(expect.arrayContaining([{ x: 12, y: 2 }, { x: 12, y: 3 }]));
    expect(landmarks.map((landmark) => landmark.landmarkId)).toEqual([
      'village_gate',
      'main_street',
      'old_lighthouse_road',
      'shoreline',
      'forge',
      'ritual_pier',
      'creation_yard',
      'fog_tide_blockade'
    ]);
    expect(template.entities.map((entity) => entity.entityId)).toEqual(expect.arrayContaining(['tree-1', 'ore-1', 'crate-1']));
    expect(template.entities.map((entity) => entity.entityId)).not.toContain('wolf-1');
    expect(template.monsterSpawns).toEqual(expect.arrayContaining([
      expect.objectContaining({
        spawnId: 'wolf-1',
        monsterId: 'fog_ooze',
        position: { x: 8, y: 8 },
        active: true
      })
    ]));
  });

  it('loads the generic Mist Harbor template with only base entities and monster spawns', async () => {
    const storage = createMemoryStorage();
    const template = await storage.worldTemplates.load('mist-harbor-test');
    const entitiesById = new Map(template.entities.map((entity) => [entity.entityId, entity]));

    expect([...entitiesById.keys()]).toEqual(expect.arrayContaining([
      'tree-1',
      'ore-1',
      'crate-1'
    ]));
    expect([...entitiesById.keys()].filter((id) => id.startsWith('m2-'))).toEqual([]);
    expect([...entitiesById.keys()]).not.toContain('wolf-1');
    expect(template.monsterSpawns).toEqual(expect.arrayContaining([
      expect.objectContaining({
        spawnId: 'wolf-1',
        monsterId: 'fog_ooze',
        position: { x: 8, y: 8 },
        active: true,
        storyVisibleId: 'wolf-1'
      })
    ]));
    expect(entitiesById.get('tree-1')).toMatchObject({
      type: 'resource',
      position: { x: 4, y: 2 },
      state: { kind: 'tree', depleted: false }
    });
    expect(entitiesById.get('crate-1')).toMatchObject({
      type: 'prop',
      position: { x: 3, y: 4 },
      state: { pushable: true }
    });
  });

  it('appends world deltas in version order and replays after a version', async () => {
    const storage = createMemoryStorage();
    await storage.worldDeltas.append({ deltaId: 'd2', shardId: 'm3-dev', mapId: 'm3-test', actorPlayerId: 'p1', targetEntityId: 'tree-1', type: 'state_changed', patch: { depleted: true }, createdAt: 20, version: 2 });
    await storage.worldDeltas.append({ deltaId: 'd1', shardId: 'm3-dev', mapId: 'm3-test', actorPlayerId: 'p1', targetEntityId: 'ore-1', type: 'state_changed', patch: { depleted: true }, createdAt: 10, version: 1 });

    const deltas = await storage.worldDeltas.list('m3-dev');
    expect(deltas.map((delta) => delta.version)).toEqual([1, 2]);
    expect((await storage.worldDeltas.replay('m3-dev', 1)).map((delta) => delta.deltaId)).toEqual(['d2']);
  });
});

describe('memory storage map directory loader', () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = mkdtempSync(join(tmpdir(), 'maps-loader-'));
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  function writeTemplate(fileName: string, template: Record<string, unknown>): void {
    writeFileSync(join(tempDir, fileName), JSON.stringify(template));
  }

  function minimalTemplate(mapId: string): Record<string, unknown> {
    return {
      mapId,
      templateHash: `${mapId}-v1`,
      width: 4,
      height: 4,
      spawn: { x: 0, y: 0 },
      blocked: [],
      entities: []
    };
  }

  it('auto-loads every .json under the maps dir and lists them as canonical', async () => {
    writeTemplate('alpha.json', minimalTemplate('alpha-map'));
    writeTemplate('beta.json', minimalTemplate('beta-map'));

    const storage = createMemoryStorage({ mapsDir: tempDir });
    const list = await storage.worldTemplates.list();

    expect(list.map((tpl) => tpl.mapId).sort()).toEqual(['alpha-map', 'beta-map']);
    expect((await storage.worldTemplates.load('alpha-map')).templateHash).toBe('alpha-map-v1');
  });

  it('throws when the maps dir is empty', () => {
    expect(() => createMemoryStorage({ mapsDir: tempDir })).toThrowError(/MAP_TEMPLATES_DIR_EMPTY/);
  });

  it('throws when a map template lacks mapId', () => {
    writeTemplate('bad.json', { templateHash: 'bad-v1' } as Record<string, unknown>);
    expect(() => createMemoryStorage({ mapsDir: tempDir })).toThrowError(/MAP_TEMPLATE_MISSING_MAP_ID/);
  });

  it('throws when two files declare the same mapId', () => {
    writeTemplate('one.json', minimalTemplate('dup-map'));
    writeTemplate('two.json', minimalTemplate('dup-map'));
    expect(() => createMemoryStorage({ mapsDir: tempDir })).toThrowError(/MAP_TEMPLATE_DUPLICATE_MAP_ID/);
  });

  it('wires legacy m3-test alias only when mist-harbor-test is present', async () => {
    writeTemplate('only-other.json', minimalTemplate('other-map'));
    const storage = createMemoryStorage({ mapsDir: tempDir });
    await expect(storage.worldTemplates.load('m3-test')).rejects.toThrowError(/UNKNOWN_WORLD_TEMPLATE/);
  });
});
