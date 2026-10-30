extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const DAY_CYCLE_PATH := "res://scripts/world/day_cycle_service.gd"

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "day7 narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_day7.gd --")
	test_day7_event_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_day7_event_builds_valid_prompt_context() -> void:
	var service = _service()
	if service == null:
		return
	assert_true(service.has_method("request_day7_event_ai_gm"), "DayCycleService exposes request_day7_event_ai_gm()")
	if not service.has_method("request_day7_event_ai_gm"):
		return

	var fake_service := FakeAIGMService.new()
	var gs = _game_state()
	var text: String = str(service.call("request_day7_event_ai_gm", gs, {
		"mainline_progress": ["node_1_tutorial_tower", "node_2_black_market"],
	}, fake_service))

	assert_eq(text, "day7 narration", "day7_event returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "day7_event calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "day7_event", "DAY7_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(int(payload.get("cycle", -1)), 2, "day7_event payload includes cycle")
	assert_eq(_string_array(payload.get("mainline_progress", [])), ["node_1_tutorial_tower", "node_2_black_market"], "day7_event payload includes mainline_progress")
	assert_eq(int(payload.get("halfmoon_trust", -1)), 47, "day7_event payload includes halfmoon_trust")


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 9
	gs.pollution = 28
	gs.pollution_stage = 0
	gs.cycle = 2
	gs.day = 7
	gs.time_of_day = "morning"
	gs.halfmoon_trust = 47
	return gs


func _service():
	var script = load(DAY_CYCLE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "day_cycle_service.gd loads")
		return null
	return script


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("day", -1)), 7, "%s player_state.day" % expected_scene)
	assert_eq(int(ctx.player_state.get("cycle", -1)), 2, "%s player_state.cycle" % expected_scene)


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
