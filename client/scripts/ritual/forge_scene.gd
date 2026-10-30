class_name ForgeScene
extends Node2D

signal forge_completed(perfect_rate: float, total_notes: int)
signal dao_heart_question_shown(checkpoint: float)
signal return_requested
signal forge_aborted

const ForgeStageScript = preload("res://scripts/ritual/forge_stage.gd")
const ChartGeneratorScript = preload("res://scripts/battle/phigros/stage/chart_generator.gd")
const ReactionEngineScript = preload("res://scripts/ritual/reaction_engine.gd")
const ReactionTableScript = preload("res://scripts/ritual/reaction_table.gd")
const SkillLibraryScript = preload("res://scripts/combat/skill_library.gd")
const GlyphArrangement = preload("res://scripts/ritual/glyph_arrangement.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

const WORKSHOP_SCENE := "res://scenes/hub/hub.tscn"
const BATTLE_SCENE := "res://scenes/combat/atb_battle.tscn"

const MOUSE_NOTE_RATIO := 0.75
const DAO_HEART_OPTIONS := [
	{"id": "hold", "label": "A. 继续坚持", "mark": "★", "perfect_delta": 0.0, "pollution": 0, "finish": false},
	{"id": "shift", "label": "B. 改变思路", "mark": "★★", "perfect_delta": 0.02, "pollution": 0, "finish": false},
	{"id": "give_up", "label": "C. 放弃", "mark": "×", "perfect_delta": -0.05, "pollution": 5, "finish": true},
]

@onready var _ui_layer: CanvasLayer = get_node_or_null("UiLayer") as CanvasLayer
@onready var _title_label: Label = get_node_or_null("UiLayer/UpperPanel/VBox/TitleLabel") as Label
@onready var _arrangement_display: HBoxContainer = get_node_or_null("UiLayer/UpperPanel/VBox/ArrangementDisplay") as HBoxContainer
@onready var _reaction_preview: Label = get_node_or_null("UiLayer/UpperPanel/VBox/ReactionPreview") as Label
@onready var _progress_label: Label = get_node_or_null("UiLayer/UpperPanel/VBox/ProgressLabel") as Label
@onready var _result_panel: PanelContainer = get_node_or_null("UiLayer/ResultPanel") as PanelContainer
@onready var _result_title: Label = get_node_or_null("UiLayer/ResultPanel/VBox/ResultTitle") as Label
@onready var _result_detail: Label = get_node_or_null("UiLayer/ResultPanel/VBox/ResultDetail") as Label
@onready var _equip_buttons: Array[Button] = _collect_equip_buttons()
@onready var _return_button: Button = get_node_or_null("UiLayer/ResultPanel/VBox/ReturnButton") as Button
@onready var _battle_button: Button = get_node_or_null("UiLayer/ResultPanel/VBox/BattleButton") as Button
@onready var _abort_button: Button = get_node_or_null("UiLayer/AbortButton") as Button

var arrangement = null
var reactions: Array = []
var target_reaction_id := ""

var _skill_library = null
var _reaction_table = null
var _game_state = null
var _stage: Node = null
var _finished := false
var _forged_skill = null
var _forged_card = null
var _buttons_connected := false
var _dao_heart_panel: PanelContainer = null
var _dao_heart_title: Label = null
var _dao_heart_body_labels: Array[Label] = []
var _dao_heart_choices: VBoxContainer = null
var _dao_choices: Array = []
var _dao_perfect_delta: float = 0.0
var _dao_finish_early: bool = false
var _dao_pending_checkpoint: float = 0.0
var _top_controls_bar: HBoxContainer = null
var _reforge_entry_button: Button = null
var _reforge_panel: PanelContainer = null
var _reforge_list: VBoxContainer = null
var _reforge_source_card = null
var _reforge_mode: String = "default"
var _ai_gm_service = null


func _ready() -> void:
	_connect_buttons()
	_apply_runtime_ui_styles()
	_layout_runtime_ui()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_layout_runtime_ui):
		viewport.size_changed.connect(_layout_runtime_ui)
	_build_dao_heart_panel()
	if _result_panel != null:
		_result_panel.visible = false
	if _game_state == null:
		_game_state = _resolve_game_state()
	_consume_pending_reforge()
	if arrangement == null:
		_try_load_pending_arrangement()
	if arrangement != null:
		_begin_forge()
	_layout_runtime_ui()


