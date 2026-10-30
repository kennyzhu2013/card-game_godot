export type Direction = 'north' | 'east' | 'south' | 'west';

export interface GridPosition {
  x: number;
  y: number;
}

export interface PlayerWorldState {
  playerId: string;
  displayName: string;
  position: GridPosition;
  facing: Direction;
  movementState: 'idle' | 'moving' | 'locked';
  combatLockId: string | null;
  lastMoveSeq: number;
  updatedAt: number;
}

export type PathwayId =
  | 'unselected'
  | 'tide_priestess'
  | 'ashen_sovereign'
  | 'dream_weaver'
  | 'star_abyss_walker'
  | 'duke_eternal_night'
  | 'polymath'
  | 'rust_bellsmith';

export interface PlayerProgressionState {
  playerId: string;
  level: number;
  exp: number;
  expToNextLevel: number;
  skillPoints: number;
  pathway: PathwayId;
  sequence: number;
  sanity: number;
  isOutOfControl: boolean;
  recoveryQuestId: string | null;
  transformationDepth: 0 | 1 | 2 | 3;
  transformedSpecies: string | null;
  transformExpiresAt: number | null;
  speciesReputation: Record<string, number>;
  identityVisibleInAoi: boolean;
  aoiActorLabel: string;
  aoiActorVariantId: string;
  protocolVersion: 'v3';
  updatedAt: number;
  contentHash: string;
}

export type SequenceBadge =
  | 'none'
  | 'sequence_5'
  | 'sequence_4'
  | 'sequence_3'
  | 'sequence_2'
  | 'sequence_1'
  | 'sequence_0';

export interface AoiVisibleProgression {
  playerId: string;
  aoiActorLabel: string;
  aoiActorVariantId: string;
  level: number;
  pathway: PathwayId;
  sequenceBadge: SequenceBadge;
  outOfControlAura: boolean;
  transformationVisible: boolean;
  identityVisibleInAoi: boolean;
}

export interface ProgressionMilestone {
  milestoneId: string;
  playerId: string;
  type: 'level_up' | 'sequence_advanced' | 'out_of_control' | 'transformation_started' | 'transformation_ended';
  occurredAt: number;
  shardBroadcast: boolean;
  duplicate: boolean;
  payload: Record<string, unknown>;
}

export interface WorldEntity {
  entityId: string;
  type: 'resource' | 'prop' | 'npc' | 'objective' | 'temporary' | 'monster';
  position: GridPosition;
  state: Record<string, unknown>;
  version: number;
}

export type ContentExtensionScope = 'interaction_actions' | 'entity_state_machines' | 'delta_emitters';

export type ContentExtensionActionType = 'set_state' | 'emit_delta' | 'broadcast' | 'lock_combat';

export interface ContentExtensionTrigger {
  entityIdPattern: string;
  action: string;
  preconditions?: Record<string, unknown>;
}

export interface ContentExtensionAction {
  type: ContentExtensionActionType;
  params: Record<string, unknown>;
}

export interface ContentExtension {
  extensionId: string;
  scope: ContentExtensionScope;
  triggers: ContentExtensionTrigger[];
  actions: ContentExtensionAction[];
}

export interface ContentExtensionMeta {
  extensionId: string;
  loaded: boolean;
  triggerCount: number;
  actionCount: number;
}

export interface MonsterSpawn {
  spawnId: string;
  monsterId: string;
  position: GridPosition;
  patrolAnchorOverride?: GridPosition;
  initialState?: 'patrol' | 'idle' | 'leashed';
  packMemberIndex?: number;
  active: boolean;
  storyVisibleId?: string;
}

export type MonsterSkillType = 'attack' | 'buff' | 'heal' | 'control' | 'support';

export interface MonsterSkillTemplate {
  id: string;
  name: string;
  type: MonsterSkillType;
  power: number;
  costAp: number;
  element?: string;
}

export interface MonsterStatsTemplate {
  maxHp: number;
  atk: number;
  def: number;
  spd: number;
  shieldPoints: number;
  weaknesses: string[];
  skills: MonsterSkillTemplate[];
}

export interface MonsterSenseTemplate {
  radiusCells: number;
  visionConeDeg: number;
  blockingTileTags: string[];
  alertCooldownMs: number;
}

export interface MonsterAggroTemplate {
  initial: 'passive' | 'neutral' | 'hostile';
  decayPerSec: number;
  maxThreat: number;
  alertThreshold: number;
  huntThreshold: number;
  huntPlayerSpeciesPenalty: number;
  transformedPlayerImmunity: boolean;
}

