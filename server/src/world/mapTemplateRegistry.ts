import type { Storage } from '../storage/storage.js';
import { createDefaultAoiZone, validateAoiZones } from './aoiZone.js';
import { resolveCanonicalMapId } from './mapAliases.js';
import type { GridPosition, MapLayerId, MapTemplateMeta, MonsterSpawn, WorldPortal, WorldRegion, WorldTemplate } from './types.js';

const DEFAULT_MAP_LAYER: MapLayerId = 'surface';
const DEFAULT_SERVER_VISIBLE_NAMESPACE = '';
const VALID_MAP_LAYERS = new Set<MapLayerId>(['surface', 'underground', 'rooftop', 'interior']);
const VALID_PORTAL_SHARD_SELECTORS = new Set<WorldPortal['toShardSelector']>(['same_account', 'least_loaded', 'fixed']);
const VALID_PORTAL_VISIBILITIES = new Set<WorldPortal['visibility']>(['always', 'objective_unlocked']);
const VALID_MONSTER_INITIAL_STATES = new Set<NonNullable<MonsterSpawn['initialState']>>(['patrol', 'idle', 'leashed']);

export class MapTemplateRegistry {
  constructor(private readonly storage: Storage) {}

  async list(): Promise<MapTemplateMeta[]> {
    const templates = await this.storage.worldTemplates.list();
    return templates
      .map((template) => this.metaFor(template))
      .sort((a, b) => a.mapId.localeCompare(b.mapId));
  }

  async load(mapId: string): Promise<WorldTemplate> {
    const template = this.normalizeTemplate(await this.storage.worldTemplates.load(this.canonicalMapId(mapId)));
    this.validateNormalized(template);
    return template;
  }

  validate(template: WorldTemplate): void {
    this.validateNormalized(this.normalizeTemplate(template));
  }

  hash(template: WorldTemplate): string {
    return template.meta?.templateHash ?? template.templateHash;
  }

  private canonicalMapId(mapId: string): string {
    return resolveCanonicalMapId(mapId);
  }

