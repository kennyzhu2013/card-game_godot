import type { Envelope } from '../core/envelope.js';
import type {
  AoiVisibleProgression,
  Direction,
  GridPosition,
  PathwayId,
  PlayerProgressionState,
  ProgressionMilestone,
  SequenceBadge
} from '../world/types.js';
import { ClientOps, PROTOCOL_VERSION } from './ops.js';
import { asObject, invalid, nonEmptyString, type ValidationResult } from './validators/common.js';

export interface AuthLoginPayload {
  token: string;
  clientProtocolVersion?: number;
}

export interface AuthRefreshPayload {
  refreshToken: string;
  clientToken?: string;
}

export interface SystemPingPayload {
  tick?: number;
}

export interface WorldEnterPayload {
  shardId: string;
}

export interface WorldListShardsPayload {
}

export interface WorldListMapsPayload {
}

export interface InventoryFetchPayload {
}

export interface InventoryDiscardPayload {
  itemId: string;
  amount: number;
}

export interface EquipmentListPayload {
}

export type EquipmentSlot = 'weapon' | 'armor' | 'trinket';

export interface EquipmentEquipPayload {
  slot: EquipmentSlot;
  itemId: string;
  loadoutId?: string;
}

export interface EquipmentUnequipPayload {
  slot: EquipmentSlot;
}

export type ForgeMode = 'nl' | 'dsl';

export interface MaterialInput {
  itemId: string;
  amount: number;
}

export interface ForgeRequestPayload {
  stationEntityId: string;
  mode: ForgeMode;
  prompt?: string;
  dslSource?: string;
  inputs: MaterialInput[];
}

export interface ForgeCancelPayload {
  requestId: string;
}

export interface RitualStartPayload {
  altarEntityId: string;
  ritualId: string;
  expectedMaterials: MaterialInput[];
}

export interface RitualFeedPayload {
  requestId: string;
  itemId: string;
  amount: number;
}

export interface RitualCancelPayload {
  requestId: string;
}

export interface QuestListPayload {
}

export interface QuestIdPayload {
  questId: string;
}

export type TransformationDepth = 'disguise' | 'communion' | 'assimilation';
export type TransformationEndReason = 'manual' | 'timeout' | 'forced';

export interface TransformationStartPayload {
  speciesId: string;
  depth: TransformationDepth;
}

export interface TransformationFeedPayload {
  itemId: string;
  amount: number;
}

export interface TransformationEndPayload {
  reason: TransformationEndReason;
}

export interface PathwayListPayload {
}

export interface PathwayAdvanceRequestPayload {
  pathwayId: string;
  targetSequence: number;
  potionItemId: string;
  ritualSnapshotId?: string;
}

export interface PathwayConsumePotionPayload {
  potionItemId: string;
}

export interface SkillLearnPayload {
  skillId: string;
  pathwaySource: string;
}

export interface SkillEquipLoadoutPayload {
  loadoutId: string;
  skills: string[];
}

export interface BuildPlaceRequestPayload {
  workbenchEntityId: string;
  blueprintId: string;
  dslSource?: string;
  position: GridPosition;
  facing: Direction;
  inputs: MaterialInput[];
}

export interface BuildCancelPayload {
  requestId: string;
}

export interface BuildDismantlePayload {
  structureEntityId: string;
}

export interface ShopListPayload {
  shopEntityId: string;
}

export interface ShopBuyPayload {
  shopEntityId: string;
  itemId: string;
  amount: number;
}

export interface ShopSellPayload {
  shopEntityId: string;
  itemId: string;
  amount: number;
}

export interface ChatSayPayload {
  text: string;
}

export interface ChatWhisperPayload {
  targetPlayerId: string;
  text: string;
}

export interface ChatPartyPayload {
  partyId: string;
  text: string;
}

export interface WorldMovePayload {
  playerId: string;
  seq: number;
  from: GridPosition;
  to: GridPosition;
  startedAt: number;
}

export interface WorldInteractPayload {
  entityId: string;
  action: 'chop' | 'mine' | 'push' | 'inspect' | 'scout' | 'combat_check';
}

export type WorldSkillTargetType = 'self' | 'ally' | 'enemy' | 'ground_point' | 'entity_id' | 'none';

export interface WorldCastSkillPayload {
  abilityId: string;
  pathwayId: string;
  sequence: number;
  targetType: WorldSkillTargetType;
  targetEntityId?: string;
  targetGroundPosition?: GridPosition;
  clientPredictedSpawnedAt: number;
}

export interface CombatActionPayload {
  combatLockId: string;
  action: string;
  targetId?: string;
}

export type MonsterEvadeKind = 'sprint' | 'stealth' | 'transform';
export type MonsterRuntimeProtocolState = 'IDLE' | 'PATROL' | 'ALERT' | 'CHASE' | 'COMBAT_LOCKED' | 'DEAD';

export interface MonsterEvadePayload {
  shardId: string;
  monsterId: string;
  evadeKind: MonsterEvadeKind;
}

export interface MonsterAggroChangedPayload {
  shardId: string;
  monsterId: string;
  fromState: MonsterRuntimeProtocolState;
  toState: MonsterRuntimeProtocolState;
  threat: number;
  towardsPlayerId: string;
  tick: number;
}

export interface MonsterCombatPreludePayload {
  shardId: string;
  monsterId: string;
  monsterEntityIds: string[];
  leadTimeMs: number;
  escapeWindowMs: number;
}

export interface MonsterEvadeAckPayload {
  ok: boolean;
  code: string;
  reason: string;
}

export interface WorldTransferPayload {
  playerId: string;
  fromShardId: string;
  toShardId: string;
  toPosition: GridPosition;
  portalId?: string;
}

export interface ProgressionSubscribePayload {
  shardId: string;
}

export interface ProgressionAcknowledgeMilestonePayload {
  milestoneId: string;
}

export interface ProgressionSelfStatePayload {
  state: PlayerProgressionState;
}

export interface ProgressionSelfPatchPayload {
  patch: Partial<PlayerProgressionState>;
  reason: string;
}

export interface ProgressionAoiVisibleChangedPayload {
  playerId: string;
  projection: AoiVisibleProgression;
}

export interface ProgressionAoiVisibleLeftPayload {
  playerId: string;
}

export interface ProgressionMilestonePayload {
  milestone: ProgressionMilestone;
}

