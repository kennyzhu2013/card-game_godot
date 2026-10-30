import fogOozeTemplate from '../data/monsters/fog_ooze.json';
import drownedBoneSailorTemplate from '../data/monsters/drowned_bone_sailor.json';
import coalFireLizardTemplate from '../data/monsters/coal_fire_lizard.json';
import shadowHoundTemplate from '../data/monsters/shadow_hound.json';
import mothLampCultistTemplate from '../data/monsters/moth_lamp_cultist.json';
import fogTouchedThreatTemplate from '../data/monsters/fog_touched_threat.json';
import type { GridPosition, MonsterPackTemplate, MonsterTemplate } from './types.js';

const DEFAULT_MONSTER_TEMPLATES = [
  fogOozeTemplate,
  drownedBoneSailorTemplate,
  coalFireLizardTemplate,
  shadowHoundTemplate,
  mothLampCultistTemplate,
  fogTouchedThreatTemplate
] as MonsterTemplate[];

const VALID_AGGRO_INITIAL = new Set<MonsterTemplate['aggro']['initial']>(['passive', 'neutral', 'hostile']);
const VALID_PATROL_TYPES = new Set<MonsterTemplate['patrol']['type']>(['circular', 'route', 'stationary']);
const VALID_PACK_ROLES = new Set<MonsterPackTemplate['role']>(['scout', 'guard', 'brute', 'caster']);
const VALID_COMBAT_LOCK_MODES = new Set<MonsterTemplate['encounter']['preferredCombatLockMode']>(['instant', 'prelude']);
const VALID_SKILL_TYPES = new Set(['attack', 'buff', 'heal', 'control', 'support']);

export class MonsterTemplateRegistry {
  private readonly templates = new Map<string, MonsterTemplate>();

  constructor(templates: MonsterTemplate[] = DEFAULT_MONSTER_TEMPLATES) {
    for (const template of templates) {
      this.validate(template);
      if (this.templates.has(template.monsterId)) {
        throw new Error(`INVALID_MONSTER_TEMPLATE:${template.monsterId}:duplicate_monster_id`);
      }
      this.templates.set(template.monsterId, clone(template));
    }
  }

  async list(): Promise<MonsterTemplate[]> {
    return [...this.templates.values()]
      .sort((a, b) => a.monsterId.localeCompare(b.monsterId))
      .map((template) => clone(template));
  }

  async load(monsterId: string): Promise<MonsterTemplate> {
    return this.loadSync(monsterId);
  }

  loadSync(monsterId: string): MonsterTemplate {
    const template = this.templates.get(monsterId);
    if (!template) {
      throw new Error(`UNKNOWN_MONSTER_TEMPLATE:${monsterId}`);
    }
    return clone(template);
  }

  hash(template: MonsterTemplate): string {
    return template.templateHash;
  }

  validate(template: MonsterTemplate): void {
    const id = stringValue(template?.monsterId) || 'unknown';
    if (!stringValue(template?.monsterId)) {
      throw invalid(id, 'monster_id');
    }
    if (!stringValue(template.templateHash)) {
      throw invalid(id, 'template_hash');
    }
    if (!stringValue(template.displayName)) {
      throw invalid(id, 'display_name');
    }
    if (!stringValue(template.speciesId)) {
      throw invalid(id, 'species_id');
    }
    if (!stringValue(template.spriteSheet)) {
      throw invalid(id, 'sprite_sheet');
    }
    this.validateStats(id, template.stats);
    this.validateSense(id, template.sense);
    this.validateAggro(id, template.aggro);
    this.validatePatrol(id, template.patrol);
    this.validateRespawn(id, template.respawn);
    this.validatePack(id, template.pack);
    this.validateLoot(id, template.loot);
    this.validateEncounter(id, template.encounter);
  }

  private validateStats(id: string, stats: MonsterTemplate['stats']): void {
    if (!isPositiveNumber(stats?.maxHp)) {
      throw invalid(id, 'stats_max_hp');
    }
    if (!isNonNegativeNumber(stats.atk)) {
      throw invalid(id, 'stats_atk');
    }
    if (!isNonNegativeNumber(stats.def)) {
      throw invalid(id, 'stats_def');
    }
    if (!isPositiveNumber(stats.spd)) {
      throw invalid(id, 'stats_spd');
    }
    if (!isNonNegativeNumber(stats.shieldPoints)) {
      throw invalid(id, 'stats_shield_points');
    }
    if (!Array.isArray(stats.weaknesses) || stats.weaknesses.some((weakness) => !stringValue(weakness))) {
      throw invalid(id, 'stats_weaknesses');
    }
    if (!Array.isArray(stats.skills) || stats.skills.length === 0) {
      throw invalid(id, 'stats_skills');
    }
    const skillIds = new Set<string>();
    for (const skill of stats.skills) {
      if (!stringValue(skill.id) || skillIds.has(skill.id)) {
        throw invalid(id, 'skill_id');
      }
      skillIds.add(skill.id);
      if (!stringValue(skill.name) || !VALID_SKILL_TYPES.has(skill.type) || !isNonNegativeNumber(skill.power) || !isNonNegativeNumber(skill.costAp)) {
        throw invalid(id, `skill:${skill.id}`);
      }
    }
  }

