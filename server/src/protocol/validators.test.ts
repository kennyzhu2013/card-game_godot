import { describe, expect, it } from 'vitest';
import * as validatorExports from './validators.js';
import {
  ProgressionErrorCodes,
  WRITE_OPS_REQUIRING_CLIENT_TOKEN,
  validateAuthLoginPayload,
  validateChatPartyPayload,
  validateChatSayPayload,
  validateChatWhisperPayload,
  validateCombatActionPayload,
  validateForgeCancelPayload,
  validateForgeRequestPayload,
  validateMonsterAggroChangedPayload,
  validateMonsterCombatPreludePayload,
  validateMonsterEvadeAckPayload,
  validateMonsterEvadePayload,
  validateProtocolVersion,
  validateQuestAbandonPayload,
  validateQuestAcceptPayload,
  validateQuestListPayload,
  validateQuestTurnInPayload,
  validatePathwayAdvanceRequestPayload,
  validatePathwayConsumePotionPayload,
  validatePathwayListPayload,
  validateTransformationEndPayload,
  validateTransformationFeedPayload,
  validateTransformationStartPayload,
  validateSkillEquipLoadoutPayload,
  validateSkillLearnPayload,
  validateShopBuyPayload,
  validateShopListPayload,
  validateShopSellPayload,
  validateProgressionAcknowledgeMilestonePayload,
  validateProgressionAoiVisibleChangedPayload,
  validateProgressionAoiVisibleLeftPayload,
  validateProgressionMilestonePayload,
  validateProgressionSelfPatchPayload,
  validateProgressionSelfStatePayload,
  validateProgressionSubscribePayload,
  validateRitualCancelPayload,
  validateRitualFeedPayload,
  validateRitualStartPayload,
  validateSystemPingPayload,
  validateWriteEnvelopeHeaders,
  validateWorldListMapsPayload,
  validateWorldListShardsPayload,
  validateWorldTransferPayload,
  validateWorldEnterPayload,
  validateWorldCastSkillPayload,
  validateWorldInteractPayload,
  validateWorldMovePayload
} from './validators.js';

