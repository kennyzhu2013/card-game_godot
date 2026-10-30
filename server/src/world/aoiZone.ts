import type { AoiZoneConfig } from './types.js';

const DEFAULT_AOI_ZONE_ID = 'default';

export function createDefaultAoiZone(zoneId: string = DEFAULT_AOI_ZONE_ID): AoiZoneConfig {
  return {
    zoneId,
    playersRadiusCells: 30,
    entitiesRadiusCells: 30,
    combatLocksRadiusCells: 6,
    deltaMode: 'full'
  };
}

export function validateAoiZones(mapId: string, zones: AoiZoneConfig[], defaultAoiZoneId: string): void {
  const seen = new Set<string>();
  let hasDefault = false;
  for (const zone of zones) {
    if (!zone.zoneId) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${mapId}:invalid_aoi_zone:missing_zone_id`);
    }
    if (seen.has(zone.zoneId)) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${mapId}:duplicate_aoi_zone:${zone.zoneId}`);
    }
    seen.add(zone.zoneId);
    if (zone.zoneId === defaultAoiZoneId) {
      hasDefault = true;
    }
    validateRadius(mapId, zone.zoneId, 'players_radius', zone.playersRadiusCells);
    validateRadius(mapId, zone.zoneId, 'entities_radius', zone.entitiesRadiusCells);
    validateRadius(mapId, zone.zoneId, 'combat_locks_radius', zone.combatLocksRadiusCells);
    if (zone.deltaMode !== 'event' && zone.deltaMode !== 'full') {
      throw new Error(`INVALID_WORLD_TEMPLATE:${mapId}:invalid_aoi_zone:${zone.zoneId}:delta_mode`);
    }
  }

  if (!hasDefault) {
    throw new Error(`INVALID_WORLD_TEMPLATE:${mapId}:missing_default_aoi_zone:${defaultAoiZoneId || DEFAULT_AOI_ZONE_ID}`);
  }
}

function validateRadius(mapId: string, zoneId: string, field: string, value: number): void {
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`INVALID_WORLD_TEMPLATE:${mapId}:invalid_aoi_zone:${zoneId}:${field}`);
  }
}
