extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_card.gd --")
	test_card_from_json_full()
	test_card_default_brand_slots()
	test_card_from_skill_json_compat()
	test_card_play_count_advances_cultivation()
	test_card_to_dict_roundtrip()
	test_record_battle_witnessed()
	test_grant_acting_exp_basic()
	test_grant_acting_exp_triggers_upgrade()
	test_grant_acting_exp_capped_at_5()
	test_get_effective_damage()
	test_new_fields_roundtrip()
	test_effect_summary_explains_combat_and_field_effects()
	test_effect_summary_is_clean_player_facing_chinese()
	test_effect_summary_explains_mounted_brand_effects()
	return {"passed": _passed, "failed": _failed}


func test_card_from_json_full() -> void:
	var d := {
		"id": "shadow_arrow_q3",
		"template_id": "shadow_arrow",
		"quality": 3,
		"pathway": "fool",
		"sequence": 7,
		"rarity": "rare",
		"energy_cost": 2,
		"element": "影",
		"description": "test",
		"combat_effect": {"damage": 10, "heal": 0, "target": "single", "range": 1, "status_effects": []},
		"acting_rules": ["不连续 2 回合主动攻击", "保持神秘"],
		"brand_slots": 4,
	}
	var c = CardScript.from_json(d)
	assert_eq(c.id, "shadow_arrow_q3", "id")
	assert_eq(c.template_id, "shadow_arrow", "template_id")
	assert_eq(c.quality, 3, "quality")
	assert_eq(c.pathway, "fool", "pathway")
	assert_eq(c.sequence, 7, "sequence")
	assert_eq(c.energy_cost, 2, "energy_cost")
	assert_eq(c.damage, 10, "damage")
	assert_eq(c.acting_rules.size(), 2, "acting_rules size")
	assert_eq(c.brand_slots, 4, "brand_slots explicit")


func test_card_default_brand_slots() -> void:
	var c = CardScript.from_json({"id": "x", "quality": 5})
	assert_eq(c.brand_slots, 6, "brand_slots = quality + 1")


func test_card_from_skill_json_compat() -> void:
	var skill_d := {
		"id": "flame_arrow",
		"display_name": "焰矢",
		"pathway": "fool",
		"mp_cost": 2,
		"combat_effect": {"damage": 8, "heal": 0, "target": "single"},
	}
	var c = CardScript.from_skill_json(skill_d)
	assert_eq(c.id, "flame_arrow", "compat id")
	assert_eq(c.energy_cost, 2, "mp_cost → energy_cost")
	assert_eq(c.damage, 8, "compat damage")
	assert_true(c.brand_slots >= 2, "compat brand_slots default")


func test_card_play_count_advances_cultivation() -> void:
	var c = CardScript.from_json({"id": "y", "quality": 1})
	for i in 10:
		c.record_play()
	assert_eq(c.play_count, 10, "play_count after 10")
	assert_eq(c.cultivation_level, 1, "cultivation_level 1")
	c.record_play()
	assert_eq(c.cultivation_level, 1, "cultivation stays 1 at 11")
	for i in 9:
		c.record_play()
	assert_eq(c.play_count, 20, "play_count 20")
	assert_eq(c.cultivation_level, 2, "cultivation_level 2")


func test_card_to_dict_roundtrip() -> void:
	var d := {
		"id": "rt", "quality": 2, "pathway": "priestess", "sequence": 8,
		"energy_cost": 1, "combat_effect": {"damage": 5},
		"acting_rules": ["a"],
	}
	var c1 = CardScript.from_json(d)
	var d2 = c1.to_dict()
	var c2 = CardScript.from_json(d2)
	assert_eq(c1.id, c2.id, "rt id")
	assert_eq(c1.quality, c2.quality, "rt quality")
	assert_eq(c1.energy_cost, c2.energy_cost, "rt energy_cost")
	assert_eq(c1.damage, c2.damage, "rt damage")
	assert_eq(c1.acting_rules, c2.acting_rules, "rt acting_rules")


func test_record_battle_witnessed() -> void:
	var c = CardScript.from_json({"id": "bw_test"})
	assert_eq(c.battles_witnessed, 0, "battles_witnessed default 0")
	c.record_battle_witnessed()
	assert_eq(c.battles_witnessed, 1, "battles_witnessed incremented to 1")
	c.record_battle_witnessed()
	assert_eq(c.battles_witnessed, 2, "battles_witnessed incremented to 2")


func test_grant_acting_exp_basic() -> void:
	var c = CardScript.from_json({"id": "ae_test"})
	assert_eq(c.acting_exp, 0, "acting_exp default 0")
	assert_eq(c.upgrade_level, 0, "upgrade_level default 0")
	var result = c.grant_acting_exp(1)
	assert_true(not result, "1 acting_exp does not trigger upgrade")
	assert_eq(c.acting_exp, 1, "acting_exp now 1")
	assert_eq(c.upgrade_level, 0, "upgrade_level still 0")


