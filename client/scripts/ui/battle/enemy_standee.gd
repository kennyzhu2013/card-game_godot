class_name EnemyStandee
extends PanelContainer

signal target_pressed(enemy)

const ArtManifestScript = preload("res://scripts/art_manifest.gd")
const StatusTextScript = preload("res://scripts/combat/status_text.gd")
const DEFAULT_MIN_SIZE := Vector2(168, 210)
const DROP_HIGHLIGHT_NONE := "none"
const DROP_HIGHLIGHT_VALID := "valid"
const DROP_HIGHLIGHT_INVALID := "invalid"

var enemy = null
var _intent: Dictionary = {}
var _intent_text := ""
var _obscured_intent := false
var _selected := false

var _portrait_slot: TextureRect
var _intent_floater: Label
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _def_chip: Label
var _status_strip: HBoxContainer
var _target_button: Button


func _init() -> void:
	name = "EnemyStandee"
	_ensure_ui()


func _ready() -> void:
	_ensure_ui()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = DEFAULT_MIN_SIZE
	_refresh_panel_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_highlight(DROP_HIGHLIGHT_NONE)


func bind_enemy(bound_enemy, arg2, arg3 = "", arg4 = false, arg5 = true, arg6 = false, arg7 = {}, arg8 = false, arg9 = false) -> void:
	_ensure_ui()
	enemy = bound_enemy
	var intent_dict: Dictionary = {}
	var intent_text := ""
	var obscured_intent := false
	var target_disabled := true
	var selected := false
	var target_text := "Target"
	if arg2 is Dictionary:
		intent_dict = (arg2 as Dictionary).duplicate(true)
		intent_text = str(arg3)
		obscured_intent = bool(arg4)
		target_disabled = bool(arg5)
		selected = bool(arg6)
	else:
		intent_text = str(arg2)
		target_disabled = bool(arg5)
		target_text = str(arg6).strip_edges()
		if arg7 is Dictionary:
			intent_dict = (arg7 as Dictionary).duplicate(true)
		obscured_intent = bool(arg8)
		selected = bool(arg9)
	if target_text == "":
		target_text = "Target"
	_intent = intent_dict.duplicate(true)
	_intent_text = intent_text.strip_edges()
	_obscured_intent = obscured_intent
	_selected = selected

	var hp := _actor_int("hp", 0)
	var max_hp := maxi(1, _actor_int("max_hp", hp))
	var defense := maxi(0, _actor_int("def", 0))
	_name_label.text = _actor_string("display_name", "Enemy")

	# Load portrait if actor_id exists
	var portrait_id := _actor_string("actor_id", "")
	if portrait_id != "":
		var portrait_texture := ArtManifestScript.texture_for("portrait", portrait_id)
		if portrait_texture != null:
			_portrait_slot.texture = portrait_texture
		else:
			_portrait_slot.texture = null
	else:
		_portrait_slot.texture = null

	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(hp, 0, max_hp)
	_hp_text.text = "生命 %d/%d" % [hp, max_hp]
	_def_chip.text = "防御 %d" % defense
	_intent_floater.text = _display_intent_text()
	_intent_floater.tooltip_text = _intent_floater.text
	_render_status_feet()
	_target_button.text = target_text
	_target_button.disabled = target_disabled
	_target_button.tooltip_text = "target disabled" if target_disabled else "select target"
	tooltip_text = compose_detail_text()
	_refresh_panel_style()


func target_button() -> Button:
	_ensure_ui()
	return _target_button


func compose_detail_text() -> String:
	var lines: Array[String] = []
	lines.append(_actor_string("display_name", "Enemy"))
	lines.append("生命 %d/%d" % [_actor_int("hp", 0), maxi(1, _actor_int("max_hp", _actor_int("hp", 0)))])
	lines.append("防御 %d" % maxi(0, _actor_int("def", 0)))
	var status_lines := _status_detail_lines()
	if status_lines.is_empty():
		lines.append("状态：无")
	else:
		lines.append("状态：")
		for line in status_lines:
			lines.append("  - %s" % line)
	lines.append("意图：")
	lines.append(_display_intent_text())
	return "\n".join(lines)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var card = (data as Dictionary).get("card", null) if data is Dictionary else null
	var accepted := _is_battle_card_payload(data) and _accepts_card_drop(card)
	_set_drop_highlight_from_payload(data, accepted)
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_highlight(DROP_HIGHLIGHT_NONE)
	if not _is_battle_card_payload(data):
		return
	var card = (data as Dictionary).get("card", null)
	if not _accepts_card_drop(card):
		return
	if _card_has_select_targets_effect(card):
		_route_select_targets_drop(card)
	else:
		_route_card_drop(card, enemy)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _target_button != null and not _target_button.disabled:
			target_pressed.emit(enemy)


