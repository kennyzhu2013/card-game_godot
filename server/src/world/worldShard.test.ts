import { afterEach, describe, expect, it } from 'vitest';
import { ManualClock } from '../core/time.js';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import type { Storage } from '../storage/storage.js';
import { WorldShard } from './worldShard.js';
import type { SkillAbilityContract } from './skillValidator.js';
import type { SkillExecutionPlan } from './skillExecutor.js';
import type { ContentExtension, WorldEntity, WorldTemplate } from './types.js';

const shardsToDispose: WorldShard[] = [];

async function createShard(overrides: {
  extraEntities?: WorldEntity[];
  contentExtensions?: ContentExtension[];
} = {}) {
  const storage = createMemoryStorage();
  const baseTemplate = await storage.worldTemplates.load('m3-test');
  const template: WorldTemplate = overrides.extraEntities
    ? { ...baseTemplate, entities: [...baseTemplate.entities, ...overrides.extraEntities] }
    : baseTemplate;
  const wrappedStorage: Storage = overrides.extraEntities
    ? {
        ...storage,
        worldTemplates: {
          list: storage.worldTemplates.list.bind(storage.worldTemplates),
          load: async () => structuredClone(template)
        }
      }
    : storage;
  const clock = new ManualClock(1000);
  const shard = new WorldShard({
    shardId: 'm3-dev',
    template,
    contentExtensions: overrides.contentExtensions ?? template.contentExtensions,
    storage: wrappedStorage,
    clock,
    aoiRadiusCells: 3,
    maxMoveCellsPerSecond: 3
  });
  shardsToDispose.push(shard);
  return { shard, storage: wrappedStorage, clock };
}

async function createSkillShard(overrides: {
  skillAbilities?: SkillAbilityContract[];
  skillPlans?: SkillExecutionPlan[];
  skillBroadcastRadiusCells?: number;
  skillBroadcastThrottleMs?: number;
} = {}) {
  const storage = createMemoryStorage();
  const template = await storage.worldTemplates.load('m3-test');
  const clock = new ManualClock(1000);
  const abilities: SkillAbilityContract[] = overrides.skillAbilities ?? [
    {
      abilityId: 'tide_priestess__seq9__heal_basic',
      pathwayId: 'tide_priestess',
      sequence: 9,
      worldCastable: true,
      worldTargetType: 'entity_id',
      worldRangeCells: 4,
      worldCooldownMs: 8000,
      costMp: 8,
      worldPollutionCost: 1,
      worldVfxId: 'vfx_tide_heal_v1',
      worldBroadcastScope: 'aoi_visible'
    }
  ];
  const plans: SkillExecutionPlan[] = overrides.skillPlans ?? [
    {
      abilityId: 'tide_priestess__seq9__heal_basic',
      durationMs: 800,
      channelMs: 500,
      effects: [
        {
          effect: 'heal_target',
          targetType: 'entity_id',
          targetEntityId: 'tree-1',
          amount: 5
        }
      ]
    }
  ];
  const shard = new WorldShard({
    shardId: 'm3-dev',
    template,
    contentExtensions: template.contentExtensions,
    storage,
    clock,
    aoiRadiusCells: 3,
    maxMoveCellsPerSecond: 3,
    skillAbilities: abilities,
    skillPlans: plans,
    skillBroadcastRadiusCells: overrides.skillBroadcastRadiusCells,
    skillBroadcastThrottleMs: overrides.skillBroadcastThrottleMs
  });
  shardsToDispose.push(shard);
  return { shard, storage, clock };
}

async function createEventAoiShard() {
  const storage = createMemoryStorage();
  const template = await storage.worldTemplates.load('m3-test');
  const eventTemplate: WorldTemplate = {
    ...structuredClone(template),
    meta: {
      ...template.meta,
      recommendedAoiZoneId: 'tight'
    },
    aoiZones: [
      {
        zoneId: 'tight',
        playersRadiusCells: 3,
        entitiesRadiusCells: 3,
        combatLocksRadiusCells: 3,
        deltaMode: 'event'
      }
    ],
    defaultAoiZoneId: 'tight'
  };
  const clock = new ManualClock(1000);
  const shard = new WorldShard({
    shardId: 'm3-dev',
    template: eventTemplate,
    contentExtensions: eventTemplate.contentExtensions,
    storage,
    clock,
    aoiRadiusCells: 30,
    maxMoveCellsPerSecond: 3
  });
  shardsToDispose.push(shard);
  return { shard, storage, clock };
}

async function movePlayerNearWolf(shard: WorldShard) {
  await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
  const moved = await shard.movePlayer({
    playerId: 'player-1',
    seq: 1,
    from: { x: 2, y: 2 },
    to: { x: 10, y: 8 },
    startedAt: -5000
  });
  expect(moved).toMatchObject({ ok: true });
}

async function tickWolfIntoPrelude(shard: WorldShard, clock: ManualClock) {
  const alertTick = await shard.tickMonsters(clock.now());
  clock.advance(200);
  const chaseTick = await shard.tickMonsters(clock.now());
  clock.advance(200);
  const preludeTick = await shard.tickMonsters(clock.now());
  return { alertTick, chaseTick, preludeTick };
}

