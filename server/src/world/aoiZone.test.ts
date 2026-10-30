import { describe, expect, it } from 'vitest';
import { createDefaultAoiZone, validateAoiZones } from './aoiZone.js';

describe('AoiZone', () => {
  it('creates the default zone used by legacy templates', () => {
    expect(createDefaultAoiZone()).toEqual({
      zoneId: 'default',
      playersRadiusCells: 30,
      entitiesRadiusCells: 30,
      combatLocksRadiusCells: 6,
      deltaMode: 'full'
    });
  });

  it('rejects duplicate zone ids and a missing default zone', () => {
    expect(() =>
      validateAoiZones('mist-harbor-test', [createDefaultAoiZone(), { ...createDefaultAoiZone(), zoneId: 'default' }], 'default')
    ).toThrow('INVALID_WORLD_TEMPLATE:mist-harbor-test:duplicate_aoi_zone:default');

    expect(() =>
      validateAoiZones('mist-harbor-test', [{ ...createDefaultAoiZone(), zoneId: 'shoreline' }], 'default')
    ).toThrow('INVALID_WORLD_TEMPLATE:mist-harbor-test:missing_default_aoi_zone:default');
  });
});