export interface MonsterPatrolTemplate {
  type: 'circular' | 'route' | 'stationary';
  radiusCells: number;
  speedCellsPerSec: number;
  idleMsRange: [number, number];
  anchorOverride: GridPosition | null;
  route?: GridPosition[];
}

export interface MonsterRespawnTemplate {
  timerMs: number;
  scatterRadiusCells: number;
  weeklyOnlyOnReset: boolean;
}

export interface MonsterPackTemplate {
  packId: string;
  role: 'scout' | 'guard' | 'brute' | 'caster';
  callAlliesRadiusCells: number;
  maxConcurrentMembers: number;
}

export interface MonsterLootTemplate {
  table: string;
  rolls: number;
}

export interface MonsterEncounterTemplate {
  combatLockRadiusCells: number;
  preferredCombatLockMode: 'instant' | 'prelude';
  victoryDeltas: string[];
  defeatDeltas: string[];
}

export interface MonsterTemplate {
  monsterId: string;
  templateHash: string;
  displayName: string;
  speciesId: string;
  spriteSheet: string;
  stats: MonsterStatsTemplate;
  sense: MonsterSenseTemplate;
  aggro: MonsterAggroTemplate;
  patrol: MonsterPatrolTemplate;
  respawn: MonsterRespawnTemplate;
  pack: MonsterPackTemplate;
  loot: MonsterLootTemplate;
  encounter: MonsterEncounterTemplate;
}

export type MapLayerId = 'surface' | 'underground' | 'rooftop' | 'interior';

export interface WorldRegion {
  regionId: string;
  name: string;
  layer: MapLayerId;
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  baseTile?: string;
  aoiZoneId?: string;
}

export interface WorldPortal {
  portalId: string;
  fromMapId: string;
  fromPosition: GridPosition;
  toMapId: string;
  toShardSelector: 'same_account' | 'least_loaded' | 'fixed';
  toShardId?: string;
  toPosition: GridPosition;
  toFacing: Direction;
  cooldownMs: number;
  visibility: 'always' | 'objective_unlocked';
  unlockObjectiveId?: string;
}

export interface AoiZoneConfig {
  zoneId: string;
  playersRadiusCells: number;
  entitiesRadiusCells: number;
  combatLocksRadiusCells: number;
  deltaMode: 'event' | 'full';
}

export type AoiDeltaEventType =
  | 'player_enter'
  | 'player_leave'
  | 'entity_enter'
  | 'entity_leave'
  | 'lock_enter'
  | 'lock_leave';

export interface AoiDeltaEvent {
  type: AoiDeltaEventType;
  subjectId: string;
  position: GridPosition;
  zoneId: string;
  tick: number;
}

export interface MapTemplateMeta {
  mapId: string;
  templateHash: string;
  displayName: string;
  layers: MapLayerId[];
  defaultLayer: MapLayerId;
  recommendedAoiZoneId: string;
  contentRevision: number;
  serverVisibleIdNamespace: string;
}

export type ShardStatus = 'starting' | 'running' | 'draining' | 'closed';

export interface ShardMeta {
  shardId: string;
  mapId: string;
  status: ShardStatus;
  playerCount: number;
  lastTickAt: number;
  contentRevision: number;
  createdAt: number;
}

export interface CombatLockZone {
  combatLockId: string;
  shardId: string;
  center: GridPosition;
  radius: number;
  state: 'forming' | 'active' | 'resolving' | 'closed';
  participantPlayerIds: string[];
  spectatorPlayerIds: string[];
  hostileEntityIds: string[];
  createdAt: number;
  updatedAt: number;
}

export interface WorldDelta {
  deltaId: string;
  shardId: string;
  mapId: string;
  actorPlayerId: string;
  targetEntityId: string;
  type: 'resource_depleted' | 'prop_moved' | 'entity_spawned' | 'entity_removed' | 'state_changed';
  patch: Record<string, unknown>;
  createdAt: number;
  version: number;
}

export interface WorldTemplate {
  mapId: string;
  templateHash: string;
  width: number;
  height: number;
  spawn: GridPosition;
  blocked: GridPosition[];
  entities: WorldEntity[];
  monsterSpawns: MonsterSpawn[];
  meta: MapTemplateMeta;
  regions: WorldRegion[];
  portals: WorldPortal[];
  aoiZones: AoiZoneConfig[];
  defaultAoiZoneId: string;
  contentExtensions?: ContentExtension[];
  landmarks?: WorldLandmark[];
}

export interface WorldLandmark {
  landmarkId: string;
  role: 'spawn' | 'street' | 'route' | 'shore' | 'service' | 'ritual' | 'creation' | 'blockade';
  position: GridPosition;
  radius: number;
}
