extends RefCounted

const TowerScript = preload("res://scripts/tower/tower.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const PROMOTION_RITUAL_PATH := "res://scripts/sequence/promotion_ritual_service.gd"

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "sequence promotion narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_sequence_promotion.gd --")
	test_sequence_promotion_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_sequence_promotion_builds_valid_prompt_context() -> void:
	var service = _service()
	if service == null:
		return
	assert_true(service.has_method("request_sequence_promotion_ai_gm"), "PromotionRitualService exposes request_sequence_promotion_ai_gm()")
	if not service.has_method("request_sequence_promotion_ai_gm"):
		return

	var fake_service := FakeAIGMService.new()
	var text: String = str(service.call("request_sequence_promotion_ai_gm", _tower(), _game_state(), {
		"contract_ratio": 1.0,
	}, fake_service))

	assert_eq(text, "sequence promotion narration", "sequence_promotion returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "sequence_promotion calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "sequence_promotion", "SEQUENCE_PROMOTION_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(int(payload.get("from_sequence", -1)), 9, "sequence_promotion payload includes from_sequence")
	assert_eq(int(payload.get("to_sequence", -1)), 8, "sequence_promotion payload includes to_sequence")
	assert_eq(str(payload.get("ritual_tower_id", "")), "ritual_tower_introspection_3f", "sequence_promotion payload includes ritual_tower_id")
	assert_almost_eq(float(payload.get("contract_ratio", 0.0)), 1.0, 0.0001, "sequence_promotion payload includes contract_ratio")


func _tower():
	var tower = TowerScript.new()
	tower.tower_id = "ritual_tower_introspection_3f"
	tower.is_ritual_tower = true
	tower.promotion_from_sequence = 9
	tower.promotion_to_sequence = 8
	return tower


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 9
	gs.pollution = 22
	gs.pollution_stage = 0
	gs.cycle = 1
	gs.day = 10
	gs.time_of_day = "night"
	return gs


func _service():
	var script = load(PROMOTION_RITUAL_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "promotion_ritual_service.gd loads")
		return null
	return script


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 9, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("day", -1)), 10, "%s player_state.day" % expected_scene)


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
