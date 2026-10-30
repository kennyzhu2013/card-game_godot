import { randomUUID } from 'node:crypto';
import type { AddressInfo } from 'node:net';
import { WebSocketServer, type RawData, type WebSocket } from 'ws';
import { decodeEnvelope, type Envelope } from '../core/envelope.js';
import type { Clock } from '../core/time.js';
import { ClientOps, PROTOCOL_VERSION, ServerOps } from '../protocol/ops.js';
import { ProtocolRouter } from '../protocol/router.js';
import {
  validateAuthRefreshPayload,
  validateAuthLoginPayload,
  validateBuildCancelPayload,
  validateBuildDismantlePayload,
  validateBuildPlaceRequestPayload,
  validateChatPartyPayload,
  validateChatSayPayload,
  validateChatWhisperPayload,
  validateCombatActionPayload,
  validateEquipmentEquipPayload,
  validateEquipmentListPayload,
  validateEquipmentUnequipPayload,
  validateForgeCancelPayload,
  validateForgeRequestPayload,
  validateInventoryDiscardPayload,
  validateInventoryFetchPayload,
  validateProgressionAcknowledgeMilestonePayload,
  validateProgressionSubscribePayload,
  ProgressionErrorCodes,
  validateQuestAbandonPayload,
  validateQuestAcceptPayload,
  validateQuestListPayload,
  validateQuestTurnInPayload,
  validatePathwayAdvanceRequestPayload,
  validatePathwayConsumePotionPayload,
  validatePathwayListPayload,
  validateTransformationEndPayload,
  validateTransformationFeedPayload,
  validateTransformationStartPayload,
  validateSkillEquipLoadoutPayload,
  validateSkillLearnPayload,
  validateShopBuyPayload,
  validateShopListPayload,
  validateShopSellPayload,
  validateRitualCancelPayload,
  validateRitualFeedPayload,
  validateRitualStartPayload,
  validateMonsterEvadePayload,
  validateProtocolVersion,
  validateSystemPingPayload,
  validateWriteEnvelopeHeaders,
  validateWorldEnterPayload,
  validateWorldListMapsPayload,
  validateWorldListShardsPayload,
  validateWorldInteractPayload,
  validateWorldTransferPayload,
  validateWorldMovePayload,
  type BuildPlaceRequestPayload,
  type EquipmentSlot,
  type MaterialInput,
  type TransformationDepth
} from '../protocol/validators.js';
import type { AuthResult, DevAuthService } from './auth.js';
import type { PerOpRateLimiter } from './rateLimiter.js';
import type { SessionManager } from './sessionManager.js';
import type { Storage } from '../storage/storage.js';
import { SnapshotScheduler } from '../world/snapshotScheduler.js';
import type { MapTemplateRegistry } from '../world/mapTemplateRegistry.js';
import type { CombatLockZone, Direction, GridPosition } from '../world/types.js';
import type { WorldSnapshotPayload, WorldShard } from '../world/worldShard.js';
import type { ShardRegistry } from '../world/shardRegistry.js';

export interface M3WebSocketGatewayOptions {
  port: number;
  clock: Clock;
  auth: DevAuthService;
  storage: Storage;
  sessions: SessionManager;
  shard: WorldShard;
  shardRegistry: ShardRegistry;
  templateRegistry: MapTemplateRegistry;
  rateLimiter: PerOpRateLimiter;
  snapshotRateHz: number;
}

export interface M3WebSocketGateway {
  wsPort: number;
  broadcastCombatLock(lock: CombatLockZone): void;
  broadcastCombatUnlock(lock: CombatLockZone): void;
  broadcastToPlayers(playerIds: string[], message: ServerMessage): void;
  stop(): Promise<void>;
}

interface IdempotencyCacheEntry {
  storedAt: number;
  responses: Envelope[];
}

const IDEMPOTENCY_TTL_MS = 60_000;
const IDEMPOTENCY_MAX_ENTRIES = 10_000;

export async function createM3WebSocketGateway(options: M3WebSocketGatewayOptions): Promise<M3WebSocketGateway> {
  const wss = new WebSocketServer({ host: '127.0.0.1', port: options.port });
  const profiles = new Map<string, AuthResult>();
  const sessionSockets = new Map<string, WebSocket>();
  const progressionSubscribers = new Set<string>();
  const idempotencyCache = new Map<string, IdempotencyCacheEntry>();
  const resolveShard = (shardId: string | null | undefined): WorldShard => {
    if (shardId) {
      return options.shardRegistry.get(shardId) ?? options.shard;
    }
    return options.shard;
  };
  const broadcaster = createBroadcaster(options, sessionSockets, progressionSubscribers, resolveShard);
  const router = createRouter(options, profiles, broadcaster.broadcastToPlayers, progressionSubscribers, resolveShard);
  const scheduler = new SnapshotScheduler({
    snapshotRateHz: options.snapshotRateHz,
    onTick: () => {
      void broadcaster.broadcastSnapshots();
    }
  });

  wss.on('connection', (socket, request) => {
    const socketId = `socket-${randomUUID()}`;
    const remoteAddress = request.socket.remoteAddress ?? 'unknown';
    let sessionId: string | undefined;
    let messageChain = Promise.resolve();

    void options.sessions.create(socketId, remoteAddress).then((session) => {
      sessionId = session.sessionId;
      sessionSockets.set(session.sessionId, socket);
    });

    socket.on('message', (data) => {
      messageChain = messageChain.then(async () => {
        if (!sessionId) {
          await waitForSessionId(() => sessionId);
        }
        await handleMessage(socket, data, sessionId as string, router, options, idempotencyCache);
      }).catch((error: unknown) => {
        sendError(socket, 0, 'HANDLER_ERROR', error instanceof Error ? error.message : 'Unhandled message error', true, options.clock);
      });
    });

    socket.on('close', () => {
      if (sessionId) {
        profiles.delete(sessionId);
        sessionSockets.delete(sessionId);
        progressionSubscribers.delete(sessionId);
        void options.sessions.get(sessionId).then(async (session) => {
          if (session?.playerId) {
            await resolveShard(session.shardId).leavePlayer(session.playerId);
          }
          await options.sessions.disconnect(sessionId as string);
        });
      }
    });
  });

  await waitForListening(wss);
  scheduler.start();

  return {
    wsPort: (wss.address() as AddressInfo).port,
    broadcastCombatLock(lock: CombatLockZone): void {
      broadcaster.broadcastToPlayers(lock.participantPlayerIds, { op: ServerOps.CombatLock, payload: { lock } });
    },
    broadcastCombatUnlock(lock: CombatLockZone): void {
      broadcaster.broadcastToPlayers(lock.participantPlayerIds, { op: ServerOps.CombatUnlock, payload: { lock } });
    },
    broadcastToPlayers(playerIds: string[], message: ServerMessage): void {
      broadcaster.broadcastToPlayers(playerIds, message);
    },
    async stop(): Promise<void> {
      scheduler.stop();
      for (const client of wss.clients) {
        client.close();
      }
      await new Promise<void>((resolve, reject) => {
        wss.close((error) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        });
      });
    }
  };
}

type ServerMessage = Omit<Envelope, 'id' | 'ts'>;
const PROTOCOL_FEATURE_FLAGS = [
  ClientOps.AuthRefresh,
  ClientOps.SystemPing,
  ClientOps.WorldListShards,
  ClientOps.WorldListMaps,
  ClientOps.WorldEnter,
  ClientOps.WorldMove,
  ClientOps.WorldInteract,
  ClientOps.WorldTransfer,
  ClientOps.InventoryFetch,
  ClientOps.InventoryDiscard,
  ClientOps.EquipmentList,
  ClientOps.EquipmentEquip,
  ClientOps.EquipmentUnequip,
  ClientOps.ForgeRequest,
  ClientOps.ForgeCancel,
  ClientOps.RitualStart,
  ClientOps.RitualFeed,
  ClientOps.RitualCancel,
  ClientOps.QuestList,
  ClientOps.QuestAccept,
  ClientOps.QuestTurnIn,
  ClientOps.QuestAbandon,
  ClientOps.TransformationStart,
  ClientOps.TransformationFeed,
  ClientOps.TransformationEnd,
  ClientOps.PathwayList,
  ClientOps.PathwayAdvanceRequest,
  ClientOps.PathwayConsumePotion,
  ClientOps.SkillLearn,
  ClientOps.SkillEquipLoadout,
  ClientOps.BuildPlaceRequest,
  ClientOps.BuildCancel,
  ClientOps.BuildDismantle,
  ClientOps.ShopList,
  ClientOps.ShopBuy,
  ClientOps.ShopSell,
  ClientOps.ProgressionSubscribe,
  ClientOps.ProgressionAcknowledgeMilestone,
  ClientOps.CombatAction,
  ClientOps.MonsterEvade,
  ClientOps.ChatSay,
  ClientOps.ChatWhisper,
  ClientOps.ChatParty
];

