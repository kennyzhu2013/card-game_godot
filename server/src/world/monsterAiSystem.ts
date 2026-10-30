import { gridDistance } from './aoiSystem.js';
import { cloneMonsterRuntime, createMonsterRuntime, type MonsterRuntime, type MonsterRuntimeState } from './monsterRuntime.js';
import type { Direction, GridPosition, MonsterSpawn, MonsterTemplate, PlayerWorldState, WorldDelta } from './types.js';

export interface MonsterTemplateSource {
  loadSync(monsterId: string): MonsterTemplate;
}

export interface TransformationOracle {
  isSameSpecies(player: PlayerWorldState, template: MonsterTemplate): boolean;
}

export interface MonsterAiConfig {
  threatGainPerTick: number;
  leashRadiusCells: number;
  preludeLeadTimeMs: number;
  evadeWindowMs: number;
}

export interface MonsterAggroEvent {
  monsterId: string;
  fromState: MonsterRuntimeState;
  toState: MonsterRuntimeState;
  threat: number;
  towardsPlayerId: string;
  tick: number;
}

export interface MonsterCombatPrelude {
  monsterId: string;
  monsterEntityIds: string[];
  targetPlayerId: string;
  leadTimeMs: number;
  escapeWindowMs: number;
  tick: number;
}

export interface MonsterCombatLockRequest {
  center: GridPosition;
  hostileEntityIds: string[];
  targetPlayerId: string;
}

export interface MonsterTickResult {
  monsters: MonsterRuntime[];
  deltas: WorldDelta[];
  aggroEvents: MonsterAggroEvent[];
  preludes: MonsterCombatPrelude[];
  combatLockRequests: MonsterCombatLockRequest[];
}

export interface MonsterEvadeInput {
  evadeKind: 'sprint' | 'stealth' | 'transform';
  now: number;
}

export type MonsterEvadeAck =
  | { ok: true; code: 'EVADED'; reason: string }
  | { ok: false; code: 'NOT_ELIGIBLE' | 'PRELUDE_EXPIRED' | 'NO_PRELUDE'; reason: string };

export interface MonsterEvadeResult {
  monster: MonsterRuntime;
  ack: MonsterEvadeAck;
}

export class MonsterAiSystem {
  constructor(private readonly opts: {
    templates: MonsterTemplateSource;
    transformationOracle: TransformationOracle;
    config: MonsterAiConfig;
  }) {}

  spawn(spawn: MonsterSpawn, now: number): MonsterRuntime {
    return createMonsterRuntime(spawn, this.opts.templates.loadSync(spawn.monsterId), now);
  }

  tick(monsters: MonsterRuntime[], players: PlayerWorldState[], now: number): MonsterTickResult {
    const result: MonsterTickResult = {
      monsters: [],
      deltas: [],
      aggroEvents: [],
      preludes: [],
      combatLockRequests: []
    };

    for (const input of monsters) {
      const monster = cloneMonsterRuntime(input);
      const template = this.opts.templates.loadSync(monster.templateId);
      if (monster.state === 'DEAD' || monster.state === 'COMBAT_LOCKED') {
        monster.lastTickAt = now;
        result.monsters.push(monster);
        continue;
      }

      if (monster.state === 'PATROL') {
        this.advancePatrol(monster, template, now);
      }

      if (monster.state === 'CHASE') {
        this.tickChase(monster, template, players, now, result);
      } else {
        this.tickSense(monster, template, players, now, result);
      }

      monster.lastTickAt = now;
      result.monsters.push(monster);
    }

    return result;
  }

