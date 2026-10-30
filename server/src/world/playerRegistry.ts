import type { PlayerWorldState } from './types.js';

export class PlayerRegistry {
  private readonly players = new Map<string, PlayerWorldState>();

  upsert(player: PlayerWorldState): PlayerWorldState {
    const copy = clone(player);
    this.players.set(copy.playerId, copy);
    return clone(copy);
  }

  get(playerId: string): PlayerWorldState | undefined {
    const player = this.players.get(playerId);
    return player ? clone(player) : undefined;
  }

  list(): PlayerWorldState[] {
    return [...this.players.values()]
      .sort((a, b) => a.playerId.localeCompare(b.playerId))
      .map((player) => clone(player));
  }

  remove(playerId: string): void {
    this.players.delete(playerId);
  }
}

function clone<T>(value: T): T {
  return structuredClone(value);
}
