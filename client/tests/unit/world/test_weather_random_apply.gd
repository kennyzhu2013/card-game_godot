extends RefCounted

const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const WeatherApplierScript = preload("res://scripts/state/weather_effects_applier.gd")
const TowerGeneratorScript = preload("res://scripts/tower/tower_generator.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const AUTO_SAVE_PATH := "user://weather_random_apply_auto.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_weather_random_apply.gd --")
	test_weather_table_has_five_weighted_entries()
	test_sleep_rolls_weather_into_game_state()
	await test_hub_window_label_uses_current_weather()
	test_weather_applier_exposes_r19_keys()
	test_storm_weather_upgrades_small_tower()
	return {"passed": _passed, "failed": _failed}


func test_weather_table_has_five_weighted_entries() -> void:
	var table := _weather_table()
	assert_eq(table.size(), 5, "weather table has 5 MVP entries")
	var ids: Array[String] = []
	var total_prob := 0.0
	for entry in table:
		if entry is Dictionary:
			ids.append(str(entry.get("weather_id", "")))
			total_prob += float(entry.get("prob", 0.0))
	for expected in ["sunny", "fog", "rain", "storm", "full_moon"]:
		assert_true(expected in ids, "weather table contains %s" % expected)
	assert_true(abs(total_prob - 1.0) < 0.001, "weather probabilities sum to 1.0")


func test_sleep_rolls_weather_into_game_state() -> void:
	if not _script_defines_method("roll_weather"):
		assert_true(false, "SleepService exposes roll_weather")
		return
	var service = SleepServiceScript.new()
	var rolled: Dictionary = service.call("roll_weather", 0.36)
	assert_eq(str(rolled.get("weather_id", "")), "fog", "roll 0.36 selects fog from weighted table")
	var gs = _state()
	service.call("sleep_to_next_day", gs, 1, AUTO_SAVE_PATH, 0.36)
	assert_eq(str(gs.current_weather), "fog", "sleep writes rolled weather to GameState.current_weather")


func test_hub_window_label_uses_current_weather() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.current_weather = "fog"
	GameState.time_of_day = "morning"
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for weather label")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var label = hub.get_node_or_null("MarginContainer/VBoxContainer/WindowLabel")
	assert_true(label != null, "WindowLabel exists")
	if label != null:
		assert_eq(str(label.text), "窗外：雾 · 白天", "WindowLabel shows current weather and time")
	hub.queue_free()
	GameState.from_dict(previous)


func test_weather_applier_exposes_r19_keys() -> void:
	assert_eq(WeatherApplierScript.get_bonus("fog", "fool", "sequence_exp"), 20, "fog fool sequence_exp bonus")
	assert_eq(WeatherApplierScript.get_bonus("fog", "fool", "acting_check"), 1, "fog fool acting_check bonus")
	assert_eq(WeatherApplierScript.get_bonus("fog", "fool", "forge"), 20, "fog fool forge bonus")
	assert_eq(WeatherApplierScript.get_bonus("fog", "fool", "pollution"), 0, "fog fool pollution key default")
	assert_eq(WeatherApplierScript.get_global_modifier("storm", "tower_size_up"), 100, "storm tower_size_up global modifier")
	assert_eq(WeatherApplierScript.get_global_modifier("storm", "pollution"), 2, "storm pollution global modifier")


func test_storm_weather_upgrades_small_tower() -> void:
	var gs = _state()
	gs.current_weather = "storm"
	var generator = TowerGeneratorScript.new()
	var tower = generator.spawn_tower("small", "shadow_alley", gs, 91, "user://storm_tower_auto.json")
	assert_eq(str(tower.size), "medium", "storm weather upgrades small tower to medium")
	assert_true(tower.floors.size() >= 6 and tower.floors.size() <= 8, "storm-upgraded tower uses medium floor count")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _weather_table() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/weather/weather_table.json"))
	return parsed if parsed is Array else []


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
