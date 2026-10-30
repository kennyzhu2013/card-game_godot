class_name Hud
extends Control

var current_pollution_stage: int = 0
var current_pollution_visual: Dictionary = {}
var _bound_game_state = null
var _filter_rect: ColorRect
var _status_bar_rect: ColorRect
var _edge_top_rect: ColorRect
var _edge_bottom_rect: ColorRect
var _edge_left_rect: ColorRect
var _edge_right_rect: ColorRect


func _ready() -> void:
	_ensure_visual_nodes()
	apply_pollution_stage_visual(current_pollution_stage)


func pollution_visual_for_stage(stage: int) -> Dictionary:
	if stage >= 5:
		return {
			"mode": "lost_control",
			"label": "失控",
			"filter_color": Color(0.52, 0.02, 0.04, 0.46),
			"status_bar_color": Color(0.33, 0.02, 0.04, 1.0),
			"edge_color": Color(0.95, 0.03, 0.06, 0.72),
			"edge_intensity": 1.0,
			"shadow_overlay": true,
		}
	var index := clampi(stage, 0, 4)
	var configs := [
		{
			"label": "清醒",
			"filter_color": Color(0.96, 0.97, 0.94, 0.08),
			"status_bar_color": Color(0.13, 0.15, 0.16, 1.0),
			"edge_color": Color(0.30, 0.36, 0.38, 0.10),
			"edge_intensity": 0.0,
		},
		{
			"label": "旧名",
			"filter_color": Color(0.70, 0.76, 0.80, 0.13),
			"status_bar_color": Color(0.16, 0.20, 0.22, 1.0),
			"edge_color": Color(0.42, 0.50, 0.55, 0.18),
			"edge_intensity": 0.18,
		},
		{
			"label": "倒影",
			"filter_color": Color(0.45, 0.38, 0.62, 0.20),
			"status_bar_color": Color(0.19, 0.16, 0.27, 1.0),
			"edge_color": Color(0.42, 0.30, 0.62, 0.28),
			"edge_intensity": 0.34,
		},
		{
			"label": "钟摆",
			"filter_color": Color(0.64, 0.30, 0.25, 0.27),
			"status_bar_color": Color(0.30, 0.15, 0.14, 1.0),
			"edge_color": Color(0.76, 0.22, 0.16, 0.36),
			"edge_intensity": 0.56,
		},
		{
			"label": "半月",
			"filter_color": Color(0.28, 0.12, 0.20, 0.34),
			"status_bar_color": Color(0.15, 0.07, 0.12, 1.0),
			"edge_color": Color(0.55, 0.08, 0.22, 0.48),
			"edge_intensity": 0.82,
		},
	]
	return configs[index].duplicate(true)


func apply_pollution_stage_visual(stage: int) -> Dictionary:
	current_pollution_stage = clampi(stage, 0, 5)
	current_pollution_visual = pollution_visual_for_stage(current_pollution_stage)
	_ensure_visual_nodes()
	_apply_visual_to_nodes(current_pollution_visual)
	return current_pollution_visual.duplicate(true)


func bind_game_state(game_state) -> void:
	if _bound_game_state != null and is_instance_valid(_bound_game_state) and _bound_game_state.has_signal("pollution_stage_changed"):
		var old_callable := Callable(self, "_on_pollution_stage_changed")
		if _bound_game_state.is_connected("pollution_stage_changed", old_callable):
			_bound_game_state.disconnect("pollution_stage_changed", old_callable)
	_bound_game_state = game_state
	if _bound_game_state == null:
		return
	if _bound_game_state.has_signal("pollution_stage_changed"):
		var callback := Callable(self, "_on_pollution_stage_changed")
		if not _bound_game_state.is_connected("pollution_stage_changed", callback):
			_bound_game_state.connect("pollution_stage_changed", callback)
	if _bound_game_state.has_method("get"):
		apply_pollution_stage_visual(int(_bound_game_state.get("pollution_stage")))


func _on_pollution_stage_changed(_from_stage: int, to_stage: int) -> void:
	apply_pollution_stage_visual(to_stage)


func _ensure_visual_nodes() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_filter_rect = _ensure_color_rect("PollutionFilter")
	_status_bar_rect = _ensure_color_rect("PollutionStatusBar")
	_edge_top_rect = _ensure_color_rect("PollutionEdgeTop")
	_edge_bottom_rect = _ensure_color_rect("PollutionEdgeBottom")
	_edge_left_rect = _ensure_color_rect("PollutionEdgeLeft")
	_edge_right_rect = _ensure_color_rect("PollutionEdgeRight")
	_configure_full_rect(_filter_rect)
	_configure_top_bar(_status_bar_rect)
	_configure_edge(_edge_top_rect, "top")
	_configure_edge(_edge_bottom_rect, "bottom")
	_configure_edge(_edge_left_rect, "left")
	_configure_edge(_edge_right_rect, "right")


func _ensure_color_rect(node_name: String) -> ColorRect:
	var existing := get_node_or_null(node_name)
	if existing is ColorRect:
		return existing as ColorRect
	var rect := ColorRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _configure_full_rect(rect: Control) -> void:
	if rect == null:
		return
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0


func _configure_top_bar(rect: Control) -> void:
	if rect == null:
		return
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 1.0
	rect.anchor_bottom = 0.0
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 10.0


func _configure_edge(rect: Control, edge: String) -> void:
	if rect == null:
		return
	match edge:
		"top":
			rect.anchor_left = 0.0
			rect.anchor_top = 0.0
			rect.anchor_right = 1.0
			rect.anchor_bottom = 0.0
			rect.offset_left = 0.0
			rect.offset_top = 0.0
			rect.offset_right = 0.0
			rect.offset_bottom = 18.0
		"bottom":
			rect.anchor_left = 0.0
			rect.anchor_top = 1.0
			rect.anchor_right = 1.0
			rect.anchor_bottom = 1.0
			rect.offset_left = 0.0
			rect.offset_top = -18.0
			rect.offset_right = 0.0
			rect.offset_bottom = 0.0
		"left":
			rect.anchor_left = 0.0
			rect.anchor_top = 0.0
			rect.anchor_right = 0.0
			rect.anchor_bottom = 1.0
			rect.offset_left = 0.0
			rect.offset_top = 0.0
			rect.offset_right = 18.0
			rect.offset_bottom = 0.0
		"right":
			rect.anchor_left = 1.0
			rect.anchor_top = 0.0
			rect.anchor_right = 1.0
			rect.anchor_bottom = 1.0
			rect.offset_left = -18.0
			rect.offset_top = 0.0
			rect.offset_right = 0.0
			rect.offset_bottom = 0.0


func _apply_visual_to_nodes(visual: Dictionary) -> void:
	var filter_color: Color = visual.get("filter_color", Color.TRANSPARENT)
	var status_color: Color = visual.get("status_bar_color", Color.TRANSPARENT)
	var edge_color: Color = visual.get("edge_color", Color.TRANSPARENT)
	if _filter_rect != null:
		_filter_rect.color = filter_color
	if _status_bar_rect != null:
		_status_bar_rect.color = status_color
	for rect in [_edge_top_rect, _edge_bottom_rect, _edge_left_rect, _edge_right_rect]:
		if rect != null:
			rect.color = edge_color
