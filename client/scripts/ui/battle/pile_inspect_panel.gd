class_name PileInspectPanel
extends Control

var _panel: PanelContainer
var _title_label: Label
var _rows_box: VBoxContainer
var _close_button: Button


func _init() -> void:
	name = "PileInspectPanel"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_ui()


func show_for(pile_name: String, cards: Array) -> void:
	_ensure_ui()
	_title_label.text = pile_name
	_clear_rows()
	if cards.is_empty():
		_add_empty_row()
	else:
		for card in cards:
			_add_card_row(card)
	visible = true
	move_to_front()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var point := mouse_event.global_position
			if point == Vector2.ZERO:
				point = mouse_event.position
			if _panel == null or not _panel.get_global_rect().has_point(point):
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
	center.name = "PileInspectCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "PileInspectContent"
	_panel.custom_minimum_size = Vector2(620, 420)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.08, 0.10, 0.97), Color(0.58, 0.66, 0.78), 2, 8))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "PileInspectMargin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var body := VBoxContainer.new()
	body.name = "PileInspectBody"
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.name = "PileInspectHeader"
	header.add_theme_constant_override("separation", 8)
	body.add_child(header)

	_title_label = Label.new()
	_title_label.name = "PileInspectTitleLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "PileInspectCloseButton"
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(76, 32)
	_close_button.pressed.connect(hide)
	header.add_child(_close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "PileInspectScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.name = "PileInspectRows"
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)


func _clear_rows() -> void:
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()


func _add_empty_row() -> void:
	var row := _make_row_container()
	var label := Label.new()
	label.name = "PileInspectEmptyLabel"
	label.text = "(empty)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_rows_box.add_child(row)


func _add_card_row(card) -> void:
	var row := _make_row_container()
	var cost := Label.new()
	cost.name = "PileInspectCostLabel"
	cost.text = "Cost %d" % _card_cost(card)
	cost.custom_minimum_size = Vector2(64, 26)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_stylebox_override("normal", _panel_style(Color(0.14, 0.17, 0.22), Color(0.46, 0.54, 0.66), 1, 5))
	row.add_child(cost)

	var text_box := VBoxContainer.new()
	text_box.name = "PileInspectTextBox"
	text_box.add_theme_constant_override("separation", 2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.name = "PileInspectNameLabel"
	name_label.text = _card_name(card)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 15)
	text_box.add_child(name_label)

	var summary_label := Label.new()
	summary_label.name = "PileInspectSummaryLabel"
	summary_label.text = _card_summary(card)
	summary_label.tooltip_text = summary_label.text
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.add_theme_font_size_override("font_size", 13)
	text_box.add_child(summary_label)
	_rows_box.add_child(row)


func _make_row_container() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PileInspectRow"
	row.set_meta("pile_inspect_row", true)
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _card_cost(card) -> int:
	if card == null:
		return 0
	if card.has_method("get"):
		return int(card.get("energy_cost"))
	return int(card.energy_cost)


func _card_name(card) -> String:
	if card == null:
		return ""
	if card.has_method("get_display_name"):
		return str(card.call("get_display_name"))
	return str(card)


func _card_summary(card) -> String:
	if card == null:
		return ""
	if card.has_method("effect_summary_text"):
		return str(card.call("effect_summary_text")).strip_edges()
	return ""


func _panel_style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