export const ProgressionErrorCodes = {
  NotInWorld: 'PROGRESSION_NOT_IN_WORLD',
  VersionMismatch: 'PROGRESSION_VERSION_MISMATCH',
  RateLimited: 'PROGRESSION_RATE_LIMITED',
  MilestoneDuplicate: 'PROGRESSION_MILESTONE_DUPLICATE',
  PatchRejected: 'PROGRESSION_PATCH_REJECTED'
} as const;

export type ProgressionErrorCode = (typeof ProgressionErrorCodes)[keyof typeof ProgressionErrorCodes];

export const WRITE_OPS_REQUIRING_CLIENT_TOKEN = new Set<string>([
  ClientOps.AuthRefresh,
  ClientOps.WorldInteract,
  ClientOps.WorldCastSkill,
  ClientOps.WorldTransfer,
  ClientOps.InventoryDiscard,
  ClientOps.EquipmentEquip,
  ClientOps.EquipmentUnequip,
  ClientOps.ForgeRequest,
  ClientOps.ForgeCancel,
  ClientOps.RitualStart,
  ClientOps.RitualFeed,
  ClientOps.RitualCancel,
  ClientOps.QuestAccept,
  ClientOps.QuestTurnIn,
  ClientOps.QuestAbandon,
  ClientOps.TransformationStart,
  ClientOps.TransformationFeed,
  ClientOps.TransformationEnd,
  ClientOps.PathwayAdvanceRequest,
  ClientOps.PathwayConsumePotion,
  ClientOps.SkillLearn,
  ClientOps.SkillEquipLoadout,
  ClientOps.BuildPlaceRequest,
  ClientOps.BuildCancel,
  ClientOps.BuildDismantle,
  ClientOps.ShopBuy,
  ClientOps.ShopSell,
  ClientOps.ProgressionAcknowledgeMilestone,
  ClientOps.CombatAction,
  ClientOps.MonsterEvade,
  ClientOps.ChatSay,
  ClientOps.ChatWhisper,
  ClientOps.ChatParty
]);

export function validateAuthLoginPayload(value: unknown): ValidationResult<AuthLoginPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  if (!nonEmptyString(object.value.token)) {
    return invalid('INVALID_AUTH_LOGIN', 'Auth login requires a non-empty token');
  }
  const version = validateProtocolVersion(object.value.clientProtocolVersion);
  if (!version.ok) {
    return version;
  }
  const payload: AuthLoginPayload = { token: object.value.token };
  if (object.value.clientProtocolVersion !== undefined) {
    payload.clientProtocolVersion = object.value.clientProtocolVersion as number;
  }
  return { ok: true, value: payload };
}

export function validateAuthRefreshPayload(value: unknown): ValidationResult<AuthRefreshPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  if (!nonEmptyString(object.value.refreshToken)) {
    return invalid('INVALID_AUTH_REFRESH', 'Auth refresh requires a non-empty refreshToken');
  }
  return { ok: true, value: { refreshToken: object.value.refreshToken } };
}

export function validateSystemPingPayload(value: unknown): ValidationResult<SystemPingPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  if (object.value.tick !== undefined && (!Number.isInteger(object.value.tick) || Number(object.value.tick) < 0)) {
    return invalid('INVALID_SYSTEM_PING', 'System ping tick must be a non-negative integer when present');
  }
  return object.value.tick === undefined
    ? { ok: true, value: {} }
    : { ok: true, value: { tick: object.value.tick as number } };
}

export function validateProtocolVersion(value: unknown): ValidationResult<number> {
  if (value === undefined) {
    return { ok: true, value: 0 };
  }
  if (!Number.isInteger(value) || Number(value) < 0) {
    return invalid('INVALID_PROTOCOL_VERSION', 'protocolVersion must be a non-negative integer');
  }
  if (Number(value) > PROTOCOL_VERSION) {
    return invalid('PROTOCOL_VERSION_MISMATCH', 'Client protocol version is not supported by this server');
  }
  return { ok: true, value: value as number };
}

export function validateWriteEnvelopeHeaders(op: string, envelope: Envelope): ValidationResult<Envelope> {
  const version = validateProtocolVersion(envelope.protocolVersion);
  if (!version.ok) {
    return version;
  }
  if (op.startsWith('progression.') && version.value !== PROTOCOL_VERSION) {
    return invalid(ProgressionErrorCodes.VersionMismatch, 'Progression protocol ops require the current protocol version');
  }
  if (version.value === 0) {
    return { ok: true, value: envelope };
  }
  if (!WRITE_OPS_REQUIRING_CLIENT_TOKEN.has(op)) {
    return { ok: true, value: envelope };
  }
  if (!nonEmptyString(envelope.clientToken)) {
    return invalid(`INVALID_${op.toUpperCase().replace('.', '_')}`, `${op} requires a clientToken envelope header`);
  }
  return { ok: true, value: envelope };
}

export function validateWorldEnterPayload(value: unknown): ValidationResult<WorldEnterPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.shardId)
    ? { ok: true, value: { shardId: object.value.shardId } }
    : invalid('INVALID_WORLD_ENTER', 'World enter requires a non-empty shardId');
}

export function validateWorldListShardsPayload(value: unknown): ValidationResult<WorldListShardsPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return Object.keys(object.value).length === 0
    ? { ok: true, value: {} }
    : invalid('INVALID_WORLD_LIST_SHARDS', 'World list shards does not accept a payload');
}

export function validateWorldListMapsPayload(value: unknown): ValidationResult<WorldListMapsPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return Object.keys(object.value).length === 0
    ? { ok: true, value: {} }
    : invalid('INVALID_WORLD_LIST_MAPS', 'World list maps does not accept a payload');
}

export function validateInventoryFetchPayload(value: unknown): ValidationResult<InventoryFetchPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return Object.keys(object.value).length === 0
    ? { ok: true, value: {} }
    : invalid('INVALID_INVENTORY_FETCH', 'Inventory fetch does not accept a payload');
}

export function validateInventoryDiscardPayload(value: unknown): ValidationResult<InventoryDiscardPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.itemId) || !Number.isInteger(payload.amount) || Number(payload.amount) <= 0) {
    return invalid('INVALID_INVENTORY_DISCARD', 'Inventory discard requires itemId and a positive integer amount');
  }
  return { ok: true, value: { itemId: payload.itemId, amount: payload.amount as number } };
}

