import { createMonsterRuntime, type MonsterRuntime } from './monsterRuntime.js';
import type { GridPosition, MonsterSpawn, MonsterTemplate, WorldDelta } from './types.js';

export interface MonsterRespawnTemplateSource {
  loadSync(monsterId: string): MonsterTemplate;
}

export interface MonsterRespawnSystemOptions {
  templates: MonsterRespawnTemplateSource;
  shardId: string;
  mapId: string;
}

export interface MonsterRespawnResult {
  spawn: MonsterSpawn;
  runtime: MonsterRuntime;
  delta: WorldDelta;
}

interface PendingRespawn {
  spawn: MonsterSpawn;
  scheduledAt: number;
  dueAt: number;
  weeklyOnlyOnReset: boolean;
}

export class MonsterRespawnSystem {
  private readonly pending = new Map<string, PendingRespawn>();
  private deltaVersion = 0;

  constructor(private readonly options: MonsterRespawnSystemOptions) {}

  schedule(spawn: MonsterSpawn, now: number): void {
    if (!spawn.active) {
      return;
    }
    const template = this.options.templates.loadSync(spawn.monsterId);
    this.pending.set(spawn.spawnId, {
      spawn: cloneSpawn(spawn),
      scheduledAt: now,
      dueAt: now + template.respawn.timerMs,
      weeklyOnlyOnReset: template.respawn.weeklyOnlyOnReset
    });
  }

  tick(now: number): MonsterRespawnResult[] {
    const results: MonsterRespawnResult[] = [];
    for (const pending of [...this.pending.values()].sort((a, b) => a.scheduledAt - b.scheduledAt)) {
      if (pending.weeklyOnlyOnReset || now < pending.dueAt) {
        continue;
      }
      results.push(this.spawnFromPending(pending, now));
      this.pending.delete(pending.spawn.spawnId);
    }
    return results;
  }

  weeklyReset(now: number): MonsterRespawnResult[] {
    const results: MonsterRespawnResult[] = [];
    for (const pending of [...this.pending.values()].sort((a, b) => a.scheduledAt - b.scheduledAt)) {
      if (!pending.weeklyOnlyOnReset) {
        continue;
      }
      results.push(this.spawnFromPending(pending, now));
      this.pending.delete(pending.spawn.spawnId);
    }
    return results;
  }

  private spawnFromPending(pending: PendingRespawn, now: number): MonsterRespawnResult {
    const template = this.options.templates.loadSync(pending.spawn.monsterId);
    const spawn = cloneSpawn(pending.spawn);
    spawn.position = scatterPosition(spawn.position, template.respawn.scatterRadiusCells, spawn.spawnId);
    const runtime = createMonsterRuntime(spawn, template, now);
    const delta = this.createSpawnDelta(runtime, pending.spawn, now);
    return { spawn: cloneSpawn(pending.spawn), runtime, delta };
  }

  private createSpawnDelta(runtime: MonsterRuntime, spawn: MonsterSpawn, now: number): WorldDelta {
    const version = this.nextDeltaVersion();
    return {
      deltaId: `${this.options.shardId}-monster-respawn-${version}`,
      shardId: this.options.shardId,
      mapId: this.options.mapId,
      actorPlayerId: 'system',
      targetEntityId: runtime.entityId,
      type: 'entity_spawned',
      patch: {
        spawnId: spawn.spawnId,
        monsterId: spawn.monsterId,
        state: runtime.state,
        position: { ...runtime.position },
        hp: runtime.hp
      },
      createdAt: now,
      version
    };
  }

  private nextDeltaVersion(): number {
    this.deltaVersion += 1;
    return this.deltaVersion;
  }
}

function scatterPosition(anchor: GridPosition, radiusCells: number, seed: string): GridPosition {
  if (radiusCells <= 0) {
    return { ...anchor };
  }
  const span = radiusCells * 2 + 1;
  const hash = hashString(seed);
  const dx = (hash % span) - radiusCells;
  const maxDy = radiusCells - Math.abs(dx);
  const dySpan = maxDy * 2 + 1;
  const dy = (Math.floor(hash / span) % dySpan) - maxDy;
  return {
    x: Math.max(0, anchor.x + dx),
    y: Math.max(0, anchor.y + dy)
  };
}

function hashString(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) >>> 0;
  }
  return hash;
}

function cloneSpawn(spawn: MonsterSpawn): MonsterSpawn {
  return {
    ...spawn,
    position: { ...spawn.position },
    patrolAnchorOverride: spawn.patrolAnchorOverride ? { ...spawn.patrolAnchorOverride } : undefined
  };
}
