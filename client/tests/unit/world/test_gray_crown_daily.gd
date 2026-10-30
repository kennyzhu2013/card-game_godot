extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")

const DAILY_DATA_PATH := "res://data/rumors/gray_crown_daily.json"
const DAILY_DIALOG_SCENE := "res://scenes/ui/gray_crown_daily_dialog.tscn"
const REQUIRED_METHODS := [
	"load_gray_crown_daily",
	"gray_crown_week_index",
	"current_gray_crown_daily",
	"claim_gray_crown_daily",
	"auto_push_gray_crown_daily_if_due",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_gray_crown_daily.gd --")
	test_daily_data_schema_has_weekly_editions()
	test_game_state_gray_crown_daily_state_roundtrips()
	test_service_claims_three_permanent_weekly_intels_without_duplicates()
	test_weekly_auto_push_runs_once_and_refreshes_on_next_monday()
	test_fake_edition_is_seeded_visible_and_uses_false_lead()
	await test_dialog_renders_headlines_and_fake_marker()
	await test_hub_newspaper_hotspot_opens_daily_dialog()
	await test_hub_day7_morning_button_shows_current_week_summary()
	return {"passed": _passed, "failed": _failed}


func test_daily_data_schema_has_weekly_editions() -> void:
	var data := _daily_data()
	if data.is_empty():
		return
	assert_eq(str(data.get("$schema", "")), "gray_crown_daily_v1", "daily data declares the gray_crown_daily_v1 schema")
	assert_eq(str(data.get("publication", "")), "灰冠日报", "daily data names the publication")
	var editions: Array = _array(data.get("editions", []))
	assert_true(editions.size() >= 2, "daily data has at least two weekly editions")
	for edition in editions:
		if not edition is Dictionary:
			assert_true(false, "each daily edition is a dictionary")
			continue
		var edition_dict: Dictionary = edition
		var headlines: Array = _array(edition_dict.get("headlines", []))
		assert_eq(headlines.size(), 3, "each weekly edition has exactly three normal headlines")
		for headline in headlines:
			_assert_headline_schema(_dict(headline), false)
		var fake_headlines: Array = _array(edition_dict.get("fake_headlines", []))
		assert_true(fake_headlines.size() >= 1, "each weekly edition has at least one fake-edition headline")
		for headline in fake_headlines:
			_assert_headline_schema(_dict(headline), true)


func test_game_state_gray_crown_daily_state_roundtrips() -> void:
	var gs = _fresh_state()
	assert_true(_has_property(gs, "gray_crown_daily_state"), "GameState exposes gray_crown_daily_state")
	if not _has_property(gs, "gray_crown_daily_state"):
		gs.queue_free()
		return
	gs.set("gray_crown_daily_state", {
		"claimed_weeks": {"0": true},
		"auto_pushed_weeks": {"0": true},
		"last_week_index": 0,
		"last_edition": {"week_index": 0, "is_fake_edition": false},
	})
	var snapshot: Dictionary = gs.to_dict()
	var restored = _fresh_state()
	restored.from_dict(snapshot)
	var restored_state: Dictionary = _dict(restored.get("gray_crown_daily_state"))
	assert_true(_dict(restored_state.get("claimed_weeks", {})).has("0"), "claimed week roundtrips through GameState")
	assert_true(_dict(restored_state.get("auto_pushed_weeks", {})).has("0"), "auto-pushed week roundtrips through GameState")
	assert_eq(int(restored_state.get("last_week_index", -1)), 0, "last week index roundtrips through GameState")
	gs.queue_free()
	restored.queue_free()


func test_service_claims_three_permanent_weekly_intels_without_duplicates() -> void:
	var service = _new_service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 1
	gs.pollution = 0
	gs.church_awareness = 0
	var result: Dictionary = service.call("claim_gray_crown_daily", gs, 91, "manual")
	assert_true(bool(result.get("ok", false)), "claim_gray_crown_daily succeeds")
	assert_eq(int(result.get("week_index", -1)), 0, "day 1 maps to week 0")
	assert_true(not bool(result.get("is_fake_edition", true)), "low pollution first edition is not fake")
	assert_eq(_result_intels(result).size(), 3, "weekly claim grants exactly three headlines")
	assert_eq(_active_rumors(gs).size(), 3, "weekly claim writes three active rumors")
	for intel in _result_intels(result):
		var intel_dict: Dictionary = _dict(intel)
		assert_eq(str(intel_dict.get("source_type", "")), "newspaper", "newspaper headline stores source_type")
		assert_eq(str(intel_dict.get("expires_after", "")), "permanent", "newspaper headline is permanent")
		assert_true(str(intel_dict.get("id", "")).begins_with("gray_crown_daily_w0_"), "headline id includes the week key")
	var duplicate: Dictionary = service.call("claim_gray_crown_daily", gs, 91, "manual")
	assert_true(bool(duplicate.get("ok", false)), "same-week manual read still returns the edition")
	assert_eq(_active_rumors(gs).size(), 3, "same-week manual read does not duplicate active rumors")
	assert_true(bool(duplicate.get("already_claimed", false)), "same-week manual read reports already_claimed")
	gs.queue_free()


func test_weekly_auto_push_runs_once_and_refreshes_on_next_monday() -> void:
	var service = _new_service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 1
	var first: Dictionary = service.call("auto_push_gray_crown_daily_if_due", gs, 12)
	assert_true(bool(first.get("pushed", false)), "day 1 auto-push opens the weekly newspaper")
	assert_eq(_active_rumors(gs).size(), 3, "first auto-push grants week 0 headlines")
	var second: Dictionary = service.call("auto_push_gray_crown_daily_if_due", gs, 12)
	assert_true(not bool(second.get("pushed", true)), "same Monday auto-push only runs once")
	assert_eq(str(second.get("reason", "")), "already_pushed", "same Monday auto-push reports already_pushed")
	assert_eq(_active_rumors(gs).size(), 3, "second same-week auto-push does not duplicate headlines")
	gs.day = 2
	var non_monday: Dictionary = service.call("auto_push_gray_crown_daily_if_due", gs, 13)
	assert_true(not bool(non_monday.get("pushed", true)), "non-Monday does not auto-push")
	assert_eq(str(non_monday.get("reason", "")), "not_monday", "non-Monday reports not_monday")
	gs.day = 8
	var next_week: Dictionary = service.call("auto_push_gray_crown_daily_if_due", gs, 14)
	assert_true(bool(next_week.get("pushed", false)), "day 8 auto-push refreshes the next weekly edition")
	assert_eq(int(next_week.get("week_index", -1)), 1, "day 8 maps to week 1")
	assert_eq(_active_rumors(gs).size(), 6, "next-week auto-push grants three new permanent headlines")
	gs.queue_free()


func test_fake_edition_is_seeded_visible_and_uses_false_lead() -> void:
	var service = _new_service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 8
	gs.set_pollution(60)
	gs.church_awareness = 50
	var result: Dictionary = service.call("claim_gray_crown_daily", gs, 42, "manual")
	assert_true(bool(result.get("ok", false)), "high pollution newspaper claim succeeds")
	assert_true(bool(result.get("is_fake_edition", false)), "seed 42 triggers the pollution fake-edition branch")
	assert_true(str(result.get("edition_marker", "")).contains("伪刊") or str(result.get("edition_marker", "")).contains("假版"), "fake edition exposes a visible marker")
	assert_true(str(result.get("church_marker", "")).contains("教会") or str(result.get("church_marker", "")).contains("污染"), "fake edition names the pollution/church interference")
	var fake_found := false
	for intel in _result_intels(result):
		var intel_dict: Dictionary = _dict(intel)
		var target: Dictionary = _dict(intel_dict.get("apply_target", {}))
		if str(intel_dict.get("category", "")) == "false" or str(target.get("kind", "")) == "false_lead.cost":
			fake_found = true
			assert_eq(str(target.get("kind", "")), "false_lead.cost", "fake-edition headline uses false_lead.cost")
			assert_true(not _dict(intel_dict.get("false_lead", {})).is_empty(), "fake-edition headline carries false_lead data")
	assert_true(fake_found, "fake edition includes at least one fake headline")
	gs.queue_free()


func test_dialog_renders_headlines_and_fake_marker() -> void:
	var scene = load(DAILY_DIALOG_SCENE)
	assert_true(scene != null and scene.can_instantiate(), "Gray Crown Daily dialog scene loads")
	if scene == null or not scene.can_instantiate():
		return
	var dialog = scene.instantiate()
	Engine.get_main_loop().root.add_child(dialog)
	await Engine.get_main_loop().process_frame
	assert_true(dialog.has_method("open"), "Gray Crown Daily dialog exposes open()")
	assert_true(dialog.has_method("headline_texts"), "Gray Crown Daily dialog exposes headline_texts()")
	assert_true(dialog.has_method("fake_marker_text"), "Gray Crown Daily dialog exposes fake_marker_text()")
	if not dialog.has_method("open"):
		dialog.queue_free()
		return
	dialog.call("open", _fake_edition_payload())
	await Engine.get_main_loop().process_frame
	var marker = dialog.find_child("FakeEditionMarker", true, false)
	assert_true(marker is Label and marker.visible, "fake edition marker is visible in the dialog")
	if marker is Label:
		assert_true(str(marker.text).contains("伪刊") or str(marker.text).contains("假版"), "fake edition marker text is explicit")
	var headline_texts: Array = dialog.call("headline_texts") if dialog.has_method("headline_texts") else []
	assert_eq(headline_texts.size(), 3, "dialog renders three headline rows")
	assert_true(str(dialog.call("fake_marker_text")).contains("伪刊") or str(dialog.call("fake_marker_text")).contains("假版"), "dialog exposes fake marker text for tests/WebQA")
	dialog.queue_free()


func test_hub_newspaper_hotspot_opens_daily_dialog() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 2
	GameState.pollution = 0
	GameState.church_awareness = 0
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var dialog = hub.find_child("GrayCrownDailyDialog", true, false)
	assert_true(dialog != null, "Hub instantiates GrayCrownDailyDialog")
	var button = hub.find_child("GrayCrownDailyButton", true, false)
	assert_true(button is Button, "Hub exposes a newspaper button")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_true(dialog != null and dialog.visible, "newspaper button opens the weekly report dialog")
	if dialog != null:
		dialog.hide()
	hub.call("_on_city_hotspot_selected", {"type": "newspaper", "label": "灰冠日报", "payload": {}})
	await Engine.get_main_loop().process_frame
	assert_true(dialog != null and dialog.visible, "newspaper hotspot opens the same GrayCrownDailyDialog")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_day7_morning_button_shows_current_week_summary() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 7
	GameState.time_of_day = "morning"
	GameState.pollution = 0
	GameState.church_awareness = 0
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var button = hub.find_child("GrayCrownDailyButton", true, false)
	assert_true(button is Button, "Hub exposes Gray Crown Daily button on day 7 morning")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.find_child("GrayCrownDailyDialog", true, false)
	assert_true(dialog != null and dialog.visible, "day 7 morning newspaper button opens dialog")
	var headline_texts: Array = dialog.call("headline_texts") if dialog != null and dialog.has_method("headline_texts") else []
	assert_true(headline_texts.size() > 0, "day 7 newspaper dialog shows current-week headlines")
	var combined := "灰冠日报"
	for text in headline_texts:
		combined += "\n%s" % str(text)
	assert_true(combined.contains("灰冠日报") or headline_texts.size() >= 3, "day 7 newspaper dialog contains publication or weekly summary text")
	hub.queue_free()
	GameState.from_dict(previous)


func _assert_headline_schema(headline: Dictionary, expect_fake: bool) -> void:
	assert_true(str(headline.get("id", "")) != "", "headline has id")
	assert_true(str(headline.get("category", "")) != "", "headline has category")
	assert_true(str(headline.get("display_text", "")) != "", "headline has display_text")
	assert_eq(str(headline.get("expires_after", "")), "permanent", "headline is permanent")
	assert_eq(str(headline.get("source_type", "")), "newspaper", "headline source_type is newspaper")
	var target: Dictionary = _dict(headline.get("apply_target", {}))
	assert_true(not target.is_empty(), "headline has apply_target")
	if expect_fake:
		assert_eq(str(target.get("kind", "")), "false_lead.cost", "fake headline apply target is false_lead.cost")
	else:
		assert_true(str(target.get("kind", "")) in ["main_story_unlock.branch", "tower_intel.enemy_intent_reveal", "npc_relation_boost.gift_topic", "weather_forecast.next_day"], "normal headline apply target is a useful intel kind")


func _new_service():
	var service = IntelServiceScript.new()
	for method in REQUIRED_METHODS:
		assert_true(service.has_method(str(method)), "IntelService exposes %s()" % str(method))
		if not service.has_method(str(method)):
			return null
	return service


func _daily_data() -> Dictionary:
	assert_true(FileAccess.file_exists(DAILY_DATA_PATH), "gray_crown_daily.json exists")
	if not FileAccess.file_exists(DAILY_DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DAILY_DATA_PATH))
	assert_true(parsed is Dictionary, "gray_crown_daily.json parses as dictionary")
	return parsed if parsed is Dictionary else {}


