import type { Direction, GridPosition, PlayerWorldState } from './types.js';

export interface MovementSystemOptions {
  maxMoveCellsPerSecond: number;
  blocked: Set<string>;
}

export interface WorldMoveInput {
  playerId: string;
  seq: number;
  from: GridPosition;
  to: GridPosition;
  startedAt: number;
}

export type MovementRejectReason = 'stale_seq' | 'speed' | 'blocked' | 'locked' | 'origin_mismatch' | 'unknown';

export type MovementValidationResult =
  | { ok: true; player: PlayerWorldState }
  | {
      ok: false;
      reason: MovementRejectReason;
      acceptedSeq: number;
      authoritativePosition: GridPosition;
    };

export class MovementSystem {
  private readonly maxMoveCellsPerSecond: number;
  private readonly blocked: Set<string>;

  constructor(options: MovementSystemOptions) {
    this.maxMoveCellsPerSecond = options.maxMoveCellsPerSecond;
    this.blocked = options.blocked;
  }

  validate(player: PlayerWorldState, move: WorldMoveInput, now: number): MovementValidationResult {
    if (player.movementState === 'locked' || player.combatLockId !== null) {
      return this.reject(player, 'locked');
    }
    if (move.playerId !== player.playerId) {
      return this.reject(player, 'unknown');
    }
    if (move.seq <= player.lastMoveSeq) {
      return this.reject(player, 'stale_seq');
    }
    if (!samePosition(player.position, move.from)) {
      return this.reject(player, 'origin_mismatch');
    }
    if (this.blocked.has(positionKey(move.to))) {
      return this.reject(player, 'blocked');
    }
    if (this.exceedsSpeed(move, now)) {
      return this.reject(player, 'speed');
    }

    return {
      ok: true,
      player: {
        ...player,
        position: { ...move.to },
        facing: facingFromDelta(move.from, move.to, player.facing),
        movementState: 'moving',
        lastMoveSeq: move.seq,
        updatedAt: now
      }
    };
  }

  private exceedsSpeed(move: WorldMoveInput, now: number): boolean {
    const elapsedSeconds = Math.max((now - move.startedAt) / 1000, 0.001);
    const allowedDistance = this.maxMoveCellsPerSecond * elapsedSeconds;
    return manhattanDistance(move.from, move.to) > allowedDistance + 0.0001;
  }

  private reject(player: PlayerWorldState, reason: MovementRejectReason): MovementValidationResult {
    return {
      ok: false,
      reason,
      acceptedSeq: player.lastMoveSeq,
      authoritativePosition: { ...player.position }
    };
  }
}

export function positionKey(position: GridPosition): string {
  return `${position.x},${position.y}`;
}

function samePosition(a: GridPosition, b: GridPosition): boolean {
  return a.x === b.x && a.y === b.y;
}

function manhattanDistance(a: GridPosition, b: GridPosition): number {
  return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
}

function facingFromDelta(from: GridPosition, to: GridPosition, fallback: Direction): Direction {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  if (Math.abs(dx) >= Math.abs(dy) && dx > 0) {
    return 'east';
  }
  if (Math.abs(dx) >= Math.abs(dy) && dx < 0) {
    return 'west';
  }
  if (dy > 0) {
    return 'south';
  }
  if (dy < 0) {
    return 'north';
  }
  return fallback;
}
