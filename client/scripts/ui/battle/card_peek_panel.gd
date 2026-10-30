class_name CardPeekPanel
extends Control

var card = null

var _panel: PanelContainer
var _art_rect: TextureRect
var _art_scrim: ColorRect
var _name_label: Label
var _cost_label: Label
var _effect_label: Label


func _init() -> void:
	name = "CardPeekPanel"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()


func show_for(bound_card, effective_cost: int = -1, effect_text: String = "", texture: Texture2D = null) -> void:
	_ensure_ui()
	card = bound_card
	var cost := effective_cost
	if cost < 0 and card != null and card.has_method("get"):
		cost = int(card.get("energy_cost"))
	_name_label.text = _card_name_text(card)
	_cost_label.text = "费用 %d" % cost
	var summary := effect_text.strip_edges()
	if summary == "":
		summary = _card_effect_text(card)
	_effect_label.text = summary
	_effect_label.tooltip_text = summary
	_art_rect.texture = texture
	_art_rect.visible = texture != null
	if _art_scrim != null:
		_art_scrim.visible = texture != null
	visible = true
	move_to_front()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		hide()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _panel == null or not _panel.get_global_rect().has_point(mouse_event.global_position):
				hide()
				accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel") or event.keycode == KEY_ESCAPE:
			hide()
			accept_event()


func _ensure_ui() -> void:
	if _panel != null:
		return
	var center := CenterContainer.new()
	center.name = "CardPeekCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "CardPeekContent"
	_panel.custom_minimum_size = Vector2(380, 560)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.045, 0.06, 0.98), Color(0.62, 0.70, 0.82), 2))
	center.add_child(_panel)

	var stack := Control.new()
	stack.name = "CardPeekStack"
	stack.custom_minimum_size = Vector2(380, 560)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(stack)

	_art_rect = TextureRect.new()
	_art_rect.name = "CardPeekArt"
	_art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_rect.visible = false
	stack.add_child(_art_rect)

	_art_scrim = ColorRect.new()
	_art_scrim.name = "CardPeekArtScrim"
	_art_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_scrim.color = Color(0.015, 0.018, 0.024, 0.34)
	_art_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_scrim.visible = false
	stack.add_child(_art_scrim)

	var margin := MarginContainer.new()
	margin.name = "CardPeekMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	stack.add_child(margin)

	var body := VBoxContainer.new()
	body.name = "CardPeekBody"
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	var header_ribbon := PanelContainer.new()
	header_ribbon.name = "CardPeekHeaderRibbon"
	header_ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_ribbon.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.045, 0.06, 0.78), Color(0.86, 0.74, 0.50, 0.45), 1))
	body.add_child(header_ribbon)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 10)
	header_margin.add_theme_constant_override("margin_top", 8)
	header_margin.add_theme_constant_override("margin_right", 10)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	header_ribbon.add_child(header_margin)
	var header_body := VBoxContainer.new()
	header_body.name = "CardPeekHeaderBody"
	header_body.add_theme_constant_override("separation", 3)
	header_margin.add_child(header_body)

	_name_label = Label.new()
	_name_label.name = "CardPeekNameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 22)
	header_body.add_child(_name_label)

	_cost_label = Label.new()
	_cost_label.name = "CardPeekCostLabel"
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 16)
	header_body.add_child(_cost_label)

	var spacer := Control.new()
	spacer.name = "CardPeekArtReadSpace"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)

	var text_ribbon := PanelContainer.new()
	text_ribbon.name = "CardPeekTextRibbon"
	text_ribbon.custom_minimum_size = Vector2(0, 132)
	text_ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_ribbon.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.045, 0.06, 0.82), Color(0.50, 0.55, 0.64, 0.42), 1))
	body.add_child(text_ribbon)
	var text_margin := MarginContainer.new()
	text_margin.add_theme_constant_override("margin_left", 12)
	text_margin.add_theme_constant_override("margin_top", 10)
	text_margin.add_theme_constant_override("margin_right", 12)
	text_margin.add_theme_constant_override("margin_bottom", 10)
	text_ribbon.add_child(text_margin)

	_effect_label = Label.new()
	_effect_label.name = "CardPeekEffectLabel"
	_effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.clip_text = true
	_effect_label.max_lines_visible = 5
	_effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_effect_label.add_theme_font_size_override("font_size", 15)
	text_margin.add_child(_effect_label)


func _card_name_text(value) -> String:
	if value == null:
		return ""
	if value.has_method("get_display_name"):
		return str(value.call("get_display_name"))
	return str(value)


func _card_effect_text(value) -> String:
	if value == null:
		return ""
	if value.has_method("effect_summary_text"):
		return str(value.call("effect_summary_text")).strip_edges()
	return ""


func _panel_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
