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
		return "mainline boss narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_mainline_boss.gd --")
	test_mainline_boss_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_mainline_boss_builds_valid_prompt_context() -> void:
	var runner = TowerRunnerScript.new()
	assert_true(runner.has_method("set_ai_gm_service"), "TowerRunner exposes set_ai_gm_service() for mainline_boss")
	assert_true(runner.has_method("request_mainline_boss_ai_gm"), "TowerRunner exposes request_mainline_boss_ai_gm()")
	if not runner.has_method("set_ai_gm_service") or not runner.has_method("request_mainline_boss_ai_gm"):
		runner.free()
		return

	var fake_service := FakeAIGMService.new()
	var boss_floor = _floor(5, "boss", {"boss_id": "pseudo_god_shadow"})
	runner._tower = _tower([boss_floor])
	runner._game_state = _game_state()
	runner.call("set_ai_gm_service", fake_service)

	var text: String = str(runner.call("request_mainline_boss_ai_gm", boss_floor, {
		"prior_choices": ["spared_witness", "accepted_halfmoon"],
	}))

	assert_eq(text, "mainline boss narration", "mainline_boss returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "mainline_boss calls AI GM once")
	if fake_service.calls.is_empty():
		runner.free()
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "mainline_boss", "MAINLINE_BOSS_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("node_id", "")), "node_6_final_tower", "mainline_boss payload includes node_id")
	assert_eq(str(payload.get("boss_id", "")), "pseudo_god_shadow", "mainline_boss payload includes boss_id")
	assert_eq(_string_array(payload.get("prior_choices", [])), ["spared_witness", "accepted_halfmoon"], "mainline_boss payload includes prior_choices")
	assert_eq(int(payload.get("sequence", -1)), 6, "mainline_boss payload includes sequence")
	runner.free()


func _tower(floors: Array):
	var tower = TowerScript.new()
	tower.tower_id = "mainline_tower_unit"
	tower.tower_name = "Mainline Tower Unit"
	tower.district = "ascetic_mountain"
	tower.theme_modifiers = {"mainline_node_id": "node_6_final_tower"}
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
	gs.sequence = 6
	gs.pollution = 73
	gs.pollution_stage = 2
	gs.cycle = 3
	gs.day = 14
	gs.time_of_day = "evening"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 6, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution_stage", -1)), 2, "%s player_state.pollution_stage" % expected_scene)


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
