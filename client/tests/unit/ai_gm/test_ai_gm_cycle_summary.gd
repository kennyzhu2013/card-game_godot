extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const CYCLE_END_PATH := "res://scripts/world/cycle_end_service.gd"

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "cycle summary narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_cycle_summary.gd --")
	test_cycle_summary_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_cycle_summary_builds_valid_prompt_context() -> void:
	var service = _service()
	if service == null:
		return
	assert_true(service.has_method("request_cycle_summary_ai_gm"), "CycleEndService exposes request_cycle_summary_ai_gm()")
	if not service.has_method("request_cycle_summary_ai_gm"):
		return

	var fake_service := FakeAIGMService.new()
	var gs = _game_state()
	var text: String = str(service.call("request_cycle_summary_ai_gm", gs, 2, {
		"days_played": 14,
		"sequence_changes": ["9_to_8"],
		"key_events": ["node_3_halfmoon_contact", "node_6_final_tower"],
	}, fake_service))

	assert_eq(text, "cycle summary narration", "cycle_summary returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "cycle_summary calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "cycle_summary", "CYCLE_SUMMARY_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(int(payload.get("cycle", -1)), 2, "cycle_summary payload includes cycle")
	assert_eq(int(payload.get("days_played", -1)), 14, "cycle_summary payload includes days_played")
	assert_eq(_string_array(payload.get("sequence_changes", [])), ["9_to_8"], "cycle_summary payload includes sequence_changes")
	assert_eq(_string_array(payload.get("key_events", [])), ["node_3_halfmoon_contact", "node_6_final_tower"], "cycle_summary payload includes key_events")


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 51
	gs.pollution_stage = 2
	gs.cycle = 2
	gs.day = 14
	gs.time_of_day = "night"
	return gs


func _service():
	var script = load(CYCLE_END_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "cycle_end_service.gd loads")
		return null
	return script


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 8, "%s player_state.sequence" % expected_scene)
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
