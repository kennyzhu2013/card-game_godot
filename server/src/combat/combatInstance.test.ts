import { describe, expect, it } from 'vitest';
import { CombatInstance } from './combatInstance.js';
import type { CombatLockZone } from '../world/types.js';

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

describe('CombatInstance', () => {
  it('stores submitted actions in order and emits combat state', () => {
    const instance = new CombatInstance(lock);

    const first = instance.submitAction({ playerId: 'player-1', action: 'basic_attack', targetId: 'wolf-1' }, 1000);
    const second = instance.submitAction({ playerId: 'player-1', action: 'guard' }, 1100);

    expect(first.actionCount).toBe(1);
    expect(second).toMatchObject({
      combatLockId: 'lock-1',
      participantPlayerIds: ['player-1'],
      hostileEntityIds: ['wolf-1'],
      actionCount: 2
    });
    expect(instance.actions.map((action) => action.action)).toEqual(['basic_attack', 'guard']);
  });
});
