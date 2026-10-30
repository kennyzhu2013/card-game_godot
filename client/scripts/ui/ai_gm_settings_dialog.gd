class_name AIGMSettingsDialog
extends Panel

const SecretStoreScript = preload("res://scripts/ai_gm/ai_gm_secret_store.gd")
const ProviderScript = preload("res://scripts/ai_gm/ai_gm_provider.gd")

const DEFAULT_SECRET_PATH := SecretStoreScript.DEFAULT_PATH
const PROVIDER_IDS := [
	ProviderScript.CLAUDE_HAIKU,
	ProviderScript.CLAUDE_SONNET,
	ProviderScript.DEEPSEEK,
	ProviderScript.GEMINI,
	ProviderScript.QWEN,
]

var _game_state = null
var _secret_store = SecretStoreScript.new()
var _provider_button: OptionButton
var _offline_toggle: CheckButton
var _api_key_edit: LineEdit
var _cost_label: Label
var _message_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()
	hide()


func open(game_state = null, secret_path: String = DEFAULT_SECRET_PATH) -> void:
	_ensure_ui()
	_game_state = game_state if game_state != null else GameState
	_secret_store = SecretStoreScript.new()
	_secret_store.path = secret_path
	_apply_settings_to_controls(_settings_from_state())
	_api_key_edit.text = _secret_store.load_api_key()
	show()


func selected_provider_id() -> String:
	if _provider_button == null:
		return ProviderScript.CLAUDE_HAIKU
	var index := _provider_button.selected
	if index < 0 or index >= PROVIDER_IDS.size():
		return ProviderScript.CLAUDE_HAIKU
	return str(PROVIDER_IDS[index])


func set_provider_id(provider_id: String) -> void:
	_ensure_ui()
	var index := PROVIDER_IDS.find(provider_id)
	_provider_button.select(maxi(index, 0))


func is_offline_mode() -> bool:
	return true if _offline_toggle == null else _offline_toggle.button_pressed


func set_offline_mode(value: bool) -> void:
	_ensure_ui()
	_offline_toggle.button_pressed = value


func set_api_key_for_test(value: String) -> void:
	_ensure_ui()
	_api_key_edit.text = value


func load_api_key_for_test() -> String:
	return _secret_store.load_api_key()


func apply_current_settings() -> bool:
	if _game_state == null:
		return false
	var settings := _settings_from_state()
	settings["provider"] = selected_provider_id()
	settings["offline_mode"] = is_offline_mode()
	settings["network_enabled"] = not is_offline_mode()
	_game_state.set("ai_gm_settings", settings)
	var ok := _secret_store.save_api_key(_api_key_edit.text if _api_key_edit != null else "")
	_set_message("AI GM 设置已保存" if ok else "AI GM 设置保存失败")
	_refresh_cost_label(settings)
	return ok


func close_dialog() -> void:
	hide()


func _ensure_ui() -> void:
	if _provider_button != null:
		return
	_build_ui()


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
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title := Label.new()
	title.text = "AI GM"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(close_dialog)
	header.add_child(close_button)

	_offline_toggle = CheckButton.new()
	_offline_toggle.name = "OfflineToggle"
	_offline_toggle.text = "离线模式"
	_offline_toggle.button_pressed = true
	root.add_child(_offline_toggle)

	var provider_row := HBoxContainer.new()
	provider_row.add_theme_constant_override("separation", 8)
	root.add_child(provider_row)
	var provider_label := Label.new()
	provider_label.text = "提供商"
	provider_label.custom_minimum_size.x = 80
	provider_row.add_child(provider_label)
	_provider_button = OptionButton.new()
	_provider_button.name = "ProviderButton"
	_provider_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for provider_id in PROVIDER_IDS:
		_provider_button.add_item(_provider_label(provider_id))
	provider_row.add_child(_provider_button)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 8)
	root.add_child(key_row)
	var key_label := Label.new()
	key_label.text = "API key"
	key_label.custom_minimum_size.x = 80
	key_row.add_child(key_label)
	_api_key_edit = LineEdit.new()
	_api_key_edit.name = "ApiKeyEdit"
	_api_key_edit.secret = true
	_api_key_edit.placeholder_text = "user://ai_gm_secret.json"
	_api_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(_api_key_edit)

	_cost_label = Label.new()
	_cost_label.name = "CostLabel"
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_cost_label)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	root.add_child(button_row)
	var apply_button := Button.new()
	apply_button.text = "应用"
	apply_button.pressed.connect(apply_current_settings)
	button_row.add_child(apply_button)
	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(close_dialog)
	button_row.add_child(cancel_button)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)


func _settings_from_state() -> Dictionary:
	var defaults := {}
	if _game_state != null and _game_state.has_method("default_ai_gm_settings"):
		defaults = _game_state.default_ai_gm_settings()
	else:
		defaults = {
			"provider": ProviderScript.CLAUDE_HAIKU,
			"offline_mode": true,
			"network_enabled": false,
			"daily_call_cap": 120,
			"daily_cost_cap": 0.02,
		}
	var value = _game_state.get("ai_gm_settings") if _game_state != null and _has_property(_game_state, "ai_gm_settings") else {}
	if value is Dictionary:
		for key in value.keys():
			if str(key) != "api_key":
				defaults[key] = value[key]
	return defaults


func _apply_settings_to_controls(settings: Dictionary) -> void:
	set_provider_id(str(settings.get("provider", ProviderScript.CLAUDE_HAIKU)))
	set_offline_mode(bool(settings.get("offline_mode", true)))
	_refresh_cost_label(settings)


func _refresh_cost_label(settings: Dictionary) -> void:
	if _cost_label == null:
		return
	_cost_label.text = "今日预算：%d 次 / $%.4f；当前模式：%s" % [
		int(settings.get("daily_call_cap", 120)),
		float(settings.get("daily_cost_cap", 0.02)),
		"离线" if bool(settings.get("offline_mode", true)) else "网络",
	]


func _provider_label(provider_id: String) -> String:
	match provider_id:
		ProviderScript.CLAUDE_SONNET:
			return "Claude Sonnet"
		ProviderScript.DEEPSEEK:
			return "DeepSeek"
		ProviderScript.GEMINI:
			return "Gemini"
		ProviderScript.QWEN:
			return "Qwen"
		_:
			return "Claude Haiku"


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func _has_property(obj, prop_name: String) -> bool:
	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == prop_name:
			return true
	return false
