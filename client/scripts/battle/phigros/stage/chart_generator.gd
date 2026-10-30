class_name ChartGenerator
extends RefCounted

const ChartScript = preload("res://scripts/battle/phigros/stage/chart.gd")
const NoteScript = preload("res://scripts/battle/phigros/stage/note.gd")


func generate(template_id: String, params: Dictionary, momentum_value: int):
	var notes: Array = []
	match template_id:
		"T1":
			notes = _generate_t1(params, momentum_value)
		"T2":
			notes = _generate_t2(params, momentum_value)
		"T3":
			notes = _generate_t3(params, momentum_value)
		"WHISPER":
			notes = _pattern_single_lane(
				int(params.get("start_ms", 0)),
				_scaled_count(int(params.get("note_count", 4)), momentum_value),
				int(params.get("interval_ms", 600)),
				int(params.get("lane", 1))
			)
		"BREATH":
			notes = _pattern_hold_chain(
				int(params.get("start_ms", 0)),
				int(params.get("hold_count", 3)),
				int(params.get("hold_duration_ms", 2000)),
				int(params.get("gap_ms", 500)),
				int(params.get("lane", 1))
			)
		"WEAVE":
			notes = _pattern_alternating(
				int(params.get("start_ms", 0)),
				_scaled_count(int(params.get("note_count", 6)), momentum_value),
				int(params.get("interval_ms", 200)),
				int(params.get("lane_a", 1)),
				int(params.get("lane_b", 2))
			)
		"MIRROR":
			notes = _pattern_mirror(
				int(params.get("start_ms", 0)),
				_scaled_count(int(params.get("note_count", 4)), momentum_value),
				int(params.get("interval_ms", 250)),
				[int(params.get("outer_lane", 0)), 3 - int(params.get("outer_lane", 0))],
				[int(params.get("inner_lane", 1)), 3 - int(params.get("inner_lane", 1))]
			)
		"PERF":
			notes = _generate_performance(params)
		_:
			notes = []

	var duration_ms := 0.0
	if not notes.is_empty():
		duration_ms = float(notes[-1].time_ms)

	return ChartScript.new(duration_ms, float(params.get("bpm", 0.0)), notes, template_id, {
		"momentum": momentum_value,
		"density_multiplier": _density_multiplier(momentum_value),
	}, _choreography_for(template_id))


func _choreography_for(template_id: String) -> Array:
	match template_id:
		"T2":
			return [
				{"type": "move_y", "offset": -14.0, "duration_ms": 180, "delay_ms": 0},
				{"type": "move_y", "offset": 14.0, "duration_ms": 180, "delay_ms": 180},
				{"type": "move_y", "offset": -14.0, "duration_ms": 180, "delay_ms": 360},
				{"type": "move_y", "offset": 0.0, "duration_ms": 180, "delay_ms": 540},
			]
		"T3":
			return [
				{"type": "move_y", "offset": 36.0, "duration_ms": 80, "delay_ms": 0},
				{"type": "move_y", "offset": 0.0, "duration_ms": 320, "delay_ms": 80},
			]
		"PERF":
			return _performance_choreography()
		"WHISPER":
			return [
				{"type": "move_y", "offset": -8.0, "duration_ms": 800, "delay_ms": 0},
				{"type": "move_y", "offset": 8.0, "duration_ms": 800, "delay_ms": 800},
				{"type": "move_y", "offset": 0.0, "duration_ms": 600, "delay_ms": 1600},
			]
		"BREATH":
			return [
				{"type": "scale_x", "value": 1.08, "duration_ms": 1000, "delay_ms": 0},
				{"type": "scale_x", "value": 0.92, "duration_ms": 1000, "delay_ms": 1000},
				{"type": "scale_x", "value": 1.0, "duration_ms": 500, "delay_ms": 2000},
			]
		"WEAVE":
			return [
				{"type": "rotate", "degrees": 2.0, "duration_ms": 400, "delay_ms": 0},
				{"type": "rotate", "degrees": -2.0, "duration_ms": 400, "delay_ms": 400},
				{"type": "rotate", "degrees": 0.0, "duration_ms": 200, "delay_ms": 800},
			]
		"MIRROR":
			return [
				{"type": "scale_x", "value": 1.1, "duration_ms": 200, "delay_ms": 0},
				{"type": "scale_x", "value": 0.9, "duration_ms": 200, "delay_ms": 200},
				{"type": "scale_x", "value": 1.0, "duration_ms": 100, "delay_ms": 400},
			]
	return []


func _generate_t1(params: Dictionary, momentum_value: int) -> Array:
	var base_count := int(params.get("note_count", 3))
	var count := _scaled_count(base_count, momentum_value)
	var interval_ms := int(params.get("interval_ms", 333))
	var start_ms := int(params.get("start_ms", 0))
	var lane := int(params.get("lane", 0))
	return _pattern_single_lane(start_ms, count, interval_ms, lane)


