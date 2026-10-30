extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_turn_battle_effect_pipeline.gd --")
	test_status_effects_dispatch_into_charge_zone()
	test_player_turn_applies_dot_and_ticks_statuses()
	test_enemy_turn_applies_dot_before_intent()
	test_resolve_battle_clears_field_state()
	test_resolve_battle_clears_actor_runtime_statuses()
	return {"passed": _passed, "failed": _failed}


func test_status_effects_dispatch_into_charge_zone() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	var enemy = _enemy("dummy", 30, 0)
	var card = _card_with_effects("charge_probe", [{"id": "charge", "magnitude": 1, "payload": []}])
	battle.setup_battle([card], [], [enemy], [], player, null)
	assert_true(_has_property(battle, "last_effect_results"), "TurnBattle.last_effect_results exists")
	assert_true(_has_property(battle, "charged_zone"), "TurnBattle.charged_zone exists")
	assert_true(_has_property(battle, "resolved_charge_payloads"), "TurnBattle.resolved_charge_payloads exists")
	assert_true(battle.has_method("add_charged_effect"), "TurnBattle.add_charged_effect exists")
	assert_true(battle.play_card(card, enemy), "charge card can be played")
	if not (_has_property(battle, "last_effect_results") and _has_property(battle, "charged_zone")):
		return
	assert_eq(battle.last_effect_results.size(), 1, "status_effects dispatch records one result")
	assert_eq(str(battle.last_effect_results[0].get("id", "")), "charge", "dispatch result preserves charge id")
	assert_true(bool(battle.last_effect_results[0].get("ok", false)), "charge dispatch succeeds")
	assert_eq(battle.charged_zone.size(), 1, "charge card enters charged_zone")
	assert_true(not card in battle.discard_pile, "charging card does not enter discard pile")
	battle.end_player_turn()
	var result: Dictionary = battle.run_enemy_turn()
	assert_eq(int(result.get("phase", -1)), battle.Phase.PLAYER_TURN, "enemy turn returns to player turn")
	assert_eq(battle.charged_zone.size(), 0, "charge resolves after one player-turn tick")
	assert_eq(battle.resolved_charge_payloads.size(), 1, "charge payload resolution is recorded")


func test_player_turn_applies_dot_and_ticks_statuses() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 20
	player.max_hp = 20
	player.add_status("burn", {"duration": 2, "magnitude": 3})
	battle.setup_battle([_blank_card("c0")], [], [_enemy("dummy", 30, 0)], [], player, null)
	assert_eq(player.hp, 17, "player burn applies at PLAYER_TURN start")
	assert_true(player.has_status("burn"), "burn survives when duration remains")
	assert_eq(int(player.statuses["burn"].get("duration", 0)), 1, "player burn duration ticks down")


func test_enemy_turn_applies_dot_before_intent() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 20
	player.max_hp = 20
	var enemy = _enemy("poisoned", 4, 0)
	enemy.add_status("poison", {"duration": 1, "magnitude": 5})
	battle.setup_battle([_blank_card("c0")], [], [enemy], [], player, null)
	battle.end_player_turn()
	var result: Dictionary = battle.run_enemy_turn()
	assert_true(enemy.is_dead(), "enemy poison applies before intent")
	assert_true(not enemy.has_status("poison"), "enemy poison duration 1 is removed")
	assert_eq(int(result.get("phase", -1)), battle.Phase.RESOLVE, "enemy death from poison resolves battle")


func test_resolve_battle_clears_field_state() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	battle.setup_battle([_blank_card("c0")], [], [_enemy("dummy", 30, 0)], [], player, null)
	battle.add_field_marker("flame_markers", 3)
	assert_eq(battle.get_field_marker_count("flame_markers"), 3, "precondition field has flame markers")
	battle.resolve_battle(true, [], 0, null)
	assert_eq(battle.get_field_marker_count("flame_markers"), 0, "resolve_battle clears field_state")


func test_resolve_battle_clears_actor_runtime_statuses() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	var enemy = _enemy("status_holder", 30, 0)
	battle.setup_battle([_blank_card("c0")], [], [enemy], [], player, null)
	player.add_status("fatal_damage_convert", {"magnitude": 0.5, "uses_per_battle": 1})
	player.add_status("immune_debuff", {"duration": 2})
	player.add_status("dodge_counter", {"magnitude": 4})
	enemy.add_status("damage_reduction", {"magnitude": 0.5, "duration": 1})
	enemy.add_status("weak", {"duration": 2, "magnitude": 1})
	assert_true(not player.statuses.is_empty(), "precondition player has runtime statuses")
	assert_true(not enemy.statuses.is_empty(), "precondition enemy has runtime statuses")
	battle.resolve_battle(true, [], 0, null)
	assert_true(player.statuses.is_empty(), "resolve_battle clears player runtime statuses")
	assert_true(enemy.statuses.is_empty(), "resolve_battle clears enemy runtime statuses")


func _blank_card(id: String):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"energy_cost": 0,
		"damage": 0,
		"quality": 3,
		"sequence": 9,
	})


func _card_with_effects(id: String, effects: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"energy_cost": 0,
		"damage": 0,
		"quality": 3,
		"sequence": 9,
		"combat_effect": {"status_effects": effects},
	})


func _enemy(id: String, hp: int, defense: int):
	return EnemyScript.from_json({
		"id": id,
		"display_name": id,
		"stats": {"hp": hp, "max_hp": hp, "atk": 1, "def": defense, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func _has_property(object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


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
