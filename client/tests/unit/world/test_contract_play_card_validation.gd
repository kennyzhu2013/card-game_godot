extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_contract_play_card_validation.gd --")
	test_contract_rules_start_unresolved_and_update_on_play()
	test_drill_card_referenced_marks_used_card_for_acting_exp()
	return {"passed": _passed, "failed": _failed}


func test_contract_rules_start_unresolved_and_update_on_play() -> void:
	var gs = _state()
	var battle = TurnBattleScript.new()
	var rule_a := "rule_a"
	var rule_b := "rule_b"
	var contract: Array[String] = [rule_a, rule_b]
	var card = _card("rule_a_card", [rule_a])
	battle.setup_battle([card], [], [_enemy("dummy")], contract, null, gs)
	assert_eq(str(battle.rule_satisfaction.get(rule_a, "")), "unresolved", "matching contract rule starts unresolved")
	assert_eq(str(battle.rule_satisfaction.get(rule_b, "")), "unresolved", "unplayed contract rule starts unresolved")
	assert_true(battle.play_card(card, battle.enemies[0]), "card with acting rule can be played")
	assert_eq(str(battle.rule_satisfaction.get(rule_a, "")), "satisfied", "played card immediately satisfies matching rule")
	assert_eq(str(battle.rule_satisfaction.get(rule_b, "")), "unresolved", "unplayed rule remains unresolved before resolve")
	gs.queue_free()


func test_drill_card_referenced_marks_used_card_for_acting_exp() -> void:
	var gs = _state()
	gs.ap = 12
	var card = _card("dtl_referenced_card", ["practice_rule"])
	gs.add_card(card)
	var runner = DrillRunnerScript.new()
	var result: Dictionary = runner.resolve_drill(gs, "street_debate", {
		"satisfied_rule_ids": ["no_god_name", "quote_scripture", "avoid_sequence_word"],
		"card_referenced": card.id,
	})
	assert_true(bool(result.get("ok", false)), "drill resolves with DTL card_referenced option")
	assert_eq(str(result.get("outcome", "")), "perfect", "all satisfied rules produce perfect drill")
	assert_eq(int(card.acting_exp), 1, "card_referenced card receives acting_exp as a used card")
	assert_eq(Array(result.get("acting_exp_card_ids", [])), [card.id], "result reports card_referenced as acting_exp source")
	gs.queue_free()


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _card(id: String, rules: Array[String]):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"rarity": "common",
		"quality": 1,
		"energy_cost": 0,
		"combat_effect": {"damage": 1, "target": "single"},
		"acting_rules": rules,
	})


func _enemy(id: String):
	var enemy = EnemyScript.new()
	enemy.id = id
	enemy.display_name = id
	enemy.hp = 30
	enemy.max_hp = 30
	enemy.def = 0
	return enemy


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