func _ensure_ui() -> void:
	if _target_button != null:
		return
	custom_minimum_size = DEFAULT_MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.name = "EnemyStandeeMargin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var body := VBoxContainer.new()
	body.name = "EnemyStandeeBody"
	body.add_theme_constant_override("separation", 5)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	_portrait_slot = TextureRect.new()
	_portrait_slot.name = "PortraitSlot"
	_portrait_slot.custom_minimum_size = Vector2(0, 92)
	_portrait_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_slot.add_theme_stylebox_override("panel", _panel_style(Color(0.14, 0.12, 0.13), Color(0.28, 0.31, 0.36), 1))
	body.add_child(_portrait_slot)

	_intent_floater = Label.new()
	_intent_floater.name = "IntentFloater"
	_intent_floater.anchor_left = 0.5
	_intent_floater.anchor_right = 0.5
	_intent_floater.anchor_top = 0.0
	_intent_floater.anchor_bottom = 0.0
	_intent_floater.offset_left = -78
	_intent_floater.offset_right = 78
	_intent_floater.offset_top = 0
	_intent_floater.offset_bottom = 26
	_intent_floater.custom_minimum_size = Vector2(0, 26)
	_intent_floater.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_floater.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intent_floater.clip_text = true
	_intent_floater.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_intent_floater.add_theme_font_size_override("font_size", 12)
	_intent_floater.add_theme_stylebox_override("normal", _panel_style(Color(0.05, 0.06, 0.08, 0.76), Color(0.58, 0.62, 0.70), 1))
	body.add_child(_intent_floater)
	body.move_child(_intent_floater, 0)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	_hp_bar.show_percentage = false
	body.add_child(_hp_bar)

	_hp_text = Label.new()
	_hp_text.name = "HpText"
	_hp_text.add_theme_font_size_override("font_size", 12)
	body.add_child(_hp_text)

	_def_chip = Label.new()
	_def_chip.name = "DefChip"
	_def_chip.custom_minimum_size = Vector2(68, 22)
	_def_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_def_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_def_chip.add_theme_stylebox_override("normal", _panel_style(Color(0.16, 0.18, 0.21), Color(0.42, 0.46, 0.53), 1))
	body.add_child(_def_chip)

	_status_strip = HBoxContainer.new()
	_status_strip.name = "StatusFeetStrip"
	_status_strip.add_theme_constant_override("separation", 4)
	body.add_child(_status_strip)

	_target_button = Button.new()
	_target_button.name = "TargetButton"
	_target_button.text = "Target"
	_target_button.custom_minimum_size = Vector2(0, 28)
	_target_button.focus_mode = Control.FOCUS_ALL
	_target_button.pressed.connect(_on_target_button_pressed)
	body.add_child(_target_button)


func _on_target_button_pressed() -> void:
	target_pressed.emit(enemy)


func _display_intent_text() -> String:
	return _composed_intent_text()
	if _obscured_intent:
		return "??? 被遮蔽"
	if _intent_text != "":
		return _intent_text
	var action := str(_intent.get("action", "observe"))
	var amount := str(_intent.get("amount", _intent.get("damage", ""))).strip_edges()
	return action if amount == "" else "%s %s" % [action, amount]


func _composed_intent_text() -> String:
	if _obscured_intent:
		return "??? 意图被遮蔽"
	var preview := _intent_preview_text()
	if preview == "":
		preview = _clean_legacy_intent_text(_intent_text)
	if preview == "":
		preview = "观察"
	return "意图：%s %s" % [_intent_prefix_text(), preview]


func _intent_prefix_text() -> String:
	var action := str(_intent.get("action", ""))
	var intent_type := str(_intent.get("intent_type", ""))
	if action == "defend":
		return "防御"
	if intent_type in ["attack", "attack_debuff"]:
		return "攻击"
	if intent_type in ["self_buff", "self_heal", "heal"]:
		return "强化"
	if intent_type in ["status", "debuff"]:
		return "负面"
	return "行动"