describe('protocol validators', () => {
  it('exposes the D7 progression protocol error code set', () => {
    expect(Object.values(ProgressionErrorCodes)).toEqual(expect.arrayContaining([
      'PROGRESSION_NOT_IN_WORLD',
      'PROGRESSION_VERSION_MISMATCH',
      'PROGRESSION_RATE_LIMITED',
      'PROGRESSION_MILESTONE_DUPLICATE',
      'PROGRESSION_PATCH_REJECTED'
    ]));
  });

  it('accepts valid M3 gateway and world payloads', () => {
    expect(validateAuthLoginPayload({ token: 'dev:one' }).ok).toBe(true);
    expect(validateWorldListShardsPayload({}).ok).toBe(true);
    expect(validateWorldListMapsPayload({}).ok).toBe(true);
    expect(validateWorldEnterPayload({ shardId: 'm3-dev' }).ok).toBe(true);
    expect(validateWorldMovePayload({
      playerId: 'player-one',
      seq: 2,
      from: { x: 1, y: 1 },
      to: { x: 2, y: 1 },
      startedAt: 1000
    }).ok).toBe(true);
    expect(validateWorldInteractPayload({ entityId: 'tree-1', action: 'chop' }).ok).toBe(true);
    expect(validateWorldInteractPayload({ entityId: 'hostile-1', action: 'scout' }).ok).toBe(true);
    expect(validateWorldInteractPayload({ entityId: 'hostile-1', action: 'combat_check' }).ok).toBe(true);
    expect(validateWorldCastSkillPayload({
      abilityId: 'tide_priestess__seq9__heal_basic',
      pathwayId: 'tide_priestess',
      sequence: 9,
      targetType: 'ally',
      targetEntityId: 'ally-1',
      clientPredictedSpawnedAt: 1000
    }).ok).toBe(true);
    expect(validateWorldCastSkillPayload({
      abilityId: 'tide_priestess__seq9__detect_basic',
      pathwayId: 'tide_priestess',
      sequence: 9,
      targetType: 'none',
      clientPredictedSpawnedAt: 1000
    }).ok).toBe(true);
    expect(validateCombatActionPayload({ combatLockId: 'lock-1', action: 'basic_attack', targetId: 'hostile-1' }).ok).toBe(true);
    expect(validateMonsterEvadePayload({ shardId: 'm3-dev', monsterId: 'wolf-1', evadeKind: 'stealth' }).ok).toBe(true);
    expect(validateProgressionSubscribePayload({ shardId: 'm3-dev' }).ok).toBe(true);
    expect(validateProgressionAcknowledgeMilestonePayload({ milestoneId: 'player-one:level_up:10' }).ok).toBe(true);
    expect(validateWorldTransferPayload({
      playerId: 'player-one',
      fromShardId: 'm3-dev',
      toShardId: 'm3-event',
      toPosition: { x: 4, y: 6 },
      portalId: 'mist-port'
    }).ok).toBe(true);
  });

  it('rejects malformed M3 payloads before routing mutates state', () => {
    expect(validateAuthLoginPayload({ token: '' }).ok).toBe(false);
    expect(validateWorldEnterPayload({ shardId: '' }).ok).toBe(false);
    expect(validateWorldMovePayload({
      playerId: 'player-one',
      seq: 1,
      from: { x: 1, y: '1' },
      to: { x: 2, y: 1 },
      startedAt: 1000
    }).ok).toBe(false);
    expect(validateWorldInteractPayload({ entityId: 'tree-1', action: 'delete' }).ok).toBe(false);
    expect(validateWorldCastSkillPayload({
      abilityId: 'tide_priestess__seq9__heal_basic',
      pathwayId: 'tide_priestess',
      sequence: 9,
      targetType: 'ally',
      clientPredictedSpawnedAt: 1000
    })).toMatchObject({ ok: false, code: 'INVALID_WORLD_CAST_SKILL' });
    expect(validateWorldCastSkillPayload({
      abilityId: 'tide_priestess__seq9__blink_basic',
      pathwayId: 'tide_priestess',
      sequence: 9,
      targetType: 'ground_point',
      targetGroundPosition: { x: '3', y: 4 },
      clientPredictedSpawnedAt: 1000
    })).toMatchObject({ ok: false, code: 'INVALID_WORLD_CAST_SKILL' });
    expect(validateCombatActionPayload({ combatLockId: 'lock-1', action: '' }).ok).toBe(false);
    expect(validateMonsterEvadePayload({ shardId: 'm3-dev', monsterId: '', evadeKind: 'stealth' })).toMatchObject({
      ok: false,
      code: 'INVALID_MONSTER_EVADE'
    });
    expect(validateMonsterEvadePayload({ shardId: 'm3-dev', monsterId: 'wolf-1', evadeKind: 'teleport' })).toMatchObject({
      ok: false,
      code: 'INVALID_MONSTER_EVADE'
    });
    expect(validateProgressionSubscribePayload({ shardId: '' })).toMatchObject({ ok: false, code: 'INVALID_PROGRESSION_SUBSCRIBE' });
    expect(validateProgressionAcknowledgeMilestonePayload({ milestoneId: ' ' })).toMatchObject({
      ok: false,
      code: 'INVALID_PROGRESSION_ACKNOWLEDGE_MILESTONE'
    });
    expect(validateWorldListShardsPayload({ unexpected: true })).toMatchObject({
      ok: false,
      code: 'INVALID_WORLD_LIST_SHARDS'
    });
    expect(validateWorldListMapsPayload({ unexpected: true })).toMatchObject({
      ok: false,
      code: 'INVALID_WORLD_LIST_MAPS'
    });
    expect(validateWorldTransferPayload({
      playerId: 'player-one',
      fromShardId: 'm3-dev',
      toShardId: '',
      toPosition: { x: 4, y: 6 }
    })).toMatchObject({
      ok: false,
      code: 'INVALID_WORLD_TRANSFER'
    });
  });

  it('accepts protocol version zero and one while rejecting future major versions', () => {
    expect(validateProtocolVersion(undefined).ok).toBe(true);
    expect(validateProtocolVersion(0).ok).toBe(true);
    expect(validateProtocolVersion(1).ok).toBe(true);
    expect(validateProtocolVersion(2)).toMatchObject({ ok: false, code: 'PROTOCOL_VERSION_MISMATCH' });
  });

  it('requires clientToken for write envelopes while preserving read op compatibility', () => {
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('world.interact')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('world.cast_skill')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('world.transfer')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('progression.acknowledge_milestone')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('combat.action')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('chat.say')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('monster.evade')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('inventory.discard')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('equipment.equip')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('equipment.unequip')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('forge.request')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('forge.cancel')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('ritual.start')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('ritual.feed')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('ritual.cancel')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('quest.accept')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('quest.turn_in')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('quest.abandon')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('transformation.start')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('transformation.feed')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('transformation.end')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('pathway.advance_request')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('pathway.consume_potion')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('skill.learn')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('skill.equip_loadout')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('build.place_request')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('build.cancel')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('build.dismantle')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('shop.buy')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('shop.sell')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('chat.whisper')).toBe(true);
    expect(WRITE_OPS_REQUIRING_CLIENT_TOKEN.has('chat.party')).toBe(true);
    expect(validateWriteEnvelopeHeaders('world.enter', { id: 1, op: 'world.enter', payload: {}, ts: 1 }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('world.interact', {
      id: 2,
      op: 'world.interact',
      payload: {},
      ts: 2,
      protocolVersion: 1,
      clientToken: 'token-world-interact',
      shardId: 'm3-dev'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('world.interact', {
      id: 3,
      op: 'world.interact',
      payload: {},
      ts: 3,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_WORLD_INTERACT' });
    expect(validateWriteEnvelopeHeaders('world.interact', {
      id: 4,
      op: 'world.interact',
      payload: {},
      ts: 4,
      protocolVersion: 0
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('world.cast_skill', {
      id: 5,
      op: 'world.cast_skill',
      payload: {},
      ts: 5,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_WORLD_CAST_SKILL' });
    expect(validateWriteEnvelopeHeaders('world.list_shards', {
      id: 6,
      op: 'world.list_shards',
      payload: {},
      ts: 6,
      protocolVersion: 1
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('world.transfer', {
      id: 7,
      op: 'world.transfer',
      payload: {},
      ts: 7,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_WORLD_TRANSFER' });
    expect(validateWriteEnvelopeHeaders('world.transfer', {
      id: 8,
      op: 'world.transfer',
      payload: {},
      ts: 8,
      protocolVersion: 1,
      clientToken: 'transfer-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('monster.evade', {
      id: 9,
      op: 'monster.evade',
      payload: {},
      ts: 9,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_MONSTER_EVADE' });
    expect(validateWriteEnvelopeHeaders('monster.evade', {
      id: 10,
      op: 'monster.evade',
      payload: {},
      ts: 10,
      protocolVersion: 1,
      clientToken: 'monster-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('monster.evade', {
      id: 11,
      op: 'monster.evade',
      payload: {},
      ts: 11,
      protocolVersion: 0
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('progression.subscribe', {
      id: 12,
      op: 'progression.subscribe',
      payload: {},
      ts: 12,
      protocolVersion: 1
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('progression.acknowledge_milestone', {
      id: 13,
      op: 'progression.acknowledge_milestone',
      payload: {},
      ts: 13,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_PROGRESSION_ACKNOWLEDGE_MILESTONE' });
    expect(validateWriteEnvelopeHeaders('progression.acknowledge_milestone', {
      id: 14,
      op: 'progression.acknowledge_milestone',
      payload: {},
      ts: 14,
      protocolVersion: 1,
      clientToken: 'token-milestone-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('progression.subscribe', {
      id: 15,
      op: 'progression.subscribe',
      payload: {},
      ts: 15,
      protocolVersion: 0
    })).toMatchObject({ ok: false, code: 'PROGRESSION_VERSION_MISMATCH' });
    expect(validateWriteEnvelopeHeaders('inventory.fetch', {
      id: 16,
      op: 'inventory.fetch',
      payload: {},
      ts: 16,
      protocolVersion: 1
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('inventory.discard', {
      id: 17,
      op: 'inventory.discard',
      payload: {},
      ts: 17,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_INVENTORY_DISCARD' });
    expect(validateWriteEnvelopeHeaders('equipment.equip', {
      id: 18,
      op: 'equipment.equip',
      payload: {},
      ts: 18,
      protocolVersion: 1,
      clientToken: 'equip-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('forge.request', {
      id: 19,
      op: 'forge.request',
      payload: {},
      ts: 19,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_FORGE_REQUEST' });
    expect(validateWriteEnvelopeHeaders('ritual.feed', {
      id: 20,
      op: 'ritual.feed',
      payload: {},
      ts: 20,
      protocolVersion: 1,
      clientToken: 'ritual-feed-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('quest.list', {
      id: 21,
      op: 'quest.list',
      payload: {},
      ts: 21,
      protocolVersion: 1
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('quest.accept', {
      id: 22,
      op: 'quest.accept',
      payload: {},
      ts: 22,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_QUEST_ACCEPT' });
    expect(validateWriteEnvelopeHeaders('quest.turn_in', {
      id: 23,
      op: 'quest.turn_in',
      payload: {},
      ts: 23,
      protocolVersion: 1,
      clientToken: 'quest-turn-in-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('transformation.start', {
      id: 24,
      op: 'transformation.start',
      payload: {},
      ts: 24,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_TRANSFORMATION_START' });
    expect(validateWriteEnvelopeHeaders('transformation.feed', {
      id: 25,
      op: 'transformation.feed',
      payload: {},
      ts: 25,
      protocolVersion: 1,
      clientToken: 'transformation-feed-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('pathway.list', {
      id: 26,
      op: 'pathway.list',
      payload: {},
      ts: 26,
      protocolVersion: 1
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('pathway.advance_request', {
      id: 27,
      op: 'pathway.advance_request',
      payload: {},
      ts: 27,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_PATHWAY_ADVANCE_REQUEST' });
    expect(validateWriteEnvelopeHeaders('pathway.consume_potion', {
      id: 28,
      op: 'pathway.consume_potion',
      payload: {},
      ts: 28,
      protocolVersion: 1,
      clientToken: 'pathway-consume-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('skill.learn', {
      id: 29,
      op: 'skill.learn',
      payload: {},
      ts: 29,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_SKILL_LEARN' });
    expect(validateWriteEnvelopeHeaders('skill.equip_loadout', {
      id: 30,
      op: 'skill.equip_loadout',
      payload: {},
      ts: 30,
      protocolVersion: 1,
      clientToken: 'skill-equip-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('build.place_request', {
      id: 31,
      op: 'build.place_request',
      payload: {},
      ts: 31,
      protocolVersion: 1,
      clientToken: 'build-place-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('build.place_request', {
      id: 32,
      op: 'build.place_request',
      payload: {},
      ts: 32,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_BUILD_PLACE_REQUEST' });
    expect(validateWriteEnvelopeHeaders('shop.buy', {
      id: 33,
      op: 'shop.buy',
      payload: {},
      ts: 33,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_SHOP_BUY' });
    expect(validateWriteEnvelopeHeaders('shop.sell', {
      id: 34,
      op: 'shop.sell',
      payload: {},
      ts: 34,
      protocolVersion: 1,
      clientToken: 'shop-sell-token-1'
    }).ok).toBe(true);
    expect(validateWriteEnvelopeHeaders('chat.whisper', {
      id: 35,
      op: 'chat.whisper',
      payload: {},
      ts: 35,
      protocolVersion: 1
    })).toMatchObject({ ok: false, code: 'INVALID_CHAT_WHISPER' });
    expect(validateWriteEnvelopeHeaders('chat.party', {
      id: 36,
      op: 'chat.party',
      payload: {},
      ts: 36,
      protocolVersion: 1,
      clientToken: 'chat-party-token-1'
    }).ok).toBe(true);
  });

  it('validates shop and expanded chat payloads', () => {
    expect(validateShopListPayload({ shopEntityId: 'mist-harbor-general-store' })).toMatchObject({
      ok: true,
      value: { shopEntityId: 'mist-harbor-general-store' }
    });
    expect(validateShopBuyPayload({ shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1 })).toMatchObject({
      ok: true,
      value: { shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1 }
    });
    expect(validateShopSellPayload({ shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1 })).toMatchObject({
      ok: true,
      value: { shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 1 }
    });
    expect(validateShopBuyPayload({ shopEntityId: 'mist-harbor-general-store', itemId: '', amount: 1 })).toMatchObject({ ok: false, code: 'INVALID_SHOP_BUY' });
    expect(validateShopSellPayload({ shopEntityId: 'mist-harbor-general-store', itemId: 'harbor_charm', amount: 0 })).toMatchObject({ ok: false, code: 'INVALID_SHOP_SELL' });

    expect(validateChatSayPayload({ text: 'hello shard' })).toMatchObject({ ok: true, value: { text: 'hello shard' } });
    expect(validateChatWhisperPayload({ targetPlayerId: 'player-two', text: 'private route' })).toMatchObject({
      ok: true,
      value: { targetPlayerId: 'player-two', text: 'private route' }
    });
    expect(validateChatPartyPayload({ partyId: 'party-alpha', text: 'party route' })).toMatchObject({
      ok: true,
      value: { partyId: 'party-alpha', text: 'party route' }
    });
    expect(validateChatSayPayload({ text: 'x'.repeat(1025) })).toMatchObject({ ok: false, code: 'INVALID_CHAT_SAY' });
    expect(validateChatWhisperPayload({ targetPlayerId: '', text: 'private route' })).toMatchObject({ ok: false, code: 'INVALID_CHAT_WHISPER' });
    expect(validateChatPartyPayload({ partyId: 'party-alpha', text: ' ' })).toMatchObject({ ok: false, code: 'INVALID_CHAT_PARTY' });
  });

  it('validates build payloads and rejects malformed positions, facing, and ids', () => {
    const exports = validatorExports as unknown as Record<string, (value: unknown) => unknown>;
    expect(typeof exports.validateBuildPlaceRequestPayload).toBe('function');
    expect(typeof exports.validateBuildCancelPayload).toBe('function');
    expect(typeof exports.validateBuildDismantlePayload).toBe('function');
    const validateBuildPlaceRequestPayload = exports.validateBuildPlaceRequestPayload;
    const validateBuildCancelPayload = exports.validateBuildCancelPayload;
    const validateBuildDismantlePayload = exports.validateBuildDismantlePayload;

    expect(validateBuildPlaceRequestPayload({
      workbenchEntityId: 'mist-build-bench-1',
      blueprintId: 'fog_lattice',
      dslSource: 'place fog_lattice',
      position: { x: 6, y: 4 },
      facing: 'east',
      inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
    })).toMatchObject({
      ok: true,
      value: expect.objectContaining({
        workbenchEntityId: 'mist-build-bench-1',
        blueprintId: 'fog_lattice',
        position: { x: 6, y: 4 },
        facing: 'east'
      })
    });
    expect(validateBuildPlaceRequestPayload({
      workbenchEntityId: 'mist-build-bench-1',
      blueprintId: '',
      position: { x: 6, y: 4 },
      facing: 'east',
      inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
    })).toMatchObject({ ok: false, code: 'INVALID_BUILD_PLACE_REQUEST' });
    expect(validateBuildPlaceRequestPayload({
      workbenchEntityId: 'mist-build-bench-1',
      blueprintId: 'fog_lattice',
      position: { x: '6', y: 4 },
      facing: 'east',
      inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
    })).toMatchObject({ ok: false, code: 'INVALID_BUILD_PLACE_REQUEST' });
    expect(validateBuildPlaceRequestPayload({
      workbenchEntityId: 'mist-build-bench-1',
      blueprintId: 'fog_lattice',
      position: { x: 6, y: 4 },
      facing: 'uphill',
      inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
    })).toMatchObject({ ok: false, code: 'INVALID_BUILD_PLACE_REQUEST' });
    expect(validateBuildPlaceRequestPayload({
      workbenchEntityId: 'mist-build-bench-1',
      blueprintId: 'fog_lattice',
      position: { x: 6, y: 4 },
      facing: 'east',
      inputs: []
    })).toMatchObject({ ok: false, code: 'INVALID_BUILD_PLACE_REQUEST' });

    expect(validateBuildCancelPayload({ requestId: 'build-1' })).toMatchObject({
      ok: true,
      value: { requestId: 'build-1' }
    });
    expect(validateBuildCancelPayload({ requestId: ' ' })).toMatchObject({ ok: false, code: 'INVALID_BUILD_CANCEL' });
    expect(validateBuildDismantlePayload({ structureEntityId: 'build-structure-1' })).toMatchObject({
      ok: true,
      value: { structureEntityId: 'build-structure-1' }
    });
    expect(validateBuildDismantlePayload({ structureEntityId: '' })).toMatchObject({ ok: false, code: 'INVALID_BUILD_DISMANTLE' });
  });

  it('validates pathway and skill payloads', () => {
    expect(validatePathwayListPayload({})).toMatchObject({ ok: true, value: {} });
    expect(validatePathwayListPayload({ unexpected: true })).toMatchObject({ ok: false, code: 'INVALID_PATHWAY_LIST' });
    expect(validatePathwayAdvanceRequestPayload({
      pathwayId: 'tide_priestess',
      targetSequence: 8,
      potionItemId: 'moonlight_grass',
      ritualSnapshotId: 'ritual-snapshot-1'
    })).toMatchObject({
      ok: true,
      value: {
        pathwayId: 'tide_priestess',
        targetSequence: 8,
        potionItemId: 'moonlight_grass',
        ritualSnapshotId: 'ritual-snapshot-1'
      }
    });
    expect(validatePathwayAdvanceRequestPayload({
      pathwayId: 'tide_priestess',
      targetSequence: -1,
      potionItemId: 'moonlight_grass'
    })).toMatchObject({ ok: false, code: 'INVALID_PATHWAY_ADVANCE_REQUEST' });
    expect(validatePathwayConsumePotionPayload({ potionItemId: 'moonlight_grass' })).toMatchObject({
      ok: true,
      value: { potionItemId: 'moonlight_grass' }
    });
    expect(validatePathwayConsumePotionPayload({ potionItemId: ' ' })).toMatchObject({
      ok: false,
      code: 'INVALID_PATHWAY_CONSUME_POTION'
    });

    expect(validateSkillLearnPayload({ skillId: 'mist-step', pathwaySource: 'tide_priestess' })).toMatchObject({
      ok: true,
      value: { skillId: 'mist-step', pathwaySource: 'tide_priestess' }
    });
    expect(validateSkillLearnPayload({ skillId: '', pathwaySource: 'tide_priestess' })).toMatchObject({
      ok: false,
      code: 'INVALID_SKILL_LEARN'
    });
    expect(validateSkillEquipLoadoutPayload({ loadoutId: 'field', skills: ['mist-step'] })).toMatchObject({
      ok: true,
      value: { loadoutId: 'field', skills: ['mist-step'] }
    });
    expect(validateSkillEquipLoadoutPayload({ loadoutId: 'field', skills: [''] })).toMatchObject({
      ok: false,
      code: 'INVALID_SKILL_EQUIP_LOADOUT'
    });
  });

  it('validates quest payloads and rejects malformed quest ids', () => {
    expect(validateQuestListPayload({})).toMatchObject({ ok: true, value: {} });
    expect(validateQuestListPayload({ unexpected: true })).toMatchObject({ ok: false, code: 'INVALID_QUEST_LIST' });
    expect(validateQuestAcceptPayload({ questId: 'mist-harbor-field-aid' })).toMatchObject({
      ok: true,
      value: { questId: 'mist-harbor-field-aid' }
    });
    expect(validateQuestTurnInPayload({ questId: 'mist-harbor-field-aid' })).toMatchObject({
      ok: true,
      value: { questId: 'mist-harbor-field-aid' }
    });
    expect(validateQuestAbandonPayload({ questId: 'mist-harbor-field-aid' })).toMatchObject({
      ok: true,
      value: { questId: 'mist-harbor-field-aid' }
    });
    expect(validateQuestAcceptPayload({ questId: '' })).toMatchObject({ ok: false, code: 'INVALID_QUEST_ACCEPT' });
    expect(validateQuestTurnInPayload({ questId: ' ' })).toMatchObject({ ok: false, code: 'INVALID_QUEST_TURN_IN' });
    expect(validateQuestAbandonPayload({ quest: 'mist-harbor-field-aid' })).toMatchObject({ ok: false, code: 'INVALID_QUEST_ABANDON' });
  });

  it('validates transformation payloads and rejects malformed species, materials, and end reasons', () => {
    expect(validateTransformationStartPayload({ speciesId: 'mist-wolf', depth: 'disguise' })).toMatchObject({
      ok: true,
      value: { speciesId: 'mist-wolf', depth: 'disguise' }
    });
    expect(validateTransformationStartPayload({ speciesId: 'mist-wolf', depth: 'assimilation' }).ok).toBe(true);
    expect(validateTransformationStartPayload({ speciesId: '', depth: 'disguise' })).toMatchObject({
      ok: false,
      code: 'INVALID_TRANSFORMATION_START'
    });
    expect(validateTransformationStartPayload({ speciesId: 'mist-wolf', depth: 'mask' })).toMatchObject({
      ok: false,
      code: 'INVALID_TRANSFORMATION_START'
    });

    expect(validateTransformationFeedPayload({ itemId: 'moonlight_grass', amount: 2 })).toMatchObject({
      ok: true,
      value: { itemId: 'moonlight_grass', amount: 2 }
    });
    expect(validateTransformationFeedPayload({ itemId: 'moonlight_grass', amount: 0 })).toMatchObject({
      ok: false,
      code: 'INVALID_TRANSFORMATION_FEED'
    });

    expect(validateTransformationEndPayload({ reason: 'manual' })).toMatchObject({
      ok: true,
      value: { reason: 'manual' }
    });
    expect(validateTransformationEndPayload({ reason: 'timeout' }).ok).toBe(true);
    expect(validateTransformationEndPayload({ reason: 'abandon' })).toMatchObject({
      ok: false,
      code: 'INVALID_TRANSFORMATION_END'
    });
  });

  it('validates forge and ritual payloads', () => {
    expect(validateForgeRequestPayload({
      stationEntityId: 'mist-forge-1',
      mode: 'nl',
      prompt: 'shape a fog blade',
      inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
    })).toMatchObject({
      ok: true,
      value: expect.objectContaining({ stationEntityId: 'mist-forge-1', mode: 'nl' })
    });
    expect(validateForgeRequestPayload({
      stationEntityId: 'mist-forge-1',
      mode: 'dsl',
      dslSource: 'forge { blade }',
      inputs: [{ itemId: 'mist_iron_ore', amount: 1 }]
    }).ok).toBe(true);
    expect(validateForgeRequestPayload({
      stationEntityId: 'mist-forge-1',
      mode: 'nl',
      inputs: [{ itemId: 'moonlight_grass', amount: 1 }]
    })).toMatchObject({ ok: false, code: 'INVALID_FORGE_REQUEST' });
    expect(validateForgeRequestPayload({
      stationEntityId: 'mist-forge-1',
      mode: 'nl',
      prompt: 'shape',
      inputs: [{ itemId: '', amount: 1 }]
    })).toMatchObject({ ok: false, code: 'INVALID_FORGE_REQUEST' });
    expect(validateForgeCancelPayload({ requestId: 'forge-1' })).toMatchObject({
      ok: true,
      value: { requestId: 'forge-1' }
    });

    expect(validateRitualStartPayload({
      altarEntityId: 'mist-altar-1',
      ritualId: 'fog_lattice_focus',
      expectedMaterials: [{ itemId: 'moonlight_grass', amount: 1 }]
    })).toMatchObject({
      ok: true,
      value: expect.objectContaining({ ritualId: 'fog_lattice_focus' })
    });
    expect(validateRitualFeedPayload({ requestId: 'ritual-1', itemId: 'moonlight_grass', amount: 1 })).toMatchObject({
      ok: true,
      value: { requestId: 'ritual-1', itemId: 'moonlight_grass', amount: 1 }
    });
    expect(validateRitualCancelPayload({ requestId: 'ritual-1' })).toMatchObject({
      ok: true,
      value: { requestId: 'ritual-1' }
    });
    expect(validateRitualStartPayload({
      altarEntityId: 'mist-altar-1',
      ritualId: '',
      expectedMaterials: []
    })).toMatchObject({ ok: false, code: 'INVALID_RITUAL_START' });
    expect(validateRitualFeedPayload({ requestId: 'ritual-1', itemId: 'moonlight_grass', amount: 0 })).toMatchObject({
      ok: false,
      code: 'INVALID_RITUAL_FEED'
    });
  });

  it('validates system ping payloads without requiring a tick', () => {
    expect(validateSystemPingPayload({ tick: 7 }).ok).toBe(true);
    expect(validateSystemPingPayload({}).ok).toBe(true);
    expect(validateSystemPingPayload({ tick: -1 }).ok).toBe(false);
  });

  it('validates progression server push payloads with authoritative state and audit reasons', () => {
    const state = createProgressionState();
    const projection = {
      playerId: 'player-two',
      aoiActorLabel: '狂暴的旅人',
      aoiActorVariantId: 'player_ooc',
      level: 12,
      pathway: 'tide_priestess',
      sequenceBadge: 'sequence_3',
      outOfControlAura: true,
      transformationVisible: false,
      identityVisibleInAoi: false
    };
    const milestone = {
      milestoneId: 'player-one:level_up:10',
      playerId: 'player-one',
      type: 'level_up',
      occurredAt: 1200,
      shardBroadcast: true,
      duplicate: false,
      payload: { level: 10, source: 'quest' }
    };

    expect(validateProgressionSelfStatePayload({ state })).toMatchObject({ ok: true, value: { state } });
    expect(validateProgressionSelfPatchPayload({ patch: { exp: 25, sanity: 10 }, reason: 'quest_reward' })).toMatchObject({
      ok: true,
      value: { patch: { exp: 25, sanity: 10 }, reason: 'quest_reward' }
    });
    expect(validateProgressionAoiVisibleChangedPayload({ playerId: 'player-two', projection })).toMatchObject({
      ok: true,
      value: { playerId: 'player-two', projection }
    });
    expect(validateProgressionAoiVisibleLeftPayload({ playerId: 'player-two' })).toMatchObject({
      ok: true,
      value: { playerId: 'player-two' }
    });
    expect(validateProgressionMilestonePayload({ milestone })).toMatchObject({ ok: true, value: { milestone } });
  });

  it('validates monster server push payloads and evade acknowledgements', () => {
    expect(validateMonsterAggroChangedPayload({
      shardId: 'm3-dev',
      monsterId: 'wolf-1',
      fromState: 'PATROL',
      toState: 'ALERT',
      threat: 35,
      towardsPlayerId: 'player-one',
      tick: 1200
    })).toMatchObject({
      ok: true,
      value: expect.objectContaining({ monsterId: 'wolf-1', toState: 'ALERT' })
    });
    expect(validateMonsterCombatPreludePayload({
      shardId: 'm3-dev',
      monsterId: 'wolf-1',
      monsterEntityIds: ['wolf-1'],
      leadTimeMs: 1500,
      escapeWindowMs: 1500
    })).toMatchObject({
      ok: true,
      value: expect.objectContaining({ monsterEntityIds: ['wolf-1'] })
    });
    expect(validateMonsterEvadeAckPayload({ ok: true, code: 'EVADED', reason: 'stealth evade accepted' })).toMatchObject({ ok: true });
    expect(validateMonsterEvadeAckPayload({ ok: false, code: 'NOT_ELIGIBLE', reason: 'player is facing the monster' })).toMatchObject({ ok: true });

    expect(validateMonsterAggroChangedPayload({
      shardId: 'm3-dev',
      monsterId: 'wolf-1',
      fromState: 'PATROL',
      toState: 'FLYING',
      threat: 35,
      towardsPlayerId: 'player-one',
      tick: 1200
    })).toMatchObject({ ok: false, code: 'INVALID_MONSTER_AGGRO_CHANGED' });
    expect(validateMonsterCombatPreludePayload({
      shardId: 'm3-dev',
      monsterId: 'wolf-1',
      monsterEntityIds: [],
      leadTimeMs: 1500,
      escapeWindowMs: 1500
    })).toMatchObject({ ok: false, code: 'INVALID_MONSTER_COMBAT_PRELUDE' });
    expect(validateMonsterEvadeAckPayload({ ok: true, code: '', reason: 'missing code' })).toMatchObject({
      ok: false,
      code: 'INVALID_MONSTER_EVADE_ACK'
    });
  });

  it('rejects progression patches with empty reasons or out-of-range authoritative fields', () => {
    expect(validateProgressionSelfStatePayload({
      state: {
        playerId: 'player-one',
        protocolVersion: 'v3',
        updatedAt: 1000,
        contentHash: 'hash-one'
      }
    })).toMatchObject({ ok: false, code: 'INVALID_PROGRESSION_SELF_STATE' });
    expect(validateProgressionSelfPatchPayload({ patch: { level: 0 }, reason: 'server_patch' })).toMatchObject({
      ok: false,
      code: 'PROGRESSION_PATCH_REJECTED'
    });
    expect(validateProgressionSelfPatchPayload({ patch: { sanity: 101 }, reason: 'server_patch' })).toMatchObject({
      ok: false,
      code: 'PROGRESSION_PATCH_REJECTED'
    });
    expect(validateProgressionSelfPatchPayload({ patch: { exp: 10 }, reason: '' })).toMatchObject({
      ok: false,
      code: 'INVALID_PROGRESSION_SELF_PATCH'
    });
  });
});

function createProgressionState() {
  return {
    playerId: 'player-one',
    level: 5,
    exp: 40,
    expToNextLevel: 100,
    skillPoints: 2,
    pathway: 'tide_priestess',
    sequence: 7,
    sanity: 0,
    isOutOfControl: false,
    recoveryQuestId: null,
    transformationDepth: 0,
    transformedSpecies: null,
    transformExpiresAt: null,
    speciesReputation: { slime_collective: 3 },
    identityVisibleInAoi: true,
    aoiActorLabel: 'Player',
    aoiActorVariantId: 'player',
    protocolVersion: 'v3',
    updatedAt: 1000,
    contentHash: 'hash-one'
  };
}
