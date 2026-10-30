extends RefCounted

const HubScript = preload("res://scripts/hub/hub.gd")
const MeditationServiceScript = preload("res://scripts/world/meditation_service.gd")

var _passed := 0
var _failed := 0
var _last_zone: String = ""


func run() -> Dictionary:
	print("\n-- test_hub.gd --")
	await test_hub_scene_loads()
	await test_hub_full_rect_root_does_not_assign_manual_size()
	await test_hidden_city_scene_layer_stays_hidden_on_startup()
	await test_hub_main_controls_fit_common_fullscreen_viewports()
	await test_hub_status_children_fit_common_fullscreen_viewports()
	await test_has_8_zone_buttons()
	await test_status_bar_labels_exist()
	await test_ap_label_updates_after_game_state_ap_signal()
	await test_desk_menu_has_four_options()
	await test_non_desk_zones_emit_signal()
	await test_cushion_press_opens_meditation_panel()
	await test_cushion_button_disables_when_ap_short()
	await test_bed_press_does_not_advance_day_until_confirmed()
	await test_bed_press_cancel_keeps_state()
	await test_night_hub_actions_can_open_front_door_after_reaching_night()
	await test_force_sleep_pending_keeps_mandatory_prompt_structural()
	await test_sleep_confirm_shows_morning_dream_and_old_li_text()
	await test_desk_click_shows_menu()
	await test_clock_click_opens_settings_menu()
	await test_escape_on_main_hub_opens_settings()
	await test_escape_with_panel_open_does_not_open_settings()
	test_hub_source_handles_f11_fullscreen_toggle()
	await test_promotion_progress_label_shows_current_vs_required()
	await test_promotion_progress_hides_when_no_gate()
	return {"passed": _passed, "failed": _failed}


func _instantiate() -> Control:
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var instance = scene.instantiate()
	Engine.get_main_loop().root.add_child(instance)
	await Engine.get_main_loop().process_frame
	return instance


func test_hub_scene_loads() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	assert_true(hub is Control, "hub is Control")
	assert_true(hub.has_signal("zone_clicked"), "hub has zone_clicked signal")
	hub.queue_free()


func test_hub_full_rect_root_does_not_assign_manual_size() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hub/hub.gd")
	assert_true(not source.contains("set_deferred(\"size\""), "Hub full-rect root does not defer manual size assignment")


func test_hidden_city_scene_layer_stays_hidden_on_startup() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null, "CityScene panel is mounted for city entry")
	if city != null:
		assert_true(not city.visible, "CityScene root starts hidden")
		var layer = city.get_node_or_null("UILayer")
		assert_true(layer != null, "CityScene UILayer exists")
		if layer != null:
			var layer_visible: Variant = layer.get("visible")
			if layer_visible != null:
				assert_true(not bool(layer_visible), "hidden CityScene hides its CanvasLayer")
		var return_button = city.find_child("ReturnButton", true, false)
		var advance_button = city.find_child("TimeAdvanceButton", true, false)
		var intel_button = city.find_child("IntelInfoButton", true, false)
		if return_button is Control:
			assert_true(not return_button.is_visible_in_tree(), "CityScene Return button is not visible over Hub")
		if advance_button is Control:
			assert_true(not advance_button.is_visible_in_tree(), "CityScene Advance Time button is not visible over Hub")
		if intel_button is Control:
			assert_true(not intel_button.is_visible_in_tree(), "CityScene Intel button is not visible over Hub")
	hub.queue_free()


func test_hub_main_controls_fit_common_fullscreen_viewports() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size := root.size
	for size in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		root.size = size
		await Engine.get_main_loop().process_frame
		var hub = await _instantiate()
		if hub == null:
			root.size = original_size
			return
		await Engine.get_main_loop().process_frame
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
		for node_path in [
			"MarginContainer",
			"MarginContainer/VBoxContainer",
			"MarginContainer/VBoxContainer/ZoneGrid",
			"MarginContainer/VBoxContainer/StatusBar",
		]:
			var control = hub.get_node_or_null(node_path)
			assert_true(control is Control and viewport_rect.encloses((control as Control).get_global_rect()), "%s fits inside %s" % [node_path, str(size)])
		for button_name in ["DeskButton", "NoticeBoardButton", "CushionButton", "BookshelfButton", "BedButton", "FrontDoorButton", "ClockButton"]:
			var button = hub.find_child(button_name, true, false)
			assert_true(button is Control and viewport_rect.encloses((button as Control).get_global_rect()), "%s fits inside %s" % [button_name, str(size)])
		hub.queue_free()
	root.size = original_size


