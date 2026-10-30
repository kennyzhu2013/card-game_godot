class_name ArenaPlayZone
extends PanelContainer

const DROP_HIGHLIGHT_NONE := "none"
const DROP_HIGHLIGHT_VALID := "valid"
const DROP_HIGHLIGHT_INVALID := "invalid"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_set_drag_hint_active(false)
	_refresh_panel_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_set_drag_hint_active(true)
	elif what == NOTIFICATION_DRAG_END:
		_set_drag_hint_active(false)
		_set_drop_highlight(DROP_HIGHLIGHT_NONE)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var card = (data as Dictionary).get("card", null) if data is Dictionary else null
	var accepted := _is_battle_card_payload(data) and _is_aoe_target(_card_target(card))
	_set_drop_highlight_from_payload(data, accepted)
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_highlight(DROP_HIGHLIGHT_NONE)
	_set_drag_hint_active(false)
	if not _is_battle_card_payload(data):
		return
	var card = (data as Dictionary).get("card", null)
	if not _is_aoe_target(_card_target(card)):
		return
	_route_card_drop(card, null)


func _is_battle_card_payload(data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == "battle_card" and (data as Dictionary).get("card", null) != null


func _card_target(card) -> String:
	if card == null or not card.has_method("get"):
		return ""
	return str(card.get("target"))


func _is_aoe_target(target: String) -> bool:
	return target in ["all_enemies", "aoe", "field", "deck", "random_enemies"]


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


func _set_drag_hint_active(value: bool) -> void:
	set_meta("drag_hint_active", value)
	var hint := find_child("ArenaPlayZoneDropHint", true, false)
	if hint is Label:
		(hint as Label).visible = value
		(hint as Label).modulate = Color(1, 1, 1, 1.0 if value else 0.4)
	_refresh_panel_style()


func _refresh_panel_style() -> void:
	var state := str(get_meta("drop_highlight_state", DROP_HIGHLIGHT_NONE))
	var dragging := bool(get_meta("drag_hint_active", false))
	var border := Color(0.50, 0.58, 0.68) if dragging else Color(0.30, 0.34, 0.40)
	var width := 2 if dragging else 1
	if state == DROP_HIGHLIGHT_VALID:
		border = Color(0.58, 0.78, 0.46)
		width = 2
	elif state == DROP_HIGHLIGHT_INVALID:
		border = Color(0.86, 0.30, 0.24)
		width = 2
	add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.09, 0.11), border, width))


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
