import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { InteractionSystem } from './interactionSystem.js';
import type { ContentExtension, PlayerWorldState, WorldEntity } from './types.js';

const player: PlayerWorldState = {
  playerId: 'p1',
  displayName: 'P1',
  position: { x: 2, y: 2 },
  facing: 'east',
  movementState: 'idle',
  combatLockId: null,
  lastMoveSeq: 1,
  updatedAt: 1
};

describe('InteractionSystem', () => {
  it('keeps concrete M2 shoreline ids out of server interaction code', () => {
    const interactionSource = readFileSync('src/world/interactionSystem.ts', 'utf8');
    const worldShardSource = readFileSync('src/world/worldShard.ts', 'utf8');

    expect(interactionSource).not.toContain('m2-shoreline-small-threat');
    expect(worldShardSource).not.toContain('m2-shoreline-small-threat');
  });

  it('depletes trees and ores through chop and mine', () => {
    const system = new InteractionSystem();
    const tree: WorldEntity = { entityId: 'tree-1', type: 'resource', position: { x: 3, y: 2 }, state: { kind: 'tree', depleted: false }, version: 1 };

    const result = system.apply(player, tree, { action: 'chop' }, 1000);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.entity.state.depleted).toBe(true);
      expect(result.entity.version).toBe(2);
      expect(result.delta?.type).toBe('resource_depleted');
    }

    const ore: WorldEntity = { entityId: 'ore-1', type: 'resource', position: { x: 4, y: 2 }, state: { kind: 'ore', depleted: false }, version: 1 };
    const mined = system.apply(player, ore, { action: 'mine' }, 1000);
    expect(mined).toMatchObject({ ok: true });
  });

  it('pushes props one grid cell in the player facing direction', () => {
    const system = new InteractionSystem();
    const crate: WorldEntity = { entityId: 'crate-1', type: 'prop', position: { x: 3, y: 2 }, state: { pushable: true }, version: 1 };

    const result = system.apply(player, crate, { action: 'push' }, 1000);

    expect(result).toMatchObject({
      ok: true,
      entity: { position: { x: 4, y: 2 }, version: 2 },
      delta: { type: 'prop_moved', patch: { position: { x: 4, y: 2 } } }
    });
  });

  it('inspects without mutating or creating a delta', () => {
    const system = new InteractionSystem();
    const tree: WorldEntity = { entityId: 'tree-1', type: 'resource', position: { x: 3, y: 2 }, state: { kind: 'tree', depleted: false }, version: 1 };

    const result = system.apply(player, tree, { action: 'inspect' }, 1000);

    expect(result).toMatchObject({ ok: true, entity: tree, delta: null });
  });

  it('applies data-driven shoreline extensions without hardcoded M2 ids in the interaction system', () => {
    const system = new InteractionSystem(createShorelineExtensions());
    const scoutPlayer: PlayerWorldState = { ...player, position: { x: 4, y: 6 } };
    const threat: WorldEntity = {
      entityId: 'm3-reef-watch',
      type: 'npc',
      position: { x: 5, y: 6 },
      state: {
        storyRole: 'reef_watch',
        encounterRole: 'followup_check',
        hostile: true,
        status: 'waiting'
      },
      version: 1
    };

    const scout = system.apply(scoutPlayer, threat, { action: 'scout' }, 1000);
    expect(scout).toMatchObject({
      ok: true,
      entity: {
        version: 2,
        state: {
          storyRole: 'reef_watch',
          status: 'scouted',
          routeAction: 'reef_watch_scouted',
          scoutedBy: 'p1'
        }
      },
      delta: {
        type: 'state_changed',
        patch: {
          state: {
            status: 'scouted',
            routeAction: 'reef_watch_scouted',
            scoutedBy: 'p1'
          },
          version: 2
        }
      }
    });

    if (!scout.ok) {
      return;
    }

    const combatCheck = system.apply(scoutPlayer, scout.entity, { action: 'combat_check' }, 1200);
    expect(combatCheck).toMatchObject({
      ok: true,
      entity: {
        version: 3,
        state: {
          status: 'combat_check_locked',
          routePhase: 'combat_check',
          routeAction: 'reef_watch_combat_check',
          combatCheckBy: 'p1'
        }
      },
      combatLockRequest: {
        combatLockId: 'reef_followup',
        radius: 2
      }
    });

    if (!combatCheck.ok) {
      return;
    }

    expect(system.apply(scoutPlayer, threat, { action: 'combat_check' }, 1000)).toMatchObject({
      ok: false,
      code: 'ACTION_NOT_SUPPORTED'
    });
  });

  it('rejects interactions outside distance two and mismatched actions', () => {
    const system = new InteractionSystem();
    const farOre: WorldEntity = { entityId: 'ore-1', type: 'resource', position: { x: 10, y: 10 }, state: { kind: 'ore', depleted: false }, version: 1 };
    const tree: WorldEntity = { entityId: 'tree-1', type: 'resource', position: { x: 3, y: 2 }, state: { kind: 'tree', depleted: false }, version: 1 };

    expect(system.apply(player, farOre, { action: 'mine' }, 1000)).toMatchObject({ ok: false, code: 'OUT_OF_RANGE' });
    expect(system.apply(player, tree, { action: 'mine' }, 1000)).toMatchObject({ ok: false, code: 'ACTION_NOT_SUPPORTED' });
    expect(system.apply(player, tree, { action: 'scout' }, 1000)).toMatchObject({ ok: false, code: 'ACTION_NOT_SUPPORTED' });
  });
});

function createShorelineExtensions(): ContentExtension[] {
  return [
    {
      extensionId: 'reef-watch-scout',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'm3-reef-watch',
          action: 'scout'
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'scouted',
            routeAction: 'reef_watch_scouted',
            scoutedBy: '$actorPlayerId'
          }
        },
        {
          type: 'emit_delta',
          params: {
            type: 'state_changed'
          }
        }
      ]
    },
    {
      extensionId: 'reef-watch-combat-check',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'm3-reef-watch',
          action: 'combat_check',
          preconditions: {
            status: 'scouted',
            routeAction: 'reef_watch_scouted'
          }
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'combat_check_locked',
            routePhase: 'combat_check',
            routeAction: 'reef_watch_combat_check',
            combatCheckBy: '$actorPlayerId'
          }
        },
        {
          type: 'emit_delta',
          params: {
            type: 'state_changed'
          }
        },
        {
          type: 'lock_combat',
          params: {
            combatLockId: 'reef_followup',
            radius: 2
          }
        }
      ]
    },
    {
      extensionId: 'reef-watch-combat-close',
      scope: 'interaction_actions',
      triggers: [
        {
          entityIdPattern: 'm3-reef-watch',
          action: 'combat_close',
          preconditions: {
            status: 'combat_check_locked',
            routeAction: 'reef_watch_combat_check',
            combatResult: 'victory'
          }
        }
      ],
      actions: [
        {
          type: 'set_state',
          params: {
            status: 'pollution_read_ready',
            routePhase: 'pollution_read',
            routeAction: 'reef_watch_pollution_read_ready',
            combatResult: '$combatResult'
          }
        },
        {
          type: 'emit_delta',
          params: {
            type: 'state_changed'
          }
        }
      ]
    }
  ];
}
