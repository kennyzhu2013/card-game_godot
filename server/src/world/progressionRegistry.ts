import type {
  AoiVisibleProgression,
  PathwayId,
  PlayerProgressionState,
  ProgressionMilestone,
  SequenceBadge
} from './types.js';

export interface ProgressionRegistryOptions {
  now: () => number;
  patchCoalesceMs?: number;
  milestoneDedupeMs?: number;
}

export type ProgressionPatch = Partial<Omit<PlayerProgressionState, 'playerId' | 'protocolVersion' | 'updatedAt' | 'contentHash'>>;

export interface IdentityVisibility {
  identityVisibleInAoi: boolean;
  aoiActorLabel: string;
}

const DEFAULT_PATCH_COALESCE_MS = 200;
const DEFAULT_MILESTONE_DEDUPE_MS = 60_000;
const DEFAULT_AOI_ACTOR_LABEL = 'Player';
const DEFAULT_AOI_ACTOR_VARIANT_ID = 'player';
const OUT_OF_CONTROL_LABEL = '狂暴的旅人';

const PATHWAYS = new Set<PathwayId>([
  'unselected',
  'tide_priestess',
  'ashen_sovereign',
  'dream_weaver',
  'star_abyss_walker',
  'duke_eternal_night',
  'polymath',
  'rust_bellsmith'
]);

export class ProgressionRegistry {
  private readonly states = new Map<string, PlayerProgressionState>();
  private readonly lastPatchByField = new Map<string, number>();
  private readonly milestones = new Map<string, number>();
  private readonly patchCoalesceMs: number;
  private readonly milestoneDedupeMs: number;

  constructor(private readonly options: ProgressionRegistryOptions) {
    this.patchCoalesceMs = options.patchCoalesceMs ?? DEFAULT_PATCH_COALESCE_MS;
    this.milestoneDedupeMs = options.milestoneDedupeMs ?? DEFAULT_MILESTONE_DEDUPE_MS;
  }

  getProgression(playerId: string): PlayerProgressionState | null {
    const state = this.states.get(playerId);
    return state ? clone(state) : null;
  }

  getOrCreateProgression(playerId: string): PlayerProgressionState {
    const existing = this.states.get(playerId);
    if (existing) {
      return clone(existing);
    }
    const initial = createInitialProgressionState(playerId, this.options.now());
    this.states.set(playerId, initial);
    return clone(initial);
  }

  setProgression(playerId: string, state: PlayerProgressionState): void {
    const sanitized = finalizeState({
      ...state,
      playerId,
      updatedAt: state.updatedAt
    });
    this.states.set(playerId, sanitized);
  }

  patchProgression(playerId: string, patch: ProgressionPatch): PlayerProgressionState {
    const current = this.getOrCreateProgression(playerId);
    const now = this.options.now();
    const acceptedPatch: ProgressionPatch = {};
    for (const [field, value] of Object.entries(patch) as [keyof ProgressionPatch, ProgressionPatch[keyof ProgressionPatch]][]) {
      const key = `${playerId}:${String(field)}`;
      const lastPatchedAt = this.lastPatchByField.get(key);
      if (lastPatchedAt !== undefined && now - lastPatchedAt < this.patchCoalesceMs) {
        continue;
      }
      this.lastPatchByField.set(key, now);
      acceptedPatch[field] = clone(value) as never;
    }
    if (Object.keys(acceptedPatch).length === 0) {
      return current;
    }
    const updated = finalizeState({
      ...current,
      ...acceptedPatch,
      playerId,
      protocolVersion: 'v3',
      updatedAt: now
    });
    this.states.set(playerId, updated);
    return clone(updated);
  }

  computeAoiVisibleProjection(playerId: string): AoiVisibleProgression {
    const state = this.getOrCreateProgression(playerId);
    return {
      playerId,
      aoiActorLabel: state.aoiActorLabel,
      aoiActorVariantId: state.aoiActorVariantId,
      level: state.level,
      pathway: state.pathway,
      sequenceBadge: toSequenceBadge(state.sequence),
      outOfControlAura: state.isOutOfControl,
      transformationVisible: state.transformationDepth > 0,
      identityVisibleInAoi: state.identityVisibleInAoi
    };
  }

  registerLevelUp(playerId: string, newLevel: number, source: string): ProgressionMilestone {
    const level = clampInteger(newLevel, 1, 999);
    return this.registerMilestone({
      milestoneId: `${playerId}:level_up:${level}`,
      playerId,
      type: 'level_up',
      shardBroadcast: level >= 10,
      payload: { level, source }
    });
  }

  registerSequenceAdvanced(playerId: string, newSequence: number, ritualId: string): ProgressionMilestone {
    const sequence = clampInteger(newSequence, 0, 9);
    return this.registerMilestone({
      milestoneId: `${playerId}:sequence_advanced:${sequence}`,
      playerId,
      type: 'sequence_advanced',
      shardBroadcast: sequence <= 3,
      payload: { sequence, ritualId }
    });
  }

  registerOutOfControl(playerId: string, source: string): ProgressionMilestone {
    return this.registerMilestone({
      milestoneId: `${playerId}:out_of_control:${source}`,
      playerId,
      type: 'out_of_control',
      shardBroadcast: true,
      payload: { source }
    });
  }

  registerTransformationStarted(playerId: string, depth: number, species: string): ProgressionMilestone {
    const transformationDepth = clampTransformationDepth(depth);
    return this.registerMilestone({
      milestoneId: `${playerId}:transformation_started:${transformationDepth}:${species}`,
      playerId,
      type: 'transformation_started',
      shardBroadcast: false,
      payload: { depth: transformationDepth, species }
    });
  }

