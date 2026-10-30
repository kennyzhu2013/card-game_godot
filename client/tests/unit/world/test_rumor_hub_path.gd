extends RefCounted

const LOCATION_DIR := "res://data/locations"
const EXPECTED_DISTRICT_POOLS := {
	"shadow_alley": "shadow_alley_rumors",
	"steelworks": "steelworks_tabloid",
	"misty_port": "misty_port_rumors",
	"sacred_seven": "sacred_seven_rumors",
	"stone_tower": "stone_tower_streets",
	"ascetic_mountain": "ascetic_mountain_rumors",
}

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "visible rumor ai gm text"


func run() -> Dictionary:
	print("\n-- test_rumor_hub_path.gd --")
	test_all_six_districts_have_structured_rumor_hotspot()
	await test_hub_rumor_hotspot_grants_intel_without_placeholder()
	await test_hub_rumor_hotspot_displays_ai_gm_text()
	await test_rumor_hotspot_blocks_when_ap_short()
	await test_rumor_daily_limit_blocks_third_city_draw()
	return {"passed": _passed, "failed": _failed}


func test_all_six_districts_have_structured_rumor_hotspot() -> void:
	for district_id in EXPECTED_DISTRICT_POOLS.keys():
		var data := _location(district_id)
		var rumor := _rumor_hotspot(data)
		assert_true(not rumor.is_empty(), "%s exposes one R26 rumor hotspot" % district_id)
		if not rumor.is_empty():
			assert_eq(str(rumor.get("type", "")), "rumor", "%s rumor hotspot uses structured type" % district_id)
			assert_eq(int(rumor.get("ap_cost", -1)), 1, "%s rumor hotspot displays the live rumor AP cost" % district_id)
			var payload: Dictionary = rumor.get("payload", {}) if rumor.get("payload", {}) is Dictionary else {}
			assert_eq(str(payload.get("rumor_pool", "")), str(EXPECTED_DISTRICT_POOLS[district_id]), "%s rumor hotspot points to structured pool id" % district_id)


func test_hub_rumor_hotspot_grants_intel_without_placeholder() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var button = city.find_child("Hotspot_rumor_streettalker", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes shadow_alley rumor hotspot")
	var before_ap := int(GameState.ap)
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("RumorDialog")
	assert_true(dialog != null and dialog.visible, "rumor hotspot opens RumorDialog")
	if dialog != null:
		assert_true(_is_clean_player_text(str(dialog.dialog_text)), "RumorDialog shows Chinese intel text instead of raw ids")
	assert_eq(int(GameState.ap), before_ap - 1, "rumor listening spends 1 AP")
	var active: Variant = GameState.get("active_rumors")
	assert_true(active is Array and active.size() >= 1 and active.size() <= 3, "rumor hotspot grants 1-3 active rumors")
	var placeholder = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(placeholder == null or not placeholder.visible, "rumor hotspot no longer uses generic placeholder")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_rumor_hotspot_displays_ai_gm_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	assert_true(hub.has_method("set_ai_gm_service"), "Hub can receive an injected AI GM service for rumor feedback")
	var fake := FakeAIGMService.new()
	if hub.has_method("set_ai_gm_service"):
		hub.call("set_ai_gm_service", fake)
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var button = city.find_child("Hotspot_rumor_streettalker", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes shadow_alley rumor hotspot for AI GM feedback")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("RumorDialog")
	assert_true(fake.calls.size() >= 1, "rumor hotspot uses injected AI GM service for generated streettalker text")
	assert_true(dialog != null and dialog.visible, "rumor AI GM attempt opens RumorDialog")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("visible rumor ai gm text"), "RumorDialog displays generated AI GM text")
	hub.queue_free()
	GameState.from_dict(previous)


func test_rumor_hotspot_blocks_when_ap_short() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state()
	GameState.ap = 0
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var button = city.find_child("Hotspot_rumor_streettalker", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes shadow_alley rumor hotspot for AP gate")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("RumorDialog")
	assert_true(dialog != null and dialog.visible, "AP-short rumor attempt opens RumorDialog")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("AP"), "AP-short rumor dialog names the AP cost")
	assert_eq(_active_count(), 0, "AP-short rumor attempt grants no intel")
	assert_eq(int(GameState.ap), 0, "AP-short rumor attempt does not mutate AP")
	hub.queue_free()
	GameState.from_dict(previous)


func test_rumor_daily_limit_blocks_third_city_draw() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var hotspot := {"type": "rumor", "label": "街角说书人", "payload": {"rumor_pool": "shadow_alley_rumors"}}
	hub.call("_on_city_hotspot_selected", hotspot)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", hotspot)
	await Engine.get_main_loop().process_frame
	var before_third_count := _active_count()
	hub.call("_on_city_hotspot_selected", hotspot)
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("RumorDialog")
	assert_true(dialog != null and str(dialog.dialog_text).contains("今天") and _is_clean_player_text(str(dialog.dialog_text)), "third same-day rumor draw is visibly blocked in Chinese")
	assert_eq(_active_count(), before_third_count, "third same-day rumor draw does not grant more intel")
	hub.queue_free()
	GameState.from_dict(previous)


func _setup_global_state() -> void:
	GameState.day = 4
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.sequence = 9
	GameState.ap = 9
	GameState.church_awareness = 0
	GameState.set("active_rumors", [])
	GameState.set("heard_rumor_history", {})
	GameState.minigame_history.clear()


func _active_count() -> int:
	var active: Variant = GameState.get("active_rumors")
	return active.size() if active is Array else 0


func _location(district_id: String) -> Dictionary:
	var path := "%s/%s.json" % [LOCATION_DIR, district_id]
	if not FileAccess.file_exists(path):
		assert_true(false, "%s exists" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _rumor_hotspot(data: Dictionary) -> Dictionary:
	var hotspots: Variant = data.get("hotspots", [])
	if not hotspots is Array:
		return {}
	for hotspot in hotspots:
		if hotspot is Dictionary and str(hotspot.get("type", "")) == "rumor":
			return hotspot
	return {}


func _hub() -> Control:
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _is_clean_player_text(value: String) -> bool:
	if value.strip_edges() == "":
		return false
	for fragment in [
		"pool_id=",
		"daily_limit",
		"draws_today",
		"intel_",
		"no_intel_granted",
	]:
		if value.find(fragment) >= 0:
			return false
	return _has_cjk(value)


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


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
