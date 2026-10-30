extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "drill collapse narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_drill_collapse.gd --")
	test_failed_drill_builds_valid_acting_drill_collapse_context()
	return {"passed": _passed, "failed": _failed}


func test_failed_drill_builds_valid_acting_drill_collapse_context() -> void:
	var runner = DrillRunnerScript.new()
	assert_true(runner.has_method("set_ai_gm_service"), "DrillRunner exposes set_ai_gm_service()")
	assert_true(runner.has_method("request_acting_drill_collapse_ai_gm"), "DrillRunner exposes request_acting_drill_collapse_ai_gm()")
	if not runner.has_method("set_ai_gm_service") or not runner.has_method("request_acting_drill_collapse_ai_gm"):
		return

	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	runner.call("set_ai_gm_service", fake_service)
	var result: Dictionary = runner.call("resolve_drill", gs, "street_debate", {"satisfied_rule_ids": []})
	assert_true(bool(result.get("ok", false)), "resolve_drill succeeds for fail outcome")
	assert_eq(str(result.get("outcome", "")), "fail", "test reaches failed drill outcome")
	assert_eq(str(result.get("ai_gm_text", "")), "drill collapse narration", "failed drill returns AI GM collapse text")
	assert_eq(fake_service.calls.size(), 1, "acting_drill_collapse calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "acting_drill_collapse", "ACTING_DRILL_COLLAPSE_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("drill_id", "")), "street_debate", "acting_drill_collapse payload drill_id")
	assert_eq(str(payload.get("outcome", "")), "fail", "acting_drill_collapse payload outcome")
	assert_almost_eq(float(payload.get("satisfaction_ratio", 1.0)), 0.0, 0.0001, "acting_drill_collapse payload ratio")


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 55
	gs.pollution_stage = 2
	gs.cycle = 1
	gs.day = 7
	gs.time_of_day = "noon"
	gs.ap = 12
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution_stage", -1)), 2, "%s player_state.pollution_stage" % expected_scene)


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