func _intent_preview_text() -> String:
	var legacy_preview := _clean_legacy_intent_text(_intent_text)
	if legacy_preview != "":
		return legacy_preview
	var prefix := _intent_prefix_text()
	var skill_name := str(_intent.get("skill_name", _intent.get("skill", ""))).strip_edges()
	var damage_text := _damage_preview_text()
	match prefix:
		"攻击":
			if skill_name != "" and damage_text != "":
				return "%s %s" % [skill_name, damage_text]
			return damage_text
		"防御":
			return _first_value_text(["armor", "block", "defense", "amount"])
		"强化":
			var armor := _first_value_text(["armor", "block", "defense", "amount"])
			if armor != "":
				return "自身护甲+%s" % armor
			return _status_preview_text()
		"负面":
			return _status_preview_text()
		_:
			if skill_name != "":
				return skill_name
			return _first_value_text(["amount", "damage", "armor", "stacks"])


func _damage_preview_text() -> String:
	var value := _first_value_text(["damage", "amount"])
	if value == "":
		return ""
	var hits := int(_intent.get("hits", _intent.get("times", 1)))
	if hits > 1:
		return "%sx%d" % [value, hits]
	return value


func _status_preview_text() -> String:
	var status_id := str(_intent.get("status_id", _intent.get("id", ""))).strip_edges()
	var amount := _first_value_text(["stacks", "amount", "duration", "magnitude"])
	var effects = _intent.get("status_effects", [])
	if status_id == "" and effects is Array and not (effects as Array).is_empty():
		var first = (effects as Array)[0]
		if first is Dictionary:
			status_id = str((first as Dictionary).get("id", "")).strip_edges()
			if amount == "":
				for key in ["stacks", "amount", "duration", "magnitude"]:
					if (first as Dictionary).has(key):
						amount = str((first as Dictionary).get(key, "")).strip_edges()
						break
	if status_id == "":
		status_id = "状态"
	var label_text := StatusTextScript.label(status_id) if status_id != "状态" else status_id
	return label_text if amount == "" else "%s %s" % [label_text, amount]


func _first_value_text(keys: Array[String]) -> String:
	for key in keys:
		if _intent.has(key):
			var text := str(_intent.get(key, "")).strip_edges()
			if text != "":
				return text
	return ""


func _clean_legacy_intent_text(text: String) -> String:
	var clean := text.strip_edges()
	if clean.begins_with("意图："):
		clean = clean.substr("意图：".length()).strip_edges()
	return clean


func _render_status_feet() -> void:
	for child in _status_strip.get_children():
		_status_strip.remove_child(child)
		child.queue_free()
	for status_id in _status_ids():
		var icon := Panel.new()
		icon.name = "StatusIcon_%s" % status_id
		icon.custom_minimum_size = Vector2(15, 15)
		icon.set_meta("status_id", status_id)
		icon.tooltip_text = _status_detail_text(status_id)
		icon.add_theme_stylebox_override("panel", _panel_style(_status_color(status_id), Color(0.78, 0.82, 0.86), 1))
		_status_strip.add_child(icon)


func _status_ids() -> Array[String]:
	var ids: Array[String] = []
	if enemy == null or not enemy.has_method("get"):
		return ids
	var statuses = enemy.get("statuses")
	if statuses is Dictionary:
		for status_id in (statuses as Dictionary).keys():
			ids.append(str(status_id))
	var markers = enemy.get("markers")
	if markers is Dictionary:
		for marker_id in (markers as Dictionary).keys():
			if int((markers as Dictionary).get(marker_id, 0)) > 0 and not ids.has(str(marker_id)):
				ids.append(str(marker_id))
	ids.sort()
	return ids


func _status_detail_lines() -> Array[String]:
	var lines: Array[String] = []
	for status_id in _status_ids():
		lines.append(_status_detail_text(status_id))
	return lines


func _status_detail_text(status_id: String) -> String:
	return StatusTextScript.describe(status_id, _status_payload(status_id))


func _status_payload(status_id: String) -> Dictionary:
	if enemy == null or not enemy.has_method("get"):
		return {}
	var statuses = enemy.get("statuses")
	if statuses is Dictionary and (statuses as Dictionary).has(status_id):
		var status_payload = (statuses as Dictionary).get(status_id, {})
		return status_payload if status_payload is Dictionary else {}
	var markers = enemy.get("markers")
	if markers is Dictionary and (markers as Dictionary).has(status_id):
		return {"stacks": int((markers as Dictionary).get(status_id, 0))}
	return {}


func _actor_int(property_name: String, fallback: int) -> int:
	if enemy == null or not enemy.has_method("get"):
		return fallback
	var value = enemy.get(property_name)
	return fallback if value == null else int(value)


