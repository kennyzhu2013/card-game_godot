extends RefCounted

const WeatherApplier = preload("res://scripts/state/weather_effects_applier.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_weather_effects_applier.gd --")
	test_fog_fool_sequence_exp()
	test_fog_fool_acting_check()
	test_fog_priestess_returns_zero()
	test_unknown_weather_returns_zero()
	test_unknown_key_returns_zero()
	test_empty_weather_returns_zero()
	test_fog_schema_matches_r19_example()
	return {"passed": _passed, "failed": _failed}


func test_fog_fool_sequence_exp() -> void:
	var bonus = WeatherApplier.get_bonus("fog", "fool", "sequence_exp")
	assert_eq(bonus, 20, "fog + fool + sequence_exp = 20")


func test_fog_fool_acting_check() -> void:
	var bonus = WeatherApplier.get_bonus("fog", "fool", "acting_check")
	assert_eq(bonus, 1, "fog + fool + acting_check = 1")


func test_fog_priestess_returns_zero() -> void:
	var bonus = WeatherApplier.get_bonus("fog", "priestess", "sequence_exp")
	assert_eq(bonus, 0, "fog + priestess has no bonus → 0")


func test_unknown_weather_returns_zero() -> void:
	var bonus = WeatherApplier.get_bonus("thunderstorm", "fool", "sequence_exp")
	assert_eq(bonus, 0, "unknown weather returns 0")


func test_unknown_key_returns_zero() -> void:
	var bonus = WeatherApplier.get_bonus("fog", "fool", "unknown_key")
	assert_eq(bonus, 0, "unknown key returns 0")


func test_empty_weather_returns_zero() -> void:
	var bonus = WeatherApplier.get_bonus("", "fool", "sequence_exp")
	assert_eq(bonus, 0, "empty weather_id returns 0")


func test_fog_schema_matches_r19_example() -> void:
	var table := _load_weather_table()
	var fog := {}
	for entry in table:
		if entry is Dictionary and str(entry.get("weather_id", "")) == "fog":
			fog = entry
			break
	assert_true(not fog.is_empty(), "weather table contains fog entry")
	assert_true(fog.has("weather_id"), "fog has weather_id metadata")
	assert_true(fog.has("prob"), "fog has probability metadata")
	assert_true(fog.has("visual"), "fog has visual metadata")
	assert_true(fog.has("pathway_bonus"), "fog has pathway_bonus")
	assert_true(fog.has("global_modifiers"), "fog has global_modifiers")
	var fool_bonus: Dictionary = fog.get("pathway_bonus", {}).get("fool", {})
	assert_true(fool_bonus.has("sequence_exp"), "fog fool bonus has sequence_exp")
	assert_true(fool_bonus.has("acting_check"), "fog fool bonus has acting_check")
	assert_true(fool_bonus.has("forge"), "fog fool bonus has forge")
	assert_true(fool_bonus.has("pollution"), "fog fool bonus has pollution default")
	assert_eq(WeatherApplier.get_bonus("fog", "fool", "forge"), 20, "fog forge modifier = 20")
	assert_eq(WeatherApplier.get_bonus("fog", "fool", "pollution"), 0, "fog pollution modifier default = 0")
	assert_eq(WeatherApplier.get_forge_modifier("fog", "fool"), 20, "forge getter reads fog bonus")
	assert_eq(WeatherApplier.get_pollution_modifier("fog", "fool"), 0, "pollution getter reads fog default")
	assert_eq(WeatherApplier.get_global_modifier("fog", "tower_size_up"), 0, "global getter returns default 0")


func _load_weather_table() -> Array:
	var text := FileAccess.get_file_as_string("res://data/weather/weather_table.json")
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Array else []


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