func _collect_equip_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for path in [
		"UiLayer/ResultPanel/VBox/EquipSlots/EquipSlot1",
		"UiLayer/ResultPanel/VBox/EquipSlots/EquipSlot2",
		"UiLayer/ResultPanel/VBox/EquipSlots/EquipSlot3",
		"UiLayer/ResultPanel/VBox/EquipSlots/EquipSlot4",
	]:
		var button := get_node_or_null(str(path)) as Button
		if button != null:
			buttons.append(button)
	return buttons


func setup(p_arrangement, p_reaction_id: String = "", p_skill_library = null, p_reaction_table = null, p_game_state = null) -> void:
	arrangement = p_arrangement
	target_reaction_id = p_reaction_id
	_skill_library = p_skill_library
	_reaction_table = p_reaction_table
	_game_state = p_game_state
	if is_inside_tree() and is_node_ready():
		_begin_forge()


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func _begin_forge() -> void:
	_skill_library = _skill_library if _skill_library != null else _default_skill_library()
	_reaction_table = _reaction_table if _reaction_table != null else _default_reaction_table()
	reactions = _compute_reactions()
	if target_reaction_id == "":
		target_reaction_id = _resolve_target_reaction(reactions)
	if target_reaction_id == "" and reactions.is_empty():
		request_unknown_reaction_ai_gm({"base_damage": 0, "base_status_hint": ""})
	print("[forge] arrangement slots=%s, reactions=%s, target=%s, skill_id=%s" % [
		_arrangement_slots_debug(),
		_reactions_debug(),
		target_reaction_id,
		ForgeResultCalculator.REACTION_TO_SKILL.get(target_reaction_id, "<UNMAPPED>"),
	])
	_render_arrangement()
	_update_reaction_preview()
	_spawn_stage()


func _spawn_stage() -> void:
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	_stage = ForgeStageScript.new()
	add_child(_stage)
	move_child(_stage, 0)
	_layout_runtime_ui()
	_stage.forge_chart_finished.connect(_on_forge_chart_finished)
	if _stage.has_signal("dao_heart_checkpoint_reached"):
		_stage.dao_heart_checkpoint_reached.connect(_on_dao_heart_checkpoint)
	var compile_result: Dictionary = ForgeChartCompiler.compile(arrangement, reactions)
	if String(compile_result.get("template_id", "")) == "":
		_progress_label.text = "阵图未触发反应，无法锻造"
		return
	var generator = ChartGeneratorScript.new()
	var player_chart = generator.generate(
		String(compile_result.get("template_id", "")),
		compile_result.get("params", {}),
		int(compile_result.get("momentum", 0))
	)
	var mouse_params: Dictionary = compile_result.get("params", {}).duplicate(true)
	mouse_params["note_count"] = max(1, int(int(mouse_params.get("note_count", 1)) * MOUSE_NOTE_RATIO))
	mouse_params["start_ms"] = int(mouse_params.get("start_ms", 0)) + 250
	var mouse_chart = generator.generate(
		String(compile_result.get("template_id", "")),
		mouse_params,
		int(compile_result.get("momentum", 0))
	)
	_stage.start_forge(player_chart, mouse_chart)
	_progress_label.text = "心手 + 心眼 同步演化中..."
	_layout_runtime_ui()


