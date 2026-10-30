import { describe, expect, it } from 'vitest';
import { ManualClock } from '../core/time.js';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import type { Storage } from '../storage/storage.js';
import { MapTemplateRegistry } from './mapTemplateRegistry.js';
import { ShardRegistry } from './shardRegistry.js';
import type { WorldTemplate } from './types.js';

function createRegistry() {
  const storage = createMemoryStorage();
  const clock = new ManualClock(10_000);
  const registry = new ShardRegistry({
    storage,
    clock,
    templateRegistry: new MapTemplateRegistry(storage),
    defaultsByMap: {
      'mist-harbor-test': {
        aoiRadiusCells: 3,
        maxMoveCellsPerSecond: 3,
        combatLockRadiusCells: 5
      }
    }
  });
  return { registry, storage, clock };
}

describe('ShardRegistry', () => {
  it('spawns shards and exposes stable metadata by id and map', async () => {
    const { registry, storage, clock } = createRegistry();

    const pending = registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });

    expect(registry.meta('m3-dev')).toMatchObject({
      shardId: 'm3-dev',
      mapId: 'mist-harbor-test',
      status: 'starting',
      playerCount: 0,
      contentRevision: 1,
      createdAt: 10_000
    });

    const shard = await pending;

    expect(registry.get('m3-dev')).toBe(shard);
    expect(registry.meta('m3-dev')).toMatchObject({
      shardId: 'm3-dev',
      mapId: 'mist-harbor-test',
      status: 'running',
      playerCount: 0,
      lastTickAt: 10_000
    });
    expect(registry.list().map((meta) => meta.shardId)).toEqual(['m3-dev']);
    expect(registry.listByMap('mist-harbor-test').map((meta) => meta.shardId)).toEqual(['m3-dev']);
    expect(await storage.shardMetas.get('m3-dev')).toMatchObject({
      shardId: 'm3-dev',
      status: 'running'
    });

    clock.advance(500);
    await shard.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    expect(registry.meta('m3-dev')).toMatchObject({
      playerCount: 1,
      lastTickAt: 10_500
    });
  });

  it('fails shard startup when content extensions do not parse', async () => {
    const baseStorage = createMemoryStorage();
    const template = await baseStorage.worldTemplates.load('mist-harbor-test');
    const brokenTemplate: WorldTemplate = {
      ...template,
      mapId: 'broken-map',
      templateHash: 'broken-map-v1',
      meta: {
        ...template.meta,
        mapId: 'broken-map',
        templateHash: 'broken-map-v1',
        displayName: 'Broken Map'
      },
      contentExtensions: [
        {
          extensionId: 'broken-extension',
          scope: 'interaction_actions',
          triggers: [
            {
              entityIdPattern: 'broken-target',
              action: 'scout'
            }
          ],
          actions: [
            {
              type: 'set_state',
              params: {}
            }
          ]
        },
        {
          extensionId: 'broken-extension',
          scope: 'interaction_actions',
          triggers: [
            {
              entityIdPattern: 'broken-target',
              action: 'combat_check'
            }
          ],
          actions: [
            {
              type: 'emit_delta',
              params: {
                type: 'state_changed'
              }
            }
          ]
        }
      ]
    };
    const storage: Storage = {
      ...baseStorage,
      worldTemplates: {
        async list() {
          return [structuredClone(brokenTemplate)];
        },
        async load(mapId: string) {
          if (mapId !== brokenTemplate.mapId) {
            throw new Error(`UNKNOWN_WORLD_TEMPLATE:${mapId}`);
          }
          return structuredClone(brokenTemplate);
        }
      }
    };

    const registry = new ShardRegistry({
      storage,
      clock: new ManualClock(10_000),
      templateRegistry: new MapTemplateRegistry(storage),
      defaultsByMap: {
        'broken-map': {
          aoiRadiusCells: 3,
          maxMoveCellsPerSecond: 3
        }
      }
    });

    await expect(registry.spawn({ shardId: 'broken-shard', mapId: 'broken-map' })).rejects.toThrow('EXT_PARSE_FAILED:broken-map');
  });

  it('rejects duplicate shard ids without replacing the existing shard', async () => {
    const { registry } = createRegistry();
    const original = await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });

    await expect(registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' })).rejects.toThrow('SHARD_ALREADY_EXISTS:m3-dev');

    expect(registry.get('m3-dev')).toBe(original);
    expect(registry.list()).toHaveLength(1);
  });

  it('marks shards as draining and closed while preserving discoverable metadata', async () => {
    const { registry, storage } = createRegistry();
    await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });

    await registry.drain('m3-dev');
    expect(registry.meta('m3-dev')).toMatchObject({ status: 'draining' });
    expect(await storage.shardMetas.get('m3-dev')).toMatchObject({ status: 'draining' });

    await registry.close('m3-dev');
    expect(registry.get('m3-dev')).toBeUndefined();
    expect(registry.meta('m3-dev')).toMatchObject({ status: 'closed' });
    expect(registry.listByMap('mist-harbor-test').map((meta) => meta.status)).toEqual(['closed']);
  });

  it('moves players through a handoff token with target position and sequence reset', async () => {
    const { registry } = createRegistry();
    const source = await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });
    await registry.spawn({ shardId: 'm3-eventless', mapId: 'mist-harbor-test' });
    await source.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const begin = await registry.beginTransfer('player-1', 'm3-dev', 'm3-eventless', { x: 6, y: 6 });

    expect(begin).toMatchObject({
      ok: true,
      handoffToken: expect.any(String),
      expiresAt: 15_000
    });
    expect(() => source.createSnapshotFor('player-1')).toThrow('PLAYER_NOT_IN_SHARD:player-1');

    if (!begin.ok) {
      throw new Error('Expected beginTransfer to succeed');
    }
    const complete = await registry.completeTransfer(begin.handoffToken);

    expect(complete).toMatchObject({
      ok: true,
      snapshot: {
        shardId: 'm3-eventless',
        self: {
          playerId: 'player-1',
          position: { x: 6, y: 6 },
          movementState: 'idle',
          combatLockId: null,
          lastMoveSeq: 0
        }
      }
    });
    expect(registry.meta('m3-dev')).toMatchObject({ playerCount: 0 });
    expect(registry.meta('m3-eventless')).toMatchObject({ playerCount: 1 });
  });

  it('allows transfer out from draining shards but rejects incoming transfers to draining shards', async () => {
    const { registry } = createRegistry();
    const source = await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });
    const target = await registry.spawn({ shardId: 'm3-eventless', mapId: 'mist-harbor-test' });
    await source.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });
    await target.enterPlayer({ playerId: 'player-2', displayName: 'Player 2' });
    await registry.drain('m3-dev');

    const outbound = await registry.beginTransfer('player-1', 'm3-dev', 'm3-eventless', { x: 6, y: 6 });
    const inbound = await registry.beginTransfer('player-2', 'm3-eventless', 'm3-dev', { x: 2, y: 2 });

    expect(outbound).toMatchObject({ ok: true });
    expect(inbound).toEqual({
      ok: false,
      code: 'SHARD_DRAINING',
      message: 'Shard m3-dev is draining'
    });
  });

  it('expires handoff tokens after five seconds', async () => {
    const { registry, clock } = createRegistry();
    const source = await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });
    const target = await registry.spawn({ shardId: 'm3-eventless', mapId: 'mist-harbor-test' });
    await source.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const begin = await registry.beginTransfer('player-1', 'm3-dev', 'm3-eventless', { x: 6, y: 6 });
    if (!begin.ok) {
      throw new Error('Expected beginTransfer to succeed');
    }
    clock.advance(5001);

    await expect(registry.completeTransfer(begin.handoffToken)).resolves.toEqual({
      ok: false,
      code: 'HANDOFF_EXPIRED',
      message: 'Handoff token expired'
    });
    expect(() => target.createSnapshotFor('player-1')).toThrow('PLAYER_NOT_IN_SHARD:player-1');
  });

  it('lazily spawns an auto-<mapId> target shard when transferring to an unstarted shard', async () => {
    const storage = createMemoryStorage();
    const clock = new ManualClock(10_000);
    const registry = new ShardRegistry({
      storage,
      clock,
      templateRegistry: new MapTemplateRegistry(storage),
      defaultsByMap: {
        'mist-harbor-test': {
          aoiRadiusCells: 3,
          maxMoveCellsPerSecond: 3,
          combatLockRadiusCells: 5
        }
      },
      fallbackDefaults: {
        aoiRadiusCells: 4,
        maxMoveCellsPerSecond: 4
      }
    });
    const source = await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });
    await source.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    expect(registry.get('auto-mist-harbor-test')).toBeUndefined();

    const begin = await registry.beginTransfer('player-1', 'm3-dev', 'auto-mist-harbor-test', { x: 6, y: 6 });
    expect(begin).toMatchObject({ ok: true });
    if (!begin.ok) {
      throw new Error('Expected lazy beginTransfer to succeed');
    }

    expect(registry.get('auto-mist-harbor-test')).toBeDefined();
    expect(registry.meta('auto-mist-harbor-test')).toMatchObject({
      shardId: 'auto-mist-harbor-test',
      mapId: 'mist-harbor-test',
      status: 'running'
    });

    const complete = await registry.completeTransfer(begin.handoffToken);
    expect(complete).toMatchObject({
      ok: true,
      snapshot: {
        shardId: 'auto-mist-harbor-test',
        self: { playerId: 'player-1', position: { x: 6, y: 6 } }
      }
    });
  });

  it('rejects lazy spawn when the derived mapId is unknown', async () => {
    const { registry } = createRegistry();
    const source = await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });
    await source.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const begin = await registry.beginTransfer('player-1', 'm3-dev', 'auto-nonexistent-map', { x: 2, y: 2 });
    expect(begin).toEqual({
      ok: false,
      code: 'SHARD_NOT_FOUND',
      message: 'Transfer shard was not found'
    });
  });

  it('does not lazy-spawn for shard ids that do not use the auto- prefix', async () => {
    const { registry } = createRegistry();
    const source = await registry.spawn({ shardId: 'm3-dev', mapId: 'mist-harbor-test' });
    await source.enterPlayer({ playerId: 'player-1', displayName: 'Player 1' });

    const begin = await registry.beginTransfer('player-1', 'm3-dev', 'm3-other', { x: 2, y: 2 });
    expect(begin).toEqual({
      ok: false,
      code: 'SHARD_NOT_FOUND',
      message: 'Transfer shard was not found'
    });
  });
}
);
