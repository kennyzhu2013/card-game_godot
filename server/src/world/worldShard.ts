import type { Clock } from '../core/time.js';
import { CombatInstance } from '../combat/combatInstance.js';
import { CombatLockCoordinator } from '../combat/combatLockCoordinator.js';
import { CombatRouter, type CombatActionPayload, type CombatRouteResult } from '../combat/combatRouter.js';
import type { Storage } from '../storage/storage.js';
import { applyContentExtensions } from './contentExtensionRuntime.js';
import { AoiSystem, type AoiVisibility } from './aoiSystem.js';
import { DeltaLedger } from './deltaLedger.js';
import { InteractionSystem, type WorldInteractionAction } from './interactionSystem.js';
import {
  MonsterAiSystem,
  type MonsterAggroEvent,
  type MonsterCombatLockRequest,
  type MonsterCombatPrelude
} from './monsterAiSystem.js';
import { MonsterPackRegistry } from './monsterPackRegistry.js';
import { MonsterRespawnSystem } from './monsterRespawnSystem.js';
import { cloneMonsterRuntime, type MonsterRuntime } from './monsterRuntime.js';
import { MonsterTemplateRegistry } from './monsterTemplateRegistry.js';
import { MovementSystem, positionKey, type WorldMoveInput } from './movementSystem.js';
import { PlayerRegistry } from './playerRegistry.js';
import { ProgressionRegistry, type ProgressionPatch } from './progressionRegistry.js';
import { SkillExecutor, type SkillExecutionPlan, type SkillExecutorResult } from './skillExecutor.js';
import { SkillValidator, type SkillAbilityContract, type SkillCastInput, type SkillFailureCode } from './skillValidator.js';
import type {
  AoiVisibleProgression,
  AoiDeltaEvent,
  AoiZoneConfig,
  CombatLockZone,
  Direction,
  GridPosition,
  ContentExtension,
  MonsterSpawn,
  PlayerProgressionState,
  PlayerWorldState,
  WorldDelta,
  WorldEntity,
  WorldTemplate
} from './types.js';

export interface WorldShardOptions {
  shardId: string;
  template: WorldTemplate;
  storage: Storage;
  clock: Clock;
  aoiRadiusCells: number;
  maxMoveCellsPerSecond: number;
  combatLockRadiusCells?: number;
  contentExtensions?: ContentExtension[];
  skillAbilities?: SkillAbilityContract[];
  skillPlans?: SkillExecutionPlan[];
  skillBroadcastRadiusCells?: number;
  skillBroadcastThrottleMs?: number;
}

export interface EnterPlayerInput {
  playerId: string;
  displayName: string;
}

export interface TransferInInput {
  player: PlayerWorldState;
  handoffToken: string;
  toPosition: GridPosition;
  toFacing: Direction;
}

export type TransferOutResult =
  | { ok: true; handoffToken: string; snapshotAtExit: WorldSnapshotPayload }
  | { ok: false; code: 'PLAYER_NOT_IN_SHARD' | 'PLAYER_LOCKED'; message: string };

export interface WorldSnapshotPayload {
  shardId: string;
  mapId: string;
  templateHash: string;
  defaultAoiZoneId: string;
  tick: number;
  self: PlayerWorldState;
  players: PlayerWorldState[];
  entities: WorldEntity[];
  combatLocks: CombatLockZone[];
  projectionContract: WorldProjectionContract;
  meta: WorldTemplate['meta'];
  regions: WorldTemplate['regions'];
  portals: WorldTemplate['portals'];
  aoiZones: WorldTemplate['aoiZones'];
}

export interface WorldProjectionContract {
  mapId: string;
  coordinateSpace: 'm3-grid-to-godot-world';
  origin: { x: number; y: number };
  originText: string;
  cellSize: number;
  gridAxis: { x: 'east' | 'west'; y: 'north' | 'south' };
  worldAxis: { x: 'right' | 'left'; y: 'down' | 'up' };
}

export interface WorldCorrectionPayload {
  playerId: string;
  acceptedSeq: number;
  authoritativePosition: { x: number; y: number };
  reason: string;
}

export type MovePlayerResult =
  | { ok: true; snapshot: WorldSnapshotPayload }
  | { ok: false; correction: WorldCorrectionPayload; interruptedSkill?: SkillCastResult | null };

export interface WorldInteractInput {
  playerId: string;
  entityId: string;
  action: WorldInteractionAction;
}

export type WorldInteractResult =
  | {
      ok: true;
      entity: WorldEntity;
      delta: WorldDelta | null;
      interestedPlayerIds: string[];
      combatLock?: CombatLockZone;
      lockedPlayerIds?: string[];
    }
  | { ok: false; code: string; message: string };

export interface CreateCombatLockInput {
  center: { x: number; y: number };
  radius?: number;
  hostileEntityIds?: string[];
}

export interface CreateCombatLockResult {
  lock: CombatLockZone;
  lockedPlayerIds: string[];
}

export type CombatLockCloseResult = 'victory' | 'defeat' | 'cancelled';

export type CloseCombatLockResult =
  | {
      ok: true;
      lock: CombatLockZone;
      unlockedPlayerIds: string[];
      entity?: WorldEntity;
      delta?: WorldDelta;
      deltas?: WorldDelta[];
      interestedPlayerIds?: string[];
    }
  | { ok: false; code: string; message: string };

export interface WorldShardInspection {
  shardId: string;
  mapId: string;
  templateHash: string;
  contentRevision: number;
  playerCount: number;
  entityCount: number;
  activeLockCount: number;
  activeChannelCount: number;
}

export interface SkillCastResult {
  ok: boolean;
  ack: SkillExecutorResult['ack'];
  resolved: SkillExecutorResult['resolved'];
  broadcast: SkillExecutorResult['broadcast'];
  broadcastPlayerIds: string[];
  deltas: SkillExecutorResult['deltas'];
  interrupted?: boolean;
}

export type ProgressionSubscribeResult =
  | { ok: true; state: PlayerProgressionState }
  | { ok: false; code: string; message: string };

export interface ProgressionPatchInput {
  playerId: string;
  patch: ProgressionPatch;
  reason: string;
}

