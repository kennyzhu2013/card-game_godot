import { describe, expect, it } from 'vitest';
import { MovementSystem } from './movementSystem.js';
import type { PlayerWorldState } from './types.js';

const basePlayer: PlayerWorldState = {
  playerId: 'player-1',
  displayName: 'Player 1',
  position: { x: 2, y: 2 },
  facing: 'south',
  movementState: 'idle',
  combatLockId: null,
  lastMoveSeq: 1,
  updatedAt: 1000
};

describe('MovementSystem', () => {
  it('accepts valid movement and updates sequence', () => {
    const system = new MovementSystem({ maxMoveCellsPerSecond: 3, blocked: new Set<string>() });
    const result = system.validate(basePlayer, {
      playerId: 'player-1',
      seq: 2,
      from: { x: 2, y: 2 },
      to: { x: 3, y: 2 },
      startedAt: 1000
    }, 1400);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.player.position).toEqual({ x: 3, y: 2 });
      expect(result.player.lastMoveSeq).toBe(2);
      expect(result.player.facing).toBe('east');
    }
  });

  it('rejects stale, too fast, blocked, mismatched-origin, and locked movement', () => {
    const system = new MovementSystem({ maxMoveCellsPerSecond: 3, blocked: new Set(['5,5']) });

    expect(system.validate(basePlayer, {
      playerId: 'player-1',
      seq: 1,
      from: { x: 2, y: 2 },
      to: { x: 3, y: 2 },
      startedAt: 1000
    }, 1400)).toMatchObject({ ok: false, reason: 'stale_seq' });
    expect(system.validate(basePlayer, {
      playerId: 'player-1',
      seq: 2,
      from: { x: 2, y: 2 },
      to: { x: 10, y: 2 },
      startedAt: 1000
    }, 1100)).toMatchObject({ ok: false, reason: 'speed' });
    expect(system.validate(basePlayer, {
      playerId: 'player-1',
      seq: 2,
      from: { x: 2, y: 2 },
      to: { x: 5, y: 5 },
      startedAt: 1000
    }, 3000)).toMatchObject({ ok: false, reason: 'blocked' });
    expect(system.validate(basePlayer, {
      playerId: 'player-1',
      seq: 2,
      from: { x: 9, y: 9 },
      to: { x: 3, y: 2 },
      startedAt: 1000
    }, 1400)).toMatchObject({ ok: false, reason: 'origin_mismatch' });
    expect(system.validate({ ...basePlayer, movementState: 'locked' }, {
      playerId: 'player-1',
      seq: 2,
      from: { x: 2, y: 2 },
      to: { x: 3, y: 2 },
      startedAt: 1000
    }, 1400)).toMatchObject({ ok: false, reason: 'locked' });
  });
});