function createSelfSkill(scope: SkillAbilityContract['worldBroadcastScope'] = 'aoi_visible'): {
  ability: SkillAbilityContract;
  plan: SkillExecutionPlan;
} {
  const abilityId = scope === 'self_only'
    ? 'tide_priestess__seq9__detect_self'
    : 'tide_priestess__seq9__pulse_aoi';
  return {
    ability: {
      abilityId,
      pathwayId: 'tide_priestess',
      sequence: 9,
      worldCastable: true,
      worldTargetType: 'self',
      worldRangeCells: 0,
      worldCooldownMs: 0,
      costMp: 0,
      worldPollutionCost: 0,
      worldVfxId: 'vfx_tide_pulse_v1',
      worldBroadcastScope: scope
    },
    plan: {
      abilityId,
      durationMs: 120,
      effects: [
        {
          effect: 'narrate',
          targetType: 'self'
        }
      ]
    }
  };
}

function createSkillCastInput(
  shard: WorldShard,
  playerId: string,
  abilityId: string,
  now: number,
  clientToken: string
) {
  return {
    caster: {
      player: shard.createSnapshotFor(playerId).self,
      pathwayId: 'tide_priestess',
      sequence: 9,
      mana: 20
    },
    abilityId,
    pathwayId: 'tide_priestess',
    sequence: 9,
    target: {
      targetType: 'self' as const
    },
    now,
    clientToken
  };
}

afterEach(() => {
  while (shardsToDispose.length > 0) {
    shardsToDispose.pop()?.dispose();
  }
});