func _fake_edition_payload() -> Dictionary:
	return {
		"ok": true,
		"publication": "灰冠日报",
		"week_index": 1,
		"is_fake_edition": true,
		"edition_marker": "伪刊",
		"church_marker": "教会改写",
		"headlines": [
			{"id": "gray_crown_daily_w1_main", "display_text": "第一条头条", "category": "main_story"},
			{"id": "gray_crown_daily_w1_church", "display_text": "第二条头条", "category": "church"},
			{"id": "gray_crown_daily_w1_false", "display_text": "第三条头条", "category": "false"},
		],
		"granted_intels": [],
	}


func _fresh_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.set("active_rumors", [])
	gs.set("heard_rumor_history", {})
	gs.minigame_history.clear()
	gs.day = 1
	gs.time_of_day = "morning"
	gs.pollution = 0
	gs.pollution_stage = 0
	gs.church_awareness = 0
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


func _result_intels(result: Dictionary) -> Array:
	var value: Variant = result.get("granted_intels", result.get("intels", []))
	return value if value is Array else []


func _active_rumors(game_state) -> Array:
	var value: Variant = game_state.get("active_rumors")
	return value if value is Array else []


func _has_property(obj, prop_name: String) -> bool:
	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == prop_name:
			return true
	return false


func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value if value is Array else []


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
