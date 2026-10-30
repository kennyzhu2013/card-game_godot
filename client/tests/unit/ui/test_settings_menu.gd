extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const SaveStoreScript = preload("res://scripts/state/save_store.gd")

const SCRIPT_PATH := "res://scripts/ui/settings_menu.gd"
const SCENE_PATH := "res://scenes/ui/settings_menu.tscn"
const SAVE_BASE_PATH := "user://settings_menu_unit_saves"
const SETTINGS_PATH := "user://settings_menu_unit_settings.cfg"

var _passed := 0
var _failed := 0
var _unique_save_counter := 0


func run() -> Dictionary:
	print("\n-- test_settings_menu.gd --")
	test_script_and_scene_load()
	test_user_settings_cfg_roundtrip()
	test_slot_display_text_includes_save_metadata()
	await test_open_pauses_and_resume_unpauses()
	test_menu_save_and_load_slot_restores_state()
	await test_settings_s_key_opens_save_slot_picker()
	await test_save_slot_picker_writes_after_confirm()
	await test_ai_gm_settings_entry_opens_dialog()
	return {"passed": _passed, "failed": _failed}


func test_script_and_scene_load() -> void:
	var script = load(SCRIPT_PATH)
	assert_true(script != null and script.can_instantiate(), "settings menu script loads")
	var scene = load(SCENE_PATH)
	assert_true(scene != null and scene.can_instantiate(), "settings menu scene loads")


func test_user_settings_cfg_roundtrip() -> void:
	var script = _script()
	if script == null:
		return
	var ok: bool = script.save_user_settings({
		"bgm_volume": 0.25,
		"sfx_volume": 0.75,
		"language": "en",
	}, SETTINGS_PATH)
	assert_true(ok, "settings menu saves user_settings.cfg")
	var loaded: Dictionary = script.load_user_settings(SETTINGS_PATH)
	assert_eq(float(loaded.get("bgm_volume", -1.0)), 0.25, "BGM volume roundtrip")
	assert_eq(float(loaded.get("sfx_volume", -1.0)), 0.75, "SFX volume roundtrip")
	assert_eq(str(loaded.get("language", "")), "en", "language roundtrip")


func test_slot_display_text_includes_save_metadata() -> void:
	var script = _script()
	if script == null:
		return
	var text: String = script.slot_display_text("save_1", {
		"timestamp": 1770000000,
		"saved_at_display": "2026-05-27 10:00",
		"summary": {
			"cycle": 2,
			"sequence": 8,
			"day": 6,
			"location": "mist_harbor",
		},
	})
	assert_true(text.contains("save_1"), "slot label includes slot id")
	assert_true(text.contains("Cycle 2"), "slot label includes cycle")
	assert_true(text.contains("Seq 8"), "slot label includes sequence")
	assert_true(text.contains("Day 6"), "slot label includes day")
	assert_true(text.contains("mist_harbor"), "slot label includes location")


func test_open_pauses_and_resume_unpauses() -> void:
	var scene = load(SCENE_PATH)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "settings menu scene loads for pause test")
		return
	var menu = scene.instantiate()
	Engine.get_main_loop().root.add_child(menu)
	await Engine.get_main_loop().process_frame
	Engine.get_main_loop().paused = false
	menu.open(_state(), SAVE_BASE_PATH, SETTINGS_PATH)
	assert_true(Engine.get_main_loop().paused, "opening settings menu pauses tree")
	assert_true(menu.visible, "opening settings menu shows panel")
	menu.resume_game()
	assert_true(not Engine.get_main_loop().paused, "resume_game unpauses tree")
	assert_true(not menu.visible, "resume_game hides panel")
	menu.queue_free()


func test_menu_save_and_load_slot_restores_state() -> void:
	var script = _script()
	if script == null:
		return
	var menu = script.new()
	var gs = _state()
	gs.day = 8
	gs.sequence = 7
	gs.current_district = "shadow_alley"
	menu.open(gs, SAVE_BASE_PATH, SETTINGS_PATH)
	assert_true(menu.save_to_slot("save_2"), "settings menu saves selected slot")
	gs.day = 1
	gs.sequence = 9
	gs.current_district = ""
	assert_true(menu.load_from_slot("save_2"), "settings menu loads selected slot")
	assert_eq(gs.day, 8, "settings load restores day")
	assert_eq(gs.sequence, 7, "settings load restores sequence")
	assert_eq(gs.current_district, "shadow_alley", "settings load restores district")
	menu.resume_game()


