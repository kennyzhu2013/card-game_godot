extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")

const TOWER_RUNNER_SCENE := "res://scenes/tower/tower_runner.tscn"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_tower_intel_apply.gd --")
	await test_tower_runner_applies_four_tower_intel_kinds()
	return {"passed": _passed, "failed": _failed}


func test_tower_runner_applies_four_tower_intel_kinds() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _fresh_state()
	gs.ap = 12
	gs.set("active_rumors", [
		_tower_intel("intel_enemy_preview", "tower_intel.enemy_intent_reveal", {"tower_template": "shadow_alley_small", "floor_index_min": 0, "floor_index_max": 0}),
		_tower_intel("intel_shrine_location", "tower_intel.shrine_location", {"tower_template": "shadow_alley_small", "floor_index": 1}),
		_tower_intel("intel_event_choice", "tower_intel.event_choice_correct", {"tower_template": "shadow_alley_small", "event_id": "shadow_event_01", "correct_choice_id": "follow_cat"}),
		_tower_intel("intel_boss_weakness", "tower_intel.boss_weakness", {"tower_template": "shadow_alley_small", "boss_id": "alley_horror", "weakness_tag": "paper"}),
	])
	var tower = _tower()

	runner.open(tower, gs)

	assert_eq(str(tower.floors[0].event_data.get("intel_hint", "")), "preview_enemies", "enemy_intent_reveal marks matching battle floor")
	assert_eq(str(tower.floors[1].event_type), "shrine", "shrine_location forces matching floor to shrine")
	assert_eq(str(tower.floors[1].event_data.get("intel_hint", "")), "known_shrine", "shrine_location records intel hint")
	assert_eq(str(tower.floors[2].event_data.get("correct_choice_id", "")), "follow_cat", "event_choice_correct records correct choice")
	assert_eq(str(tower.floors[3].event_data.get("weakness_revealed", "")), "paper", "boss_weakness records revealed weakness")
	assert_eq(_applied_count(gs), 4, "all four tower_intel entries are marked applied")
	runner.queue_free()
	gs.queue_free()


func _tower():
	var tower = TowerScript.new()
	tower.tower_id = "shadow_alley_small"
	tower.tower_name = "Shadow Alley Intel Tower"
	tower.size = "small"
	tower.district = "shadow_alley"
	tower.floors = [
		_floor(0, "battle", {"enemy_ids": ["drunkard"]}),
		_floor(1, "battle", {"enemy_ids": ["vagrant"]}),
		_floor(2, "event", {"event_id": "shadow_event_01", "choices": [{"id": "follow_cat"}, {"id": "ignore_cat"}]}),
		_floor(3, "boss", {"boss_id": "alley_horror"}),
	]
	tower.floor_count = tower.floors.size()
	return tower


func _floor(index: int, event_type: String, event_data: Dictionary):
	var floor = FloorScript.new()
	floor.floor_index = index
	floor.event_type = event_type
	floor.event_data = event_data.duplicate(true)
	return floor


func _tower_intel(intel_id: String, kind: String, payload: Dictionary) -> Dictionary:
	return {
		"id": intel_id,
		"category": "tower_hint",
		"display_text": intel_id,
		"source_type": "unit_test",
		"source_district": "shadow_alley",
		"expires_after": "today",
		"apply_target": {"kind": kind, "payload": payload},
		"truth_value": 100,
		"has_applied": false,
	}


func _runner():
	var scene = load(TOWER_RUNNER_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower_runner scene loads")
		return null
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	return runner


func _fresh_state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _applied_count(game_state) -> int:
	var count := 0
	var active: Variant = game_state.get("active_rumors")
	if not active is Array:
		return 0
	for intel in active:
		if intel is Dictionary and bool(intel.get("has_applied", false)):
			count += 1
	return count


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
