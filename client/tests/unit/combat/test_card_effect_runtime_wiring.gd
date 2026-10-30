extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EffectEngineScript = preload("res://scripts/combat/effect_engine.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_card_effect_runtime_wiring.gd --")
	test_all_skill_effect_ids_are_registered()
	test_legacy_effect_cards_use_explicit_structured_payloads()
	test_common_arrow_cards_use_limited_pierce_block()
	test_range_bonus_does_not_ignore_defense_by_itself()
	test_space_fold_splits_range_bonus_and_pierce_block()
	test_door_step_ignore_guard_is_fixed_defense_ignore()
	test_duration_one_weak_survives_until_enemy_action()
	test_blind_has_real_next_attack_penalty()
	test_stun_blocks_next_enemy_action()
	test_control_status_effects_block_next_enemy_action()
	test_confusion_can_redirect_enemy_attack_to_another_enemy()
	test_life_steal_heals_player_not_target()
	test_execute_bonus_changes_current_hit_damage()
	return {"passed": _passed, "failed": _failed}


func test_all_skill_effect_ids_are_registered() -> void:
	var missing: Array[String] = []
	for path in _skill_paths():
		var data := _json(path)
		var combat: Dictionary = data.get("combat_effect", {})
		var effects: Array = combat.get("status_effects", [])
		for raw_effect in effects:
			var effect_id := _effect_id(raw_effect)
			if effect_id == "":
				continue
			if not EffectEngineScript.HANDLERS.has(effect_id):
				missing.append("%s:%s" % [path.get_file(), effect_id])
	assert_true(missing.is_empty(), "all skill status_effect ids have EffectEngine handlers: %s" % ", ".join(missing))


func test_legacy_effect_cards_use_explicit_structured_payloads() -> void:
	var expected := {
		"arrow_water": {"id": "pierce_block", "magnitude": 2},
		"flame_water": {"id": "self_damage", "magnitude": 7},
		"fortune_arrow": {"id": "crit_up"},
		"inquiry_arrow": {"id": "pierce_block", "magnitude": 2},
		"jester_arrow": {"id": "confusion", "duration": 1},
		"name_arrow": {"id": "mark", "magnitude": 2},
		"shadow_flame": {"id": "burn", "duration": 1, "magnitude": 5},
		"shadow_water": {"id": "fear", "duration": 1},
		"thread_arrow": {"id": "link"},
	}
	for card_id in expected.keys():
		var data := _json("res://data/skills/%s.json" % card_id)
		var effects := _effects_from_data(data)
		assert_true(not effects.is_empty(), "%s has combat status_effects" % card_id)
		for effect in effects:
			assert_true(effect is Dictionary, "%s status_effect is explicit Dictionary payload" % card_id)
		if effects.is_empty() or not effects[0] is Dictionary:
			continue
		var actual: Dictionary = effects[0]
		var expected_effect: Dictionary = expected[card_id]
		for key in expected_effect.keys():
			if str(key) in ["duration", "magnitude"]:
				assert_eq(int(actual.get(key, 0)), int(expected_effect.get(key, 0)), "%s explicit %s" % [card_id, str(key)])
			else:
				assert_eq(actual.get(key, null), expected_effect.get(key), "%s explicit %s" % [card_id, str(key)])


func test_common_arrow_cards_use_limited_pierce_block() -> void:
	for path in ["res://data/skills/arrow_water.json", "res://data/skills/inquiry_arrow.json"]:
		var card = CardScript.from_json(_json(path))
		var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
		assert_eq(str(effect.get("id", "")), "pierce_block", "%s uses fixed pierce instead of full pierce" % card.id)
		assert_eq(int(effect.get("magnitude", 0)), 2, "%s pierces two defense points" % card.id)
		var player = _player(30)
		var enemy = _enemy("armored_%s" % card.id, 30, 6, 0)
		var battle = _battle([card], player, enemy, 9)
		assert_true(battle.play_card(card, enemy), "%s can be played at sequence 9" % card.id)
		assert_eq(enemy.hp, 24, "%s ignores only two defense points instead of full defense" % card.id)


func test_range_bonus_does_not_ignore_defense_by_itself() -> void:
	var card = _effect_attack_card("range_bonus_only", [{"id": "range_bonus", "magnitude": 3}], 7, 10)
	var player = _player(30)
	var enemy = _enemy("range_bonus_target", 30, 6, 0)
	var battle = _battle([card], player, enemy, 7)
	assert_true(battle.play_card(card, enemy), "range_bonus-only card can be played")
	assert_eq(enemy.hp, 23, "range_bonus adds damage but does not ignore defense by itself")


