extends RefCounted

const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const AUTO_SAVE_PATH := "user://sleep_full_resolve_auto.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_sleep_full_resolve.gd --")
	test_check_force_sleep_requires_pending_flag_at_night()
	test_sleep_deficit_penalties_apply_to_next_day_only()
	test_sleep_heavy_deficit_adds_pollution()
	test_storm_sleep_adds_weather_pollution_and_stacks_with_deficit()
	test_dream_fallback_pool_has_five_pollution_stages()
	test_sleep_result_contains_dream_text_for_each_pollution_stage()
	test_sleep_result_contains_old_li_morning_visitor()
	test_auto_save_payload_reflects_resolved_sleep()
	return {"passed": _passed, "failed": _failed}


func test_check_force_sleep_requires_pending_flag_at_night() -> void:
	if not _script_defines_method("check_force_sleep"):
		assert_true(false, "SleepService exposes check_force_sleep")
		return
	var gs = _state()
	gs.day = 4
	gs.time_of_day = "evening"
	var idle: Dictionary = SleepServiceScript.check_force_sleep(gs, AUTO_SAVE_PATH)
	assert_true(not bool(idle.get("forced", true)), "evening does not force sleep")
	assert_eq(int(gs.day), 4, "evening force check keeps day")
	gs.time_of_day = "night"
	var night_idle: Dictionary = SleepServiceScript.check_force_sleep(gs, AUTO_SAVE_PATH)
	assert_true(not bool(night_idle.get("forced", true)), "night alone stays playable and does not force sleep")
	assert_eq(int(gs.day), 4, "night idle force check keeps day")
	assert_eq(str(gs.time_of_day), "night", "night idle force check keeps the night segment")
	gs.set_meta("force_sleep_pending", true)
	var forced: Dictionary = SleepServiceScript.check_force_sleep(gs, AUTO_SAVE_PATH)
	assert_true(bool(forced.get("forced", false)), "pending night force check triggers sleep")
	assert_eq(int(gs.day), 5, "pending forced sleep advances day")
	assert_eq(str(gs.time_of_day), "morning", "pending forced sleep wakes in morning")
	assert_true(not bool(gs.get_meta("force_sleep_pending", true)), "pending forced sleep clears force_sleep_pending")


func test_sleep_deficit_penalties_apply_to_next_day_only() -> void:
	var gs = _state()
	gs.ap = 2
	gs.ap_max = 12
	var deficit_sleep: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_eq(int(deficit_sleep.get("ap_deficit", -1)), 1, "sleep reports deficit 1 when AP is 2")
	assert_eq(int(gs.ap_max), 11, "deficit 1 reduces next-day ap_max by 1")
	assert_eq(int(gs.ap), 11, "AP refills to reduced next-day max")
	gs.ap = gs.ap_max
	var clean_sleep: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_eq(int(clean_sleep.get("ap_deficit", -1)), 0, "clean sleep has no deficit")
	assert_eq(int(gs.ap_max), 12, "AP max penalty does not persist across later days")
	assert_eq(int(gs.ap), 12, "AP refills to restored max after clean sleep")


func test_sleep_heavy_deficit_adds_pollution() -> void:
	var gs = _state()
	gs.ap = 0
	gs.ap_max = 12
	gs.pollution = 29
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_eq(int(result.get("ap_deficit", -1)), 3, "sleep reports deficit 3 when AP is 0")
	assert_eq(int(gs.ap_max), 10, "deficit 2-3 reduces next-day ap_max by 2")
	assert_eq(int(gs.ap), 10, "AP refills to reduced heavy-deficit max")
	assert_eq(int(gs.pollution), 32, "heavy deficit adds 3 pollution")
	assert_eq(int(gs.pollution_stage), 1, "heavy deficit refreshes pollution stage")


func test_storm_sleep_adds_weather_pollution_and_stacks_with_deficit() -> void:
	var sunny = _state()
	sunny.ap = 0
	sunny.ap_max = 12
	sunny.pollution = 10
	sunny.current_weather = "sunny"
	var sunny_result: Dictionary = SleepServiceScript.sleep_to_next_day(sunny, 1, AUTO_SAVE_PATH, 0.0)
	var storm = _state()
	storm.ap = 0
	storm.ap_max = 12
	storm.pollution = 10
	storm.current_weather = "storm"
	var storm_result: Dictionary = SleepServiceScript.sleep_to_next_day(storm, 1, AUTO_SAVE_PATH, 0.0)
	assert_eq(int(sunny_result.get("weather_pollution_delta", 0)), 0, "sunny sleep has no weather pollution")
	assert_eq(int(storm_result.get("weather_pollution_delta", 0)), 2, "storm sleep reports +2 weather pollution")
	assert_eq(int(storm_result.get("pollution_delta", 0)), 5, "storm sleep stacks +2 weather with +3 AP deficit")
	assert_eq(int(storm.pollution), int(sunny.pollution) + 2, "storm sleep leaves pollution two higher than sunny with same deficit")


func test_dream_fallback_pool_has_five_pollution_stages() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dreams/fallback_pool.json"))
	assert_true(parsed is Array, "dream fallback pool is an array")
	if not parsed is Array:
		return
	var stages: Array[int] = []
	for entry in parsed:
		if entry is Dictionary:
			stages.append(int(entry.get("pollution_stage", -1)))
			assert_true(str(entry.get("text", "")).length() > 0, "dream stage %s has fallback text" % str(entry.get("pollution_stage", "")))
	for expected in range(5):
		assert_true(expected in stages, "dream fallback pool contains pollution stage %d" % expected)


func test_sleep_result_contains_dream_text_for_each_pollution_stage() -> void:
	var pollution_values: Array[int] = [0, 30, 50, 80, 95]
	for expected_stage in range(pollution_values.size()):
		var gs = _state()
		gs.pollution = pollution_values[expected_stage]
		gs.pollution_stage = expected_stage
		var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
		var dream: Dictionary = result.get("dream", {})
		assert_eq(int(dream.get("pollution_stage", -1)), expected_stage, "sleep dream uses pollution stage %d" % expected_stage)
		assert_true(str(dream.get("text", "")).length() > 0, "sleep dream stage %d has text" % expected_stage)


func test_sleep_result_contains_old_li_morning_visitor() -> void:
	var gs = _state()
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	var visitor: Dictionary = result.get("visitor", {})
	assert_eq(str(visitor.get("id", "")), "old_li_breakfast", "sleep result includes old Li breakfast visitor")
	assert_eq(str(visitor.get("time_of_day", "")), "morning", "old Li visitor happens in morning")
	assert_true(str(visitor.get("text", "")).length() > 0, "old Li visitor has static text")


func test_auto_save_payload_reflects_resolved_sleep() -> void:
	var gs = _state()
	gs.day = 8
	gs.time_of_day = "night"
	SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	var payload = JSON.parse_string(FileAccess.get_file_as_string(AUTO_SAVE_PATH))
	assert_true(payload is Dictionary, "auto save payload is dictionary")
	if not payload is Dictionary:
		return
	var saved_state: Dictionary = payload.get("game_state", {})
	assert_eq(int(saved_state.get("day", 0)), 9, "auto save stores advanced day")
	assert_eq(str(saved_state.get("time_of_day", "")), "morning", "auto save stores morning")
	assert_eq(int(saved_state.get("ap", 0)), int(saved_state.get("ap_max", -1)), "auto save stores refilled AP")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _script_defines_method(method_name: String) -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/world/sleep_service.gd")
	return source.contains("func %s" % method_name)


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
