class_name JudgeResult
extends RefCounted

var verdict: String = "miss"
var offset_ms: Variant = null
var note_id: int = -1


func _init(p_verdict: String = "miss", p_offset_ms: Variant = null, p_note_id: int = -1) -> void:
	verdict = p_verdict
	offset_ms = p_offset_ms
	note_id = p_note_id