export type ProgressionPatchResult =
  | {
      ok: true;
      selfPatch: {
        patch: Partial<PlayerProgressionState>;
        reason: string;
      };
      state: PlayerProgressionState;
    }
  | { ok: false; code: string; message: string };

export interface ProgressionAoiChangedUpdate {
  playerId: string;
  projection: AoiVisibleProgression;
}

export interface ProgressionAoiUpdates {
  changed: ProgressionAoiChangedUpdate[];
  left: string[];
}

export interface WorldShardMonsterTickResult {
  deltas: WorldDelta[];
  aggroEvents: MonsterAggroEvent[];
  preludes: MonsterCombatPrelude[];
  combatLockRequests: MonsterCombatLockRequest[];
}

export type EvadeMonsterResult =
  | { ok: true }
  | { ok: false; code: string; message: string };

export interface WeeklyResetPayload {
  resetId: string;
  mapId: string;
  serverTime: number;
  nextResetAt: number;
  respawnedSpawnIds: string[];
}

export interface WeeklyResetResult {
  reset: WeeklyResetPayload;
  playerIds: string[];
}

interface ActiveSkillChannel {
  playerId: string;
  abilityId: string;
  clientToken: string;
  startedAt: number;
  endsAt: number;
  validation: Extract<ReturnType<SkillValidator['validateCast']>, { ok: true }>;
  execution: Extract<SkillExecutorResult, { ok: true }>;
}

export class WorldShard {
  private readonly players = new PlayerRegistry();
  private readonly entities = new Map<string, WorldEntity>();
  private readonly combatLocks = new Map<string, CombatLockZone>();
  private readonly combatInstances = new Map<string, CombatInstance>();
  private readonly combatLockCoordinator: CombatLockCoordinator;
  private readonly combatRouter: CombatRouter;
  private readonly movement: MovementSystem;
  private readonly interaction: InteractionSystem;
  private readonly contentExtensions: ContentExtension[];
  private readonly deltaLedger: DeltaLedger;
  private readonly aoi: AoiSystem;
  private readonly progression: ProgressionRegistry;
  private readonly skillValidator?: SkillValidator;
  private readonly skillExecutor?: SkillExecutor;
  private readonly monsterTemplates = new MonsterTemplateRegistry();
  private readonly monsterAi: MonsterAiSystem;
  private readonly monsterPack: MonsterPackRegistry;
  private readonly monsterRespawn: MonsterRespawnSystem;
  private readonly monsterRuntimes = new Map<string, MonsterRuntime>();
  private readonly monsterSpawnsByEntityId = new Map<string, MonsterSpawn>();
  private readonly skillChannels = new Map<string, ActiveSkillChannel>();
  private readonly skillBroadcastRadiusCells: number;
  private readonly skillBroadcastThrottleMs: number;
  private readonly recentSkillBroadcasts = new Map<string, number>();
  private readonly progressionAoiByObserver = new Map<string, Map<string, string>>();
  private readonly aoiVisibilityByObserver = new Map<string, AoiVisibility>();
  private readonly projectionContract: WorldProjectionContract;
  private channelTimer: ReturnType<typeof setInterval> | undefined;
  private tick = 0;

  constructor(private readonly options: WorldShardOptions) {
    this.progression = new ProgressionRegistry({ now: () => this.options.clock.now() });
    this.monsterAi = new MonsterAiSystem({
      templates: this.monsterTemplates,
      transformationOracle: {
        isSameSpecies: (player, template) => this.progression.getProgression(player.playerId)?.transformedSpecies === template.speciesId
      },
      config: {
        threatGainPerTick: 35,
        leashRadiusCells: 8,
        preludeLeadTimeMs: 1500,
        evadeWindowMs: 1500
      }
    });
    this.monsterPack = new MonsterPackRegistry({ templates: this.monsterTemplates });
    this.monsterRespawn = new MonsterRespawnSystem({
      templates: this.monsterTemplates,
      shardId: options.shardId,
      mapId: options.template.mapId
    });
    for (const entity of options.template.entities) {
      this.entities.set(entity.entityId, clone(entity));
    }
    for (const spawn of options.template.monsterSpawns ?? []) {
      if (spawn.active) {
        this.registerMonsterRuntime(this.monsterAi.spawn(spawn, options.clock.now()), spawn);
      }
    }
    this.movement = new MovementSystem({
      maxMoveCellsPerSecond: options.maxMoveCellsPerSecond,
      blocked: new Set(options.template.blocked.map((position) => positionKey(position)))
    });
    this.combatLockCoordinator = new CombatLockCoordinator({
      defaultRadius: options.combatLockRadiusCells ?? 6
    });
    this.combatRouter = new CombatRouter(this.combatInstances, options.clock);
    this.deltaLedger = new DeltaLedger(options.storage, options.clock, {
      shardId: options.shardId,
      mapId: options.template.mapId
    });
    this.aoi = new AoiSystem({
      defaultZone: resolveDefaultAoiZone(options.template, options.aoiRadiusCells),
      zones: options.template.aoiZones,
      regions: options.template.regions
    });
    this.skillBroadcastRadiusCells = options.skillBroadcastRadiusCells ?? options.aoiRadiusCells;
    this.skillBroadcastThrottleMs = options.skillBroadcastThrottleMs ?? 600;
    this.contentExtensions = options.contentExtensions ?? [];
    this.interaction = new InteractionSystem(this.contentExtensions);
    this.projectionContract = buildProjectionContract(options.template.mapId);
    if (options.skillAbilities && options.skillAbilities.length > 0) {
      this.skillValidator = new SkillValidator(options.skillAbilities);
    }
    if (options.skillPlans && options.skillPlans.length > 0) {
      this.skillExecutor = new SkillExecutor(options.skillPlans);
    }
  }

  async enterPlayer(input: EnterPlayerInput): Promise<PlayerWorldState> {
    const stored = await this.options.storage.playerStates.get(input.playerId);
    const player = stored ?? {
      playerId: input.playerId,
      displayName: input.displayName,
      position: clone(this.options.template.spawn),
      facing: 'south' as const,
      movementState: 'idle' as const,
      combatLockId: null,
      lastMoveSeq: 0,
      updatedAt: this.options.clock.now()
    };

    const registered = this.players.upsert(player);
    await this.options.storage.playerStates.upsert(registered);
    const storedProgression = await this.options.storage.playerProgressionStates.get(input.playerId);
    if (storedProgression) {
      this.progression.setProgression(input.playerId, storedProgression);
    } else {
      await this.options.storage.playerProgressionStates.upsert(this.progression.getOrCreateProgression(input.playerId));
    }
    return registered;
  }

