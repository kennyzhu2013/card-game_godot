import { randomUUID } from 'node:crypto';
import { gridDistance } from '../world/aoiSystem.js';
import type { CombatLockZone, GridPosition, PlayerWorldState, WorldEntity } from '../world/types.js';

export interface CombatLockCoordinatorOptions {
  defaultRadius: number;
}

export interface CombatLockCreationResult {
  lock: CombatLockZone;
  players: PlayerWorldState[];
}

export interface CombatLockCloseResult {
  lock: CombatLockZone;
  players: PlayerWorldState[];
}

export class CombatLockCoordinator {
  constructor(private readonly options: CombatLockCoordinatorOptions) {}

  createLock(
    shardId: string,
    center: GridPosition,
    players: PlayerWorldState[],
    hostiles: WorldEntity[],
    now: number,
    radius = this.options.defaultRadius
  ): CombatLockCreationResult {
    const combatLockId = `combat-lock-${randomUUID()}`;
    const participantPlayerIds = players
      .filter((player) => gridDistance(center, player.position) <= radius)
      .map((player) => player.playerId);
    const hostileEntityIds = hostiles
      .filter((entity) => (entity.type === 'npc' || entity.type === 'monster') && entity.state.hostile === true)
      .filter((entity) => gridDistance(center, entity.position) <= radius)
      .map((entity) => entity.entityId);

    const lock: CombatLockZone = {
      combatLockId,
      shardId,
      center: { ...center },
      radius,
      state: 'active',
      participantPlayerIds,
      spectatorPlayerIds: [],
      hostileEntityIds,
      createdAt: now,
      updatedAt: now
    };

    return {
      lock,
      players: players.map((player) => {
        if (!participantPlayerIds.includes(player.playerId)) {
          return { ...player, position: { ...player.position } };
        }
        return {
          ...player,
          position: { ...player.position },
          movementState: 'locked',
          combatLockId,
          updatedAt: now
        };
      })
    };
  }

  closeLock(lock: CombatLockZone, players: PlayerWorldState[], now: number): CombatLockCloseResult {
    const participantIds = new Set(lock.participantPlayerIds);
    const closedLock: CombatLockZone = {
      ...lock,
      center: { ...lock.center },
      state: 'closed',
      participantPlayerIds: [...lock.participantPlayerIds],
      spectatorPlayerIds: [...lock.spectatorPlayerIds],
      hostileEntityIds: [...lock.hostileEntityIds],
      updatedAt: now
    };

    return {
      lock: closedLock,
      players: players.map((player) => {
        if (!participantIds.has(player.playerId)) {
          return { ...player, position: { ...player.position } };
        }
        return {
          ...player,
          position: { ...player.position },
          movementState: 'idle',
          combatLockId: null,
          updatedAt: now
        };
      })
    };
  }
}