func _generate_t2(params: Dictionary, momentum_value: int) -> Array:
	var base_count := int(params.get("beat_count", params.get("note_count", 6)))
	var count := _scaled_count(base_count, momentum_value)
	var interval_ms := int(params.get("interval_ms", 240))
	var start_ms := int(params.get("start_ms", 0))
	var lane_pair: Array = params.get("lanes", [0, 3])
	var lane_a := int(lane_pair[0]) if lane_pair.size() > 0 else 0
	var lane_b := int(lane_pair[1]) if lane_pair.size() > 1 else 3
	return _pattern_alternating(start_ms, count, interval_ms, lane_a, lane_b)


func _generate_t3(params: Dictionary, momentum_value: int) -> Array:
	var repeat_count := int(params.get("repeat_count", 1))
	var base_count := repeat_count * 4
	var count := _scaled_count(base_count, momentum_value)
	var interval_ms := int(params.get("interval_ms", 200))
	var start_ms := int(params.get("start_ms", 0))
	var forward := str(params.get("direction", "forward")) != "reverse"
	var lane_order: Array = [0, 1, 2, 3] if forward else [3, 2, 1, 0]
	return _pattern_sweep(start_ms, count, interval_ms, lane_order)


# pattern primitives — 可被多个模板复用的基础节奏构件

func _pattern_single_lane(start_ms: int, count: int, interval_ms: int, lane: int, kind: String = "tap") -> Array:
	var notes: Array = []
	for i in range(count):
		notes.append(NoteScript.new(i, start_ms + i * interval_ms, lane, kind))
	return notes


func _pattern_alternating(start_ms: int, count: int, interval_ms: int, lane_a: int, lane_b: int) -> Array:
	var notes: Array = []
	for i in range(count):
		var lane: int = lane_a if i % 2 == 0 else lane_b
		notes.append(NoteScript.new(i, start_ms + i * interval_ms, lane, "tap"))
	return notes


func _pattern_sweep(start_ms: int, count: int, interval_ms: int, lane_order: Array) -> Array:
	var notes: Array = []
	for i in range(count):
		notes.append(NoteScript.new(i, start_ms + i * interval_ms, int(lane_order[i % lane_order.size()]), "tap"))
	return notes


func _pattern_hold_chain(start_ms: int, count: int, hold_duration_ms: int, gap_ms: int, lane: int) -> Array:
	var notes: Array = []
	var t := start_ms
	for i in range(count):
		var note = NoteScript.new(i, t, lane, "hold")
		note.hold_duration_ms = hold_duration_ms
		notes.append(note)
		t += hold_duration_ms + gap_ms
	return notes


func _pattern_mirror(start_ms: int, beat_count: int, interval_ms: int, outer_pair: Array, inner_pair: Array) -> Array:
	# 每拍两个同步 note，交替 outer / inner pair
	var notes: Array = []
	var id := 0
	for beat in range(beat_count):
		var t := start_ms + beat * interval_ms
		var pair: Array = outer_pair if beat % 2 == 0 else inner_pair
		for lane in pair:
			notes.append(NoteScript.new(id, t, int(lane), "tap"))
			id += 1
	return notes


func _scaled_count(base_count: int, momentum_value: int) -> int:
	var scaled := float(base_count) * _density_multiplier(momentum_value)
	return maxi(int(round(scaled)), 1)


func _density_multiplier(momentum_value: int) -> float:
	if momentum_value < 20:
		return 0.8
	if momentum_value < 60:
		return 1.0
	if momentum_value < 80:
		return 1.2
	return 1.4


func _generate_performance(_params: Dictionary) -> Array:
	# 手编 20s 演出谱，BPM 120（每拍 500ms）。
	# 段落 A (0-4s): 单轨热身 → 交替
	# 段落 B (4-10s): 四轨扫 + 密集交替
	# 段落 C (10-16s): 双押 + 变速
	# 段落 D (16-20s): 高潮全轨乱打
	var notes: Array = []
	var id := 0
	var beat_ms := 667

	# --- A: 热身 (beat 0-7) ---
	for i in range(4):
		notes.append(NoteScript.new(id, 1600 + i * beat_ms, 1, "tap"))
		id += 1
	for i in range(4):
		var lane := 0 if i % 2 == 0 else 3
		notes.append(NoteScript.new(id, 4267 + i * beat_ms, lane, "tap"))
		id += 1

	# --- B: 四轨扫 (beat 8-19) ---
	for rep in range(3):
		for lane in range(4):
			notes.append(NoteScript.new(id, 6933 + rep * 2667 + lane * 240, lane, "tap"))
			id += 1
	# 密集交替
	for i in range(8):
		var lane := 1 if i % 2 == 0 else 2
		notes.append(NoteScript.new(id, 14933 + i * 333, lane, "tap"))
		id += 1

	# --- C: 双押 + 变速 (beat 20-31) ---
	for i in range(6):
		var t := 17600 + i * beat_ms
		notes.append(NoteScript.new(id, t, 0, "tap"))
		id += 1
		notes.append(NoteScript.new(id, t, 3, "tap"))
		id += 1
	# 加速段
	for i in range(8):
		notes.append(NoteScript.new(id, 21600 + i * 267, i % 4, "tap"))
		id += 1

	# --- D: 高潮 (beat 32-39) ---
	var d_lanes: Array = [0, 2, 3, 1, 3, 0, 2, 1, 0, 3, 1, 2, 3, 0, 1, 2]
	for i in range(16):
		notes.append(NoteScript.new(id, 23733 + i * 200, int(d_lanes[i]), "tap"))
		id += 1
	# 终结四连
	for l in range(4):
		notes.append(NoteScript.new(id, 26933, l, "tap"))
		id += 1

	return notes