describe('WorldShard', () => {
  it('enters players at spawn and reuses stored player state', async () => {
    const { shard, storage } = await createShard();

    const first = await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await storage.playerStates.upsert({ ...first, position: { x: 10, y: 10 }, updatedAt: 1200 });
    const reused = await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    expect(first.position).toEqual({ x: 2, y: 2 });
    expect(reused.position).toEqual({ x: 10, y: 10 });
  });

  it('creates, patches, persists, and restores player progression outside world snapshots', async () => {
    const { shard, storage, clock } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const subscribed = shard.subscribeProgression('player-1');
    expect(subscribed).toMatchObject({
      ok: true,
      state: {
        playerId: 'player-1',
        level: 1,
        exp: 0,
        sequence: 9,
        sanity: 0,
        protocolVersion: 'v3'
      }
    });
    if (!subscribed.ok) {
      return;
    }
    expect(Object.prototype.hasOwnProperty.call(shard.createSnapshotFor('player-1'), 'progression')).toBe(false);

    clock.advance(1000);
    const patched = await shard.patchProgression({
      playerId: 'player-1',
      patch: { exp: 35, sanity: 100 },
      reason: 'quest_reward'
    });

    expect(patched).toMatchObject({
      ok: true,
      selfPatch: {
        reason: 'quest_reward',
        patch: {
          exp: 35,
          sanity: 100,
          isOutOfControl: true,
          identityVisibleInAoi: false
        }
      },
      state: {
        playerId: 'player-1',
        exp: 35,
        sanity: 100,
        isOutOfControl: true,
        identityVisibleInAoi: false
      }
    });
    if (!patched.ok) {
      return;
    }
    expect(patched.state.contentHash).not.toBe(subscribed.state.contentHash);
    expect(await storage.playerProgressionStates.get('player-1')).toMatchObject({
      exp: 35,
      sanity: 100,
      isOutOfControl: true
    });

    const left = await shard.leavePlayer('player-1');
    expect(left).toMatchObject({ playerId: 'player-1', exp: 35 });

    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    expect(shard.subscribeProgression('player-1')).toMatchObject({
      ok: true,
      state: {
        playerId: 'player-1',
        exp: 35,
        sanity: 100,
        isOutOfControl: true
      }
    });
  });

  it('reports AOI progression entered, changed, and left updates from authoritative shard state', async () => {
    const { shard, clock } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });

    expect(shard.consumeProgressionAoiUpdates('player-1')).toEqual({
      changed: [
        {
          playerId: 'player-2',
          projection: expect.objectContaining({
            playerId: 'player-2',
            level: 1,
            sequenceBadge: 'none',
            identityVisibleInAoi: true
          })
        }
      ],
      left: []
    });
    expect(shard.consumeProgressionAoiUpdates('player-1')).toEqual({ changed: [], left: [] });

    clock.advance(1000);
    const patched = await shard.patchProgression({
      playerId: 'player-2',
      patch: { level: 12, sequence: 3, sanity: 100 },
      reason: 'test_ooc_projection'
    });
    expect(patched).toMatchObject({ ok: true });

    expect(shard.consumeProgressionAoiUpdates('player-1')).toEqual({
      changed: [
        {
          playerId: 'player-2',
          projection: expect.objectContaining({
            playerId: 'player-2',
            level: 12,
            sequenceBadge: 'sequence_3',
            outOfControlAura: true,
            identityVisibleInAoi: false,
            aoiActorLabel: '狂暴的旅人'
          })
        }
      ],
      left: []
    });
    expect(shard.consumeProgressionAoiUpdates('player-2')).toEqual({
      changed: [
        {
          playerId: 'player-1',
          projection: expect.objectContaining({ playerId: 'player-1', level: 1 })
        }
      ],
      left: []
    });

    clock.advance(2000);
    const moved = await shard.movePlayer({
      playerId: 'player-2',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 10, y: 10 },
      startedAt: -2000
    });
    expect(moved).toMatchObject({ ok: true });

    expect(shard.consumeProgressionAoiUpdates('player-1')).toEqual({
      changed: [],
      left: ['player-2']
    });
  });

  it('creates AOI snapshots with self, visible players, nearby entities, and no far entities', async () => {
    const { shard } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });

    const snapshot = shard.createSnapshotFor('player-1');
    const visibleEntityIds = snapshot.entities.map((entity) => entity.entityId);

    expect(snapshot.self.playerId).toBe('player-1');
    expect(snapshot.players.map((player) => player.playerId)).toEqual(['player-2']);
    expect(visibleEntityIds).toEqual(expect.arrayContaining(['tree-1', 'crate-1']));
    expect(visibleEntityIds).not.toContain('ore-1');
    expect(visibleEntityIds).not.toContain('wolf-1');
    expect(snapshot).toMatchObject({
      templateHash: expect.any(String),
      defaultAoiZoneId: expect.any(String),
      projectionContract: expect.objectContaining({
        mapId: 'mist-harbor-test',
        coordinateSpace: 'm3-grid-to-godot-world',
        cellSize: 48,
        origin: expect.objectContaining({ x: 0, y: -96 })
      }),
      meta: expect.objectContaining({
        mapId: 'mist-harbor-test',
        templateHash: expect.any(String)
      }),
      regions: expect.any(Array),
      portals: expect.any(Array),
      aoiZones: expect.any(Array)
    });
  });

  it('materializes active monster spawns as server-visible entities for M2 projection compatibility', async () => {
    const { shard, storage } = await createShard();
    const template = await storage.worldTemplates.load('m3-test');
    expect(template.entities.map((entity) => entity.entityId)).not.toContain('wolf-1');

    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    const moved = await shard.movePlayer({
      playerId: 'player-1',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 8, y: 6 },
      startedAt: -3000
    });
    expect(moved).toMatchObject({ ok: true });

    const snapshot = shard.createSnapshotFor('player-1');
    const entitiesById = new Map(snapshot.entities.map((entity) => [entity.entityId, entity]));

    expect(entitiesById.get('wolf-1')).toMatchObject({
      entityId: 'wolf-1',
      type: 'monster',
      position: { x: 8, y: 8 },
      state: {
        spawnId: 'wolf-1',
        monsterId: 'fog_ooze',
        storyVisibleId: 'wolf-1',
        initialState: 'patrol',
        active: true,
        hostile: true
      },
      version: 1
    });
  });

  it('bubbles monster tick deltas, aggro events, preludes, and combat lock requests', async () => {
    const { shard, storage, clock } = await createShard();
    await movePlayerNearWolf(shard);

    const { alertTick, chaseTick, preludeTick } = await tickWolfIntoPrelude(shard, clock);
    const storedDeltas = await storage.worldDeltas.list('m3-dev');

    expect(alertTick.aggroEvents).toEqual([
      expect.objectContaining({
        monsterId: 'wolf-1',
        fromState: 'PATROL',
        toState: 'ALERT',
        towardsPlayerId: 'player-1'
      })
    ]);
    expect(chaseTick.aggroEvents).toEqual([
      expect.objectContaining({
        monsterId: 'wolf-1',
        fromState: 'ALERT',
        toState: 'CHASE',
        towardsPlayerId: 'player-1'
      })
    ]);
    expect(preludeTick.preludes).toEqual([
      expect.objectContaining({
        monsterId: 'wolf-1',
        monsterEntityIds: ['wolf-1'],
        targetPlayerId: 'player-1',
        leadTimeMs: 1500,
        escapeWindowMs: 1500
      })
    ]);
    expect(preludeTick.combatLockRequests).toEqual([
      expect.objectContaining({
        center: { x: 8, y: 8 },
        hostileEntityIds: ['wolf-1'],
        targetPlayerId: 'player-1'
      })
    ]);
    expect([...alertTick.deltas, ...chaseTick.deltas, ...preludeTick.deltas]).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          targetEntityId: 'wolf-1',
          type: 'state_changed',
          patch: expect.objectContaining({
            state: expect.objectContaining({ monsterState: 'ALERT' })
          })
        }),
        expect.objectContaining({
          targetEntityId: 'wolf-1',
          type: 'state_changed',
          patch: expect.objectContaining({
            state: expect.objectContaining({ monsterState: 'CHASE' })
          })
        })
      ])
    );
    expect(storedDeltas.map((delta) => delta.targetEntityId)).toEqual(expect.arrayContaining(['wolf-1']));
  });

  it('routes monster evade through the active prelude window', async () => {
    const { shard, clock } = await createShard();
    await movePlayerNearWolf(shard);
    await tickWolfIntoPrelude(shard, clock);

    const ack = shard.evadeMonster({
      playerId: 'player-1',
      monsterEntityId: 'wolf-1',
      evadeKind: 'stealth'
    });

    expect(ack).toEqual({ ok: true });
    expect(shard.createSnapshotFor('player-1').entities.find((entity) => entity.entityId === 'wolf-1')).toMatchObject({
      position: { x: 8, y: 8 },
      state: {
        monsterState: 'PATROL',
        hp: 70,
        pendingPrelude: false
      }
    });
  });

  it('applies monster victory outcome as entity removal and schedules respawn', async () => {
    const { shard, clock } = await createShard();
    await movePlayerNearWolf(shard);
    const lock = shard.createCombatLock({
      center: { x: 8, y: 8 },
      radius: 2,
      hostileEntityIds: ['wolf-1']
    });

    const removed = await shard.applyMonsterCombatOutcome(lock.lock.combatLockId, 'victory');

    expect(removed).toEqual([
      expect.objectContaining({
        targetEntityId: 'wolf-1',
        type: 'entity_removed',
        patch: expect.objectContaining({
          state: expect.objectContaining({ monsterState: 'DEAD', hp: 0 })
        })
      })
    ]);
    expect(shard.createSnapshotFor('player-1').entities.map((entity) => entity.entityId)).not.toContain('wolf-1');

    clock.advance(60000);
    const respawned = await shard.tickMonsters(clock.now());

    expect(respawned.deltas).toEqual([
      expect.objectContaining({
        targetEntityId: 'wolf-1',
        type: 'entity_spawned',
        patch: expect.objectContaining({
          monsterId: 'fog_ooze',
          hp: 70
        })
      })
    ]);
    expect(shard.createSnapshotFor('player-1').entities.find((entity) => entity.entityId === 'wolf-1')).toMatchObject({
      type: 'monster',
      state: {
        monsterId: 'fog_ooze',
        monsterState: 'PATROL',
        hp: 70
      }
    });
  });

  it('applies generic monster victory outcome when closing a combat lock', async () => {
    const { shard } = await createShard();
    await movePlayerNearWolf(shard);
    const lock = shard.createCombatLock({
      center: { x: 8, y: 8 },
      radius: 2,
      hostileEntityIds: ['wolf-1']
    });

    const closed = await shard.closeCombatLock(lock.lock.combatLockId, 'victory');

    expect(closed).toMatchObject({
      ok: true,
      lock: { state: 'closed' },
      delta: {
        targetEntityId: 'wolf-1',
        type: 'entity_removed'
      }
    });
    expect(shard.createSnapshotFor('player-1').self).toMatchObject({
      movementState: 'idle',
      combatLockId: null
    });
    expect(shard.createSnapshotFor('player-1').entities.map((entity) => entity.entityId)).not.toContain('wolf-1');
  });

  it('applies monster defeat outcome by leashing back and restoring max hp', async () => {
    const { shard } = await createShard();
    await movePlayerNearWolf(shard);
    const lock = shard.createCombatLock({
      center: { x: 8, y: 8 },
      radius: 2,
      hostileEntityIds: ['wolf-1']
    });

    const deltas = await shard.applyMonsterCombatOutcome(lock.lock.combatLockId, 'defeat');

    expect(deltas).toEqual([
      expect.objectContaining({
        targetEntityId: 'wolf-1',
        type: 'state_changed',
        patch: expect.objectContaining({
          position: { x: 8, y: 8 },
          state: expect.objectContaining({
            status: 'leashed_back',
            monsterState: 'PATROL',
            hp: 70,
            combatLockId: null
          })
        })
      })
    ]);
    expect(shard.createSnapshotFor('player-1').entities.find((entity) => entity.entityId === 'wolf-1')).toMatchObject({
      position: { x: 8, y: 8 },
      state: {
        status: 'leashed_back',
        monsterState: 'PATROL',
        hp: 70
      }
    });
  });

  it('reports inspectState content revision in sync with template metadata', async () => {
    const { shard, storage } = await createShard();
    const state = shard.inspectState();
    const template = await storage.worldTemplates.load('m3-test');

    expect(state).toMatchObject({
      shardId: 'm3-dev',
      mapId: 'mist-harbor-test',
      templateHash: template.templateHash,
      contentRevision: template.meta.contentRevision,
      playerCount: 0,
      entityCount: expect.any(Number),
      activeLockCount: 0,
      activeChannelCount: 0
    });
  });

  it('emits AOI leave deltas from the observer full-snapshot baseline in event mode', async () => {
    const { shard, clock } = await createEventAoiShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });

    expect(shard.createSnapshotFor('player-1').players.map((player) => player.playerId)).toEqual(['player-2']);

    clock.advance(2000);
    const moved = await shard.movePlayer({
      playerId: 'player-2',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 6, y: 2 },
      startedAt: -2000
    });
    expect(moved).toMatchObject({ ok: true });

    expect(shard.computeAoiDelta('player-1', 0)).toEqual([
      { type: 'player_leave', subjectId: 'player-2', position: { x: 6, y: 2 }, zoneId: 'tight', tick: expect.any(Number) }
    ]);
    expect(shard.computeAoiDelta('player-1', 0)).toEqual([]);
  });

  it('accepts valid movement and rejects blocked movement with corrections', async () => {
    const { shard, clock } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    clock.advance(400);
    const moved = await shard.movePlayer({
      playerId: 'player-1',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 3, y: 2 },
      startedAt: 1000
    });

    expect(moved).toMatchObject({ ok: true });
    if (moved.ok) {
      expect(moved.snapshot.self.position).toEqual({ x: 3, y: 2 });
    }

    clock.advance(2000);
    const correction = await shard.movePlayer({
      playerId: 'player-1',
      seq: 2,
      from: { x: 3, y: 2 },
      to: { x: 5, y: 5 },
      startedAt: 1400
    });

    expect(correction).toMatchObject({
      ok: false,
      correction: {
        playerId: 'player-1',
        reason: 'blocked',
        acceptedSeq: 1,
        authoritativePosition: { x: 3, y: 2 }
      }
    });
  });

  it('applies interactions, stores deltas, and returns interested player ids', async () => {
    const { shard } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });

    const result = await shard.interact({ playerId: 'player-1', entityId: 'tree-1', action: 'chop' });

    expect(result).toMatchObject({
      ok: true,
      delta: { version: 1, targetEntityId: 'tree-1', type: 'resource_depleted' },
      interestedPlayerIds: ['player-1', 'player-2']
    });
    expect(shard.createSnapshotFor('player-1').entities.find((entity) => entity.entityId === 'tree-1')?.state.depleted).toBe(true);
  });

  it('inspects entities without storing deltas', async () => {
    const { shard, storage } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const result = await shard.interact({ playerId: 'player-1', entityId: 'tree-1', action: 'inspect' });

    expect(result).toMatchObject({ ok: true, delta: null, interestedPlayerIds: ['player-1'] });
    expect(await storage.worldDeltas.list('m3-dev')).toEqual([]);
  });

  it('creates and closes combat locks while rejecting locked movement', async () => {
    const { shard, clock } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const lockResult = shard.createCombatLock({ center: { x: 2, y: 2 }, radius: 3 });
    expect(lockResult.lock.participantPlayerIds).toEqual(['player-1']);
    expect(shard.createSnapshotFor('player-1').self).toMatchObject({ movementState: 'locked', combatLockId: lockResult.lock.combatLockId });

    const rejectedMove = await shard.movePlayer({ playerId: 'player-1', seq: 1, from: { x: 2, y: 2 }, to: { x: 3, y: 2 }, startedAt: 1000 });
    expect(rejectedMove).toMatchObject({ ok: false, correction: { reason: 'locked' } });

    clock.advance(1000);
    const closeResult = await shard.closeCombatLock(lockResult.lock.combatLockId);
    expect(closeResult).toMatchObject({ ok: true, lock: { state: 'closed' }, unlockedPlayerIds: ['player-1'] });
    expect(shard.createSnapshotFor('player-1').self).toMatchObject({ movementState: 'idle', combatLockId: null });
  });

  it('rejects transfer out and interactions while the player is combat locked', async () => {
    const { shard } = await createShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    shard.createCombatLock({ center: { x: 2, y: 2 }, radius: 3 });

    await expect(shard.transferOut('player-1', 'handoff-test')).resolves.toEqual({
      ok: false,
      code: 'PLAYER_LOCKED',
      message: 'Player player-1 is locked by combat'
    });
    await expect(shard.interact({ playerId: 'player-1', entityId: 'tree-1', action: 'inspect' })).resolves.toMatchObject({
      ok: false,
      code: 'TARGET_LOCKED'
    });
  });

  it('backs a followup-check combat lock with a server-visible small threat target from injected content', async () => {
    const { shard } = await createShard(createShorelineFixture());
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const moved = await shard.movePlayer({
      playerId: 'player-1',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 4, y: 6 },
      startedAt: -2000
    });
    expect(moved.ok).toBe(true);

    const snapshot = shard.createSnapshotFor('player-1');
    const smallThreat = snapshot.entities.find((entity) => entity.entityId === 'test-hostile-1');
    expect(smallThreat).toMatchObject({
      type: 'npc',
      position: { x: 5, y: 6 },
      state: {
        storyRole: 'test_small_threat',
        encounterRole: 'followup_check',
        hostile: true
      }
    });

    const lockResult = shard.createCombatLock({ center: { x: 4, y: 6 }, radius: 2 });
    expect(lockResult.lock.participantPlayerIds).toEqual(['player-1']);
    expect(lockResult.lock.hostileEntityIds).toEqual(['test-hostile-1']);
    expect(shard.createSnapshotFor('player-1').self).toMatchObject({
      movementState: 'locked',
      combatLockId: lockResult.lock.combatLockId
    });
  });

  it('stores an injected small-threat scout route action as an AOI world delta', async () => {
    const { shard, storage } = await createShard(createShorelineFixture());
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const moved = await shard.movePlayer({
      playerId: 'player-1',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 4, y: 6 },
      startedAt: -2000
    });
    expect(moved.ok).toBe(true);

    const result = await shard.interact({
      playerId: 'player-1',
      entityId: 'test-hostile-1',
      action: 'scout'
    });

    expect(result).toMatchObject({
      ok: true,
      entity: {
        entityId: 'test-hostile-1',
        version: 2,
        state: {
          storyRole: 'test_small_threat',
          status: 'scouted',
          routeAction: 'test_small_threat_scouted',
          scoutedBy: 'player-1'
        }
      },
      delta: {
        targetEntityId: 'test-hostile-1',
        type: 'state_changed',
        patch: {
          state: {
            status: 'scouted',
            routeAction: 'test_small_threat_scouted',
            scoutedBy: 'player-1'
          },
          version: 2
        }
      },
      interestedPlayerIds: ['player-1']
    });
    expect(shard.createSnapshotFor('player-1').entities.find((entity) => entity.entityId === 'test-hostile-1')?.state.status).toBe('scouted');
    expect((await storage.worldDeltas.list('m3-dev')).map((delta) => delta.targetEntityId)).toEqual(['test-hostile-1']);
  });

  it('creates a combat lock from an injected small-threat combat_check route action', async () => {
    const { shard } = await createShard(createShorelineFixture());
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const moved = await shard.movePlayer({
      playerId: 'player-1',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 4, y: 6 },
      startedAt: -2000
    });
    expect(moved.ok).toBe(true);

    await shard.interact({
      playerId: 'player-1',
      entityId: 'test-hostile-1',
      action: 'scout'
    });
    const result = await shard.interact({
      playerId: 'player-1',
      entityId: 'test-hostile-1',
      action: 'combat_check'
    });

    expect(result).toMatchObject({
      ok: true,
      entity: {
        entityId: 'test-hostile-1',
        version: 3,
        state: {
          status: 'combat_check_locked',
          routePhase: 'combat_check',
          routeAction: 'test_small_threat_combat_check',
          combatCheckBy: 'player-1'
        }
      },
      delta: {
        targetEntityId: 'test-hostile-1',
        type: 'state_changed',
        patch: {
          state: {
            status: 'combat_check_locked',
            routePhase: 'combat_check',
            routeAction: 'test_small_threat_combat_check',
            combatCheckBy: 'player-1'
          },
          version: 3
        }
      },
      combatLock: {
        participantPlayerIds: ['player-1'],
        hostileEntityIds: ['test-hostile-1']
      },
      lockedPlayerIds: ['player-1']
    });
    expect(shard.createSnapshotFor('player-1').self).toMatchObject({
      movementState: 'locked',
      combatLockId: expect.any(String)
    });
  });

  it('advances injected small-threat aftermath when its combat check lock closes with victory', async () => {
    const { shard, storage } = await createShard(createShorelineFixture());
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const moved = await shard.movePlayer({
      playerId: 'player-1',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 4, y: 6 },
      startedAt: -2000
    });
    expect(moved.ok).toBe(true);

    await shard.interact({
      playerId: 'player-1',
      entityId: 'test-hostile-1',
      action: 'scout'
    });
    const combatCheck = await shard.interact({
      playerId: 'player-1',
      entityId: 'test-hostile-1',
      action: 'combat_check'
    });
    expect(combatCheck.ok).toBe(true);
    if (!combatCheck.ok || !combatCheck.combatLock) {
      return;
    }

    const closed = await shard.closeCombatLock(combatCheck.combatLock.combatLockId, 'victory');

    expect(closed).toMatchObject({
      ok: true,
      lock: { state: 'closed' },
      delta: {
        targetEntityId: 'test-hostile-1',
        type: 'state_changed',
        patch: {
          state: {
            status: 'pollution_read_ready',
            routePhase: 'pollution_read',
            routeAction: 'test_small_threat_pollution_read_ready',
            combatResult: 'victory'
          },
          version: 4
        }
      },
      interestedPlayerIds: ['player-1']
    });
    expect(shard.createSnapshotFor('player-1').entities.find((entity) => entity.entityId === 'test-hostile-1')?.state).toMatchObject({
      status: 'pollution_read_ready',
      routePhase: 'pollution_read',
      routeAction: 'test_small_threat_pollution_read_ready',
      combatResult: 'victory'
    });
    expect((await storage.worldDeltas.list('m3-dev')).map((delta) => delta.targetEntityId)).toEqual([
      'test-hostile-1',
      'test-hostile-1',
      'test-hostile-1'
    ]);
  });

  it('starts a channeling skill with immediate ack and resolves it when the timer elapses', async () => {
    const { shard, storage, clock } = await createSkillShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const snapshot = shard.createSnapshotFor('player-1');
    const targetEntity = snapshot.entities.find((entity) => entity.entityId === 'tree-1');
    expect(targetEntity).toBeDefined();
    if (!targetEntity) {
      return;
    }

    const cast = await shard.castSkill({
      caster: {
        player: {
          playerId: 'player-1',
          displayName: 'Player 1',
          position: { x: 2, y: 2 },
          facing: 'south',
          movementState: 'idle',
          combatLockId: null,
          lastMoveSeq: 1,
          updatedAt: 1000
        },
        pathwayId: 'tide_priestess',
        sequence: 9,
        mana: 20
      },
      abilityId: 'tide_priestess__seq9__heal_basic',
      pathwayId: 'tide_priestess',
      sequence: 9,
      target: {
        targetType: 'entity_id',
        targetEntityId: 'tree-1'
      },
      targetEntity,
      now: 1000,
      clientToken: 'cast-token-1'
    });

    expect(cast.ok).toBe(true);
    if (!cast.ok) {
      return;
    }
    expect(cast.ack).toMatchObject({
      ok: true,
      channelStartedAt: 1000,
      channelEndsAt: 1500
    });
    expect(cast.resolved).toBeNull();
    expect(cast.broadcast).toBeNull();
    expect(cast.deltas).toEqual([]);

    clock.advance(600);
    const ready = await shard.advanceSkillChannels(clock.now());
    expect(ready).toHaveLength(1);
    expect(ready[0]).toMatchObject({
      ok: true,
      ack: {
        channelStartedAt: 1000,
        channelEndsAt: 1500
      },
      resolved: {
        abilityId: 'tide_priestess__seq9__heal_basic',
        durationMs: 500
      }
    });
    expect((await storage.worldDeltas.list('m3-dev')).map((delta) => delta.targetEntityId)).toEqual(['tree-1']);
  });

  it('interrupts a channel when the player moves and reports the interruption on correction', async () => {
    const { shard, clock } = await createSkillShard();
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const targetEntity = shard.createSnapshotFor('player-1').entities.find((entity) => entity.entityId === 'tree-1');
    expect(targetEntity).toBeDefined();
    if (!targetEntity) {
      return;
    }

    await shard.castSkill({
      caster: {
        player: {
          playerId: 'player-1',
          displayName: 'Player 1',
          position: { x: 2, y: 2 },
          facing: 'south',
          movementState: 'idle',
          combatLockId: null,
          lastMoveSeq: 1,
          updatedAt: 1000
        },
        pathwayId: 'tide_priestess',
        sequence: 9,
        mana: 20
      },
      abilityId: 'tide_priestess__seq9__heal_basic',
      pathwayId: 'tide_priestess',
      sequence: 9,
      target: {
        targetType: 'entity_id',
        targetEntityId: 'tree-1'
      },
      targetEntity,
      now: 1000,
      clientToken: 'cast-token-2'
    });

    clock.advance(100);
    const moved = await shard.movePlayer({
      playerId: 'player-1',
      seq: 2,
      from: { x: 2, y: 2 },
      to: { x: 3, y: 2 },
      startedAt: 1000
    });

    expect(moved).toMatchObject({
      ok: false,
      correction: { reason: 'channel_interrupted' },
      interruptedSkill: {
        ok: false,
        ack: {
          reason: 'SKILL_CHANNEL_INTERRUPTED',
          channelStartedAt: 1000,
          channelEndsAt: 1500
        }
      }
    });
  });

  it('does not create AOI broadcast recipients for self-only skills', async () => {
    const selfSkill = createSelfSkill('self_only');
    const { shard, clock } = await createSkillShard({
      skillAbilities: [selfSkill.ability],
      skillPlans: [selfSkill.plan]
    });
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });

    const cast = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      selfSkill.ability.abilityId,
      clock.now(),
      'broadcast-token-1'
    ));

    expect(cast).toMatchObject({
      ok: true,
      broadcast: null,
      broadcastPlayerIds: []
    });
  });

  it('routes AOI-visible skill broadcasts only to players inside the caster skill radius', async () => {
    const aoiSkill = createSelfSkill('aoi_visible');
    const { shard, clock } = await createSkillShard({
      skillAbilities: [aoiSkill.ability],
      skillPlans: [aoiSkill.plan],
      skillBroadcastRadiusCells: 3
    });
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });
    await shard.enterPlayer({ playerId: 'player-3', displayName: 'Player 3' });
    await shard.movePlayer({ playerId: 'player-3', seq: 1, from: { x: 2, y: 2 }, to: { x: 20, y: 20 }, startedAt: -20000 });

    const cast = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      aoiSkill.ability.abilityId,
      clock.now(),
      'broadcast-token-2'
    ));

    expect(cast).toMatchObject({
      ok: true,
      broadcast: {
        abilityId: aoiSkill.ability.abilityId,
        scope: 'aoi_visible'
      },
      broadcastPlayerIds: ['player-2']
    });
  });

  it('aligns AOI-visible skill broadcast actor visibility with progression identity projection', async () => {
    const aoiSkill = createSelfSkill('aoi_visible');
    const { shard, clock } = await createSkillShard({
      skillAbilities: [aoiSkill.ability],
      skillPlans: [aoiSkill.plan],
      skillBroadcastRadiusCells: 3
    });
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });
    clock.advance(1000);
    const progression = await shard.patchProgression({
      playerId: 'player-1',
      patch: { sanity: 100 },
      reason: 'skill_broadcast_ooc_visibility'
    });

    const cast = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      aoiSkill.ability.abilityId,
      clock.now(),
      'broadcast-token-ooc'
    ));

    expect(progression).toMatchObject({
      ok: true,
      state: {
        identityVisibleInAoi: false,
        isOutOfControl: true
      }
    });
    expect(cast).toMatchObject({
      ok: true,
      broadcast: {
        abilityId: aoiSkill.ability.abilityId,
        scope: 'aoi_visible',
        actor_visible: false,
        actor_anonymized_label: progression.ok ? progression.state.aoiActorLabel : expect.any(String)
      },
      broadcastPlayerIds: ['player-2']
    });
  });

  it('throttles duplicate AOI-visible skill broadcasts for the same player and ability within 600ms', async () => {
    const aoiSkill = createSelfSkill('aoi_visible');
    const { shard, clock } = await createSkillShard({
      skillAbilities: [aoiSkill.ability],
      skillPlans: [aoiSkill.plan],
      skillBroadcastRadiusCells: 3,
      skillBroadcastThrottleMs: 600
    });
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });

    const first = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      aoiSkill.ability.abilityId,
      clock.now(),
      'broadcast-token-3'
    ));
    clock.advance(100);
    const second = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      aoiSkill.ability.abilityId,
      clock.now(),
      'broadcast-token-4'
    ));
    clock.advance(600);
    const third = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      aoiSkill.ability.abilityId,
      clock.now(),
      'broadcast-token-5'
    ));

    expect(first.broadcastPlayerIds).toEqual(['player-2']);
    expect(second.broadcast).toBeNull();
    expect(second.broadcastPlayerIds).toEqual([]);
    expect(third.broadcastPlayerIds).toEqual(['player-2']);
  });

  it('keeps failed combat-lock casts side-effect free for token, cooldown, broadcast, and deltas', async () => {
    const aoiSkill = createSelfSkill('aoi_visible');
    const { shard, clock } = await createSkillShard({
      skillAbilities: [aoiSkill.ability],
      skillPlans: [aoiSkill.plan],
      skillBroadcastRadiusCells: 3
    });
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await shard.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });
    shard.createCombatLock({ center: { x: 2, y: 2 }, radius: 1 });

    const locked = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      aoiSkill.ability.abilityId,
      clock.now(),
      'combat-lock-token'
    ));
    expect(locked).toMatchObject({
      ok: false,
      ack: {
        abilityId: null,
        reason: 'SKILL_LOCKED_IN_COMBAT',
        pollutionApplied: 0,
        manaApplied: 0
      },
      resolved: null,
      broadcast: null,
      broadcastPlayerIds: [],
      deltas: []
    });

    const lockId = shard.createSnapshotFor('player-1').self.combatLockId;
    expect(lockId).toBeTruthy();
    if (lockId) {
      await shard.closeCombatLock(lockId);
    }
    const retry = await shard.castSkill(createSkillCastInput(
      shard,
      'player-1',
      aoiSkill.ability.abilityId,
      clock.now(),
      'combat-lock-token'
    ));

    expect(retry).toMatchObject({
      ok: true,
      broadcastPlayerIds: ['player-2']
    });
  });
});