  async leavePlayer(playerId: string): Promise<PlayerProgressionState | null> {
    const state = this.progression.getProgression(playerId);
    this.players.remove(playerId);
    this.progressionAoiByObserver.delete(playerId);
    this.aoiVisibilityByObserver.delete(playerId);
    if (!state) {
      return null;
    }
    await this.options.storage.playerProgressionStates.upsert(state);
    return state;
  }

  async transferOut(playerId: string, handoffToken: string): Promise<TransferOutResult> {
    const player = this.players.get(playerId);
    if (!player) {
      return { ok: false, code: 'PLAYER_NOT_IN_SHARD', message: `Player ${playerId} is not in shard` };
    }
    if (player.movementState === 'locked' || player.combatLockId !== null) {
      return { ok: false, code: 'PLAYER_LOCKED', message: `Player ${playerId} is locked by combat` };
    }

    const snapshotAtExit = this.createSnapshotFor(playerId);
    await this.leavePlayer(playerId);
    return { ok: true, handoffToken, snapshotAtExit };
  }

  async transferIn(input: TransferInInput): Promise<WorldSnapshotPayload> {
    const state: PlayerWorldState = {
      ...clone(input.player),
      position: clone(input.toPosition),
      facing: input.toFacing,
      movementState: 'idle',
      combatLockId: null,
      lastMoveSeq: 0,
      updatedAt: this.options.clock.now()
    };
    await this.options.storage.playerStates.upsert(state);
    await this.enterPlayer({ playerId: state.playerId, displayName: state.displayName });
    return this.createSnapshotFor(state.playerId);
  }

  subscribeProgression(playerId: string): ProgressionSubscribeResult {
    if (!this.players.get(playerId)) {
      return { ok: false, code: 'PLAYER_NOT_IN_SHARD', message: `Player ${playerId} is not in shard` };
    }
    return { ok: true, state: this.progression.getOrCreateProgression(playerId) };
  }

  async patchProgression(input: ProgressionPatchInput): Promise<ProgressionPatchResult> {
    if (!this.players.get(input.playerId)) {
      return { ok: false, code: 'PLAYER_NOT_IN_SHARD', message: `Player ${input.playerId} is not in shard` };
    }
    const before = this.progression.getOrCreateProgression(input.playerId);
    const after = this.progression.patchProgression(input.playerId, input.patch);
    await this.options.storage.playerProgressionStates.upsert(after);
    return {
      ok: true,
      selfPatch: {
        patch: diffProgressionState(before, after),
        reason: input.reason
      },
      state: after
    };
  }

  consumeProgressionAoiUpdates(observerPlayerId: string): ProgressionAoiUpdates {
    const observer = this.players.get(observerPlayerId);
    if (!observer) {
      this.progressionAoiByObserver.delete(observerPlayerId);
      return { changed: [], left: [] };
    }

    const previous = this.progressionAoiByObserver.get(observerPlayerId) ?? new Map<string, string>();
    const next = new Map<string, string>();
    const changed: ProgressionAoiChangedUpdate[] = [];
    const visiblePlayers = this.aoi.playersWithin(
      observer.position,
      this.players.list().filter((player) => player.playerId !== observerPlayerId)
    );

    for (const player of visiblePlayers) {
      const projection = this.progression.computeAoiVisibleProjection(player.playerId);
      const hash = JSON.stringify(projection);
      next.set(player.playerId, hash);
      if (previous.get(player.playerId) !== hash) {
        changed.push({ playerId: player.playerId, projection });
      }
    }

    const left = [...previous.keys()]
      .filter((playerId) => !next.has(playerId))
      .sort((a, b) => a.localeCompare(b));
    this.progressionAoiByObserver.set(observerPlayerId, next);
    return { changed, left };
  }

  async movePlayer(move: WorldMoveInput): Promise<MovePlayerResult> {
    const player = this.players.get(move.playerId);
    if (!player) {
      return {
        ok: false,
        correction: {
          playerId: move.playerId,
          acceptedSeq: 0,
          authoritativePosition: clone(this.options.template.spawn),
          reason: 'unknown'
        }
      };
    }

    const interruptedSkill = this.interruptChannelForPlayer(move.playerId);
    if (interruptedSkill) {
      return {
        ok: false,
        correction: {
          playerId: move.playerId,
          acceptedSeq: player.lastMoveSeq,
          authoritativePosition: { ...player.position },
          reason: 'channel_interrupted'
        },
        interruptedSkill
      };
    }

    const result = this.movement.validate(player, move, this.options.clock.now());
    if (!result.ok) {
      return {
        ok: false,
        correction: {
          playerId: move.playerId,
          acceptedSeq: result.acceptedSeq,
          authoritativePosition: result.authoritativePosition,
          reason: result.reason
        }
      };
    }

    const updated = this.players.upsert(result.player);
    await this.options.storage.playerStates.upsert(updated);
    return { ok: true, snapshot: this.createSnapshotFor(updated.playerId) };
  }

  async interact(input: WorldInteractInput): Promise<WorldInteractResult> {
    const player = this.players.get(input.playerId);
    if (!player) {
      return { ok: false, code: 'PLAYER_NOT_IN_SHARD', message: `Player ${input.playerId} is not in shard` };
    }
    const entity = this.entities.get(input.entityId);
    if (!entity) {
      return { ok: false, code: 'ENTITY_NOT_FOUND', message: `Entity ${input.entityId} does not exist` };
    }

    const result = this.interaction.apply(player, entity, { action: input.action }, this.options.clock.now());
    if (!result.ok) {
      return result;
    }

    let delta: WorldDelta | null = null;
    this.entities.set(result.entity.entityId, clone(result.entity));
    if (result.delta) {
      delta = await this.deltaLedger.append({
        actorPlayerId: input.playerId,
        targetEntityId: input.entityId,
        type: result.delta.type,
        patch: result.delta.patch
      });
    }
    const combatLockResult = result.combatLockRequest
      ? this.createCombatLock({
          center: result.entity.position,
          radius: result.combatLockRequest.radius ?? 2
        })
      : null;

    return {
      ok: true,
      entity: result.entity,
      delta,
      interestedPlayerIds: this.findPlayersInterestedIn(result.entity),
      ...(combatLockResult ? {
        combatLock: combatLockResult.lock,
        lockedPlayerIds: combatLockResult.lockedPlayerIds
      } : {})
    };
  }

