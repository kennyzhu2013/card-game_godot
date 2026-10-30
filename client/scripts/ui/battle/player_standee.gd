class_name PlayerStandee
extends PanelContainer

const ArtManifestScript = preload("res://scripts/art_manifest.gd")
const StatusTextScript = preload("res://scripts/combat/status_text.gd")
const DEFAULT_MIN_SIZE := Vector2(200, 210)
const DROP_HIGHLIGHT_NONE := "none"
const DROP_HIGHLIGHT_VALID := "valid"
const DROP_HIGHLIGHT_INVALID := "invalid"

var player_actor = null
var _contract_text := ""
var _rules_text := ""

var _portrait_slot: TextureRect
var _hp_bar: ProgressBar
var _hp_text: Label
var _def_chip: Label
var _status_strip: HBoxContainer
var _player_chip_alias: Control
var _player_chip_strip: HBoxContainer
var _status_detail_label: Label


func _init() -> void:
	name = "PlayerStandee"
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_highlight(DROP_HIGHLIGHT_NONE)


func bind_player(bound_player, contract_text: String, rules_text: String) -> void:
	_ensure_ui()
	player_actor = bound_player
	_contract_text = contract_text.strip_edges()
	_rules_text = rules_text.strip_edges()

	var hp := _actor_int("hp", 0)
	var max_hp := maxi(1, _actor_int("max_hp", hp))
	var defense := maxi(0, _actor_int("def", 0))
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(hp, 0, max_hp)
	_hp_text.text = "生命 %d/%d" % [hp, max_hp]

	# Load player portrait (default fallback: "player")
	var portrait_id := _actor_string("actor_id", "player")
	if portrait_id == "":
		portrait_id = "player"
	var portrait_texture := ArtManifestScript.texture_for("portrait", portrait_id)
	if portrait_texture != null:
		_portrait_slot.texture = portrait_texture
	else:
		_portrait_slot.texture = null

	_def_chip.text = "防御 %d" % defense
	_render_status_feet()
	tooltip_text = compose_detail_text()


func compose_detail_text() -> String:
	var lines: Array[String] = []
	lines.append("生命 %d/%d" % [_actor_int("hp", 0), maxi(1, _actor_int("max_hp", _actor_int("hp", 0)))])
	lines.append("防御 %d" % maxi(0, _actor_int("def", 0)))
	var status_lines := _status_detail_lines()
	if status_lines.is_empty():
		lines.append("状态：无")
	else:
		lines.append("状态：")
		for line in status_lines:
			lines.append("  - %s" % line)
	if _contract_text != "":
		lines.append("扮演契约：")
		lines.append(_contract_text)
	if _rules_text != "":
		lines.append("已领悟规则：")
		lines.append(_rules_text)
	return "\n".join(lines)


func player_chip_strip() -> HBoxContainer:
	_ensure_ui()
	return _player_chip_strip


func charge_zone_box() -> VBoxContainer:
	_ensure_ui()
	return null


func field_state_label() -> Label:
	_ensure_ui()
	return null


func set_player_chip_texts(chip_texts: Array) -> void:
	_ensure_ui()
	for child in _player_chip_strip.get_children():
		_player_chip_strip.remove_child(child)
		child.queue_free()
	for raw_text in chip_texts:
		var text := str(raw_text).strip_edges()
		if text == "":
			continue
		var chip := Label.new()
		chip.name = "PlayerChip_%d" % _player_chip_strip.get_child_count()
		chip.text = text
		chip.tooltip_text = text
		chip.custom_minimum_size = Vector2(0, 22)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.clip_text = true
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.add_theme_stylebox_override("normal", _panel_style(Color(0.12, 0.15, 0.18), Color(0.46, 0.54, 0.62), 1))
		_player_chip_strip.add_child(chip)
	var has_chips := _player_chip_strip.get_child_count() > 0
	_player_chip_strip.visible = has_chips
	if _player_chip_alias != null:
		_player_chip_alias.visible = has_chips


func set_status_detail_text(text: String) -> void:
	_ensure_ui()
	_status_detail_label.text = text


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var card = (data as Dictionary).get("card", null) if data is Dictionary else null
	var accepted := _is_battle_card_payload(data) and _card_target(card) == "self"
	_set_drop_highlight_from_payload(data, accepted)
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_highlight(DROP_HIGHLIGHT_NONE)
	if not _is_battle_card_payload(data):
		return
	var card = data.get("card", null)
	if _card_target(card) != "self":
		return
	_route_card_drop(card, player_actor)


