export const PROTOCOL_VERSION = 1;

export const ClientOpDomains = {
  auth: {
    Login: 'auth.login',
    Refresh: 'auth.refresh'
  },
  system: {
    Ping: 'system.ping'
  },
  world: {
    Enter: 'world.enter',
    Move: 'world.move',
    Interact: 'world.interact',
    CastSkill: 'world.cast_skill',
    ListShards: 'world.list_shards',
    ListMaps: 'world.list_maps',
    Transfer: 'world.transfer'
  },
  inventory: {
    Fetch: 'inventory.fetch',
    Discard: 'inventory.discard'
  },
  equipment: {
    List: 'equipment.list',
    Equip: 'equipment.equip',
    Unequip: 'equipment.unequip'
  },
  forge: {
    Request: 'forge.request',
    Cancel: 'forge.cancel'
  },
  ritual: {
    Start: 'ritual.start',
    Feed: 'ritual.feed',
    Cancel: 'ritual.cancel'
  },
  quest: {
    List: 'quest.list',
    Accept: 'quest.accept',
    TurnIn: 'quest.turn_in',
    Abandon: 'quest.abandon'
  },
  transformation: {
    Start: 'transformation.start',
    Feed: 'transformation.feed',
    End: 'transformation.end'
  },
  pathway: {
    List: 'pathway.list',
    AdvanceRequest: 'pathway.advance_request',
    ConsumePotion: 'pathway.consume_potion'
  },
  skill: {
    Learn: 'skill.learn',
    EquipLoadout: 'skill.equip_loadout'
  },
  build: {
    PlaceRequest: 'build.place_request',
    Cancel: 'build.cancel',
    Dismantle: 'build.dismantle'
  },
  shop: {
    List: 'shop.list',
    Buy: 'shop.buy',
    Sell: 'shop.sell'
  },
  progression: {
    Subscribe: 'progression.subscribe',
    AcknowledgeMilestone: 'progression.acknowledge_milestone'
  },
  combat: {
    Action: 'combat.action'
  },
  monster: {
    Evade: 'monster.evade'
  },
  chat: {
    Say: 'chat.say',
    Whisper: 'chat.whisper',
    Party: 'chat.party'
  }
} as const;

export const ServerOpDomains = {
  auth: {
    Result: 'auth.result',
    Kicked: 'auth.kicked'
  },
  system: {
    Pong: 'system.pong',
    RateLimit: 'system.ratelimit'
  },
  world: {
    Entered: 'world.entered',
    Snapshot: 'world.snapshot',
    Correction: 'world.correction',
    Delta: 'world.delta',
    Error: 'world.error',
    ShardList: 'world.shard_list',
    MapList: 'world.map_list',
    TransferAck: 'world.transfer_ack',
    AoiDelta: 'world.aoi_delta',
    SkillCastAck: 'world.skill_cast_ack',
    SkillResolved: 'world.skill_resolved',
    SkillBroadcast: 'world.skill_broadcast'
  },
  inventory: {
    Snapshot: 'inventory.snapshot',
    Delta: 'inventory.delta'
  },
  equipment: {
    Snapshot: 'equipment.snapshot',
    Delta: 'equipment.delta'
  },
  forge: {
    Progress: 'forge.progress',
    Result: 'forge.result'
  },
  ritual: {
    Progress: 'ritual.progress',
    Result: 'ritual.result',
    Interrupted: 'ritual.interrupted'
  },
  quest: {
    Snapshot: 'quest.snapshot',
    Delta: 'quest.delta',
    ObjectiveProgress: 'quest.objective_progress'
  },
  transformation: {
    State: 'transformation.state',
    SuspicionChanged: 'transformation.suspicion_changed',
    Exposed: 'transformation.exposed'
  },
  pathway: {
    Snapshot: 'pathway.snapshot',
    Delta: 'pathway.delta',
    UnlockEvent: 'pathway.unlock_event'
  },
  skill: {
    Snapshot: 'skill.snapshot',
    Delta: 'skill.delta'
  },
  build: {
    Progress: 'build.progress',
    Result: 'build.result',
    WorldAlteration: 'build.world_alteration'
  },
  shop: {
    Snapshot: 'shop.snapshot',
    TransactionResult: 'shop.transaction_result'
  },
  weekly: {
    Reset: 'weekly.reset'
  },
  progression: {
    SelfState: 'progression.self_state',
    SelfPatch: 'progression.self_patch',
    AoiVisibleChanged: 'progression.aoi_visible_changed',
    AoiVisibleLeft: 'progression.aoi_visible_left',
    Milestone: 'progression.milestone'
  },
  combat: {
    Lock: 'combat.lock',
    State: 'combat.state',
    Unlock: 'combat.unlock'
  },
  monster: {
    AggroChanged: 'monster.aggro_changed',
    CombatPrelude: 'monster.combat_prelude',
    EvadeAck: 'monster.evade_ack'
  },
  chat: {
    Message: 'chat.message'
  }
} as const;