func test_grant_acting_exp_triggers_upgrade() -> void:
	var c = CardScript.from_json({"id": "up_test", "quality": 3})
	# 9 grants: acting_exp = 9, no upgrade
	for i in 9:
		var r = c.grant_acting_exp(1)
		assert_true(not r, "grant %d no upgrade" % (i + 1))
	assert_eq(c.acting_exp, 9, "acting_exp = 9")
	assert_eq(c.upgrade_level, 0, "upgrade_level still 0")
	# 10th grant triggers upgrade
	var r10 = c.grant_acting_exp(1)
	assert_true(r10, "10th grant triggers upgrade")
	assert_eq(c.acting_exp, 0, "acting_exp reset to 0")
	assert_eq(c.upgrade_level, 1, "upgrade_level = 1")
	assert_eq(c.brand_slots, c.quality + 1 + 1, "brand_slots = quality + 1 + upgrade_level")


func test_grant_acting_exp_capped_at_5() -> void:
	var c = CardScript.from_json({"id": "cap_test", "quality": 1})
	# grant 10 * 5 = 50 exp to reach upgrade_level 5
	for i in 5:
		for j in 10:
			c.grant_acting_exp(1)
	assert_eq(c.upgrade_level, 5, "upgrade_level capped at 5")
	# further grants should be rejected
	var result = c.grant_acting_exp(1)
	assert_true(not result, "grant beyond level 5 rejected")
	assert_eq(c.acting_exp, 0, "acting_exp stays 0 (not accumulated)")
	assert_eq(c.upgrade_level, 5, "upgrade_level stays at 5")


func test_get_effective_damage() -> void:
	var c = CardScript.from_json({"id": "dmg_test", "quality": 1, "combat_effect": {"damage": 10}})
	assert_eq(c.get_effective_damage(), 10, "eff dmg = 10 at upgrade_level 0")
	# reach upgrade_level 2
	for i in 20:
		c.grant_acting_exp(1)
	assert_eq(c.upgrade_level, 2, "upgrade_level = 2")
	assert_eq(c.get_effective_damage(), 14, "eff dmg = round(10 * 1.40) = 14")
	# reach upgrade_level 5
	for i in 30:
		c.grant_acting_exp(1)
	assert_eq(c.upgrade_level, 5, "upgrade_level = 5")
	assert_eq(c.get_effective_damage(), 20, "eff dmg = round(10 * 2.0) = 20")


func test_new_fields_roundtrip() -> void:
	var d := {
		"id": "rt2", "quality": 2,
		"acting_exp": 7, "upgrade_level": 2, "tags": ["intent_reveal", "multi_strike"],
	}
	var c1 = CardScript.from_json(d)
	assert_eq(c1.acting_exp, 7, "rt acting_exp")
	assert_eq(c1.upgrade_level, 2, "rt upgrade_level")
	assert_eq(c1.tags.size(), 2, "rt tags size")
	assert_true("multi_strike" in c1.tags, "rt tag multi_strike")
	assert_eq(c1.brand_slots, 5, "brand_slots = quality+1+upgrade_level without explicit")
	var d2 = c1.to_dict()
	var c2 = CardScript.from_json(d2)
	assert_eq(c2.acting_exp, 7, "rt2 acting_exp")
	assert_eq(c2.upgrade_level, 2, "rt2 upgrade_level")
	assert_eq(c2.tags, ["intent_reveal", "multi_strike"], "rt2 tags")


func test_effect_summary_explains_combat_and_field_effects() -> void:
	var c = CardScript.from_json({
		"id": "summary_probe",
		"display_name": "说明探针",
		"description": "显化目标内心一句真话",
		"energy_cost": 2,
		"combat_effect": {
			"damage": 8,
			"heal": 3,
			"target": "single",
			"range": 3,
			"status_effects": [{"id": "confusion", "duration": 1}],
		},
		"social_effect": {"type": "read_truth", "duration_days": 0},
		"world_effect": {"type": "reveal_hidden_lore", "lore_entry": "hidden_probe"},
	})
	assert_true(c.has_method("effect_summary_text"), "Card exposes player-facing effect_summary_text()")
	if not c.has_method("effect_summary_text"):
		return
	var text := str(c.call("effect_summary_text"))
	assert_true(text.contains("显化目标内心一句真话"), "effect summary keeps card description")
	assert_true(text.contains("战斗") and text.contains("造成 8 伤害") and text.contains("治疗 3"), "effect summary explains combat numbers")
	assert_true(text.contains("混乱") or text.contains("confusion"), "effect summary explains status effects")
	assert_true(text.contains("社交") and text.contains("读取真话"), "effect summary explains social_effect")
	assert_true(text.contains("世界") and text.contains("揭示隐藏知识"), "effect summary explains world_effect")