func test_space_fold_splits_range_bonus_and_pierce_block() -> void:
	var card = CardScript.from_json(_json("res://data/skills/priestess_s7_space_fold.json"))
	assert_eq(_effect_ids(card.status_effects), ["range_bonus", "pierce_block"], "space_fold separates distance damage from fixed pierce")
	var player = _player(30)
	var enemy = _enemy("space_fold_target", 30, 6, 0)
	var battle = _battle([card], player, enemy, 7)
	assert_true(battle.play_card(card, enemy), "space_fold can be played")
	assert_eq(enemy.hp, 16, "space_fold keeps explicit pierce_block output after splitting range_bonus")


func test_door_step_ignore_guard_is_fixed_defense_ignore() -> void:
	var card = CardScript.from_json(_json("res://data/skills/priestess_s8_door_step.json"))
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "ignore_guard", "door_step uses ignore_guard, not full pierce")
	assert_eq(int(effect.get("magnitude", 0)), 2, "door_step ignores exactly two defense points")
	var player = _player(30)
	var enemy = _enemy("door_step_target", 30, 6, 0)
	var battle = _battle([card], player, enemy, 8)
	assert_true(battle.play_card(card, enemy), "door_step can be played at sequence 8")
	assert_eq(enemy.def, 6, "door_step does not shred or mutate target defense")
	assert_eq(enemy.hp, 25, "door_step ignores two defense points instead of fully piercing defense")


func test_duration_one_weak_survives_until_enemy_action() -> void:
	var card := CardScript.from_json(_json("res://data/skills/chariot_s9_sailor_shout.json"))
	var player = _player(30)
	var enemy = _enemy("duration_one_attacker", 30, 0, 8)
	var battle = _battle([card], player, enemy, 9)
	assert_true(battle.play_card(card, null), "duration-1 weak card can be played")
	assert_true(enemy.has_status("weak"), "enemy receives weak before its turn")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 24, "duration-1 weak reduces the enemy's advertised 8 damage to 6 before expiring")
	assert_true(not enemy.has_status("weak"), "duration-1 weak expires after the affected enemy acts")


func test_blind_has_real_next_attack_penalty() -> void:
	var card := CardScript.from_json(_json("res://data/skills/tower_s9_night_pebble.json"))
	var player = _player(30)
	var enemy = _enemy("blind_attacker", 30, 0, 10)
	var battle = _battle([card], player, enemy, 9)
	assert_true(battle.play_card(card, enemy), "blind card can be played")
	assert_true(enemy.has_status("blind"), "blind status is applied to the enemy")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 25, "blind halves the enemy's next outgoing attack in the deterministic card-battle model")
	assert_true(not enemy.has_status("blind"), "duration-1 blind expires after the affected enemy acts")


func test_stun_blocks_next_enemy_action() -> void:
	var card := CardScript.from_json(_json("res://data/skills/chariot_s7_thunder_boarding.json"))
	var player = _player(30)
	var enemy = _enemy("stunned_attacker", 40, 0, 9)
	var battle = _battle([card], player, enemy, 7)
	assert_true(battle.play_card(card, enemy), "stun card can be played")
	assert_true(enemy.has_status("stun"), "stun status is applied to the enemy")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 30, "stunned enemy skips its next action instead of dealing damage")
	assert_true(not enemy.has_status("stun"), "duration-1 stun expires after skipping the affected action")


func test_control_status_effects_block_next_enemy_action() -> void:
	for effect_id in ["bind", "root", "delay_intent", "fear", "slow", "chill", "displace"]:
		var card: Card = _effect_card("control_%s" % effect_id, [{"id": effect_id, "duration": 1}], 7)
		var player = _player(30)
		var enemy = _enemy("%s_attacker" % effect_id, 30, 0, 9)
		var battle = _battle([card], player, enemy, 7)
		assert_true(battle.play_card(card, enemy), "%s card can be played" % effect_id)
		assert_true(enemy.has_status(effect_id) or enemy.has_status("confusion"), "%s status is applied" % effect_id)
		battle.end_player_turn()
		battle.run_enemy_turn()
		assert_eq(player.hp, 30, "%s prevents the enemy attack action instead of being a cosmetic status" % effect_id)


