extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const DayCycleServiceScript = preload("res://scripts/world/day_cycle_service.gd")
const DistrictSelectScript = preload("res://scripts/ui/district_select.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const TOWER_RUNNER_SCENE := "res://scenes/tower/tower_runner.tscn"
const AUTO_SAVE_PATH := "user://slice3_t3_sleep_auto.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_mainline_hooks_full.gd --")
	test_day10_node4_hook_unlocks_ascetic_mountain()
	test_ascetic_remote_cost_and_daily_limit()
	test_day12_church_investigation_threshold()
	await test_city_main_story_hotspot_records_node_without_placeholder()
	await test_day7_sleep_hook_reaches_medium_tower_from_hub()
	await test_day14_final_tower_completion_advances_cycle()
	return {"passed": _passed, "failed": _failed}


func test_day10_node4_hook_unlocks_ascetic_mountain() -> void:
	var gs = _state()
	gs.day = 10
	gs.ap = 5
	var hook: Dictionary = DayCycleServiceScript.apply_day_hooks(gs)
	assert_true(bool(hook.get("triggered", false)), "Day 10 mainline hook triggers")
	assert_true(_completed_nodes(gs).has("node_4_promotion_98"), "Day 10 records concrete node_4 promotion id")
	var entry_check: Dictionary = DistrictSelectScript.can_enter_district("ascetic_mountain", gs)
	assert_true(bool(entry_check.get("ok", false)), "completed node_4 promotion unlocks ascetic_mountain selector entry")


func test_ascetic_remote_cost_and_daily_limit() -> void:
	var gs = _state()
	gs.sequence = 8
	gs.ap = 5
	var locked: Dictionary = DistrictSelectScript.can_enter_district("ascetic_mountain", gs)
	assert_true(not bool(locked.get("ok", true)), "ascetic_mountain remains locked before node_4")
	assert_eq(str(locked.get("reason", "")), "locked", "ascetic_mountain pre-node4 lock reason")

	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	gs.ap = 1
	var short: Dictionary = DistrictSelectScript.enter_district("ascetic_mountain", gs)
	assert_true(not bool(short.get("ok", true)), "ascetic_mountain rejects remote travel when AP is short")
	assert_eq(str(short.get("reason", "")), "ap_short", "ascetic_mountain AP short reason")
	assert_eq(int(gs.ap), 1, "AP-short ascetic entry does not spend AP")

	gs.ap = 5
	var first: Dictionary = DistrictSelectScript.enter_district("ascetic_mountain", gs)
	assert_true(bool(first.get("ok", false)), "first ascetic_mountain visit succeeds after node_4")
	assert_eq(int(first.get("ap_cost", -1)), 2, "ascetic_mountain reports 2 AP remote route fee")
	assert_eq(int(gs.ap), 3, "first ascetic_mountain visit spends exactly 2 AP")
	assert_true(bool(gs.get_meta("ascetic_visited_today", false)), "first ascetic visit records today's remote visit")

	var second: Dictionary = DistrictSelectScript.enter_district("ascetic_mountain", gs)
	assert_true(not bool(second.get("ok", true)), "second ascetic_mountain visit on same day is blocked")
	assert_eq(str(second.get("reason", "")), "daily_remote_limit", "same-day ascetic block uses daily_remote_limit")
	assert_eq(int(gs.ap), 3, "same-day ascetic block does not spend AP")

	SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH, 0.0)
	gs.ap = 5
	var next_day: Dictionary = DistrictSelectScript.enter_district("ascetic_mountain", gs)
	assert_true(bool(next_day.get("ok", false)), "ascetic_mountain can be visited again after sleep reset")
	assert_eq(int(gs.ap), 3, "next-day ascetic visit spends 2 AP again")


func test_day12_church_investigation_threshold() -> void:
	var low = _state()
	low.day = 12
	low.church_awareness = 24
	var low_hook: Dictionary = DayCycleServiceScript.apply_day_hooks(low)
	assert_true(bool(low_hook.get("triggered", false)), "Day 12 hook still records the story day")
	assert_true(_forced_tower(low).is_empty(), "Day 12 below church_awareness 25 does not force the investigation tower")

	var high = _state()
	high.day = 12
	high.church_awareness = 25
	var high_hook: Dictionary = DayCycleServiceScript.apply_day_hooks(high)
	var forced: Dictionary = _forced_tower(high)
	assert_true(bool(high_hook.get("triggered", false)), "Day 12 threshold hook triggers")
	assert_true(not forced.is_empty(), "Day 12 church_awareness 25 forces a tower hook")
	assert_eq(str(forced.get("node_id", "")), "node_5_church_investigation", "Day 12 forced tower carries node_5 id")
	assert_eq(Array(forced.get("district_ids", [])), ["sacred_seven"], "Day 12 forced tower targets sacred_seven")
	assert_eq(str(forced.get("tower_template", "")), "church_investigation", "Day 12 forced tower uses church investigation template")


