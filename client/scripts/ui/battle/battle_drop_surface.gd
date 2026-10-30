class_name BattleDropSurface
extends Control

const DROP_VISUAL_NONE := "none"
const DROP_VISUAL_VALID := "valid"
const DROP_VISUAL_INVALID := "invalid"


func _ready() -> void:
	name = "BattleAoeDropSurface"
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_meta("drop_surface_visual_state", DROP_VISUAL_NONE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_set_drag_routing_active(true)
	elif what == NOTIFICATION_DRAG_END:
		_set_drag_routing_active(false)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var router := _drop_router()
	if router == null or not router.has_method("_can_drop_surface_data"):
		_set_drop_visual(DROP_VISUAL_NONE)
		return false
	var accepted := bool(router.call("_can_drop_surface_data", _global_point(at_position), data))
	var visual_state := DROP_VISUAL_NONE
	if _is_battle_card_payload(data):
		visual_state = DROP_VISUAL_VALID if accepted else DROP_VISUAL_INVALID
	_set_drop_visual(visual_state)
	return accepted


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var router := _drop_router()
	if router == null or not router.has_method("_drop_surface_data"):
		_set_drop_visual(DROP_VISUAL_NONE)
		return
	router.call("_drop_surface_data", _global_point(at_position), data)
	_set_drop_visual(DROP_VISUAL_NONE)


func _draw() -> void:
	var state := str(get_meta("drop_surface_visual_state", DROP_VISUAL_NONE))
	if state == DROP_VISUAL_NONE:
		return
	var border := Color(0.58, 0.78, 0.46, 0.72)
	var fill := Color(0.20, 0.35, 0.18, 0.10)
	if state == DROP_VISUAL_INVALID:
		border = Color(0.86, 0.30, 0.24, 0.72)
		fill = Color(0.42, 0.08, 0.07, 0.10)
	var rect := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 3.0)


func _set_drag_routing_active(active: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	set_meta("drop_surface_armed", active)
	if not active:
		_set_drop_visual(DROP_VISUAL_NONE)


func _set_drop_visual(state: String) -> void:
	var clean_state := state if state in [DROP_VISUAL_VALID, DROP_VISUAL_INVALID] else DROP_VISUAL_NONE
	set_meta("drop_surface_visual_state", clean_state)
	queue_redraw()


func _is_battle_card_payload(data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == "battle_card" and (data as Dictionary).get("card", null) != null


func _global_point(at_position: Vector2) -> Vector2:
	return get_global_rect().position + at_position


func _drop_router() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("_can_drop_surface_data") or current.has_method("_drop_surface_data"):
			return current
		current = current.get_parent()
	return null
