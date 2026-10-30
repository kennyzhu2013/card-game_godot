extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const SERVICE_PATH := "res://scripts/world/time_advance_service.gd"

var _passed := 0
var _failed := 0
var _force_sleep_requests := 0


func run() -> Dictionary:
	print("\n-- test_time_advance_in_city.gd --")
	test_time_advance_service_action_table()
	await test_city_overlay_colors_include_fog_overlay()
	await test_city_debug_time_advance_requests_force_sleep_at_night()
	await test_hotspot_time_modifier_changes_label_and_interactable_state()
	return {"passed": _passed, "failed": _failed}


func test_time_advance_service_action_table() -> void:
	var service = _service()
	if service == null:
		return
	for action_id in ["roam", "short_chat", "listen_rumor", "casino_round"]:
		var gs = _state()
		gs.time_of_day = "morning"
		var result: Dictionary = service.call("advance_for_action", gs, action_id)
		assert_true(bool(result.get("ok", false)), "%s returns ok" % action_id)
		assert_true(not bool(result.get("advanced", true)), "%s does not advance time" % action_id)
		assert_eq(str(gs.time_of_day), "morning", "%s keeps morning" % action_id)
	for action_id in ["job", "meditation", "drill", "tower_return", "debug_wait"]:
		var gs = _state()
		gs.time_of_day = "morning"
		var result: Dictionary = service.call("advance_for_action", gs, action_id)
		assert_true(bool(result.get("ok", false)), "%s returns ok" % action_id)
		assert_true(bool(result.get("advanced", false)), "%s advances time" % action_id)
		assert_eq(str(gs.time_of_day), "noon", "%s advances morning to noon" % action_id)


func test_city_overlay_colors_include_fog_overlay() -> void:
	var city = await _city()
	if city == null:
		return
	var expected := {
		"morning": {"r": 1.0, "g": 0.98, "b": 0.94, "a": 0.05},
		"noon": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.0},
		"evening": {"r": 1.0, "g": 0.60, "b": 0.40, "a": 0.10},
		"night": {"r": 0.10, "g": 0.16, "b": 0.25, "a": 0.30},
	}
	for time_id in expected.keys():
		var gs = _state()
		gs.time_of_day = str(time_id)
		gs.current_weather = "sunny"
		city.open_from_data(_district_data(), gs)
		await Engine.get_main_loop().process_frame
		var backdrop = city.get_node_or_null("DistrictBackdrop")
		assert_true(backdrop is ColorRect and backdrop.visible and float(backdrop.color.a) >= 0.99, "CityScene keeps an opaque district backdrop for %s" % time_id)
		var overlay = city.get_node_or_null("TimeOverlay")
		assert_true(overlay is ColorRect, "TimeOverlay exists for %s" % time_id)
		if overlay is ColorRect:
			_assert_color(overlay.color, expected[time_id], "TimeOverlay color for %s" % time_id)
	var fog_state = _state()
	fog_state.time_of_day = "night"
	fog_state.current_weather = "fog"
	city.open_from_data(_district_data(), fog_state)
	await Engine.get_main_loop().process_frame
	var fog = city.get_node_or_null("FogOverlay")
	assert_true(fog is ColorRect, "FogOverlay exists")
	if fog is ColorRect:
		_assert_color(fog.color, {"r": 0.53, "g": 0.53, "b": 0.53, "a": 0.15}, "FogOverlay color when weather is fog")
	city.queue_free()