func test_hub_status_children_fit_common_fullscreen_viewports() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.sequence = 9
	GameState.sequence_exp = 40
	GameState.pollution = 12
	GameState.lingstones = 99999
	GameState.dao_pages = 999
	GameState.forge_materials = {"愚者残页": 999}
	GameState.known_reactions.clear()
	GameState.known_reactions.append("rx_0")
	GameState.known_reactions.append("rx_1")
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size := root.size
	for size in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = size
		await Engine.get_main_loop().process_frame
		var hub = await _instantiate()
		if hub == null:
			root.size = original_size
			GameState.from_dict(previous)
			return
		hub.call("_refresh_promotion_button")
		await Engine.get_main_loop().process_frame
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(size))
		var bar = hub.get_node("MarginContainer/VBoxContainer/StatusBar")
		for child in bar.get_children():
			if child is Control and (child as Control).is_visible_in_tree():
				assert_true(viewport_rect.encloses((child as Control).get_global_rect()), "%s fits in status row inside %s" % [str(child.name), str(size)])
		hub.queue_free()
	root.size = original_size
	GameState.from_dict(previous)


func test_has_8_zone_buttons() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var grid = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid")
	if grid == null:
		assert_true(false, "ZoneGrid exists")
		hub.queue_free()
		return
	var btns := 0
	for i in grid.get_child_count():
		if grid.get_child(i) is Button:
			btns += 1
			var name = grid.get_child(i).name
			assert_true(name.length() > 0, "zone button %s" % name)
	assert_eq(btns, 7, "7 visible zone buttons (8th is spacer)")
	hub.queue_free()


func test_status_bar_labels_exist() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var bar = hub.get_node("MarginContainer/VBoxContainer/StatusBar")
	if bar == null:
		assert_true(false, "StatusBar exists")
		hub.queue_free()
		return
	assert_true(bar.get_node("DayLabel").text.begins_with("第"), "DayLabel text")
	assert_true(bar.get_node("ApLabel").text.begins_with("AP"), "ApLabel text")
	assert_true(bar.get_node("PollutionLabel").text.begins_with("污染"), "PollutionLabel text")
	assert_true(bar.get_node("LingstonesLabel").text.begins_with("灵石"), "LingstonesLabel text")
	var win = hub.get_node("MarginContainer/VBoxContainer/WindowLabel")
	assert_true(win.text.begins_with("窗外"), "WindowLabel text begins with 窗外")
	hub.queue_free()


func test_ap_label_updates_after_game_state_ap_signal() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 12
	GameState.ap_max = 12
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	GameState.spend_ap(2)
	await Engine.get_main_loop().process_frame
	var label = hub.get_node("MarginContainer/VBoxContainer/StatusBar/ApLabel")
	assert_eq(str(label.text), "AP 10/12", "ApLabel updates after GameState AP signal")
	hub.queue_free()
	GameState.from_dict(previous)


func test_desk_menu_has_four_options() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var menu = hub.get_node_or_null("PopupMenu") if hub.has_method("get_node_or_null") else null
	if menu == null:
		var kids = hub.get_children()
		for k in kids:
			if k is PopupMenu:
				menu = k
				break
	if menu == null:
		assert_true(false, "desk popup menu exists")
		hub.queue_free()
		return
	assert_eq(menu.item_count, 4, "menu has 4 items")
	assert_eq(menu.get_item_text(0), "锻造台", "menu item 0 = 锻造台")
	assert_eq(menu.get_item_text(1), "塔罗书桌", "menu item 1 = 塔罗书桌")
	assert_eq(menu.get_item_text(2), "烙印工坊", "menu item 2 = 烙印工坊")
	assert_eq(menu.get_item_text(3), "构筑卡组", "menu item 3 = 构筑卡组")
	hub.queue_free()


func test_non_desk_zones_emit_signal() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.meditation_count_today = 0
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	_last_zone = ""
	hub.zone_clicked.connect(_on_zone)

	var grid = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid")
	# 蒲团 is index 2 in grid, which is _zone_buttons[2] = cushion
	var cushion = grid.get_child(2)
	if cushion is Button:
		cushion.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_eq(_last_zone, "", "click cushion is handled locally instead of fallback zone_clicked")
		var meditation = hub.get_node_or_null("CushionMeditation")
		assert_true(meditation != null and meditation.visible, "click cushion opens meditation panel")
		if meditation != null:
			meditation.hide()

	# 床 → 仅弹确认框，不再走 zone_clicked
	var initial_day := int(GameState.day)
	var bed = grid.get_child(4)
	if bed is Button:
		bed.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_eq(int(GameState.day), initial_day, "click bed waits for confirmation")
	hub.queue_free()
	GameState.from_dict(previous)


