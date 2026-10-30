import { gridDistance } from './aoiSystem.js';
import { cloneMonsterRuntime, type MonsterRuntime } from './monsterRuntime.js';
import type { MonsterPackTemplate, MonsterTemplate } from './types.js';

export interface MonsterPackTemplateSource {
  loadSync(monsterId: string): MonsterTemplate;
}

export interface MonsterPackRegistryOptions {
  templates: MonsterPackTemplateSource;
}

interface RegisteredMonster {
  monster: MonsterRuntime;
  pack: MonsterPackTemplate;
}

export class MonsterPackRegistry {
  private readonly members = new Map<string, RegisteredMonster>();

  constructor(private readonly options: MonsterPackRegistryOptions) {}

  register(monster: MonsterRuntime): void {
    const template = this.options.templates.loadSync(monster.templateId);
    this.members.set(monster.entityId, {
      monster: cloneMonsterRuntime(monster),
      pack: { ...template.pack }
    });
  }

  registerMany(monsters: MonsterRuntime[]): void {
    for (const monster of monsters) {
      this.register(monster);
    }
  }

  unregister(entityId: string): void {
    this.members.delete(entityId);
  }

  list(): MonsterRuntime[] {
    return this.sortedMembers().map((member) => cloneMonsterRuntime(member.monster));
  }

  callAllies(triggerEntityId: string, now: number): MonsterRuntime[] {
    const trigger = this.members.get(triggerEntityId);
    if (!trigger || (trigger.monster.state !== 'ALERT' && trigger.monster.state !== 'CHASE')) {
      return this.list();
    }

    for (const candidate of this.members.values()) {
      if (candidate.monster.entityId === trigger.monster.entityId) {
        continue;
      }
      if (candidate.pack.packId !== trigger.pack.packId || candidate.pack.role !== 'guard') {
        continue;
      }
      if (gridDistance(candidate.monster.position, trigger.monster.position) > trigger.pack.callAlliesRadiusCells) {
        continue;
      }
      if (candidate.monster.state === 'PATROL' || candidate.monster.state === 'IDLE') {
        candidate.monster.state = 'ALERT';
        candidate.monster.lastTransitionAt = now;
      }
    }

    return this.list();
  }

  enforceMaxConcurrent(packId: string, now: number): MonsterRuntime[] {
    const packMembers = this.sortedMembers().filter((member) => member.pack.packId === packId);
    if (packMembers.length === 0) {
      return this.list();
    }

    const maxConcurrent = Math.min(...packMembers.map((member) => member.pack.maxConcurrentMembers));
    const chasing = packMembers
      .filter((member) => member.monster.state === 'CHASE')
      .sort((a, b) => a.monster.lastTransitionAt - b.monster.lastTransitionAt || a.monster.entityId.localeCompare(b.monster.entityId));

    for (const overflow of chasing.slice(maxConcurrent)) {
      overflow.monster.state = 'PATROL';
      overflow.monster.pendingPrelude = null;
      overflow.monster.combatLockId = null;
      overflow.monster.lastTransitionAt = now;
    }

    return this.list();
  }

  private sortedMembers(): RegisteredMonster[] {
    return [...this.members.values()].sort((a, b) => a.monster.entityId.localeCompare(b.monster.entityId));
  }
}