  createCombatLock(input: CreateCombatLockInput): CreateCombatLockResult {
    const allowedHostiles = input.hostileEntityIds ? new Set(input.hostileEntityIds) : null;
    const result = this.combatLockCoordinator.createLock(
      this.options.shardId,
      input.center,
      this.players.list(),
      [...this.entities.values()]
        .filter((entity) => !allowedHostiles || allowedHostiles.has(entity.entityId))
        .map((entity) => clone(entity)),
      this.options.clock.now(),
      input.radius
    );

    for (const player of result.players) {
      this.players.upsert(player);
    }
    this.combatLocks.set(result.lock.combatLockId, clone(result.lock));
    this.combatInstances.set(result.lock.combatLockId, new CombatInstance(result.lock));
    for (const hostileEntityId of result.lock.hostileEntityIds) {
      const runtime = this.monsterRuntimes.get(hostileEntityId);
      if (!runtime) {
        continue;
      }
      runtime.state = 'COMBAT_LOCKED';
      runtime.combatLockId = result.lock.combatLockId;
      runtime.lastTransitionAt = this.options.clock.now();
      this.monsterRuntimes.set(hostileEntityId, runtime);
      this.syncMonsterEntity(runtime);
      this.monsterPack.register(runtime);
    }

    return {
      lock: result.lock,
      lockedPlayerIds: result.lock.participantPlayerIds
    };
  }

  async closeCombatLock(combatLockId: string, combatResult: CombatLockCloseResult = 'cancelled'): Promise<CloseCombatLockResult> {
    const lock = this.combatLocks.get(combatLockId);
    if (!lock) {
      return { ok: false, code: 'COMBAT_LOCK_NOT_FOUND', message: `Combat lock ${combatLockId} is not active` };
    }

    const result = this.combatLockCoordinator.closeLock(lock, this.players.list(), this.options.clock.now());
    for (const player of result.players) {
      this.players.upsert(player);
    }
    this.combatLocks.delete(combatLockId);
    this.combatInstances.delete(combatLockId);

    const monsterDeltas = await this.applyMonsterCombatOutcomeForLock(lock, combatResult);
    const aftermath = await this.applyCombatCloseContentExtensions(lock, combatResult);
    const monsterAftermath = !aftermath && monsterDeltas.length > 0
      ? {
          delta: monsterDeltas[0],
          interestedPlayerIds: result.lock.participantPlayerIds
        }
      : null;
    return {
      ok: true,
      lock: result.lock,
      unlockedPlayerIds: result.lock.participantPlayerIds,
      ...(aftermath ? aftermath : {}),
      ...(monsterAftermath ? monsterAftermath : {}),
      ...(monsterDeltas.length > 1 ? { deltas: monsterDeltas } : {})
    };
  }

  async tickMonsters(now: number = this.options.clock.now()): Promise<WorldShardMonsterTickResult> {
    const before = new Map(
      [...this.monsterRuntimes.entries()].map(([entityId, runtime]) => [entityId, cloneMonsterRuntime(runtime)])
    );
    const aiResult = this.monsterAi.tick(
      [...this.monsterRuntimes.values()],
      this.players.list(),
      now
    );
    let nextMonsters = aiResult.monsters;
    this.monsterPack.registerMany(nextMonsters);
    for (const event of aiResult.aggroEvents) {
      if (event.toState === 'ALERT' || event.toState === 'CHASE') {
        this.monsterPack.callAllies(event.monsterId, now);
      }
      if (event.toState === 'CHASE') {
        const runtime = this.monsterRuntimes.get(event.monsterId);
        if (runtime) {
          const template = this.monsterTemplates.loadSync(runtime.templateId);
          this.monsterPack.enforceMaxConcurrent(template.pack.packId, now);
        }
      }
    }
    nextMonsters = this.monsterPack.list();

    const deltas: WorldDelta[] = [];
    for (const runtime of nextMonsters) {
      const previous = before.get(runtime.entityId);
      this.monsterRuntimes.set(runtime.entityId, cloneMonsterRuntime(runtime));
      const delta = await this.appendMonsterRuntimeDelta(previous, runtime, 'system');
      if (delta) {
        deltas.push(delta);
      }
    }

    for (const respawn of this.monsterRespawn.tick(now)) {
      this.registerMonsterRuntime(respawn.runtime, respawn.spawn);
      const delta = await this.deltaLedger.append({
        actorPlayerId: 'system',
        targetEntityId: respawn.delta.targetEntityId,
        type: respawn.delta.type,
        patch: respawn.delta.patch
      });
      deltas.push(delta);
    }

    return {
      deltas,
      aggroEvents: aiResult.aggroEvents,
      preludes: aiResult.preludes,
      combatLockRequests: aiResult.combatLockRequests
    };
  }

  async triggerWeeklyReset(now: number = this.options.clock.now()): Promise<WeeklyResetResult> {
    const respawnedSpawnIds = new Set<string>();
    for (const respawn of this.monsterRespawn.weeklyReset(now)) {
      this.registerMonsterRuntime(respawn.runtime, respawn.spawn);
      await this.deltaLedger.append({
        actorPlayerId: 'system',
        targetEntityId: respawn.delta.targetEntityId,
        type: respawn.delta.type,
        patch: respawn.delta.patch
      });
      respawnedSpawnIds.add(respawn.spawn.spawnId);
    }
    if (respawnedSpawnIds.size === 0) {
      for (const spawn of this.options.template.monsterSpawns ?? []) {
        if (!spawn.active) {
          continue;
        }
        this.registerMonsterRuntime(this.monsterAi.spawn(spawn, now), spawn);
        respawnedSpawnIds.add(spawn.spawnId);
      }
    }

    return {
      reset: {
        resetId: `${this.options.shardId}-weekly-${now}`,
        mapId: this.options.template.mapId,
        serverTime: now,
        nextResetAt: now + 7 * 24 * 60 * 60 * 1000,
        respawnedSpawnIds: [...respawnedSpawnIds].sort((a, b) => a.localeCompare(b))
      },
      playerIds: this.players.list().map((player) => player.playerId).sort((a, b) => a.localeCompare(b))
    };
  }

