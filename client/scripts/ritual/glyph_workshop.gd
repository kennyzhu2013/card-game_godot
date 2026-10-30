extends Control
class_name GlyphWorkshop

const SymbolCardScene = preload("res://scenes/ui/symbol_card.tscn")
const GlyphArrangementScript = preload("res://scripts/ritual/glyph_arrangement.gd")
const SymbolLibraryScript = preload("res://scripts/ritual/symbol_library.gd")
const ReactionTableScript = preload("res://scripts/ritual/reaction_table.gd")
const ReactionEngineScript = preload("res://scripts/ritual/reaction_engine.gd")
const SlotDropTargetScript = preload("res://scripts/ritual/slot_drop_target.gd")
const RitualSymbolScript = preload("res://scripts/ritual/symbol.gd")
const ApServiceScript = preload("res://scripts/state/ap_service.gd")

const REFORGE_MODES := ["default", "keep_brands", "keep_brands_new_slot"]

signal arrangement_confirmed(arrangement: GlyphArrangement)

@onready var _palette_grid: GridContainer = find_child("PaletteGrid", true, false) as GridContainer
@onready var _slot_container: HBoxContainer = find_child("SlotContainer", true, false) as HBoxContainer
@onready var _preview_label: RichTextLabel = find_child("PreviewLabel", true, false) as RichTextLabel
@onready var _confirm_button: Button = find_child("ConfirmButton", true, false) as Button
@onready var _return_button: Button = find_child("ReturnButton", true, false) as Button
@onready var _inventory_status_label: Label = find_child("ForgeInventoryStatus", true, false) as Label

var _pathway: String = ""
var _symbol_library
var _reaction_table
var _reaction_engine
var _arrangement
var _slot_targets: Array = []   # SlotDropTarget panel nodes
var _reforge_button: Button = null
var _reforge_panel: PanelContainer = null
var _reforge_list: VBoxContainer = null
var _reforge_status_label: Label = null
var _selected_reforge_card_id: String = ""
var _selected_reforge_mode: String = "default"


func _ready() -> void:
	_crossfade_bgm("hammer_forge")
	_apply_workbench_styles()
	_connect_window_layout()
	_symbol_library = SymbolLibraryScript.new()
	_symbol_library.load_from_file("res://data/ritual/fool_symbols.json")
	_reaction_table = ReactionTableScript.new()
	_reaction_table.load_from_file("res://data/ritual/fool_reactions.json")
	_reaction_engine = ReactionEngineScript.new(_reaction_table)
	if _confirm_button != null:
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if _return_button != null:
		_return_button.pressed.connect(_on_return_pressed)
	_build_reforge_controls()
	_refresh_reforge_button()
	set_pathway("fool")
	set_arrangement_shape(3)
	_refresh_confirm_button_state()
	_layout_workbench_to_window_size()


func _on_return_pressed() -> void:
	_crossfade_bgm("hub_sanctuary")
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_return_pressed()
		accept_event()


func set_pathway(pathway: String) -> void:
	_pathway = pathway
	_rebuild_palette()


func set_arrangement_shape(capacity: int) -> void:
	var shape: int = GlyphArrangementScript.SHAPE_LINE
	if capacity == 4:
		shape = GlyphArrangementScript.SHAPE_L
	elif capacity == 6:
		shape = GlyphArrangementScript.SHAPE_HEX
	_arrangement = GlyphArrangementScript.new(capacity, shape)
	_rebuild_slots()
	_refresh_confirm_button_state()
	refresh_reaction_preview()


func get_arrangement():
	return _arrangement


func symbol_card_count() -> int:
	if _palette_grid == null:
		return 0
	return _palette_grid.get_child_count()


func place_symbol_in_slot(slot_index: int, symbol_id: String) -> void:
	if _arrangement == null:
		return
	_arrangement.place(slot_index, symbol_id)
	_update_slot_visual(slot_index, symbol_id)


