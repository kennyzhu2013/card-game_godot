class_name EnemyStageSlot
extends PanelContainer

signal target_pressed(enemy)

const DEFAULT_MIN_SIZE := Vector2(228, 112)
const NORMAL_BORDER_COLOR := Color(0.36, 0.42, 0.50)
const SELECTED_BORDER_COLOR := Color(1.0, 0.82, 0.28)
const DISABLED_BORDER_COLOR := Color(0.55, 0.30, 0.30)

var enemy = null
var _selected := false
var _obscured_intent := false
var _intent: Dictionary = {}

var _name_label: Label
var _hp_bar: ProgressBar
var _hp_text_label: Label
var _def_label: Label
var _status_row: HBoxContainer
var _status_text_label: Label
var _intent_badge: Label
var _target_button: Button


func _init() -> void:
	name = "EnemyStageSlot"
	_ensure_ui()


func _ready() -> void:
	_ensure_ui()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = DEFAULT_MIN_SIZE
	_refresh_panel_style()


func bind_enemy(
		bound_enemy,
		intent_text: String,
		status_text: String = "",
		defense_value: int = -1,
		target_disabled: bool = true,
		target_text: String = "选择目标",
		intent: Dictionary = {},
		obscured_intent: bool = false,
		selected: bool = false
) -> void:
	_ensure_ui()
	enemy = bound_enemy
	_intent = intent.duplicate(true)
	_obscured_intent = obscured_intent
	_selected = selected

	var hp := _actor_int("hp", 0)
	var max_hp := maxi(1, _actor_int("max_hp", hp))
	_name_label.text = _enemy_name_text()
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(hp, 0, max_hp)
	_hp_text_label.text = "HP %d/%d" % [hp, max_hp]

	var resolved_defense := defense_value
	if resolved_defense < 0:
		resolved_defense = maxi(0, _actor_int("def", 0))
	_def_label.text = "DEF %d" % resolved_defense

	var clean_status := status_text.strip_edges()
	if clean_status == "":
		clean_status = _status_summary_text()
	_status_text_label.text = clean_status
	_status_text_label.tooltip_text = clean_status

	_intent_badge.text = _intent_badge_text(intent_text)
	_intent_badge.tooltip_text = _intent_badge.text

	var clean_target_text := target_text.strip_edges()
	_target_button.text = clean_target_text if clean_target_text != "" else "选择目标"
	_target_button.disabled = target_disabled
	_target_button.tooltip_text = "当前不可选择" if target_disabled else "选择该敌人为目标"
	_refresh_panel_style()


func target_button() -> Button:
	_ensure_ui()
	return _target_button