function createShorelineFixture(): { extraEntities: WorldEntity[]; contentExtensions: ContentExtension[] } {
  const extraEntities: WorldEntity[] = [
    {
      entityId: 'test-hostile-1',
      type: 'npc',
      position: { x: 5, y: 6 },
      state: {
        storyRole: 'test_small_threat',
        encounterRole: 'followup_check',
        hostile: true,
        status: 'waiting'
      },
      version: 1
    }
  ];
  const contentExtensions: ContentExtension[] = [
    {
      extensionId: 'test-hostile-scout',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'test-hostile-1',
          action: 'scout'
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'scouted',
            routeAction: 'test_small_threat_scouted',
            scoutedBy: '$actorPlayerId'
          }
        },
        {
          type: 'emit_delta',
          params: {
            type: 'state_changed'
          }
        }
      ]
    },
    {
      extensionId: 'test-hostile-combat-check',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'test-hostile-1',
          action: 'combat_check',
          preconditions: {
            status: 'scouted',
            routeAction: 'test_small_threat_scouted'
          }
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'combat_check_locked',
            routePhase: 'combat_check',
            routeAction: 'test_small_threat_combat_check',
            combatCheckBy: '$actorPlayerId'
          }
        },
        {
          type: 'emit_delta',
          params: {
            type: 'state_changed'
          }
        },
        {
          type: 'lock_combat',
          params: {
            combatLockId: 'test_small_threat_followup',
            radius: 2
          }
        }
      ]
    },
    {
      extensionId: 'test-hostile-combat-close',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'test-hostile-1',
          action: 'combat_close',
          preconditions: {
            status: 'combat_check_locked',
            routeAction: 'test_small_threat_combat_check',
            combatResult: 'victory'
          }
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'pollution_read_ready',
            routePhase: 'pollution_read',
            routeAction: 'test_small_threat_pollution_read_ready',
            combatResult: '$combatResult'
          }
        },
        {
          type: 'emit_delta',
          params: {
            type: 'state_changed'
          }
        }
      ]
    }
  ];
  return { extraEntities, contentExtensions };
}