func _on_forge_chart_finished(player_summary: Dictionary, mouse_summary: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	var combined: Dictionary = {
		"perfect": int(player_summary.get("perfect", 0)) + int(mouse_summary.get("perfect", 0)),
		"good":    int(player_summary.get("good", 0))    + int(mouse_summary.get("good", 0)),
		"bad":     int(player_summary.get("bad", 0))     + int(mouse_summary.get("bad", 0)),
		"miss":    int(player_summary.get("miss", 0))    + int(mouse_summary.get("miss", 0)),
	}
	var total: int = int(combined.perfect) + int(combined.good) + int(combined.bad) + int(combined.miss)
	var raw_perfect_rate: float = 0.0 if total <= 0 else float(combined.perfect) / float(total)
	var perfect_rate: float = apply_dao_heart_to_perfect_rate(raw_perfect_rate)
	forge_completed.emit(perfect_rate, total)
	_progress_label.text = "锻造完成！综合完美率 %.0f%%" % (perfect_rate * 100.0)
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
		_stage = null
	var forged_result: Dictionary = ForgeResultCalculator.forge(
		target_reaction_id,
		perfect_rate,
		arrangement,
		_skill_library,
		_resolve_game_state(_game_state)
	)
	var did_reforge := _apply_reforge_if_selected(forged_result, perfect_rate)
	if not did_reforge:
		_commit_forged_card(forged_result)
		forged_result["brand_dropped"] = _commit_forge_brand(forged_result, perfect_rate) != null
	forged_result["combined_summary"] = combined
	forged_result["raw_perfect_rate"] = raw_perfect_rate
	forged_result["perfect_rate"] = perfect_rate
	forged_result["dao_choices"] = get_dao_choices()
	forged_result["dao_perfect_delta"] = _dao_perfect_delta
	forged_result["ai_gm_text"] = request_forge_resolve_ai_gm(forged_result)
	_show_result_panel(forged_result)


func _player_total(summary: Dictionary) -> int:
	return int(summary.get("perfect", 0)) + int(summary.get("good", 0)) + int(summary.get("bad", 0)) + int(summary.get("miss", 0))


func set_game_state(game_state) -> void:
	_game_state = game_state


func show_dao_heart_question(checkpoint: float) -> void:
	if _dao_heart_panel == null:
		_build_dao_heart_panel()
	_dao_pending_checkpoint = checkpoint
	_dao_heart_title.text = "道心问答 %.0f%%" % (checkpoint * 100.0)
	var preview_rate := _current_dao_preview_rate()
	var line_texts := [
		"当前 perfect_rate：%.2f" % preview_rate,
		"评级预测：%s" % _quality_preview_text(preview_rate),
		"A：维持",
		"B：稳一手 +0.02 perfect_rate，记 ★★",
		"C：放弃，立刻按 ★★★ 出货，污染 +5",
	]
	for i in range(min(_dao_heart_body_labels.size(), line_texts.size())):
		_dao_heart_body_labels[i].text = str(line_texts[i])
	for child in _dao_heart_choices.get_children():
		child.queue_free()
	for i in range(DAO_HEART_OPTIONS.size()):
		var option: Dictionary = DAO_HEART_OPTIONS[i]
		var button := Button.new()
		button.text = str(option.get("label", ""))
		button.custom_minimum_size.y = 40
		button.pressed.connect(answer_dao_heart_option.bind(i))
		_dao_heart_choices.add_child(button)
	_dao_heart_panel.show()
	dao_heart_question_shown.emit(checkpoint)


func answer_dao_heart_option(index: int) -> bool:
	if index < 0 or index >= DAO_HEART_OPTIONS.size():
		return false
	var option: Dictionary = DAO_HEART_OPTIONS[index]
	_dao_choices.append(str(option.get("mark", "★")))
	_dao_perfect_delta += float(option.get("perfect_delta", 0.0))
	var state = _resolve_game_state(_game_state)
	var pollution_delta := int(option.get("pollution", 0))
	if state != null and pollution_delta != 0:
		var next_pollution := int(state.pollution) + pollution_delta
		if state.has_method("set_pollution"):
			state.call("set_pollution", next_pollution, ["forge_dao_choice", str(option.get("id", ""))])
		else:
			state.pollution = clampi(next_pollution, 0, 100)
			state.pollution_stage = _pollution_stage(int(state.pollution))
	_dao_finish_early = bool(option.get("finish", false))
	if _dao_heart_panel != null:
		_dao_heart_panel.hide()
	if _stage != null and is_instance_valid(_stage):
		if _dao_finish_early and _stage.has_method("finish_with_current_rating"):
			_stage.finish_with_current_rating()
		elif _stage.has_method("resume_after_dao_question"):
			_stage.resume_after_dao_question()
	return true


func get_dao_choices() -> Array:
	return _dao_choices.duplicate()


func get_dao_heart_option_count() -> int:
	if _dao_heart_choices == null:
		return 0
	return _dao_heart_choices.get_child_count()


func is_dao_heart_question_visible() -> bool:
	return _dao_heart_panel != null and _dao_heart_panel.visible


func apply_dao_heart_to_perfect_rate(perfect_rate: float) -> float:
	return clampf(perfect_rate + _dao_perfect_delta, 0.0, 1.0)


func _pollution_stage(value: int) -> int:
	if value >= 100:
		return 5
	if value >= 95:
		return 4
	if value >= 80:
		return 3
	if value >= 50:
		return 2
	if value >= 30:
		return 1
	return 0


func _on_dao_heart_checkpoint(checkpoint: float) -> void:
	show_dao_heart_question(checkpoint)


func _build_dao_heart_panel() -> void:
	if _dao_heart_panel != null:
		return
	_dao_heart_panel = PanelContainer.new()
	_dao_heart_panel.name = "DaoHeartQuestionPanel"
	_dao_heart_panel.set_anchors_preset(Control.PRESET_CENTER)
	_dao_heart_panel.custom_minimum_size = Vector2(480, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.055, 0.05, 0.98)
	style.border_color = Color(0.7, 0.55, 0.35, 0.85)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_dao_heart_panel.add_theme_stylebox_override("panel", style)
	var center := CenterContainer.new()
	center.name = "DaoHeartDialogCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(center)
	center.add_child(_dao_heart_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_dao_heart_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_dao_heart_title = Label.new()
	_dao_heart_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dao_heart_title.add_theme_font_size_override("font_size", 18)
	root.add_child(_dao_heart_title)

	var body_box := VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 4)
	root.add_child(body_box)
	_dao_heart_body_labels.clear()
	for i in range(5):
		var line := Label.new()
		line.name = "DaoHeartLine%d" % (i + 1)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_box.add_child(line)
		_dao_heart_body_labels.append(line)

	_dao_heart_choices = VBoxContainer.new()
	_dao_heart_choices.add_theme_constant_override("separation", 8)
	root.add_child(_dao_heart_choices)
	_dao_heart_panel.hide()


func _build_reforge_controls() -> void:
	# 重锻 UI 已迁移到锻造台 (glyph_workshop)，此处保留空函数兼容旧调用。
	pass


func _refresh_reforge_entry() -> void:
	# 重锻按钮已不在 forge_scene。函数保留为兼容入口。
	pass


func _consume_pending_reforge() -> void:
	var state = _resolve_game_state(_game_state)
	if state == null:
		return
	var pending: Dictionary = state.pending_reforge
	if pending.is_empty():
		_reforge_source_card = null
		_reforge_mode = "default"
		return
	var card_id := str(pending.get("card_id", ""))
	var mode := str(pending.get("mode", "default"))
	state.pending_reforge = {}
	if card_id == "":
		return
	for card in state.cards_inventory:
		if card != null and str(card.id) == card_id:
			_reforge_source_card = card
			_reforge_mode = mode
			if _progress_label != null:
				_progress_label.text = "重锻目标：%s · %s" % [_card_label(card), _reforge_mode_label(mode)]
			return


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


func _ensure_top_controls_bar() -> void:
	if _top_controls_bar != null:
		return
	if _ui_layer == null:
		return
	_top_controls_bar = HBoxContainer.new()
	_top_controls_bar.name = "TopControlsBar"
	_top_controls_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_controls_bar.offset_left = 16.0
	_top_controls_bar.offset_top = 16.0
	_top_controls_bar.offset_right = -16.0
	_top_controls_bar.offset_bottom = 64.0
	_top_controls_bar.add_theme_constant_override("separation", 8)
	_ui_layer.add_child(_top_controls_bar)
	if _abort_button != null:
		_abort_button.text = "中断退出"
		_abort_button.custom_minimum_size = Vector2(148, 48)
		_abort_button.focus_mode = Control.FOCUS_ALL
		var abort_parent := _abort_button.get_parent()
		if abort_parent != null and abort_parent != _top_controls_bar:
			abort_parent.remove_child(_abort_button)
		if _abort_button.get_parent() != _top_controls_bar:
			_top_controls_bar.add_child(_abort_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_controls_bar.add_child(spacer)


func _apply_runtime_ui_styles() -> void:
	_ensure_top_controls_bar()
	if _abort_button != null:
		_abort_button.text = "中断退出"
		_abort_button.custom_minimum_size = Vector2(148, 48)
		_abort_button.add_theme_font_size_override("font_size", 15)
		_abort_button.add_theme_color_override("font_color", Color(0.98, 0.9, 0.82))
		_abort_button.add_theme_stylebox_override("normal", _ui_box(Color(0.24, 0.09, 0.07, 0.96), Color(0.78, 0.34, 0.24, 0.95), 2))
		_abort_button.add_theme_stylebox_override("hover", _ui_box(Color(0.34, 0.12, 0.09, 0.98), Color(1.0, 0.52, 0.36, 1.0), 2))
		_abort_button.add_theme_stylebox_override("pressed", _ui_box(Color(0.16, 0.06, 0.05, 1.0), Color(0.64, 0.26, 0.2, 1.0), 2))
	var upper := get_node_or_null("UiLayer/UpperPanel") as PanelContainer
	if upper != null:
		upper.add_theme_stylebox_override("panel", _ui_box(Color(0.045, 0.052, 0.062, 0.88), Color(0.34, 0.44, 0.54, 0.78), 2))
	for label in [_title_label, _reaction_preview, _progress_label]:
		if label == null:
			continue
		label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.86))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", 16)
	for button in [_return_button, _battle_button]:
		if button == null:
			continue
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 48.0)
		button.focus_mode = Control.FOCUS_ALL