func refresh_reaction_preview() -> void:
	if _arrangement == null or _preview_label == null:
		return
	var reactions: Array = _reaction_engine.compute(_arrangement)
	var lines: Array = []
	for rx in reactions:
		lines.append("[b]%s[/b]：%s（污染 +%d）" % [rx.display_name, rx.description, rx.pollution_delta])
	var total: int = _reaction_engine.total_pollution(_arrangement)
	if total > 0:
		lines.append("")
		lines.append("[color=#ff8866]总污染：+%d[/color]" % total)
	_preview_label.text = "\n".join(lines) if lines.size() > 0 else "（暂无反应）"


func get_reaction_preview_text() -> String:
	if _preview_label == null:
		return ""
	return _preview_label.text


func _rebuild_palette() -> void:
	if _palette_grid == null:
		return
	for child in _palette_grid.get_children():
		child.queue_free()
	var symbols: Array = _symbol_library.list_for_pathway(_pathway)
	for sym in symbols:
		var card = SymbolCardScene.instantiate()
		_palette_grid.add_child(card)
		card.bind_symbol(sym)


func _rebuild_slots() -> void:
	if _slot_container == null:
		return
	for child in _slot_container.get_children():
		child.queue_free()
	_slot_targets.clear()
	for i in range(_arrangement.capacity):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(80, 80)
		slot.set_meta("slot_index", i)
		slot.set_meta("symbol_id", "")
		slot.set_script(SlotDropTargetScript)
		slot.add_theme_stylebox_override("panel", _slot_style(false))
		slot.connect("symbol_dropped", _on_symbol_dropped_to_slot)
		_slot_container.add_child(slot)
		_slot_targets.append(slot)


func _update_slot_visual(slot_index: int, symbol_id: String) -> void:
	if slot_index < 0 or slot_index >= _slot_targets.size():
		return
	var slot = _slot_targets[slot_index]
	slot.set_meta("symbol_id", symbol_id)
	if slot is Panel:
		(slot as Panel).add_theme_stylebox_override("panel", _slot_style(symbol_id != ""))
	for child in slot.get_children():
		child.queue_free()
	if symbol_id == "":
		return
	var sym = _symbol_library.get_by_id(symbol_id)
	if sym == null:
		return
	var label := Label.new()
	label.text = sym.display_name
	label.add_theme_font_size_override("font_size", 32)
	label.anchor_left = 0
	label.anchor_top = 0
	label.anchor_right = 1
	label.anchor_bottom = 1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)


func _on_symbol_dropped_to_slot(slot_index: int, symbol_id: String) -> void:
	place_symbol_in_slot(slot_index, symbol_id)
	refresh_reaction_preview()


func _on_confirm_pressed() -> void:
	if _arrangement == null:
		return
	var gs = _resolve_game_state()
	var spend: Dictionary = ApServiceScript.try_spend_forge(gs, int(_arrangement.capacity))
	if not bool(spend.get("ok", false)):
		_show_ap_gate_message("AP 不足：锻造需要 %d AP" % int(spend.get("cost", 0)))
		_refresh_confirm_button_state()
		return
	arrangement_confirmed.emit(_arrangement)
	if gs != null:
		gs.pending_forge_arrangement = _arrangement.to_dict()
		if _selected_reforge_card_id != "":
			gs.pending_reforge = {"card_id": _selected_reforge_card_id, "mode": _selected_reforge_mode}
		else:
			gs.pending_reforge = {}
	if is_inside_tree() and get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/ritual/forge_phigros.tscn")


func _resolve_game_state():
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	return loop.root.get_node_or_null("GameState")


func _bgm_autoload() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Bgm")


func _crossfade_bgm(track_id: String, duration: float = 1.5) -> void:
	var bgm := _bgm_autoload()
	if bgm != null and bgm.has_method("crossfade_to"):
		bgm.call("crossfade_to", track_id, duration)


func _refresh_confirm_button_state() -> void:
	if _confirm_button == null or _arrangement == null:
		return
	var gs = _resolve_game_state()
	if gs == null:
		return
	var cost: int = ApServiceScript.forge_cost_for_capacity(int(_arrangement.capacity))
	if ApServiceScript.can_afford(gs, cost):
		_confirm_button.disabled = false
		_confirm_button.tooltip_text = "开始锻造（消耗 %d AP）" % cost
	else:
		_confirm_button.disabled = true
		_confirm_button.tooltip_text = "AP 不足：锻造需要 %d AP" % cost
	_refresh_inventory_status(cost)


