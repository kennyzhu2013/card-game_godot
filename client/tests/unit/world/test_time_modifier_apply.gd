extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CitySceneScript = preload("res://scripts/world/city_scene.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const TowerGeneratorScript = preload("res://scripts/tower/tower_generator.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_time_modifier_apply.gd --")
	await test_hotspot_time_modifier_applies_label_suffix_visibility_and_interactable_state()
	await test_npc_city_presence_filters_shadow_alley_hotspots_by_time()
	await test_visible_when_time_gates_follow_weekly_city_rules()
	test_storm_weather_promotes_small_tower_to_medium()
	return {"passed": _passed, "failed": _failed}


func test_hotspot_time_modifier_applies_label_suffix_visibility_and_interactable_state() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.time_of_day = "morning"
	city.open_from_data(_time_modifier_fixture(), gs)
	await Engine.get_main_loop().process_frame
	var morning = city.find_child("Hotspot_npc_time_modifier", true, false)
	assert_true(morning is Button, "time_modifier hotspot renders in morning")
	if morning is Button:
		assert_true(morning.text.contains("[morning]"), "morning time_modifier appends label suffix")
		assert_true(not morning.disabled, "morning time_modifier stays interactable")
	var hidden_morning = city.find_child("Hotspot_npc_hidden_morning", true, false)
	assert_true(hidden_morning == null, "time_modifier visible=false hides the morning hotspot")
	gs.time_of_day = "night"
	city.open_from_data(_time_modifier_fixture(), gs)
	await Engine.get_main_loop().process_frame
	var night = city.find_child("Hotspot_npc_time_modifier", true, false)
	assert_true(night is Button, "time_modifier hotspot renders at night")
	if night is Button:
		assert_true(night.text.contains("[night]"), "night time_modifier appends label suffix")
		assert_true(night.disabled, "night time_modifier can make hotspot non-interactable")
	city.queue_free()


func test_npc_city_presence_filters_shadow_alley_hotspots_by_time() -> void:
	var library = NpcLibraryScript.new()
	var load_result: Dictionary = library.load_all()
	assert_true(bool(load_result.get("ok", false)), "NpcLibrary loads for city_presence")
	var old_li: Dictionary = library.get_definition("old_li")
	var xiao_ran: Dictionary = library.get_definition("xiao_ran")
	assert_true(not _city_presence_for(old_li, "shadow_alley", "morning").is_empty(), "old_li has morning presence data")
	assert_true(not _city_presence_for(old_li, "shadow_alley", "night").is_empty(), "old_li has night presence data")
	assert_true(_city_presence_for(xiao_ran, "shadow_alley", "morning").is_empty(), "xiao_ran has no morning presence in shadow_alley")
	assert_true(not _city_presence_for(xiao_ran, "shadow_alley", "night").is_empty(), "xiao_ran has night presence in shadow_alley")
	var city = await _city()
	if city == null:
		return
	var morning = _state()
	morning.time_of_day = "morning"
	city.open_district("shadow_alley", morning)
	await Engine.get_main_loop().process_frame
	var old_li_morning = city.find_child("Hotspot_npc_old_li", true, false)
	assert_true(old_li_morning is Button, "old_li renders in morning")
	if old_li_morning is Button:
		assert_true(old_li_morning.disabled, "old_li morning presence is non-interactable")
	var xiao_ran_morning = city.find_child("Hotspot_npc_xiao_ran", true, false)
	assert_true(xiao_ran_morning == null, "xiao_ran is hidden in shadow_alley morning")
	var night = _state()
	night.time_of_day = "night"
	city.open_district("shadow_alley", night)
	await Engine.get_main_loop().process_frame
	var xiao_ran_night = city.find_child("Hotspot_npc_xiao_ran", true, false)
	assert_true(xiao_ran_night is Button, "xiao_ran renders in shadow_alley night")
	city.queue_free()


func test_visible_when_time_gates_follow_weekly_city_rules() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 3
	gs.time_of_day = "night"
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	assert_true(city.find_child("Hotspot_shop_blackmarket", true, false) is Button, "black market is visible at shadow_alley night")
	gs.time_of_day = "noon"
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	var blackmarket_noon = city.find_child("Hotspot_shop_blackmarket", true, false)
	assert_true(blackmarket_noon is Button and blackmarket_noon.disabled, "black market remains discoverable but locked outside night")
	if blackmarket_noon is Button:
		assert_true(_button_copy(blackmarket_noon).contains("夜间"), "black market locked hint explains night opening")
	gs.day = 7
	gs.time_of_day = "morning"
	city.open_district("sacred_seven", gs)
	await Engine.get_main_loop().process_frame
	assert_true(city.find_child("Hotspot_job_worship_observation", true, false) is Button, "worship hotspot is visible on Sunday morning")
	gs.time_of_day = "night"
	city.open_district("sacred_seven", gs)
	await Engine.get_main_loop().process_frame
	assert_true(city.find_child("Hotspot_job_worship_observation", true, false) == null, "worship hotspot hides outside Sunday morning")
	gs.day = 6
	gs.time_of_day = "night"
	city.open_district("misty_port", gs)
	await Engine.get_main_loop().process_frame
	assert_true(city.find_child("Hotspot_auction_smuggler", true, false) is Button, "auction hotspot is visible on Saturday night")
	gs.time_of_day = "morning"
	city.open_district("misty_port", gs)
	await Engine.get_main_loop().process_frame
	var casino_morning = city.find_child("Hotspot_casino_eel_fan", true, false)
	assert_true(casino_morning is Button and casino_morning.disabled, "casino remains discoverable but locked outside night")
	if casino_morning is Button:
		assert_true(_button_copy(casino_morning).contains("夜间"), "casino locked hint explains night opening")
	var auction_morning = city.find_child("Hotspot_auction_smuggler", true, false)
	assert_true(auction_morning is Button and auction_morning.disabled, "auction remains discoverable but locked outside Saturday night")
	if auction_morning is Button:
		assert_true(_button_copy(auction_morning).contains("周六") and _button_copy(auction_morning).contains("夜间"), "auction locked hint explains Saturday night opening")
	city.queue_free()


func test_storm_weather_promotes_small_tower_to_medium() -> void:
	var generator = TowerGeneratorScript.new()
	var storm_state = _state()
	storm_state.current_weather = "storm"
	var storm_tower = generator.spawn_tower("small", "shadow_alley", storm_state, 123)
	assert_true(storm_tower != null, "storm tower spawns")
	if storm_tower != null:
		assert_eq(str(storm_tower.size), "medium", "storm upgrades small tower to medium")
	var clear_state = _state()
	clear_state.current_weather = "sunny"
	var clear_tower = generator.spawn_tower("small", "shadow_alley", clear_state, 123)
	assert_true(clear_tower != null, "sunny tower spawns")
	if clear_tower != null:
		assert_eq(str(clear_tower.size), "small", "clear weather keeps small tower size")


func _city_presence_for(npc_def: Dictionary, district_id: String, time_id: String) -> Dictionary:
	if npc_def.is_empty():
		return {}
	var raw_presence: Variant = npc_def.get("city_presence", [])
	if not raw_presence is Array:
		return {}
	for entry in raw_presence:
		if not entry is Dictionary:
			continue
		if str(entry.get("district", "")) == district_id and str(entry.get("time_of_day", "")) == time_id:
			return entry.duplicate(true)
	return {}


func _time_modifier_fixture() -> Dictionary:
	return {
		"$schema": "city_hotspot_v1",
		"district_id": "time_modifier_test",
		"display_name": "Time Modifier Test",
		"hotspots": [
			{
				"id": "npc_time_modifier",
				"label": "Time Modifier",
				"icon": "T",
				"type": "npc",
				"ap_cost": 0,
				"payload": {"npc_id": "old_li"},
				"visible_when": "always",
				"time_modifier": {
					"morning": {"label_suffix": " [morning]", "interactable": true},
					"night": {"label_suffix": " [night]", "interactable": false},
				},
			},
			{
				"id": "npc_hidden_morning",
				"label": "Hidden",
				"icon": "H",
				"type": "npc",
				"ap_cost": 0,
				"payload": {"npc_id": "xiao_ran"},
				"visible_when": "always",
				"time_modifier": {
					"morning": {"visible": false},
				},
			},
		],
	}


func _city() -> Control:
	var scene = load("res://scenes/world/city_scene.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "city_scene loads")
		return null
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	return city


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _button_copy(button: Button) -> String:
	return "%s\n%s" % [str(button.text), str(button.tooltip_text)]


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
