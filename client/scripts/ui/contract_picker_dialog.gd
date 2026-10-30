class_name ContractPickerDialog
extends Panel

const GameStateScript = preload("res://scripts/state/game_state.gd")

const REQUIRED_RULE_COUNT := 3

signal contract_locked(rules: Array)
signal contract_cancelled()

var _game_state = null
var _selected_rules: Array[String] = []
var _rule_checks: Dictionary = {}
var _rules_box: VBoxContainer
var _message_label: Label
var _lock_button: Button
var _cancel_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()
	hide()


func open(game_state = null) -> void:
	_ensure_ui()
	_game_state = game_state if game_state != null else GameState
	_selected_rules = _initial_selection_from_state(_game_state)
	_rebuild_rule_checks()
	_refresh_message()
	show()
	if _rules_box != null and _rules_box.get_child_count() > 0:
		var first = _rules_box.get_child(0)
		if first is Control:
			first.grab_focus()


func available_rules() -> Array[String]:
	return _available_rules_for_state(_game_state)


func selected_rules() -> Array[String]:
	return _selected_rules.duplicate()


func select_rule(rule_id: String, selected: bool = true) -> bool:
	var normalized := str(rule_id)
	if not normalized in available_rules():
		return false
	if selected:
		if not normalized in _selected_rules:
			_selected_rules.append(normalized)
	else:
		_selected_rules.erase(normalized)
	if _rule_checks.has(normalized):
		var check = _rule_checks[normalized]
		if check is CheckBox:
			check.set_pressed_no_signal(normalized in _selected_rules)
	_refresh_message()
	return true


func lock_selection() -> bool:
	if _game_state == null:
		_set_message("契约状态不可用")
		return false
	if _selected_rules.size() != REQUIRED_RULE_COUNT:
		_refresh_message()
		return false
	_write_active_contract(_game_state, _selected_rules)
	hide()
	contract_locked.emit(_selected_rules.duplicate())
	return true


func ensure_contract_for_tower(game_state) -> bool:
	if game_state == null:
		return false
	var active := _string_array(game_state.get("active_contract"))
	if active.size() >= REQUIRED_RULE_COUNT:
		return true
	var rules := _available_rules_for_state(game_state)
	if rules.size() < REQUIRED_RULE_COUNT:
		return false
	var defaults: Array[String] = []
	for i in range(REQUIRED_RULE_COUNT):
		defaults.append(str(rules[i]))
	_write_active_contract(game_state, defaults)
	return true


func close_dialog() -> void:
	hide()
	contract_cancelled.emit()


func _ensure_ui() -> void:
	if _rules_box != null:
		return
	_build_ui()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.045, 0.05, 0.055, 0.96)
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
	title.text = "扮演契约"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_cancel_button = Button.new()
	_cancel_button.text = "关闭"
	_cancel_button.focus_mode = Control.FOCUS_ALL
	_cancel_button.pressed.connect(close_dialog)
	header.add_child(_cancel_button)

	var hint := Label.new()
	hint.text = "选择 3 条守则作为本次进塔契约。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_rules_box = VBoxContainer.new()
	_rules_box.name = "RulesBox"
	_rules_box.add_theme_constant_override("separation", 8)
	_rules_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rules_box)

	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	_lock_button = Button.new()
	_lock_button.name = "LockButton"
	_lock_button.text = "锁定"
	_lock_button.custom_minimum_size.y = 44
	_lock_button.focus_mode = Control.FOCUS_ALL
	_lock_button.pressed.connect(lock_selection)
	buttons.add_child(_lock_button)

	var reset_button := Button.new()
	reset_button.name = "DefaultButton"
	reset_button.text = "默认三条"
	reset_button.custom_minimum_size.y = 44
	reset_button.focus_mode = Control.FOCUS_ALL
	reset_button.pressed.connect(_select_default_three)
	buttons.add_child(reset_button)


func _rebuild_rule_checks() -> void:
	_rule_checks.clear()
	for child in _rules_box.get_children():
		_rules_box.remove_child(child)
		child.queue_free()
	for rule in available_rules():
		var check := CheckBox.new()
		check.name = "Rule_%s" % _node_safe_name(rule)
		check.text = str(rule)
		check.focus_mode = Control.FOCUS_ALL
		check.custom_minimum_size.y = 44
		check.button_pressed = str(rule) in _selected_rules
		check.toggled.connect(_on_rule_toggled.bind(str(rule)))
		_rules_box.add_child(check)
		_rule_checks[str(rule)] = check


func _on_rule_toggled(pressed: bool, rule_id: String) -> void:
	select_rule(rule_id, pressed)


func _select_default_three() -> void:
	_selected_rules.clear()
	var rules := available_rules()
	for i in range(mini(REQUIRED_RULE_COUNT, rules.size())):
		_selected_rules.append(str(rules[i]))
	for key in _rule_checks.keys():
		var check = _rule_checks[key]
		if check is CheckBox:
			check.set_pressed_no_signal(str(key) in _selected_rules)
	_refresh_message()


func _initial_selection_from_state(game_state) -> Array[String]:
	var result := _string_array(game_state.get("active_contract")) if game_state != null else []
	if result.size() >= REQUIRED_RULE_COUNT:
		return result
	result.clear()
	return result


func _available_rules_for_state(game_state) -> Array[String]:
	var result: Array[String] = []
	if game_state != null:
		_merge_unique(result, game_state.get("learned_rules"))
	if result.size() < REQUIRED_RULE_COUNT:
		_merge_unique(result, GameStateScript.DEFAULT_FOOL_RULES)
	return result


func _write_active_contract(game_state, rules: Array[String]) -> void:
	game_state.active_contract.clear()
	for rule in rules:
		game_state.active_contract.append(str(rule))


func _refresh_message() -> void:
	if _selected_rules.size() == REQUIRED_RULE_COUNT:
		_set_message("已选择 3 条，可以锁定。")
	else:
		_set_message("已选择 %d/%d 条。" % [_selected_rules.size(), REQUIRED_RULE_COUNT])


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func _merge_unique(target: Array[String], value: Variant) -> void:
	if not value is Array:
		return
	for item in value:
		var text := str(item)
		if text != "" and not text in target:
			target.append(text)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _node_safe_name(value: String) -> String:
	var text := ""
	for i in value.length():
		var code := value.unicode_at(i)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			text += value.substr(i, 1)
		else:
			text += "_"
	return text
