class_name PhigrosInputRouter
extends RefCounted

signal note_judged(note_part, verdict: String, offset_ms: int)

const KeyRemapConfigScript = preload("res://scripts/battle/phigros/stage/key_remap_config.gd")

const BAD_WINDOW_MS := 120

var key_config: Resource = KeyRemapConfigScript.new()
var break_window_active := false
var _lane_notes: Dictionary = {}


func set_lane_notes(lane_idx: int, note_parts: Array) -> void:
	_lane_notes[lane_idx] = note_parts


func set_lane_count(n: int) -> void:
	if key_config != null and key_config.has_method("set_lane_count"):
		key_config.call("set_lane_count", n)
	clear()


func clear() -> void:
	_lane_notes.clear()
	var count := 4
	if key_config != null:
		var configured_count = key_config.get("lane_count")
		if configured_count != null:
			count = int(configured_count)
	for i in range(count):
		_lane_notes[i] = []


func handle_keycode(keycode: int, input_time_ms: int) -> Dictionary:
	if key_config == null or not key_config.has_method("lane_for_key"):
		return {}
	var lane := int(key_config.call("lane_for_key", keycode))
	if lane < 0:
		return {}
	return judge_lane(lane, input_time_ms)


func handle_input_event(event: InputEvent, input_time_ms: int) -> Dictionary:
	if not (event is InputEventKey):
		return {}
	if event.echo or not event.pressed:
		return {}
	return handle_keycode(event.keycode, input_time_ms)


func judge_lane(lane_idx: int, input_time_ms: int) -> Dictionary:
	var notes: Array = _lane_notes.get(lane_idx, [])
	var best = null
	for np in notes:
		if np == null or np.judged:
			continue
		if absi(input_time_ms - int(np.note_time_ms)) > BAD_WINDOW_MS:
			continue
		if best == null or int(np.note_time_ms) < int(best.note_time_ms):
			best = np
	if best == null:
		return {}
	var verdict: String = best.judge_at(input_time_ms, break_window_active)
	if verdict == "":
		return {}
	var offset := input_time_ms - int(best.note_time_ms)
	note_judged.emit(best, verdict, offset)
	return {"verdict": verdict, "offset_ms": offset, "lane": lane_idx}


func resolve_misses_until(now_ms: int) -> Array:
	var missed: Array = []
	for lane_idx in _lane_notes.keys():
		for np in _lane_notes[lane_idx]:
			if np == null or np.judged:
				continue
			if now_ms - int(np.note_time_ms) > BAD_WINDOW_MS:
				np.mark_miss()
				missed.append(np)
				note_judged.emit(np, "miss", BAD_WINDOW_MS + 1)
	return missed