  registerTransformationEnded(playerId: string, reason: string): ProgressionMilestone {
    return this.registerMilestone({
      milestoneId: `${playerId}:transformation_ended:${reason}`,
      playerId,
      type: 'transformation_ended',
      shardBroadcast: false,
      payload: { reason }
    });
  }

  isMilestoneDuplicate(playerId: string, milestoneId: string): boolean {
    const occurredAt = this.milestones.get(`${playerId}:${milestoneId}`);
    return occurredAt !== undefined && this.options.now() - occurredAt < this.milestoneDedupeMs;
  }

  private registerMilestone(input: Omit<ProgressionMilestone, 'occurredAt' | 'duplicate'>): ProgressionMilestone {
    const now = this.options.now();
    const key = `${input.playerId}:${input.milestoneId}`;
    const previous = this.milestones.get(key);
    const duplicate = previous !== undefined && now - previous < this.milestoneDedupeMs;
    if (!duplicate) {
      this.milestones.set(key, now);
    }
    return {
      ...input,
      occurredAt: duplicate && previous !== undefined ? previous : now,
      duplicate
    };
  }
}

export function createInitialProgressionState(playerId: string, now: number): PlayerProgressionState {
  return finalizeState({
    playerId,
    level: 1,
    exp: 0,
    expToNextLevel: 100,
    skillPoints: 0,
    pathway: 'unselected',
    sequence: 9,
    sanity: 0,
    isOutOfControl: false,
    recoveryQuestId: null,
    transformationDepth: 0,
    transformedSpecies: null,
    transformExpiresAt: null,
    speciesReputation: {},
    identityVisibleInAoi: true,
    aoiActorLabel: DEFAULT_AOI_ACTOR_LABEL,
    aoiActorVariantId: DEFAULT_AOI_ACTOR_VARIANT_ID,
    protocolVersion: 'v3',
    updatedAt: now,
    contentHash: ''
  });
}

export function computeIdentityVisibility(state: Pick<
  PlayerProgressionState,
  'isOutOfControl' | 'sanity' | 'transformationDepth' | 'transformedSpecies'
>): IdentityVisibility {
  if (state.isOutOfControl || state.sanity >= 100) {
    return { identityVisibleInAoi: false, aoiActorLabel: OUT_OF_CONTROL_LABEL };
  }
  if (state.transformationDepth > 0 && state.transformedSpecies) {
    return { identityVisibleInAoi: false, aoiActorLabel: state.transformedSpecies };
  }
  return { identityVisibleInAoi: true, aoiActorLabel: DEFAULT_AOI_ACTOR_LABEL };
}

function finalizeState(state: PlayerProgressionState): PlayerProgressionState {
  const transformationDepth = clampTransformationDepth(state.transformationDepth);
  const sanitized: PlayerProgressionState = {
    ...state,
    level: clampInteger(state.level, 1, 999),
    exp: Math.max(0, finiteNumber(state.exp, 0)),
    expToNextLevel: Math.max(1, finiteNumber(state.expToNextLevel, 100)),
    skillPoints: Math.max(0, clampInteger(state.skillPoints, 0, Number.MAX_SAFE_INTEGER)),
    pathway: PATHWAYS.has(state.pathway) ? state.pathway : 'unselected',
    sequence: clampInteger(state.sequence, 0, 9),
    sanity: clampInteger(state.sanity, 0, 100),
    isOutOfControl: state.isOutOfControl || state.sanity >= 100,
    recoveryQuestId: state.recoveryQuestId,
    transformationDepth,
    transformedSpecies: state.transformedSpecies,
    transformExpiresAt: state.transformExpiresAt === null ? null : finiteNumber(state.transformExpiresAt, -1),
    speciesReputation: clone(state.speciesReputation ?? {}),
    aoiActorVariantId: state.aoiActorVariantId || DEFAULT_AOI_ACTOR_VARIANT_ID,
    protocolVersion: 'v3'
  };
  const identity = computeIdentityVisibility(sanitized);
  sanitized.identityVisibleInAoi = identity.identityVisibleInAoi;
  sanitized.aoiActorLabel = identity.aoiActorLabel;
  sanitized.contentHash = createContentHash({ ...sanitized, contentHash: '' });
  return clone(sanitized);
}

function toSequenceBadge(sequence: number): SequenceBadge {
  if (sequence <= 0) {
    return 'sequence_0';
  }
  if (sequence <= 5) {
    return `sequence_${sequence}` as SequenceBadge;
  }
  return 'none';
}

function clampTransformationDepth(value: number): 0 | 1 | 2 | 3 {
  return clampInteger(value, 0, 3) as 0 | 1 | 2 | 3;
}

function clampInteger(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.min(Math.max(Math.trunc(value), min), max);
}

function finiteNumber(value: number | null, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function createContentHash(state: Omit<PlayerProgressionState, 'contentHash'> & { contentHash?: string }): string {
  const serialized = JSON.stringify(stableValue(state));
  let hash = 2166136261;
  for (let i = 0; i < serialized.length; i += 1) {
    hash ^= serialized.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(stableValue);
  }
  if (value && typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>)
      .filter(([key]) => key !== 'contentHash')
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, entryValue]) => [key, stableValue(entryValue)]);
    return Object.fromEntries(entries);
  }
  return value;
}

function clone<T>(value: T): T {
  return structuredClone(value);
}