func test_city_main_story_hotspot_records_node_without_placeholder() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_state().to_dict())
	GameState.day = 3
	GameState.ap = 12
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_on_city_hotspot_selected", {
		"id": "main_story_node2_probe",
		"label": "黑市初遇",
		"type": "main_story",
		"payload": {
			"node_id": "node_2_black_market",
			"title": "黑市初遇",
			"popup_text": "老李的灯牌第一次在夜里亮起。"
		},
	})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("MainlineDialog")
	assert_true(dialog != null and dialog.visible, "city main_story hotspot opens the mainline dialog")
	assert_true(_completed_nodes(GameState).has("node_2_black_market"), "city main_story hotspot records the concrete node")
	assert_true(_completed_nodes(GameState).has("node_2"), "city main_story hotspot records the generic node alias")
	if dialog != null:
		var text := str(dialog.dialog_text)
		assert_true(text.contains("黑市初遇"), "mainline hotspot dialog includes player-facing title")
		assert_true(text.find("node_2_black_market") < 0, "mainline hotspot dialog hides raw node id")
	var placeholder = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(placeholder == null or not placeholder.visible, "city main_story hotspot does not use the generic placeholder")
	hub.queue_free()
	GameState.from_dict(previous)


func test_day7_sleep_hook_reaches_medium_tower_from_hub() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_t3_meta(GameState)
	GameState.from_dict(_state().to_dict())
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.ap = 12
	var sleep_result: Dictionary = SleepServiceScript.sleep_to_next_day(GameState, 1, AUTO_SAVE_PATH, 0.0)
	assert_true(bool(sleep_result.get("ok", false)), "sleep into Day 7 succeeds")
	assert_eq(int(GameState.day), 7, "sleep advances to Day 7")
	var forced: Dictionary = _forced_tower(GameState)
	assert_true(not forced.is_empty(), "Day 7 sleep hook stores a forced tower")
	assert_eq(str(forced.get("tower_size", "")), "medium", "Day 7 forced tower is a medium tower")
	assert_eq(Array(forced.get("district_ids", [])), ["steelworks", "misty_port"], "Day 7 forced tower targets steelworks or misty_port")

	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		_clear_t3_meta(GameState)
		return
	var door = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	if door is Button:
		door.pressed.emit()
		await Engine.get_main_loop().process_frame
	var selector = hub.get_node_or_null("DistrictSelect")
	assert_true(selector != null and selector.visible, "Hub front door opens selector after Day 7 hook")
	if selector != null:
		var steel = selector.find_child("DistrictRow_steelworks", true, false)
		assert_true(steel is Button and not steel.disabled, "Day 7 steelworks forced district row is visible and enterable")
		if steel is Button:
			assert_true(str(steel.text).contains("主线"), "Day 7 forced district row exposes a mainline marker")
			steel.pressed.emit()
			await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Day 7 forced district opens CityScene")
	if city != null:
		var tower_button = city.find_child("Hotspot_tower_entry_steelworks", true, false)
		assert_true(tower_button is Button, "Day 7 CityScene exposes steelworks tower hotspot")
		if tower_button is Button:
			assert_true(str(tower_button.text).contains("半月"), "Day 7 tower hotspot is visibly the halfmoon contact tower")
			_seed_active_contract(GameState)
			tower_button.pressed.emit()
			await Engine.get_main_loop().process_frame
	var runner = hub.get_node_or_null("TowerRunner")
	assert_true(runner != null and runner.visible, "Day 7 forced tower hotspot opens TowerRunner from Hub path")
	if runner != null and runner.has_method("get_tower"):
		var tower = runner.get_tower()
		assert_true(tower != null, "Day 7 TowerRunner has a tower instance")
		if tower != null:
			assert_eq(str(tower.size), "medium", "Day 7 Hub path opens the medium tower")
			assert_eq(str(tower.district), "steelworks", "Day 7 Hub path opens the steelworks tower")
			assert_eq(str(tower.theme_modifiers.get("mainline_node_id", "")), "node_3_halfmoon_contact", "Day 7 tower carries structured mainline node id")
	hub.queue_free()
	GameState.from_dict(previous)
	_clear_t3_meta(GameState)