  evadeMonster(input: { playerId: string; monsterEntityId: string; evadeKind: string }): EvadeMonsterResult {
    const player = this.players.get(input.playerId);
    if (!player) {
      return { ok: false, code: 'PLAYER_NOT_IN_SHARD', message: `Player ${input.playerId} is not in shard` };
    }
    const monster = this.monsterRuntimes.get(input.monsterEntityId);
    if (!monster) {
      return { ok: false, code: 'MONSTER_NOT_FOUND', message: `Monster ${input.monsterEntityId} is not active` };
    }
    if (input.evadeKind !== 'sprint' && input.evadeKind !== 'stealth' && input.evadeKind !== 'transform') {
      return { ok: false, code: 'INVALID_EVADE_KIND', message: `Unsupported evade kind ${input.evadeKind}` };
    }

    const result = this.monsterAi.attemptEvade(monster, player, {
      evadeKind: input.evadeKind,
      now: this.options.clock.now()
    });
    this.monsterRuntimes.set(result.monster.entityId, cloneMonsterRuntime(result.monster));
    this.syncMonsterEntity(result.monster);
    this.monsterPack.register(result.monster);
    if (!result.ack.ok) {
      return { ok: false, code: result.ack.code, message: result.ack.reason };
    }
    return { ok: true };
  }

  async applyMonsterCombatOutcome(combatLockId: string, outcome: CombatLockCloseResult): Promise<WorldDelta[]> {
    const lock = this.combatLocks.get(combatLockId);
    if (!lock) {
      return [];
    }
    return this.applyMonsterCombatOutcomeForLock(lock, outcome);
  }

  private async applyMonsterCombatOutcomeForLock(lock: CombatLockZone, outcome: CombatLockCloseResult): Promise<WorldDelta[]> {
    const deltas: WorldDelta[] = [];
    for (const hostileEntityId of lock.hostileEntityIds) {
      const runtime = this.monsterRuntimes.get(hostileEntityId);
      const spawn = this.monsterSpawnsByEntityId.get(hostileEntityId);
      if (!runtime || !spawn) {
        continue;
      }
      if (outcome === 'victory') {
        deltas.push(await this.removeDefeatedMonster(runtime, spawn));
      } else {
        deltas.push(await this.leashMonsterAfterCombat(runtime, outcome));
      }
    }
    return deltas;
  }

  submitCombatAction(playerId: string, payload: CombatActionPayload): CombatRouteResult {
    const player = this.players.get(playerId);
    if (!player) {
      return { ok: false, code: 'PLAYER_NOT_IN_SHARD', message: `Player ${playerId} is not in shard` };
    }
    return this.combatRouter.dispatch(player, payload);
  }

  async castSkill(input: SkillCastInput): Promise<SkillCastResult> {
    if (!this.skillValidator || !this.skillExecutor) {
      return this.rejectedSkillResult('SKILL_VALIDATION_FAILED', input.clientToken, 0);
    }

    const validation = this.skillValidator.validateCast(input);
    if (!validation.ok) {
      return this.rejectedSkillResult(validation.code, input.clientToken, validation.cooldownEndsAt);
    }

    const execution = this.skillExecutor.execute({
      caster: input.caster.player,
      validation,
      targetEntity: input.targetEntity,
      targetGroundPosition: input.target.targetGroundPosition,
      clientToken: input.clientToken,
      appliedAt: input.now
    });

    if (!execution.ok) {
      return this.rejectedSkillResult(execution.ack.reason ?? 'SKILL_VALIDATION_FAILED', input.clientToken, execution.ack.cooldownEndsAt);
    }

    if (this.skillChannels.has(input.caster.player.playerId)) {
      return this.rejectedSkillResult('SKILL_VALIDATION_FAILED', input.clientToken, validation.cooldownEndsAt);
    }

    const channelMs = this.skillExecutor.getPlanChannelMs(validation.abilityId);
    if (channelMs > 0) {
      const startedAt = input.now;
      const endsAt = startedAt + channelMs;
      this.skillChannels.set(input.caster.player.playerId, {
        playerId: input.caster.player.playerId,
        abilityId: validation.abilityId,
        clientToken: input.clientToken,
        startedAt,
        endsAt,
        validation,
        execution
      });
      this.ensureChannelTimer();
      return {
        ok: true,
        ack: {
          ...execution.ack,
          channelStartedAt: startedAt,
          channelEndsAt: endsAt
        },
        resolved: null,
        broadcast: null,
        broadcastPlayerIds: [],
        deltas: []
      };
    }

    return this.applySkillExecution(input.caster.player.playerId, execution);
  }

  async advanceSkillChannels(now: number = this.options.clock.now()): Promise<SkillCastResult[]> {
    const ready: SkillCastResult[] = [];
    for (const [playerId, channel] of [...this.skillChannels]) {
      if (channel.endsAt > now) {
        continue;
      }
      this.skillChannels.delete(playerId);
      const durationMs = Math.max(channel.endsAt - channel.startedAt, 0);
      const execution: Extract<SkillExecutorResult, { ok: true }> = {
        ...channel.execution,
        ack: {
          ...channel.execution.ack,
          channelStartedAt: channel.startedAt,
          channelEndsAt: channel.endsAt
        },
        resolved: { ...channel.execution.resolved, durationMs },
        broadcast: channel.execution.broadcast ? { ...channel.execution.broadcast, durationMs } : null,
        deltas: channel.execution.deltas
      };
      ready.push(await this.applySkillExecution(playerId, execution));
    }
    return ready;
  }

  dispose(): void {
    if (this.channelTimer) {
      clearInterval(this.channelTimer);
      this.channelTimer = undefined;
    }
  }

  listCombatLocks(): CombatLockZone[] {
    return [...this.combatLocks.values()]
      .sort((a, b) => a.combatLockId.localeCompare(b.combatLockId))
      .map((lock) => clone(lock));
  }