func test_effect_summary_is_clean_player_facing_chinese() -> void:
	var c = CardScript.from_json({
		"id": "clean_summary_probe",
		"display_name": "纸偶契约",
		"description": "让纸张替你承受一次灾厄。",
		"rarity": "rare",
		"energy_cost": 2,
		"combat_effect": {
			"damage": 12,
			"heal": 0,
			"target": "single",
			"range": 3,
			"status_effects": [
				{"id": "paper_doll_marker", "max_stacks": 3},
				{"id": "absorb_fatal_or_curse"},
				{"id": "damage_reduction", "magnitude": 3, "duration": 2},
				{"id": "select_targets", "min_targets": 1, "max_targets": 3},
				{"id": "per_use_damage_growth", "magnitude": 1, "max_bonus": 3},
				{"id": "charge", "turns": 1},
			],
		},
		"social_effect": {
			"type": "identity_mask",
			"duration_days": 1,
			"suspicion_delta": -10,
			"church_awareness_delta": 2,
			"parameters": {
				"notes": "让别人把你认成影子替身",
				"npc_perception": "shadow_double",
			},
		},
		"world_effect": {
			"type": "create_residual_identity",
			"identity_id": "borrowed_face_clean_probe",
			"duration_days": 1,
			"allowed_locations": ["shadow_alley"],
			"uses_remaining": 3,
			"parameters": {
				"identity_id": "borrowed_face_clean_probe",
				"allowed_locations": ["shadow_alley"],
				"lore_entry": "npc_true_name",
			},
		},
	})
	var text := str(c.call("effect_summary_text"))
	assert_true(text.contains("费用：2"), "clean summary includes card cost")
	assert_true(text.contains("目标：单体") and text.contains("范围：3"), "clean summary includes target and range")
	assert_true(text.contains("造成 12 伤害"), "clean summary includes damage number")
	assert_true(text.contains("纸人替身") and text.contains("最多3层"), "clean summary explains paper-doll status")
	assert_true(text.contains("伤害减免") and text.contains("3"), "clean summary explains damage reduction value")
	assert_true(text.contains("选择1-3个目标"), "clean summary explains target-selection mechanism")
	assert_true(text.contains("本场每次使用伤害 +1") and text.contains("最多 +3"), "clean summary explains growth mechanism")
	assert_true(text.contains("场外·社交") and text.contains("伪装身份") and text.contains("怀疑-10"), "clean summary explains social effect")
	assert_true(text.contains("教会查觉 +2"), "clean summary includes church-awareness side effect")
	assert_true(text.contains("场外·世界") and text.contains("残留身份"), "clean summary explains world effect")
	assert_true(text.contains("影巷区") and text.contains("可使用3次"), "clean summary localizes locations and uses")
	for raw in [
		"paper_doll_marker",
		"absorb_fatal_or_curse",
		"damage_reduction",
		"select_targets",
		"per_use_damage_growth",
		"identity_mask",
		"create_residual_identity",
		"shadow_alley",
		"borrowed_face",
		"lore_entry",
		"parameters",
		"{",
		"}",
	]:
		assert_true(not text.contains(raw), "clean summary hides raw token %s" % raw)


func test_effect_summary_explains_mounted_brand_effects() -> void:
	var c = CardScript.from_json({
		"id": "brand_summary_probe",
		"display_name": "烙印说明探针",
		"description": "用于验证挂载烙印会显示具体效果。",
		"brand_slots": 4,
		"brands": ["damage_plus_low", "pierce", "fate_thread"],
		"combat_effect": {
			"damage": 8,
			"heal": 0,
			"target": "single",
			"range": 2,
			"status_effects": [],
		},
	})
	var summary := str(c.call("effect_summary_text"))
	assert_true(summary.contains("烙印"), "effect summary has a mounted-brand section")
	assert_true(summary.contains("锐利之纹") and summary.contains("该卡伤害增加3"), "effect summary explains damage-plus brand")
	assert_true(summary.contains("破甲之纹") and summary.contains("忽视3点防御"), "effect summary explains pierce brand")
	assert_true(summary.contains("命运之纹") and summary.contains("25%概率不消耗能量"), "effect summary explains trigger brand")
	var brands_text := c.brands_text()
	assert_true(brands_text.contains("已挂载 3/4"), "brands_text keeps slot count")
	assert_true(brands_text.contains("锐利之纹") and brands_text.contains("破甲之纹") and brands_text.contains("命运之纹"), "brands_text lists mounted brand names")
	for raw in ["damage_plus_low", "pierce", "fate_thread", "effect_payload", "{", "}"]:
		assert_true(not summary.contains(raw), "brand summary hides raw token %s" % raw)
		assert_true(not brands_text.contains(raw), "brands_text hides raw token %s" % raw)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