func generate_duel_chart() -> Array:
	var notes: Array = []
	var interval_ms := 286
	var start_ms := 600
	var lane_pair: Array = [0, 3]
	for i in range(8):
		var lane: int = lane_pair[i % 2]
		notes.append(NoteScript.new(i, start_ms + i * interval_ms, lane, "tap"))
	return notes


func generate_execute_chart_phase(n_axes: int, beat_count: int, interval_ms: int, double_tap: bool = false) -> Array:
	var notes: Array = []
	var start_ms := 600
	var id := 0
	for i in range(beat_count):
		var lane := i % n_axes
		notes.append(_make_lane_note(id, start_ms + i * interval_ms, lane, "tap"))
		id += 1
		if double_tap:
			var alt_lane := (lane + n_axes / 2) % n_axes
			notes.append(_make_lane_note(id, start_ms + i * interval_ms, alt_lane, "tap"))
			id += 1
	return notes


func _make_lane_note(id: int, time_ms: int, lane: int, kind: String):
	var note = NoteScript.new(id, time_ms, lane, kind)
	note.lane = lane
	return note


func _performance_choreography() -> Array:
	# 配合 _generate_performance 的判定线演出编排。
	return [
		# A 段：轻微呼吸
		{"type": "move_y", "offset": -8.0, "duration_ms": 400, "delay_ms": 1200},
		{"type": "move_y", "offset": 8.0, "duration_ms": 400, "delay_ms": 1600},
		{"type": "move_y", "offset": 0.0, "duration_ms": 300, "delay_ms": 2000},

		# B 段入场：旋转 + 缩放
		{"type": "rotate", "degrees": 3.0, "duration_ms": 300, "delay_ms": 5200},
		{"type": "rotate", "degrees": -3.0, "duration_ms": 300, "delay_ms": 5500},
		{"type": "rotate", "degrees": 0.0, "duration_ms": 200, "delay_ms": 5800},
		{"type": "scale_x", "value": 1.15, "duration_ms": 150, "delay_ms": 7200},
		{"type": "scale_x", "value": 1.0, "duration_ms": 150, "delay_ms": 7350},
		# 四轨扫时判定线下沉
		{"type": "move_y", "offset": 20.0, "duration_ms": 500, "delay_ms": 9200},
		{"type": "move_y", "offset": 0.0, "duration_ms": 400, "delay_ms": 9700},

		# C 段：闪烁 + 颜色
		{"type": "alpha", "value": 0.3, "duration_ms": 100, "delay_ms": 13200},
		{"type": "alpha", "value": 1.0, "duration_ms": 100, "delay_ms": 13300},
		{"type": "color_flash", "color": "#ff6644", "duration_ms": 200, "delay_ms": 14200},
		{"type": "color_flash", "color": "#ffffff", "duration_ms": 200, "delay_ms": 14400},
		{"type": "move_y", "offset": -16.0, "duration_ms": 200, "delay_ms": 16200},
		{"type": "move_y", "offset": 16.0, "duration_ms": 200, "delay_ms": 16400},
		{"type": "move_y", "offset": 0.0, "duration_ms": 150, "delay_ms": 16600},

		# D 段高潮：旋转 + 缩放 + 颜色全开
		{"type": "rotate", "degrees": -5.0, "duration_ms": 200, "delay_ms": 17800},
		{"type": "rotate", "degrees": 5.0, "duration_ms": 200, "delay_ms": 18000},
		{"type": "rotate", "degrees": 0.0, "duration_ms": 150, "delay_ms": 18200},
		{"type": "scale_x", "value": 1.3, "duration_ms": 100, "delay_ms": 18800},
		{"type": "color_flash", "color": "#ffdd22", "duration_ms": 150, "delay_ms": 18800},
		{"type": "scale_x", "value": 1.0, "duration_ms": 200, "delay_ms": 18900},
		{"type": "alpha", "value": 0.2, "duration_ms": 80, "delay_ms": 19600},
		{"type": "alpha", "value": 1.0, "duration_ms": 80, "delay_ms": 19680},
		# 终结闪白
		{"type": "color_flash", "color": "#ffffff", "duration_ms": 300, "delay_ms": 20200},
	]
