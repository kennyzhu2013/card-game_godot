extends RefCounted

const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "mock ai gm"


func run() -> Dictionary:
	print("\n-- test_contract_resolve_full.gd --")
	test_contract_failed_tier_between_partial_and_broken()
	test_contract_pollution_uses_stage_multiplier_table()
	test_contract_violation_ai_gm_only_for_broken_once()
	test_contract_exp_upgrade_triggers_card_upgrade_ai_gm()
	test_perfect_drills_unlock_dedicated_rules()
	return {"passed": _passed, "failed": _failed}


func test_contract_failed_tier_between_partial_and_broken() -> void:
	var gs = _game_state()
	gs.pollution = 10
	gs.pollution_stage = 0
	var rules: Array[String] = ["rule_a", "rule_b", "rule_c"]
	var satisfied_card = _card("satisfied_card", ["rule_a"])
	var missed_card = _card("missed_card", [])
	var battle = _battle([satisfied_card, missed_card], rules, gs)
	battle.play_card(satisfied_card, battle.enemies[0])
	battle.play_card(missed_card, battle.enemies[0])
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)
	var contract: Dictionary = result.get("contract", {})
	assert_almost_eq(float(contract.get("ratio", 0.0)), 1.0 / 3.0, 0.0001, "one of three rules produces ratio below 0.6")
	assert_eq(str(contract.get("outcome", "")), "failed", "below-0.6 nonzero ratio uses failed tier, not partial or broken")
	assert_eq(int(contract.get("pollution_delta", 0)), 5, "failed tier applies base +5 pollution at stage 0")
	assert_eq(int(satisfied_card.acting_exp), 0, "failed tier does not grant acting_exp to satisfied card")
	assert_true(not bool(battle.disabled_in_floor.get("satisfied_card", false)), "failed tier does not disable cards unless outcome is broken")


func test_contract_pollution_uses_stage_multiplier_table() -> void:
	var stages := [
		{"stage": 0, "pollution": 10, "full_delta": -1, "broken_delta": 5},
		{"stage": 1, "pollution": 35, "full_delta": -2, "broken_delta": 5},
		{"stage": 2, "pollution": 60, "full_delta": -1, "broken_delta": 10},
		{"stage": 3, "pollution": 85, "full_delta": -1, "broken_delta": 10},
		{"stage": 4, "pollution": 96, "full_delta": -1, "broken_delta": 20},
	]
	for row in stages:
		var full := _resolve_contract_at_stage(int(row.get("stage")), int(row.get("pollution")), true)
		assert_eq(int(full.get("pollution_delta", 0)), int(row.get("full_delta")), "stage %d full-contract pollution delta follows R08 table" % int(row.get("stage")))
		var broken := _resolve_contract_at_stage(int(row.get("stage")), int(row.get("pollution")), false)
		assert_eq(int(broken.get("pollution_delta", 0)), int(row.get("broken_delta")), "stage %d broken-contract pollution delta follows R08 table" % int(row.get("stage")))


func test_contract_violation_ai_gm_only_for_broken_once() -> void:
	var partial_service := FakeAIGMService.new()
	var partial_gs = _game_state()
	var partial_battle = _battle([
		_card("partial_a", ["rule_a"]),
		_card("partial_b", ["rule_b"]),
	], ["rule_a", "rule_b", "rule_c"] as Array[String], partial_gs, partial_service)
	partial_battle.play_card(partial_battle.hand[0], partial_battle.enemies[0])
	partial_battle.play_card(partial_battle.hand[0], partial_battle.enemies[0])
	var partial_result: Dictionary = partial_battle.resolve_battle(true, [], 0, partial_gs)
	assert_eq(str(partial_result.get("contract", {}).get("outcome", "")), "partial", "2/3 contract remains partial")
	assert_eq(_scene_count(partial_service.calls, "contract_violation"), 0, "partial contract does not call contract_violation AI GM")

	var failed_service := FakeAIGMService.new()
	var failed_gs = _game_state()
	var failed_battle = _battle([
		_card("failed_a", ["rule_a"]),
	], ["rule_a", "rule_b", "rule_c"] as Array[String], failed_gs, failed_service)
	failed_battle.play_card(failed_battle.hand[0], failed_battle.enemies[0])
	var failed_result: Dictionary = failed_battle.resolve_battle(true, [], 0, failed_gs)
	assert_eq(str(failed_result.get("contract", {}).get("outcome", "")), "failed", "1/3 contract uses failed tier")
	assert_eq(_scene_count(failed_service.calls, "contract_violation"), 0, "failed non-broken contract does not call contract_violation AI GM")

	var broken_service := FakeAIGMService.new()
	var broken_gs = _game_state()
	var broken_battle = _battle([
		_card("broken_card", []),
	], ["rule_a", "rule_b", "rule_c"] as Array[String], broken_gs, broken_service)
	broken_battle.play_card(broken_battle.hand[0], broken_battle.enemies[0])
	var broken_result: Dictionary = broken_battle.resolve_battle(true, [], 0, broken_gs)
	assert_eq(str(broken_result.get("contract", {}).get("outcome", "")), "broken", "0/3 contract uses broken tier")
	assert_eq(_scene_count(broken_service.calls, "contract_violation"), 1, "broken contract calls contract_violation AI GM exactly once")


