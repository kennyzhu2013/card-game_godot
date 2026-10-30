import type {
  AoiDeltaEvent,
  AoiDeltaEventType,
  AoiZoneConfig,
  CombatLockZone,
  GridPosition,
  PlayerWorldState,
  WorldEntity,
  WorldRegion
} from './types.js';

export interface AoiSnapshot {
  players: PlayerWorldState[];
  entities: WorldEntity[];
  combatLocks: CombatLockZone[];
}

export interface AoiVisibilitySubject {
  type: 'player' | 'entity' | 'lock';
  subjectId: string;
  position: GridPosition;
}

export interface AoiVisibility {
  zoneId: string;
  deltaMode: AoiZoneConfig['deltaMode'];
  players: string[];
  entities: string[];
  combatLocks: string[];
  subjects: Record<string, AoiVisibilitySubject>;
}

export interface AoiSystemOptions {
  defaultZone: AoiZoneConfig;
  zones?: AoiZoneConfig[];
  regions?: WorldRegion[];
}

export class AoiSystem {
  private readonly defaultZone: AoiZoneConfig;
  private readonly zones = new Map<string, AoiZoneConfig>();
  private readonly regions: WorldRegion[];

  constructor(input: number | AoiZoneConfig | AoiSystemOptions) {
    if (typeof input === 'number') {
      this.defaultZone = createSingleRadiusZone(input);
      this.regions = [];
      this.zones.set(this.defaultZone.zoneId, this.defaultZone);
      return;
    }

    if ('playersRadiusCells' in input) {
      this.defaultZone = input;
      this.regions = [];
      this.zones.set(input.zoneId, input);
      return;
    }

    this.defaultZone = input.defaultZone;
    this.regions = input.regions ?? [];
    for (const zone of input.zones ?? [input.defaultZone]) {
      this.zones.set(zone.zoneId, zone);
    }
    this.zones.set(input.defaultZone.zoneId, input.defaultZone);
  }

  visibleFrom(
    origin: GridPosition,
    players: PlayerWorldState[],
    entities: WorldEntity[],
    combatLocks: CombatLockZone[]
  ): AoiSnapshot {
    const visibility = this.captureVisibilityFrom(origin, players, entities, combatLocks);
    const visiblePlayerIds = new Set(visibility.players);
    const visibleEntityIds = new Set(visibility.entities);
    const visibleLockIds = new Set(visibility.combatLocks);
    return {
      players: players.filter((player) => visiblePlayerIds.has(player.playerId)),
      entities: entities.filter((entity) => visibleEntityIds.has(entity.entityId)),
      combatLocks: combatLocks.filter((lock) => visibleLockIds.has(lock.combatLockId))
    };
  }

  playersWithin(origin: GridPosition, players: PlayerWorldState[], radiusCells: number = this.defaultZone.playersRadiusCells): PlayerWorldState[] {
    return players.filter((player) => withinRadius(origin, player.position, radiusCells));
  }

  captureVisibilityFrom(
    origin: GridPosition,
    players: PlayerWorldState[],
    entities: WorldEntity[],
    combatLocks: CombatLockZone[]
  ): AoiVisibility {
    const zone = this.resolveZone(origin);
    const visibility: AoiVisibility = {
      zoneId: zone.zoneId,
      deltaMode: zone.deltaMode,
      players: [],
      entities: [],
      combatLocks: [],
      subjects: {}
    };

    for (const player of players) {
      visibility.subjects[player.playerId] = {
        type: 'player',
        subjectId: player.playerId,
        position: clonePosition(player.position)
      };
      if (withinRadius(origin, player.position, zone.playersRadiusCells)) {
        visibility.players.push(player.playerId);
      }
    }

    for (const entity of entities) {
      visibility.subjects[entity.entityId] = {
        type: 'entity',
        subjectId: entity.entityId,
        position: clonePosition(entity.position)
      };
      if (withinRadius(origin, entity.position, zone.entitiesRadiusCells)) {
        visibility.entities.push(entity.entityId);
      }
    }

    for (const lock of combatLocks) {
      visibility.subjects[lock.combatLockId] = {
        type: 'lock',
        subjectId: lock.combatLockId,
        position: clonePosition(lock.center)
      };
      if (withinRadius(origin, lock.center, zone.combatLocksRadiusCells + lock.radius)) {
        visibility.combatLocks.push(lock.combatLockId);
      }
    }

    return visibility;
  }

  diffVisibility(previous: AoiVisibility, next: AoiVisibility, tick: number): AoiDeltaEvent[] {
    if (next.deltaMode !== 'event') {
      return [];
    }

    return [
      ...diffIds(previous.players, next.players, 'player_leave', previous, next, tick),
      ...diffIds(next.players, previous.players, 'player_enter', previous, next, tick),
      ...diffIds(previous.entities, next.entities, 'entity_leave', previous, next, tick),
      ...diffIds(next.entities, previous.entities, 'entity_enter', previous, next, tick),
      ...diffIds(previous.combatLocks, next.combatLocks, 'lock_leave', previous, next, tick),
      ...diffIds(next.combatLocks, previous.combatLocks, 'lock_enter', previous, next, tick)
    ];
  }

  private resolveZone(origin: GridPosition): AoiZoneConfig {
    const region = this.regions.find((candidate) => {
      const bounds = candidate.bounds;
      return origin.x >= bounds.x &&
        origin.y >= bounds.y &&
        origin.x < bounds.x + bounds.width &&
        origin.y < bounds.y + bounds.height;
    });
    if (region?.aoiZoneId) {
      return this.zones.get(region.aoiZoneId) ?? this.defaultZone;
    }
    return this.defaultZone;
  }
}

export function gridDistance(a: GridPosition, b: GridPosition): number {
  return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
}

function withinRadius(a: GridPosition, b: GridPosition, radius: number): boolean {
  return gridDistance(a, b) <= radius;
}

function createSingleRadiusZone(radiusCells: number): AoiZoneConfig {
  return {
    zoneId: 'default',
    playersRadiusCells: radiusCells,
    entitiesRadiusCells: radiusCells,
    combatLocksRadiusCells: radiusCells,
    deltaMode: 'full'
  };
}

function diffIds(
  candidates: string[],
  comparison: string[],
  eventType: AoiDeltaEventType,
  previous: AoiVisibility,
  next: AoiVisibility,
  tick: number
): AoiDeltaEvent[] {
  const comparisonSet = new Set(comparison);
  return candidates
    .filter((subjectId) => !comparisonSet.has(subjectId))
    .sort((a, b) => a.localeCompare(b))
    .map((subjectId) => {
      const subject = next.subjects[subjectId] ?? previous.subjects[subjectId];
      return {
        type: eventType,
        subjectId,
        position: clonePosition(subject.position),
        zoneId: next.zoneId,
        tick
      };
    });
}

function clonePosition(position: GridPosition): GridPosition {
  return { x: position.x, y: position.y };
}