export function validateEquipmentListPayload(value: unknown): ValidationResult<EquipmentListPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return Object.keys(object.value).length === 0
    ? { ok: true, value: {} }
    : invalid('INVALID_EQUIPMENT_LIST', 'Equipment list does not accept a payload');
}

export function validateEquipmentEquipPayload(value: unknown): ValidationResult<EquipmentEquipPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (typeof payload.slot !== 'string' || !EQUIPMENT_SLOTS.has(payload.slot as EquipmentSlot) || !nonEmptyString(payload.itemId)) {
    return invalid('INVALID_EQUIPMENT_EQUIP', 'Equipment equip requires a supported slot and non-empty itemId');
  }
  const result: EquipmentEquipPayload = { slot: payload.slot as EquipmentSlot, itemId: payload.itemId };
  if (payload.loadoutId !== undefined) {
    if (!nonEmptyString(payload.loadoutId)) {
      return invalid('INVALID_EQUIPMENT_EQUIP', 'Equipment equip loadoutId must be non-empty when present');
    }
    result.loadoutId = payload.loadoutId;
  }
  return { ok: true, value: result };
}

export function validateEquipmentUnequipPayload(value: unknown): ValidationResult<EquipmentUnequipPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  return typeof payload.slot === 'string' && EQUIPMENT_SLOTS.has(payload.slot as EquipmentSlot)
    ? { ok: true, value: { slot: payload.slot as EquipmentSlot } }
    : invalid('INVALID_EQUIPMENT_UNEQUIP', 'Equipment unequip requires a supported slot');
}

export function validateForgeRequestPayload(value: unknown): ValidationResult<ForgeRequestPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.stationEntityId) || typeof payload.mode !== 'string' || !FORGE_MODES.has(payload.mode as ForgeMode)) {
    return invalid('INVALID_FORGE_REQUEST', 'Forge request requires stationEntityId and a supported mode');
  }
  if (payload.mode === 'nl') {
    if (!nonEmptyString(payload.prompt) || String(payload.prompt).length > 4096) {
      return invalid('INVALID_FORGE_REQUEST', 'NL forge requests require a non-empty prompt up to 4096 characters');
    }
  }
  if (payload.mode === 'dsl') {
    if (!nonEmptyString(payload.dslSource) || String(payload.dslSource).length > 8192) {
      return invalid('INVALID_FORGE_REQUEST', 'DSL forge requests require a non-empty dslSource up to 8192 characters');
    }
  }
  const inputs = parseMaterialInputs(payload.inputs, 'INVALID_FORGE_REQUEST');
  if (!inputs.ok) {
    return inputs;
  }
  const result: ForgeRequestPayload = {
    stationEntityId: payload.stationEntityId,
    mode: payload.mode as ForgeMode,
    inputs: inputs.value
  };
  if (nonEmptyString(payload.prompt)) {
    result.prompt = payload.prompt;
  }
  if (nonEmptyString(payload.dslSource)) {
    result.dslSource = payload.dslSource;
  }
  return { ok: true, value: result };
}

export function validateForgeCancelPayload(value: unknown): ValidationResult<ForgeCancelPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.requestId)
    ? { ok: true, value: { requestId: object.value.requestId } }
    : invalid('INVALID_FORGE_CANCEL', 'Forge cancel requires a non-empty requestId');
}

export function validateRitualStartPayload(value: unknown): ValidationResult<RitualStartPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.altarEntityId) || !nonEmptyString(payload.ritualId)) {
    return invalid('INVALID_RITUAL_START', 'Ritual start requires altarEntityId and ritualId');
  }
  const expectedMaterials = parseMaterialInputs(payload.expectedMaterials, 'INVALID_RITUAL_START');
  if (!expectedMaterials.ok) {
    return expectedMaterials;
  }
  return {
    ok: true,
    value: {
      altarEntityId: payload.altarEntityId,
      ritualId: payload.ritualId,
      expectedMaterials: expectedMaterials.value
    }
  };
}

export function validateRitualFeedPayload(value: unknown): ValidationResult<RitualFeedPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.requestId) || !nonEmptyString(payload.itemId) || !positiveInteger(payload.amount)) {
    return invalid('INVALID_RITUAL_FEED', 'Ritual feed requires requestId, itemId, and a positive integer amount');
  }
  return { ok: true, value: { requestId: payload.requestId, itemId: payload.itemId, amount: payload.amount as number } };
}

export function validateRitualCancelPayload(value: unknown): ValidationResult<RitualCancelPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.requestId)
    ? { ok: true, value: { requestId: object.value.requestId } }
    : invalid('INVALID_RITUAL_CANCEL', 'Ritual cancel requires a non-empty requestId');
}

export function validateQuestListPayload(value: unknown): ValidationResult<QuestListPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return Object.keys(object.value).length === 0
    ? { ok: true, value: {} }
    : invalid('INVALID_QUEST_LIST', 'Quest list does not accept a payload');
}

export function validateQuestAcceptPayload(value: unknown): ValidationResult<QuestIdPayload> {
  return validateQuestIdPayload(value, 'INVALID_QUEST_ACCEPT', 'Quest accept requires a non-empty questId');
}

export function validateQuestTurnInPayload(value: unknown): ValidationResult<QuestIdPayload> {
  return validateQuestIdPayload(value, 'INVALID_QUEST_TURN_IN', 'Quest turn-in requires a non-empty questId');
}

export function validateQuestAbandonPayload(value: unknown): ValidationResult<QuestIdPayload> {
  return validateQuestIdPayload(value, 'INVALID_QUEST_ABANDON', 'Quest abandon requires a non-empty questId');
}

export function validateTransformationStartPayload(value: unknown): ValidationResult<TransformationStartPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.speciesId) || typeof payload.depth !== 'string' || !TRANSFORMATION_DEPTHS.has(payload.depth as TransformationDepth)) {
    return invalid('INVALID_TRANSFORMATION_START', 'Transformation start requires speciesId and a supported depth');
  }
  return { ok: true, value: { speciesId: payload.speciesId, depth: payload.depth as TransformationDepth } };
}

export function validateTransformationFeedPayload(value: unknown): ValidationResult<TransformationFeedPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.itemId) || !positiveInteger(payload.amount)) {
    return invalid('INVALID_TRANSFORMATION_FEED', 'Transformation feed requires itemId and a positive integer amount');
  }
  return { ok: true, value: { itemId: payload.itemId, amount: payload.amount as number } };
}

