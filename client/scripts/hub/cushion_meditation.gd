extends Control

signal meditation_finished(result: Dictionary)

const BreathCircleScript = preload("res://scripts/hub/breath_circle.gd")
const MeditationServiceScript = preload("res://scripts/world/meditation_service.gd")

const BREATH_CYCLES := 6
const BREATH_CYCLE_MS := 5000
const TOTAL_JUDGEMENTS := BREATH_CYCLES * 2

var _game_state = null
var _status_label: Label
var _hint_label: Label
var _result_label: Label
var _hit_button: Button
var _exit_button: Button
var _circle: Control
var _session_started: bool = false
var _settled: bool = false
var _started_ms: int = 0
var _summary: Dictionary = {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
var _next_judgement_for_test: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	set_process(false)
	hide()


func open(game_state = null) -> Dictionary:
	_game_state = game_state if game_state != null else GameState
	var start: Dictionary = MeditationServiceScript.start_session(_game_state)
	_reset_run_state()
	if not bool(start.get("ok", false)):
		_session_started = false
		_status_label.text = _failure_text(str(start.get("reason", "")))
		_hint_label.text = ""
		_result_label.text = ""
		_hit_button.disabled = true
		show()
		return start
	_session_started = true
	_settled = false
	_started_ms = Time.get_ticks_msec()
	_status_label.text = "吸气..."
	_hint_label.text = "圆胀到最大或缩到最小时，按空格或点击判定。"
	_result_label.text = ""
	_hit_button.disabled = false
	show()
	set_process(true)
	_update_breath_visual(0.0)
	return start


func breath_cycle_count() -> int:
	return BREATH_CYCLES


func breath_duration_ms() -> int:
	return BREATH_CYCLES * BREATH_CYCLE_MS


func settle_for_test(summary: Dictionary) -> Dictionary:
	_summary = _normalized_summary(summary)
	return _settle()


func set_next_judgement_for_test(judgement: String) -> void:
	_next_judgement_for_test = judgement


func _process(_delta: float) -> void:
	if not visible or not _session_started or _settled:
		return
	var elapsed := Time.get_ticks_msec() - _started_ms
	var duration := breath_duration_ms()
	var phase := clampf(float(elapsed) / float(duration), 0.0, 1.0)
	_update_breath_visual(phase)
	if elapsed >= duration:
		_pad_missing_judgements()
		_settle()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_on_hit_pressed()
		accept_event()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and int(event.button_index) == MOUSE_BUTTON_LEFT:
		_on_hit_pressed()
		accept_event()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "CushionMeditationPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := Label.new()
	title.text = "蒲团修炼"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_exit_button = Button.new()
	_exit_button.name = "MeditationExitButton"
	_exit_button.text = "退出"
	_exit_button.pressed.connect(_on_exit_pressed)
	header.add_child(_exit_button)

	_status_label = Label.new()
	_status_label.name = "MeditationStatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.name = "MeditationHintLabel"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	_circle = BreathCircleScript.new()
	_circle.name = "BreathCircle"
	_circle.custom_minimum_size = Vector2(260, 260)
	center.add_child(_circle)

	_hit_button = Button.new()
	_hit_button.name = "BreathHitButton"
	_hit_button.text = "按下 / 空格"
	_hit_button.custom_minimum_size = Vector2(180, 42)
	_hit_button.pressed.connect(_on_hit_pressed)
	root.add_child(_hit_button)

	_result_label = Label.new()
	_result_label.name = "MeditationResultLabel"
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_result_label)


func _on_hit_pressed() -> void:
	if not _session_started or _settled:
		return
	var judgement := _next_judgement_for_test
	_next_judgement_for_test = ""
	if judgement == "":
		judgement = _judge_current_phase()
	_record_judgement(judgement)
	_status_label.text = _judgement_text(judgement)
	if _recorded_judgements() >= TOTAL_JUDGEMENTS:
		_settle()