  inspectState(): WorldShardInspection {
    return {
      shardId: this.options.shardId,
      mapId: this.options.template.mapId,
      templateHash: this.options.template.templateHash,
      contentRevision: this.options.template.meta.contentRevision,
      playerCount: this.players.list().length,
      entityCount: this.entities.size,
      activeLockCount: this.combatLocks.size,
      activeChannelCount: this.skillChannels.size
    };
  }

  createSnapshotFor(playerId: string): WorldSnapshotPayload {
    const self = this.players.get(playerId);
    if (!self) {
      throw new Error(`PLAYER_NOT_IN_SHARD:${playerId}`);
    }

    const visible = this.captureAoiFor(self);
    this.aoiVisibilityByObserver.set(playerId, visible.visibility);

    return {
      shardId: this.options.shardId,
      mapId: this.options.template.mapId,
      templateHash: this.options.template.templateHash,
      defaultAoiZoneId: this.options.template.defaultAoiZoneId,
      tick: this.tick++,
      self,
      players: visible.players,
      entities: visible.entities,
      combatLocks: visible.combatLocks,
      projectionContract: clone(this.projectionContract),
      meta: clone(this.options.template.meta),
      regions: clone(this.options.template.regions),
      portals: clone(this.options.template.portals),
      aoiZones: clone(this.options.template.aoiZones)
    };
  }

  computeAoiDelta(playerId: string, _sinceTick: number): AoiDeltaEvent[] {
    const self = this.players.get(playerId);
    if (!self) {
      this.aoiVisibilityByObserver.delete(playerId);
      return [];
    }

    const previous = this.aoiVisibilityByObserver.get(playerId);
    const current = this.captureAoiFor(self).visibility;
    this.aoiVisibilityByObserver.set(playerId, current);
    if (!previous) {
      return [];
    }

    return this.aoi.diffVisibility(previous, current, this.tick++);
  }

  private findPlayersInterestedIn(entity: WorldEntity): string[] {
    return this.players.list()
      .filter((player) => this.aoi.visibleFrom(player.position, [], [entity], []).entities.length > 0)
      .map((player) => player.playerId);
  }

  private captureAoiFor(self: PlayerWorldState): {
    visibility: AoiVisibility;
    players: PlayerWorldState[];
    entities: WorldEntity[];
    combatLocks: CombatLockZone[];
  } {
    const players = this.players.list().filter((player) => player.playerId !== self.playerId);
    const entities = [...this.entities.values()].map((entity) => clone(entity));
    const combatLocks = [...this.combatLocks.values()].map((lock) => clone(lock));
    const visibility = this.aoi.captureVisibilityFrom(self.position, players, entities, combatLocks);
    const visiblePlayerIds = new Set(visibility.players);
    const visibleEntityIds = new Set(visibility.entities);
    const visibleLockIds = new Set(visibility.combatLocks);
    return {
      visibility,
      players: players.filter((player) => visiblePlayerIds.has(player.playerId)),
      entities: entities.filter((entity) => visibleEntityIds.has(entity.entityId)),
      combatLocks: combatLocks.filter((lock) => visibleLockIds.has(lock.combatLockId))
    };
  }

  private async applyCombatCloseContentExtensions(
    lock: CombatLockZone,
    combatResult: CombatLockCloseResult
  ): Promise<{ entity: WorldEntity; delta: WorldDelta; interestedPlayerIds: string[] } | null> {
    const actorPlayerId = lock.participantPlayerIds[0] ?? 'system';
    for (const hostileEntityId of lock.hostileEntityIds) {
      const entity = this.entities.get(hostileEntityId);
      if (!entity) {
        continue;
      }
      const result = applyContentExtensions(this.contentExtensions, entity, 'combat_close', {
        actorPlayerId,
        combatResult
      });
      if (!result) {
        continue;
      }
      this.entities.set(result.entity.entityId, clone(result.entity));
      if (!result.delta) {
        continue;
      }
      const delta = await this.deltaLedger.append({
        actorPlayerId,
        targetEntityId: result.entity.entityId,
        type: result.delta.type,
        patch: result.delta.patch
      });
      return {
        entity: result.entity,
        delta,
        interestedPlayerIds: this.findPlayersInterestedIn(result.entity)
      };
    }
    return null;
  }

  private registerMonsterRuntime(runtime: MonsterRuntime, spawn: MonsterSpawn): void {
    const cloned = cloneMonsterRuntime(runtime);
    this.monsterRuntimes.set(cloned.entityId, cloned);
    this.monsterSpawnsByEntityId.set(cloned.entityId, cloneMonsterSpawn(spawn));
    this.syncMonsterEntity(cloned);
    this.monsterPack.register(cloned);
  }

  private syncMonsterEntity(runtime: MonsterRuntime, extraState: Record<string, unknown> = {}): void {
    const spawn = this.monsterSpawnsByEntityId.get(runtime.entityId);
    if (!spawn) {
      return;
    }
    const existing = this.entities.get(runtime.entityId);
    this.entities.set(runtime.entityId, this.createMonsterEntity(runtime, spawn, existing, extraState));
  }

  private async appendMonsterRuntimeDelta(
    previous: MonsterRuntime | undefined,
    runtime: MonsterRuntime,
    actorPlayerId: string,
    extraState: Record<string, unknown> = {}
  ): Promise<WorldDelta | null> {
    const spawn = this.monsterSpawnsByEntityId.get(runtime.entityId);
    if (!spawn || !previous) {
      this.syncMonsterEntity(runtime, extraState);
      return null;
    }
    const existing = this.entities.get(runtime.entityId);
    const beforeEntity = this.createMonsterEntity(previous, spawn, existing);
    const afterEntity = this.createMonsterEntity(runtime, spawn, existing, extraState);
    const statePatch = diffRecord(beforeEntity.state, afterEntity.state);
    const positionChanged = !samePosition(beforeEntity.position, afterEntity.position);
    if (!positionChanged && Object.keys(statePatch).length === 0) {
      return null;
    }
    const version = (existing?.version ?? beforeEntity.version) + 1;
    const patch: Record<string, unknown> = {
      ...(positionChanged ? { position: { ...afterEntity.position } } : {}),
      ...(Object.keys(statePatch).length > 0 ? { state: statePatch } : {}),
      version
    };
    const delta = await this.deltaLedger.append({
      actorPlayerId,
      targetEntityId: runtime.entityId,
      type: 'state_changed',
      patch
    });
    this.entities.set(runtime.entityId, {
      ...afterEntity,
      version
    });
    return delta;
  }

