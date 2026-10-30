class_name BattleCardView
extends PanelContainer

signal pressed(card)
signal peek_requested(card)

const DEFAULT_MIN_SIZE := Vector2(108, 162)
const DRAG_PREVIEW_SIZE := Vector2(150, 225)
const CARD_ART_FALLBACK_ASPECT := 1.5
const CARD_ART_MIN_ASPECT := 1.25
const CARD_ART_MAX_ASPECT := 1.8
const DRAG_LIFT_SCALE := 1.08
const DRAG_SOURCE_PLACEHOLDER_ALPHA := 0.0
const SELECTED_BORDER_COLOR := Color(1.0, 0.82, 0.28)
const NORMAL_BORDER_COLOR := Color(0.42, 0.46, 0.52)
const DISABLED_BORDER_COLOR := Color(0.62, 0.34, 0.34)

var card = null
var _disabled_reason := ""
var _selected := false

var _cost_badge: Label
var _name_label: Label
var _type_label: Label
var _effect_label: Label
var _disabled_reason_label: Label
var _art_rect: TextureRect
var _art_scrim: ColorRect
var _drag_source_placeholder: Control
var _drag_source_original_modulate := Color(1, 1, 1, 1)
var _drag_source_original_mouse_filter := Control.MOUSE_FILTER_STOP
var _drag_source_original_disabled := false
var _last_hover_time_msec := 0


func _init() -> void:
	name = "BattleCardView"
	_ensure_ui()
	mouse_entered.connect(_on_mouse_entered)


func _ready() -> void:
	_ensure_ui()
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = DEFAULT_MIN_SIZE
	_refresh_panel_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drag_source_placeholder(false)


func bind_card(bound_card, effective_cost: int = -1, effect_text: String = "", disabled_reason: String = "", tooltip: String = "", selected: bool = false, texture: Texture2D = null) -> void:
	_ensure_ui()
	_set_drag_source_placeholder(false)
	card = bound_card
	_disabled_reason = disabled_reason.strip_edges()
	_selected = selected
	var cost := effective_cost
	if cost < 0 and card != null:
		cost = int(card.energy_cost)
	_cost_badge.text = "费用 %d" % cost
	_name_label.text = _card_name_text(card)
	_type_label.text = _card_type_text(card)
	var summary := _card_effect_text(card)
	if summary == "":
		summary = effect_text.strip_edges()
	_effect_label.text = _compact_text(summary, 108)
	_effect_label.tooltip_text = summary
	tooltip_text = tooltip.strip_edges()
	if tooltip_text == "":
		tooltip_text = _default_tooltip_text(card, cost, summary)
	if _disabled_reason != "":
		_disabled_reason_label.text = "不可用：%s" % _disabled_reason
		_disabled_reason_label.visible = true
		tooltip_text += "\n\n不可用：%s" % _disabled_reason
	else:
		_disabled_reason_label.text = ""
		_disabled_reason_label.visible = false
	_art_rect.texture = texture
	_art_rect.visible = texture != null
	_art_scrim.visible = texture != null
	_refresh_panel_style()


func set_selected(value: bool) -> void:
	_selected = value
	_refresh_panel_style()


func is_disabled() -> bool:
	return _disabled_reason != ""


func disabled_reason() -> String:
	return _disabled_reason


func activate() -> void:
	_emit_pressed()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_disabled() or card == null:
		return {}
	var preview_size := preferred_card_size_for_art(_art_rect.texture if _art_rect != null else null, DRAG_PREVIEW_SIZE.x)
	var preview_rect := _drag_preview_rect_for_size(preview_size)
	var preview := _make_drag_preview(preview_rect.size)
	set_drag_preview(preview)
	var source_placeholder := _set_drag_source_placeholder(true)
	return {
		"kind": "battle_card",
		"card": card,
		"view": self,
		"source_view": self,
		"source_placeholder": source_placeholder,
		"source_hidden_during_drag": source_placeholder != null,
		"preview_rect": preview_rect,
		"preview_attached": true,
		"preview_control": preview,
		"drag_lift_animation": true,
		"drag_travel_animation": true,
	}


func _gui_input(event: InputEvent) -> void:
	if _is_mouse_peek_event(event):
		_emit_peek_requested()
		accept_event()
		return
	if _is_activation_event(event):
		_emit_pressed()
		accept_event()


func _is_mouse_peek_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	return false


func _is_activation_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.is_action_pressed("ui_accept") or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE
	if event is InputEventJoypadButton and event.pressed:
		return event.is_action_pressed("ui_accept")
	return false


func _emit_pressed() -> void:
	if is_disabled():
		return
	pressed.emit(card)


func _emit_peek_requested() -> void:
	if card == null:
		return
	peek_requested.emit(card)


func _drag_preview_rect() -> Rect2:
	return _drag_preview_rect_for_size(preferred_card_size_for_art(_art_rect.texture if _art_rect != null else null, DRAG_PREVIEW_SIZE.x))