func _ensure_ui() -> void:
	if _status_strip != null:
		return
	custom_minimum_size = DEFAULT_MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_refresh_panel_style()

	var margin := MarginContainer.new()
	margin.name = "PlayerStandeeMargin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var body := VBoxContainer.new()
	body.name = "PlayerStandeeBody"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	_portrait_slot = TextureRect.new()
	_portrait_slot.name = "PortraitSlot"
	_portrait_slot.custom_minimum_size = Vector2(0, 112)
	_portrait_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_slot.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.16, 0.20), Color(0.26, 0.31, 0.38), 1))
	body.add_child(_portrait_slot)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	_hp_bar.show_percentage = false
	body.add_child(_hp_bar)

	_hp_text = Label.new()
	_hp_text.name = "HpText"
	_hp_text.add_theme_font_size_override("font_size", 14)
	body.add_child(_hp_text)

	_def_chip = Label.new()
	_def_chip.name = "DefChip"
	_def_chip.custom_minimum_size = Vector2(72, 24)
	_def_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_def_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_def_chip.add_theme_stylebox_override("normal", _panel_style(Color(0.16, 0.19, 0.23), Color(0.43, 0.49, 0.58), 1))
	body.add_child(_def_chip)

	_status_strip = HBoxContainer.new()
	_status_strip.name = "StatusFeetStrip"
	_status_strip.add_theme_constant_override("separation", 4)
	body.add_child(_status_strip)

	_player_chip_alias = MarginContainer.new()
	_player_chip_alias.name = "ChargeZone"
	_player_chip_alias.visible = false
	_player_chip_alias.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_player_chip_alias)

	_player_chip_strip = HBoxContainer.new()
	_player_chip_strip.name = "PlayerChipStrip"
	_player_chip_strip.visible = false
	_player_chip_strip.add_theme_constant_override("separation", 4)
	_player_chip_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_chip_alias.add_child(_player_chip_strip)

	_status_detail_label = Label.new()
	_status_detail_label.name = "StatusDetailLabel"
	_status_detail_label.visible = false
	_status_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status_detail_label)


func _render_status_feet() -> void:
	for child in _status_strip.get_children():
		_status_strip.remove_child(child)
		child.queue_free()
	for status_id in _status_ids():
		var icon := Panel.new()
		icon.name = "StatusIcon_%s" % status_id
		icon.custom_minimum_size = Vector2(16, 16)
		icon.set_meta("status_id", status_id)
		icon.tooltip_text = _status_detail_text(status_id)
		icon.add_theme_stylebox_override("panel", _panel_style(_status_color(status_id), Color(0.78, 0.82, 0.86), 1))
		_status_strip.add_child(icon)


func _status_ids() -> Array[String]:
	var ids: Array[String] = []
	if player_actor == null or not player_actor.has_method("get"):
		return ids
	var statuses = player_actor.get("statuses")
	if statuses is Dictionary:
		for status_id in (statuses as Dictionary).keys():
			ids.append(str(status_id))
	var markers = player_actor.get("markers")
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
	if player_actor == null or not player_actor.has_method("get"):
		return {}
	var statuses = player_actor.get("statuses")
	if statuses is Dictionary and (statuses as Dictionary).has(status_id):
		var status_payload = (statuses as Dictionary).get(status_id, {})
		return status_payload if status_payload is Dictionary else {}
	var markers = player_actor.get("markers")
	if markers is Dictionary and (markers as Dictionary).has(status_id):
		return {"stacks": int((markers as Dictionary).get(status_id, 0))}
	return {}


func _actor_int(property_name: String, fallback: int) -> int:
	if player_actor == null or not player_actor.has_method("get"):
		return fallback
	var value = player_actor.get(property_name)
	return fallback if value == null else int(value)


func _actor_string(property_name: String, fallback: String) -> String:
	if player_actor == null or not player_actor.has_method("get"):
		return fallback
	var value = player_actor.get(property_name)
	return fallback if value == null else str(value)


func _is_battle_card_payload(data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == "battle_card" and (data as Dictionary).get("card", null) != null


func _card_target(card) -> String:
	if card == null or not card.has_method("get"):
		return ""
	return str(card.get("target"))


func _route_card_drop(card, target) -> void:
	var router := _drop_router()
	if router == null:
		return
	if router.has_method("_play_card_from_drop"):
		router.call("_play_card_from_drop", card, target)
	elif router.has_method("_play_selected"):
		router.call("_play_selected", target)


func _drop_router() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("_play_card_from_drop") or current.has_method("_play_selected"):
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
	var r := 0.22 + float(hash_value % 37) / 100.0
	var g := 0.28 + float((hash_value / 37) % 31) / 110.0
	var b := 0.34 + float((hash_value / 1147) % 29) / 105.0
	return Color(minf(r, 0.72), minf(g, 0.72), minf(b, 0.72), 1.0)


func _refresh_panel_style() -> void:
	var state := str(get_meta("drop_highlight_state", DROP_HIGHLIGHT_NONE))
	var border := Color(0.31, 0.38, 0.46)
	var width := 1
	if state == DROP_HIGHLIGHT_VALID:
		border = Color(0.58, 0.78, 0.46)
		width = 2
	elif state == DROP_HIGHLIGHT_INVALID:
		border = Color(0.86, 0.30, 0.24)
		width = 2
	add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.13), border, width))


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
