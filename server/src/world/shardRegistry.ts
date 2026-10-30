import type { Clock } from '../core/time.js';
import type { Storage } from '../storage/storage.js';
import type { MapTemplateRegistry } from './mapTemplateRegistry.js';
import { ContentExtensionRegistry } from './contentExtensionRegistry.js';
import type { Direction, GridPosition, PlayerWorldState, ShardMeta, ShardStatus, WorldTemplate } from './types.js';
import { WorldShard, type WorldShardOptions, type WorldSnapshotPayload } from './worldShard.js';

export type ShardRegistryWorldDefaults = Partial<Omit<WorldShardOptions, 'shardId' | 'template' | 'storage' | 'clock'>>;

export interface ShardRegistryOptions {
  storage: Storage;
  clock: Clock;
  templateRegistry: MapTemplateRegistry;
  defaultsByMap: Record<string, ShardRegistryWorldDefaults>;
  fallbackDefaults?: ShardRegistryWorldDefaults;
}

export interface SpawnShardInput {
  shardId: string;
  mapId: string;
  overrides?: ShardRegistryWorldDefaults;
}

export type BeginTransferResult =
  | { ok: true; handoffToken: string; expiresAt: number }
  | { ok: false; code: 'SHARD_NOT_FOUND' | 'PLAYER_NOT_IN_SHARD' | 'SHARD_DRAINING' | 'PLAYER_LOCKED'; message: string };

export type CompleteTransferResult =
  | { ok: true; snapshot: WorldSnapshotPayload }
  | { ok: false; code: 'HANDOFF_NOT_FOUND' | 'HANDOFF_EXPIRED' | 'SHARD_NOT_FOUND' | 'SHARD_DRAINING'; message: string };

interface HandoffRecord {
  token: string;
  player: PlayerWorldState;
  fromShardId: string;
  toShardId: string;
  toPosition: GridPosition;
  toFacing: Direction;
  expiresAt: number;
}

export class ShardRegistry {
  private readonly shards = new Map<string, WorldShard>();
  private readonly metas = new Map<string, ShardMeta>();
  private readonly handoffs = new Map<string, HandoffRecord>();
  private readonly contentExtensionRegistry: ContentExtensionRegistry;
  private handoffSequence = 0;

  constructor(private readonly options: ShardRegistryOptions) {
    this.contentExtensionRegistry = new ContentExtensionRegistry(options.templateRegistry);
  }

  async spawn(input: SpawnShardInput): Promise<WorldShard> {
    if (this.metas.has(input.shardId) || this.shards.has(input.shardId)) {
      throw new Error(`SHARD_ALREADY_EXISTS:${input.shardId}`);
    }

    const starting = this.createMeta(input.shardId, input.mapId, 'starting', undefined);
    this.metas.set(input.shardId, clone(starting));
    await this.options.storage.shardMetas.upsert(starting);

    try {
      const template = await this.options.templateRegistry.load(input.mapId);
      let contentExtensions;
      try {
        contentExtensions = await this.contentExtensionRegistry.list(template.mapId);
      } catch (error) {
        const message = error instanceof Error ? error.message : 'unknown';
        throw new Error(`EXT_PARSE_FAILED:${template.mapId}:${message}`);
      }
      const shard = new WorldShard(this.createShardOptions(input, template, contentExtensions));
      this.shards.set(input.shardId, shard);
      await this.setMeta(this.createMeta(input.shardId, template.mapId, 'running', template));
      return shard;
    } catch (error) {
      await this.setMeta({ ...starting, status: 'closed', lastTickAt: this.options.clock.now() });
      throw error;
    }
  }

  get(shardId: string): WorldShard | undefined {
    return this.shards.get(shardId);
  }

  meta(shardId: string): ShardMeta | undefined {
    const meta = this.metas.get(shardId);
    if (!meta) {
      return undefined;
    }
    return clone(this.refreshRuntimeMeta(meta));
  }

  list(): ShardMeta[] {
    return [...this.metas.values()]
      .map((meta) => this.refreshRuntimeMeta(meta))
      .sort((a, b) => a.shardId.localeCompare(b.shardId))
      .map((meta) => clone(meta));
  }

  listByMap(mapId: string): ShardMeta[] {
    return this.list().filter((meta) => meta.mapId === mapId);
  }

  shardMap(): Map<string, WorldShard> {
    return new Map(this.shards);
  }

  async beginTransfer(
    playerId: string,
    fromShardId: string,
    toShardId: string,
    toPosition: GridPosition,
    toFacing?: Direction
  ): Promise<BeginTransferResult> {
    const fromShard = this.shards.get(fromShardId);
    if (!fromShard) {
      return { ok: false, code: 'SHARD_NOT_FOUND', message: 'Transfer shard was not found' };
    }

    let toShard = this.shards.get(toShardId);
    if (!toShard) {
      const lazyResult = await this.tryLazySpawn(toShardId);
      if (!lazyResult.ok) {
        return { ok: false, code: 'SHARD_NOT_FOUND', message: 'Transfer shard was not found' };
      }
      toShard = lazyResult.shard;
    }

    const targetMeta = this.metas.get(toShardId);
    if (targetMeta?.status === 'draining') {
      return { ok: false, code: 'SHARD_DRAINING', message: `Shard ${toShardId} is draining` };
    }

    const token = this.createHandoffToken(playerId, fromShardId, toShardId);
    const transferOut = await fromShard.transferOut(playerId, token);
    if (!transferOut.ok) {
      return { ok: false, code: transferOut.code, message: transferOut.message };
    }

    const expiresAt = this.options.clock.now() + 5000;
    this.handoffs.set(token, {
      token,
      player: transferOut.snapshotAtExit.self,
      fromShardId,
      toShardId,
      toPosition: clone(toPosition),
      toFacing: toFacing ?? transferOut.snapshotAtExit.self.facing,
      expiresAt
    });
    return { ok: true, handoffToken: token, expiresAt };
  }