func _drag_preview_rect_for_size(preview_size: Vector2) -> Rect2:
	var rect := get_global_rect()
	var bounds := _drag_preview_bounds()
	var width := minf(preview_size.x, bounds.size.x)
	var height := minf(preview_size.y, bounds.size.y)
	var x := clampf(rect.position.x, bounds.position.x, bounds.position.x + bounds.size.x - width)
	var y := clampf(rect.position.y, bounds.position.y, bounds.position.y + bounds.size.y - height)
	return Rect2(Vector2(x, y), Vector2(width, height))


func _drag_preview_bounds() -> Rect2:
	var current := get_parent()
	var best := Rect2(Vector2.ZERO, get_viewport_rect().size)
	while current != null:
		if current is Control and (current as Control).clip_contents:
			best = (current as Control).get_global_rect()
		current = current.get_parent()
	return best


func preferred_card_size_for_art(texture: Texture2D = null, target_width: float = DEFAULT_MIN_SIZE.x) -> Vector2:
	var width := maxf(48.0, target_width)
	var aspect := CARD_ART_FALLBACK_ASPECT
	if texture != null:
		var texture_size := texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			aspect = clampf(texture_size.y / texture_size.x, CARD_ART_MIN_ASPECT, CARD_ART_MAX_ASPECT)
	var height := maxf(width * aspect, width + 24.0)
	return Vector2(floor(width + 0.5), floor(height + 0.5))


func _set_drag_source_placeholder(active: bool) -> Control:
	if active:
		var source_visual := _drag_source_visual_control()
		if source_visual == null:
			return null
		if _drag_source_placeholder == source_visual and bool(source_visual.get_meta("drag_source_placeholder", false)):
			return source_visual
		_drag_source_placeholder = source_visual
		_drag_source_original_modulate = source_visual.modulate
		_drag_source_original_mouse_filter = source_visual.mouse_filter
		_drag_source_original_disabled = (source_visual as BaseButton).disabled if source_visual is BaseButton else false
		source_visual.visible = true
		source_visual.modulate = Color(
			_drag_source_original_modulate.r,
			_drag_source_original_modulate.g,
			_drag_source_original_modulate.b,
			DRAG_SOURCE_PLACEHOLDER_ALPHA
		)
		source_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if source_visual is BaseButton:
			(source_visual as BaseButton).disabled = true
		source_visual.set_meta("drag_source_placeholder", true)
		set_meta("drag_source_placeholder", true)
		return source_visual
	var source_visual := _drag_source_placeholder
	if source_visual != null and is_instance_valid(source_visual):
		source_visual.modulate = _drag_source_original_modulate
		source_visual.mouse_filter = _drag_source_original_mouse_filter
		if source_visual is BaseButton:
			(source_visual as BaseButton).disabled = _drag_source_original_disabled
		source_visual.set_meta("drag_source_placeholder", false)
	set_meta("drag_source_placeholder", false)
	_drag_source_placeholder = null
	return null


func _drag_source_visual_control() -> Control:
	var parent_node := get_parent()
	if parent_node is BaseButton:
		return parent_node as Control
	return self