export const ClientOps = {
  AuthLogin: ClientOpDomains.auth.Login,
  AuthRefresh: ClientOpDomains.auth.Refresh,
  SystemPing: ClientOpDomains.system.Ping,
  WorldEnter: ClientOpDomains.world.Enter,
  WorldMove: ClientOpDomains.world.Move,
  WorldInteract: ClientOpDomains.world.Interact,
  WorldCastSkill: ClientOpDomains.world.CastSkill,
  WorldListShards: ClientOpDomains.world.ListShards,
  WorldListMaps: ClientOpDomains.world.ListMaps,
  WorldTransfer: ClientOpDomains.world.Transfer,
  InventoryFetch: ClientOpDomains.inventory.Fetch,
  InventoryDiscard: ClientOpDomains.inventory.Discard,
  EquipmentList: ClientOpDomains.equipment.List,
  EquipmentEquip: ClientOpDomains.equipment.Equip,
  EquipmentUnequip: ClientOpDomains.equipment.Unequip,
  ForgeRequest: ClientOpDomains.forge.Request,
  ForgeCancel: ClientOpDomains.forge.Cancel,
  RitualStart: ClientOpDomains.ritual.Start,
  RitualFeed: ClientOpDomains.ritual.Feed,
  RitualCancel: ClientOpDomains.ritual.Cancel,
  QuestList: ClientOpDomains.quest.List,
  QuestAccept: ClientOpDomains.quest.Accept,
  QuestTurnIn: ClientOpDomains.quest.TurnIn,
  QuestAbandon: ClientOpDomains.quest.Abandon,
  TransformationStart: ClientOpDomains.transformation.Start,
  TransformationFeed: ClientOpDomains.transformation.Feed,
  TransformationEnd: ClientOpDomains.transformation.End,
  PathwayList: ClientOpDomains.pathway.List,
  PathwayAdvanceRequest: ClientOpDomains.pathway.AdvanceRequest,
  PathwayConsumePotion: ClientOpDomains.pathway.ConsumePotion,
  SkillLearn: ClientOpDomains.skill.Learn,
  SkillEquipLoadout: ClientOpDomains.skill.EquipLoadout,
  BuildPlaceRequest: ClientOpDomains.build.PlaceRequest,
  BuildCancel: ClientOpDomains.build.Cancel,
  BuildDismantle: ClientOpDomains.build.Dismantle,
  ShopList: ClientOpDomains.shop.List,
  ShopBuy: ClientOpDomains.shop.Buy,
  ShopSell: ClientOpDomains.shop.Sell,
  ProgressionSubscribe: ClientOpDomains.progression.Subscribe,
  ProgressionAcknowledgeMilestone: ClientOpDomains.progression.AcknowledgeMilestone,
  CombatAction: ClientOpDomains.combat.Action,
  MonsterEvade: ClientOpDomains.monster.Evade,
  ChatSay: ClientOpDomains.chat.Say,
  ChatWhisper: ClientOpDomains.chat.Whisper,
  ChatParty: ClientOpDomains.chat.Party
} as const;