  attemptEvade(monsterInput: MonsterRuntime, player: PlayerWorldState, input: MonsterEvadeInput): MonsterEvadeResult {
    const monster = cloneMonsterRuntime(monsterInput);
    const prelude = monster.pendingPrelude;
    if (!prelude || prelude.targetPlayerId !== player.playerId) {
      return { monster, ack: { ok: false, code: 'NO_PRELUDE', reason: 'no active prelude for player' } };
    }
    if (input.now > prelude.expiresAt) {
      return { monster, ack: { ok: false, code: 'PRELUDE_EXPIRED', reason: 'prelude window expired' } };
    }
    if (isFacing(player.facing, player.position, monster.position)) {
      return { monster, ack: { ok: false, code: 'NOT_ELIGIBLE', reason: 'player is facing the monster' } };
    }

    monster.state = 'PATROL';
    monster.position = { ...monster.patrolAnchor };
    monster.threat.set(player.playerId, 0);
    monster.pendingPrelude = null;
    monster.lastTransitionAt = input.now;
    return { monster, ack: { ok: true, code: 'EVADED', reason: `${input.evadeKind} evade accepted` } };
  }

  private tickSense(
    monster: MonsterRuntime,
    template: MonsterTemplate,
    players: PlayerWorldState[],
    now: number,
    result: MonsterTickResult
  ): void {
    let topPlayer: PlayerWorldState | null = null;
    let topThreat = 0;

    for (const player of players) {
      const current = monster.threat.get(player.playerId) ?? 0;
      if (gridDistance(monster.position, player.position) > template.sense.radiusCells) {
        const decayed = Math.max(0, current - template.aggro.decayPerSec);
        monster.threat.set(player.playerId, decayed);
        continue;
      }
      if (template.aggro.transformedPlayerImmunity && this.opts.transformationOracle.isSameSpecies(player, template)) {
        monster.threat.set(player.playerId, Math.max(0, current - this.opts.config.threatGainPerTick));
        continue;
      }

      const nextThreat = Math.min(template.aggro.maxThreat, current + this.opts.config.threatGainPerTick);
      monster.threat.set(player.playerId, nextThreat);
      if (nextThreat > topThreat) {
        topThreat = nextThreat;
        topPlayer = player;
      }
    }

    if (!topPlayer) {
      return;
    }

    const nextState = topThreat >= template.aggro.huntThreshold
      ? 'CHASE'
      : topThreat >= template.aggro.alertThreshold
        ? 'ALERT'
        : monster.state;
    this.transition(monster, nextState, topThreat, topPlayer.playerId, now, result);
  }

  private tickChase(
    monster: MonsterRuntime,
    template: MonsterTemplate,
    players: PlayerWorldState[],
    now: number,
    result: MonsterTickResult
  ): void {
    const target = this.highestThreatPlayer(monster, players);
    if (!target) {
      return;
    }

    if (gridDistance(monster.position, monster.patrolAnchor) > this.opts.config.leashRadiusCells) {
      monster.position = { ...monster.patrolAnchor };
      monster.threat.set(target.playerId, 0);
      monster.pendingPrelude = null;
      this.transition(monster, 'PATROL', 0, target.playerId, now, result);
      return;
    }

    if (gridDistance(monster.position, target.position) <= template.encounter.combatLockRadiusCells) {
      const hostileEntityIds = [monster.entityId, ...monster.packMembers];
      monster.pendingPrelude = {
        targetPlayerId: target.playerId,
        startedAt: now,
        expiresAt: now + this.opts.config.evadeWindowMs,
        monsterEntityIds: hostileEntityIds
      };
      result.preludes.push({
        monsterId: monster.entityId,
        monsterEntityIds: hostileEntityIds,
        targetPlayerId: target.playerId,
        leadTimeMs: this.opts.config.preludeLeadTimeMs,
        escapeWindowMs: this.opts.config.evadeWindowMs,
        tick: now
      });
      result.combatLockRequests.push({
        center: { ...monster.position },
        hostileEntityIds,
        targetPlayerId: target.playerId
      });
    }
  }