func _layout_runtime_ui() -> void:
	var viewport_size := _runtime_viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var safe := maxf(12.0, minf(viewport_size.x, viewport_size.y) * 0.025)
	var top_height := clampf(viewport_size.y * 0.075, 48.0, 58.0)
	var top_reserved := safe + top_height + 6.0

	_ensure_top_controls_bar()
	if _top_controls_bar != null:
		_top_controls_bar.offset_left = safe
		_top_controls_bar.offset_top = safe
		_top_controls_bar.offset_right = -safe
		_top_controls_bar.offset_bottom = safe + 48.0
	if _abort_button != null:
		_abort_button.custom_minimum_size = Vector2(148, 48)

	var upper := get_node_or_null("UiLayer/UpperPanel") as PanelContainer
	if upper != null:
		_set_control_rect(upper, Rect2(Vector2(safe, safe), Vector2(viewport_size.x - safe * 2.0, top_height)))

	if _stage != null and is_instance_valid(_stage):
		var available := Vector2(
			maxf(ForgeStageScript.VIEWPORT.x * 0.5, viewport_size.x - safe * 2.0),
			maxf(ForgeStageScript.VIEWPORT.y * 0.5, viewport_size.y - top_reserved - safe)
		)
		var stage_scale := minf(available.x / ForgeStageScript.VIEWPORT.x, available.y / ForgeStageScript.VIEWPORT.y)
		stage_scale = maxf(0.72, stage_scale)
		_stage.scale = Vector2.ONE * stage_scale
		var stage_size: Vector2 = ForgeStageScript.VIEWPORT * stage_scale
		var stage_pos := Vector2(
			(viewport_size.x - stage_size.x) * 0.5,
			maxf(top_reserved, (viewport_size.y - stage_size.y) * 0.5)
		)
		if stage_pos.y + stage_size.y > viewport_size.y - safe:
			stage_pos.y = viewport_size.y - safe - stage_size.y
		stage_pos.x = clampf(stage_pos.x, safe, maxf(safe, viewport_size.x - safe - stage_size.x))
		stage_pos.y = clampf(stage_pos.y, safe, maxf(safe, viewport_size.y - safe - stage_size.y))
		_stage.global_position = stage_pos

	if _result_panel != null:
		var result_size := Vector2(minf(560.0, viewport_size.x - safe * 2.0), minf(360.0, viewport_size.y - safe * 2.0))
		_result_panel.custom_minimum_size = result_size
		_set_control_rect(_result_panel, Rect2((viewport_size - result_size) * 0.5, result_size))


