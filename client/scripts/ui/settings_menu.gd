class_name SettingsMenu
extends Panel

const SaveStoreScript = preload("res://scripts/state/save_store.gd")
const AIGMSettingsScene = preload("res://scenes/ui/ai_gm_settings_dialog.tscn")

const DEFAULT_SETTINGS_PATH := "user://user_settings.cfg"
const LANGUAGES := ["zh_CN", "en"]

var _game_state = null
var _save_base_path: String = SaveStoreScript.SAVE_DIR
var _settings_path: String = DEFAULT_SETTINGS_PATH
var _tabs: TabContainer
var _slots_box: VBoxContainer
var _message_label: Label
var _bgm_slider: HSlider
var _sfx_slider: HSlider
var _language_button: OptionButton
var _load_confirm: ConfirmationDialog
var _ai_gm_settings_dialog: Control
var _pending_load_slot: String = ""
var _selected_save_slot: String = "save_1"
var _save_tab_index: int = 0
var _previous_tab_index: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()
	hide()


func open(game_state = null, save_base_path: String = SaveStoreScript.SAVE_DIR, settings_path: String = DEFAULT_SETTINGS_PATH) -> void:
	_ensure_ui()
	_game_state = game_state if game_state != null else GameState
	_save_base_path = save_base_path
	_settings_path = settings_path
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = true
	_apply_settings_to_controls(load_user_settings(_settings_path))
	_refresh_slots()
	show()


func resume_game() -> void:
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
	if _ai_gm_settings_dialog != null and is_instance_valid(_ai_gm_settings_dialog):
		if _ai_gm_settings_dialog.has_method("close_dialog"):
			_ai_gm_settings_dialog.call("close_dialog")
		else:
			_ai_gm_settings_dialog.hide()
	hide()


func save_to_slot(slot: String) -> bool:
	if _game_state == null:
		return false
	_selected_save_slot = slot if slot != "" else "save_1"
	var ok := SaveStoreScript.save(slot, _game_state, _save_base_path)
	_set_message("存档完成" if ok else "存档失败")
	_refresh_slots()
	return ok


func request_load_slot(slot: String) -> void:
	_selected_save_slot = slot if slot != "" else _selected_save_slot
	_pending_load_slot = slot
	_set_message("确认读档：%s" % slot)
	if _load_confirm != null and is_inside_tree():
		_load_confirm.dialog_text = "读档会覆盖当前进度：%s" % slot
		_load_confirm.popup_centered()


func confirm_load_selected() -> bool:
	if _pending_load_slot == "":
		return false
	var slot := _pending_load_slot
	_pending_load_slot = ""
	return load_from_slot(slot)


func load_from_slot(slot: String) -> bool:
	if _game_state == null:
		return false
	_selected_save_slot = slot if slot != "" else _selected_save_slot
	var payload := SaveStoreScript.load(slot, _save_base_path)
	var ok := SaveStoreScript.apply_payload(payload, _game_state)
	_set_message("读档完成" if ok else "读档失败")
	_refresh_slots()
	return ok


func auto_save_current() -> bool:
	if _game_state == null:
		return false
	var ok := SaveStoreScript.auto_save(_game_state, _save_base_path)
	_set_message("自动存档完成" if ok else "自动存档失败")
	_refresh_slots()
	return ok


func apply_current_settings() -> bool:
	var ok := save_user_settings(_collect_user_settings(), _settings_path)
	_set_message("设置已保存" if ok else "设置保存失败")
	return ok


func open_ai_gm_settings() -> void:
	_ensure_ui()
	if _game_state == null:
		_game_state = GameState
	if _ai_gm_settings_dialog == null or not is_instance_valid(_ai_gm_settings_dialog):
		_ai_gm_settings_dialog = AIGMSettingsScene.instantiate()
		_ai_gm_settings_dialog.name = "AIGMSettingsDialog"
		add_child(_ai_gm_settings_dialog)
	if _ai_gm_settings_dialog.has_method("open"):
		_ai_gm_settings_dialog.call("open", _game_state)
	else:
		_ai_gm_settings_dialog.show()
	_set_message("AI GM settings")