func _on_exit_pressed() -> void:
	_session_started = false
	set_process(false)
	hide()


func _settle() -> Dictionary:
	if not _session_started:
		return {"ok": false, "reason": "session_not_started"}
	_settled = true
	_session_started = false
	set_process(false)
	_hit_button.disabled = true
	var result: Dictionary = MeditationServiceScript.resolve_started_session(_game_state, _summary, {})
	_status_label.text = "修炼结束"
	_result_label.text = _format_result(result)
	meditation_finished.emit(result)
	return result


func _format_result(result: Dictionary) -> String:
	var base_exp := int(result.get("base_sequence_exp", 0))
	var exp_delta := int(result.get("sequence_exp_delta", 0))
	var pollution_delta := int(result.get("pollution_delta", 0))
	var lines: Array[String] = [
		"评级 %s · 序列经验 +%d · 污染 %+d" % [
			str(result.get("rating", "")),
			exp_delta,
			pollution_delta,
		],
	]
	var bonus := int(result.get("sequence_exp_bonus_percent", 0))
	if bonus > 0:
		lines.append("天气加成 +%d%% 序列经验（%d→%d）" % [bonus, base_exp, exp_delta])
	return _join_lines(lines)


func _update_breath_visual(phase: float) -> void:
	var cycle_phase := fmod(phase * float(BREATH_CYCLES), 1.0)
	var wave := 0.5 - cos(cycle_phase * TAU) * 0.5
	if _circle != null and _circle.has_method("set_breath_amount"):
		_circle.set_breath_amount(wave)
	if cycle_phase < 0.5:
		_status_label.text = "吸气..."
	else:
		_status_label.text = "呼气..."


func _judge_current_phase() -> String:
	var elapsed := Time.get_ticks_msec() - _started_ms
	var cycle_pos := posmod(elapsed, BREATH_CYCLE_MS)
	var peak_error: int = abs(cycle_pos - int(BREATH_CYCLE_MS / 2))
	var bottom_error: int = mini(cycle_pos, abs(BREATH_CYCLE_MS - cycle_pos))
	var error: int = mini(peak_error, bottom_error)
	if error <= 150:
		return "perfect"
	if error <= 350:
		return "good"
	if error <= 650:
		return "bad"
	return "miss"


func _record_judgement(judgement: String) -> void:
	match judgement:
		"perfect", "good", "bad", "miss":
			_summary[judgement] = int(_summary.get(judgement, 0)) + 1
		_:
			_summary["miss"] = int(_summary.get("miss", 0)) + 1


func _judgement_text(judgement: String) -> String:
	match judgement:
		"perfect":
			return "正合呼吸"
		"good":
			return "略有偏差"
		"bad":
			return "气息不稳"
		_:
			return "错过节拍"


func _pad_missing_judgements() -> void:
	var missing := maxi(0, TOTAL_JUDGEMENTS - _recorded_judgements())
	_summary["miss"] = int(_summary.get("miss", 0)) + missing


func _recorded_judgements() -> int:
	return int(_summary.get("perfect", 0)) + int(_summary.get("good", 0)) + int(_summary.get("bad", 0)) + int(_summary.get("miss", 0))


func _reset_run_state() -> void:
	_summary = {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
	_next_judgement_for_test = ""
	_settled = false
	set_process(false)


func _normalized_summary(summary: Dictionary) -> Dictionary:
	return {
		"perfect": int(summary.get("perfect", 0)),
		"good": int(summary.get("good", 0)),
		"bad": int(summary.get("bad", 0)),
		"miss": int(summary.get("miss", 0)),
	}


func _failure_text(reason: String) -> String:
	match reason:
		"ap_short":
			return "AP 不足：修炼需要 3 AP"
		"daily_limit":
			return "今日修炼已达 3 次"
		_:
			return "暂时无法修炼"


func _join_lines(lines: Array[String]) -> String:
	var text := ""
	for line in lines:
		if text != "":
			text += "\n"
		text += line
	return text