func test_city_debug_time_advance_requests_force_sleep_at_night() -> void:
	var city = await _city()
	if city == null:
		return
	assert_true(city.has_signal("force_sleep_requested"), "CityScene exposes force_sleep_requested")
	if city.has_signal("force_sleep_requested"):
		_force_sleep_requests = 0
		city.force_sleep_requested.connect(_on_force_sleep_requested)
	var gs = _state()
	gs.time_of_day = "night"
	city.open_from_data(_district_data(), gs)
	await Engine.get_main_loop().process_frame
	var advance = city.find_child("TimeAdvanceButton", true, false)
	assert_true(advance is Button, "TimeAdvanceButton exists")
	if advance is Button:
		advance.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(str(gs.time_of_day), "night", "night debug advance does not silently change day or time")
	assert_true(bool(gs.get_meta("force_sleep_pending", false)), "night debug advance marks force_sleep_pending")
	assert_eq(_force_sleep_requests, 1, "night debug advance requests forced sleep from city")
	city.queue_free()


func test_hotspot_time_modifier_changes_label_and_interactable_state() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.time_of_day = "morning"
	city.open_from_data(_time_modifier_district(), gs)
	await Engine.get_main_loop().process_frame
	var morning_button = city.find_child("Hotspot_npc_old_li_time", true, false)
	assert_true(morning_button is Button, "time modifier hotspot renders in morning")
	if morning_button is Button:
		assert_true(morning_button.text.contains("还没出摊"), "morning time modifier appends label suffix")
		assert_true(morning_button.disabled, "morning time modifier can make hotspot non-interactable")
	gs.time_of_day = "night"
	city.open_from_data(_time_modifier_district(), gs)
	await Engine.get_main_loop().process_frame
	var night_button = city.find_child("Hotspot_npc_old_li_time", true, false)
	assert_true(night_button is Button, "time modifier hotspot renders at night")
	if night_button is Button:
		assert_true(night_button.text.contains("巷尾摆摊"), "night time modifier appends label suffix")
		assert_true(not night_button.disabled, "night time modifier keeps hotspot interactable")
	city.queue_free()


func _service():
	if not FileAccess.file_exists(SERVICE_PATH):
		assert_true(false, "TimeAdvanceService script exists")
		return null
	var script = load(SERVICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "TimeAdvanceService loads")
		return null
	return script.new()


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


func _district_data() -> Dictionary:
	return {
		"$schema": "city_hotspot_v1",
		"district_id": "time_test",
		"display_name": "Time Test",
		"hotspots": [
			{
				"id": "tower_time_test",
				"label": "时间塔",
				"icon": "T",
				"type": "tower",
				"ap_cost": 2,
				"payload": {},
				"visible_when": "always",
			},
		],
	}


func _time_modifier_district() -> Dictionary:
	return {
		"$schema": "city_hotspot_v1",
		"district_id": "time_modifier_test",
		"display_name": "Time Modifier Test",
		"hotspots": [
			{
				"id": "npc_old_li_time",
				"label": "老李",
				"icon": "L",
				"type": "npc",
				"ap_cost": 0,
				"payload": {"npc_id": "old_li"},
				"visible_when": "always",
				"time_modifier": {
					"morning": {"label_suffix": "（还没出摊）", "interactable": false},
					"night": {"label_suffix": "（巷尾摆摊）", "interactable": true},
				},
			},
		],
	}


func _on_force_sleep_requested() -> void:
	_force_sleep_requests += 1


func _assert_color(actual: Color, expected: Dictionary, message: String) -> void:
	var ok: bool = abs(actual.r - float(expected.get("r", 0.0))) <= 0.01
	ok = ok and abs(actual.g - float(expected.get("g", 0.0))) <= 0.01
	ok = ok and abs(actual.b - float(expected.get("b", 0.0))) <= 0.01
	ok = ok and abs(actual.a - float(expected.get("a", 0.0))) <= 0.01
	assert_true(ok, "%s expected rgba(%s,%s,%s,%s), got rgba(%.2f,%.2f,%.2f,%.2f)" % [
		message,
		str(expected.get("r", 0.0)),
		str(expected.get("g", 0.0)),
		str(expected.get("b", 0.0)),
		str(expected.get("a", 0.0)),
		actual.r,
		actual.g,
		actual.b,
		actual.a,
	])


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