func _show_ap_gate_message(message: String) -> void:
	if _preview_label != null:
		_preview_label.text = "[color=#ff8866]%s[/color]" % message


func _apply_workbench_styles() -> void:
	_apply_panel_style("ForgeStatusBar", Color(0.055, 0.065, 0.08, 0.96), Color(0.32, 0.43, 0.52, 0.82), 2)
	_apply_panel_style("SymbolPalettePanel", Color(0.07, 0.065, 0.058, 0.96), Color(0.48, 0.38, 0.26, 0.8), 2)
	_apply_panel_style("ArrangementPanel", Color(0.058, 0.07, 0.072, 0.96), Color(0.42, 0.56, 0.52, 0.85), 3)
	_apply_panel_style("ReactionPreviewPanel", Color(0.055, 0.06, 0.075, 0.96), Color(0.36, 0.42, 0.62, 0.78), 2)
	_apply_panel_style("ForgeActionBar", Color(0.075, 0.065, 0.052, 0.98), Color(0.64, 0.48, 0.28, 0.86), 2)

	for node_name in ["ConfirmButton", "ReturnButton", "ReforgeEntryButton"]:
		var button := find_child(node_name, true, false) as Button
		if button == null:
			continue
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 48.0)
		button.focus_mode = Control.FOCUS_ALL
		_apply_button_style(button, node_name == "ConfirmButton")

	for node_name in ["ForgeWorkshopTitle", "PaletteTitle", "ArrangementTitle", "PreviewTitle"]:
		var label := find_child(node_name, true, false) as Label
		if label == null:
			continue
		if node_name == "ForgeWorkshopTitle":
			label.text = "仪式锻造台"
		label.add_theme_font_size_override("font_size", 18 if node_name == "ForgeWorkshopTitle" else 16)
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.68))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)

	for node_name in ["PaletteHint", "ArrangementHint"]:
		var hint := find_child(node_name, true, false) as Label
		if hint != null:
			hint.add_theme_font_size_override("font_size", 14)
			hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.78))

	if _inventory_status_label != null:
		_inventory_status_label.add_theme_font_size_override("font_size", 15)
		_inventory_status_label.add_theme_color_override("font_color", Color(0.82, 0.9, 0.92))
	if _preview_label != null:
		_preview_label.add_theme_font_size_override("normal_font_size", 15)
		_preview_label.add_theme_color_override("default_color", Color(0.88, 0.88, 0.8))


func _connect_window_layout() -> void:
	if is_inside_tree():
		var viewport := get_viewport()
		if viewport != null and not viewport.size_changed.is_connected(_layout_workbench_to_window_size):
			viewport.size_changed.connect(_layout_workbench_to_window_size)
	var window := _root_window()
	if window != null and not window.size_changed.is_connected(_layout_workbench_to_window_size):
		window.size_changed.connect(_layout_workbench_to_window_size)


func _layout_workbench_to_window_size() -> void:
	var window_size := _runtime_window_size()
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = window_size.x
	offset_bottom = window_size.y

	var safe_margin := find_child("ForgeSafeMargin", true, false) as MarginContainer
	if safe_margin != null:
		safe_margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
		safe_margin.offset_left = 0.0
		safe_margin.offset_top = 0.0
		safe_margin.offset_right = window_size.x
		safe_margin.offset_bottom = window_size.y
		var edge := int(maxf(12.0, minf(window_size.x, window_size.y) * 0.025))
		safe_margin.add_theme_constant_override("margin_left", edge)
		safe_margin.add_theme_constant_override("margin_top", edge)
		safe_margin.add_theme_constant_override("margin_right", edge)
		safe_margin.add_theme_constant_override("margin_bottom", edge)


func _runtime_window_size() -> Vector2:
	if is_inside_tree():
		var viewport := get_viewport()
		if viewport != null:
			var visible_size := viewport.get_visible_rect().size
			if visible_size.x > 1.0 and visible_size.y > 1.0:
				return visible_size
	var window := _root_window()
	if window != null and window.size.x > 1 and window.size.y > 1:
		return Vector2(window.size)
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	)


