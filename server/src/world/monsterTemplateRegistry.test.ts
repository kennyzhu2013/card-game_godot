import { describe, expect, it } from 'vitest';
import fogOozeTemplate from '../data/monsters/fog_ooze.json';
import { MonsterTemplateRegistry } from './monsterTemplateRegistry.js';
import type { MonsterTemplate } from './types.js';

describe('MonsterTemplateRegistry', () => {
  it('loads the canonical fog_ooze template and exposes a stable file hash', async () => {
    const registry = new MonsterTemplateRegistry();

    const ids = (await registry.list()).map((template) => template.monsterId);
    expect(ids).toEqual(expect.arrayContaining([
      'fog_ooze',
      'drowned_bone_sailor',
      'coal_fire_lizard',
      'shadow_hound',
      'moth_lamp_cultist'
    ]));

    const template = await registry.load('fog_ooze');

    expect(template.monsterId).toBe('fog_ooze');
    expect(template.displayName).toBe('雾髓黏液体');
    expect(template.stats).toMatchObject({
      maxHp: 70,
      atk: 14,
      def: 5,
      spd: 8,
      shieldPoints: 2
    });
    expect(template.sense).toMatchObject({
      radiusCells: 4,
      visionConeDeg: 240,
      alertCooldownMs: 1500
    });
    expect(template.aggro.transformedPlayerImmunity).toBe(true);
    expect(template.patrol).toMatchObject({
      type: 'circular',
      radiusCells: 3,
      speedCellsPerSec: 0.5
    });
    expect(template.encounter).toMatchObject({
      combatLockRadiusCells: 2,
      preferredCombatLockMode: 'instant'
    });
    expect(registry.hash(template)).toBe(fogOozeTemplate.templateHash);
    expect(() => registry.validate(template)).not.toThrow();
  });

  it('rejects malformed monster templates with INVALID_MONSTER_TEMPLATE', () => {
    const registry = new MonsterTemplateRegistry([]);
    const invalid = {
      ...fogOozeTemplate,
      monsterId: 'broken_ooze',
      sense: {
        ...fogOozeTemplate.sense,
        radiusCells: undefined
      }
    } as unknown as MonsterTemplate;

    expect(() => registry.validate(invalid)).toThrow('INVALID_MONSTER_TEMPLATE:broken_ooze:sense_radius');
  });
});
