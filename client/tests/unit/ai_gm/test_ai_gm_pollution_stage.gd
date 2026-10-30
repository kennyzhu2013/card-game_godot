extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "pollution stage narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_pollution_stage.gd --")
	test_pollution_stage_transition_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_pollution_stage_transition_builds_valid_prompt_context() -> void:
	var gs = _game_state()
	assert_true(gs.has_method("set_ai_gm_service"), "GameState exposes set_ai_gm_service() for pollution_stage_transition")
	assert_true(gs.has_method("set_pollution"), "GameState exposes set_pollution()")
	assert_true(gs.has_method("request_pollution_stage_transition_ai_gm"), "GameState exposes request_pollution_stage_transition_ai_gm()")
	if not gs.has_method("set_ai_gm_service") or not gs.has_method("set_pollution") or not gs.has_method("request_pollution_stage_transition_ai_gm"):
		return

	var fake_service := FakeAIGMService.new()
	gs.call("set_ai_gm_service", fake_service)
	var result: Dictionary = gs.call("set_pollution", 30, ["contract_broken"])

	assert_eq(str(result.get("ai_gm_text", "")), "pollution stage narration", "set_pollution returns pollution AI GM text")
	assert_eq(fake_service.calls.size(), 1, "pollution_stage_transition calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "pollution_stage_transition", "POLLUTION_STAGE_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(int(payload.get("from_stage", -1)), 0, "pollution_stage_transition payload includes from_stage")
	assert_eq(int(payload.get("to_stage", -1)), 1, "pollution_stage_transition payload includes to_stage")
	assert_eq(_string_array(payload.get("recent_actions", [])), ["contract_broken"], "pollution_stage_transition payload includes recent_actions")


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 29
	gs.pollution_stage = 0
	gs.cycle = 1
	gs.day = 11
	gs.time_of_day = "noon"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), 30, "%s player_state.pollution" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution_stage", -1)), 1, "%s player_state.pollution_stage" % expected_scene)


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