func _runtime_viewport_size() -> Vector2:
	if is_inside_tree():
		var viewport := get_viewport()
		if viewport != null:
			var visible_size := viewport.get_visible_rect().size
			if visible_size.x > 1.0 and visible_size.y > 1.0:
				return visible_size
	var width := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var height := float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	return Vector2(width, height)


func _set_control_rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


func _ui_box(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _branded_cards() -> Array:
	var state = _resolve_game_state(_game_state)
	if state == null:
		return []
	var result: Array = []
	for card in state.cards_inventory:
		if card != null and card.brands.size() > 0:
			result.append(card)
	return result


func _card_label(card) -> String:
	if card == null:
		return ""
	return card.get_display_name() if card.has_method("get_display_name") else str(card.template_id)


func _reforge_mode_label(mode: String) -> String:
	match mode:
		"keep_brands":
			return "保留烙印"
		"keep_brands_new_slot":
			return "保留+新槽"
		_:
			return "默认重锻"


func _current_dao_preview_rate() -> float:
	if _stage == null or not is_instance_valid(_stage):
		return 0.0
	var perfect := 0
	var total := 0
	for summary in [_stage._player_summary, _stage._mouse_summary]:
		if not summary is Dictionary:
			continue
		perfect += int(summary.get("perfect", 0))
		total += int(summary.get("perfect", 0)) + int(summary.get("good", 0)) + int(summary.get("bad", 0)) + int(summary.get("miss", 0))
	return 0.0 if total <= 0 else float(perfect) / float(total)


func _quality_preview_text(perfect_rate: float) -> String:
	var quality: Dictionary = ForgeResultCalculator.evaluate_quality(apply_dao_heart_to_perfect_rate(perfect_rate))
	var stars := ""
	for i in int(quality.get("stars", quality.get("id", 1))):
		stars += "★"
	return "%s %s" % [stars, str(quality.get("name", ""))]


func _apply_reforge_if_selected(forged_result: Dictionary, perfect_rate: float) -> bool:
	if _reforge_source_card == null:
		return false
	var state = _resolve_game_state(_game_state)
	var new_card = forged_result.get("forged_card", null)
	if state == null or new_card == null:
		return false
	_apply_reforge_base_quality(new_card)
	var old_id := str(_reforge_source_card.id)
	var result: Dictionary = ForgeResultCalculator.reforge_card(
		_reforge_source_card,
		new_card,
		_reforge_mode,
		state,
		perfect_rate >= 0.95
	)
	forged_result["reforge"] = result
	if not bool(result.get("ok", false)):
		return false
	state.remove_card(old_id)
	state.add_card(new_card)
	var discovered_cards: Array = state.daodian.get("discovered_cards", [])
	if not new_card.template_id in discovered_cards:
		discovered_cards.append(new_card.template_id)
	state.daodian["discovered_cards"] = discovered_cards
	_reforge_source_card = null
	_reforge_mode = "default"
	_refresh_reforge_entry()
	return true


func _apply_reforge_base_quality(card) -> void:
	if _reforge_source_card == null or card == null:
		return
	card.quality = int(_reforge_source_card.quality)
	card.rarity = _rarity_for_quality(card.quality)
	card.brand_slots = int(card.quality) + 1 + int(card.upgrade_level)


func _rarity_for_quality(quality: int) -> String:
	match quality:
		5:
			return "legendary"
		4:
			return "epic"
		3:
			return "rare"
		_:
			return "common"


func _show_result_panel(result: Dictionary) -> void:
	_forged_skill = result.get("forged_skill", null)
	_forged_card = result.get("forged_card", null)
	var quality: Dictionary = result.get("quality", {})
	var combined: Dictionary = result.get("combined_summary", {})
	var perfect_rate: float = float(result.get("perfect_rate", 0.0))
	_ensure_result_panel_style()
	_result_panel.modulate.a = 0.0
	_result_panel.visible = true
	_result_title.text = "锻造完成 - %s" % quality.get("name", "未知")
	if _forged_card == null:
		_result_detail.text = "符阵溃散，未凝成卡"
		_result_title.text = "锻造失败"
	else:
		var card_name: String = _forged_card.get_display_name() if _forged_card.has_method("get_display_name") else _forged_card.template_id
		var reaction = _reaction_by_id(target_reaction_id)
		var reaction_name: String = reaction.display_name if reaction != null else target_reaction_id
		_result_detail.text = "%s\n品质:★%d  伤害:%d  能量:%d\n反应:%s  P:%d G:%d B:%d M:%d\n完美率:%.0f%%" % [
			card_name,
			_forged_card.quality,
			_forged_card.damage,
			_forged_card.energy_cost,
			reaction_name,
			int(combined.get("perfect", 0)),
			int(combined.get("good", 0)),
			int(combined.get("bad", 0)),
			int(combined.get("miss", 0)),
			perfect_rate * 100.0,
		]
		var weather_bonus_line := _forge_weather_bonus_line(result)
		if weather_bonus_line != "":
			_result_detail.text += "\n" + weather_bonus_line
		var ai_gm_text := str(result.get("ai_gm_text", "")).strip_edges()
		if ai_gm_text != "":
			_result_detail.text += "\n" + ai_gm_text
	_hide_equip_slots()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_result_panel, "modulate:a", 1.0, 0.3)


