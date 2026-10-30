import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  ProgressionRegistry,
  computeIdentityVisibility,
  createInitialProgressionState
} from './progressionRegistry.js';

const pixelAssetManifestPath = path.resolve(process.cwd(), '../client/assets/art_specs/pixel_asset_manifest.json');

describe('ProgressionRegistry', () => {
  it('creates a complete initial PlayerProgressionState for a new player', () => {
    const state = createInitialProgressionState('player-1', 1000);

    expect(state).toMatchObject({
      playerId: 'player-1',
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
      aoiActorLabel: 'Player',
      aoiActorVariantId: 'player',
      protocolVersion: 'v3',
      updatedAt: 1000
    });
    expect(state.contentHash).toBeTruthy();
  });

  it('returns clones and creates initial state from getOrCreateProgression', () => {
    const registry = new ProgressionRegistry({ now: () => 1000 });

    const first = registry.getOrCreateProgression('player-1');
    first.level = 99;
    const second = registry.getProgression('player-1');

    expect(first.level).toBe(99);
    expect(second).toMatchObject({
      playerId: 'player-1',
      level: 1,
      protocolVersion: 'v3'
    });
  });

  it('patches progression with clamped authoritative fields and a new content hash', () => {
    const registry = new ProgressionRegistry({ now: () => 1000 });
    const initial = registry.getOrCreateProgression('player-1');

    const patched = registry.patchProgression('player-1', {
      level: 0,
      exp: -5,
      expToNextLevel: 0,
      skillPoints: -1,
      sequence: 99,
      sanity: 200,
      pathway: 'tide_priestess',
      transformationDepth: 2,
      transformedSpecies: 'mist_slime',
      transformExpiresAt: -1,
      speciesReputation: { mist_slime: 12 }
    });

    expect(patched).toMatchObject({
      level: 1,
      exp: 0,
      expToNextLevel: 1,
      skillPoints: 0,
      pathway: 'tide_priestess',
      sequence: 9,
      sanity: 100,
      isOutOfControl: true,
      transformationDepth: 2,
      transformedSpecies: 'mist_slime',
      transformExpiresAt: -1,
      speciesReputation: { mist_slime: 12 },
      updatedAt: 1000
    });
    expect(patched.contentHash).not.toBe(initial.contentHash);
  });

  it('coalesces repeated patches to the same field inside the configured window', () => {
    let now = 1000;
    const registry = new ProgressionRegistry({ now: () => now, patchCoalesceMs: 200 });
    registry.getOrCreateProgression('player-1');

    const first = registry.patchProgression('player-1', { exp: 10 });
    now = 1100;
    const second = registry.patchProgression('player-1', { exp: 20 });
    now = 1250;
    const third = registry.patchProgression('player-1', { exp: 30 });

    expect(first.exp).toBe(10);
    expect(second.exp).toBe(10);
    expect(second.updatedAt).toBe(first.updatedAt);
    expect(second.contentHash).toBe(first.contentHash);
    expect(third.exp).toBe(30);
  });

  it('computes AOI projection without exposing identity during out-of-control or assimilation', () => {
    const registry = new ProgressionRegistry({ now: () => 1000 });
    registry.setProgression('player-1', {
      ...createInitialProgressionState('player-1', 1000),
      level: 12,
      pathway: 'ashen_sovereign',
      sequence: 3,
      isOutOfControl: true,
      transformationDepth: 3,
      transformedSpecies: 'mist_wolf',
      aoiActorVariantId: 'enemy_mist_wolf'
    });

    const projection = registry.computeAoiVisibleProjection('player-1');

    expect(projection).toEqual({
      playerId: 'player-1',
      aoiActorLabel: '狂暴的旅人',
      aoiActorVariantId: 'enemy_mist_wolf',
      level: 12,
      pathway: 'ashen_sovereign',
      sequenceBadge: 'sequence_3',
      outOfControlAura: true,
      transformationVisible: true,
      identityVisibleInAoi: false
    });
  });

  it('uses a default AOI actor variant id that exists in the pixel asset manifest', () => {
    const state = createInitialProgressionState('player-1', 1000);
    const manifest = JSON.parse(readFileSync(pixelAssetManifestPath, 'utf8')) as {
      assets?: Record<string, unknown>;
    };

    expect(manifest.assets ?? {}).toHaveProperty(state.aoiActorVariantId);
  });

  it('uses shared identity visibility logic for normal, pollution cap, disguise, assimilation, and OOC states', () => {
    const normal = createInitialProgressionState('normal', 1000);
    const disguised = {
      ...normal,
      playerId: 'disguised',
      transformationDepth: 1 as const,
      transformedSpecies: 'mist_slime'
    };
    const assimilated = {
      ...normal,
      playerId: 'assimilated',
      transformationDepth: 3 as const,
      transformedSpecies: 'mist_wolf'
    };
    const ooc = {
      ...normal,
      playerId: 'ooc',
      sanity: 100
    };

    expect(computeIdentityVisibility(normal)).toMatchObject({
      identityVisibleInAoi: true,
      aoiActorLabel: 'Player'
    });
    expect(computeIdentityVisibility(disguised)).toMatchObject({
      identityVisibleInAoi: false,
      aoiActorLabel: 'mist_slime'
    });
    expect(computeIdentityVisibility(assimilated)).toMatchObject({
      identityVisibleInAoi: false,
      aoiActorLabel: 'mist_wolf'
    });
    expect(computeIdentityVisibility(ooc)).toMatchObject({
      identityVisibleInAoi: false,
      aoiActorLabel: '狂暴的旅人'
    });
  });

  it('registers milestones with 60s de-duplication and shard broadcast thresholds', () => {
    let now = 1000;
    const registry = new ProgressionRegistry({ now: () => now });

    const levelNine = registry.registerLevelUp('player-1', 9, 'combat');
    const levelTen = registry.registerLevelUp('player-1', 10, 'combat');
    const duplicateLevelTen = registry.registerLevelUp('player-1', 10, 'combat');
    now = 62_000;
    const levelTenAfterWindow = registry.registerLevelUp('player-1', 10, 'combat');
    const sequenceFour = registry.registerSequenceAdvanced('player-1', 4, 'ritual-1');
    const sequenceThree = registry.registerSequenceAdvanced('player-1', 3, 'ritual-2');
    const outOfControl = registry.registerOutOfControl('player-1', 'sanity_zero');

    expect(levelNine).toMatchObject({ shardBroadcast: false, duplicate: false });
    expect(levelTen).toMatchObject({
      milestoneId: 'player-1:level_up:10',
      shardBroadcast: true,
      duplicate: false,
      payload: { level: 10, source: 'combat' }
    });
    expect(duplicateLevelTen).toMatchObject({ duplicate: true, shardBroadcast: true });
    expect(levelTenAfterWindow).toMatchObject({ duplicate: false, shardBroadcast: true });
    expect(sequenceFour).toMatchObject({ shardBroadcast: false });
    expect(sequenceThree).toMatchObject({ shardBroadcast: true });
    expect(outOfControl).toMatchObject({ shardBroadcast: true, payload: { source: 'sanity_zero' } });
  });
});