func _root_window() -> Window:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return null


func _apply_panel_style(node_name: String, bg: Color, border: Color, border_width: int) -> void:
	var panel := find_child(node_name, true, false) as PanelContainer
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _panel_style(bg, border, border_width))


func _panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _slot_style(filled: bool) -> StyleBoxFlat:
	var style := _panel_style(
		Color(0.1, 0.105, 0.1, 0.94) if filled else Color(0.045, 0.052, 0.06, 0.94),
		Color(0.72, 0.58, 0.35, 0.9) if filled else Color(0.28, 0.34, 0.4, 0.86),
		2
	)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := _panel_style(bg, border, 2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _apply_button_style(button: Button, primary: bool) -> void:
	if primary:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.38, 0.24, 0.11, 1.0), Color(0.88, 0.58, 0.26, 0.95)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.48, 0.31, 0.14, 1.0), Color(1.0, 0.72, 0.38, 1.0)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.26, 0.16, 0.08, 1.0), Color(0.68, 0.42, 0.22, 1.0)))
	else:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.14, 0.16, 1.0), Color(0.42, 0.5, 0.58, 0.92)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.17, 0.19, 0.21, 1.0), Color(0.62, 0.7, 0.76, 1.0)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.09, 0.1, 1.0), Color(0.36, 0.42, 0.48, 1.0)))
	button.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.86))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.5, 0.52))
	button.add_theme_font_size_override("font_size", 15)