func test_day14_final_tower_completion_advances_cycle() -> void:
	var gs = _state()
	gs.day = 14
	gs.cycle = 1
	gs.sequence = 8
	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	gs.ap = 12
	var hook: Dictionary = DayCycleServiceScript.apply_day_hooks(gs)
	var forced: Dictionary = _forced_tower(gs)
	assert_true(bool(hook.get("triggered", false)), "Day 14 final hook triggers")
	assert_true(not forced.is_empty(), "Day 14 stores a final forced tower")
	assert_eq(str(forced.get("tower_size", "")), "large", "Day 14 forced tower is a large tower")
	assert_true(bool(forced.get("cycle_end_on_complete", false)), "Day 14 forced tower requests cycle end on completion")

	var runner = await _runner()
	if runner == null:
		return
	var tower = _single_event_tower()
	tower.size = "large"
	tower.district = "ascetic_mountain"
	tower.theme_modifiers["mainline_node_id"] = "node_6_final_tower"
	tower.theme_modifiers["cycle_end_on_complete"] = true
	var opened: Dictionary = runner.open(tower, gs)
	assert_true(bool(opened.get("ok", false)), "Day 14 final tower opens with enough AP")
	runner.enter_current_floor()
	runner.choose_event_option(0)
	assert_eq(str(tower.resolution), "cleared", "Day 14 final tower clears")
	assert_eq(int(gs.cycle), 2, "Day 14 final tower completion increments cycle")
	assert_eq(int(gs.day), 1, "Day 14 final tower completion resets to Day 1")
	assert_true(str(gs.get_meta("cycle_end_summary", "")) != "", "Day 14 final tower writes AI GM summary placeholder")
	_free_runner(runner)


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	_clear_t3_meta(gs)
	return gs


func _seed_active_contract(state) -> void:
	if state == null:
		return
	var rules: Array[String] = []
	for rule in state.learned_rules:
		rules.append(str(rule))
		if rules.size() >= 3:
			break
	if rules.size() < 3:
		rules = ["rule_a", "rule_b", "rule_c"]
	state.active_contract.clear()
	for rule in rules:
		state.active_contract.append(str(rule))


func _completed_nodes(gs) -> Array:
	var raw: Variant = gs.daodian.get("completed_main_story_nodes", [])
	return raw if raw is Array else []


func _forced_tower(gs) -> Dictionary:
	if gs != null and gs.has_method("get_meta"):
		var value: Variant = gs.get_meta("mainline_forced_tower", {})
		if value is Dictionary:
			return value.duplicate(true)
	return {}


func _clear_t3_meta(gs) -> void:
	if gs == null:
		return
	for key in [
		"mainline_forced_tower",
		"mainline_popup_pending",
		"mainline_popup_text",
		"mainline_popup_title",
		"mainline_day",
		"ascetic_visited_today",
		"cycle_end_ready",
		"cycle_final_tower",
	]:
		if gs.has_method("remove_meta") and gs.has_meta(key):
			gs.remove_meta(key)


func _hub():
	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var instance = scene.instantiate()
	Engine.get_main_loop().root.add_child(instance)
	await Engine.get_main_loop().process_frame
	return instance


func _runner():
	var scene = load(TOWER_RUNNER_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower_runner scene loads")
		return null
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	return runner


func _free_runner(runner) -> void:
	if runner != null:
		runner.queue_free()


func _single_event_tower():
	var tower = TowerScript.new()
	tower.tower_id = "slice3_t3_final"
	tower.tower_name = "Slice 3 T3 Final"
	tower.size = "small"
	tower.district = "ascetic_mountain"
	var floor = FloorScript.new()
	floor.floor_index = 0
	floor.event_type = "event"
	floor.event_data = {
		"title": "Final Placeholder",
		"choices": [
			{"id": "clear", "text": "Clear", "outcome": {}},
		],
	}
	tower.floors.append(floor)
	tower.floor_count = 1
	return tower


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
