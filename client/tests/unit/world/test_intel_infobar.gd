extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_intel_infobar.gd --")
	test_structured_intel_fallback_reads_specific_effects()
	await test_hub_and_city_infobars_show_active_rumors()
	await test_tower_runner_preview_lists_tower_intels()
	return {"passed": _passed, "failed": _failed}


func test_hub_and_city_infobars_show_active_rumors() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.set("active_rumors", [_display_intel("intel_ui_shadow_001", "失踪案塔第 1 层敌人意图明牌")])
	var active_rumors: Variant = GameState.get("active_rumors")
	var expected_text := ""
	if active_rumors is Array and not active_rumors.is_empty():
		expected_text = IntelServiceScript.player_display_text(active_rumors[0])
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var hub_info = hub.find_child("IntelInfoButton", true, false)
	assert_true(hub_info is Button, "Hub status bar exposes IntelInfoButton")
	if hub_info is Button:
		assert_true(str(hub_info.text).find("1") >= 0, "Hub intel info button shows active count")
		assert_true(str(hub_info.tooltip_text).find(expected_text) >= 0, "Hub intel tooltip lists active rumor text")
		hub_info.pressed.emit()
		await Engine.get_main_loop().process_frame
		var hub_dialog = hub.find_child("IntelInfoDialog", true, false)
		assert_true(hub_dialog != null and hub_dialog.visible, "Hub IntelInfoButton opens an intel dialog")
		if hub_dialog != null:
			assert_true(str(hub_dialog.dialog_text).find(expected_text) >= 0, "Hub intel dialog lists active rumor text")
			hub_dialog.hide()
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var city_info = city.find_child("IntelInfoButton", true, false) if city != null else null
	assert_true(city_info is Button, "CityScene top bar exposes IntelInfoButton")
	if city_info is Button:
		assert_true(str(city_info.text).find("1") >= 0, "CityScene intel info button shows active count")
		assert_true(str(city_info.tooltip_text).find(expected_text) >= 0, "CityScene intel tooltip lists active rumor text")
		city_info.pressed.emit()
		await Engine.get_main_loop().process_frame
		var city_dialog = city.find_child("IntelInfoDialog", true, false)
		assert_true(city_dialog != null and city_dialog.visible, "CityScene IntelInfoButton opens an intel dialog")
		if city_dialog != null:
			assert_true(str(city_dialog.dialog_text).find(expected_text) >= 0, "CityScene intel dialog lists active rumor text")
	hub.queue_free()
	GameState.from_dict(previous)


func test_structured_intel_fallback_reads_specific_effects() -> void:
	var tower_text := IntelServiceScript.player_display_text({
		"display_text": "mist_small first floors reveal enemy intent",
		"category": "tower_hint",
		"source_district": "misty_port",
		"apply_target": {
			"kind": "tower_intel.enemy_intent_reveal",
			"payload": {"tower_template": "mist_small", "floor_index_min": 0, "floor_index_max": 1},
		},
	})
	assert_true(tower_text.contains("敌人意图") and tower_text.contains("1-2"), "structured tower intel explains the concrete effect")
	assert_true(not tower_text.contains("一条情报"), "structured tower intel does not fall back to generic text")
	assert_true(not tower_text.contains("mist_small"), "structured tower intel hides raw template ids")


func test_tower_runner_preview_lists_tower_intels() -> void:
	var scene = load("res://scenes/tower/tower_runner.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower_runner scene loads")
		return
	var gs = _fresh_state()
	gs.set("active_rumors", [_display_intel("intel_preview_enemy_001", "进塔后第 1 层敌人意图明牌")])
	var tower = TowerScript.new()
	tower.tower_id = "shadow_alley_small"
	tower.tower_name = "Shadow Alley Preview Tower"
	tower.size = "small"
	tower.district = "shadow_alley"
	tower.floors = [_floor(0, "battle", {"enemy_ids": ["drunkard"]}), _floor(1, "boss", {"boss_id": "alley_horror"})]
	tower.floor_count = tower.floors.size()
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	runner.open(tower, gs)
	await Engine.get_main_loop().process_frame
	var preview = runner.find_child("IntelPreviewLabel", true, false)
	assert_true(preview is Label, "TowerRunner exposes IntelPreviewLabel before floor entry")
	if preview is Label:
		assert_true(str(preview.text).find("第 1 层") >= 0, "TowerRunner preview lists active tower intel text")
	runner.queue_free()
	gs.queue_free()


func _display_intel(intel_id: String, text: String) -> Dictionary:
	return {
		"id": intel_id,
		"category": "tower_hint",
		"display_text": text,
		"source_type": "unit_test",
		"source_district": "shadow_alley",
		"expires_after": "today",
		"apply_target": {"kind": "tower_intel.enemy_intent_reveal", "payload": {"tower_template": "shadow_alley_small", "floor_index_min": 0, "floor_index_max": 0}},
		"truth_value": 100,
		"has_applied": false,
	}


func _floor(index: int, event_type: String, event_data: Dictionary):
	var floor = FloorScript.new()
	floor.floor_index = index
	floor.event_type = event_type
	floor.event_data = event_data.duplicate(true)
	return floor


func _fresh_state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _hub() -> Control:
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


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