func _forge_weather_bonus_line(result: Dictionary) -> String:
	var bonus := int(result.get("forge_weather_bonus_percent", 0))
	if bonus <= 0:
		return ""
	var outputs: Dictionary = result.get("material_outputs", {})
	var detail_text := ""
	for material_name in outputs.keys():
		var modified := int(outputs.get(material_name, 0))
		var base := int(round(float(modified) / (1.0 + float(bonus) / 100.0)))
		if detail_text != "":
			detail_text += "，"
		detail_text += "%s %d→%d" % [str(material_name), base, modified]
	if detail_text == "":
		return "天气加成 +%d%% 锻造材料" % bonus
	return "天气加成 +%d%% 锻造材料（%s）" % [bonus, detail_text]


func _hide_equip_slots() -> void:
	for btn in _equip_buttons:
		btn.visible = false
	var parent := _equip_buttons[0].get_parent() if _equip_buttons.size() > 0 else null
	if parent != null:
		parent.visible = false


func _on_equip_slot_pressed(_slot: int) -> void:
	pass


func _commit_forged_card(result: Dictionary) -> void:
	var card = result.get("forged_card", null)
	if card == null:
		return
	var state = _resolve_game_state(_game_state)
	if state == null:
		return
	state.add_card(card)
	var discovered_cards: Array = state.daodian.get("discovered_cards", [])
	if not card.template_id in discovered_cards:
		discovered_cards.append(card.template_id)
	state.daodian["discovered_cards"] = discovered_cards
	ForgeResultCalculator.deduct_forge_materials(state)


