import { describe, expect, it } from 'vitest';
import { createMemoryStorage } from '../storage/memoryStorage.js';
import type { Storage } from '../storage/storage.js';
import type { ContentExtension, WorldTemplate } from './types.js';
import { ContentExtensionRegistry } from './contentExtensionRegistry.js';
import { MapTemplateRegistry } from './mapTemplateRegistry.js';

describe('ContentExtensionRegistry', () => {
  it('returns an empty extension list for the canonical Mist Harbor template and keeps alias loading consistent', async () => {
    const registry = new ContentExtensionRegistry(new MapTemplateRegistry(createMemoryStorage()));

    const canonical = await registry.list('mist-harbor-test');
    const alias = await registry.list('m3-test');

    expect(canonical).toEqual(alias);
    expect(canonical).toEqual([]);
    expect(await registry.get('m3-test', 'anything')).toBeUndefined();
    expect(await registry.meta('m3-test')).toEqual([]);
  });

  it('loads multiple extensions without cross-contaminating clones', async () => {
    const template = await createMemoryStorage().worldTemplates.load('mist-harbor-test');
    const customTemplate: WorldTemplate = {
      ...template,
      mapId: 'legacy-map',
      templateHash: 'legacy-map-v1',
      meta: {
        ...template.meta,
        mapId: 'legacy-map',
        templateHash: 'legacy-map-v1',
        displayName: 'Legacy Map'
      },
      contentExtensions: [
        {
          extensionId: 'm2-foo',
          scope: 'interaction_actions',
          triggers: [
            {
              entityIdPattern: 'm2-foo-target',
              action: 'inspect'
            }
          ],
          actions: [
            {
              type: 'set_state',
              params: {
                state: 'ready'
              }
            }
          ]
        },
        {
          extensionId: 'm3-bar',
          scope: 'delta_emitters',
          triggers: [
            {
              entityIdPattern: 'm3-bar-target',
              action: 'scout',
              preconditions: {
                stage: 'one'
              }
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

    const registry = new ContentExtensionRegistry(new MapTemplateRegistry(createTemplateStorage(customTemplate)));
    const extensions = await registry.list('legacy-map');

    expect(extensions.map((extension) => extension.extensionId)).toEqual(['m2-foo', 'm3-bar']);
    expect(await registry.meta('legacy-map')).toEqual([
      {
        extensionId: 'm2-foo',
        loaded: true,
        triggerCount: 1,
        actionCount: 1
      },
      {
        extensionId: 'm3-bar',
        loaded: true,
        triggerCount: 1,
        actionCount: 1
      }
    ]);

    extensions[0].triggers[0].entityIdPattern = 'mutated-pattern';
    const reread = await registry.get('legacy-map', 'm2-foo');
    expect(reread?.triggers[0].entityIdPattern).toBe('m2-foo-target');
  });

  it('rejects malformed extensions before exposing them', async () => {
    const template = await createMemoryStorage().worldTemplates.load('mist-harbor-test');
    const invalidTemplate: WorldTemplate = {
      ...template,
      mapId: 'invalid-map',
      templateHash: 'invalid-map-v1',
      meta: {
        ...template.meta,
        mapId: 'invalid-map',
        templateHash: 'invalid-map-v1',
        displayName: 'Invalid Map'
      },
      contentExtensions: [
        {
          extensionId: 'bad-extension',
          scope: 'not-a-valid-scope' as ContentExtension['scope'],
          triggers: [
            {
              entityIdPattern: 'bad-target',
              action: 'inspect'
            }
          ],
          actions: [
            {
              type: 'set_state',
              params: {}
            }
          ]
        }
      ]
    };

    const registry = new ContentExtensionRegistry(new MapTemplateRegistry(createTemplateStorage(invalidTemplate)));

    await expect(registry.list('invalid-map')).rejects.toThrow(
      'INVALID_CONTENT_EXTENSION:invalid-map:bad-extension:invalid_scope'
    );
  });
});

function createTemplateStorage(template: WorldTemplate): Storage {
  const clone = structuredClone(template);
  return {
    sessions: {} as Storage['sessions'],
    playerStates: {} as Storage['playerStates'],
    playerProgressionStates: {} as Storage['playerProgressionStates'],
    worldTemplates: {
      async list(): Promise<WorldTemplate[]> {
        return [structuredClone(clone)];
      },
      async load(mapId: string): Promise<WorldTemplate> {
        if (mapId !== clone.mapId) {
          throw new Error(`UNKNOWN_WORLD_TEMPLATE:${mapId}`);
        }
        return structuredClone(clone);
      }
    },
    shardMetas: {} as Storage['shardMetas'],
    worldDeltas: {} as Storage['worldDeltas']
  } as Storage;
}