func test_contract_exp_upgrade_triggers_card_upgrade_ai_gm() -> void:
	var fake_service := FakeAIGMService.new()
	var gs = _game_state()
	var card = _card("upgrade_contract_card", ["rule_a"])
	card.acting_exp = 9
	card.set_ai_gm_service(fake_service)
	var battle = _battle([card], ["rule_a"] as Array[String], gs)
	battle.play_card(card, battle.enemies[0])
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)
	var contract: Dictionary = result.get("contract", {})
	assert_eq(str(contract.get("outcome", "")), "full", "upgrade test resolves full contract")
	assert_eq(int(card.upgrade_level), 1, "contract acting_exp grant upgrades card at 10 exp")
	assert_eq(int(card.acting_exp), 0, "upgraded card resets acting_exp")
	assert_eq(fake_service.calls.size(), 1, "card_upgrade AI GM is triggered once by contract exp grant")
	if not fake_service.calls.is_empty():
		assert_eq(str(fake_service.calls[0].scene), "card_upgrade", "upgrade call uses card_upgrade scene")


func test_perfect_drills_unlock_dedicated_rules() -> void:
	var runner = DrillRunnerScript.new()
	for drill_id in runner.DRILL_DEFINITION_PATHS.keys():
		var definition: Dictionary = runner.load_drill_definition(str(drill_id))
		var unlock_ids := _rule_unlock_ids(definition)
		assert_true(not unlock_ids.is_empty(), "%s perfect rewards include a dedicated rule_unlock" % str(drill_id))
		if unlock_ids.is_empty():
			continue
		var gs = _game_state()
		gs.ap = 20
		for rule_id in unlock_ids:
			gs.learned_rules.erase(rule_id)
		var result: Dictionary = runner.resolve_drill(gs, str(drill_id), {
			"satisfied_rule_ids": _definition_rule_ids(definition),
		})
		assert_eq(str(result.get("outcome", "")), "perfect", "%s resolves as perfect when all rules are satisfied" % str(drill_id))
		for rule_id in unlock_ids:
			assert_true(rule_id in gs.learned_rules, "%s perfect drill unlocks rule %s" % [str(drill_id), rule_id])


func _resolve_contract_at_stage(stage: int, pollution: int, full: bool) -> Dictionary:
	var gs = _game_state()
	gs.pollution = pollution
	gs.pollution_stage = stage
	var card = _card("stage_%d_%s" % [stage, "full" if full else "broken"], ["rule_a"] if full else [])
	var battle = _battle([card], ["rule_a"] as Array[String], gs)
	battle.play_card(card, battle.enemies[0])
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)
	return result.get("contract", {})


func _battle(cards: Array, rules: Array[String], gs, ai_gm_service = null):
	var battle = TurnBattleScript.new()
	if ai_gm_service != null:
		battle.set_ai_gm_service(ai_gm_service)
	battle.setup_battle(cards, [], [_enemy("contract_dummy", 200, 0)], rules, null, gs)
	return battle


func _card(id: String, rules: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"quality": 1,
		"energy_cost": 0,
		"combat_effect": {"damage": 1, "target": "single"},
		"acting_rules": rules,
	})


func _enemy(id: String, hp: int, defense: int):
	var enemy = EnemyScript.new()
	enemy.id = id
	enemy.display_name = id
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.def = defense
	return enemy


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.ap = 20
	gs.pollution = 0
	gs.pollution_stage = 0
	return gs


func _rule_unlock_ids(definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var rewards: Array = definition.get("rewards_perfect", []) if definition.get("rewards_perfect", []) is Array else []
	for reward in rewards:
		if reward is Dictionary and str((reward as Dictionary).get("type", "")) == "rule_unlock":
			var rule_id := str((reward as Dictionary).get("id", ""))
			if rule_id != "" and not rule_id in result:
				result.append(rule_id)
	return result


func _definition_rule_ids(definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var rules: Array = definition.get("rules", []) if definition.get("rules", []) is Array else []
	for rule in rules:
		if rule is Dictionary:
			var rule_id := str((rule as Dictionary).get("id", ""))
			if rule_id != "":
				result.append(rule_id)
	return result


func _scene_count(calls: Array, scene: String) -> int:
	var count := 0
	for ctx in calls:
		if ctx != null and str(ctx.scene) == scene:
			count += 1
	return count


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


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected %.4f, got %.4f" % [message, expected, actual])
