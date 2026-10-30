extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "rumor generated narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_rumor_generated.gd --")
	test_streettalker_rumor_generated_builds_context_once_per_day()
	return {"passed": _passed, "failed": _failed}


func test_streettalker_rumor_generated_builds_context_once_per_day() -> void:
	var service = IntelServiceScript.new()
	assert_true(service.has_method("set_ai_gm_service"), "IntelService exposes set_ai_gm_service()")
	assert_true(service.has_method("request_rumor_generated_ai_gm"), "IntelService exposes request_rumor_generated_ai_gm()")
	if not service.has_method("set_ai_gm_service") or not service.has_method("request_rumor_generated_ai_gm"):
		return

	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	service.call("set_ai_gm_service", fake_service)
	var first: Dictionary = service.call("grant", gs, _intel("intel_rumor_ai_001", "tower_hint"), {"source_type": "rumor_streettalker"})
	var second: Dictionary = service.call("grant", gs, _intel("intel_rumor_ai_002", "main_story"), {"source_type": "rumor_streettalker"})

	assert_true(bool(first.get("ok", false)), "first rumor grant succeeds")
	assert_true(bool(second.get("ok", false)), "second rumor grant succeeds")
	assert_eq(str(first.get("ai_gm_text", "")), "rumor generated narration", "first daily rumor returns AI GM text")
	assert_eq(str(second.get("ai_gm_text", "")), "", "second daily rumor is rate-limited")
	assert_eq(fake_service.calls.size(), 1, "rumor_generated calls AI GM once per day")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "rumor_generated", "RUMOR_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("district", "")), "shadow_alley", "rumor_generated payload district")
	assert_eq(str(payload.get("rumor_category", "")), "tower_hint", "rumor_generated payload category")
	assert_eq(int(payload.get("truth_value", 0)), 80, "rumor_generated payload truth_value")
	assert_eq(int(payload.get("current_pollution_stage", -1)), 1, "rumor_generated payload pollution stage")


func _intel(id: String, category: String) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"display_text": "A rumor for AI GM testing.",
		"source_type": "rumor_streettalker",
		"source_district": "shadow_alley",
		"expires_after": "today",
		"truth_value": 80,
		"apply_target": {"kind": "tower_intel.enemy_intent_reveal", "payload": {"tower_template": "steelworks_small"}},
	}


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 44
	gs.pollution_stage = 1
	gs.cycle = 1
	gs.day = 4
	gs.time_of_day = "evening"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)


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
