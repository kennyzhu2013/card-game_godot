class_name Note
extends RefCounted

var id: int = 0
var time_ms: int = 0
var lane: int = 0
var kind: String = "tap"
var hold_duration_ms: int = 0
var drag_target_lane: int = -1
var is_super: bool = false
var element_form: String = ""
var judged: bool = false


func _init(
	p_id: int = 0,
	p_time_ms: int = 0,
	p_lane: int = 0,
	p_kind: String = "tap",
	p_hold_duration_ms: int = 0,
	p_drag_target_lane: int = -1,
	p_is_super: bool = false,
	p_element_form: String = ""
) -> void:
	id = p_id
	time_ms = p_time_ms
	lane = clampi(p_lane, 0, 3)
	kind = p_kind
	hold_duration_ms = p_hold_duration_ms
	drag_target_lane = p_drag_target_lane
	is_super = p_is_super
	element_form = p_element_form