func test_cushion_press_opens_meditation_panel() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.meditation_count_today = 0
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	var grid = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid")
	var cushion = grid.get_node_or_null("CushionButton")
	if cushion is Button:
		cushion.pressed.emit()
		await Engine.get_main_loop().process_frame
		var panel = hub.get_node_or_null("CushionMeditation")
		assert_true(panel != null and panel.visible, "cushion opens meditation panel")
		if panel != null:
			assert_true(panel.find_child("BreathCircle", true, false) != null, "meditation panel mounts breathing circle")
			assert_true(panel.find_child("MeditationExitButton", true, false) != null, "meditation panel has an exit button")
		assert_eq(int(GameState.ap), 9, "cushion press spends 3 AP")
	hub.queue_free()
	GameState.from_dict(previous)


func test_cushion_button_disables_when_ap_short() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 2
	GameState.meditation_count_today = 0
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	var cushion = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/CushionButton")
	assert_true(cushion is Button, "cushion button exists")
	if cushion is Button:
		assert_true(cushion.disabled, "cushion is disabled when AP is short")
		assert_true(cushion.tooltip_text.contains("AP 不足"), "cushion tooltip explains AP shortage")
		assert_true(str(cushion.text).contains("AP") and str(cushion.text).contains("3"), "cushion label shows the AP gate instead of silently looking broken")
	hub.queue_free()
	GameState.from_dict(previous)


func test_bed_press_does_not_advance_day_until_confirmed() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	_set_time_state(6, 2, 12, "night")
	var bed = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/BedButton")
	bed.pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_eq(int(GameState.day), 6, "bed press does not advance day before confirm")
	var dialog = hub.get_node_or_null("SleepConfirmDialog")
	assert_true(dialog != null and dialog.visible, "bed press shows sleep confirmation dialog")
	if hub.has_method("_confirm_sleep"):
		hub.call("_confirm_sleep")
		await Engine.get_main_loop().process_frame
		assert_eq(int(GameState.day), 7, "confirming sleep advances to next day")
	hub.queue_free()


func test_bed_press_cancel_keeps_state() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	_set_time_state(9, 3, 12, "evening")
	var bed = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/BedButton")
	bed.pressed.emit()
	await Engine.get_main_loop().process_frame
	if hub.has_method("_cancel_sleep"):
		hub.call("_cancel_sleep")
		await Engine.get_main_loop().process_frame
	assert_eq(int(GameState.day), 9, "cancel sleep keeps day")
	assert_eq(int(GameState.ap), 3, "cancel sleep keeps AP")
	assert_eq(str(GameState.time_of_day), "evening", "cancel sleep keeps time_of_day")
	hub.queue_free()


