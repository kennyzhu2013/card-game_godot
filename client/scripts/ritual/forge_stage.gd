class_name ForgeStage
extends Node2D

signal forge_chart_finished(player_summary: Dictionary, mouse_summary: Dictionary)
signal dao_heart_checkpoint_reached(checkpoint: float)

const NotePartScene = preload("res://scripts/battle/phigros/phigros_lane/note_part.tscn")
const LaneNotePartScript = preload("res://scripts/battle/phigros/phigros_lane/note_part.gd")
const PhigrosInputRouterScript = preload("res://scripts/battle/phigros/stage/input_router.gd")
const KeyRemapConfigScript = preload("res://scripts/battle/phigros/stage/key_remap_config.gd")
const ChartGeneratorScript = preload("res://scripts/battle/phigros/stage/chart_generator.gd")
const BgmPlayerScript = preload("res://scripts/battle/phigros/stage/bgm_player.gd")

const VIEWPORT := Vector2(960, 540)

const PLAYER_LANE_X := [200.0, 280.0, 360.0, 440.0]
const PLAYER_JUDGE_Y := 470.0
const PLAYER_SPAWN_TOP_Y := 60.0

const MOUSE_LANE_X := [560.0, 660.0, 760.0, 860.0]
const MOUSE_JUDGE_Y := 470.0
const MOUSE_SPAWN_TOP_Y := 60.0
const MOUSE_LANE_HALF_WIDTH := 40.0

const NOTE_TRAVEL_MS := 1500.0
const END_GRACE_MS := 3000
const DAO_HEART_CHECKPOINTS := [0.3, 0.7]

var _player_router = PhigrosInputRouterScript.new()
var _player_notes: Array = []
var _player_summary := _blank_summary()
var _player_active := false

var _mouse_notes: Array = []
var _mouse_summary := _blank_summary()
var _mouse_active := false

var _player_note_layer: Node2D = null
var _mouse_note_layer: Node2D = null
var _player_judge_line: ColorRect = null
var _mouse_judge_line: ColorRect = null
var _player_lane_labels: Array[Label] = []

var _scene_start_ms: int = 0
var _started: bool = false
var _finished: bool = false
var _max_note_time_ms: int = 0
var _bgm_player = null
var _dao_checkpoint_index: int = 0
var _paused_for_dao_question: bool = false
var _pause_started_ms: int = 0
var _pause_accumulated_ms: int = 0

# hit feedback
var _sfx_player: AudioStreamPlayer = null
var _sfx_initialized := false
var _verdict_labels: Array[Label] = []

# combo / progress
var _combo := 0
var _progress_label: Label = null


func _ready() -> void:
	_scene_start_ms = Time.get_ticks_msec()
	_build_visuals()
	_init_sfx()
	_init_bgm()
	_player_router.key_config = KeyRemapConfigScript.new()
	if not _player_router.note_judged.is_connected(_on_player_note_judged):
		_player_router.note_judged.connect(_on_player_note_judged)
	set_process(true)
	set_process_input(true)


func _init_bgm() -> void:
	var bgm_path := "res://assets/audio/bgm/forge_rhythm.wav"
	if not FileAccess.file_exists(bgm_path):
		return
	_bgm_player = BgmPlayerScript.new()
	add_child(_bgm_player)
	_bgm_player.load_stream(bgm_path)


func _init_sfx() -> void:
	if _sfx_initialized:
		return
	_sfx_initialized = true
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.3
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.stream = generator
	_sfx_player.volume_db = -8.0
	_sfx_player.bus = "Master"
	add_child(_sfx_player)
	_sfx_player.play()


func _play_hit_sfx(verdict: String) -> void:
	if _sfx_player == null:
		return
	if not _sfx_player.playing:
		_sfx_player.play()
	var pb := _sfx_player.get_stream_playback()
	if pb == null:
		return
	var freq: float
	var duration: float
	match verdict:
		"perfect": freq = 1200.0; duration = 0.05
		"good":    freq = 800.0;  duration = 0.04
		"bad":     freq = 400.0;  duration = 0.03
		_:         freq = 200.0;  duration = 0.02
	var rate := 44100
	var n := int(rate * duration)
	var buf := PackedVector2Array()
	buf.resize(maxi(1, n))
	for i in range(buf.size()):
		var t := float(i) / rate
		var env := 1.0 - float(i) / float(buf.size())
		var v := sin(2.0 * PI * freq * t) * env * 0.4
		buf[i] = Vector2(v, v)
	pb.push_buffer(buf)


