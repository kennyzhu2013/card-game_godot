extends RefCounted

const TowerRunnerScript = preload("res://scripts/tower/tower_runner.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "boss victory narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_boss_victory.gd --")
	test_boss_victory_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_boss_victory_builds_valid_prompt_context() -> void:
	var runner = TowerRunnerScript.new()
	assert_true(runner.has_method("set_ai_gm_service"), "TowerRunner exposes set_ai_gm_service() for boss_victory")
	assert_true(runner.has_method("request_boss_victory_ai_gm"), "TowerRunner exposes request_boss_victory_ai_gm()")
	if not runner.has_method("set_ai_gm_service") or not runner.has_method("request_boss_victory_ai_gm"):
		runner.free()
		return

	var fake_service := FakeAIGMService.new()
	var boss_floor = _floor(3, "boss", {"boss_id": "slag_golem"})
	runner._tower = _tower([boss_floor])
	runner._game_state = _game_state()
	runner.call("set_ai_gm_service", fake_service)

	var text: String = str(runner.call("request_boss_victory_ai_gm", boss_floor, {
		"brand_drop": {"id": "steam_brand"},
		"contract": {"ratio": 0.66},
	}))

	assert_eq(text, "boss victory narration", "boss_victory returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "boss_victory calls AI GM once")
	if fake_service.calls.is_empty():
		runner.free()
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "boss_victory", "BOSS_VICTORY_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("boss_id", "")), "slag_golem", "boss_victory payload includes boss_id")
	assert_eq(str(payload.get("district", "")), "steelworks", "boss_victory payload includes district")
	assert_true(bool(payload.get("brand_dropped", false)), "boss_victory payload includes brand_dropped")
	assert_almost_eq(float(payload.get("contract_ratio", 0.0)), 0.66, 0.0001, "boss_victory payload includes contract_ratio")
	runner.free()


func _tower(floors: Array):
	var tower = TowerScript.new()
	tower.tower_id = "tower_boss_unit"
	tower.tower_name = "Boss Unit Tower"
	tower.district = "steelworks"
	tower.floors = floors
	tower.floor_count = floors.size()
	return tower


func _floor(index: int, event_type: String, event_data: Dictionary):
	var floor = FloorScript.new()
	floor.floor_index = index
	floor.event_type = event_type
	floor.event_data = event_data.duplicate(true)
	return floor


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 7
	gs.pollution = 61
	gs.pollution_stage = 2
	gs.cycle = 2
	gs.day = 8
	gs.time_of_day = "night"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 7, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), 61, "%s player_state.pollution" % expected_scene)
	assert_eq(str(ctx.player_state.get("time_of_day", "")), "night", "%s player_state.time_of_day" % expected_scene)


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