export function validateTransformationEndPayload(value: unknown): ValidationResult<TransformationEndPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const reason = object.value.reason;
  if (typeof reason !== 'string' || !TRANSFORMATION_END_REASONS.has(reason as TransformationEndReason)) {
    return invalid('INVALID_TRANSFORMATION_END', 'Transformation end requires a supported reason');
  }
  return { ok: true, value: { reason: reason as TransformationEndReason } };
}

export function validatePathwayListPayload(value: unknown): ValidationResult<PathwayListPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return Object.keys(object.value).length === 0
    ? { ok: true, value: {} }
    : invalid('INVALID_PATHWAY_LIST', 'Pathway list does not accept a payload');
}

export function validatePathwayAdvanceRequestPayload(value: unknown): ValidationResult<PathwayAdvanceRequestPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.pathwayId) || !integerInRange(payload.targetSequence, 0, 9) || !nonEmptyString(payload.potionItemId)) {
    return invalid('INVALID_PATHWAY_ADVANCE_REQUEST', 'Pathway advance requires pathwayId, targetSequence 0-9, and potionItemId');
  }
  const result: PathwayAdvanceRequestPayload = {
    pathwayId: payload.pathwayId,
    targetSequence: payload.targetSequence as number,
    potionItemId: payload.potionItemId
  };
  if (payload.ritualSnapshotId !== undefined) {
    if (!nonEmptyString(payload.ritualSnapshotId)) {
      return invalid('INVALID_PATHWAY_ADVANCE_REQUEST', 'Pathway advance ritualSnapshotId must be non-empty when present');
    }
    result.ritualSnapshotId = payload.ritualSnapshotId;
  }
  return { ok: true, value: result };
}

export function validatePathwayConsumePotionPayload(value: unknown): ValidationResult<PathwayConsumePotionPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.potionItemId)
    ? { ok: true, value: { potionItemId: object.value.potionItemId } }
    : invalid('INVALID_PATHWAY_CONSUME_POTION', 'Pathway consume potion requires a non-empty potionItemId');
}

export function validateSkillLearnPayload(value: unknown): ValidationResult<SkillLearnPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.skillId) && nonEmptyString(object.value.pathwaySource)
    ? { ok: true, value: { skillId: object.value.skillId, pathwaySource: object.value.pathwaySource } }
    : invalid('INVALID_SKILL_LEARN', 'Skill learn requires skillId and pathwaySource');
}

export function validateSkillEquipLoadoutPayload(value: unknown): ValidationResult<SkillEquipLoadoutPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.loadoutId) || !Array.isArray(payload.skills) || !payload.skills.every((skill) => nonEmptyString(skill))) {
    return invalid('INVALID_SKILL_EQUIP_LOADOUT', 'Skill equip loadout requires loadoutId and non-empty skill ids');
  }
  return {
    ok: true,
    value: {
      loadoutId: payload.loadoutId,
      skills: [...payload.skills] as string[]
    }
  };
}

export function validateBuildPlaceRequestPayload(value: unknown): ValidationResult<BuildPlaceRequestPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.workbenchEntityId) || !nonEmptyString(payload.blueprintId)) {
    return invalid('INVALID_BUILD_PLACE_REQUEST', 'Build place_request requires workbenchEntityId and blueprintId');
  }
  if (!isGridPosition(payload.position)) {
    return invalid('INVALID_BUILD_PLACE_REQUEST', 'Build place_request requires a valid grid position');
  }
  if (typeof payload.facing !== 'string' || !BUILD_DIRECTIONS.has(payload.facing as Direction)) {
    return invalid('INVALID_BUILD_PLACE_REQUEST', 'Build place_request requires a supported facing');
  }
  if (payload.dslSource !== undefined && (!nonEmptyString(payload.dslSource) || String(payload.dslSource).length > 8192)) {
    return invalid('INVALID_BUILD_PLACE_REQUEST', 'Build place_request dslSource must be non-empty and under 8192 characters when present');
  }
  const inputs = parseMaterialInputs(payload.inputs, 'INVALID_BUILD_PLACE_REQUEST');
  if (!inputs.ok) {
    return inputs;
  }
  const result: BuildPlaceRequestPayload = {
    workbenchEntityId: payload.workbenchEntityId,
    blueprintId: payload.blueprintId,
    position: { ...payload.position },
    facing: payload.facing as Direction,
    inputs: inputs.value
  };
  if (nonEmptyString(payload.dslSource)) {
    result.dslSource = payload.dslSource;
  }
  return { ok: true, value: result };
}

export function validateBuildCancelPayload(value: unknown): ValidationResult<BuildCancelPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.requestId)
    ? { ok: true, value: { requestId: object.value.requestId } }
    : invalid('INVALID_BUILD_CANCEL', 'Build cancel requires a non-empty requestId');
}

export function validateBuildDismantlePayload(value: unknown): ValidationResult<BuildDismantlePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.structureEntityId)
    ? { ok: true, value: { structureEntityId: object.value.structureEntityId } }
    : invalid('INVALID_BUILD_DISMANTLE', 'Build dismantle requires a non-empty structureEntityId');
}

export function validateShopListPayload(value: unknown): ValidationResult<ShopListPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.shopEntityId)
    ? { ok: true, value: { shopEntityId: object.value.shopEntityId } }
    : invalid('INVALID_SHOP_LIST', 'Shop list requires a non-empty shopEntityId');
}

export function validateShopBuyPayload(value: unknown): ValidationResult<ShopBuyPayload> {
  return validateShopTransactionPayload(value, 'INVALID_SHOP_BUY', 'Shop buy requires shopEntityId, itemId, and a positive integer amount');
}

export function validateShopSellPayload(value: unknown): ValidationResult<ShopSellPayload> {
  return validateShopTransactionPayload(value, 'INVALID_SHOP_SELL', 'Shop sell requires shopEntityId, itemId, and a positive integer amount');
}

export function validateChatSayPayload(value: unknown): ValidationResult<ChatSayPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return validateChatTextValue(object.value.text, 'INVALID_CHAT_SAY')
    ? { ok: true, value: { text: object.value.text as string } }
    : invalid('INVALID_CHAT_SAY', 'Chat say requires non-empty text up to 1024 characters');
}

