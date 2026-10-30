import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { LEGACY_MAP_ALIASES } from '../world/mapAliases.js';
import type { PlayerProgressionState, PlayerWorldState, ShardMeta, WorldDelta, WorldTemplate } from '../world/types.js';
import type { Session, Storage } from './storage.js';

const MAPS_DIR = join(__dirname, '..', 'data', 'maps');

export interface MemoryStorageOptions {
  mapsDir?: string;
}

export function createMemoryStorage(options: MemoryStorageOptions = {}): Storage {
  const sessions = new Map<string, Session>();
  const playerStates = new Map<string, PlayerWorldState>();
  const playerProgressionStates = new Map<string, PlayerProgressionState>();
  const worldDeltas = new Map<string, WorldDelta[]>();
  const shardMetas = new Map<string, ShardMeta>();

  const { templates, canonicalTemplateIds } = loadMapTemplates(options.mapsDir ?? MAPS_DIR);

  return {
    sessions: {
      async upsert(session: Session): Promise<void> {
        sessions.set(session.sessionId, clone(session));
      },

      async get(sessionId: string): Promise<Session | undefined> {
        return cloneOrUndefined(sessions.get(sessionId));
      },

      async listActive(): Promise<Session[]> {
        return [...sessions.values()]
          .filter((session) => session.state !== 'disconnected')
          .map((session) => clone(session));
      },

      async markDisconnected(sessionId: string, disconnectedAt: number): Promise<void> {
        const session = sessions.get(sessionId);
        if (!session) {
          return;
        }
        sessions.set(sessionId, {
          ...clone(session),
          state: 'disconnected',
          disconnectedAt
        });
      },

      async findRecentDisconnected(accountId: string, playerId: string, graceMs: number, now: number): Promise<Session | undefined> {
        const candidates = [...sessions.values()]
          .filter((session) => session.state === 'disconnected')
          .filter((session) => session.accountId === accountId && session.playerId === playerId)
          .filter((session) => session.disconnectedAt !== undefined && now - session.disconnectedAt <= graceMs)
          .sort((a, b) => (b.disconnectedAt ?? 0) - (a.disconnectedAt ?? 0));
        return cloneOrUndefined(candidates[0]);
      }
    },

    playerStates: {
      async upsert(state: PlayerWorldState): Promise<void> {
        playerStates.set(state.playerId, clone(state));
      },

      async get(playerId: string): Promise<PlayerWorldState | undefined> {
        return cloneOrUndefined(playerStates.get(playerId));
      }
    },

    playerProgressionStates: {
      async upsert(state: PlayerProgressionState): Promise<void> {
        playerProgressionStates.set(state.playerId, clone(state));
      },

      async get(playerId: string): Promise<PlayerProgressionState | undefined> {
        return cloneOrUndefined(playerProgressionStates.get(playerId));
      }
    },

    worldTemplates: {
      async list(): Promise<WorldTemplate[]> {
        return canonicalTemplateIds.map((mapId) => clone(templates.get(mapId)!));
      },

      async load(mapId: string): Promise<WorldTemplate> {
        const template = templates.get(mapId);
        if (!template) {
          throw new Error(`UNKNOWN_WORLD_TEMPLATE:${mapId}`);
        }
        return clone(template);
      }
    },

    shardMetas: {
      async upsert(meta: ShardMeta): Promise<void> {
        shardMetas.set(meta.shardId, clone(meta));
      },

      async get(shardId: string): Promise<ShardMeta | undefined> {
        return cloneOrUndefined(shardMetas.get(shardId));
      },

      async list(): Promise<ShardMeta[]> {
        return [...shardMetas.values()]
          .sort((a, b) => a.shardId.localeCompare(b.shardId))
          .map((meta) => clone(meta));
      }
    },

    worldDeltas: {
      async append(delta: WorldDelta): Promise<void> {
        const shardDeltas = worldDeltas.get(delta.shardId) ?? [];
        shardDeltas.push(clone(delta));
        shardDeltas.sort((a, b) => a.version - b.version);
        worldDeltas.set(delta.shardId, shardDeltas);
      },

      async list(shardId: string): Promise<WorldDelta[]> {
        return (worldDeltas.get(shardId) ?? []).map((delta) => clone(delta));
      },

      async replay(shardId: string, afterVersion: number): Promise<WorldDelta[]> {
        return (worldDeltas.get(shardId) ?? [])
          .filter((delta) => delta.version > afterVersion)
          .map((delta) => clone(delta));
      }
    }
  };
}

function loadMapTemplates(mapsDir: string): {
  templates: Map<string, WorldTemplate>;
  canonicalTemplateIds: string[];
} {
  let files: string[];
  try {
    files = readdirSync(mapsDir).filter((name) => name.endsWith('.json')).sort();
  } catch (error) {
    const reason = error instanceof Error ? error.message : String(error);
    throw new Error(`MAP_TEMPLATES_DIR_UNAVAILABLE:${mapsDir}:${reason}`);
  }
  if (files.length === 0) {
    throw new Error(`MAP_TEMPLATES_DIR_EMPTY:${mapsDir}`);
  }

  const templates = new Map<string, WorldTemplate>();
  const canonicalTemplateIds: string[] = [];
  for (const file of files) {
    const fullPath = join(mapsDir, file);
    let raw: unknown;
    try {
      raw = JSON.parse(readFileSync(fullPath, 'utf8'));
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      throw new Error(`MAP_TEMPLATE_PARSE_FAILED:${file}:${reason}`);
    }
    const template = raw as WorldTemplate;
    const mapId = template?.mapId;
    if (typeof mapId !== 'string' || mapId.length === 0) {
      throw new Error(`MAP_TEMPLATE_MISSING_MAP_ID:${file}`);
    }
    if (templates.has(mapId)) {
      throw new Error(`MAP_TEMPLATE_DUPLICATE_MAP_ID:${mapId}:${file}`);
    }
    templates.set(mapId, clone(template));
    canonicalTemplateIds.push(mapId);
  }

  for (const [alias, target] of LEGACY_MAP_ALIASES.entries()) {
    if (!templates.has(target)) {
      continue;
    }
    if (templates.has(alias)) {
      continue;
    }
    templates.set(alias, clone(templates.get(target)!));
  }

  return { templates, canonicalTemplateIds };
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function cloneOrUndefined<T>(value: T | undefined): T | undefined {
  return value === undefined ? undefined : clone(value);
}