func _actor_string(property_name: String, fallback: String) -> String:
	if enemy == null or not enemy.has_method("get"):
		return fallback
	var value = enemy.get(property_name)
	return fallback if value == null else str(value)


func _is_battle_card_payload(data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == "battle_card" and (data as Dictionary).get("card", null) != null


func _accepts_card_drop(card) -> bool:
	if enemy == null or (enemy.has_method("is_dead") and enemy.call("is_dead")):
		return false
	if card == null:
		return false
	if _card_has_select_targets_effect(card):
		return true
	var target := _card_target(card)
	if target == "self" or _is_aoe_target(target):
		return false
	return true


func _card_target(card) -> String:
	if card == null or not card.has_method("get"):
		return ""
	return str(card.get("target"))


func _is_aoe_target(target: String) -> bool:
	return target in ["all_enemies", "aoe", "field", "deck", "random_enemies"]


func _card_has_select_targets_effect(card) -> bool:
	if card == null or not card.has_method("get"):
		return false
	var effects = card.get("status_effects")
	if not effects is Array:
		return false
	for effect in effects:
		if effect is Dictionary and str((effect as Dictionary).get("id", "")) == "select_targets":
			return true
	return false


func _route_card_drop(card, target) -> void:
	var router := _drop_router()
	if router == null:
		return
	if router.has_method("_play_card_from_drop"):
		router.call("_play_card_from_drop", card, target)
	elif router.has_method("_play_selected"):
		router.call("_play_selected", target)


func _route_select_targets_drop(card) -> void:
	var router := _drop_router()
	if router == null:
		return
	if router.has_method("_drop_select_targets_card_on_enemy"):
		router.call("_drop_select_targets_card_on_enemy", card, enemy)
		return
	if router.has_method("_start_target_selection"):
		router.call("_start_target_selection", card)
	if router.has_method("_toggle_target_selection"):
		router.call("_toggle_target_selection", enemy)


func _drop_router() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("_play_card_from_drop") or current.has_method("_play_selected") or current.has_method("_start_target_selection"):
			return current
		current = current.get_parent()
	return null


func _set_drop_hovered(value: bool) -> void:
	set_meta("drop_hovered", value)
	if not value:
		_set_drop_highlight(DROP_HIGHLIGHT_NONE)


func _set_drop_highlight_from_payload(data: Variant, accepted: bool) -> void:
	if not _is_battle_card_payload(data) or not _should_show_drop_highlight():
		_set_drop_highlight(DROP_HIGHLIGHT_NONE)
		return
	_set_drop_highlight(DROP_HIGHLIGHT_VALID if accepted else DROP_HIGHLIGHT_INVALID)


func _set_drop_highlight(state: String) -> void:
	var clean_state := state if state in [DROP_HIGHLIGHT_VALID, DROP_HIGHLIGHT_INVALID] else DROP_HIGHLIGHT_NONE
	set_meta("drop_highlight_state", clean_state)
	set_meta("valid_drop_target", clean_state == DROP_HIGHLIGHT_VALID)
	_refresh_panel_style()


func _should_show_drop_highlight() -> bool:
	return not has_meta("drop_hovered") or bool(get_meta("drop_hovered", true))


func _on_mouse_entered() -> void:
	_set_drop_hovered(true)


func _on_mouse_exited() -> void:
	_set_drop_hovered(false)


func _status_color(status_id: String) -> Color:
	var hash_value: int = abs(int(hash(status_id)))
	var r := 0.24 + float(hash_value % 37) / 100.0
	var g := 0.22 + float((hash_value / 37) % 31) / 110.0
	var b := 0.30 + float((hash_value / 1147) % 29) / 105.0
	return Color(minf(r, 0.72), minf(g, 0.72), minf(b, 0.72), 1.0)


func _refresh_panel_style() -> void:
	var state := str(get_meta("drop_highlight_state", DROP_HIGHLIGHT_NONE))
	var border := Color(0.34, 0.38, 0.45)
	var width := 1
	if state == DROP_HIGHLIGHT_VALID:
		border = Color(0.58, 0.78, 0.46)
		width = 2
	elif state == DROP_HIGHLIGHT_INVALID:
		border = Color(0.86, 0.30, 0.24)
		width = 2
	elif _selected:
		border = Color(1.0, 0.82, 0.28)
		width = 2
	add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.09, 0.11), border, width))


func _panel_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
