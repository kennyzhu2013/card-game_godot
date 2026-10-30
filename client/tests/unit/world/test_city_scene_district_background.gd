extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const DISTRICT_IDS := [
	"shadow_alley",
	"steelworks",
	"misty_port",
	"sacred_seven",
	"stone_tower",
	"ascetic_mountain",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_city_scene_district_background.gd --")
	await test_shadow_alley_morning_uses_phase_background()
	await test_shadow_alley_night_uses_phase_background()
	await test_empty_time_falls_back_to_base_district_background()
	await test_all_districts_have_morning_runtime_background()
	return {"passed": _passed, "failed": _failed}


func test_shadow_alley_morning_uses_phase_background() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.time_of_day = "morning"
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	_assert_background_path_contains(city, "district_shadow_alley_morning.png", "shadow_alley morning applies the phase district background")
	city.queue_free()


func test_shadow_alley_night_uses_phase_background() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.time_of_day = "night"
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	_assert_background_path_contains(city, "district_shadow_alley_night.png", "shadow_alley night applies the phase district background")
	city.queue_free()


func test_empty_time_falls_back_to_base_district_background() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.time_of_day = ""
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	_assert_background_path_contains(city, "district_shadow_alley.png", "empty time_of_day falls back to the base district background")
	city.queue_free()


func test_all_districts_have_morning_runtime_background() -> void:
	for district_id in DISTRICT_IDS:
		var city = await _city()
		if city == null:
			return
		var gs = _state()
		gs.time_of_day = "morning"
		city.open_district(str(district_id), gs)
		await Engine.get_main_loop().process_frame
		_assert_background_path_contains(city, "district_%s_morning.png" % str(district_id), "%s morning background is mounted at runtime" % str(district_id))
		city.queue_free()


func _city() -> Control:
	var packed = load("res://scenes/world/city_scene.tscn")
	if packed == null or not packed.can_instantiate():
		assert_true(false, "city_scene.tscn loads")
		return null
	var city = packed.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	return city


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _assert_background_path_contains(city: Control, expected_filename: String, message: String) -> void:
	var background = city.get_node_or_null("Background")
	assert_true(background is TextureRect, "%s has Background TextureRect" % message)
	if not background is TextureRect:
		return
	var texture := (background as TextureRect).texture
	assert_true(texture is Texture2D, "%s loads a Texture2D" % message)
	if texture is Texture2D:
		assert_true(str((texture as Texture2D).resource_path).find(expected_filename) >= 0, "%s path contains %s" % [message, expected_filename])


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