  private transition(
    monster: MonsterRuntime,
    nextState: MonsterRuntimeState,
    threat: number,
    playerId: string,
    now: number,
    result: MonsterTickResult
  ): void {
    if (monster.state === nextState) {
      return;
    }
    const fromState = monster.state;
    monster.state = nextState;
    monster.lastTransitionAt = now;
    result.aggroEvents.push({
      monsterId: monster.entityId,
      fromState,
      toState: nextState,
      threat,
      towardsPlayerId: playerId,
      tick: now
    });
  }

  private advancePatrol(monster: MonsterRuntime, template: MonsterTemplate, now: number): void {
    if (template.patrol.type === 'stationary') {
      return;
    }
    const elapsedMs = Math.max(now - monster.lastTickAt, 0);
    const steps = Math.floor((elapsedMs / 1000) * template.patrol.speedCellsPerSec);
    for (let step = 0; step < steps; step += 1) {
      const patrolPoints = resolvePatrolPoints(monster.patrolAnchor, template);
      if (patrolPoints.length === 0) {
        return;
      }
      const target = patrolPoints[monster.patrolTargetIndex % patrolPoints.length];
      if (samePosition(monster.position, target)) {
        monster.patrolTargetIndex = (monster.patrolTargetIndex + 1) % patrolPoints.length;
      }
      const nextTarget = patrolPoints[monster.patrolTargetIndex % patrolPoints.length];
      const nextPosition = stepTowards(monster.position, nextTarget);
      monster.facing = facingFromStep(monster.position, nextPosition, monster.facing);
      monster.position = nextPosition;
      if (samePosition(monster.position, nextTarget)) {
        monster.patrolTargetIndex = (monster.patrolTargetIndex + 1) % patrolPoints.length;
      }
    }
  }

  private highestThreatPlayer(monster: MonsterRuntime, players: PlayerWorldState[]): PlayerWorldState | null {
    let best: PlayerWorldState | null = null;
    let bestThreat = 0;
    for (const player of players) {
      const threat = monster.threat.get(player.playerId) ?? 0;
      if (threat > bestThreat) {
        best = player;
        bestThreat = threat;
      }
    }
    return best;
  }
}

function resolvePatrolPoints(anchor: GridPosition, template: MonsterTemplate): GridPosition[] {
  if (template.patrol.type === 'route' && template.patrol.route && template.patrol.route.length > 0) {
    return template.patrol.route.map((point) => ({ ...point }));
  }
  const radius = template.patrol.radiusCells;
  if (radius <= 0) {
    return [];
  }
  return [
    { x: anchor.x + radius, y: anchor.y },
    { x: anchor.x, y: anchor.y + radius },
    { x: Math.max(0, anchor.x - radius), y: anchor.y },
    { x: anchor.x, y: Math.max(0, anchor.y - radius) }
  ];
}

function stepTowards(from: GridPosition, to: GridPosition): GridPosition {
  if (from.x < to.x) {
    return { x: from.x + 1, y: from.y };
  }
  if (from.x > to.x) {
    return { x: from.x - 1, y: from.y };
  }
  if (from.y < to.y) {
    return { x: from.x, y: from.y + 1 };
  }
  if (from.y > to.y) {
    return { x: from.x, y: from.y - 1 };
  }
  return { ...from };
}

function facingFromStep(from: GridPosition, to: GridPosition, fallback: Direction): Direction {
  if (to.x > from.x) {
    return 'east';
  }
  if (to.x < from.x) {
    return 'west';
  }
  if (to.y > from.y) {
    return 'south';
  }
  if (to.y < from.y) {
    return 'north';
  }
  return fallback;
}

function isFacing(facing: Direction, from: GridPosition, to: GridPosition): boolean {
  return directionTo(from, to) === facing;
}

function directionTo(from: GridPosition, to: GridPosition): Direction {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  if (Math.abs(dx) >= Math.abs(dy)) {
    return dx >= 0 ? 'east' : 'west';
  }
  return dy >= 0 ? 'south' : 'north';
}

function samePosition(a: GridPosition, b: GridPosition): boolean {
  return a.x === b.x && a.y === b.y;
}