export function validateChatWhisperPayload(value: unknown): ValidationResult<ChatWhisperPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  if (!nonEmptyString(object.value.targetPlayerId) || !validateChatTextValue(object.value.text, 'INVALID_CHAT_WHISPER')) {
    return invalid('INVALID_CHAT_WHISPER', 'Chat whisper requires targetPlayerId and non-empty text up to 1024 characters');
  }
  return {
    ok: true,
    value: {
      targetPlayerId: object.value.targetPlayerId,
      text: object.value.text as string
    }
  };
}

export function validateChatPartyPayload(value: unknown): ValidationResult<ChatPartyPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  if (!nonEmptyString(object.value.partyId) || !validateChatTextValue(object.value.text, 'INVALID_CHAT_PARTY')) {
    return invalid('INVALID_CHAT_PARTY', 'Chat party requires partyId and non-empty text up to 1024 characters');
  }
  return {
    ok: true,
    value: {
      partyId: object.value.partyId,
      text: object.value.text as string
    }
  };
}

export function validateWorldMovePayload(value: unknown): ValidationResult<WorldMovePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.playerId)) {
    return invalid('INVALID_WORLD_MOVE', 'World move requires a playerId');
  }
  if (!Number.isInteger(payload.seq) || Number(payload.seq) < 0) {
    return invalid('INVALID_WORLD_MOVE', 'World move requires a non-negative integer seq');
  }
  if (!isGridPosition(payload.from) || !isGridPosition(payload.to)) {
    return invalid('INVALID_WORLD_MOVE', 'World move requires valid from and to positions');
  }
  if (!Number.isFinite(payload.startedAt) || Number(payload.startedAt) < 0) {
    return invalid('INVALID_WORLD_MOVE', 'World move requires a non-negative startedAt');
  }
  return {
    ok: true,
    value: {
      playerId: payload.playerId,
      seq: payload.seq as number,
      from: payload.from,
      to: payload.to,
      startedAt: payload.startedAt as number
    }
  };
}

export function validateWorldInteractPayload(value: unknown): ValidationResult<WorldInteractPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  const actions = new Set(['chop', 'mine', 'push', 'inspect', 'scout', 'combat_check']);
  if (!nonEmptyString(payload.entityId) || typeof payload.action !== 'string' || !actions.has(payload.action)) {
    return invalid('INVALID_WORLD_INTERACT', 'World interact requires an entityId and supported action');
  }
  return { ok: true, value: { entityId: payload.entityId, action: payload.action as WorldInteractPayload['action'] } };
}

export function validateWorldCastSkillPayload(value: unknown): ValidationResult<WorldCastSkillPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.abilityId) || !nonEmptyString(payload.pathwayId)) {
    return invalid('INVALID_WORLD_CAST_SKILL', 'World cast skill requires abilityId and pathwayId');
  }
  if (!Number.isInteger(payload.sequence) || Number(payload.sequence) < 0) {
    return invalid('INVALID_WORLD_CAST_SKILL', 'World cast skill requires a non-negative sequence');
  }
  if (!Number.isFinite(payload.clientPredictedSpawnedAt) || Number(payload.clientPredictedSpawnedAt) < 0) {
    return invalid('INVALID_WORLD_CAST_SKILL', 'World cast skill requires a non-negative clientPredictedSpawnedAt');
  }
  const targetTypes = new Set<WorldSkillTargetType>(['self', 'ally', 'enemy', 'ground_point', 'entity_id', 'none']);
  if (typeof payload.targetType !== 'string' || !targetTypes.has(payload.targetType as WorldSkillTargetType)) {
    return invalid('INVALID_WORLD_CAST_SKILL', 'World cast skill requires a supported targetType');
  }

  const targetType = payload.targetType as WorldSkillTargetType;
  const needsEntity = targetType === 'ally' || targetType === 'enemy' || targetType === 'entity_id';
  if (needsEntity && !nonEmptyString(payload.targetEntityId)) {
    return invalid('INVALID_WORLD_CAST_SKILL', 'Entity-targeted world skills require targetEntityId');
  }
  if (targetType === 'ground_point' && !isGridPosition(payload.targetGroundPosition)) {
    return invalid('INVALID_WORLD_CAST_SKILL', 'Ground-targeted world skills require targetGroundPosition');
  }
  if ((targetType === 'self' || targetType === 'none') && (payload.targetEntityId !== undefined || payload.targetGroundPosition !== undefined)) {
    return invalid('INVALID_WORLD_CAST_SKILL', 'Self and none target skills must not include target coordinates or entity ids');
  }

  const result: WorldCastSkillPayload = {
    abilityId: payload.abilityId,
    pathwayId: payload.pathwayId,
    sequence: payload.sequence as number,
    targetType,
    clientPredictedSpawnedAt: payload.clientPredictedSpawnedAt as number
  };
  if (nonEmptyString(payload.targetEntityId)) {
    result.targetEntityId = payload.targetEntityId;
  }
  if (isGridPosition(payload.targetGroundPosition)) {
    result.targetGroundPosition = payload.targetGroundPosition;
  }
  return { ok: true, value: result };
}

export function validateCombatActionPayload(value: unknown): ValidationResult<CombatActionPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.combatLockId) || !nonEmptyString(payload.action)) {
    return invalid('INVALID_COMBAT_ACTION', 'Combat action requires a combatLockId and action');
  }
  if (payload.targetId !== undefined && !nonEmptyString(payload.targetId)) {
    return invalid('INVALID_COMBAT_ACTION', 'Combat action targetId must be non-empty when present');
  }
  return {
    ok: true,
    value: {
      combatLockId: payload.combatLockId,
      action: payload.action,
      targetId: payload.targetId
    }
  };
}

export function validateMonsterEvadePayload(value: unknown): ValidationResult<MonsterEvadePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (
    !nonEmptyString(payload.shardId)
    || !nonEmptyString(payload.monsterId)
    || typeof payload.evadeKind !== 'string'
    || !MONSTER_EVADE_KINDS.has(payload.evadeKind as MonsterEvadeKind)
  ) {
    return invalid('INVALID_MONSTER_EVADE', 'Monster evade requires shardId, monsterId, and supported evadeKind');
  }
  return {
    ok: true,
    value: {
      shardId: payload.shardId,
      monsterId: payload.monsterId,
      evadeKind: payload.evadeKind as MonsterEvadeKind
    }
  };
}