func _commit_forge_brand(result: Dictionary, perfect_rate: float):
	var quality: Dictionary = result.get("quality", {})
	var state = _resolve_game_state(_game_state)
	if state == null:
		return null
	return ForgeResultCalculator.resolve_forge_brand_drop(
		int(quality.get("id", 1)),
		perfect_rate,
		get_dao_choices(),
		state,
		randf(),
		randf()
	)


func _on_return_pressed() -> void:
	return_requested.emit()
	if is_inside_tree() and ResourceLoader.exists(WORKSHOP_SCENE):
		get_tree().change_scene_to_file(WORKSHOP_SCENE)


func _on_abort_pressed() -> void:
	if _finished:
		return
	_finished = true
	if _stage != null and is_instance_valid(_stage):
		if _stage.get_parent() != null:
			_stage.queue_free()
		_stage = null
	if _dao_heart_panel != null:
		_dao_heart_panel.hide()
	if _result_panel != null:
		_result_panel.hide()
	forge_aborted.emit()
	if is_inside_tree():
		_on_return_pressed()


func _on_battle_pressed() -> void:
	if is_inside_tree() and ResourceLoader.exists(BATTLE_SCENE):
		get_tree().change_scene_to_file(BATTLE_SCENE)


func _ensure_result_panel_style() -> void:
	if _result_panel.get_theme_stylebox("panel") == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.08, 0.12, 0.95)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.6, 0.55, 0.3, 0.7)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		_result_panel.add_theme_stylebox_override("panel", sb)


func _connect_buttons() -> void:
	if _buttons_connected:
		return
	for i in range(_equip_buttons.size()):
		if _equip_buttons[i] != null and not _equip_buttons[i].pressed.is_connected(_on_equip_slot_pressed.bind(i)):
			_equip_buttons[i].pressed.connect(_on_equip_slot_pressed.bind(i))
	if _return_button != null and not _return_button.pressed.is_connected(_on_return_pressed):
		_return_button.pressed.connect(_on_return_pressed)
	if _battle_button != null and not _battle_button.pressed.is_connected(_on_battle_pressed):
		_battle_button.pressed.connect(_on_battle_pressed)
	if _abort_button != null:
		if _abort_button.pressed.is_connected(_on_return_pressed):
			_abort_button.pressed.disconnect(_on_return_pressed)
		if not _abort_button.pressed.is_connected(_on_abort_pressed):
			_abort_button.pressed.connect(_on_abort_pressed)
	_buttons_connected = true


func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event.is_action_pressed("ui_cancel") and (_result_panel == null or not _result_panel.visible):
		_on_return_pressed()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _render_arrangement() -> void:
	for child in _arrangement_display.get_children():
		child.queue_free()
	if arrangement == null:
		return
	for i in range(arrangement.capacity):
		var label := Label.new()
		var symbol_id := String(arrangement.get_at(i))
		label.text = "[%s]" % (symbol_id if symbol_id != "" else "-")
		_arrangement_display.add_child(label)


func _update_reaction_preview() -> void:
	var reaction = _reaction_by_id(target_reaction_id)
	var base = _skill_library.get_skill(ForgeResultCalculator.REACTION_TO_SKILL.get(target_reaction_id, ""))
	_title_label.text = "锻造仪式：%s" % (reaction.display_name if reaction != null else target_reaction_id)
	if reaction == null:
		_reaction_preview.text = "反应：%s" % target_reaction_id
		return
	var damage: int = base.damage if base != null else 0
	_reaction_preview.text = "反应：%s → %s  基础伤害 %d" % [
		", ".join(reaction.required_symbols),
		reaction.display_name,
		damage,
	]