func return_to_title() -> void:
	auto_save_current()
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
		if FileAccess.file_exists("res://scenes/title/title.tscn"):
			get_tree().change_scene_to_file("res://scenes/title/title.tscn")
		else:
			hide()
			_set_message("标题场景未配置")


func quit_game() -> void:
	auto_save_current()
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false
		get_tree().quit()


static func default_user_settings() -> Dictionary:
	return {
		"bgm_volume": 0.7,
		"sfx_volume": 0.8,
		"language": "zh_CN",
		"keymap": "default",
	}


static func load_user_settings(path: String = DEFAULT_SETTINGS_PATH) -> Dictionary:
	var settings := default_user_settings()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return settings
	settings["bgm_volume"] = float(cfg.get_value("audio", "bgm_volume", settings["bgm_volume"]))
	settings["sfx_volume"] = float(cfg.get_value("audio", "sfx_volume", settings["sfx_volume"]))
	settings["language"] = str(cfg.get_value("ui", "language", settings["language"]))
	settings["keymap"] = str(cfg.get_value("input", "keymap", settings["keymap"]))
	return settings


static func save_user_settings(settings: Dictionary, path: String = DEFAULT_SETTINGS_PATH) -> bool:
	if not _ensure_parent_dir(path):
		return false
	var merged := default_user_settings()
	for key in settings:
		merged[key] = settings[key]
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "bgm_volume", clampf(float(merged["bgm_volume"]), 0.0, 1.0))
	cfg.set_value("audio", "sfx_volume", clampf(float(merged["sfx_volume"]), 0.0, 1.0))
	cfg.set_value("ui", "language", str(merged["language"]))
	cfg.set_value("input", "keymap", str(merged["keymap"]))
	return cfg.save(path) == OK


static func slot_display_text(slot: String, payload: Dictionary) -> String:
	if payload.is_empty():
		return "%s | Empty" % slot
	var summary: Dictionary = payload.get("summary", {})
	return "%s | %s | Cycle %d | Seq %d | Day %d | %s" % [
		slot,
		str(payload.get("saved_at_display", payload.get("timestamp", ""))),
		int(summary.get("cycle", 0)),
		int(summary.get("sequence", 0)),
		int(summary.get("day", 0)),
		str(summary.get("location", "hub")),
	]


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.06, 0.07, 0.96)
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	margin.name = "RootMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "RootBox"
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "钟"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var resume := Button.new()
	resume.text = "恢复"
	resume.pressed.connect(resume_game)
	header.add_child(resume)

	_tabs = TabContainer.new()
	_tabs.name = "SettingsTabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(_on_tab_changed)
	root.add_child(_tabs)
	_tabs.add_child(_build_save_tab())
	_tabs.add_child(_build_settings_tab())
	_tabs.add_child(_build_system_tab())

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	_load_confirm = ConfirmationDialog.new()
	_load_confirm.name = "LoadConfirm"
	_load_confirm.confirmed.connect(confirm_load_selected)
	add_child(_load_confirm)


func _ensure_ui() -> void:
	if _message_label != null:
		return
	_build_ui()


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func _build_save_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "存档"
	tab.add_theme_constant_override("separation", 8)
	_slots_box = VBoxContainer.new()
	_slots_box.name = "SaveSlotPicker"
	_slots_box.add_theme_constant_override("separation", 6)
	tab.add_child(_slots_box)
	var cancel_btn := Button.new()
	cancel_btn.name = "SaveSlotCancelButton"
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(_return_from_save_picker)
	tab.add_child(cancel_btn)
	return tab