export function validateMonsterAggroChangedPayload(value: unknown): ValidationResult<MonsterAggroChangedPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (
    !nonEmptyString(payload.shardId)
    || !nonEmptyString(payload.monsterId)
    || typeof payload.fromState !== 'string'
    || !MONSTER_RUNTIME_STATES.has(payload.fromState as MonsterRuntimeProtocolState)
    || typeof payload.toState !== 'string'
    || !MONSTER_RUNTIME_STATES.has(payload.toState as MonsterRuntimeProtocolState)
    || !Number.isFinite(payload.threat)
    || Number(payload.threat) < 0
    || !nonEmptyString(payload.towardsPlayerId)
    || !Number.isInteger(payload.tick)
    || Number(payload.tick) < 0
  ) {
    return invalid('INVALID_MONSTER_AGGRO_CHANGED', 'Monster aggro change payload fields are invalid');
  }
  return {
    ok: true,
    value: {
      shardId: payload.shardId,
      monsterId: payload.monsterId,
      fromState: payload.fromState as MonsterRuntimeProtocolState,
      toState: payload.toState as MonsterRuntimeProtocolState,
      threat: payload.threat as number,
      towardsPlayerId: payload.towardsPlayerId,
      tick: payload.tick as number
    }
  };
}

export function validateMonsterCombatPreludePayload(value: unknown): ValidationResult<MonsterCombatPreludePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (
    !nonEmptyString(payload.shardId)
    || !nonEmptyString(payload.monsterId)
    || !Array.isArray(payload.monsterEntityIds)
    || payload.monsterEntityIds.length === 0
    || !payload.monsterEntityIds.every((id) => nonEmptyString(id))
    || !Number.isFinite(payload.leadTimeMs)
    || Number(payload.leadTimeMs) < 0
    || !Number.isFinite(payload.escapeWindowMs)
    || Number(payload.escapeWindowMs) < 0
  ) {
    return invalid('INVALID_MONSTER_COMBAT_PRELUDE', 'Monster combat prelude payload fields are invalid');
  }
  return {
    ok: true,
    value: {
      shardId: payload.shardId,
      monsterId: payload.monsterId,
      monsterEntityIds: [...payload.monsterEntityIds] as string[],
      leadTimeMs: payload.leadTimeMs as number,
      escapeWindowMs: payload.escapeWindowMs as number
    }
  };
}

export function validateMonsterEvadeAckPayload(value: unknown): ValidationResult<MonsterEvadeAckPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (typeof payload.ok !== 'boolean' || !nonEmptyString(payload.code) || !nonEmptyString(payload.reason)) {
    return invalid('INVALID_MONSTER_EVADE_ACK', 'Monster evade ack requires ok, code, and reason');
  }
  return {
    ok: true,
    value: {
      ok: payload.ok,
      code: payload.code,
      reason: payload.reason
    }
  };
}

export function validateWorldTransferPayload(value: unknown): ValidationResult<WorldTransferPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.playerId) || !nonEmptyString(payload.fromShardId) || !nonEmptyString(payload.toShardId)) {
    return invalid('INVALID_WORLD_TRANSFER', 'World transfer requires playerId, fromShardId, and toShardId');
  }
  if (!isGridPosition(payload.toPosition)) {
    return invalid('INVALID_WORLD_TRANSFER', 'World transfer requires a valid toPosition');
  }
  if (payload.portalId !== undefined && !nonEmptyString(payload.portalId)) {
    return invalid('INVALID_WORLD_TRANSFER', 'World transfer portalId must be non-empty when present');
  }
  const result: WorldTransferPayload = {
    playerId: payload.playerId,
    fromShardId: payload.fromShardId,
    toShardId: payload.toShardId,
    toPosition: payload.toPosition
  };
  if (nonEmptyString(payload.portalId)) {
    result.portalId = payload.portalId;
  }
  return { ok: true, value: result };
}

export function validateProgressionSubscribePayload(value: unknown): ValidationResult<ProgressionSubscribePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.shardId)
    ? { ok: true, value: { shardId: object.value.shardId } }
    : invalid('INVALID_PROGRESSION_SUBSCRIBE', 'Progression subscribe requires a non-empty shardId');
}

export function validateProgressionAcknowledgeMilestonePayload(value: unknown): ValidationResult<ProgressionAcknowledgeMilestonePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.milestoneId)
    ? { ok: true, value: { milestoneId: object.value.milestoneId } }
    : invalid('INVALID_PROGRESSION_ACKNOWLEDGE_MILESTONE', 'Progression milestone acknowledgement requires a non-empty milestoneId');
}

export function validateProgressionSelfStatePayload(value: unknown): ValidationResult<ProgressionSelfStatePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const state = parsePlayerProgressionState(object.value.state);
  return state.ok ? { ok: true, value: { state: state.value } } : state;
}

export function validateProgressionSelfPatchPayload(value: unknown): ValidationResult<ProgressionSelfPatchPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  if (!nonEmptyString(object.value.reason)) {
    return invalid('INVALID_PROGRESSION_SELF_PATCH', 'Progression self_patch requires a non-empty reason');
  }
  const patch = asObject(object.value.patch);
  if (!patch.ok) {
    return invalid('INVALID_PROGRESSION_SELF_PATCH', 'Progression self_patch requires an object patch');
  }
  const parsed = parseProgressionPatch(patch.value);
  if (!parsed.ok) {
    return parsed;
  }
  return { ok: true, value: { patch: parsed.value, reason: object.value.reason } };
}

export function validateProgressionAoiVisibleChangedPayload(value: unknown): ValidationResult<ProgressionAoiVisibleChangedPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  if (!nonEmptyString(object.value.playerId)) {
    return invalid('INVALID_PROGRESSION_AOI_VISIBLE_CHANGED', 'Progression AOI visible change requires a playerId');
  }
  const projection = parseAoiVisibleProgression(object.value.projection);
  if (!projection.ok) {
    return projection;
  }
  if (projection.value.playerId !== object.value.playerId) {
    return invalid('INVALID_PROGRESSION_AOI_VISIBLE_CHANGED', 'Progression AOI projection playerId must match payload playerId');
  }
  return { ok: true, value: { playerId: object.value.playerId, projection: projection.value } };
}

export function validateProgressionAoiVisibleLeftPayload(value: unknown): ValidationResult<ProgressionAoiVisibleLeftPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.playerId)
    ? { ok: true, value: { playerId: object.value.playerId } }
    : invalid('INVALID_PROGRESSION_AOI_VISIBLE_LEFT', 'Progression AOI visible left requires a playerId');
}

