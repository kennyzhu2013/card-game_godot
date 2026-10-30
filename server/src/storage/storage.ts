import type { PlayerProgressionState, PlayerWorldState, ShardMeta, WorldDelta, WorldTemplate } from '../world/types.js';

export type SessionState = 'connected' | 'authenticated' | 'in_world' | 'disconnected';

export interface Session {
  sessionId: string;
  socketId: string;
  accountId: string | null;
  playerId: string | null;
  shardId: string | null;
  ip: string;
  state: SessionState;
  lastHeartbeatAt: number;
  createdAt: number;
  disconnectedAt?: number;
}

export interface SessionStore {
  upsert(session: Session): Promise<void>;
  get(sessionId: string): Promise<Session | undefined>;
  listActive(): Promise<Session[]>;
  markDisconnected(sessionId: string, disconnectedAt: number): Promise<void>;
  findRecentDisconnected(accountId: string, playerId: string, graceMs: number, now: number): Promise<Session | undefined>;
}

export interface PlayerStateStore {
  upsert(state: PlayerWorldState): Promise<void>;
  get(playerId: string): Promise<PlayerWorldState | undefined>;
}

export interface PlayerProgressionStateStore {
  upsert(state: PlayerProgressionState): Promise<void>;
  get(playerId: string): Promise<PlayerProgressionState | undefined>;
}

export interface WorldTemplateStore {
  list(): Promise<WorldTemplate[]>;
  load(mapId: string): Promise<WorldTemplate>;
}

export interface ShardMetaStore {
  upsert(meta: ShardMeta): Promise<void>;
  get(shardId: string): Promise<ShardMeta | undefined>;
  list(): Promise<ShardMeta[]>;
}

export interface WorldDeltaStore {
  append(delta: WorldDelta): Promise<void>;
  list(shardId: string): Promise<WorldDelta[]>;
  replay(shardId: string, afterVersion: number): Promise<WorldDelta[]>;
}

export interface Storage {
  sessions: SessionStore;
  playerStates: PlayerStateStore;
  playerProgressionStates: PlayerProgressionStateStore;
  worldTemplates: WorldTemplateStore;
  shardMetas: ShardMetaStore;
  worldDeltas: WorldDeltaStore;
}
