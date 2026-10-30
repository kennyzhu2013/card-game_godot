class_name Chart
extends RefCounted

var duration_ms: float = 0.0
var bpm: float = 0.0
var notes: Array = []
var template_id: String = ""
var modifiers: Dictionary = {}
var choreography: Array = []


func _init(
	p_duration_ms: float = 0.0,
	p_bpm: float = 0.0,
	p_notes: Array = [],
	p_template_id: String = "",
	p_modifiers: Dictionary = {},
	p_choreography: Array = []
) -> void:
	duration_ms = p_duration_ms
	bpm = p_bpm
	notes = p_notes
	template_id = p_template_id
	modifiers = p_modifiers.duplicate(true)
	choreography = p_choreography.duplicate(true)