  private validateSense(id: string, sense: MonsterTemplate['sense']): void {
    if (!isPositiveInteger(sense?.radiusCells)) {
      throw invalid(id, 'sense_radius');
    }
    if (!isPositiveNumber(sense.visionConeDeg) || sense.visionConeDeg > 360) {
      throw invalid(id, 'sense_vision_cone');
    }
    if (!Array.isArray(sense.blockingTileTags) || sense.blockingTileTags.some((tag) => !stringValue(tag))) {
      throw invalid(id, 'sense_blocking_tile_tags');
    }
    if (!isNonNegativeNumber(sense.alertCooldownMs)) {
      throw invalid(id, 'sense_alert_cooldown');
    }
  }

  private validateAggro(id: string, aggro: MonsterTemplate['aggro']): void {
    if (!VALID_AGGRO_INITIAL.has(aggro?.initial)) {
      throw invalid(id, 'aggro_initial');
    }
    if (!isNonNegativeNumber(aggro.decayPerSec) || !isPositiveNumber(aggro.maxThreat)) {
      throw invalid(id, 'aggro_thresholds');
    }
    if (!isNonNegativeNumber(aggro.alertThreshold) || !isNonNegativeNumber(aggro.huntThreshold) || aggro.alertThreshold > aggro.huntThreshold || aggro.huntThreshold > aggro.maxThreat) {
      throw invalid(id, 'aggro_thresholds');
    }
    if (!isNonNegativeNumber(aggro.huntPlayerSpeciesPenalty) || typeof aggro.transformedPlayerImmunity !== 'boolean') {
      throw invalid(id, 'aggro_transform');
    }
  }

  private validatePatrol(id: string, patrol: MonsterTemplate['patrol']): void {
    if (!VALID_PATROL_TYPES.has(patrol?.type)) {
      throw invalid(id, 'patrol_type');
    }
    if (!isNonNegativeInteger(patrol.radiusCells) || !isPositiveNumber(patrol.speedCellsPerSec)) {
      throw invalid(id, 'patrol_motion');
    }
    if (!Array.isArray(patrol.idleMsRange) || patrol.idleMsRange.length !== 2 || !isNonNegativeNumber(patrol.idleMsRange[0]) || !isNonNegativeNumber(patrol.idleMsRange[1]) || patrol.idleMsRange[0] > patrol.idleMsRange[1]) {
      throw invalid(id, 'patrol_idle_range');
    }
    if (patrol.anchorOverride !== null && patrol.anchorOverride !== undefined && !isGridPosition(patrol.anchorOverride)) {
      throw invalid(id, 'patrol_anchor');
    }
    if (patrol.route !== undefined && (!Array.isArray(patrol.route) || patrol.route.some((point) => !isGridPosition(point)))) {
      throw invalid(id, 'patrol_route');
    }
  }

  private validateRespawn(id: string, respawn: MonsterTemplate['respawn']): void {
    if (!isNonNegativeNumber(respawn?.timerMs) || !isNonNegativeInteger(respawn.scatterRadiusCells) || typeof respawn.weeklyOnlyOnReset !== 'boolean') {
      throw invalid(id, 'respawn');
    }
  }

  private validatePack(id: string, pack: MonsterTemplate['pack']): void {
    if (!stringValue(pack?.packId) || !VALID_PACK_ROLES.has(pack.role)) {
      throw invalid(id, 'pack');
    }
    if (!isNonNegativeInteger(pack.callAlliesRadiusCells) || !isPositiveInteger(pack.maxConcurrentMembers)) {
      throw invalid(id, 'pack_limits');
    }
  }

  private validateLoot(id: string, loot: MonsterTemplate['loot']): void {
    if (!stringValue(loot?.table) || !isPositiveInteger(loot.rolls)) {
      throw invalid(id, 'loot');
    }
  }

  private validateEncounter(id: string, encounter: MonsterTemplate['encounter']): void {
    if (!isPositiveInteger(encounter?.combatLockRadiusCells) || !VALID_COMBAT_LOCK_MODES.has(encounter.preferredCombatLockMode)) {
      throw invalid(id, 'encounter');
    }
    if (!Array.isArray(encounter.victoryDeltas) || !Array.isArray(encounter.defeatDeltas)) {
      throw invalid(id, 'encounter_deltas');
    }
  }
}

function invalid(monsterId: string, reason: string): Error {
  return new Error(`INVALID_MONSTER_TEMPLATE:${monsterId}:${reason}`);
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function isPositiveNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value > 0;
}

function isNonNegativeNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0;
}

function isPositiveInteger(value: unknown): value is number {
  return Number.isInteger(value) && (value as number) > 0;
}

function isNonNegativeInteger(value: unknown): value is number {
  return Number.isInteger(value) && (value as number) >= 0;
}

function isGridPosition(value: unknown): value is GridPosition {
  const position = value as GridPosition;
  return isNonNegativeInteger(position?.x) && isNonNegativeInteger(position.y);
}
