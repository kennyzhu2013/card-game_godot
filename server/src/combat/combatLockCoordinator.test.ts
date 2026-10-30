import { describe, expect, it } from 'vitest';
import { CombatLockCoordinator } from './combatLockCoordinator.js';
import type { CombatLockZone, PlayerWorldState, WorldEntity } from '../world/types.js';

describe('CombatLockCoordinator', () => {
  it('locks participants inside radius and leaves non-participants moving', () => {
    const coordinator = new CombatLockCoordinator({ defaultRadius: 3 });
    const players: PlayerWorldState[] = [
      { playerId: 'inside', displayName: 'Inside', position: { x: 1, y: 1 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 },
      { playerId: 'outside', displayName: 'Outside', position: { x: 9, y: 9 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 }
    ];
    const hostiles: WorldEntity[] = [
      { entityId: 'wolf-1', type: 'npc', position: { x: 2, y: 1 }, state: { hostile: true }, version: 1 }
    ];

    const result = coordinator.createLock('m3-dev', { x: 0, y: 0 }, players, hostiles, 1000);

    expect(result.lock.participantPlayerIds).toEqual(['inside']);
    expect(result.lock.hostileEntityIds).toEqual(['wolf-1']);
    expect(result.players.find((player) => player.playerId === 'inside')?.movementState).toBe('locked');
    expect(result.players.find((player) => player.playerId === 'outside')?.movementState).toBe('idle');
  });

  it('treats active monster entities as combat lock hostiles', () => {
    const coordinator = new CombatLockCoordinator({ defaultRadius: 3 });
    const players: PlayerWorldState[] = [
      { playerId: 'inside', displayName: 'Inside', position: { x: 1, y: 1 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 }
    ];
    const hostiles: WorldEntity[] = [
      { entityId: 'wolf-1', type: 'monster', position: { x: 2, y: 1 }, state: { hostile: true }, version: 1 }
    ];

    const result = coordinator.createLock('m3-dev', { x: 0, y: 0 }, players, hostiles, 1000);

    expect(result.lock.hostileEntityIds).toEqual(['wolf-1']);
  });

  it('unlocks participants when a lock closes', () => {
    const coordinator = new CombatLockCoordinator({ defaultRadius: 3 });
    const lock: CombatLockZone = { combatLockId: 'lock-1', shardId: 'm3-dev', center: { x: 0, y: 0 }, radius: 3, state: 'active', participantPlayerIds: ['inside'], spectatorPlayerIds: [], hostileEntityIds: ['wolf-1'], createdAt: 1, updatedAt: 1 };
    const players: PlayerWorldState[] = [
      { playerId: 'inside', displayName: 'Inside', position: { x: 1, y: 1 }, facing: 'south', movementState: 'locked', combatLockId: 'lock-1', lastMoveSeq: 1, updatedAt: 1 }
    ];

    const result = coordinator.closeLock(lock, players, 2000);

    expect(result.lock.state).toBe('closed');
    expect(result.players[0]).toMatchObject({ movementState: 'idle', combatLockId: null, updatedAt: 2000 });
  });
});