func test_settings_s_key_opens_save_slot_picker() -> void:
	var script = _script()
	if script == null:
		return
	var base_path := _unique_save_base_path()
	var menu = script.new()
	Engine.get_main_loop().root.add_child(menu)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	gs.day = 4
	gs.sequence = 8
	menu.open(gs, base_path, SETTINGS_PATH)
	var tabs = menu.find_child("SettingsTabs", true, false)
	if tabs != null and tabs.get_tab_count() > 2:
		tabs.current_tab = 2
	if menu.has_method("_input"):
		menu.call("_input", _make_s_key_event())
	else:
		assert_true(false, "settings menu handles key input")
	var picker = menu.find_child("SaveSlotPicker", true, false)
	assert_true(picker != null and picker.is_visible_in_tree(), "S key opens visible save slot picker")
	if tabs != null:
		assert_eq(tabs.current_tab, 0, "S key switches to the save slot tab")
	for slot in SaveStoreScript.MANUAL_SLOTS:
		var button = menu.find_child(slot, true, false)
		assert_true(button != null, "%s overwrite button exists" % slot)
		assert_true(not FileAccess.file_exists(SaveStoreScript.slot_path(slot, base_path)), "S key does not write %s before confirm" % slot)
	menu.resume_game()
	menu.queue_free()


func test_save_slot_picker_writes_after_confirm() -> void:
	var script = _script()
	if script == null:
		return
	var base_path := _unique_save_base_path()
	var menu = script.new()
	Engine.get_main_loop().root.add_child(menu)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	gs.day = 12
	gs.current_district = "mist_harbor"
	menu.open(gs, base_path, SETTINGS_PATH)
	menu.call("_input", _make_s_key_event())
	var save_2 = menu.find_child("save_2", true, false)
	assert_true(save_2 != null, "save_2 overwrite button exists after S picker opens")
	if save_2 != null:
		save_2.pressed.emit()
	var path := SaveStoreScript.slot_path("save_2", base_path)
	assert_true(FileAccess.file_exists(path), "save_2 file is written only after overwrite confirm")
	var payload := SaveStoreScript.load("save_2", base_path)
	var summary: Dictionary = payload.get("summary", {})
	assert_eq(int(summary.get("day", 0)), 12, "save_2 summary stores current day after confirm")
	assert_eq(str(summary.get("location", "")), "mist_harbor", "save_2 summary stores current location after confirm")
	menu.resume_game()
	menu.queue_free()


func test_ai_gm_settings_entry_opens_dialog() -> void:
	var scene = load(SCENE_PATH)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "settings menu scene loads for AI GM entry test")
		return
	var menu = scene.instantiate()
	Engine.get_main_loop().root.add_child(menu)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	menu.open(gs, _unique_save_base_path(), SETTINGS_PATH)
	var button = menu.find_child("AIGMSettingsButton", true, false)
	assert_true(button != null and button is Button, "settings menu exposes AI GM settings button")
	if button != null:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = menu.find_child("AIGMSettingsDialog", true, false)
	assert_true(dialog != null, "settings menu mounts AI GM settings dialog")
	assert_true(dialog != null and dialog.visible, "settings menu opens visible AI GM settings dialog")
	if dialog != null:
		assert_true(dialog.find_child("OfflineToggle", true, false) != null, "AI GM dialog exposes offline toggle from settings menu")
		assert_true(dialog.find_child("ProviderButton", true, false) != null, "AI GM dialog exposes provider picker from settings menu")
	menu.resume_game()
	menu.queue_free()


func _script():
	var script = load(SCRIPT_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "settings menu script loads")
		return null
	return script


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _make_s_key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_S
	event.physical_keycode = KEY_S
	event.pressed = true
	event.echo = false
	return event


func _unique_save_base_path() -> String:
	_unique_save_counter += 1
	return "user://settings_menu_unit_saves_%d_%d" % [Time.get_ticks_msec(), _unique_save_counter]


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
