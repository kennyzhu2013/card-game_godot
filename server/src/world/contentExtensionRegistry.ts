import type { MapTemplateRegistry } from './mapTemplateRegistry.js';
import type {
  ContentExtension,
  ContentExtensionAction,
  ContentExtensionActionType,
  ContentExtensionMeta,
  ContentExtensionScope,
  ContentExtensionTrigger
} from './types.js';

const VALID_SCOPES = new Set<ContentExtensionScope>([
  'interaction_actions',
  'entity_state_machines',
  'delta_emitters'
]);

const VALID_ACTION_TYPES = new Set<ContentExtensionActionType>([
  'set_state',
  'emit_delta',
  'broadcast',
  'lock_combat'
]);

export class ContentExtensionRegistry {
  constructor(private readonly templateRegistry: MapTemplateRegistry) {}

  async list(mapId: string): Promise<ContentExtension[]> {
    return (await this.load(mapId)).extensions;
  }

  async meta(mapId: string): Promise<ContentExtensionMeta[]> {
    const { extensions } = await this.load(mapId);
    return extensions.map((extension) => ({
      extensionId: extension.extensionId,
      loaded: true,
      triggerCount: extension.triggers.length,
      actionCount: extension.actions.length
    }));
  }

  async get(mapId: string, extensionId: string): Promise<ContentExtension | undefined> {
    return (await this.list(mapId)).find((extension) => extension.extensionId === extensionId);
  }

  private async load(mapId: string): Promise<{ extensions: ContentExtension[] }> {
    const template = await this.templateRegistry.load(mapId);
    return {
      extensions: this.normalizeExtensions(template.mapId, template.contentExtensions ?? [])
    };
  }

  private normalizeExtensions(mapId: string, rawExtensions: unknown): ContentExtension[] {
    if (!Array.isArray(rawExtensions)) {
      throw new Error(`INVALID_CONTENT_EXTENSIONS:${mapId}:invalid_collection`);
    }

    const seen = new Set<string>();
    return rawExtensions.map((extension, index) => this.normalizeExtension(mapId, extension, index, seen));
  }

  private normalizeExtension(mapId: string, extension: unknown, index: number, seen: Set<string>): ContentExtension {
    if (!isPlainObject(extension)) {
      throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:extension_${index}:invalid_shape`);
    }

    const extensionId = readString(extension.extensionId);
    if (!extensionId) {
      throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:extension_${index}:missing_extension_id`);
    }
    if (seen.has(extensionId)) {
      throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:duplicate_extension`);
    }
    seen.add(extensionId);

    const rawScope = readString(extension.scope);
    if (!VALID_SCOPES.has(rawScope as ContentExtensionScope)) {
      throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_scope`);
    }
    const scope = rawScope as ContentExtensionScope;

    return {
      extensionId,
      scope,
      triggers: this.normalizeTriggers(mapId, extensionId, extension.triggers),
      actions: this.normalizeActions(mapId, extensionId, extension.actions)
    };
  }

  private normalizeTriggers(mapId: string, extensionId: string, rawTriggers: unknown): ContentExtensionTrigger[] {
    if (!Array.isArray(rawTriggers) || rawTriggers.length === 0) {
      throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_triggers`);
    }

    return rawTriggers.map((trigger, index) => {
      if (!isPlainObject(trigger)) {
        throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_trigger:${index}:invalid_shape`);
      }

      const entityIdPattern = readString(trigger.entityIdPattern);
      if (!entityIdPattern) {
        throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_trigger:${index}:missing_entity_id_pattern`);
      }

      const action = readString(trigger.action);
      if (!action) {
        throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_trigger:${index}:missing_action`);
      }

      if (trigger.preconditions !== undefined && !isPlainObject(trigger.preconditions)) {
        throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_trigger:${index}:invalid_preconditions`);
      }

      return {
        entityIdPattern,
        action,
        ...(trigger.preconditions !== undefined ? { preconditions: clone(trigger.preconditions) } : {})
      };
    });
  }

  private normalizeActions(mapId: string, extensionId: string, rawActions: unknown): ContentExtensionAction[] {
    if (!Array.isArray(rawActions) || rawActions.length === 0) {
      throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_actions`);
    }

    return rawActions.map((action, index) => {
      if (!isPlainObject(action)) {
        throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_action:${index}:invalid_shape`);
      }

      const rawType = readString(action.type);
      if (!VALID_ACTION_TYPES.has(rawType as ContentExtensionActionType)) {
        throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_action:${index}:invalid_type`);
      }
      const type = rawType as ContentExtensionActionType;
      if (!isPlainObject(action.params)) {
        throw new Error(`INVALID_CONTENT_EXTENSION:${mapId}:${extensionId}:invalid_action:${index}:invalid_params`);
      }

      return {
        type,
        params: clone(action.params)
      };
    });
  }
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function readString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}
