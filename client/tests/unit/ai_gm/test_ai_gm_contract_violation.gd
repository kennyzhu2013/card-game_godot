extends RefCounted

const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "contract violation narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_contract_violation.gd --")
	test_contract_violation_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_contract_violation_builds_valid_prompt_context() -> void:
	var battle = TurnBattleScript.new()
	assert_true(battle.has_method("set_ai_gm_service"), "TurnBattle exposes set_ai_gm_service() for contract_violation")
	assert_true(battle.has_method("request_contract_violation_ai_gm"), "TurnBattle exposes request_contract_violation_ai_gm()")
	if not battle.has_method("set_ai_gm_service") or not battle.has_method("request_contract_violation_ai_gm"):
		return

	var fake_service := FakeAIGMService.new()
	var card = _card("violating_card", ["rule_shadow"])
	battle.call("set_ai_gm_service", fake_service)
	battle._game_state = _game_state()
	battle.contracted_rules = ["rule_shadow", "rule_mask"] as Array[String]
	battle.rule_satisfaction = {"rule_shadow": "violated", "rule_mask": "satisfied"}

	var text: String = str(battle.call("request_contract_violation_ai_gm", {
		"outcome": "partial",
		"ratio": 0.5,
	}, "rule_shadow", card))

	assert_eq(text, "contract violation narration", "contract_violation returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "contract_violation calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "contract_violation", "CONTRACT_VIOLATION_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("rule_id", "")), "rule_shadow", "contract_violation payload includes rule_id")
	assert_eq(str(payload.get("violated_card_id", "")), "violating_card", "contract_violation payload includes violated_card_id")
	assert_almost_eq(float(payload.get("satisfaction_ratio", 0.0)), 0.5, 0.0001, "contract_violation payload includes satisfaction_ratio")
	assert_eq(_string_array(ctx.contract_state.get("active_contract", [])), ["rule_shadow", "rule_mask"], "contract_violation contract_state includes active_contract")


func _card(id: String, acting_rules: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"energy_cost": 0,
		"quality": 3,
		"sequence": 9,
		"acting_rules": acting_rules,
		"combat_effect": {"damage": 1, "heal": 0, "target": "single", "range": 1, "status_effects": []},
	})


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 44
	gs.pollution_stage = 1
	gs.cycle = 1
	gs.day = 9
	gs.time_of_day = "evening"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 8, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), 44, "%s player_state.pollution" % expected_scene)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


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