export function validateProgressionMilestonePayload(value: unknown): ValidationResult<ProgressionMilestonePayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const milestone = parseProgressionMilestone(object.value.milestone);
  return milestone.ok ? { ok: true, value: { milestone: milestone.value } } : milestone;
}

function isGridPosition(value: unknown): value is GridPosition {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const candidate = value as Record<string, unknown>;
  return Number.isInteger(candidate.x) && Number.isInteger(candidate.y);
}

const PROGRESSION_PATHWAYS = new Set<PathwayId>([
  'unselected',
  'tide_priestess',
  'ashen_sovereign',
  'dream_weaver',
  'star_abyss_walker',
  'duke_eternal_night',
  'polymath',
  'rust_bellsmith'
]);

const SEQUENCE_BADGES = new Set<SequenceBadge>([
  'none',
  'sequence_5',
  'sequence_4',
  'sequence_3',
  'sequence_2',
  'sequence_1',
  'sequence_0'
]);

const MILESTONE_TYPES = new Set<ProgressionMilestone['type']>([
  'level_up',
  'sequence_advanced',
  'out_of_control',
  'transformation_started',
  'transformation_ended'
]);

const MONSTER_EVADE_KINDS = new Set<MonsterEvadeKind>(['sprint', 'stealth', 'transform']);
const BUILD_DIRECTIONS = new Set<Direction>(['north', 'east', 'south', 'west']);

const EQUIPMENT_SLOTS = new Set<EquipmentSlot>(['weapon', 'armor', 'trinket']);

const FORGE_MODES = new Set<ForgeMode>(['nl', 'dsl']);

const MONSTER_RUNTIME_STATES = new Set<MonsterRuntimeProtocolState>([
  'IDLE',
  'PATROL',
  'ALERT',
  'CHASE',
  'COMBAT_LOCKED',
  'DEAD'
]);
const TRANSFORMATION_DEPTHS = new Set<TransformationDepth>(['disguise', 'communion', 'assimilation']);
const TRANSFORMATION_END_REASONS = new Set<TransformationEndReason>(['manual', 'timeout', 'forced']);

function parseMaterialInputs(value: unknown, code: string): ValidationResult<MaterialInput[]> {
  if (!Array.isArray(value) || value.length === 0) {
    return invalid(code, 'Material inputs must be a non-empty array');
  }
  const inputs: MaterialInput[] = [];
  for (const entry of value) {
    const object = asObject(entry);
    if (!object.ok) {
      return invalid(code, 'Material input entries must be objects');
    }
    if (!nonEmptyString(object.value.itemId) || !positiveInteger(object.value.amount)) {
      return invalid(code, 'Material inputs require itemId and a positive integer amount');
    }
    inputs.push({ itemId: object.value.itemId, amount: object.value.amount as number });
  }
  return { ok: true, value: inputs };
}

function validateShopTransactionPayload(value: unknown, code: string, message: string): ValidationResult<ShopBuyPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  const payload = object.value;
  if (!nonEmptyString(payload.shopEntityId) || !nonEmptyString(payload.itemId) || !positiveInteger(payload.amount)) {
    return invalid(code, message);
  }
  return {
    ok: true,
    value: {
      shopEntityId: payload.shopEntityId,
      itemId: payload.itemId,
      amount: payload.amount as number
    }
  };
}

function validateChatTextValue(value: unknown, _code: string): value is string {
  return nonEmptyString(value) && value.length <= 1024;
}

function positiveInteger(value: unknown): boolean {
  return Number.isInteger(value) && Number(value) > 0;
}

function validateQuestIdPayload(value: unknown, code: string, message: string): ValidationResult<QuestIdPayload> {
  const object = asObject(value);
  if (!object.ok) {
    return object;
  }
  return nonEmptyString(object.value.questId)
    ? { ok: true, value: { questId: object.value.questId } }
    : invalid(code, message);
}

function parsePlayerProgressionState(value: unknown): ValidationResult<PlayerProgressionState> {
  const object = asObject(value);
  if (!object.ok) {
    return invalid('INVALID_PROGRESSION_SELF_STATE', 'Progression self_state requires a state object');
  }
  const state = object.value;
  if (!nonEmptyString(state.playerId) || state.protocolVersion !== 'v3' || !nonEmptyString(state.contentHash)) {
    return invalid('INVALID_PROGRESSION_SELF_STATE', 'Progression state requires playerId, protocolVersion v3, and contentHash');
  }
  const requiredFields = [
    'level',
    'exp',
    'expToNextLevel',
    'skillPoints',
    'pathway',
    'sequence',
    'sanity',
    'isOutOfControl',
    'recoveryQuestId',
    'transformationDepth',
    'transformedSpecies',
    'transformExpiresAt',
    'speciesReputation',
    'identityVisibleInAoi',
    'aoiActorLabel',
    'aoiActorVariantId'
  ];
  if (!requiredFields.every((field) => Object.prototype.hasOwnProperty.call(state, field))) {
    return invalid('INVALID_PROGRESSION_SELF_STATE', 'Progression self_state requires a complete PlayerProgressionState');
  }
  const patch = parseProgressionPatch(state);
  if (!patch.ok) {
    return invalid('INVALID_PROGRESSION_SELF_STATE', patch.message);
  }
  if (!Number.isFinite(state.updatedAt) || Number(state.updatedAt) < 0) {
    return invalid('INVALID_PROGRESSION_SELF_STATE', 'Progression state updatedAt must be a non-negative number');
  }
  return {
    ok: true,
    value: {
      ...(patch.value as Required<Omit<PlayerProgressionState, 'playerId' | 'protocolVersion' | 'updatedAt' | 'contentHash'>>),
      playerId: state.playerId,
      protocolVersion: 'v3',
      updatedAt: state.updatedAt as number,
      contentHash: state.contentHash
    }
  };
}