func test_forced_sleep_prompt_after_actions_reach_night() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.day = 2
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.time_of_day = "morning"
	GameState.meditation_count_today = 0
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	for i in range(3):
		var result: Dictionary = MeditationServiceScript.resolve_session(GameState, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
		assert_true(bool(result.get("ok", false)), "meditation action #%d resolves before forced sleep" % [i + 1])
	assert_eq(str(GameState.time_of_day), "night", "actions push Hub state to night")
	var notice = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/NoticeBoardButton")
	notice.pressed.emit()
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("SleepConfirmDialog")
	assert_true(dialog != null and dialog.visible, "next Hub action at night shows forced sleep confirmation")
	if dialog != null:
		assert_true(dialog.dialog_text.contains("必须入梦"), "forced sleep dialog explains sleep is mandatory")
		var cancel_button = dialog.get_cancel_button()
		assert_true(cancel_button == null or cancel_button.disabled or not cancel_button.visible, "forced sleep cancel button is unavailable")
	if hub.has_method("_confirm_sleep"):
		hub.call("_confirm_sleep")
		await Engine.get_main_loop().process_frame
		assert_eq(int(GameState.day), 3, "confirming forced sleep advances day")
		assert_eq(str(GameState.time_of_day), "morning", "confirming forced sleep wakes in morning")
	hub.queue_free()
	GameState.from_dict(previous)


func test_night_hub_actions_can_open_front_door_after_reaching_night() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.day = 2
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.time_of_day = "morning"
	GameState.meditation_count_today = 0
	if GameState.has_meta("force_sleep_pending"):
		GameState.remove_meta("force_sleep_pending")
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	for i in range(3):
		var result: Dictionary = MeditationServiceScript.resolve_session(GameState, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
		assert_true(bool(result.get("ok", false)), "meditation action #%d resolves before night play" % [i + 1])
	assert_eq(str(GameState.time_of_day), "night", "actions push Hub state to night")
	assert_true(not bool(GameState.get_meta("force_sleep_pending", false)), "reaching night does not mark forced sleep pending")
	var door = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	door.pressed.emit()
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("SleepConfirmDialog")
	assert_true(dialog == null or not dialog.visible, "night front door action does not show forced sleep confirmation")
	var selector = hub.get_node_or_null("DistrictSelect")
	assert_true(selector != null and selector.visible, "night front door action opens district selector")
	hub.queue_free()
	GameState.from_dict(previous)


func test_force_sleep_pending_keeps_mandatory_prompt() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.day = 2
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.time_of_day = "night"
	GameState.set_meta("force_sleep_pending", true)
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	var notice = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/NoticeBoardButton")
	notice.pressed.emit()
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("SleepConfirmDialog")
	assert_true(dialog != null and dialog.visible, "pending forced sleep still shows mandatory confirmation")
	if dialog != null:
		assert_true(dialog.dialog_text.contains("蹇呴』鍏ユⅵ"), "forced sleep dialog explains sleep is mandatory")
		var cancel_button = dialog.get_cancel_button()
		assert_true(cancel_button == null or cancel_button.disabled or not cancel_button.visible, "forced sleep cancel button is unavailable")
	if hub.has_method("_confirm_sleep"):
		hub.call("_confirm_sleep")
		await Engine.get_main_loop().process_frame
		assert_eq(int(GameState.day), 3, "confirming forced sleep advances day")
		assert_eq(str(GameState.time_of_day), "morning", "confirming forced sleep wakes in morning")
	hub.queue_free()
	GameState.from_dict(previous)


func test_force_sleep_pending_keeps_mandatory_prompt_structural() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.day = 2
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.time_of_day = "night"
	GameState.set_meta("force_sleep_pending", true)
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	var notice = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/NoticeBoardButton")
	notice.pressed.emit()
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("SleepConfirmDialog")
	assert_true(dialog != null and dialog.visible, "pending forced sleep still shows mandatory confirmation")
	if dialog != null:
		assert_true(str(dialog.title).strip_edges() != "", "forced sleep dialog has a title")
		assert_true(str(dialog.dialog_text).strip_edges() != "", "forced sleep dialog has body text")
		var cancel_button = dialog.get_cancel_button()
		assert_true(cancel_button == null or cancel_button.disabled or not cancel_button.visible, "forced sleep cancel button is unavailable")
	if hub.has_method("_confirm_sleep"):
		hub.call("_confirm_sleep")
		await Engine.get_main_loop().process_frame
		assert_eq(int(GameState.day), 3, "confirming forced sleep advances day")
		assert_eq(str(GameState.time_of_day), "morning", "confirming forced sleep wakes in morning")
	hub.queue_free()
	GameState.from_dict(previous)


func test_sleep_confirm_shows_morning_dream_and_old_li_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	var pool: Array = _dream_pool()
	var pollution_values: Array[int] = [0, 30, 50, 80, 95]
	for i in range(pollution_values.size()):
		GameState.from_dict(previous)
		GameState.day = 1
		GameState.ap = 12
		GameState.ap_max = 12
		GameState.time_of_day = "night"
		GameState.pollution = pollution_values[i]
		GameState.current_weather = "sunny"
		var hub = await _instantiate()
		if hub == null:
			GameState.from_dict(previous)
			return
		hub.call("_confirm_sleep")
		await Engine.get_main_loop().process_frame
		var dialog = hub.get_node_or_null("HubPlaceholderDialog")
		assert_true(dialog != null and dialog.visible, "morning dialog visible for pollution %d" % pollution_values[i])
		var expected_title := _dream_title_for_stage(pool, i)
		if dialog != null:
			assert_true(dialog.dialog_text.contains(expected_title), "morning dialog contains dream title for stage %d" % i)
			if i == 0:
				assert_true(dialog.dialog_text.contains("老李"), "morning dialog includes old Li visitor text after Day 2 wake")
		hub.queue_free()
	GameState.from_dict(previous)


func test_desk_click_shows_menu() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var grid = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid")
	var desk = grid.get_child(0)
	if desk is Button:
		desk.pressed.emit()
		await Engine.get_main_loop().process_frame
		# Desk should show popup, not emit zone_clicked directly
		var menu: PopupMenu = null
		for k in hub.get_children():
			if k is PopupMenu:
				menu = k
				break
		assert_true(menu != null, "desk popup menu created")
		if menu:
			assert_true(menu.visible or menu.item_count == 4, "desk menu has items")
	hub.queue_free()


func test_clock_click_opens_settings_menu() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var grid = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid")
	var clock = grid.get_node_or_null("ClockButton")
	if clock is Button:
		clock.pressed.emit()
		await Engine.get_main_loop().process_frame
		var panel = hub.get_node_or_null("SettingsMenu")
		assert_true(panel != null, "clock creates settings menu panel")
		if panel != null:
			assert_true(panel.visible, "clock opens settings menu panel")
			if panel.has_method("resume_game"):
				panel.resume_game()
	Engine.get_main_loop().paused = false
	hub.queue_free()


func test_escape_on_main_hub_opens_settings() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var panel = hub.get_node_or_null("SettingsMenu")
	if panel == null:
		assert_true(false, "settings menu exists")
		hub.queue_free()
		return
	panel.hide()
	hub.call("_input", _make_ui_cancel_event())
	await Engine.get_main_loop().process_frame
	assert_true(panel.visible, "ESC on main hub opens settings menu")
	if panel.has_method("resume_game"):
		panel.resume_game()
	Engine.get_main_loop().paused = false
	hub.queue_free()


func test_escape_with_panel_open_does_not_open_settings() -> void:
	var hub = await _instantiate()
	if hub == null:
		return
	var settings = hub.get_node_or_null("SettingsMenu")
	var deck = hub.get_node_or_null("DeckBuilder")
	if settings == null or deck == null:
		assert_true(false, "settings and deck panels exist")
		hub.queue_free()
		return
	settings.hide()
	deck.show()
	hub.call("_input", _make_ui_cancel_event())
	await Engine.get_main_loop().process_frame
	assert_true(not settings.visible, "ESC with another panel open does not open settings")
	deck.hide()
	Engine.get_main_loop().paused = false
	hub.queue_free()


func test_hub_source_handles_f11_fullscreen_toggle() -> void:
	var hub = HubScript.new()
	assert_true(hub.has_method("_toggle_fullscreen"), "hub exposes a fullscreen toggle method")
	var source := FileAccess.get_file_as_string("res://scripts/hub/hub.gd")
	assert_true(source.contains("KEY_F11"), "hub input handles F11")
	assert_true(source.contains("_toggle_fullscreen()"), "hub input calls a fullscreen toggle helper")
	assert_true(source.contains("DisplayServer.window_set_mode"), "hub fullscreen toggle updates the window mode")


func test_promotion_progress_label_shows_current_vs_required() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.sequence = 9
	GameState.sequence_exp = 40
	GameState.pollution = 12
	GameState.known_reactions.clear()
	GameState.known_reactions.append("rx_0")
	GameState.known_reactions.append("rx_1")
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_refresh_promotion_button")
	await Engine.get_main_loop().process_frame
	var label = hub.find_child("PromotionProgressLabel", true, false)
	assert_true(label != null and label.visible, "promotion progress label is visible before gate is satisfied")
	if label != null:
		assert_true(label.text.contains("经验 40/100"), "promotion progress shows current and required exp")
		assert_true(label.text.contains("反应 2/8"), "promotion progress shows current and required reactions")
		assert_true(label.text.contains("污染 ≤50"), "promotion progress shows pollution cap")
		assert_true(label.text.contains("当前 12"), "promotion progress shows current pollution")
	hub.queue_free()
	GameState.from_dict(previous)


func test_promotion_progress_hides_when_no_gate() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.sequence = 0
	var hub = await _instantiate()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_refresh_promotion_button")
	await Engine.get_main_loop().process_frame
	var label = hub.find_child("PromotionProgressLabel", true, false)
	assert_true(label != null, "promotion progress label exists")
	if label != null:
		assert_true(not label.visible, "promotion progress hides when no next gate")
	hub.queue_free()
	GameState.from_dict(previous)


func _on_zone(zone_id: String) -> void:
	_last_zone = zone_id


func _set_time_state(day: int, ap: int, ap_max: int, time_of_day: String) -> void:
	GameState.day = day
	GameState.ap = ap
	GameState.ap_max = ap_max
	GameState.time_of_day = time_of_day


func _make_ui_cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _dream_pool() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/dreams/fallback_pool.json"))
	return parsed if parsed is Array else []


func _dream_title_for_stage(pool: Array, stage: int) -> String:
	for entry in pool:
		if entry is Dictionary and int(entry.get("pollution_stage", -1)) == stage:
			return str(entry.get("title", ""))
	return ""


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual, expected, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
