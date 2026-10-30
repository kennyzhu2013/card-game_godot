import { describe, expect, it } from 'vitest';
import { AoiSystem } from './aoiSystem.js';
import type { CombatLockZone, PlayerWorldState, WorldEntity } from './types.js';

describe('AoiSystem', () => {
  it('returns only players, entities, and combat locks within radius', () => {
    const aoi = new AoiSystem(3);
    const players: PlayerWorldState[] = [
      { playerId: 'near', displayName: 'Near', position: { x: 2, y: 1 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 },
      { playerId: 'far', displayName: 'Far', position: { x: 10, y: 10 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 }
    ];
    const entities: WorldEntity[] = [
      { entityId: 'tree-1', type: 'resource', position: { x: 1, y: 1 }, state: {}, version: 1 },
      { entityId: 'ore-1', type: 'resource', position: { x: 8, y: 8 }, state: {}, version: 1 }
    ];
    const locks: CombatLockZone[] = [
      { combatLockId: 'near-lock', shardId: 'm3-dev', center: { x: 2, y: 0 }, radius: 2, state: 'active', participantPlayerIds: [], spectatorPlayerIds: [], hostileEntityIds: [], createdAt: 1, updatedAt: 1 },
      { combatLockId: 'far-lock', shardId: 'm3-dev', center: { x: 12, y: 12 }, radius: 2, state: 'active', participantPlayerIds: [], spectatorPlayerIds: [], hostileEntityIds: [], createdAt: 1, updatedAt: 1 }
    ];

    const result = aoi.visibleFrom({ x: 0, y: 0 }, players, entities, locks);

    expect(result.players.map((player) => player.playerId)).toEqual(['near']);
    expect(result.entities.map((entity) => entity.entityId)).toEqual(['tree-1']);
    expect(result.combatLocks.map((lock) => lock.combatLockId)).toEqual(['near-lock']);
  });

  it('applies separate player, entity, and combat lock radii from the active AOI zone', () => {
    const aoi = new AoiSystem({
      zoneId: 'wide-locks',
      playersRadiusCells: 20,
      entitiesRadiusCells: 10,
      combatLocksRadiusCells: 30,
      deltaMode: 'event'
    });
    const players: PlayerWorldState[] = [
      { playerId: 'near-player', displayName: 'Near', position: { x: 20, y: 0 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 },
      { playerId: 'far-player', displayName: 'Far', position: { x: 21, y: 0 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 }
    ];
    const entities: WorldEntity[] = [
      { entityId: 'near-entity', type: 'resource', position: { x: 10, y: 0 }, state: {}, version: 1 },
      { entityId: 'far-entity', type: 'resource', position: { x: 11, y: 0 }, state: {}, version: 1 }
    ];
    const locks: CombatLockZone[] = [
      { combatLockId: 'near-lock', shardId: 'm3-dev', center: { x: 32, y: 0 }, radius: 2, state: 'active', participantPlayerIds: [], spectatorPlayerIds: [], hostileEntityIds: [], createdAt: 1, updatedAt: 1 },
      { combatLockId: 'far-lock', shardId: 'm3-dev', center: { x: 33, y: 0 }, radius: 2, state: 'active', participantPlayerIds: [], spectatorPlayerIds: [], hostileEntityIds: [], createdAt: 1, updatedAt: 1 }
    ];

    const result = aoi.visibleFrom({ x: 0, y: 0 }, players, entities, locks);

    expect(result.players.map((player) => player.playerId)).toEqual(['near-player']);
    expect(result.entities.map((entity) => entity.entityId)).toEqual(['near-entity']);
    expect(result.combatLocks.map((lock) => lock.combatLockId)).toEqual(['near-lock']);
  });

  it('diffs AOI visibility into deterministic enter and leave events', () => {
    const aoi = new AoiSystem({
      zoneId: 'tight',
      playersRadiusCells: 3,
      entitiesRadiusCells: 3,
      combatLocksRadiusCells: 3,
      deltaMode: 'event'
    });
    const previous = aoi.captureVisibilityFrom(
      { x: 0, y: 0 },
      [{ playerId: 'player-2', displayName: 'Player 2', position: { x: 3, y: 0 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 1, updatedAt: 1 }],
      [{ entityId: 'ore-1', type: 'resource', position: { x: 5, y: 0 }, state: {}, version: 1 }],
      []
    );
    const next = aoi.captureVisibilityFrom(
      { x: 0, y: 0 },
      [{ playerId: 'player-2', displayName: 'Player 2', position: { x: 4, y: 0 }, facing: 'south', movementState: 'idle', combatLockId: null, lastMoveSeq: 2, updatedAt: 2 }],
      [{ entityId: 'ore-1', type: 'resource', position: { x: 2, y: 0 }, state: {}, version: 1 }],
      []
    );

    expect(aoi.diffVisibility(previous, next, 42)).toEqual([
      { type: 'player_leave', subjectId: 'player-2', position: { x: 4, y: 0 }, zoneId: 'tight', tick: 42 },
      { type: 'entity_enter', subjectId: 'ore-1', position: { x: 2, y: 0 }, zoneId: 'tight', tick: 42 }
    ]);
  });
});
