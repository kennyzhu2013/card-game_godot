extends RefCounted

const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const ShopInventoryScript = preload("res://scripts/shop/shop_inventory.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const AUTO_SAVE_PATH := "user://sleep_service_auto.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_sleep_service.gd --")
	test_sleep_spends_mandatory_ap_and_records_deficit()
	test_sleep_advances_day_resets_ap_and_time_of_day()
	test_sleep_applies_truthful_next_day_weather_forecast()
	test_sleep_resets_ascetic_visit_flag()
	test_sleep_resets_shop_refresh_counters()
	test_sleep_writes_auto_save()
	return {"passed": _passed, "failed": _failed}


func test_sleep_spends_mandatory_ap_and_records_deficit() -> void:
	var gs = _state()
	gs.day = 2
	gs.ap = 1
	gs.ap_max = 12
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_true(bool(result.get("ok", false)), "sleep succeeds even when AP is short")
	assert_eq(int(result.get("ap_cost", 0)), 3, "sleep reports mandatory 3 AP cost")
	assert_eq(int(result.get("ap_deficit", -1)), 2, "sleep reports AP deficit")
	assert_eq(int(gs.last_sleep_ap_deficit), 2, "GameState records last sleep deficit")
	assert_eq(int(gs.day), 3, "deficit sleep still advances day")
	assert_eq(int(gs.ap), 10, "deficit sleep refills to reduced next-day max")


func test_sleep_advances_day_resets_ap_and_time_of_day() -> void:
	var gs = _state()
	gs.day = 3
	gs.ap = 4
	gs.ap_max = 12
	gs.time_of_day = "evening"
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_true(bool(result.get("ok", false)), "sleep returns ok")
	assert_eq(int(gs.day), 4, "day advanced by 1")
	assert_eq(int(gs.ap), 12, "AP reset to ap_max after sleep")
	assert_eq(str(gs.time_of_day), "morning", "time_of_day reset to morning")


func test_sleep_applies_truthful_next_day_weather_forecast() -> void:
	var gs = _state()
	gs.day = 1
	gs.current_weather = "sunny"
	gs.set("active_rumors", [{
		"id": "intel_weather_truth_probe",
		"category": "weather",
		"display_text": "Tomorrow's smoke predicts fog",
		"source_type": "unit_test",
		"source_district": "steelworks",
		"expires_after": "next_morning",
		"has_applied": false,
		"truth_value": 100,
		"apply_target": {
			"kind": "weather_forecast.next_day",
			"payload": {"predicted_weather_id": "fog"},
		},
	}])
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH, 0.82)
	assert_true(bool(result.get("ok", false)), "sleep with weather forecast returns ok")
	assert_eq(str(gs.current_weather), "fog", "truthful weather forecast overrides random storm roll")
	var weather: Dictionary = result.get("weather", {}) if result.get("weather", {}) is Dictionary else {}
	assert_eq(str(weather.get("weather_id", "")), "fog", "sleep result reports forecast weather")
	assert_eq(str(weather.get("source", "")), "intel_forecast", "sleep result records intel forecast source")
	assert_eq(str(weather.get("forecast_intel_id", "")), "intel_weather_truth_probe", "sleep result records forecast intel id")


func test_sleep_resets_ascetic_visit_flag() -> void:
	var gs = _state()
	gs.set_meta("ascetic_visited_today", true)
	SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_true(not bool(gs.get_meta("ascetic_visited_today", false)), "ascetic visit flag cleared after sleep")


func test_sleep_resets_shop_refresh_counters() -> void:
	var gs = _state()
	gs.day = 5
	var inv = ShopInventoryScript.from_pool("donen_blackmarket", {"items": []}, gs.day, 0, RandomNumberGenerator.new())
	inv.refresh_count_today = 3
	gs.shop_inventories["donen_blackmarket"] = inv
	SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_eq(int(inv.refresh_count_today), 0, "shop refresh count cleared after sleep")
	assert_eq(int(inv.last_refresh_day), -1, "shop marked stale to force re-roll")


func test_sleep_writes_auto_save() -> void:
	var gs = _state()
	SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH)
	assert_true(FileAccess.file_exists(AUTO_SAVE_PATH), "auto save file written after sleep")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


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
