import { describe, expect, it } from 'vitest';
import { CombatInstance } from './combatInstance.js';
import { CombatRouter } from './combatRouter.js';
import type { CombatLockZone, PlayerWorldState } from '../world/types.js';

const player: PlayerWorldState = {
  playerId: 'player-1',
  displayName: 'Player 1',
  position: { x: 0, y: 0 },
  facing: 'south',
  movementState: 'idle',
  combatLockId: null,
  lastMoveSeq: 1,
  updatedAt: 1
};

const lock: CombatLockZone = {
  combatLockId: 'lock-1',
  shardId: 'm3-dev',
  center: { x: 0, y: 0 },
  radius: 3,
  state: 'active',
  participantPlayerIds: ['player-1'],
  spectatorPlayerIds: [],
  hostileEntityIds: ['wolf-1'],
  createdAt: 1,
  updatedAt: 1
};

describe('CombatRouter', () => {
  it('rejects combat actions when the player has no active lock', () => {
    const router = new CombatRouter(new Map(), { now: () => 1000 });

    expect(router.dispatch(player, { action: 'basic_attack', targetId: 'wolf-1' })).toMatchObject({
      ok: false,
      code: 'COMBAT_NOT_ACTIVE'
    });
  });

  it('routes actions into the active combat instance', () => {
    const router = new CombatRouter(new Map([['lock-1', new CombatInstance(lock)]]), { now: () => 1000 });

    const result = router.dispatch({ ...player, movementState: 'locked', combatLockId: 'lock-1' }, { action: 'basic_attack', targetId: 'wolf-1' });

    expect(result).toMatchObject({
      ok: true,
      state: { combatLockId: 'lock-1', actionCount: 1 }
    });
  });
});
