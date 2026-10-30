import type { ContentExtension, WorldDelta, WorldEntity } from './types.js';

export interface ContentExtensionRuntimeContext {
  actorPlayerId?: string;
  combatResult?: string;
  [key: string]: unknown;
}

export interface ContentExtensionCombatLockRequest {
  combatLockId?: string;
  radius?: number;
}

export interface ContentExtensionResolution {
  extensionId: string;
  entity: WorldEntity;
  delta: Pick<WorldDelta, 'type' | 'patch'> | null;
  combatLockRequest: ContentExtensionCombatLockRequest | null;
}

export function applyContentExtensions(
  extensions: ContentExtension[],
  entity: WorldEntity,
  action: string,
  context: ContentExtensionRuntimeContext = {}
): ContentExtensionResolution | null {
  const runtimeContext = {
    entityId: entity.entityId,
    action,
    ...context
  };
  const matched = findMatchingExtension(extensions, entity, action, runtimeContext);
  if (!matched) {
    return null;
  }

  const initialState = clone(entity.state);
  let nextState = clone(entity.state);
  let emitDelta = false;
  let deltaType: WorldDelta['type'] = 'state_changed';
  let combatLockRequest: ContentExtensionCombatLockRequest | null = null;

  for (const actionSpec of matched.extension.actions) {
    const params = resolveTemplateValue(actionSpec.params, runtimeContext);
    switch (actionSpec.type) {
      case 'set_state':
        nextState = {
          ...nextState,
          ...(isPlainObject(params) ? params : {})
        };
        break;
      case 'emit_delta':
        emitDelta = true;
        if (isPlainObject(params) && typeof params.type === 'string' && params.type.length > 0) {
          deltaType = params.type as WorldDelta['type'];
        }
        break;
      case 'lock_combat':
        combatLockRequest = normalizeCombatLockRequest(params);
        break;
      case 'broadcast':
        break;
    }
  }

  const updated: WorldEntity = {
    ...clone(entity),
    state: nextState,
    version: entity.version + 1
  };
  const delta = emitDelta
    ? {
        type: deltaType,
        patch: {
          state: diffState(initialState, nextState),
          version: updated.version
        }
      }
    : null;

  return {
    extensionId: matched.extension.extensionId,
    entity: updated,
    delta,
    combatLockRequest
  };
}

function findMatchingExtension(
  extensions: ContentExtension[],
  entity: WorldEntity,
  action: string,
  runtimeContext: ContentExtensionRuntimeContext
): { extension: ContentExtension } | null {
  for (const extension of extensions) {
    for (const trigger of extension.triggers) {
      if (!matchesTrigger(trigger, entity, action, runtimeContext)) {
        continue;
      }
      return { extension };
    }
  }
  return null;
}

function matchesTrigger(
  trigger: ContentExtension['triggers'][number],
  entity: WorldEntity,
  action: string,
  runtimeContext: ContentExtensionRuntimeContext
): boolean {
  if (!matchesPattern(trigger.entityIdPattern, entity.entityId)) {
    return false;
  }
  if (trigger.action !== action) {
    return false;
  }

  if (!trigger.preconditions) {
    return true;
  }

  const stateContext = {
    ...clone(entity.state),
    ...runtimeContext
  };
  return matchesRecord(trigger.preconditions, stateContext);
}

function normalizeCombatLockRequest(value: unknown): ContentExtensionCombatLockRequest | null {
  if (!isPlainObject(value)) {
    return null;
  }
  const request: ContentExtensionCombatLockRequest = {};
  if (typeof value.combatLockId === 'string' && value.combatLockId.length > 0) {
    request.combatLockId = value.combatLockId;
  }
  if (typeof value.radius === 'number' && Number.isFinite(value.radius)) {
    request.radius = value.radius;
  }
  return Object.keys(request).length > 0 ? request : null;
}

function matchesPattern(pattern: string, value: string): boolean {
  if (!pattern.includes('*') && !pattern.includes('?')) {
    return pattern === value;
  }

  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, '\\$&');
  const regexSource = `^${escaped.replace(/\*/g, '.*').replace(/\?/g, '.')}$`;
  return new RegExp(regexSource).test(value);
}

function matchesRecord(expected: Record<string, unknown>, actual: Record<string, unknown>): boolean {
  return Object.entries(expected).every(([key, value]) => matchesValue(value, actual[key]));
}

function matchesValue(expected: unknown, actual: unknown): boolean {
  if (Array.isArray(expected)) {
    return Array.isArray(actual) && expected.length === actual.length && expected.every((item, index) => matchesValue(item, actual[index]));
  }
  if (isPlainObject(expected)) {
    return isPlainObject(actual) && matchesRecord(expected, actual);
  }
  return Object.is(expected, actual);
}

function resolveTemplateValue(value: unknown, context: ContentExtensionRuntimeContext): unknown {
  if (typeof value === 'string' && value.startsWith('$')) {
    const key = value.slice(1);
    if (Object.prototype.hasOwnProperty.call(context, key)) {
      return context[key];
    }
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((item) => resolveTemplateValue(item, context));
  }
  if (isPlainObject(value)) {
    const resolved: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value)) {
      resolved[key] = resolveTemplateValue(entry, context);
    }
    return resolved;
  }
  return value;
}

function diffState(before: Record<string, unknown>, after: Record<string, unknown>): Record<string, unknown> {
  const patch: Record<string, unknown> = {};
  for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
    if (JSON.stringify(before[key]) !== JSON.stringify(after[key])) {
      patch[key] = clone(after[key]);
    }
  }
  return patch;
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