  async completeTransfer(handoffToken: string): Promise<CompleteTransferResult> {
    const record = this.handoffs.get(handoffToken);
    if (!record) {
      return { ok: false, code: 'HANDOFF_NOT_FOUND', message: 'Handoff token was not found' };
    }
    if (this.options.clock.now() > record.expiresAt) {
      this.handoffs.delete(handoffToken);
      return { ok: false, code: 'HANDOFF_EXPIRED', message: 'Handoff token expired' };
    }

    const targetShard = this.shards.get(record.toShardId);
    if (!targetShard) {
      this.handoffs.delete(handoffToken);
      return { ok: false, code: 'SHARD_NOT_FOUND', message: `Shard ${record.toShardId} was not found` };
    }
    const targetMeta = this.metas.get(record.toShardId);
    if (targetMeta?.status === 'draining') {
      return { ok: false, code: 'SHARD_DRAINING', message: `Shard ${record.toShardId} is draining` };
    }

    const snapshot = await targetShard.transferIn({
      player: record.player,
      handoffToken: record.token,
      toPosition: record.toPosition,
      toFacing: record.toFacing
    });
    this.handoffs.delete(handoffToken);
    return { ok: true, snapshot };
  }

  async drain(shardId: string): Promise<void> {
    await this.updateStatus(shardId, 'draining');
  }

  async close(shardId: string): Promise<void> {
    const shard = this.shards.get(shardId);
    if (!shard && !this.metas.has(shardId)) {
      throw new Error(`SHARD_NOT_FOUND:${shardId}`);
    }
    shard?.dispose();
    this.shards.delete(shardId);
    await this.updateStatus(shardId, 'closed');
  }

  async closeAll(): Promise<void> {
    for (const shardId of [...this.metas.keys()]) {
      await this.close(shardId);
    }
  }

  private createMeta(shardId: string, mapId: string, status: ShardStatus, template: WorldTemplate | undefined): ShardMeta {
    const now = this.options.clock.now();
    return {
      shardId,
      mapId,
      status,
      playerCount: 0,
      lastTickAt: now,
      contentRevision: template?.meta?.contentRevision ?? 1,
      createdAt: now
    };
  }

  private async updateStatus(shardId: string, status: ShardStatus): Promise<void> {
    const meta = this.metas.get(shardId);
    if (!meta) {
      throw new Error(`SHARD_NOT_FOUND:${shardId}`);
    }
    await this.setMeta({
      ...this.refreshRuntimeMeta(meta),
      status,
      lastTickAt: this.options.clock.now()
    });
  }

  private async setMeta(meta: ShardMeta): Promise<void> {
    this.metas.set(meta.shardId, clone(meta));
    await this.options.storage.shardMetas.upsert(meta);
  }

  private refreshRuntimeMeta(meta: ShardMeta): ShardMeta {
    const shard = this.shards.get(meta.shardId);
    if (!shard) {
      return meta;
    }
    const state = shard.inspectState();
    return {
      ...meta,
      mapId: state.mapId,
      playerCount: state.playerCount,
      lastTickAt: this.options.clock.now()
    };
  }

  private createShardOptions(input: SpawnShardInput, template: WorldTemplate, contentExtensions: WorldShardOptions['contentExtensions']): WorldShardOptions {
    const merged = {
      ...(this.options.fallbackDefaults ?? {}),
      ...(this.options.defaultsByMap[template.mapId] ?? this.options.defaultsByMap[input.mapId] ?? {}),
      ...(input.overrides ?? {})
    };
    const aoiRadiusCells = this.requireNumber(merged.aoiRadiusCells, input.shardId, 'aoiRadiusCells');
    const maxMoveCellsPerSecond = this.requireNumber(merged.maxMoveCellsPerSecond, input.shardId, 'maxMoveCellsPerSecond');
    return {
      ...merged,
      shardId: input.shardId,
      template,
      storage: this.options.storage,
      clock: this.options.clock,
      aoiRadiusCells,
      maxMoveCellsPerSecond,
      contentExtensions
    };
  }

  private requireNumber(value: unknown, shardId: string, field: string): number {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      throw new Error(`INVALID_SHARD_DEFAULTS:${shardId}:${field}`);
    }
    return value;
  }

  private createHandoffToken(playerId: string, fromShardId: string, toShardId: string): string {
    this.handoffSequence += 1;
    return `handoff:${fromShardId}:${toShardId}:${playerId}:${this.options.clock.now()}:${this.handoffSequence}`;
  }

  private async tryLazySpawn(shardId: string): Promise<{ ok: true; shard: WorldShard } | { ok: false }> {
    const mapId = this.deriveMapIdFromAutoShardId(shardId);
    if (!mapId) {
      return { ok: false };
    }
    try {
      const shard = await this.spawn({ shardId, mapId });
      return { ok: true, shard };
    } catch {
      return { ok: false };
    }
  }

  private deriveMapIdFromAutoShardId(shardId: string): string | undefined {
    const prefix = 'auto-';
    if (!shardId.startsWith(prefix)) {
      return undefined;
    }
    const mapId = shardId.slice(prefix.length);
    return mapId.length > 0 ? mapId : undefined;
  }
}

function clone<T>(value: T): T {
  return structuredClone(value);
}