func _ensure_ui() -> void:
	if _target_button != null:
		return
	custom_minimum_size = DEFAULT_MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var margin := MarginContainer.new()
	margin.name = "EnemySlotMargin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var body := HBoxContainer.new()
	body.name = "EnemySlotBody"
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	var facts := VBoxContainer.new()
	facts.name = "EnemyFactColumn"
	facts.add_theme_constant_override("separation", 3)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(facts)

	_name_label = Label.new()
	_name_label.name = "EnemyNameLabel"
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 14)
	facts.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "EnemyHpBar"
	_hp_bar.custom_minimum_size = Vector2(92, 16)
	_hp_bar.show_percentage = false
	facts.add_child(_hp_bar)

	_hp_text_label = Label.new()
	_hp_text_label.name = "EnemyHpTextLabel"
	_hp_text_label.add_theme_font_size_override("font_size", 12)
	facts.add_child(_hp_text_label)

	var detail_row := HBoxContainer.new()
	detail_row.name = "EnemyDetailRow"
	detail_row.add_theme_constant_override("separation", 6)
	facts.add_child(detail_row)

	_def_label = Label.new()
	_def_label.name = "EnemyDefLabel"
	_def_label.add_theme_font_size_override("font_size", 12)
	detail_row.add_child(_def_label)

	_status_row = HBoxContainer.new()
	_status_row.name = "EnemyStatusRow"
	_status_row.add_theme_constant_override("separation", 4)
	_status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_child(_status_row)

	_status_text_label = Label.new()
	_status_text_label.name = "EnemyStatusTextLabel"
	_status_text_label.clip_text = true
	_status_text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_text_label.add_theme_font_size_override("font_size", 12)
	_status_row.add_child(_status_text_label)

	var action_column := VBoxContainer.new()
	action_column.name = "EnemyActionColumn"
	action_column.add_theme_constant_override("separation", 5)
	action_column.custom_minimum_size = Vector2(108, 0)
	body.add_child(action_column)

	_intent_badge = Label.new()
	_intent_badge.name = "IntentBadge"
	_intent_badge.custom_minimum_size = Vector2(108, 42)
	_intent_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intent_badge.clip_text = true
	_intent_badge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_intent_badge.add_theme_font_size_override("font_size", 12)
	action_column.add_child(_intent_badge)

	_target_button = Button.new()
	_target_button.name = "TargetButton"
	_target_button.custom_minimum_size = Vector2(108, 32)
	_target_button.focus_mode = Control.FOCUS_ALL
	_target_button.pressed.connect(_on_target_button_pressed)
	action_column.add_child(_target_button)


func _on_target_button_pressed() -> void:
	target_pressed.emit(enemy)


func _enemy_name_text() -> String:
	var display_name := _actor_string("display_name", "Enemy").strip_edges()
	if display_name == "":
		display_name = "Enemy"
	if enemy != null and enemy.has_method("is_dead") and enemy.call("is_dead"):
		return "%s（已倒）" % display_name
	return display_name


func _actor_int(property_name: String, fallback: int) -> int:
	if enemy == null or not enemy.has_method("get"):
		return fallback
	var value = enemy.get(property_name)
	if value == null:
		return fallback
	return int(value)


func _actor_string(property_name: String, fallback: String) -> String:
	if enemy == null or not enemy.has_method("get"):
		return fallback
	var value = enemy.get(property_name)
	if value == null:
		return fallback
	return str(value)


func _status_summary_text() -> String:
	if enemy == null or not enemy.has_method("get"):
		return "状态：无"
	var statuses = enemy.get("statuses")
	if not statuses is Dictionary or (statuses as Dictionary).is_empty():
		return "状态：无"
	var parts: Array[String] = []
	for status_id in (statuses as Dictionary).keys():
		var payload = (statuses as Dictionary).get(status_id, {})
		var text := str(status_id)
		if payload is Dictionary and (payload as Dictionary).has("duration"):
			text += " %d" % int((payload as Dictionary).get("duration", 0))
		parts.append(text)
	return "状态：%s" % " / ".join(parts)


func _intent_badge_text(intent_text: String) -> String:
	if _obscured_intent:
		return "??? 意图被遮蔽"
	var clean_text := intent_text.strip_edges()
	if clean_text == "":
		clean_text = "意图：观察"
	return "%s  %s" % [_intent_badge_prefix(), clean_text]


func _intent_badge_prefix() -> String:
	var action := str(_intent.get("action", ""))
	var intent_type := str(_intent.get("intent_type", ""))
	if action == "defend":
		return "DEF"
	if intent_type in ["attack", "attack_debuff"]:
		return "ATK"
	if intent_type in ["self_buff", "self_heal", "heal"]:
		return "BUFF"
	if intent_type in ["status", "debuff"]:
		return "DEBUFF"
	return "ACT"


func _refresh_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.13)
	style.border_color = NORMAL_BORDER_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	if _target_button != null and _target_button.disabled:
		style.bg_color = Color(0.11, 0.10, 0.12)
		style.border_color = DISABLED_BORDER_COLOR
	if _selected:
		style.border_color = SELECTED_BORDER_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	add_theme_stylebox_override("panel", style)