# === 重锻 UI（锻造台入口）===
func _build_reforge_controls() -> void:
	_reforge_button = find_child("ReforgeEntryButton", true, false) as Button
	if _reforge_button != null:
		_reforge_button.text = "重锻已有卡"
		_reforge_button.custom_minimum_size = Vector2(168, 48)
		_reforge_button.focus_mode = Control.FOCUS_ALL
		if not _reforge_button.pressed.is_connected(_show_reforge_picker):
			_reforge_button.pressed.connect(_show_reforge_picker)

	_reforge_status_label = find_child("ReforgeStatusLabel", true, false) as Label
	if _reforge_status_label != null:
		_reforge_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reforge_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_reforge_status_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.46))

	if _reforge_panel != null:
		return

	_reforge_panel = PanelContainer.new()
	_reforge_panel.name = "ReforgePickerPanel"
	_reforge_panel.set_anchors_preset(Control.PRESET_CENTER)
	_reforge_panel.custom_minimum_size = Vector2(520, 360)
	_reforge_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.068, 0.058, 0.98), Color(0.62, 0.46, 0.28, 0.9), 3))
	_reforge_panel.hide()
	add_child(_reforge_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_reforge_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = "选择重锻卡与模式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	root.add_child(title)

	var hint := Label.new()
	hint.text = "选定后回到锻造台排列符号，点击\"确认排列 → 开始锻造\"进入 Phigros 谱面，结束时按所选模式应用重锻。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_reforge_list = VBoxContainer.new()
	_reforge_list.add_theme_constant_override("separation", 6)
	_reforge_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_reforge_list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	var clear_button := Button.new()
	clear_button.text = "取消重锻"
	clear_button.custom_minimum_size.y = 48
	clear_button.pressed.connect(_clear_reforge_selection)
	buttons.add_child(clear_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size.y = 48
	close_button.pressed.connect(_hide_reforge_picker)
	buttons.add_child(close_button)


func _refresh_reforge_button() -> void:
	if _reforge_button == null:
		return
	var state = _resolve_game_state()
	var has_card: bool = state != null and state.cards_inventory.size() > 0
	_reforge_button.disabled = not has_card
	_reforge_button.tooltip_text = "" if has_card else "卡库空，先去锻造或获取卡牌"
	_refresh_reforge_status_label()


func _refresh_reforge_status_label() -> void:
	if _reforge_status_label == null:
		return
	if _selected_reforge_card_id == "":
		_reforge_status_label.text = ""
		return
	var card = _find_inventory_card(_selected_reforge_card_id)
	if card == null:
		_selected_reforge_card_id = ""
		_reforge_status_label.text = ""
		return
	_reforge_status_label.text = "重锻目标：%s · %s" % [_card_label(card), _reforge_mode_label(_selected_reforge_mode)]


func _show_reforge_picker() -> void:
	if _reforge_panel == null or _reforge_list == null:
		return
	for child in _reforge_list.get_children():
		child.queue_free()
	var state = _resolve_game_state()
	if state == null:
		return
	for card in state.cards_inventory:
		if card == null:
			continue
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_theme_constant_override("margin_bottom", 6)
		var brand_summary: String = ", ".join(card.brands) if card.brands.size() > 0 else "无烙印"
		var label := Label.new()
		label.text = "%s · Q%d · %s" % [_card_label(card), int(card.quality), brand_summary]
		row.add_child(label)
		var modes := HBoxContainer.new()
		modes.add_theme_constant_override("separation", 6)
		row.add_child(modes)
		for mode in REFORGE_MODES:
			var button := Button.new()
			button.text = _reforge_mode_label(mode)
			button.custom_minimum_size.y = 44
			var gate: Dictionary = _reforge_mode_availability(card, mode)
			button.disabled = not bool(gate.get("ok", false))
			if not bool(gate.get("ok", false)):
				button.tooltip_text = str(gate.get("reason", ""))
			button.pressed.connect(_on_reforge_choice.bind(card, mode))
			modes.add_child(button)
		_reforge_list.add_child(row)
	_reforge_panel.show()


func _hide_reforge_picker() -> void:
	if _reforge_panel != null:
		_reforge_panel.hide()


func _on_reforge_choice(card, mode: String) -> void:
	_selected_reforge_card_id = str(card.id)
	_selected_reforge_mode = mode
	_hide_reforge_picker()
	_refresh_reforge_status_label()


func _clear_reforge_selection() -> void:
	_selected_reforge_card_id = ""
	_selected_reforge_mode = "default"
	_refresh_reforge_status_label()


func _refresh_inventory_status(cost: int = -1) -> void:
	if _inventory_status_label == null:
		return
	var gs = _resolve_game_state()
	if gs == null:
		_inventory_status_label.text = "符号 / AP"
		return
	if cost < 0 and _arrangement != null:
		cost = ApServiceScript.forge_cost_for_capacity(int(_arrangement.capacity))
	var card_count := int(gs.cards_inventory.size())
	var ap_text := "%d/%d AP" % [int(gs.ap), int(gs.ap_max)]
	_inventory_status_label.text = "%s · 卡库 %d · 本次 %d AP" % [ap_text, card_count, maxi(cost, 0)]


func get_selected_reforge() -> Dictionary:
	if _selected_reforge_card_id == "":
		return {}
	return {"card_id": _selected_reforge_card_id, "mode": _selected_reforge_mode}


func _find_inventory_card(card_id: String):
	var state = _resolve_game_state()
	if state == null:
		return null
	for card in state.cards_inventory:
		if card != null and str(card.id) == card_id:
			return card
	return null


func _card_label(card) -> String:
	if card == null:
		return ""
	return card.get_display_name() if card.has_method("get_display_name") else str(card.template_id)


func _reforge_mode_label(mode: String) -> String:
	match mode:
		"keep_brands":
			return "保留烙印 (+50%材料)"
		"keep_brands_new_slot":
			return "保留+新槽 (+100%材料)"
		_:
			return "默认重锻"


func _reforge_mode_availability(card, mode: String) -> Dictionary:
	match mode:
		"default":
			return {"ok": true}
		"keep_brands":
			if card.brands.size() == 0:
				return {"ok": false, "reason": "无烙印可保留"}
			if int(card.quality) < 4:
				return {"ok": false, "reason": "保留烙印需 ≥ 4 星卡"}
			return {"ok": true}
		"keep_brands_new_slot":
			if card.brands.size() == 0:
				return {"ok": false, "reason": "无烙印可保留"}
			if int(card.quality) < 5:
				return {"ok": false, "reason": "新槽需 5 星卡"}
			return {"ok": true}
		_:
			return {"ok": false, "reason": "未知模式"}