function parseProgressionPatch(patch: Record<string, unknown>): ValidationResult<Partial<PlayerProgressionState>> {
  const parsed: Partial<PlayerProgressionState> = {};
  for (const [field, value] of Object.entries(patch)) {
    switch (field) {
      case 'level':
        if (!integerInRange(value, 1, 999)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression level must be between 1 and 999');
        }
        parsed.level = value;
        break;
      case 'exp':
        if (!finiteAtLeast(value, 0)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression exp must be non-negative');
        }
        parsed.exp = value;
        break;
      case 'expToNextLevel':
        if (!finiteAtLeast(value, 1)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression expToNextLevel must be at least 1');
        }
        parsed.expToNextLevel = value;
        break;
      case 'skillPoints':
        if (!integerInRange(value, 0, Number.MAX_SAFE_INTEGER)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression skillPoints must be non-negative');
        }
        parsed.skillPoints = value;
        break;
      case 'pathway':
        if (typeof value !== 'string' || !PROGRESSION_PATHWAYS.has(value as PathwayId)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression pathway must be supported');
        }
        parsed.pathway = value as PathwayId;
        break;
      case 'sequence':
        if (!integerInRange(value, 0, 9)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression sequence must be between 0 and 9');
        }
        parsed.sequence = value;
        break;
      case 'sanity':
        if (!integerInRange(value, 0, 100)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression sanity must be between 0 and 100');
        }
        parsed.sanity = value;
        break;
      case 'isOutOfControl':
      case 'identityVisibleInAoi':
        if (typeof value !== 'boolean') {
          return invalid(ProgressionErrorCodes.PatchRejected, `Progression ${field} must be boolean`);
        }
        parsed[field] = value;
        break;
      case 'recoveryQuestId':
      case 'transformedSpecies':
        if (value !== null && !nonEmptyString(value)) {
          return invalid(ProgressionErrorCodes.PatchRejected, `Progression ${field} must be null or a non-empty string`);
        }
        parsed[field] = value as string | null;
        break;
      case 'transformationDepth':
        if (!integerInRange(value, 0, 3)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression transformationDepth must be between 0 and 3');
        }
        parsed.transformationDepth = value as 0 | 1 | 2 | 3;
        break;
      case 'transformExpiresAt':
        if (value !== null && !Number.isFinite(value)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression transformExpiresAt must be null or finite');
        }
        parsed.transformExpiresAt = value as number | null;
        break;
      case 'speciesReputation':
        if (!isNumberRecord(value)) {
          return invalid(ProgressionErrorCodes.PatchRejected, 'Progression speciesReputation must map species ids to finite numbers');
        }
        parsed.speciesReputation = value;
        break;
      case 'aoiActorLabel':
      case 'aoiActorVariantId':
        if (!nonEmptyString(value)) {
          return invalid(ProgressionErrorCodes.PatchRejected, `Progression ${field} must be a non-empty string`);
        }
        parsed[field] = value;
        break;
      case 'playerId':
      case 'protocolVersion':
      case 'updatedAt':
      case 'contentHash':
        break;
      default:
        return invalid(ProgressionErrorCodes.PatchRejected, `Unsupported progression patch field ${field}`);
    }
  }
  return { ok: true, value: parsed };
}

function parseAoiVisibleProgression(value: unknown): ValidationResult<AoiVisibleProgression> {
  const object = asObject(value);
  if (!object.ok) {
    return invalid('INVALID_PROGRESSION_AOI_VISIBLE_CHANGED', 'Progression AOI projection requires an object');
  }
  const projection = object.value;
  if (
    !nonEmptyString(projection.playerId)
    || !nonEmptyString(projection.aoiActorLabel)
    || !nonEmptyString(projection.aoiActorVariantId)
    || !integerInRange(projection.level, 1, 999)
    || typeof projection.pathway !== 'string'
    || !PROGRESSION_PATHWAYS.has(projection.pathway as PathwayId)
    || typeof projection.sequenceBadge !== 'string'
    || !SEQUENCE_BADGES.has(projection.sequenceBadge as SequenceBadge)
    || typeof projection.outOfControlAura !== 'boolean'
    || typeof projection.transformationVisible !== 'boolean'
    || typeof projection.identityVisibleInAoi !== 'boolean'
  ) {
    return invalid('INVALID_PROGRESSION_AOI_VISIBLE_CHANGED', 'Progression AOI projection fields are invalid');
  }
  return {
    ok: true,
    value: {
      playerId: projection.playerId,
      aoiActorLabel: projection.aoiActorLabel,
      aoiActorVariantId: projection.aoiActorVariantId,
      level: projection.level,
      pathway: projection.pathway as PathwayId,
      sequenceBadge: projection.sequenceBadge as SequenceBadge,
      outOfControlAura: projection.outOfControlAura,
      transformationVisible: projection.transformationVisible,
      identityVisibleInAoi: projection.identityVisibleInAoi
    }
  };
}

function parseProgressionMilestone(value: unknown): ValidationResult<ProgressionMilestone> {
  const object = asObject(value);
  if (!object.ok) {
    return invalid('INVALID_PROGRESSION_MILESTONE', 'Progression milestone requires an object');
  }
  const milestone = object.value;
  if (
    !nonEmptyString(milestone.milestoneId)
    || !nonEmptyString(milestone.playerId)
    || typeof milestone.type !== 'string'
    || !MILESTONE_TYPES.has(milestone.type as ProgressionMilestone['type'])
    || !Number.isFinite(milestone.occurredAt)
    || Number(milestone.occurredAt) < 0
    || typeof milestone.shardBroadcast !== 'boolean'
    || typeof milestone.duplicate !== 'boolean'
    || !milestone.payload
    || typeof milestone.payload !== 'object'
    || Array.isArray(milestone.payload)
  ) {
    return invalid('INVALID_PROGRESSION_MILESTONE', 'Progression milestone fields are invalid');
  }
  return {
    ok: true,
    value: {
      milestoneId: milestone.milestoneId,
      playerId: milestone.playerId,
      type: milestone.type as ProgressionMilestone['type'],
      occurredAt: milestone.occurredAt as number,
      shardBroadcast: milestone.shardBroadcast,
      duplicate: milestone.duplicate,
      payload: milestone.payload as Record<string, unknown>
    }
  };
}

function integerInRange(value: unknown, min: number, max: number): value is number {
  return Number.isInteger(value) && Number(value) >= min && Number(value) <= max;
}

function finiteAtLeast(value: unknown, min: number): value is number {
  return Number.isFinite(value) && Number(value) >= min;
}

function isNumberRecord(value: unknown): value is Record<string, number> {
  return Boolean(value)
    && typeof value === 'object'
    && !Array.isArray(value)
    && Object.values(value as Record<string, unknown>).every((entry) => Number.isFinite(entry));
}
