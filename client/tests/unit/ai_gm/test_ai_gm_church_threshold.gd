extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "church threshold narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_church_threshold.gd --")
	test_church_awareness_thresholds_build_valid_prompt_contexts()
	return {"passed": _passed, "failed": _failed}


func test_church_awareness_thresholds_build_valid_prompt_contexts() -> void:
	var gs = _game_state()
	assert_true(gs.has_method("set_ai_gm_service"), "GameState exposes set_ai_gm_service() for church thresholds")
	assert_true(gs.has_method("request_church_threshold_ai_gm"), "GameState exposes request_church_threshold_ai_gm()")
	if not gs.has_method("set_ai_gm_service") or not gs.has_method("request_church_threshold_ai_gm"):
		return

	var fake_service := FakeAIGMService.new()
	gs.call("set_ai_gm_service", fake_service)

	gs.church_awareness = 9
	gs.call("adjust_church_awareness", 1, "r20:shadow_jester")
	gs.church_awareness = 24
	gs.call("adjust_church_awareness", 1, "r20:mirror_face")
	gs.church_awareness = 49
	gs.call("adjust_church_awareness", 1, "r20:inquiry_name")

	var church_calls := _church_threshold_calls(fake_service.calls)
	assert_eq(church_calls.size(), 3, "church_threshold AI GM fires once per 10/25/50 crossing")
	assert_eq(gs.church_awareness_events.size(), 3, "church threshold events are recorded")
	if church_calls.size() < 3 or gs.church_awareness_events.size() < 3:
		return
	_assert_threshold_context(church_calls[0], "church_threshold_10", "CHURCH_THRESHOLD_TEMPLATES_10", 10)
	_assert_threshold_context(church_calls[1], "church_threshold_25", "CHURCH_THRESHOLD_TEMPLATES_25", 25)
	_assert_threshold_context(church_calls[2], "church_threshold_50", "CHURCH_THRESHOLD_TEMPLATES_50", 50)
	for event in gs.church_awareness_events:
		assert_eq(str((event as Dictionary).get("ai_gm_text", "")), "church threshold narration", "threshold event stores AI GM text")


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 22
	gs.pollution_stage = 0
	gs.cycle = 1
	gs.day = 8
	gs.time_of_day = "evening"
	gs.current_district = "sacred_seven"
	return gs


func _assert_threshold_context(ctx, expected_scene: String, expected_pool: String, threshold: int) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	var payload: Dictionary = ctx.scene_payload
	assert_eq(int(payload.get("threshold", -1)), threshold, "%s payload threshold" % expected_scene)
	assert_eq(str(payload.get("current_district", "")), "sacred_seven", "%s payload current_district" % expected_scene)
	assert_true(payload.get("recent_social_actions", []) is Array, "%s payload recent_social_actions array" % expected_scene)


func _church_threshold_calls(calls: Array) -> Array:
	var result: Array = []
	for ctx in calls:
		if ctx != null and str(ctx.scene).begins_with("church_threshold_"):
			result.append(ctx)
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
