extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_effect_engine.gd --")
	test_effect_engine_dispatch_unknown_id_returns_not_registered()
	test_effect_engine_build_ctx_contains_required_contract_keys()
	return {"passed": _passed, "failed": _failed}


func test_effect_engine_dispatch_unknown_id_returns_not_registered() -> void:
	var effect_engine = load("res://scripts/combat/effect_engine.gd")
	assert_true(effect_engine != null, "EffectEngine script exists")
	if effect_engine == null:
		return
	var result: Dictionary = effect_engine.dispatch({"id": "fake_missing_effect"}, {})
	assert_eq(result.get("ok", true), false, "unknown effect dispatch fails")
	assert_eq(str(result.get("reason", "")), "unknown_effect_id", "unknown effect uses strict reason")
	assert_eq(str(result.get("id", "")), "fake_missing_effect", "unknown effect preserves id")


func test_effect_engine_build_ctx_contains_required_contract_keys() -> void:
	var effect_engine = load("res://scripts/combat/effect_engine.gd")
	assert_true(effect_engine != null, "EffectEngine script exists for ctx")
	if effect_engine == null:
		return
	var source_actor = CombatActorScript.new()
	var target_actor = CombatActorScript.new()
	var source_card = CardScript.from_json({"id": "ctx_card", "template_id": "ctx_card"})
	var battle = TurnBattleScript.new()
	var field := {"flame_markers": 0}
	var ctx: Dictionary = effect_engine._build_ctx(source_actor, target_actor, source_card, battle, field)
	for key in ["source_actor", "target_actor", "source_card", "battle", "field"]:
		assert_true(ctx.has(key), "ctx has %s" % key)
	assert_true(ctx.get("source_actor") == source_actor, "ctx source_actor identity")
	assert_true(ctx.get("target_actor") == target_actor, "ctx target_actor identity")
	assert_true(ctx.get("source_card") == source_card, "ctx source_card identity")
	assert_true(ctx.get("battle") == battle, "ctx battle identity")
	assert_true(ctx.get("field") == field, "ctx field identity")


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