  private async removeDefeatedMonster(runtime: MonsterRuntime, spawn: MonsterSpawn): Promise<WorldDelta> {
    const defeated = cloneMonsterRuntime(runtime);
    defeated.state = 'DEAD';
    defeated.hp = 0;
    defeated.combatLockId = null;
    defeated.pendingPrelude = null;
    defeated.lastTransitionAt = this.options.clock.now();
    const existing = this.entities.get(runtime.entityId);
    const version = (existing?.version ?? 1) + 1;
    const delta = await this.deltaLedger.append({
      actorPlayerId: 'system',
      targetEntityId: runtime.entityId,
      type: 'entity_removed',
      patch: {
        state: {
          monsterState: 'DEAD',
          hp: 0,
          active: false,
          combatLockId: null
        },
        version
      }
    });
    this.entities.delete(runtime.entityId);
    this.monsterRuntimes.delete(runtime.entityId);
    this.monsterPack.unregister(runtime.entityId);
    this.monsterRespawn.schedule(spawn, this.options.clock.now());
    return delta;
  }

  private async leashMonsterAfterCombat(runtime: MonsterRuntime, outcome: CombatLockCloseResult): Promise<WorldDelta> {
    const next = cloneMonsterRuntime(runtime);
    const template = this.monsterTemplates.loadSync(next.templateId);
    next.state = 'PATROL';
    next.position = { ...next.patrolAnchor };
    next.hp = template.stats.maxHp;
    next.threat = new Map();
    next.combatLockId = null;
    next.pendingPrelude = null;
    next.lastTransitionAt = this.options.clock.now();
    this.monsterRuntimes.set(next.entityId, cloneMonsterRuntime(next));
    this.monsterPack.register(next);
    const existing = this.entities.get(next.entityId);
    const version = (existing?.version ?? 1) + 1;
    const extraState = {
      status: 'leashed_back',
      combatResult: outcome
    };
    const delta = await this.deltaLedger.append({
      actorPlayerId: 'system',
      targetEntityId: next.entityId,
      type: 'state_changed',
      patch: {
        position: { ...next.position },
        state: {
          ...extraState,
          monsterState: next.state,
          hp: next.hp,
          combatLockId: null
        },
        version
      }
    });
    this.entities.set(next.entityId, {
      ...this.createMonsterEntity(next, this.monsterSpawnsByEntityId.get(next.entityId)!, existing, extraState),
      version
    });
    return delta;
  }

  private createMonsterEntity(
    runtime: MonsterRuntime,
    spawn: MonsterSpawn,
    existing?: WorldEntity,
    extraState: Record<string, unknown> = {}
  ): WorldEntity {
    const template = this.monsterTemplates.loadSync(runtime.templateId);
    const state: Record<string, unknown> = {
      ...(existing?.state ?? {}),
      spawnId: spawn.spawnId,
      monsterId: spawn.monsterId,
      active: runtime.state !== 'DEAD',
      hostile: true,
      monsterState: runtime.state,
      hp: runtime.hp,
      maxHp: template.stats.maxHp,
      combatLockId: runtime.combatLockId,
      pendingPrelude: runtime.pendingPrelude !== null,
      ...extraState
    };
    if (spawn.initialState) {
      state.initialState = spawn.initialState;
    }
    if (spawn.storyVisibleId) {
      state.storyVisibleId = spawn.storyVisibleId;
    }
    if (spawn.patrolAnchorOverride) {
      state.patrolAnchorOverride = clone(spawn.patrolAnchorOverride);
    }
    if (spawn.packMemberIndex !== undefined) {
      state.packMemberIndex = spawn.packMemberIndex;
    }
    return {
      entityId: runtime.entityId,
      type: 'monster',
      position: { ...runtime.position },
      state,
      version: existing?.version ?? 1
    };
  }

  private interruptChannelForPlayer(playerId: string): SkillCastResult | null {
    const channel = this.skillChannels.get(playerId);
    if (!channel) {
      return null;
    }
    this.skillChannels.delete(playerId);
    const elapsed = Math.max(this.options.clock.now() - channel.startedAt, 0);
    const proportion = channel.endsAt > channel.startedAt ? Math.min(Math.max(elapsed / (channel.endsAt - channel.startedAt), 0), 1) : 1;
    const cooldownWindow = Math.max(channel.validation.cooldownEndsAt - channel.startedAt, 0);
    const cooldownEndsAt = this.options.clock.now() + Math.round(cooldownWindow * (1 - proportion));
    return {
      ok: false,
      ack: {
        abilityId: channel.validation.abilityId,
        clientToken: channel.clientToken,
        ok: false,
        reason: 'SKILL_CHANNEL_INTERRUPTED',
        cooldownEndsAt: Math.max(cooldownEndsAt, this.options.clock.now()),
        pollutionApplied: 0,
        manaApplied: 0,
        channelStartedAt: channel.startedAt,
        channelEndsAt: channel.endsAt
      },
      resolved: null,
      broadcast: null,
      broadcastPlayerIds: [],
      deltas: [],
      interrupted: true
    };
  }

  private ensureChannelTimer(): void {
    if (this.channelTimer) {
      return;
    }
    this.channelTimer = setInterval(() => {
      void this.advanceSkillChannels();
    }, 50);
    this.channelTimer.unref?.();
  }