function createRouter(
  options: M3WebSocketGatewayOptions,
  profiles: Map<string, AuthResult>,
  broadcastToPlayers: (playerIds: string[], message: ServerMessage) => void,
  progressionSubscribers: Set<string>,
  resolveShard: (shardId: string | null | undefined) => WorldShard
): ProtocolRouter {
  const router = new ProtocolRouter(options.clock);
  const inventories = new Map<string, InventoryState>();
  const equipment = new Map<string, EquipmentState>();
  const activeRituals = new Map<string, RitualRequestState>();
  const quests = new Map<string, QuestLogState>();
  const transformations = new Map<string, TransformationState>();
  const pathways = new Map<string, PathwayState>();
  const skills = new Map<string, SkillState>();
  const builds = new Map<string, BuildStructureState>();
  const shops = initializeShopStates();
  const playersByShard = new Map<string, Set<string>>();
  const worldError = (code: string, message: string, retryable = false): ServerMessage => ({
    op: ServerOps.WorldError,
    payload: { code, message, retryable }
  });

  router.register(ClientOps.AuthLogin, async ({ sessionId, payload }) => {
    const parsed = validateAuthLoginPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const auth = await options.auth.login(parsed.value.token);
    profiles.set(sessionId, auth);
    const session = await options.sessions.authenticate(sessionId, auth.accountId, auth.playerId);
    return {
      op: ServerOps.AuthResult,
      payload: {
        ...auth,
        sessionId: session.sessionId,
        ok: true,
        serverProtocolVersion: PROTOCOL_VERSION,
        featureFlags: PROTOCOL_FEATURE_FLAGS
      }
    };
  });

  router.register(ClientOps.AuthRefresh, async ({ sessionId, payload }) => {
    const parsed = validateAuthRefreshPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.heartbeat(sessionId);
    return {
      op: ServerOps.AuthResult,
      payload: {
        ok: true,
        sessionId: session.sessionId,
        accountId: session.accountId,
        playerId: session.playerId,
        serverProtocolVersion: PROTOCOL_VERSION,
        featureFlags: PROTOCOL_FEATURE_FLAGS
      }
    };
  });

  router.register(ClientOps.SystemPing, async ({ sessionId, payload, envelope }) => {
    const parsed = validateSystemPingPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    await options.sessions.heartbeat(sessionId);
    return {
      op: ServerOps.SystemPong,
      payload: {
        tick: parsed.value.tick ?? 0,
        serverTime: options.clock.now(),
        rttMs: Math.max(0, options.clock.now() - envelope.ts)
      }
    };
  });

  router.register(ClientOps.WorldListShards, async ({ payload }) => {
    const parsed = validateWorldListShardsPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    return {
      op: ServerOps.WorldShardList,
      payload: {
        ok: true,
        shards: options.shardRegistry.list()
      }
    };
  });

  router.register(ClientOps.WorldListMaps, async ({ payload }) => {
    const parsed = validateWorldListMapsPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    return {
      op: ServerOps.WorldMapList,
      payload: {
        ok: true,
        maps: await options.templateRegistry.list()
      }
    };
  });

  router.register(ClientOps.InventoryFetch, async ({ sessionId, payload }) => {
    const parsed = validateInventoryFetchPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('INVENTORY_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    return {
      op: ServerOps.InventorySnapshot,
      payload: inventorySnapshot(getInventory(inventories, session.playerId))
    };
  });

  router.register(ClientOps.InventoryDiscard, async ({ sessionId, payload }) => {
    const parsed = validateInventoryDiscardPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('INVENTORY_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const inventory = getInventory(inventories, session.playerId);
    const item = inventory.items.find((candidate) => candidate.itemId === parsed.value.itemId);
    if (!item || item.amount <= 0) {
      return worldError('ITEM_NOT_FOUND', `Item ${parsed.value.itemId} was not found`, false);
    }
    if (item.meta.locked === true) {
      return worldError('ITEM_LOCKED', `Item ${parsed.value.itemId} is locked`, false);
    }
    if (item.amount < parsed.value.amount) {
      return worldError('INSUFFICIENT_AMOUNT', `Item ${parsed.value.itemId} amount is insufficient`, false);
    }
    const before = item.amount;
    item.amount -= parsed.value.amount;
    return {
      op: ServerOps.InventoryDelta,
      payload: {
        ok: true,
        changes: [{ itemId: item.itemId, before, after: item.amount }]
      }
    };
  });

  router.register(ClientOps.EquipmentList, async ({ sessionId, payload }) => {
    const parsed = validateEquipmentListPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('EQUIPMENT_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    return {
      op: ServerOps.EquipmentSnapshot,
      payload: equipmentSnapshot(getEquipment(equipment, session.playerId))
    };
  });

  router.register(ClientOps.EquipmentEquip, async ({ sessionId, payload }) => {
    const parsed = validateEquipmentEquipPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('EQUIPMENT_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const inventory = getInventory(inventories, session.playerId);
    const item = inventory.items.find((candidate) => candidate.itemId === parsed.value.itemId && candidate.amount > 0);
    if (!item) {
      return worldError('ITEM_NOT_FOUND', `Item ${parsed.value.itemId} was not found`, false);
    }
    if (!itemMatchesEquipmentSlot(item, parsed.value.slot)) {
      return worldError('ITEM_NOT_EQUIPPABLE', `Item ${parsed.value.itemId} cannot be equipped in ${parsed.value.slot}`, false);
    }
    const state = getEquipment(equipment, session.playerId);
    equipItem(state, parsed.value.slot, item.itemId);
    syncDefaultLoadout(state, parsed.value.loadoutId);
    return [
      { op: ServerOps.EquipmentSnapshot, payload: equipmentSnapshot(state) },
      { op: ServerOps.EquipmentDelta, payload: { ok: true, equipped: cloneEquipped(state.equipped), affixes: {} } }
    ];
  });

  router.register(ClientOps.EquipmentUnequip, async ({ sessionId, payload }) => {
    const parsed = validateEquipmentUnequipPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('EQUIPMENT_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const state = getEquipment(equipment, session.playerId);
    unequipItem(state, parsed.value.slot);
    syncDefaultLoadout(state);
    return [
      { op: ServerOps.EquipmentSnapshot, payload: equipmentSnapshot(state) },
      { op: ServerOps.EquipmentDelta, payload: { ok: true, equipped: cloneEquipped(state.equipped), affixes: {} } }
    ];
  });

  router.register(ClientOps.ForgeRequest, async ({ sessionId, payload }) => {
    const parsed = validateForgeRequestPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('FORGE_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const inventory = getInventory(inventories, session.playerId);
    const requestId = `forge-${randomUUID()}`;
    if (!hasMaterials(inventory, parsed.value.inputs)) {
      return {
        op: ServerOps.ForgeResult,
        payload: {
          ok: false,
          requestId,
          code: 'FORGE_INPUTS_INSUFFICIENT',
          message: 'Forge inputs are insufficient',
          refunded: []
        }
      };
    }
    const consumed = consumeMaterials(inventory, parsed.value.inputs);
    const weapon = createForgeWeapon(requestId);
    addInventoryItem(inventory, weapon);
    return [
      { op: ServerOps.ForgeProgress, payload: { requestId, phase: 'planning', progress: 0.25 } },
      { op: ServerOps.ForgeProgress, payload: { requestId, phase: 'shaping', progress: 0.6 } },
      { op: ServerOps.ForgeProgress, payload: { requestId, phase: 'tempering', progress: 1 } },
      {
        op: ServerOps.ForgeResult,
        payload: {
          ok: true,
          requestId,
          weapon,
          consumed,
          deltas: []
        }
      }
    ];
  });

  router.register(ClientOps.ForgeCancel, async ({ payload }) => {
    const parsed = validateForgeCancelPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    return {
      op: ServerOps.ForgeResult,
      payload: {
        ok: false,
        requestId: parsed.value.requestId,
        code: 'FORGE_CANCELLED',
        message: 'Forge request was cancelled',
        refunded: []
      }
    };
  });

  router.register(ClientOps.RitualStart, async ({ sessionId, payload }) => {
    const parsed = validateRitualStartPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('RITUAL_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    if (activeRituals.has(session.playerId)) {
      const active = activeRituals.get(session.playerId) as RitualRequestState;
      return {
        op: ServerOps.RitualResult,
        payload: {
          ok: false,
          requestId: active.requestId,
          code: 'RITUAL_BUSY',
          message: 'Player already has an active ritual',
          consumed: []
        }
      };
    }
    const requestId = `ritual-${randomUUID()}`;
    activeRituals.set(session.playerId, {
      requestId,
      playerId: session.playerId,
      ritualId: parsed.value.ritualId,
      expectedMaterials: parsed.value.expectedMaterials
    });
    return {
      op: ServerOps.RitualProgress,
      payload: { requestId, phase: 'drawing', progress: 0.25, pollutionPressure: 0 }
    };
  });

  router.register(ClientOps.RitualFeed, async ({ sessionId, payload }) => {
    const parsed = validateRitualFeedPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('RITUAL_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const active = activeRituals.get(session.playerId);
    if (!active || active.requestId !== parsed.value.requestId) {
      return {
        op: ServerOps.RitualResult,
        payload: {
          ok: false,
          requestId: parsed.value.requestId,
          code: 'RITUAL_NOT_FOUND',
          message: 'Ritual request is not active',
          consumed: []
        }
      };
    }
    const inventory = getInventory(inventories, session.playerId);
    const requested = [{ itemId: parsed.value.itemId, amount: parsed.value.amount }];
    if (!hasMaterials(inventory, requested)) {
      return {
        op: ServerOps.RitualResult,
        payload: {
          ok: false,
          requestId: active.requestId,
          code: 'MATERIALS_INSUFFICIENT',
          message: 'Ritual materials are insufficient',
          consumed: []
        }
      };
    }
    const consumed = consumeMaterials(inventory, requested);
    activeRituals.delete(session.playerId);
    return [
      { op: ServerOps.RitualProgress, payload: { requestId: active.requestId, phase: 'channeling', progress: 1, pollutionPressure: 0 } },
      {
        op: ServerOps.RitualResult,
        payload: {
          ok: true,
          requestId: active.requestId,
          effect: { ritualId: active.ritualId, type: 'world_focus', meta: {} },
          consumed,
          deltas: []
        }
      }
    ];
  });

  router.register(ClientOps.RitualCancel, async ({ sessionId, payload }) => {
    const parsed = validateRitualCancelPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (!session?.playerId) {
      return worldError('RITUAL_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const active = activeRituals.get(session.playerId);
    if (active?.requestId === parsed.value.requestId) {
      activeRituals.delete(session.playerId);
    }
    return {
      op: ServerOps.RitualInterrupted,
      payload: { requestId: parsed.value.requestId, reason: 'cancelled' }
    };
  });

  router.register(ClientOps.QuestList, async ({ sessionId, payload }) => {
    const parsed = validateQuestListPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('QUEST_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    return {
      op: ServerOps.QuestSnapshot,
      payload: questSnapshot(getQuestLog(quests, session.playerId))
    };
  });

  router.register(ClientOps.QuestAccept, async ({ sessionId, payload }) => {
    const parsed = validateQuestAcceptPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('QUEST_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = acceptQuest(getQuestLog(quests, session.playerId), parsed.value.questId);
    return result.ok
      ? { op: ServerOps.QuestDelta, payload: questDeltaPayload(result.record) }
      : worldError(result.code, result.message, false);
  });

  router.register(ClientOps.QuestTurnIn, async ({ sessionId, payload }) => {
    const parsed = validateQuestTurnInPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('QUEST_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = turnInQuest(getQuestLog(quests, session.playerId), parsed.value.questId);
    if (!result.ok) {
      return worldError(result.code, result.message, false);
    }
    applyQuestRewards(getInventory(inventories, session.playerId), result.rewards);
    return { op: ServerOps.QuestDelta, payload: questDeltaPayload(result.record) };
  });

  router.register(ClientOps.QuestAbandon, async ({ sessionId, payload }) => {
    const parsed = validateQuestAbandonPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('QUEST_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = abandonQuest(getQuestLog(quests, session.playerId), parsed.value.questId);
    return result.ok
      ? { op: ServerOps.QuestDelta, payload: result.payload }
      : worldError(result.code, result.message, false);
  });

  router.register(ClientOps.TransformationStart, async ({ sessionId, payload }) => {
    const parsed = validateTransformationStartPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('TRANSFORMATION_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = startTransformation(transformations, session.playerId, parsed.value.speciesId, parsed.value.depth, options.clock.now());
    return result.ok
      ? { op: ServerOps.TransformationState, payload: transformationStatePayload(result.state) }
      : worldError(result.code, result.message, false);
  });

  router.register(ClientOps.TransformationFeed, async ({ sessionId, payload }) => {
    const parsed = validateTransformationFeedPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('TRANSFORMATION_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = feedTransformation(transformations, session.playerId, parsed.value.itemId, parsed.value.amount);
    if (!result.ok) {
      return worldError(result.code, result.message, false);
    }
    const messages: ServerMessage[] = [
      {
        op: ServerOps.TransformationSuspicionChanged,
        payload: result.suspicion
      }
    ];
    if (result.exposed) {
      messages.push({ op: ServerOps.TransformationExposed, payload: result.exposed });
    }
    messages.push({ op: ServerOps.TransformationState, payload: transformationStatePayload(result.state) });
    return messages;
  });

  router.register(ClientOps.TransformationEnd, async ({ sessionId, payload }) => {
    const parsed = validateTransformationEndPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('TRANSFORMATION_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = endTransformation(transformations, session.playerId, parsed.value.reason);
    return result.ok
      ? { op: ServerOps.TransformationState, payload: transformationStatePayload(result.state) }
      : worldError(result.code, result.message, false);
  });

  router.register(ClientOps.PathwayList, async ({ sessionId, payload }) => {
    const parsed = validatePathwayListPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('PATHWAY_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    return {
      op: ServerOps.PathwaySnapshot,
      payload: pathwaySnapshot(getPathwayState(pathways, session.playerId))
    };
  });

  router.register(ClientOps.PathwayAdvanceRequest, async ({ sessionId, payload }) => {
    const parsed = validatePathwayAdvanceRequestPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('PATHWAY_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = advancePathway(getPathwayState(pathways, session.playerId), parsed.value);
    if (!result.ok) {
      return worldError(result.code, result.message, false);
    }
    return [
      { op: ServerOps.PathwayDelta, payload: pathwayDeltaPayload(result.record, result.rewards) },
      { op: ServerOps.PathwayUnlockEvent, payload: pathwayUnlockPayload(result.record, result.rewards) }
    ];
  });

  router.register(ClientOps.PathwayConsumePotion, async ({ sessionId, payload }) => {
    const parsed = validatePathwayConsumePotionPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('PATHWAY_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    if (parsed.value.potionItemId !== PATHWAY_POTION_ITEM_ID) {
      return worldError('POTION_INVALID', `Pathway potion ${parsed.value.potionItemId} is invalid`, false);
    }
    return {
      op: ServerOps.PathwayDelta,
      payload: { ok: true, pathwayId: 'tide_priestess', consumedPotionItemId: parsed.value.potionItemId }
    };
  });

  router.register(ClientOps.SkillLearn, async ({ sessionId, payload }) => {
    const parsed = validateSkillLearnPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('SKILL_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = learnSkill(getSkillState(skills, session.playerId), parsed.value.skillId, parsed.value.pathwaySource);
    if (!result.ok) {
      return worldError(result.code, result.message, false);
    }
    return [
      { op: ServerOps.SkillDelta, payload: { ok: true, learnedAdded: result.added ? [parsed.value.skillId] : [] } },
      { op: ServerOps.SkillSnapshot, payload: skillSnapshot(result.state) }
    ];
  });

  router.register(ClientOps.SkillEquipLoadout, async ({ sessionId, payload }) => {
    const parsed = validateSkillEquipLoadoutPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('SKILL_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = equipSkillLoadout(getSkillState(skills, session.playerId), parsed.value.loadoutId, parsed.value.skills);
    if (!result.ok) {
      return worldError(result.code, result.message, false);
    }
    return [
      { op: ServerOps.SkillDelta, payload: { ok: true, activeLoadoutId: parsed.value.loadoutId } },
      { op: ServerOps.SkillSnapshot, payload: skillSnapshot(result.state) }
    ];
  });

  router.register(ClientOps.BuildPlaceRequest, async ({ sessionId, payload }) => {
    const parsed = validateBuildPlaceRequestPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId || !session.shardId) {
      return worldError('BUILD_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const result = placeBuildStructure(builds, getInventory(inventories, session.playerId), session.shardId, session.playerId, parsed.value);
    if (!result.ok) {
      return {
        op: ServerOps.BuildResult,
        payload: {
          ok: false,
          requestId: result.requestId,
          code: result.code,
          message: result.message,
          refunded: result.refunded
        }
      };
    }
    broadcastToPlayers(shardPlayerIds(playersByShard, session.shardId, session.playerId), {
      op: ServerOps.BuildWorldAlteration,
      payload: buildWorldAlterationPayload(result.structure)
    });
    return [
      { op: ServerOps.BuildProgress, payload: { requestId: result.requestId, phase: 'foundation', progress: 0.25 } },
      { op: ServerOps.BuildProgress, payload: { requestId: result.requestId, phase: 'frame', progress: 0.65 } },
      { op: ServerOps.BuildProgress, payload: { requestId: result.requestId, phase: 'finishing', progress: 1 } },
      {
        op: ServerOps.BuildResult,
        payload: {
          ok: true,
          requestId: result.requestId,
          structureEntityId: result.structure.structureEntityId,
          deltas: [{
            kind: 'structure_created',
            entityId: result.structure.structureEntityId,
            position: { ...result.structure.position },
            visualId: result.structure.visualId
          }]
        }
      }
    ];
  });

  router.register(ClientOps.BuildCancel, async ({ payload }) => {
    const parsed = validateBuildCancelPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    return {
      op: ServerOps.BuildResult,
      payload: {
        ok: false,
        requestId: parsed.value.requestId,
        code: 'BUILD_CANCELLED',
        message: 'Build request was cancelled',
        refunded: []
      }
    };
  });

  router.register(ClientOps.BuildDismantle, async ({ sessionId, payload }) => {
    const parsed = validateBuildDismantlePayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId || !session.shardId) {
      return worldError('BUILD_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    const requestId = `build-${randomUUID()}`;
    const structure = builds.get(parsed.value.structureEntityId);
    if (!structure || structure.shardId !== session.shardId) {
      return {
        op: ServerOps.BuildResult,
        payload: {
          ok: false,
          requestId,
          code: 'STRUCTURE_NOT_FOUND',
          message: 'Build structure was not found',
          refunded: []
        }
      };
    }
    builds.delete(parsed.value.structureEntityId);
    return {
      op: ServerOps.BuildResult,
      payload: {
        ok: true,
        requestId,
        structureEntityId: parsed.value.structureEntityId,
        deltas: [{ kind: 'structure_removed', entityId: parsed.value.structureEntityId }]
      }
    };
  });

  router.register(ClientOps.ShopList, async ({ sessionId, payload }) => {
    const parsed = validateShopListPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return worldError('SHOP_NOT_INTERACTABLE', 'Session has not entered a world shard', false);
    }
    const shop = shops.get(parsed.value.shopEntityId);
    if (!shop || !shop.open) {
      return {
        op: ServerOps.ShopSnapshot,
        payload: { ok: false, shopEntityId: parsed.value.shopEntityId, code: 'SHOP_CLOSED', message: 'Shop is not open' }
      };
    }
    return {
      op: ServerOps.ShopSnapshot,
      payload: shopSnapshot(shop)
    };
  });

  router.register(ClientOps.ShopBuy, async ({ sessionId, payload }) => {
    const parsed = validateShopBuyPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return {
        op: ServerOps.ShopTransactionResult,
        payload: shopTransactionFailure(parsed.value.shopEntityId, parsed.value.itemId, parsed.value.amount, 'SHOP_NOT_INTERACTABLE', 'Session has not entered a world shard')
      };
    }
    const result = buyFromShop(shops, getInventory(inventories, session.playerId), parsed.value);
    return {
      op: ServerOps.ShopTransactionResult,
      payload: result
    };
  });

  router.register(ClientOps.ShopSell, async ({ sessionId, payload }) => {
    const parsed = validateShopSellPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return {
        op: ServerOps.ShopTransactionResult,
        payload: shopTransactionFailure(parsed.value.shopEntityId, parsed.value.itemId, parsed.value.amount, 'SHOP_NOT_INTERACTABLE', 'Session has not entered a world shard')
      };
    }
    const result = sellToShop(shops, getInventory(inventories, session.playerId), parsed.value);
    return {
      op: ServerOps.ShopTransactionResult,
      payload: result
    };
  });

  router.register(ClientOps.WorldEnter, async ({ sessionId, payload }) => {
    const parsed = validateWorldEnterPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const shard = options.shardRegistry.get(parsed.value.shardId);
    if (!shard) {
      return worldError('SHARD_NOT_FOUND', `Shard ${parsed.value.shardId} was not found`, false);
    }
    const session = await options.sessions.enterWorld(sessionId, parsed.value.shardId);
    if (!session.playerId) {
      throw new Error('SESSION_MISSING_PLAYER');
    }
    rememberShardPlayer(playersByShard, parsed.value.shardId, session.playerId);
    const profile = profiles.get(sessionId);
    const player = await shard.enterPlayer({
      playerId: session.playerId,
      displayName: profile?.displayName ?? session.playerId
    });
    const snapshot = shard.createSnapshotFor(player.playerId);
    return [
      {
        op: ServerOps.WorldEntered,
        payload: {
          shardId: parsed.value.shardId,
          mapId: snapshot.mapId,
          templateHash: snapshot.templateHash,
          defaultAoiZoneId: snapshot.defaultAoiZoneId,
          projectionContract: snapshot.projectionContract,
          meta: snapshot.meta,
          regions: snapshot.regions,
          portals: snapshot.portals,
          aoiZones: snapshot.aoiZones,
          player
        }
      },
      { op: ServerOps.WorldSnapshot, payload: snapshot }
    ];
  });

  router.register(ClientOps.WorldTransfer, async ({ sessionId, payload }) => {
    const parsed = validateWorldTransferPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }

    const session = await options.sessions.get(sessionId);
    if (!session?.playerId) {
      return worldError('PLAYER_NOT_IN_SHARD', 'Session is not in a world shard', false);
    }
    if (session.playerId !== parsed.value.playerId) {
      return worldError('PLAYER_MISMATCH', 'Transfer playerId does not match the authenticated player', false);
    }
    if (session.shardId !== parsed.value.fromShardId) {
      return worldError('TRANSFER_SHARD_MISMATCH', 'Transfer fromShardId does not match the session shard', false);
    }

    const begin = await options.shardRegistry.beginTransfer(
      parsed.value.playerId,
      parsed.value.fromShardId,
      parsed.value.toShardId,
      parsed.value.toPosition
    );
    if (!begin.ok) {
      return worldError(begin.code, begin.message, false);
    }
    const complete = await options.shardRegistry.completeTransfer(begin.handoffToken);
    if (!complete.ok) {
      return worldError(complete.code, complete.message, false);
    }

    await options.sessions.switchShard(sessionId, parsed.value.toShardId);
    forgetShardPlayer(playersByShard, parsed.value.fromShardId, parsed.value.playerId);
    rememberShardPlayer(playersByShard, parsed.value.toShardId, parsed.value.playerId);

    const snapshot = complete.snapshot;
    return {
      op: ServerOps.WorldTransferAck,
      payload: {
        ok: true,
        playerId: parsed.value.playerId,
        fromShardId: parsed.value.fromShardId,
        toShardId: parsed.value.toShardId,
        toMapId: snapshot.mapId,
        toPosition: { ...parsed.value.toPosition },
        toFacing: snapshot.self.facing,
        snapshot
      }
    };
  });

  router.register(ClientOps.WorldMove, async ({ sessionId, payload }) => {
    const parsed = validateWorldMovePayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (!session || session.playerId !== parsed.value.playerId) {
      throw new Error('PLAYER_MISMATCH');
    }
    const result = await resolveShard(session.shardId).movePlayer(parsed.value);
    return result.ok
      ? { op: ServerOps.WorldSnapshot, payload: result.snapshot }
      : { op: ServerOps.WorldCorrection, payload: result.correction };
  });

  router.register(ClientOps.WorldInteract, async ({ sessionId, payload }) => {
    const parsed = validateWorldInteractPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (!session?.playerId) {
      throw new Error('SESSION_NOT_IN_WORLD');
    }
    const result = await resolveShard(session.shardId).interact({
      playerId: session.playerId,
      entityId: parsed.value.entityId,
      action: parsed.value.action
    });
    if (!result.ok) {
      return { op: ServerOps.WorldError, payload: { code: result.code, message: result.message, retryable: false } };
    }
    broadcastToPlayers(result.interestedPlayerIds, { op: ServerOps.WorldDelta, payload: result });
    if (result.combatLock && result.lockedPlayerIds) {
      broadcastToPlayers(result.lockedPlayerIds, { op: ServerOps.CombatLock, payload: { lock: result.combatLock } });
    }
    return advanceQuestProgress(quests, session.playerId, parsed.value.entityId, parsed.value.action);
  });

  router.register(ClientOps.ProgressionSubscribe, async ({ sessionId, payload }) => {
    const parsed = validateProgressionSubscribePayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || session.shardId !== parsed.value.shardId || !session.playerId) {
      return { op: ServerOps.WorldError, payload: { code: ProgressionErrorCodes.NotInWorld, message: 'Session has not entered the requested shard', retryable: false } };
    }
    const result = resolveShard(session.shardId).subscribeProgression(session.playerId);
    if (result.ok) {
      progressionSubscribers.add(sessionId);
    }
    return result.ok
      ? { op: ServerOps.ProgressionSelfState, payload: { state: result.state } }
      : { op: ServerOps.WorldError, payload: { code: result.code, message: result.message, retryable: false } };
  });

  router.register(ClientOps.ProgressionAcknowledgeMilestone, async ({ sessionId, payload }) => {
    const parsed = validateProgressionAcknowledgeMilestonePayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId) {
      return { op: ServerOps.WorldError, payload: { code: ProgressionErrorCodes.NotInWorld, message: 'Session has not entered a shard', retryable: false } };
    }
    return [];
  });

  router.register(ClientOps.CombatAction, async ({ sessionId, payload }) => {
    const parsed = validateCombatActionPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (!session?.playerId) {
      throw new Error('SESSION_NOT_IN_WORLD');
    }
    const interrupted = interruptActiveRitual(activeRituals, session.playerId, parsed.value.action);
    if (interrupted) {
      return {
        op: ServerOps.RitualInterrupted,
        payload: interrupted
      };
    }
    const result = resolveShard(session.shardId).submitCombatAction(session.playerId, parsed.value);
    return result.ok
      ? { op: ServerOps.CombatState, payload: result.state }
      : { op: ServerOps.WorldError, payload: { code: result.code, message: result.message, retryable: false } };
  });

  router.register(ClientOps.MonsterEvade, async ({ sessionId, payload }) => {
    const parsed = validateMonsterEvadePayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId || !session.shardId) {
      return {
        op: ServerOps.MonsterEvadeAck,
        payload: { ok: false, code: 'MONSTER_NOT_IN_WORLD', reason: 'Session is not in a world shard' }
      };
    }
    if (session.shardId !== parsed.value.shardId) {
      return {
        op: ServerOps.MonsterEvadeAck,
        payload: { ok: false, code: 'MONSTER_SHARD_MISMATCH', reason: 'Monster evade shardId does not match the active session shard' }
      };
    }
    const result = resolveShard(session.shardId).evadeMonster({
      playerId: session.playerId,
      monsterEntityId: parsed.value.monsterId,
      evadeKind: parsed.value.evadeKind
    });
    return {
      op: ServerOps.MonsterEvadeAck,
      payload: result.ok
        ? { ok: true, code: 'EVADED', reason: 'Monster evade accepted by authoritative shard' }
        : { ok: false, code: result.code, reason: result.message }
    };
  });

  router.register(ClientOps.ChatSay, async ({ sessionId, payload }) => {
    const parsed = validateChatSayPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId || !session.shardId) {
      return worldError('CHAT_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    broadcastToPlayers(shardPlayerIds(playersByShard, session.shardId, session.playerId), {
      op: ServerOps.ChatMessage,
      payload: { channel: 'say', playerId: session.playerId, text: parsed.value.text, shardId: session.shardId }
    });
    return [];
  });

  router.register(ClientOps.ChatWhisper, async ({ sessionId, payload }) => {
    const parsed = validateChatWhisperPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId || !session.shardId) {
      return worldError('CHAT_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    broadcastToPlayers(uniquePlayerIds([session.playerId, parsed.value.targetPlayerId]), {
      op: ServerOps.ChatMessage,
      payload: {
        channel: 'whisper',
        playerId: session.playerId,
        targetPlayerId: parsed.value.targetPlayerId,
        text: parsed.value.text,
        shardId: session.shardId
      }
    });
    return [];
  });

  router.register(ClientOps.ChatParty, async ({ sessionId, payload }) => {
    const parsed = validateChatPartyPayload(payload);
    if (!parsed.ok) {
      throw new Error(parsed.code);
    }
    const session = await options.sessions.get(sessionId);
    if (session?.state !== 'in_world' || !session.playerId || !session.shardId) {
      return worldError('CHAT_NOT_IN_WORLD', 'Session has not entered a world shard', false);
    }
    broadcastToPlayers(partyMemberIds(parsed.value.partyId, session.playerId), {
      op: ServerOps.ChatMessage,
      payload: {
        channel: 'party',
        playerId: session.playerId,
        partyId: parsed.value.partyId,
        text: parsed.value.text,
        shardId: session.shardId
      }
    });
    return [];
  });

  return router;
}

function createBroadcaster(
  options: M3WebSocketGatewayOptions,
  sessionSockets: Map<string, WebSocket>,
  progressionSubscribers: Set<string>,
  resolveShard: (shardId: string | null | undefined) => WorldShard
) {
  return {
    async broadcastSnapshots(): Promise<void> {
      const tickedShards = new Set<string>();
      for (const [sessionId, socket] of sessionSockets) {
        if (socket.readyState !== socket.OPEN) {
          continue;
        }
        const session = await options.sessions.get(sessionId);
        if (session?.state !== 'in_world' || !session.playerId) {
          continue;
        }
        const shard = resolveShard(session.shardId);
        const shardId = session.shardId ?? shard.inspectState().shardId;
        if (!tickedShards.has(shardId)) {
          tickedShards.add(shardId);
          await broadcastMonsterTick(shard, shardId, options.clock, this.broadcastToPlayers);
        }
        const aoiEvents = shard.computeAoiDelta(session.playerId, 0);
        if (aoiEvents.length > 0) {
          socket.send(JSON.stringify(envelope(0, ServerOps.WorldAoiDelta, {
            shardId,
            events: aoiEvents,
            tick: aoiEvents[0]?.tick ?? 0
          }, options.clock)));
        }
        const snapshot = shard.createSnapshotFor(session.playerId);
        socket.send(JSON.stringify(envelope(0, ServerOps.WorldSnapshot, snapshot, options.clock)));
        if (progressionSubscribers.has(sessionId)) {
          const progressionUpdates = shard.consumeProgressionAoiUpdates(session.playerId);
          for (const changed of progressionUpdates.changed) {
            socket.send(JSON.stringify(envelope(0, ServerOps.ProgressionAoiVisibleChanged, changed, options.clock)));
          }
          for (const playerId of progressionUpdates.left) {
            socket.send(JSON.stringify(envelope(0, ServerOps.ProgressionAoiVisibleLeft, { playerId }, options.clock)));
          }
        }
      }
    },

    broadcastToPlayers(playerIds: string[], message: ServerMessage): void {
      const wanted = new Set(playerIds);
      for (const [sessionId, socket] of sessionSockets) {
        if (socket.readyState !== socket.OPEN) {
          continue;
        }
        void options.sessions.get(sessionId).then((session) => {
          if (session?.playerId && wanted.has(session.playerId) && socket.readyState === socket.OPEN) {
            socket.send(JSON.stringify(envelope(0, message.op, message.payload, options.clock)));
          }
        });
      }
    }
  };
}

async function broadcastMonsterTick(
  shard: WorldShard,
  shardId: string,
  clock: Clock,
  broadcastToPlayers: (playerIds: string[], message: ServerMessage) => void
): Promise<void> {
  const result = await shard.tickMonsters(clock.now());
  for (const event of result.aggroEvents) {
    broadcastToPlayers([event.towardsPlayerId], {
      op: ServerOps.MonsterAggroChanged,
      payload: {
        shardId,
        monsterId: event.monsterId,
        fromState: event.fromState,
        toState: event.toState,
        threat: event.threat,
        towardsPlayerId: event.towardsPlayerId,
        tick: event.tick
      }
    });
  }
  for (const prelude of result.preludes) {
    broadcastToPlayers([prelude.targetPlayerId], {
      op: ServerOps.MonsterCombatPrelude,
      payload: {
        shardId,
        monsterId: prelude.monsterId,
        monsterEntityIds: [...prelude.monsterEntityIds],
        leadTimeMs: prelude.leadTimeMs,
        escapeWindowMs: prelude.escapeWindowMs
      }
    });
  }
  for (const request of result.combatLockRequests) {
    const lock = shard.createCombatLock({
      center: request.center,
      hostileEntityIds: request.hostileEntityIds
    });
    if (lock.lockedPlayerIds.length > 0) {
      broadcastToPlayers(lock.lockedPlayerIds, {
        op: ServerOps.CombatLock,
        payload: { lock: lock.lock }
      });
    }
  }
}

async function handleMessage(
  socket: WebSocket,
  data: RawData,
  sessionId: string,
  router: ProtocolRouter,
  options: M3WebSocketGatewayOptions,
  idempotencyCache: Map<string, IdempotencyCacheEntry>
): Promise<void> {
  let envelope: Envelope;
  try {
    envelope = decodeEnvelope(rawDataToString(data));
  } catch {
    sendError(socket, 0, 'MALFORMED_MESSAGE', 'Message must be a valid M3 envelope', false, options.clock);
    return;
  }

  const version = validateProtocolVersion(envelope.protocolVersion);
  if (!version.ok) {
    socket.send(JSON.stringify(envelopeFor(envelope.id, ServerOps.AuthResult, {
      ok: false,
      code: version.code,
      message: version.message,
      serverProtocolVersion: PROTOCOL_VERSION,
      featureFlags: PROTOCOL_FEATURE_FLAGS
    }, options.clock, PROTOCOL_VERSION)));
    return;
  }

  const idempotencyKey = await computeIdempotencyKey(options, sessionId, envelope);
  if (idempotencyKey) {
    pruneIdempotencyCache(idempotencyCache, options.clock.now());
    const cached = idempotencyCache.get(idempotencyKey);
    if (cached) {
      for (const response of cached.responses) {
        socket.send(JSON.stringify(cloneEnvelope(response)));
      }
      return;
    }
  }

  const rateLimit = options.rateLimiter.check(sessionId, envelope.op, options.clock.now());
  if (!rateLimit.ok) {
    socket.send(JSON.stringify(envelopeFor(envelope.id, ServerOps.SystemRateLimit, {
      op: envelope.op,
      code: rateLimit.code,
      bucketRemaining: rateLimit.remaining,
      resetMs: rateLimit.resetMs
    }, options.clock, version.value)));
    return;
  }

  const headers = validateWriteEnvelopeHeaders(envelope.op, envelope);
  if (!headers.ok) {
    sendError(socket, envelope.id, headers.code, headers.message, false, options.clock, version.value);
    return;
  }

  const responses = await router.dispatch({ sessionId, envelope });
  if (idempotencyKey) {
    idempotencyCache.set(idempotencyKey, {
      storedAt: options.clock.now(),
      responses: responses.map((response) => cloneEnvelope(response))
    });
  }
  for (const response of responses) {
    socket.send(JSON.stringify(response));
  }
}

async function computeIdempotencyKey(options: M3WebSocketGatewayOptions, sessionId: string, envelope: Envelope): Promise<string | undefined> {
  const token = envelope.clientToken?.trim();
  if (!token) {
    return undefined;
  }
  const session = await options.sessions.get(sessionId);
  const ownerId = session?.playerId ?? sessionId;
  return `${ownerId}:${token}`;
}

function pruneIdempotencyCache(cache: Map<string, IdempotencyCacheEntry>, now: number): void {
  for (const [key, value] of cache) {
    if (now - value.storedAt >= IDEMPOTENCY_TTL_MS) {
      cache.delete(key);
    }
  }
  while (cache.size > IDEMPOTENCY_MAX_ENTRIES) {
    const oldest = cache.keys().next().value as string | undefined;
    if (!oldest) {
      return;
    }
    cache.delete(oldest);
  }
}

function cloneEnvelope(response: Envelope): Envelope {
  return {
    ...response,
    payload: structuredClone(response.payload)
  };
}

function sendError(socket: WebSocket, id: number, code: string, message: string, retryable: boolean, clock: Clock, protocolVersion = PROTOCOL_VERSION): void {
  socket.send(JSON.stringify(envelopeFor(id, ServerOps.WorldError, { code, message, retryable }, clock, protocolVersion)));
}

function envelope(id: number, op: string, payload: unknown, clock: Clock): Envelope {
  return envelopeFor(id, op, payload, clock, PROTOCOL_VERSION);
}

function envelopeFor(id: number, op: string, payload: unknown, clock: Clock, protocolVersion: number): Envelope {
  return { id, op, payload, ts: clock.now(), protocolVersion };
}

function rawDataToString(data: RawData): string {
  if (typeof data === 'string') {
    return data;
  }
  if (Buffer.isBuffer(data)) {
    return data.toString('utf8');
  }
  if (data instanceof ArrayBuffer) {
    return Buffer.from(data).toString('utf8');
  }
  return Buffer.concat(data).toString('utf8');
}

function waitForListening(wss: WebSocketServer): Promise<void> {
  return new Promise((resolve, reject) => {
    if (wss.address()) {
      resolve();
      return;
    }
    wss.once('listening', resolve);
    wss.once('error', reject);
  });
}

async function waitForSessionId(getSessionId: () => string | undefined): Promise<void> {
  const startedAt = Date.now();
  while (Date.now() - startedAt < 1000) {
    if (getSessionId()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 1));
  }
  throw new Error('SESSION_CREATE_TIMEOUT');
}

interface InventoryItem {
  itemId: string;
  type: string;
  amount: number;
  meta: Record<string, unknown>;
}

interface InventoryState {
  capacity: number;
  gold: number;
  items: InventoryItem[];
}

interface EquippedState {
  weapon?: string;
  armor?: string;
  trinkets: string[];
}

interface EquipmentState {
  equipped: EquippedState;
  loadouts: Record<string, { loadoutId: string; name: string; equipped: EquippedState }>;
}

interface RitualRequestState {
  requestId: string;
  playerId: string;
  ritualId: string;
  expectedMaterials: MaterialInput[];
}

type QuestStatus = 'available' | 'active' | 'completed' | 'turned_in';
type QuestObjectiveReason =
  | 'enemy_killed'
  | 'material_collected'
  | 'ritual_completed'
  | 'area_explored'
  | 'npc_talked'
  | 'forge_completed'
  | 'transformation_done';

interface QuestObjectiveTemplate {
  index: number;
  description: string;
  required: number;
  reason: QuestObjectiveReason;
  targetEntityId: string;
  action: string;
}

interface QuestObjectiveSnapshot {
  index: number;
  description: string;
  current: number;
  required: number;
  reason: QuestObjectiveReason;
}

interface RewardSnapshot {
  exp: number;
  gold: number;
  items: InventoryItem[];
}

interface QuestTemplate {
  questId: string;
  title: string;
  description: string;
  objectives: QuestObjectiveTemplate[];
  rewards: RewardSnapshot;
}

interface QuestRecord {
  questId: string;
  title: string;
  description: string;
  status: QuestStatus;
  objectives: QuestObjectiveSnapshot[];
  rewards?: RewardSnapshot;
}

interface QuestLogState {
  records: Map<string, QuestRecord>;
}

interface TransformationState {
  active: boolean;
  speciesId?: string;
  depth?: TransformationDepth;
  remainingMs?: number;
  suspicions: Record<string, number>;
  reputations: Record<string, number>;
}

interface TransformationSpeciesTemplate {
  speciesId: string;
  unlockedDepths: TransformationDepth[];
  durationMs: number;
  feedSuspicionGain: number;
  watcherNpcId: string;
}

interface AbilityGrant {
  abilityId: string;
  skillId: string;
  pathwayId: string;
  sequence: number;
}

interface PathwayRecord {
  pathwayId: string;
  sequence: number;
  sanity: number;
  abnormalities: number;
  unlockedAbilityIds: string[];
}

interface PathwayState {
  records: Map<string, PathwayRecord>;
}

interface SkillTemplate {
  skillId: string;
  pathwaySource: string;
}

interface SkillState {
  learned: Set<string>;
  loadouts: Map<string, string[]>;
  activeLoadoutId: string;
}

interface BuildBlueprintTemplate {
  blueprintId: string;
  visualId: string;
}

interface BuildStructureState {
  structureEntityId: string;
  shardId: string;
  mapId: string;
  ownerPlayerId: string;
  blueprintId: string;
  visualId: string;
  position: GridPosition;
  facing: Direction;
}

interface ShopOfferState {
  itemId: string;
  price: number;
  stock: number;
  itemType: string;
  meta: Record<string, unknown>;
}

interface ShopState {
  shopEntityId: string;
  open: boolean;
  offers: Map<string, ShopOfferState>;
  buybackPrices: Record<string, number>;
}

type ShopTransactionPayload = {
  shopEntityId: string;
  itemId: string;
  amount: number;
};

type ShopTransactionResult =
  | { ok: true; shopEntityId: string; itemId: string; amount: number; goldDelta: number }
  | { ok: false; shopEntityId: string; itemId: string; amount: number; goldDelta: 0; code: string; message: string };

const DEFAULT_INVENTORY_ITEMS: InventoryItem[] = [
  { itemId: 'moonlight_grass', type: 'material', amount: 3, meta: { locked: false } },
  { itemId: 'flame_sword', type: 'weapon', amount: 1, meta: { slot: 'weapon', equippable: true, rarity: 'rare' } },
  { itemId: 'mist_iron_ore', type: 'material', amount: 2, meta: { locked: false } }
];

const QUEST_TEMPLATES: QuestTemplate[] = [
  {
    questId: 'mist-harbor-field-aid',
    title: 'Mist Harbor Field Aid',
    description: 'Help stabilize the harbor by collecting a field resource.',
    objectives: [
      {
        index: 0,
        description: 'Collect weathered wood from the nearby tree',
        required: 1,
        reason: 'material_collected',
        targetEntityId: 'tree-1',
        action: 'chop'
      }
    ],
    rewards: {
      exp: 10,
      gold: 5,
      items: [
        { itemId: 'moonlight_grass', type: 'material', amount: 1, meta: { source: 'quest_reward' } }
      ]
    }
  }
];

const TRANSFORMATION_SPECIES: TransformationSpeciesTemplate[] = [
  {
    speciesId: 'mist-wolf',
    unlockedDepths: ['disguise'],
    durationMs: 30000,
    feedSuspicionGain: 50,
    watcherNpcId: 'mist-harbor-guard'
  }
];
const TRANSFORMATION_EXPOSE_THRESHOLD = 100;
const PATHWAY_POTION_ITEM_ID = 'moonlight_grass';
const PATHWAY_ABILITY_GRANTS: AbilityGrant[] = [
  { abilityId: 'mist-step', skillId: 'mist-step', pathwayId: 'tide_priestess', sequence: 8 }
];
const SKILL_TEMPLATES: SkillTemplate[] = [
  { skillId: 'mist-step', pathwaySource: 'tide_priestess' }
];
const BUILD_BLUEPRINTS: BuildBlueprintTemplate[] = [
  { blueprintId: 'fog_lattice', visualId: 'fog_lattice' }
];

const PARTY_MEMBERS: Record<string, string[]> = {
  'party-alpha': ['player-chat-a', 'player-chat-b', 'player-webqa']
};

function getInventory(inventories: Map<string, InventoryState>, playerId: string): InventoryState {
  let inventory = inventories.get(playerId);
  if (!inventory) {
    inventory = {
      capacity: 40,
      gold: 25,
      items: DEFAULT_INVENTORY_ITEMS.map((item) => cloneInventoryItem(item))
    };
    inventories.set(playerId, inventory);
  }
  return inventory;
}

function inventorySnapshot(inventory: InventoryState): { ok: true; items: InventoryItem[]; capacity: number; gold: number } {
  return {
    ok: true,
    items: inventory.items.filter((item) => item.amount > 0).map((item) => cloneInventoryItem(item)),
    capacity: inventory.capacity,
    gold: inventory.gold
  };
}

function cloneInventoryItem(item: InventoryItem): InventoryItem {
  return {
    itemId: item.itemId,
    type: item.type,
    amount: item.amount,
    meta: { ...item.meta }
  };
}

function hasMaterials(inventory: InventoryState, inputs: MaterialInput[]): boolean {
  const required = aggregateMaterials(inputs);
  for (const [itemId, amount] of required) {
    const item = inventory.items.find((candidate) => candidate.itemId === itemId);
    if (!item || item.amount < amount) {
      return false;
    }
  }
  return true;
}

function consumeMaterials(inventory: InventoryState, inputs: MaterialInput[]): MaterialInput[] {
  const consumed: MaterialInput[] = [];
  for (const [itemId, amount] of aggregateMaterials(inputs)) {
    const item = inventory.items.find((candidate) => candidate.itemId === itemId);
    if (!item) {
      continue;
    }
    item.amount = Math.max(0, item.amount - amount);
    consumed.push({ itemId, amount });
  }
  return consumed;
}

function aggregateMaterials(inputs: MaterialInput[]): Map<string, number> {
  const totals = new Map<string, number>();
  for (const input of inputs) {
    totals.set(input.itemId, (totals.get(input.itemId) ?? 0) + input.amount);
  }
  return totals;
}

function createForgeWeapon(requestId: string): InventoryItem {
  return {
    itemId: 'forged_fog_blade',
    type: 'weapon',
    amount: 1,
    meta: { source: 'forge_stub', requestId }
  };
}

function addInventoryItem(inventory: InventoryState, item: InventoryItem): void {
  const existing = inventory.items.find((candidate) => candidate.itemId === item.itemId);
  if (existing) {
    existing.amount += item.amount;
    existing.type = item.type;
    existing.meta = { ...existing.meta, ...item.meta };
    return;
  }
  inventory.items.push(cloneInventoryItem(item));
}

function initializeShopStates(): Map<string, ShopState> {
  const shop: ShopState = {
    shopEntityId: 'mist-harbor-general-store',
    open: true,
    offers: new Map([
      ['harbor_charm', {
        itemId: 'harbor_charm',
        price: 6,
        stock: 1,
        itemType: 'trinket',
        meta: { slot: 'trinket', equippable: true, source: 'mist-harbor-general-store' }
      }]
    ]),
    buybackPrices: { harbor_charm: 3 }
  };
  return new Map([[shop.shopEntityId, shop]]);
}

function shopSnapshot(shop: ShopState): { ok: true; shopEntityId: string; offers: Array<{ itemId: string; price: number; stock: number }>; buybackPrices: Record<string, number> } {
  return {
    ok: true,
    shopEntityId: shop.shopEntityId,
    offers: [...shop.offers.values()].map((offer) => ({ itemId: offer.itemId, price: offer.price, stock: offer.stock })),
    buybackPrices: { ...shop.buybackPrices }
  };
}

function buyFromShop(shops: Map<string, ShopState>, inventory: InventoryState, payload: ShopTransactionPayload): ShopTransactionResult {
  const shop = shops.get(payload.shopEntityId);
  if (!shop || !shop.open) {
    return shopTransactionFailure(payload.shopEntityId, payload.itemId, payload.amount, 'SHOP_CLOSED', 'Shop is not open');
  }
  const offer = shop.offers.get(payload.itemId);
  if (!offer) {
    return shopTransactionFailure(payload.shopEntityId, payload.itemId, payload.amount, 'ITEM_NOT_BUYABLE', `Item ${payload.itemId} is not buyable`);
  }
  if (offer.stock < payload.amount) {
    return shopTransactionFailure(payload.shopEntityId, payload.itemId, payload.amount, 'OUT_OF_STOCK', `Item ${payload.itemId} is out of stock`);
  }
  const totalPrice = offer.price * payload.amount;
  if (inventory.gold < totalPrice) {
    return shopTransactionFailure(payload.shopEntityId, payload.itemId, payload.amount, 'INSUFFICIENT_GOLD', 'Inventory gold is insufficient');
  }
  inventory.gold -= totalPrice;
  offer.stock -= payload.amount;
  addInventoryItem(inventory, {
    itemId: offer.itemId,
    type: offer.itemType,
    amount: payload.amount,
    meta: { ...offer.meta }
  });
  return {
    ok: true,
    shopEntityId: payload.shopEntityId,
    itemId: payload.itemId,
    amount: payload.amount,
    goldDelta: -totalPrice
  };
}

function sellToShop(shops: Map<string, ShopState>, inventory: InventoryState, payload: ShopTransactionPayload): ShopTransactionResult {
  const shop = shops.get(payload.shopEntityId);
  if (!shop || !shop.open) {
    return shopTransactionFailure(payload.shopEntityId, payload.itemId, payload.amount, 'SHOP_CLOSED', 'Shop is not open');
  }
  const buybackPrice = shop.buybackPrices[payload.itemId];
  if (!Number.isFinite(buybackPrice) || buybackPrice <= 0) {
    return shopTransactionFailure(payload.shopEntityId, payload.itemId, payload.amount, 'ITEM_NOT_BUYABLE', `Item ${payload.itemId} cannot be sold here`);
  }
  const item = inventory.items.find((candidate) => candidate.itemId === payload.itemId);
  if (!item || item.amount < payload.amount) {
    return shopTransactionFailure(payload.shopEntityId, payload.itemId, payload.amount, 'ITEM_NOT_BUYABLE', `Inventory does not contain enough ${payload.itemId}`);
  }
  item.amount -= payload.amount;
  inventory.gold += buybackPrice * payload.amount;
  const offer = shop.offers.get(payload.itemId);
  if (offer) {
    offer.stock += payload.amount;
  }
  return {
    ok: true,
    shopEntityId: payload.shopEntityId,
    itemId: payload.itemId,
    amount: payload.amount,
    goldDelta: buybackPrice * payload.amount
  };
}

function shopTransactionFailure(shopEntityId: string, itemId: string, amount: number, code: string, message: string): ShopTransactionResult {
  return {
    ok: false,
    shopEntityId,
    itemId,
    amount,
    goldDelta: 0,
    code,
    message
  };
}

function getQuestLog(quests: Map<string, QuestLogState>, playerId: string): QuestLogState {
  let state = quests.get(playerId);
  if (!state) {
    state = { records: new Map<string, QuestRecord>() };
    quests.set(playerId, state);
  }
  return state;
}

function questSnapshot(log: QuestLogState): { ok: true; quests: QuestRecord[] } {
  return {
    ok: true,
    quests: QUEST_TEMPLATES.map((template) => cloneQuestRecord(log.records.get(template.questId) ?? availableQuestRecord(template)))
  };
}

function acceptQuest(log: QuestLogState, questId: string): { ok: true; record: QuestRecord } | QuestCommandError {
  const template = findQuestTemplate(questId);
  if (!template) {
    return questCommandError('QUEST_NOT_FOUND', `Quest ${questId} was not found`);
  }
  const existing = log.records.get(questId);
  if (existing?.status === 'turned_in') {
    return questCommandError('QUEST_ALREADY_TURNED_IN', `Quest ${questId} has already been turned in`);
  }
  if (existing && (existing.status === 'active' || existing.status === 'completed')) {
    return { ok: true, record: cloneQuestRecord(existing) };
  }
  const record = activeQuestRecord(template);
  log.records.set(questId, record);
  return { ok: true, record: cloneQuestRecord(record) };
}

function turnInQuest(log: QuestLogState, questId: string): { ok: true; record: QuestRecord; rewards: RewardSnapshot } | QuestCommandError {
  const template = findQuestTemplate(questId);
  if (!template) {
    return questCommandError('QUEST_NOT_FOUND', `Quest ${questId} was not found`);
  }
  const record = log.records.get(questId);
  if (!record || record.status === 'available') {
    return questCommandError('QUEST_NOT_ACTIVE', `Quest ${questId} is not active`);
  }
  if (record.status === 'turned_in') {
    return questCommandError('QUEST_ALREADY_TURNED_IN', `Quest ${questId} has already been turned in`);
  }
  if (!questObjectivesComplete(record)) {
    return questCommandError('QUEST_OBJECTIVES_INCOMPLETE', `Quest ${questId} objectives are incomplete`);
  }
  record.status = 'turned_in';
  record.rewards = cloneRewards(template.rewards);
  log.records.set(questId, record);
  return { ok: true, record: cloneQuestRecord(record), rewards: cloneRewards(template.rewards) };
}

function abandonQuest(log: QuestLogState, questId: string): { ok: true; payload: Record<string, unknown> } | QuestCommandError {
  const template = findQuestTemplate(questId);
  if (!template) {
    return questCommandError('QUEST_NOT_FOUND', `Quest ${questId} was not found`);
  }
  const record = log.records.get(questId);
  if (!record || record.status === 'available') {
    return questCommandError('QUEST_NOT_ACTIVE', `Quest ${questId} is not active`);
  }
  if (record.status === 'turned_in') {
    return questCommandError('QUEST_ALREADY_TURNED_IN', `Quest ${questId} has already been turned in`);
  }
  log.records.delete(questId);
  const available = availableQuestRecord(template);
  return { ok: true, payload: questDeltaPayload(available) };
}

function advanceQuestProgress(
  quests: Map<string, QuestLogState>,
  playerId: string,
  entityId: string,
  action: string
): ServerMessage[] {
  const log = quests.get(playerId);
  if (!log) {
    return [];
  }
  const messages: ServerMessage[] = [];
  for (const record of log.records.values()) {
    if (record.status !== 'active') {
      continue;
    }
    const template = findQuestTemplate(record.questId);
    if (!template) {
      continue;
    }
    for (const objectiveTemplate of template.objectives) {
      if (objectiveTemplate.targetEntityId !== entityId || objectiveTemplate.action !== action) {
        continue;
      }
      const objective = record.objectives.find((candidate) => candidate.index === objectiveTemplate.index);
      if (!objective || objective.current >= objective.required) {
        continue;
      }
      objective.current = Math.min(objective.required, objective.current + 1);
      messages.push({
        op: ServerOps.QuestObjectiveProgress,
        payload: {
          questId: record.questId,
          objectiveIndex: objective.index,
          current: objective.current,
          required: objective.required,
          reason: objective.reason
        }
      });
      if (questObjectivesComplete(record)) {
        record.status = 'completed';
        messages.push({ op: ServerOps.QuestDelta, payload: questDeltaPayload(record) });
      }
    }
    log.records.set(record.questId, record);
  }
  return messages;
}

function applyQuestRewards(inventory: InventoryState, rewards: RewardSnapshot): void {
  inventory.gold += rewards.gold;
  for (const item of rewards.items) {
    addInventoryItem(inventory, item);
  }
}

interface QuestCommandError {
  ok: false;
  code: 'QUEST_NOT_FOUND' | 'QUEST_PREREQ_NOT_MET' | 'QUEST_NOT_ACTIVE' | 'QUEST_OBJECTIVES_INCOMPLETE' | 'QUEST_ALREADY_TURNED_IN';
  message: string;
}

function questCommandError(code: QuestCommandError['code'], message: string): QuestCommandError {
  return { ok: false, code, message };
}

function questDeltaPayload(record: QuestRecord): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    ok: true,
    questId: record.questId,
    status: record.status,
    objectives: record.objectives.map((objective) => ({ ...objective }))
  };
  if (record.rewards) {
    payload.rewards = cloneRewards(record.rewards);
  }
  return payload;
}

function findQuestTemplate(questId: string): QuestTemplate | undefined {
  return QUEST_TEMPLATES.find((template) => template.questId === questId);
}

function availableQuestRecord(template: QuestTemplate): QuestRecord {
  return {
    questId: template.questId,
    title: template.title,
    description: template.description,
    status: 'available',
    objectives: template.objectives.map((objective) => ({
      index: objective.index,
      description: objective.description,
      current: 0,
      required: objective.required,
      reason: objective.reason
    }))
  };
}

function activeQuestRecord(template: QuestTemplate): QuestRecord {
  return {
    ...availableQuestRecord(template),
    status: 'active'
  };
}

function questObjectivesComplete(record: QuestRecord): boolean {
  return record.objectives.every((objective) => objective.current >= objective.required);
}

function cloneQuestRecord(record: QuestRecord): QuestRecord {
  const clone: QuestRecord = {
    questId: record.questId,
    title: record.title,
    description: record.description,
    status: record.status,
    objectives: record.objectives.map((objective) => ({ ...objective }))
  };
  if (record.rewards) {
    clone.rewards = cloneRewards(record.rewards);
  }
  return clone;
}

function cloneRewards(rewards: RewardSnapshot): RewardSnapshot {
  return {
    exp: rewards.exp,
    gold: rewards.gold,
    items: rewards.items.map((item) => cloneInventoryItem(item))
  };
}

function getTransformationState(transformations: Map<string, TransformationState>, playerId: string): TransformationState {
  let state = transformations.get(playerId);
  if (!state) {
    state = {
      active: false,
      suspicions: { 'mist-harbor-guard': 0 },
      reputations: { 'mist-wolf': 0 }
    };
    transformations.set(playerId, state);
  }
  return state;
}

function startTransformation(
  transformations: Map<string, TransformationState>,
  playerId: string,
  speciesId: string,
  depth: TransformationDepth,
  nowMs: number
): { ok: true; state: TransformationState } | TransformationCommandError {
  const template = findTransformationSpecies(speciesId);
  if (!template) {
    return transformationCommandError('SPECIES_UNKNOWN', `Transformation species ${speciesId} was not found`);
  }
  if (!template.unlockedDepths.includes(depth)) {
    return transformationCommandError('DEPTH_NOT_UNLOCKED', `Transformation depth ${depth} is not unlocked`);
  }
  const state = getTransformationState(transformations, playerId);
  state.active = true;
  state.speciesId = speciesId;
  state.depth = depth;
  state.remainingMs = template.durationMs;
  state.suspicions[template.watcherNpcId] = state.suspicions[template.watcherNpcId] ?? 0;
  state.reputations[speciesId] = state.reputations[speciesId] ?? 0;
  transformations.set(playerId, state);
  void nowMs;
  return { ok: true, state: cloneTransformationState(state) };
}

function feedTransformation(
  transformations: Map<string, TransformationState>,
  playerId: string,
  itemId: string,
  amount: number
): { ok: true; state: TransformationState; suspicion: TransformationSuspicionChanged; exposed?: TransformationExposed } | TransformationCommandError {
  const state = getTransformationState(transformations, playerId);
  if (!state.active || !state.speciesId) {
    return transformationCommandError('TRANSFORMATION_NOT_ACTIVE', 'Transformation is not active');
  }
  if (itemId !== 'moonlight_grass') {
    return transformationCommandError('MATERIALS_INSUFFICIENT', `Transformation cannot consume ${itemId}`);
  }
  const template = findTransformationSpecies(state.speciesId);
  if (!template) {
    return transformationCommandError('SPECIES_UNKNOWN', `Transformation species ${state.speciesId} was not found`);
  }
  const before = state.suspicions[template.watcherNpcId] ?? 0;
  const after = Math.min(TRANSFORMATION_EXPOSE_THRESHOLD, before + template.feedSuspicionGain * amount);
  state.suspicions[template.watcherNpcId] = after;
  state.remainingMs = Math.max(0, (state.remainingMs ?? template.durationMs) + 5000 * amount);
  const suspicion: TransformationSuspicionChanged = {
    npcId: template.watcherNpcId,
    before,
    after,
    reason: 'consumed'
  };
  let exposed: TransformationExposed | undefined;
  if (after >= TRANSFORMATION_EXPOSE_THRESHOLD) {
    exposed = {
      speciesId: state.speciesId,
      reason: 'suspicion_overflow'
    };
    state.active = false;
    state.remainingMs = 0;
    state.reputations[state.speciesId] = (state.reputations[state.speciesId] ?? 0) - 1;
  }
  transformations.set(playerId, state);
  return { ok: true, state: cloneTransformationState(state), suspicion, exposed };
}

function endTransformation(
  transformations: Map<string, TransformationState>,
  playerId: string,
  reason: string
): { ok: true; state: TransformationState } | TransformationCommandError {
  const state = getTransformationState(transformations, playerId);
  if (!state.active) {
    return transformationCommandError('TRANSFORMATION_NOT_ACTIVE', 'Transformation is not active');
  }
  state.active = false;
  state.remainingMs = 0;
  void reason;
  transformations.set(playerId, state);
  return { ok: true, state: cloneTransformationState(state) };
}

interface TransformationSuspicionChanged {
  npcId: string;
  before: number;
  after: number;
  reason: 'spotted' | 'decay' | 'consumed';
}

interface TransformationExposed {
  speciesId: string;
  reason: 'suspicion_overflow' | 'forced_combat' | 'hostile_action';
}

interface TransformationCommandError {
  ok: false;
  code: 'SPECIES_UNKNOWN' | 'DEPTH_NOT_UNLOCKED' | 'MATERIALS_INSUFFICIENT' | 'COOLDOWN_NOT_READY' | 'TRANSFORMATION_NOT_ACTIVE';
  message: string;
}

function transformationCommandError(code: TransformationCommandError['code'], message: string): TransformationCommandError {
  return { ok: false, code, message };
}

function transformationStatePayload(state: TransformationState): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    active: state.active,
    suspicions: { ...state.suspicions },
    reputations: { ...state.reputations }
  };
  if (state.speciesId) {
    payload.speciesId = state.speciesId;
  }
  if (state.depth) {
    payload.depth = state.depth;
  }
  if (state.remainingMs !== undefined) {
    payload.remainingMs = state.remainingMs;
  }
  return payload;
}

function cloneTransformationState(state: TransformationState): TransformationState {
  const clone: TransformationState = {
    active: state.active,
    suspicions: { ...state.suspicions },
    reputations: { ...state.reputations }
  };
  if (state.speciesId) {
    clone.speciesId = state.speciesId;
  }
  if (state.depth) {
    clone.depth = state.depth;
  }
  if (state.remainingMs !== undefined) {
    clone.remainingMs = state.remainingMs;
  }
  return clone;
}

function findTransformationSpecies(speciesId: string): TransformationSpeciesTemplate | undefined {
  return TRANSFORMATION_SPECIES.find((template) => template.speciesId === speciesId);
}

function getPathwayState(pathways: Map<string, PathwayState>, playerId: string): PathwayState {
  let state = pathways.get(playerId);
  if (!state) {
    state = {
      records: new Map<string, PathwayRecord>([
        ['tide_priestess', {
          pathwayId: 'tide_priestess',
          sequence: 9,
          sanity: 0,
          abnormalities: 0,
          unlockedAbilityIds: []
        }]
      ])
    };
    pathways.set(playerId, state);
  }
  return state;
}

function pathwaySnapshot(state: PathwayState): { ok: true; sequences: PathwayRecord[] } {
  return {
    ok: true,
    sequences: Array.from(state.records.values()).map((record) => clonePathwayRecord(record))
  };
}

function advancePathway(
  state: PathwayState,
  payload: { pathwayId: string; targetSequence: number; potionItemId: string }
): { ok: true; record: PathwayRecord; rewards: AbilityGrant[] } | PathwayCommandError {
  const record = state.records.get(payload.pathwayId);
  if (!record) {
    return pathwayCommandError('PATHWAY_UNKNOWN', `Pathway ${payload.pathwayId} was not found`);
  }
  if (payload.potionItemId !== PATHWAY_POTION_ITEM_ID) {
    return pathwayCommandError('POTION_INVALID', `Pathway potion ${payload.potionItemId} is invalid`);
  }
  if (payload.targetSequence !== record.sequence - 1) {
    return pathwayCommandError('SEQUENCE_LOCKED', `Pathway target sequence ${payload.targetSequence} is locked`);
  }
  record.sequence = payload.targetSequence;
  record.sanity += 12;
  record.abnormalities += 1;
  const rewards = PATHWAY_ABILITY_GRANTS
    .filter((grant) => grant.pathwayId === record.pathwayId && grant.sequence === record.sequence)
    .map((grant) => ({ ...grant }));
  for (const reward of rewards) {
    if (!record.unlockedAbilityIds.includes(reward.abilityId)) {
      record.unlockedAbilityIds.push(reward.abilityId);
    }
  }
  state.records.set(record.pathwayId, record);
  return { ok: true, record: clonePathwayRecord(record), rewards };
}

function pathwayDeltaPayload(record: PathwayRecord, rewards: AbilityGrant[]): Record<string, unknown> {
  return {
    ok: true,
    pathwayId: record.pathwayId,
    sequence: record.sequence,
    sanity: record.sanity,
    abnormalities: record.abnormalities,
    rewards: rewards.map((reward) => ({ ...reward }))
  };
}

function pathwayUnlockPayload(record: PathwayRecord, rewards: AbilityGrant[]): Record<string, unknown> {
  return {
    pathwayId: record.pathwayId,
    sequence: record.sequence,
    abilityIds: rewards.map((reward) => reward.abilityId)
  };
}

interface PathwayCommandError {
  ok: false;
  code: 'PATHWAY_UNKNOWN' | 'SEQUENCE_LOCKED' | 'SANITY_OVERFLOW' | 'POTION_INVALID' | 'RITUAL_REQUIREMENT_MISSING';
  message: string;
}

function pathwayCommandError(code: PathwayCommandError['code'], message: string): PathwayCommandError {
  return { ok: false, code, message };
}

function clonePathwayRecord(record: PathwayRecord): PathwayRecord {
  return {
    pathwayId: record.pathwayId,
    sequence: record.sequence,
    sanity: record.sanity,
    abnormalities: record.abnormalities,
    unlockedAbilityIds: [...record.unlockedAbilityIds]
  };
}

function getSkillState(skills: Map<string, SkillState>, playerId: string): SkillState {
  let state = skills.get(playerId);
  if (!state) {
    state = {
      learned: new Set<string>(),
      loadouts: new Map<string, string[]>([['default', []]]),
      activeLoadoutId: 'default'
    };
    skills.set(playerId, state);
  }
  return state;
}

function learnSkill(
  state: SkillState,
  skillId: string,
  pathwaySource: string
): { ok: true; state: SkillState; added: boolean } | SkillCommandError {
  const template = findSkillTemplate(skillId);
  if (!template) {
    return skillCommandError('SKILL_UNKNOWN', `Skill ${skillId} was not found`);
  }
  if (template.pathwaySource !== pathwaySource) {
    return skillCommandError('SKILL_PREREQ_NOT_MET', `Skill ${skillId} does not belong to ${pathwaySource}`);
  }
  const added = !state.learned.has(skillId);
  state.learned.add(skillId);
  return { ok: true, state: cloneSkillState(state), added };
}

function equipSkillLoadout(
  state: SkillState,
  loadoutId: string,
  skillIds: string[]
): { ok: true; state: SkillState } | SkillCommandError {
  if (skillIds.length > 5) {
    return skillCommandError('LOADOUT_FULL', `Skill loadout ${loadoutId} has too many skills`);
  }
  for (const skillId of skillIds) {
    if (!state.learned.has(skillId)) {
      return skillCommandError('SKILL_PREREQ_NOT_MET', `Skill ${skillId} has not been learned`);
    }
  }
  state.loadouts.set(loadoutId, [...skillIds]);
  state.activeLoadoutId = loadoutId;
  return { ok: true, state: cloneSkillState(state) };
}

function skillSnapshot(state: SkillState): { ok: true; learned: string[]; loadouts: Record<string, string[]>; activeLoadoutId: string } {
  const loadouts: Record<string, string[]> = {};
  for (const [loadoutId, skillIds] of state.loadouts) {
    loadouts[loadoutId] = [...skillIds];
  }
  return {
    ok: true,
    learned: Array.from(state.learned).sort(),
    loadouts,
    activeLoadoutId: state.activeLoadoutId
  };
}

interface SkillCommandError {
  ok: false;
  code: 'SKILL_UNKNOWN' | 'SKILL_PREREQ_NOT_MET' | 'LOADOUT_FULL';
  message: string;
}

function skillCommandError(code: SkillCommandError['code'], message: string): SkillCommandError {
  return { ok: false, code, message };
}

function findSkillTemplate(skillId: string): SkillTemplate | undefined {
  return SKILL_TEMPLATES.find((template) => template.skillId === skillId);
}

function cloneSkillState(state: SkillState): SkillState {
  return {
    learned: new Set<string>(state.learned),
    loadouts: new Map<string, string[]>(Array.from(state.loadouts.entries()).map(([loadoutId, skillIds]) => [loadoutId, [...skillIds]])),
    activeLoadoutId: state.activeLoadoutId
  };
}

type BuildPlaceResult =
  | { ok: true; requestId: string; structure: BuildStructureState }
  | { ok: false; requestId: string; code: BuildCommandErrorCode; message: string; refunded: MaterialInput[] };

type BuildCommandErrorCode =
  | 'POSITION_BLOCKED'
  | 'BLUEPRINT_UNKNOWN'
  | 'OUT_OF_FOOTPRINT'
  | 'OUT_OF_REGION'
  | 'BUILD_BUSY'
  | 'DSL_INVALID'
  | 'BUILD_INPUTS_INSUFFICIENT';

function placeBuildStructure(
  builds: Map<string, BuildStructureState>,
  inventory: InventoryState,
  shardId: string,
  ownerPlayerId: string,
  payload: BuildPlaceRequestPayload
): BuildPlaceResult {
  const requestId = `build-${randomUUID()}`;
  const blueprint = findBuildBlueprint(payload.blueprintId);
  if (!blueprint) {
    return buildCommandError(requestId, 'BLUEPRINT_UNKNOWN', `Build blueprint ${payload.blueprintId} was not found`, payload.inputs);
  }
  if (isBuildPositionOccupied(builds, shardId, payload.position)) {
    return buildCommandError(requestId, 'POSITION_BLOCKED', 'Position is already occupied', payload.inputs);
  }
  if (!hasMaterials(inventory, payload.inputs)) {
    return buildCommandError(requestId, 'BUILD_INPUTS_INSUFFICIENT', 'Build inputs are insufficient', []);
  }
  consumeMaterials(inventory, payload.inputs);
  const structure: BuildStructureState = {
    structureEntityId: `build-structure-${randomUUID()}`,
    shardId,
    mapId: 'mist-harbor-test',
    ownerPlayerId,
    blueprintId: payload.blueprintId,
    visualId: blueprint.visualId,
    position: { ...payload.position },
    facing: payload.facing
  };
  builds.set(structure.structureEntityId, structure);
  return { ok: true, requestId, structure };
}

function buildCommandError(requestId: string, code: BuildCommandErrorCode, message: string, refunded: MaterialInput[]): BuildPlaceResult {
  return {
    ok: false,
    requestId,
    code,
    message,
    refunded: refunded.map((input) => ({ ...input }))
  };
}

function findBuildBlueprint(blueprintId: string): BuildBlueprintTemplate | undefined {
  return BUILD_BLUEPRINTS.find((template) => template.blueprintId === blueprintId);
}

function isBuildPositionOccupied(builds: Map<string, BuildStructureState>, shardId: string, position: GridPosition): boolean {
  for (const structure of builds.values()) {
    if (structure.shardId === shardId && structure.position.x === position.x && structure.position.y === position.y) {
      return true;
    }
  }
  return false;
}

function buildWorldAlterationPayload(structure: BuildStructureState): Record<string, unknown> {
  return {
    structureEntityId: structure.structureEntityId,
    mapId: structure.mapId,
    position: { ...structure.position },
    visualId: structure.visualId,
    ownerPlayerId: structure.ownerPlayerId
  };
}

function rememberShardPlayer(playersByShard: Map<string, Set<string>>, shardId: string, playerId: string): void {
  let players = playersByShard.get(shardId);
  if (!players) {
    players = new Set<string>();
    playersByShard.set(shardId, players);
  }
  players.add(playerId);
}

function forgetShardPlayer(playersByShard: Map<string, Set<string>>, shardId: string, playerId: string): void {
  const players = playersByShard.get(shardId);
  if (!players) {
    return;
  }
  players.delete(playerId);
  if (players.size === 0) {
    playersByShard.delete(shardId);
  }
}

function shardPlayerIds(playersByShard: Map<string, Set<string>>, shardId: string, fallbackPlayerId: string): string[] {
  const players = playersByShard.get(shardId);
  if (!players || players.size === 0) {
    return [fallbackPlayerId];
  }
  return Array.from(players);
}

function partyMemberIds(partyId: string, fallbackPlayerId: string): string[] {
  return uniquePlayerIds(PARTY_MEMBERS[partyId] ?? [fallbackPlayerId]);
}

function uniquePlayerIds(playerIds: string[]): string[] {
  return Array.from(new Set(playerIds.filter((playerId) => playerId.trim().length > 0)));
}

function getEquipment(equipment: Map<string, EquipmentState>, playerId: string): EquipmentState {
  let state = equipment.get(playerId);
  if (!state) {
    state = {
      equipped: { trinkets: [] },
      loadouts: {
        default: {
          loadoutId: 'default',
          name: 'Default',
          equipped: { trinkets: [] }
        }
      }
    };
    equipment.set(playerId, state);
  }
  return state;
}

function equipmentSnapshot(state: EquipmentState): { ok: true; equipped: EquippedState; loadouts: EquipmentState['loadouts'] } {
  return {
    ok: true,
    equipped: cloneEquipped(state.equipped),
    loadouts: cloneLoadouts(state.loadouts)
  };
}

function itemMatchesEquipmentSlot(item: InventoryItem, slot: EquipmentSlot): boolean {
  if (slot === 'trinket') {
    return item.type === 'trinket' || item.type === 'accessory' || item.meta.slot === 'trinket';
  }
  return item.type === slot || item.meta.slot === slot;
}

function equipItem(state: EquipmentState, slot: EquipmentSlot, itemId: string): void {
  if (slot === 'trinket') {
    if (!state.equipped.trinkets.includes(itemId)) {
      state.equipped.trinkets.push(itemId);
    }
    return;
  }
  state.equipped[slot] = itemId;
}

function unequipItem(state: EquipmentState, slot: EquipmentSlot): void {
  if (slot === 'trinket') {
    state.equipped.trinkets = [];
    return;
  }
  delete state.equipped[slot];
}

function syncDefaultLoadout(state: EquipmentState, loadoutId = 'default'): void {
  const id = loadoutId.trim().length > 0 ? loadoutId : 'default';
  state.loadouts[id] = {
    loadoutId: id,
    name: id === 'default' ? 'Default' : id,
    equipped: cloneEquipped(state.equipped)
  };
}

function cloneEquipped(equipped: EquippedState): EquippedState {
  const clone: EquippedState = { trinkets: [...equipped.trinkets] };
  if (equipped.weapon) {
    clone.weapon = equipped.weapon;
  }
  if (equipped.armor) {
    clone.armor = equipped.armor;
  }
  return clone;
}

function cloneLoadouts(loadouts: EquipmentState['loadouts']): EquipmentState['loadouts'] {
  const cloned: EquipmentState['loadouts'] = {};
  for (const [loadoutId, loadout] of Object.entries(loadouts)) {
    cloned[loadoutId] = {
      loadoutId: loadout.loadoutId,
      name: loadout.name,
      equipped: cloneEquipped(loadout.equipped)
    };
  }
  return cloned;
}

function interruptActiveRitual(
  activeRituals: Map<string, RitualRequestState>,
  playerId: string,
  action: string
): { requestId: string; reason: 'attacked' } | undefined {
  if (!isAttackAction(action)) {
    return undefined;
  }
  const active = activeRituals.get(playerId);
  if (!active) {
    return undefined;
  }
  activeRituals.delete(playerId);
  return { requestId: active.requestId, reason: 'attacked' };
}

function isAttackAction(action: string): boolean {
  return action === 'attack' || action === 'basic_attack' || action === 'hostile_action';
}
