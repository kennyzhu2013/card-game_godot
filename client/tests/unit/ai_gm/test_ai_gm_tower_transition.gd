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
		return "transition narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_tower_transition.gd --")
	test_tower_transition_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_tower_transition_builds_valid_prompt_context() -> void:
	var runner = TowerRunnerScript.new()
	assert_true(runner.has_method("set_ai_gm_service"), "TowerRunner exposes set_ai_gm_service()")
	assert_true(runner.has_method("request_tower_floor_transition_ai_gm"), "TowerRunner exposes request_tower_floor_transition_ai_gm()")
	if not runner.has_method("set_ai_gm_service") or not runner.has_method("request_tower_floor_transition_ai_gm"):
		runner.free()
		return

	var prev_floor = _floor(0, "battle")
	var next_floor = _floor(1, "unknown")
	runner._tower = _tower([prev_floor, next_floor])
	runner._game_state = _game_state()
	var fake_service := FakeAIGMService.new()
	runner.call("set_ai_gm_service", fake_service)

	var text: String = str(runner.call("request_tower_floor_transition_ai_gm", prev_floor, next_floor))

	assert_eq(text, "transition narration", "tower_floor_transition returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "tower_floor_transition calls AI GM once")
	if fake_service.calls.is_empty():
		runner.free()
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "tower_floor_transition", "TOWER_TRANSITION_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("tower_id", "")), "tower_unit", "tower transition payload includes tower_id")
	assert_eq(int(payload.get("floor_index", -1)), 1, "tower transition payload includes next floor_index")
	assert_eq(str(payload.get("prev_event_type", "")), "battle", "tower transition payload includes prev_event_type")
	assert_eq(str(payload.get("next_event_type", "")), "unknown", "tower transition payload includes next_event_type")
	runner.free()


func _tower(floors: Array):
	var tower = TowerScript.new()
	tower.tower_id = "tower_unit"
	tower.tower_name = "Tower Unit"
	tower.floors = floors
	tower.floor_count = floors.size()
	return tower


func _floor(index: int, event_type: String):
	var floor = FloorScript.new()
	floor.floor_index = index
	floor.event_type = event_type
	return floor


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 7
	gs.pollution = 55
	gs.pollution_stage = 2
	gs.cycle = 3
	gs.day = 6
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
