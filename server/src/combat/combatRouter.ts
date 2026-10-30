import type { Clock } from '../core/time.js';
import type { PlayerWorldState } from '../world/types.js';
import type { CombatActionInput, CombatStatePayload } from './combatInstance.js';
import { CombatInstance } from './combatInstance.js';

export type CombatRouteResult =
  | { ok: true; state: CombatStatePayload }
  | { ok: false; code: string; message: string };

export type CombatActionPayload = Omit<CombatActionInput, 'playerId'>;

export class CombatRouter {
  constructor(
    private readonly instances: Map<string, CombatInstance>,
    private readonly clock: Clock
  ) {}

  dispatch(player: PlayerWorldState, payload: CombatActionPayload): CombatRouteResult {
    if (!player.combatLockId) {
      return { ok: false, code: 'COMBAT_NOT_ACTIVE', message: 'Player is not in an active combat lock' };
    }

    const instance = this.instances.get(player.combatLockId);
    if (!instance) {
      return { ok: false, code: 'COMBAT_NOT_ACTIVE', message: 'Combat lock has no active instance' };
    }

    return {
      ok: true,
      state: instance.submitAction({ playerId: player.playerId, ...payload }, this.clock.now())
    };
  }
}
