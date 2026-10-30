import type { Direction, GridPosition, MonsterSpawn, MonsterTemplate } from './types.js';

export type MonsterRuntimeState = 'IDLE' | 'PATROL' | 'ALERT' | 'CHASE' | 'COMBAT_LOCKED' | 'DEAD';

export interface MonsterPreludeState {
  targetPlayerId: string;
  startedAt: number;
  expiresAt: number;
  monsterEntityIds: string[];
}

export interface MonsterRuntime {
  entityId: string;
  spawnId: string;
  templateId: string;
  position: GridPosition;
  facing: Direction;
  state: MonsterRuntimeState;
  hp: number;
  threat: Map<string, number>;
  patrolAnchor: GridPosition;
  patrolTargetIndex: number;
  lastTransitionAt: number;
  lastTickAt: number;
  combatLockId: string | null;
  packMembers: string[];
  pendingPrelude: MonsterPreludeState | null;
}

export function createMonsterRuntime(spawn: MonsterSpawn, template: MonsterTemplate, now: number): MonsterRuntime {
  const patrolAnchor = clonePosition(spawn.patrolAnchorOverride ?? template.patrol.anchorOverride ?? spawn.position);
  return {
    entityId: spawn.storyVisibleId ?? spawn.spawnId,
    spawnId: spawn.spawnId,
    templateId: spawn.monsterId,
    position: clonePosition(spawn.position),
    facing: 'south',
    state: stateFromSpawn(spawn.initialState),
    hp: template.stats.maxHp,
    threat: new Map(),
    patrolAnchor,
    patrolTargetIndex: 0,
    lastTransitionAt: now,
    lastTickAt: now,
    combatLockId: null,
    packMembers: [],
    pendingPrelude: null
  };
}

export function cloneMonsterRuntime(runtime: MonsterRuntime): MonsterRuntime {
  return {
    ...runtime,
    position: clonePosition(runtime.position),
    threat: new Map(runtime.threat),
    patrolAnchor: clonePosition(runtime.patrolAnchor),
    packMembers: [...runtime.packMembers],
    pendingPrelude: runtime.pendingPrelude
      ? {
          ...runtime.pendingPrelude,
          monsterEntityIds: [...runtime.pendingPrelude.monsterEntityIds]
        }
      : null
  };
}

function stateFromSpawn(initialState: MonsterSpawn['initialState']): MonsterRuntimeState {
  switch (initialState) {
    case 'idle':
      return 'IDLE';
    case 'leashed':
    case 'patrol':
    default:
      return 'PATROL';
  }
}

function clonePosition(position: GridPosition): GridPosition {
  return { x: position.x, y: position.y };
}
