import type { Direction, GridPosition, PlayerWorldState, WorldDelta, WorldEntity, ContentExtension } from './types.js';
import { applyContentExtensions, type ContentExtensionCombatLockRequest, type ContentExtensionRuntimeContext } from './contentExtensionRuntime.js';

export type WorldInteractionAction = 'chop' | 'mine' | 'push' | 'inspect' | 'scout' | 'combat_check';

export interface InteractionInput {
  action: WorldInteractionAction;
}

export type InteractionResult =
  | {
      ok: true;
      entity: WorldEntity;
      delta: Pick<WorldDelta, 'type' | 'patch'> | null;
      combatLockRequest?: ContentExtensionCombatLockRequest;
    }
  | { ok: false; code: 'OUT_OF_RANGE' | 'ACTION_NOT_SUPPORTED' | 'ALREADY_DEPLETED' | 'TARGET_LOCKED'; message: string };

export class InteractionSystem {
  constructor(private readonly contentExtensions: ContentExtension[] = []) {}

  apply(
    player: PlayerWorldState,
    entity: WorldEntity,
    input: InteractionInput,
    _now: number,
    context: ContentExtensionRuntimeContext = {}
  ): InteractionResult {
    if (player.movementState === 'locked' || player.combatLockId !== null) {
      return { ok: false, code: 'TARGET_LOCKED', message: 'Player is locked by combat' };
    }
    if (distance(player.position, entity.position) > 2) {
      return { ok: false, code: 'OUT_OF_RANGE', message: 'Interaction target is outside range two' };
    }
    if (input.action === 'inspect') {
      return { ok: true, entity: clone(entity), delta: null };
    }
    if (input.action === 'push') {
      return this.push(player, entity);
    }
    if (input.action === 'chop' || input.action === 'mine') {
      return this.depleteResource(entity, input.action);
    }
    const result = applyContentExtensions(this.contentExtensions, entity, input.action, {
      ...context,
      actorPlayerId: player.playerId
    });
    if (!result) {
      return { ok: false, code: 'ACTION_NOT_SUPPORTED', message: `${input.action} is not supported by this entity` };
    }

    return {
      ok: true,
      entity: result.entity,
      delta: result.delta,
      ...(result.combatLockRequest ? { combatLockRequest: result.combatLockRequest } : {})
    };
  }

  private depleteResource(entity: WorldEntity, action: 'chop' | 'mine'): InteractionResult {
    const expectedKind = action === 'chop' ? 'tree' : 'ore';
    if (entity.type !== 'resource' || entity.state.kind !== expectedKind) {
      return { ok: false, code: 'ACTION_NOT_SUPPORTED', message: `${action} is not supported by this entity` };
    }
    if (entity.state.depleted === true) {
      return { ok: false, code: 'ALREADY_DEPLETED', message: 'Resource is already depleted' };
    }

    const updated: WorldEntity = {
      ...clone(entity),
      state: { ...clone(entity.state), depleted: true },
      version: entity.version + 1
    };
    return {
      ok: true,
      entity: updated,
      delta: {
        type: 'resource_depleted',
        patch: { state: { depleted: true }, version: updated.version }
      }
    };
  }

  private push(player: PlayerWorldState, entity: WorldEntity): InteractionResult {
    if (entity.type !== 'prop' || entity.state.pushable !== true) {
      return { ok: false, code: 'ACTION_NOT_SUPPORTED', message: 'Push is not supported by this entity' };
    }

    const position = nextPosition(entity.position, player.facing);
    const updated: WorldEntity = {
      ...clone(entity),
      position,
      version: entity.version + 1
    };
    return {
      ok: true,
      entity: updated,
      delta: {
        type: 'prop_moved',
        patch: { position, version: updated.version }
      }
    };
  }
}

function distance(a: GridPosition, b: GridPosition): number {
  return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
}

function nextPosition(position: GridPosition, facing: Direction): GridPosition {
  switch (facing) {
    case 'north':
      return { x: position.x, y: position.y - 1 };
    case 'south':
      return { x: position.x, y: position.y + 1 };
    case 'west':
      return { x: position.x - 1, y: position.y };
    case 'east':
      return { x: position.x + 1, y: position.y };
  }
}

function clone<T>(value: T): T {
  return structuredClone(value);
}
