class_name Judge
extends RefCounted

const JudgeResultScript = preload("res://scripts/battle/phigros/stage/judge_result.gd")

const PERFECT_WINDOW_MS := 40
const GOOD_WINDOW_MS := 80
const BAD_WINDOW_MS := 120
const BREAK_WINDOW_SHRINK_MS := 20


func judge_hit(note_time_ms: int, input_time_ms: int, note_kind: String, break_window_active: bool = false):
	var offset := input_time_ms - note_time_ms
	if note_kind != "tap":
		return JudgeResultScript.new("miss", offset)

	var shrink := BREAK_WINDOW_SHRINK_MS if break_window_active else 0
	var perfect_window := maxi(PERFECT_WINDOW_MS - shrink, 0)
	var good_window := maxi(GOOD_WINDOW_MS - shrink, 0)
	var bad_window := maxi(BAD_WINDOW_MS - shrink, 0)
	var abs_offset := absi(offset)
	if abs_offset <= perfect_window:
		return JudgeResultScript.new("perfect", offset)
	if abs_offset <= good_window:
		return JudgeResultScript.new("good", offset)
	if abs_offset <= bad_window:
		return JudgeResultScript.new("bad", offset)
	return JudgeResultScript.new("miss", offset)