  private normalizeTemplate(template: WorldTemplate): WorldTemplate {
    const defaultAoiZoneId = this.normalizeAoiZoneId(template.defaultAoiZoneId ?? template.meta?.recommendedAoiZoneId);
    const normalized = clone(template) as WorldTemplate & {
      meta?: Partial<MapTemplateMeta>;
      regions?: unknown;
      portals?: unknown;
      aoiZones?: unknown;
      defaultAoiZoneId?: string;
      monsterSpawns?: unknown;
    };

    if (normalized.meta !== undefined && !isPlainObject(normalized.meta)) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_meta`);
    }

    normalized.meta = this.normalizeMeta(template, defaultAoiZoneId);
    normalized.defaultAoiZoneId = defaultAoiZoneId;
    normalized.regions = normalized.regions === undefined
      ? []
      : Array.isArray(normalized.regions)
        ? normalized.regions.map((region) => this.normalizeRegion(region))
        : normalized.regions;
    normalized.portals = normalized.portals === undefined
      ? []
      : Array.isArray(normalized.portals)
        ? normalized.portals.map((portal) => this.normalizePortal(portal))
        : normalized.portals;
    normalized.aoiZones = normalized.aoiZones === undefined || (Array.isArray(normalized.aoiZones) && normalized.aoiZones.length === 0)
      ? [createDefaultAoiZone(defaultAoiZoneId)]
      : normalized.aoiZones;
    normalized.monsterSpawns = normalized.monsterSpawns === undefined
      ? []
      : Array.isArray(normalized.monsterSpawns)
        ? normalized.monsterSpawns.map((spawn) => this.normalizeMonsterSpawn(spawn))
        : normalized.monsterSpawns;
    return normalized as WorldTemplate;
  }

  private validateNormalized(template: WorldTemplate): void {
    const hash = this.hash(template);
    if (hash !== template.templateHash) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:template_hash_mismatch`);
    }
    if (!template.mapId || !template.templateHash) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId || 'unknown'}:missing_identity`);
    }
    if (template.meta.mapId !== template.mapId) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:meta_map_id_mismatch`);
    }
    this.validateMeta(template);
    if (!Number.isInteger(template.width) || !Number.isInteger(template.height) || template.width <= 0 || template.height <= 0) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_bounds`);
    }
    this.validatePosition(template.mapId, template.spawn, 'spawn', template.width, template.height);
    for (const blocked of template.blocked) {
      this.validatePosition(template.mapId, blocked, 'blocked', template.width, template.height);
    }

    if (!Array.isArray(template.regions)) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_regions`);
    }
    if (!Array.isArray(template.portals)) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portals`);
    }
    if (!Array.isArray(template.aoiZones)) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_aoi_zones`);
    }
    if (!Array.isArray(template.monsterSpawns)) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_monster_spawns`);
    }

    validateAoiZones(template.mapId, template.aoiZones, template.defaultAoiZoneId);
    const aoiZoneIds = new Set(template.aoiZones.map((zone) => zone.zoneId));

    const regionIds = new Set<string>();
    for (const region of template.regions) {
      if (!region.regionId) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_region:missing_region_id`);
      }
      if (regionIds.has(region.regionId)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:duplicate_region:${region.regionId}`);
      }
      regionIds.add(region.regionId);
      if (!VALID_MAP_LAYERS.has(region.layer)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_region:${region.regionId}:layer`);
      }
      this.validateArea(template.mapId, region.bounds, `region:${region.regionId}`, template.width, template.height);
      if (region.aoiZoneId !== undefined && !aoiZoneIds.has(region.aoiZoneId)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:missing_aoi_zone:${region.regionId}:${region.aoiZoneId}`);
      }
    }

    const portalIds = new Set<string>();
    for (const portal of template.portals) {
      if (!portal.portalId) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:missing_portal_id`);
      }
      if (portalIds.has(portal.portalId)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:duplicate_portal:${portal.portalId}`);
      }
      portalIds.add(portal.portalId);
      if (portal.fromMapId !== template.mapId) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:${portal.portalId}:from_map`);
      }
      if (!portal.toMapId) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:${portal.portalId}:to_map`);
      }
      this.validatePosition(template.mapId, portal.fromPosition, `portal:${portal.portalId}:from_position`, template.width, template.height);
      this.validatePosition(template.mapId, portal.toPosition, `portal:${portal.portalId}:to_position`, template.width, template.height);
      if (!VALID_PORTAL_SHARD_SELECTORS.has(portal.toShardSelector)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:${portal.portalId}:shard_selector`);
      }
      if (!Number.isInteger(portal.cooldownMs) || portal.cooldownMs <= 0) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:${portal.portalId}:cooldown`);
      }
      if (!VALID_PORTAL_VISIBILITIES.has(portal.visibility)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:${portal.portalId}:visibility`);
      }
      if (portal.toShardSelector === 'fixed' && !portal.toShardId) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:${portal.portalId}:shard_id`);
      }
      if (portal.visibility === 'objective_unlocked' && !portal.unlockObjectiveId) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_portal:${portal.portalId}:unlock_objective`);
      }
    }

    const entityIds = new Set<string>();
    for (const entity of template.entities) {
      if (!entity.entityId || entityIds.has(entity.entityId)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:duplicate_entity:${entity.entityId}`);
      }
      entityIds.add(entity.entityId);
      this.validatePosition(template.mapId, entity.position, `entity:${entity.entityId}`, template.width, template.height);
    }

    const monsterSpawnIds = new Set<string>();
    const runtimeSubjectIds = new Set<string>();
    for (const spawn of template.monsterSpawns) {
      if (!isPlainObject(spawn)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_monster_spawn`);
      }
      if (!spawn.spawnId || monsterSpawnIds.has(spawn.spawnId)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:duplicate_monster_spawn:${spawn.spawnId}`);
      }
      monsterSpawnIds.add(spawn.spawnId);
      if (!spawn.monsterId) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_monster_spawn:${spawn.spawnId}:monster_id`);
      }
      if (typeof spawn.active !== 'boolean') {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_monster_spawn:${spawn.spawnId}:active`);
      }
      this.validatePosition(template.mapId, spawn.position, `monster_spawn:${spawn.spawnId}`, template.width, template.height);
      if (spawn.patrolAnchorOverride !== undefined) {
        this.validatePosition(template.mapId, spawn.patrolAnchorOverride, `monster_spawn:${spawn.spawnId}:patrol_anchor`, template.width, template.height);
      }
      if (spawn.initialState !== undefined && !VALID_MONSTER_INITIAL_STATES.has(spawn.initialState)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_monster_spawn:${spawn.spawnId}:initial_state`);
      }
      if (spawn.packMemberIndex !== undefined && (!Number.isInteger(spawn.packMemberIndex) || spawn.packMemberIndex < 0)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_monster_spawn:${spawn.spawnId}:pack_member_index`);
      }
      if (spawn.storyVisibleId !== undefined && (!spawn.storyVisibleId || typeof spawn.storyVisibleId !== 'string')) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_monster_spawn:${spawn.spawnId}:story_visible_id`);
      }
      const runtimeSubjectId = spawn.storyVisibleId ?? spawn.spawnId;
      if (entityIds.has(runtimeSubjectId) || runtimeSubjectIds.has(runtimeSubjectId)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:duplicate_world_subject:${runtimeSubjectId}`);
      }
      runtimeSubjectIds.add(runtimeSubjectId);
    }
  }

  private metaFor(template: WorldTemplate): MapTemplateMeta {
    return this.normalizeMeta(template, this.normalizeAoiZoneId(template.defaultAoiZoneId ?? template.meta?.recommendedAoiZoneId));
  }

  private normalizeMeta(template: WorldTemplate, defaultAoiZoneId: string): MapTemplateMeta {
    const source = template.meta;
    return {
      mapId: fallbackString(source?.mapId, template.mapId),
      templateHash: fallbackString(source?.templateHash, template.templateHash),
      displayName: fallbackString(source?.displayName, this.defaultDisplayName(template.mapId)),
      layers: Array.isArray(source?.layers) && source.layers.length > 0 ? [...source.layers] : [DEFAULT_MAP_LAYER],
      defaultLayer: this.normalizeMapLayer(source?.defaultLayer) as MapLayerId,
      recommendedAoiZoneId: fallbackString(source?.recommendedAoiZoneId, defaultAoiZoneId),
      contentRevision: Number.isInteger(source?.contentRevision) ? source.contentRevision : 1,
      serverVisibleIdNamespace: fallbackString(source?.serverVisibleIdNamespace, DEFAULT_SERVER_VISIBLE_NAMESPACE)
    };
  }

  private normalizeRegion(region: WorldRegion): WorldRegion {
    return {
      ...clone(region),
      layer: this.normalizeMapLayer(region.layer) as MapLayerId
    };
  }

  private normalizePortal(portal: WorldPortal): WorldPortal {
    return {
      ...clone(portal),
      visibility: portal.visibility ?? 'always'
    };
  }

  private normalizeMonsterSpawn(spawn: MonsterSpawn): MonsterSpawn {
    return clone(spawn);
  }

  private normalizeMapLayer(layer: string | undefined): string {
    return fallbackString(layer, DEFAULT_MAP_LAYER);
  }

  private normalizeAoiZoneId(zoneId: string | undefined): string {
    return fallbackString(zoneId, 'default');
  }

  private defaultDisplayName(mapId: string): string {
    return mapId
      .split('-')
      .filter((part) => part.length > 0)
      .map((part) => part[0].toUpperCase() + part.slice(1))
      .join(' ');
  }

  private validateMeta(template: WorldTemplate): void {
    if (!Array.isArray(template.meta.layers) || template.meta.layers.length === 0) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_meta:layers`);
    }
    const layers = new Set<string>();
    for (const layer of template.meta.layers) {
      if (!VALID_MAP_LAYERS.has(layer)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_meta:layer:${layer}`);
      }
      if (layers.has(layer)) {
        throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_meta:duplicate_layer:${layer}`);
      }
      layers.add(layer);
    }
    if (!VALID_MAP_LAYERS.has(template.meta.defaultLayer) || !layers.has(template.meta.defaultLayer)) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${template.mapId}:invalid_meta:default_layer`);
    }
  }

  private validateArea(mapId: string, bounds: { x: number; y: number; width: number; height: number }, role: string, width: number, height: number): void {
    if (
      !Number.isInteger(bounds.x) ||
      !Number.isInteger(bounds.y) ||
      !Number.isInteger(bounds.width) ||
      !Number.isInteger(bounds.height) ||
      bounds.width <= 0 ||
      bounds.height <= 0 ||
      bounds.x < 0 ||
      bounds.y < 0 ||
      bounds.x + bounds.width > width ||
      bounds.y + bounds.height > height
    ) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${mapId}:out_of_bounds:${role}`);
    }
  }

  private validatePosition(mapId: string, position: GridPosition, role: string, width: number, height: number): void {
    if (
      !Number.isInteger(position.x) ||
      !Number.isInteger(position.y) ||
      position.x < 0 ||
      position.y < 0 ||
      position.x >= width ||
      position.y >= height
    ) {
      throw new Error(`INVALID_WORLD_TEMPLATE:${mapId}:out_of_bounds:${role}`);
    }
  }
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function fallbackString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