func _make_drag_preview(preview_size: Vector2 = DRAG_PREVIEW_SIZE) -> Control:
	var wrapper := Control.new()
	wrapper.name = "BattleCardDragPreview"
	wrapper.custom_minimum_size = preview_size
	wrapper.size = preview_size
	wrapper.position = -preview_size * 0.5
	wrapper.pivot_offset = preview_size * 0.5
	wrapper.scale = Vector2(DRAG_LIFT_SCALE, DRAG_LIFT_SCALE)
	wrapper.z_index = 240
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.clip_contents = false
	wrapper.modulate = Color(1, 1, 1, 0.92)
	wrapper.set_meta("drag_lift_animation", true)
	wrapper.set_meta("drag_travel_animation", true)
	var preview := BattleCardView.new()
	preview.name = "BattleCardDragPreviewCard"
	preview.custom_minimum_size = preview_size
	preview.size = preview_size
	preview.position = Vector2.ZERO
	preview.z_index = 1
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	wrapper.add_child(preview)
	var cost := int(card.energy_cost) if card != null and card.has_method("get") else 0
	preview.bind_card(card, cost, _card_effect_text(card), "", "", false, _art_rect.texture if _art_rect != null else null)
	var effect_label = preview.find_child("EffectLabel", true, false)
	if effect_label is Label:
		(effect_label as Label).custom_minimum_size = Vector2.ZERO
		(effect_label as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(effect_label as Label).max_lines_visible = 4
		(effect_label as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(effect_label as Label).clip_text = true
		(effect_label as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var name_label = preview.find_child("NameLabel", true, false)
	if name_label is Label:
		(name_label as Label).custom_minimum_size = Vector2.ZERO
		(name_label as Label).clip_text = true
		(name_label as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return wrapper


func _ensure_ui() -> void:
	if _cost_badge != null:
		return

	_art_rect = TextureRect.new()
	_art_rect.name = "CardArt"
	_art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_rect.z_index = 0
	_art_rect.visible = false
	add_child(_art_rect)

	_art_scrim = ColorRect.new()
	_art_scrim.name = "CardArtScrim"
	_art_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_scrim.color = Color(0.03, 0.035, 0.045, 0.34)
	_art_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_scrim.z_index = 1
	_art_scrim.visible = false
	add_child(_art_scrim)

	var margin := MarginContainer.new()
	margin.name = "CardTextOverlay"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.z_index = 2
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var body := VBoxContainer.new()
	body.name = "CardBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	var header_ribbon := PanelContainer.new()
	header_ribbon.name = "CardHeaderRibbon"
	header_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_ribbon.add_theme_stylebox_override("panel", _ribbon_style(Color(0.05, 0.055, 0.07, 0.82), Color(0.86, 0.74, 0.50, 0.62), 1))
	body.add_child(header_ribbon)

	var header := HBoxContainer.new()
	header.name = "CardHeader"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 6)
	header_ribbon.add_child(header)

	_cost_badge = Label.new()
	_cost_badge.name = "CostBadge"
	_cost_badge.custom_minimum_size = Vector2(34, 20)
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_badge.add_theme_font_size_override("font_size", 12)
	_cost_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	header.add_child(_cost_badge)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	header.add_child(_name_label)

	var art_open_area := Control.new()
	art_open_area.name = "CardArtOpenArea"
	art_open_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_open_area.custom_minimum_size = Vector2(0, 28)
	art_open_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(art_open_area)

	var text_ribbon := PanelContainer.new()
	text_ribbon.name = "CardTextRibbon"
	text_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_ribbon.custom_minimum_size = Vector2(0, 50)
	text_ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_ribbon.size_flags_vertical = Control.SIZE_SHRINK_END
	text_ribbon.add_theme_stylebox_override("panel", _ribbon_style(Color(0.05, 0.055, 0.07, 0.86), Color(0.50, 0.55, 0.64, 0.45), 1))
	body.add_child(text_ribbon)

	var text_box := VBoxContainer.new()
	text_box.name = "CardTextBox"
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 1)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_ribbon.add_child(text_box)

	_type_label = Label.new()
	_type_label.name = "TypeLabel"
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_label.clip_text = true
	_type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_type_label.add_theme_font_size_override("font_size", 11)
	_type_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	text_box.add_child(_type_label)

	_effect_label = Label.new()
	_effect_label.name = "EffectLabel"
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_label.custom_minimum_size = Vector2(0, 28)
	_effect_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_effect_label.max_lines_visible = 2
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.clip_text = true
	_effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_effect_label.add_theme_font_size_override("font_size", 12)
	_effect_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	text_box.add_child(_effect_label)

	_disabled_reason_label = Label.new()
	_disabled_reason_label.name = "DisabledReasonLabel"
	_disabled_reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disabled_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disabled_reason_label.add_theme_font_size_override("font_size", 11)
	_disabled_reason_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.58))
	_disabled_reason_label.visible = false
	text_box.add_child(_disabled_reason_label)


func _refresh_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.14, 0.94)
	style.border_color = NORMAL_BORDER_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	if is_disabled():
		style.bg_color = Color(0.13, 0.10, 0.10)
		style.border_color = DISABLED_BORDER_COLOR
	elif _selected:
		style.border_color = SELECTED_BORDER_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	add_theme_stylebox_override("panel", style)


func _ribbon_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 5
	style.content_margin_top = 3
	style.content_margin_right = 5
	style.content_margin_bottom = 3
	return style


func _card_name_text(value) -> String:
	if value == null:
		return ""
	if value.has_method("get_display_name"):
		return str(value.call("get_display_name"))
	return str(value)


func _card_type_text(value) -> String:
	if value == null:
		return ""
	var parts: Array[String] = []
	if value.has_method("rarity_label"):
		parts.append(str(value.call("rarity_label")))
	if value.has_method("target_label"):
		parts.append(str(value.call("target_label")))
	return " / ".join(parts)


func _card_effect_text(value) -> String:
	if value == null:
		return ""
	if value.has_method("effect_summary_text"):
		return str(value.call("effect_summary_text")).strip_edges()
	return ""


func _default_tooltip_text(value, effective_cost: int, summary: String) -> String:
	var lines: Array[String] = [_card_name_text(value), "费用：%d" % effective_cost]
	if summary.strip_edges() != "":
		lines.append(summary)
	return "\n".join(lines)


func _compact_text(value: String, limit: int) -> String:
	var line_limit := maxi(18, mini(42, int(limit / 3)))
	var lines: Array[String] = []
	for raw_line in value.replace("\r\n", "\n").split("\n", false):
		var line := str(raw_line).strip_edges()
		if line == "":
			continue
		if line.length() > line_limit:
			line = line.substr(0, maxi(0, line_limit - 3)) + "..."
		lines.append(line)
		if lines.size() >= 5:
			break
	return "\n".join(lines)


func _on_mouse_entered() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_time_msec < 80:
		return
	_last_hover_time_msec = now
	Sfx.play("card_hover")