func _show_verdict(verdict: String, x: float, y: float) -> void:
	var lbl := Label.new()
	lbl.position = Vector2(x - 24.0, y - 20.0)
	lbl.size = Vector2(48, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	match verdict:
		"perfect":
			lbl.text = "Perfect"
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
		"good":
			lbl.text = "Good"
			lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		"bad":
			lbl.text = "Bad"
			lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_:
			lbl.text = "Miss"
			lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	add_child(lbl)
	_verdict_labels.append(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position", lbl.position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)


func _flash_judge_line(is_player: bool, verdict: String) -> void:
	var line: ColorRect = _player_judge_line if is_player else _mouse_judge_line
	if line == null:
		return
	var orig := line.color
	var flash: Color
	match verdict:
		"perfect": flash = Color(1.0, 1.0, 0.3, 0.95)
		"good":    flash = Color(0.4, 0.9, 1.0, 0.95)
		"bad":     flash = Color(0.7, 0.7, 0.7, 0.95)
		_:         flash = Color(0.9, 0.3, 0.3, 0.95)
	line.color = flash
	var tween := create_tween()
	tween.tween_property(line, "color", orig, 0.15)


func _on_player_note_judged(note_part, verdict: String, _offset_ms: int) -> void:
	if not is_instance_valid(note_part):
		return
	var x: float = PLAYER_LANE_X[clampi(note_part.lane, 0, 3)]
	_show_verdict(verdict, x, PLAYER_JUDGE_Y)
	_flash_judge_line(true, verdict)
	_play_hit_sfx(verdict)
	if verdict == "perfect" or verdict == "good":
		_combo += 1
	else:
		_combo = 0
	note_part.flash_verdict(verdict)
	note_part.queue_free()


func start_forge(player_chart, mouse_chart) -> void:
	_player_summary = _blank_summary()
	_mouse_summary = _blank_summary()
	_combo = 0
	_dao_checkpoint_index = 0
	_paused_for_dao_question = false
	_pause_started_ms = 0
	_pause_accumulated_ms = 0
	_clear_notes()
	_spawn_player_chart(player_chart)
	_spawn_mouse_chart(mouse_chart)
	_player_active = not _player_notes.is_empty()
	_mouse_active = not _mouse_notes.is_empty()
	_started = true
	_finished = false
	if _progress_label:
		_progress_label.visible = true
	if _bgm_player != null and _bgm_player.is_ready():
		_bgm_player.play_loop(-6.0)
	if not _player_active and not _mouse_active:
		_emit_finish()


func _build_visuals() -> void:
	var bg := ColorRect.new()
	bg.size = VIEWPORT
	bg.color = Color(0.075, 0.08, 0.09)
	add_child(bg)

	var divider := ColorRect.new()
	divider.position = Vector2(VIEWPORT.x * 0.5 - 1.0, 60.0)
	divider.size = Vector2(2.0, 440.0)
	divider.color = Color(0.5, 0.5, 0.6, 0.5)
	add_child(divider)

	var player_title := Label.new()
	player_title.text = "心手 (D F J K)"
	player_title.position = Vector2(220.0, 20.0)
	add_child(player_title)

	var mouse_title := Label.new()
	mouse_title.text = "心眼 (鼠标点击)"
	mouse_title.position = Vector2(620.0, 20.0)
	add_child(mouse_title)

	_player_judge_line = ColorRect.new()
	_player_judge_line.position = Vector2(PLAYER_LANE_X[0] - 24.0, PLAYER_JUDGE_Y - 2.0)
	_player_judge_line.size = Vector2(PLAYER_LANE_X[3] - PLAYER_LANE_X[0] + 48.0, 4.0)
	_player_judge_line.color = Color(1, 1, 0.85, 0.92)
	add_child(_player_judge_line)

	_mouse_judge_line = ColorRect.new()
	_mouse_judge_line.position = Vector2(MOUSE_LANE_X[0] - 32.0, MOUSE_JUDGE_Y - 2.0)
	_mouse_judge_line.size = Vector2(MOUSE_LANE_X[3] - MOUSE_LANE_X[0] + 64.0, 4.0)
	_mouse_judge_line.color = Color(0.6, 0.85, 1.0, 0.92)
	add_child(_mouse_judge_line)

	for i in range(4):
		var lbl := Label.new()
		lbl.text = _player_router.key_config.lane_label(i)
		lbl.position = Vector2(PLAYER_LANE_X[i] - 6.0, PLAYER_JUDGE_Y + 10.0)
		add_child(lbl)
		_player_lane_labels.append(lbl)

	_player_note_layer = Node2D.new()
	_player_note_layer.name = "PlayerNoteLayer"
	add_child(_player_note_layer)

	_mouse_note_layer = Node2D.new()
	_mouse_note_layer.name = "MouseNoteLayer"
	add_child(_mouse_note_layer)

	_progress_label = Label.new()
	_progress_label.text = "0 / 0"
	_progress_label.position = Vector2(VIEWPORT.x * 0.5 - 40.0, VIEWPORT.y - 30.0)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.visible = false
	add_child(_progress_label)


func _spawn_player_chart(chart) -> void:
	if chart == null or chart.notes == null:
		return
	for note in chart.notes:
		var np = NotePartScene.instantiate()
		_player_note_layer.add_child(np)
		np.setup(int(note.id), int(note.time_ms), int(note.lane), 1)
		np.position = Vector2(PLAYER_LANE_X[note.lane], PLAYER_SPAWN_TOP_Y)
		_player_notes.append(np)
		_max_note_time_ms = maxi(_max_note_time_ms, int(note.time_ms))
	var by_lane: Dictionary = {0: [], 1: [], 2: [], 3: []}
	for np in _player_notes:
		by_lane[np.lane].append(np)
	for lane in by_lane.keys():
		_player_router.set_lane_notes(int(lane), by_lane[lane])


func _spawn_mouse_chart(chart) -> void:
	if chart == null or chart.notes == null:
		return
	for note in chart.notes:
		var np = NotePartScene.instantiate()
		np.modulate = Color(0.6, 0.85, 1.0)
		_mouse_note_layer.add_child(np)
		np.setup(int(note.id) + 100000, int(note.time_ms), int(note.lane), 1)
		np.position = Vector2(MOUSE_LANE_X[note.lane], MOUSE_SPAWN_TOP_Y)
		_mouse_notes.append(np)
		_max_note_time_ms = maxi(_max_note_time_ms, int(note.time_ms))


func _process(delta: float) -> void:
	if not _started or _finished:
		return
	if _paused_for_dao_question:
		return
	var now := _elapsed_ms()
	_update_note_positions(_player_notes, PLAYER_LANE_X, PLAYER_SPAWN_TOP_Y, PLAYER_JUDGE_Y, now)
	_update_note_positions(_mouse_notes, MOUSE_LANE_X, MOUSE_SPAWN_TOP_Y, MOUSE_JUDGE_Y, now)
	_resolve_player_misses(now)
	_resolve_mouse_misses(now)
	_update_progress_label()
	if _maybe_pause_for_dao_checkpoint():
		return
	if _all_judged():
		_emit_finish()
		return
	if _max_note_time_ms > 0 and now > _max_note_time_ms + LaneNotePartScript.BAD_WINDOW_MS + END_GRACE_MS:
		print("[forge_stage] timeout: now=%d max_note=%d" % [now, _max_note_time_ms])
		_force_finish_remaining(now)


func _update_progress_label() -> void:
	if _progress_label == null or not _progress_label.visible:
		return
	var total := _total_notes()
	var judged := _total_judged()
	_progress_label.text = "%d / %d" % [judged, total]


func _total_notes() -> int:
	return _player_notes.size() + _mouse_notes.size()


func _total_judged() -> int:
	var n := 0
	for np in _player_notes:
		if not is_instance_valid(np) or np.judged:
			n += 1
	for np in _mouse_notes:
		if not is_instance_valid(np) or np.judged:
			n += 1
	return n


func _force_finish_remaining(now: int) -> void:
	for np in _player_notes:
		if is_instance_valid(np) and not np.judged:
			np.mark_miss()
			np.flash_verdict("miss")
			np.queue_free()
			_record(_player_summary, "miss")
			_show_verdict("miss", PLAYER_LANE_X[clampi(np.lane, 0, 3)], PLAYER_JUDGE_Y)
	for np in _mouse_notes:
		if is_instance_valid(np) and not np.judged:
			np.mark_miss()
			np.flash_verdict("miss")
			np.queue_free()
			_record(_mouse_summary, "miss")
			_show_verdict("miss", MOUSE_LANE_X[clampi(np.lane, 0, 3)], MOUSE_JUDGE_Y)
	_emit_finish()


func _input(event: InputEvent) -> void:
	if not _started or _finished:
		return
	var now := _elapsed_ms()
	if event is InputEventKey and event.pressed and not event.echo:
		var result: Dictionary = _player_router.handle_keycode(event.keycode, now)
		if result.has("verdict"):
			_record(_player_summary, String(result["verdict"]))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.position, now)


func _handle_mouse_click(mouse_pos: Vector2, now: int) -> void:
	var local_pos := to_local(mouse_pos)
	var lane := _mouse_lane_for_x(local_pos.x)
	if lane < 0:
		return
	var best = null
	var best_abs := LaneNotePartScript.BAD_WINDOW_MS + 1
	for np in _mouse_notes:
		if not is_instance_valid(np) or np.judged or np.lane != lane:
			continue
		var abs_offset := absi(now - int(np.note_time_ms))
		if abs_offset <= LaneNotePartScript.BAD_WINDOW_MS and abs_offset < best_abs:
			best = np
			best_abs = abs_offset
	if best == null:
		return
	var verdict: String = best.judge_at(now, false)
	if verdict == "":
		return
	_record(_mouse_summary, verdict)
	var x: float = MOUSE_LANE_X[clampi(best.lane, 0, 3)]
	_show_verdict(verdict, x, MOUSE_JUDGE_Y)
	_flash_judge_line(false, verdict)
	_play_hit_sfx(verdict)
	if verdict == "perfect" or verdict == "good":
		_combo += 1
	else:
		_combo = 0
	best.flash_verdict(verdict)
	best.queue_free()


func _mouse_lane_for_x(x: float) -> int:
	for i in range(MOUSE_LANE_X.size()):
		if absf(x - MOUSE_LANE_X[i]) <= MOUSE_LANE_HALF_WIDTH:
			return i
	return -1


func _update_note_positions(notes: Array, lane_x: Array, top_y: float, judge_y: float, now: int) -> void:
	for np in notes:
		if not is_instance_valid(np) or np.judged:
			continue
		var travel := float(now - (int(np.note_time_ms) - NOTE_TRAVEL_MS))
		var f := clampf(travel / NOTE_TRAVEL_MS, 0.0, 1.2)
		np.position.y = lerpf(top_y, judge_y, f)


func _resolve_player_misses(now: int) -> void:
	var missed: Array = _player_router.resolve_misses_until(now)
	for np in missed:
		_record(_player_summary, "miss")
		if is_instance_valid(np):
			_show_verdict("miss", PLAYER_LANE_X[clampi(np.lane, 0, 3)], PLAYER_JUDGE_Y)
			np.flash_verdict("miss")
		_combo = 0


func _resolve_mouse_misses(now: int) -> void:
	for np in _mouse_notes:
		if not is_instance_valid(np) or np.judged:
			continue
		if now > int(np.note_time_ms) + LaneNotePartScript.BAD_WINDOW_MS:
			np.mark_miss()
			_show_verdict("miss", MOUSE_LANE_X[clampi(np.lane, 0, 3)], MOUSE_JUDGE_Y)
			np.flash_verdict("miss")
			np.queue_free()
			_record(_mouse_summary, "miss")
			_combo = 0


func _all_judged() -> bool:
	for np in _player_notes:
		if is_instance_valid(np) and not np.judged:
			return false
	for np in _mouse_notes:
		if is_instance_valid(np) and not np.judged:
			return false
	return true


func _emit_finish() -> void:
	if _finished:
		return
	_finished = true
	_started = false
	if _bgm_player != null:
		_bgm_player.stop()
	if _progress_label:
		_progress_label.visible = false
	forge_chart_finished.emit(_player_summary.duplicate(true), _mouse_summary.duplicate(true))


func is_paused_for_dao_question() -> bool:
	return _paused_for_dao_question


func resume_after_dao_question() -> void:
	if not _paused_for_dao_question:
		return
	_pause_accumulated_ms += Time.get_ticks_msec() - _pause_started_ms
	_pause_started_ms = 0
	_paused_for_dao_question = false


func finish_with_current_rating() -> void:
	if _paused_for_dao_question:
		_pause_accumulated_ms += Time.get_ticks_msec() - _pause_started_ms
		_pause_started_ms = 0
		_paused_for_dao_question = false
	_emit_finish()


func _maybe_pause_for_dao_checkpoint() -> bool:
	if _dao_checkpoint_index >= DAO_HEART_CHECKPOINTS.size():
		return false
	var total := _total_notes()
	if total <= 0:
		return false
	var checkpoint: float = float(DAO_HEART_CHECKPOINTS[_dao_checkpoint_index])
	var progress := float(_total_judged()) / float(total)
	if progress < checkpoint:
		return false
	_dao_checkpoint_index += 1
	_paused_for_dao_question = true
	_pause_started_ms = Time.get_ticks_msec()
	dao_heart_checkpoint_reached.emit(checkpoint)
	return true


func _record(summary: Dictionary, verdict: String) -> void:
	summary[verdict] = int(summary.get(verdict, 0)) + 1


func _clear_notes() -> void:
	for np in _player_notes:
		if is_instance_valid(np):
			np.queue_free()
	for np in _mouse_notes:
		if is_instance_valid(np):
			np.queue_free()
	_player_notes.clear()
	_mouse_notes.clear()
	_player_router.clear()
	for lbl in _verdict_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_verdict_labels.clear()
	_max_note_time_ms = 0


func _elapsed_ms() -> int:
	var active_pause := 0
	if _paused_for_dao_question and _pause_started_ms > 0:
		active_pause = Time.get_ticks_msec() - _pause_started_ms
	return Time.get_ticks_msec() - _scene_start_ms - _pause_accumulated_ms - active_pause


func _blank_summary() -> Dictionary:
	return {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