func _arrangement_slots_debug() -> String:
	if arrangement == null:
		return "null"
	var ids: Array = []
	for i in range(arrangement.capacity):
		ids.append(String(arrangement.get_at(i)))
	return str(ids)


func _reactions_debug() -> String:
	var ids: Array = []
	for r in reactions:
		ids.append(r.id)
	return str(ids)


func _compute_reactions() -> Array:
	if arrangement == null or _reaction_table == null:
		return []
	return ReactionEngineScript.new(_reaction_table).compute(arrangement)


func request_forge_resolve_ai_gm(result: Dictionary) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "forge_resolve"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"glyph_arrangement": _ai_gm_glyph_arrangement(),
		"primary_source": _ai_gm_primary_source(),
		"reaction_id": str(result.get("reaction_id", target_reaction_id)),
		"perfect_rate": float(result.get("perfect_rate", 0.0)),
		"quality": _ai_gm_quality_id(result.get("quality", 0)),
		"dao_choices": _array(result.get("dao_choices", get_dao_choices())),
		"brand_dropped": bool(result.get("brand_dropped", false)),
	}
	ctx.fallback_template_pool = "FORGE_RESULT_TEMPLATES"
	return _call_ai_gm(ctx)


func request_unknown_reaction_ai_gm(payload: Dictionary = {}) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "unknown_reaction"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"glyph_arrangement": _ai_gm_glyph_arrangement(),
		"base_damage": int(payload.get("base_damage", 0)),
		"base_status_hint": str(payload.get("base_status_hint", "")),
	}
	ctx.fallback_template_pool = "UNKNOWN_REACTION_TEMPLATES"
	return _call_ai_gm(ctx)


func _call_ai_gm(ctx) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var service = _resolve_ai_gm_service()
	if service == null or not service.has_method("call_ai_gm"):
		return ""
	return str(service.call_ai_gm(ctx))


func _resolve_ai_gm_service():
	if _ai_gm_service != null:
		return _ai_gm_service
	_ai_gm_service = AIGMServiceScript.new()
	return _ai_gm_service


func _ai_gm_player_state() -> Dictionary:
	var state = _resolve_game_state(_game_state)
	if state == null:
		return {}
	return {
		"sequence": int(state.sequence),
		"pollution": int(state.pollution),
		"pollution_stage": int(state.pollution_stage),
		"cycle": int(state.cycle),
		"day": int(state.day),
		"time_of_day": str(state.time_of_day),
	}


func _ai_gm_glyph_arrangement() -> Array:
	var result: Array = []
	if arrangement == null:
		return result
	for i in range(int(arrangement.capacity)):
		result.append(str(arrangement.get_at(i)))
	return result


func _ai_gm_primary_source() -> String:
	for symbol_id in _ai_gm_glyph_arrangement():
		if str(symbol_id) != "":
			return str(symbol_id)
	return ""


func _ai_gm_quality_id(value: Variant) -> int:
	if value is Dictionary:
		return int((value as Dictionary).get("id", 0))
	return int(value)


func _array(value: Variant) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _resolve_target_reaction(p_reactions: Array) -> String:
	if p_reactions.is_empty():
		return ""
	return String(p_reactions[0].id)


func _reaction_by_id(reaction_id: String):
	for reaction in reactions:
		if reaction.id == reaction_id:
			return reaction
	if _reaction_table != null:
		for reaction in _reaction_table.all_reactions():
			if reaction.id == reaction_id:
				return reaction
	return null


func _default_reaction_table():
	var table = ReactionTableScript.new()
	table.clear()
	table.load_from_file("res://data/ritual/fool_reactions.json")
	return table


func _default_skill_library():
	var library = SkillLibraryScript.new()
	library._load_all()
	return library


func _try_load_pending_arrangement() -> void:
	var gs = _resolve_game_state(_game_state)
	if gs == null:
		return
	var data: Dictionary = gs.pending_forge_arrangement
	if data.is_empty():
		return
	var arr = GlyphArrangement.new(int(data.get("capacity", 3)), int(data.get("shape", 0)))
	var slots: Array = data.get("slots", [])
	for i in range(min(arr.capacity, slots.size())):
		arr.place(i, str(slots[i]))
	setup(arr, "", _skill_library, _reaction_table, gs)
	gs.pending_forge_arrangement.clear()


func _resolve_game_state(preferred = null):
	if preferred != null:
		return preferred
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	return loop.root.get_node_or_null("GameState")
