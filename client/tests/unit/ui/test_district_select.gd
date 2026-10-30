extends RefCounted

const DistrictSelectScript = preload("res://scripts/ui/district_select.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_district_select.gd --")
	test_v35_selector_entries_have_no_legacy_event_payload()
	test_v35_selector_source_does_not_resolve_random_events()
	test_can_enter_uses_location_unlocks_and_remote_ap()
	await test_scene_emits_city_scene_request()
	return {"passed": _passed, "failed": _failed}


func test_v35_selector_entries_have_no_legacy_event_payload() -> void:
	var entries := DistrictSelectScript.selector_entries_for(_state())
	assert_eq(entries.size(), 6, "v3.5 selector has six district rows")
	for entry in entries:
		assert_true(entry is Dictionary, "selector row is structured dictionary")
		assert_true(entry.has("district_id"), "selector row has district_id")
		assert_true(entry.has("ap_to_enter"), "selector row has ap_to_enter")
		assert_true(not entry.has("events"), "selector row has no retired events[] payload")


func test_v35_selector_source_does_not_resolve_random_events() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/district_select.gd")
	assert_true(source.find("resolve_event") < 0, "district selector no longer resolves random events")
	assert_true(source.find("event_weights_for") < 0, "district selector no longer carries event weights")
	assert_true(source.find("TowerGenerator") < 0, "district selector no longer dispatches towers directly")
	assert_true(source.find("city_scene_requested") >= 0, "district selector requests city_scene instead")


func test_can_enter_uses_location_unlocks_and_remote_ap() -> void:
	var gs = _state()
	gs.sequence = 9
	gs.ap = 12
	var stone := DistrictSelectScript.can_enter_district("stone_tower", gs)
	assert_true(not bool(stone.get("ok", true)), "stone_tower locked at sequence 9")
	assert_eq(str(stone.get("reason", "")), "locked", "stone_tower lock reason")
	gs.sequence = 8
	var unlocked := DistrictSelectScript.can_enter_district("stone_tower", gs)
	assert_true(bool(unlocked.get("ok", false)), "stone_tower unlocks at sequence 8")

	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	gs.ap = 1
	var ascetic_short := DistrictSelectScript.can_enter_district("ascetic_mountain", gs)
	assert_true(not bool(ascetic_short.get("ok", true)), "ascetic_mountain checks remote AP")
	assert_eq(str(ascetic_short.get("reason", "")), "ap_short", "ascetic AP short reason")


func test_scene_emits_city_scene_request() -> void:
	var scene = load("res://scenes/ui/district_select.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "district selector scene loads")
		return
	var selector = scene.instantiate()
	Engine.get_main_loop().root.add_child(selector)
	await Engine.get_main_loop().process_frame
	var requested: Array[String] = []
	selector.city_scene_requested.connect(func(district_id: String) -> void:
		requested.append(district_id)
	)
	selector.open(_state())
	await Engine.get_main_loop().process_frame
	var row = selector.find_child("DistrictRow_shadow_alley", true, false)
	assert_true(row is Button, "shadow_alley row exists")
	if row is Button:
		row.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(requested, ["shadow_alley"], "pressing row emits city_scene_requested")
	selector.queue_free()


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