export const ServerOps = {
  AuthResult: ServerOpDomains.auth.Result,
  AuthKicked: ServerOpDomains.auth.Kicked,
  SystemPong: ServerOpDomains.system.Pong,
  SystemRateLimit: ServerOpDomains.system.RateLimit,
  WorldEntered: ServerOpDomains.world.Entered,
  WorldSnapshot: ServerOpDomains.world.Snapshot,
  WorldCorrection: ServerOpDomains.world.Correction,
  WorldDelta: ServerOpDomains.world.Delta,
  WorldError: ServerOpDomains.world.Error,
  WorldShardList: ServerOpDomains.world.ShardList,
  WorldMapList: ServerOpDomains.world.MapList,
  WorldTransferAck: ServerOpDomains.world.TransferAck,
  WorldAoiDelta: ServerOpDomains.world.AoiDelta,
  WorldSkillCastAck: ServerOpDomains.world.SkillCastAck,
  WorldSkillResolved: ServerOpDomains.world.SkillResolved,
  WorldSkillBroadcast: ServerOpDomains.world.SkillBroadcast,
  InventorySnapshot: ServerOpDomains.inventory.Snapshot,
  InventoryDelta: ServerOpDomains.inventory.Delta,
  EquipmentSnapshot: ServerOpDomains.equipment.Snapshot,
  EquipmentDelta: ServerOpDomains.equipment.Delta,
  ForgeProgress: ServerOpDomains.forge.Progress,
  ForgeResult: ServerOpDomains.forge.Result,
  RitualProgress: ServerOpDomains.ritual.Progress,
  RitualResult: ServerOpDomains.ritual.Result,
  RitualInterrupted: ServerOpDomains.ritual.Interrupted,
  QuestSnapshot: ServerOpDomains.quest.Snapshot,
  QuestDelta: ServerOpDomains.quest.Delta,
  QuestObjectiveProgress: ServerOpDomains.quest.ObjectiveProgress,
  TransformationState: ServerOpDomains.transformation.State,
  TransformationSuspicionChanged: ServerOpDomains.transformation.SuspicionChanged,
  TransformationExposed: ServerOpDomains.transformation.Exposed,
  PathwaySnapshot: ServerOpDomains.pathway.Snapshot,
  PathwayDelta: ServerOpDomains.pathway.Delta,
  PathwayUnlockEvent: ServerOpDomains.pathway.UnlockEvent,
  SkillSnapshot: ServerOpDomains.skill.Snapshot,
  SkillDelta: ServerOpDomains.skill.Delta,
  BuildProgress: ServerOpDomains.build.Progress,
  BuildResult: ServerOpDomains.build.Result,
  BuildWorldAlteration: ServerOpDomains.build.WorldAlteration,
  ShopSnapshot: ServerOpDomains.shop.Snapshot,
  ShopTransactionResult: ServerOpDomains.shop.TransactionResult,
  WeeklyReset: ServerOpDomains.weekly.Reset,
  ProgressionSelfState: ServerOpDomains.progression.SelfState,
  ProgressionSelfPatch: ServerOpDomains.progression.SelfPatch,
  ProgressionAoiVisibleChanged: ServerOpDomains.progression.AoiVisibleChanged,
  ProgressionAoiVisibleLeft: ServerOpDomains.progression.AoiVisibleLeft,
  ProgressionMilestone: ServerOpDomains.progression.Milestone,
  CombatLock: ServerOpDomains.combat.Lock,
  CombatState: ServerOpDomains.combat.State,
  CombatUnlock: ServerOpDomains.combat.Unlock,
  MonsterAggroChanged: ServerOpDomains.monster.AggroChanged,
  MonsterCombatPrelude: ServerOpDomains.monster.CombatPrelude,
  MonsterEvadeAck: ServerOpDomains.monster.EvadeAck,
  ChatMessage: ServerOpDomains.chat.Message
} as const;

export type ClientOp = (typeof ClientOps)[keyof typeof ClientOps];
export type ServerOp = (typeof ServerOps)[keyof typeof ServerOps];