  private async applySkillExecution(playerId: string, execution: SkillCastResult | SkillExecutorResult): Promise<SkillCastResult> {
    if (!execution.ok) {
      return { ...execution, broadcastPlayerIds: 'broadcastPlayerIds' in execution ? execution.broadcastPlayerIds : [] };
    }
    const player = this.players.get(playerId);
    if (player) {
      await this.options.storage.playerStates.upsert({
        ...player,
        updatedAt: this.options.clock.now()
      });
    }
    for (const delta of execution.deltas) {
      const entity = this.entities.get(delta.targetEntityId);
      if (!entity) {
        continue;
      }
      const appended = await this.deltaLedger.append({
        actorPlayerId: playerId,
        targetEntityId: delta.targetEntityId,
        type: delta.type,
        patch: delta.patch
      });
      const patchedState = typeof appended.patch.state === 'object' && appended.patch.state
        ? { ...entity.state, ...(appended.patch.state as Record<string, unknown>) }
        : entity.state;
      const updated: WorldEntity = {
        ...clone(entity),
        ...(appended.patch.position ? { position: appended.patch.position as { x: number; y: number } } : {}),
        state: patchedState,
        version: appended.version
      };
      this.entities.set(updated.entityId, updated);
    }
    const broadcastPlayerIds = 'broadcastPlayerIds' in execution
      ? execution.broadcastPlayerIds
      : this.resolveSkillBroadcastPlayerIds(playerId, execution.ack.abilityId ?? '', execution.broadcast);
    const broadcast = broadcastPlayerIds.length > 0
      ? this.attachSkillBroadcastIdentity(playerId, execution.broadcast)
      : null;
    return {
      ...execution,
      broadcast,
      broadcastPlayerIds
    };
  }

  private attachSkillBroadcastIdentity(
    playerId: string,
    broadcast: SkillExecutorResult['broadcast']
  ): SkillExecutorResult['broadcast'] {
    if (!broadcast) {
      return null;
    }
    const projection = this.progression.computeAoiVisibleProjection(playerId);
    return {
      ...broadcast,
      actor_visible: projection.identityVisibleInAoi,
      ...(!projection.identityVisibleInAoi ? { actor_anonymized_label: projection.aoiActorLabel } : {})
    };
  }

  private resolveSkillBroadcastPlayerIds(
    casterPlayerId: string,
    abilityId: string,
    broadcast: SkillExecutorResult['broadcast']
  ): string[] {
    if (!broadcast || broadcast.scope === 'self_only') {
      return [];
    }
    const now = this.options.clock.now();
    const key = `${casterPlayerId}:${abilityId}`;
    const lastBroadcastAt = this.recentSkillBroadcasts.get(key);
    if (lastBroadcastAt !== undefined && now - lastBroadcastAt < this.skillBroadcastThrottleMs) {
      return [];
    }
    const caster = this.players.get(casterPlayerId);
    if (!caster) {
      return [];
    }
    this.recentSkillBroadcasts.set(key, now);
    return this.aoi.playersWithin(
      caster.position,
      this.players.list().filter((player) => player.playerId !== casterPlayerId),
      this.skillBroadcastRadiusCells
    )
      .map((player) => player.playerId);
  }

  private rejectedSkillResult(reason: SkillFailureCode, clientToken: string, cooldownEndsAt: number): SkillCastResult {
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
      broadcastPlayerIds: [],
      deltas: [],
      interrupted: reason === 'SKILL_CHANNEL_INTERRUPTED'
    };
  }
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function cloneMonsterSpawn(spawn: MonsterSpawn): MonsterSpawn {
  return {
    ...spawn,
    position: { ...spawn.position },
    patrolAnchorOverride: spawn.patrolAnchorOverride ? { ...spawn.patrolAnchorOverride } : undefined
  };
}

function samePosition(a: GridPosition, b: GridPosition): boolean {
  return a.x === b.x && a.y === b.y;
}

function diffRecord(before: Record<string, unknown>, after: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {};
  for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
      patch[key] = clone(after[key]);
    }
  }
  return patch;
}

function materializeMonsterSpawns(spawns: MonsterSpawn[]): WorldEntity[] {
  return spawns
    .filter((spawn) => spawn.active)
    .map((spawn) => {
      const state: Record<string, unknown> = {
        spawnId: spawn.spawnId,
        monsterId: spawn.monsterId,
        active: spawn.active,
        hostile: true
      };
      if (spawn.initialState) {
        state.initialState = spawn.initialState;
      }
      if (spawn.storyVisibleId) {
        state.storyVisibleId = spawn.storyVisibleId;
      }
      if (spawn.patrolAnchorOverride) {
        state.patrolAnchorOverride = clone(spawn.patrolAnchorOverride);
      }
      if (spawn.packMemberIndex !== undefined) {
        state.packMemberIndex = spawn.packMemberIndex;
      }
      return {
        entityId: spawn.storyVisibleId ?? spawn.spawnId,
        type: 'monster',
        position: clone(spawn.position),
        state,
        version: 1
      };
    });
}

function buildProjectionContract(mapId: string): WorldProjectionContract {
  const origin = { x: 0, y: -96 };
  return {
    mapId,
    coordinateSpace: 'm3-grid-to-godot-world',
    origin,
    originText: `${origin.x},${origin.y}`,
    cellSize: 48,
    gridAxis: { x: 'east', y: 'south' },
    worldAxis: { x: 'right', y: 'down' }
  };
}

function resolveDefaultAoiZone(template: WorldTemplate, fallbackRadiusCells: number): AoiZoneConfig {
  const configured = template.aoiZones.find((zone) => zone.zoneId === template.defaultAoiZoneId);
  if (configured) {
    if (
      configured.zoneId === 'default' &&
      configured.deltaMode === 'full' &&
      configured.playersRadiusCells === 30 &&
      configured.entitiesRadiusCells === 30 &&
      configured.combatLocksRadiusCells === 6
    ) {
      return {
        ...configured,
        playersRadiusCells: fallbackRadiusCells,
        entitiesRadiusCells: fallbackRadiusCells,
        combatLocksRadiusCells: fallbackRadiusCells
      };
    }
    return configured;
  }
  return {
    zoneId: 'default',
    playersRadiusCells: fallbackRadiusCells,
    entitiesRadiusCells: fallbackRadiusCells,
    combatLocksRadiusCells: fallbackRadiusCells,
    deltaMode: 'full'
  };
}

function diffProgressionState(
  before: PlayerProgressionState,
  after: PlayerProgressionState
): Partial<PlayerProgressionState> {
  const patch: Partial<PlayerProgressionState> = {};
  for (const key of Object.keys(after) as Array<keyof PlayerProgressionState>) {
    if (key === 'playerId' || key === 'protocolVersion' || key === 'updatedAt' || key === 'contentHash') {
      continue;
    }
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
      patch[key] = clone(after[key]) as never;
    }
  }
  return patch;
}