func _build_settings_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "设置"
	tab.add_theme_constant_override("separation", 8)
	_bgm_slider = _make_slider_row(tab, "BGM")
	_sfx_slider = _make_slider_row(tab, "SFX")
	var key_label := Label.new()
	key_label.text = "按键：E 互动 / Esc 暂停 / Tab 道典 / S 存档"
	tab.add_child(key_label)
	var lang_row := HBoxContainer.new()
	lang_row.add_child(_label("语言"))
	_language_button = OptionButton.new()
	for lang in LANGUAGES:
		_language_button.add_item(lang)
	lang_row.add_child(_language_button)
	tab.add_child(lang_row)
	var apply := Button.new()
	apply.text = "应用设置"
	apply.pressed.connect(apply_current_settings)
	tab.add_child(apply)
	var ai_gm_button := Button.new()
	ai_gm_button.name = "AIGMSettingsButton"
	ai_gm_button.text = "AI GM"
	ai_gm_button.pressed.connect(open_ai_gm_settings)
	tab.add_child(ai_gm_button)
	return tab


func _build_system_tab() -> Control:
	var tab := VBoxContainer.new()
	tab.name = "系统"
	tab.add_theme_constant_override("separation", 8)
	var auto_btn := Button.new()
	auto_btn.text = "自动存档"
	auto_btn.pressed.connect(auto_save_current)
	tab.add_child(auto_btn)
	var title_btn := Button.new()
	title_btn.text = "返回标题画面"
	title_btn.pressed.connect(return_to_title)
	tab.add_child(title_btn)
	var quit_btn := Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.pressed.connect(quit_game)
	tab.add_child(quit_btn)
	return tab


func _make_slider_row(parent: VBoxContainer, label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label(label_text))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	parent.add_child(row)
	return slider


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 80
	return label


func _refresh_slots() -> void:
	if _slots_box == null:
		return
	for child in _slots_box.get_children():
		child.queue_free()
	for slot in SaveStoreScript.MANUAL_SLOTS:
		var payload := SaveStoreScript.load(slot, _save_base_path)
		var row := HBoxContainer.new()
		row.name = "SaveSlotRow_%s" % slot
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.name = "SaveSlotSummary_%s" % slot
		label.text = slot_display_text(slot, payload)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var save_btn := Button.new()
		save_btn.name = slot
		save_btn.text = "覆盖"
		save_btn.pressed.connect(save_to_slot.bind(slot))
		row.add_child(save_btn)
		var load_btn := Button.new()
		load_btn.name = "Load_%s" % slot
		load_btn.text = "读档"
		load_btn.disabled = payload.is_empty()
		load_btn.pressed.connect(request_load_slot.bind(slot))
		row.add_child(load_btn)
		_slots_box.add_child(row)


func _apply_settings_to_controls(settings: Dictionary) -> void:
	if _bgm_slider != null:
		_bgm_slider.value = float(settings.get("bgm_volume", 0.7))
	if _sfx_slider != null:
		_sfx_slider.value = float(settings.get("sfx_volume", 0.8))
	if _language_button != null:
		var idx := LANGUAGES.find(str(settings.get("language", "zh_CN")))
		_language_button.select(maxi(idx, 0))


func _collect_user_settings() -> Dictionary:
	return {
		"bgm_volume": float(_bgm_slider.value if _bgm_slider != null else 0.7),
		"sfx_volume": float(_sfx_slider.value if _sfx_slider != null else 0.8),
		"language": LANGUAGES[_language_button.selected] if _language_button != null else "zh_CN",
		"keymap": "default",
	}


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		_open_save_slot_picker()
		accept_event()


func _open_save_slot_picker() -> void:
	_refresh_slots()
	if _tabs != null:
		_tabs.current_tab = _save_tab_index
	_set_message("选择要覆盖的存档槽")


func open_save_picker() -> void:
	_open_save_slot_picker()


func _return_from_save_picker() -> void:
	if _tabs == null:
		return
	var target := _previous_tab_index
	if target == _save_tab_index or target < 0 or target >= _tabs.get_tab_count():
		target = 1 if _tabs.get_tab_count() > 1 else _save_tab_index
	_tabs.current_tab = target
	_set_message("已取消存档")


func _on_tab_changed(tab: int) -> void:
	if tab != _save_tab_index:
		_previous_tab_index = tab


static func _ensure_parent_dir(path: String) -> bool:
	var base_dir := path.get_base_dir()
	if base_dir == "" or base_dir == ".":
		return true
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir)) == OK