func test_confusion_can_redirect_enemy_attack_to_another_enemy() -> void:
	var card: Card = _effect_card("confusion_probe", [{"id": "confusion", "duration": 1}], 7)
	var player = _player(30)
	var attacker = _enemy("confused_attacker", 30, 0, 8)
	var ally = _enemy("confused_ally", 30, 0, 0)
	var battle = _battle_multi([card], player, [attacker, ally], 7)
	battle.field_state["confusion_redirect_chance_override"] = 1.0
	assert_true(battle.play_card(card, attacker), "confusion card can be played")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 30, "forced confusion redirect prevents damage to the player")
	assert_eq(ally.hp, 22, "forced confusion redirect sends the attack into another living enemy")
	assert_true(not attacker.has_status("confusion"), "duration-1 confusion expires after the affected action")


func test_life_steal_heals_player_not_target() -> void:
	var card := CardScript.from_json(_json("res://data/skills/emperor_s8_tax_blood.json"))
	var player = _player(20)
	player.hp = 12
	var enemy = _enemy("taxed_enemy", 30, 0, 0)
	var battle = _battle([card], player, enemy, 8)
	assert_true(battle.play_card(card, enemy), "life-steal card can be played")
	assert_eq(enemy.hp, 20, "life-steal target does not receive the card heal")
	assert_eq(player.hp, 16, "life-steal heals the player by fixed heal plus drained damage share")


func test_execute_bonus_changes_current_hit_damage() -> void:
	var card := CardScript.from_json(_json("res://data/skills/death_s7_reaper_hook.json"))
	var player = _player(30)
	var enemy = _enemy("execute_target", 60, 0, 0)
	enemy.hp = 17
	var battle = _battle([card], player, enemy, 7)
	assert_true(battle.play_card(card, enemy), "execute card can be played")
	assert_eq(enemy.hp, 0, "execute bonus applies to the current hit when target is under threshold")


func _battle(cards: Array, player, enemy, sequence: int):
	return _battle_multi(cards, player, [enemy], sequence)


func _battle_multi(cards: Array, player, enemies: Array, sequence: int):
	var battle = TurnBattleScript.new()
	battle.setup_battle(cards, [], enemies, [], player, _game_state(sequence))
	battle.hand.clear()
	for card in cards:
		battle.hand.append(card)
	battle.energy = 99
	return battle


func _effect_card(id: String, effects: Array, sequence: int):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": sequence,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "single",
			"range": 5,
			"status_effects": effects,
		},
		"tags": ["skill"],
	})


func _effect_attack_card(id: String, effects: Array, sequence: int, damage: int):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": sequence,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": damage,
			"heal": 0,
			"target": "single",
			"range": 5,
			"status_effects": effects,
		},
		"tags": ["attack"],
	})


func _player(max_hp: int):
	var actor = CombatActorScript.new()
	actor.hp = max_hp
	actor.max_hp = max_hp
	actor.def = 0
	return actor


func _enemy(id: String, hp: int, defense: int, attack_damage: int):
	var skills := []
	var ai_pattern := [{"condition": "default", "action": "defend"}]
	if attack_damage > 0:
		skills = [{"id": "hit", "name": "hit", "damage": attack_damage, "target": "single", "element": "normal"}]
		ai_pattern = [{"condition": "default", "action": "use_skill", "skill": "hit"}]
	return EnemyScript.from_json({
		"id": id,
		"display_name": id,
		"element": "normal",
		"stats": {"hp": hp, "max_hp": hp, "atk": attack_damage, "def": defense, "spd": 1},
		"skills": skills,
		"ai_pattern": ai_pattern,
	})


func _game_state(sequence: int):
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = sequence
	return gs


func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _skill_paths() -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open("res://data/skills")
	if dir == null:
		return results
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir() or not name.ends_with(".json"):
			continue
		results.append("res://data/skills/%s" % name)
	dir.list_dir_end()
	results.sort()
	return results


func _effects_from_data(data: Dictionary) -> Array:
	var combat = data.get("combat_effect", {})
	if combat is Dictionary:
		var effects = combat.get("status_effects", [])
		if effects is Array:
			return effects
	return []


func _effect_ids(effects: Array) -> Array:
	var result := []
	for effect in effects:
		if effect is Dictionary:
			result.append(str(effect.get("id", "")))
	return result


func _effect_id(raw_effect: Variant) -> String:
	if raw_effect is String:
		return str(raw_effect)
	if raw_effect is Dictionary:
		return str((raw_effect as Dictionary).get("id", ""))
	return ""


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
