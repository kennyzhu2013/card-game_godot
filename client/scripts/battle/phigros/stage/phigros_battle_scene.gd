class_name PhigrosBattleScene
extends Node2D

signal note_hit(note_id: int, verdict: String, offset_ms: int)
signal chart_finished(summary: Dictionary, target: String)

const BattleLogicScript = preload("res://scripts/battle_logic.gd")
const BattleBridge = preload("res://scripts/battle/phigros/stage/battle_bridge.gd")
const ChartGenerator = preload("res://scripts/battle/phigros/stage/chart_generator.gd")
const InputRouter = preload("res://scripts/battle/phigros/stage/input_router.gd")
const KeyRemapConfig = preload("res://scripts/battle/phigros/stage/key_remap_config.gd")
const EnemyAutoPilot = preload("res://scripts/battle/phigros/stage/enemy_auto_pilot.gd")
const PokemonCharacter = preload("res://scripts/battle/phigros/stage/pokemon_character.gd")
const LaneNotePart = preload("res://scripts/battle/phigros/phigros_lane/note_part.gd")
const NotePartScene = preload("res://scripts/battle/phigros/phigros_lane/note_part.tscn")
const HitEffectsScene = preload("res://scripts/battle/phigros/phigros_lane/hit_effects.tscn")
const TapHitSound = preload("res://assets/audio/phigros/tap.wav")

const VIEWPORT := Vector2(960, 540)
const LANE_X := [288.0, 384.0, 576.0, 672.0]
const JUDGE_LINE_Y := 380.0
const SPAWN_TOP_Y := -40.0
const SPAWN_BOTTOM_Y := 800.0
const NOTE_TRAVEL_MS := 1500
const ENEMY_ATTACK_INTERVAL_MS := 4000
const SWAY_AMPLITUDE := 6.0
const SWAY_PERIOD := 4.0
const JUDGE_LINE_COLOR := Color(1, 1, 1, 0.92)
const QTE_FLASH_COLOR := Color(0.95, 0.85, 0.2, 0.95)
const QTE_FLASH_MS := 500
const PUNISHMENT_DELAY_MS := 600

# D1: main/sub view swap
const ViewLayoutScript = preload("res://scripts/battle/phigros/stage/view_layout.gd")
const SkillIntroAnimatorScript = preload("res://scripts/battle/phigros/stage/skill_intro_animator.gd")
const BeatClockScript = preload("res://scripts/battle/phigros/stage/beat_clock.gd")
const BgmPlayerScript = preload("res://scripts/battle/phigros/stage/bgm_player.gd")
const BreakPerformanceScript = preload("res://scripts/battle/phigros/stage/break_performance.gd")
const MomentumQteDirectorScript = preload("res://scripts/battle/phigros/stage/momentum_qte_director.gd")
const QteChoiceUiScript = preload("res://scripts/battle/phigros/stage/qte_choice_ui.gd")
const DuelDirectorScript = preload("res://scripts/battle/phigros/stage/duel_director.gd")
const ExecuteDirectorScript = preload("res://scripts/battle/phigros/stage/execute_director.gd")
const SWAP_TWEEN_SEC := 0.3
const MAIN_BGM_BPM := 90
const MAIN_BGM_BEAT_MS := 667
const ON_BEAT_WINDOW_MS := 50
const MAIN_BGM_PATH := "res://assets/audio/phigros/battle_bgm.wav"
const DUEL_BGM_PATH := "res://assets/audio/phigros/battle_bgm_duel.wav"
const EXECUTE_BGM_PATH := "res://assets/audio/phigros/battle_bgm_execute.wav"
const COLOR_ON_BEAT := Color(1.0, 0.85, 0.2, 0.95)

# 击破条：判者每次失误/Bad 累积自己的击破值（等于"我没接住对面的攻击"）。
# 满了 → 对应一侧吃一段不计击破的惩罚 chart（防止永动机）。
const BREAK_MAX := 100
const BREAK_PER_MISS := 20
const BREAK_PER_BAD := 8

# 共享势条：tug-of-war 双向取值，正向=玩家优势，负向=敌人优势。
# 每张 chart 完成时，按判者得分推条 (perfect*3 + good*1 + bad*0 + miss*-2)。
const MOMENTUM_RANGE := 100
const SCORE_PERFECT := 3
const SCORE_GOOD := 1
const SCORE_BAD := 0
const SCORE_MISS := -2

const MOMENTUM_BAR_WIDTH := 400.0
const MOMENTUM_BAR_HEIGHT := 16.0
const MOMENTUM_BAR_TOP := 20.0

var _router = InputRouter.new()
var _player_view: Node2D = null     # 容器：玩家角色 + 玩家判定线 + 接攻击 note
var _enemy_view: Node2D = null      # 容器：敌人角色 + 敌人判定线 + 接攻击 note
var _enemy_judge_line: ColorRect = null
var _enemy_note_layer: Node2D = null
var _view_layout = ViewLayoutScript.new()
var _intro_animator = SkillIntroAnimatorScript.new()
var _intro_blocking: bool = false
var _bgm_player: Node = null
var _beat_phase_ms_player_chart: int = 0
var _beat_phase_ms_enemy_chart: int = 0
var _break_performance_active: bool = false
var _qte_active: bool = false
var _qte_director = MomentumQteDirectorScript.new()
var _swap_tween: Tween = null
var _key_config = KeyRemapConfig.new()
var _battle_logic: RefCounted = null
var _bridge = BattleBridge.new()
var _auto_pilot = EnemyAutoPilot.new()
var _player_character: Node2D
var _enemy_character: Node2D
var _note_layer: Node2D
var _hit_effects: Node2D
var _tap_sfx: AudioStreamPlayer
var _judge_line: ColorRect
var _momentum_bar_bg: ColorRect
var _momentum_fill: ColorRect
var _momentum_mid_marker: ColorRect
var _sway_time: float = 0.0
var _choreo_offset: float = 0.0
var _scene_start_ms := 0
var _test_elapsed_ms := -1

var _break_progress: Dictionary = {}
var _shared_momentum: int = 0
var _pending_player_punishment: bool = false
var _pending_enemy_punishment: bool = false
var _top_chart_no_credit: bool = false
var _bottom_chart_no_credit: bool = false
var _top_chart_score: int = 0
var _bottom_chart_score: int = 0

# Enemy attack track (top → judgeline, judged by DFJK via _router):
var _enemy_notes: Array = []
var _enemy_summary := _blank_summary()
var _enemy_active := false
# Player attack track (bottom → judgeline, judged by AI per-note):
var _player_notes: Array = []
var _player_summary := _blank_summary()
var _player_active := false
var _next_enemy_attack_ms := ENEMY_ATTACK_INTERVAL_MS
var _battle_started := false
var _battle_flow_summary := _blank_flow_summary()
var _skill_queue: Array = []


func _ready() -> void:
	_scene_start_ms = Time.get_ticks_msec()
	_build_visuals()
	_router.key_config = _key_config
	if not _router.note_judged.is_connected(_on_note_judged):
		_router.note_judged.connect(_on_note_judged)
	if not _bridge.chart_request.is_connected(_on_bridge_chart_request):
		_bridge.chart_request.connect(_on_bridge_chart_request)
	set_process(true)
	if _player_character != null:
		_player_character.start_bpm_pulse(90)
	if _enemy_character != null:
		_enemy_character.start_bpm_pulse(90)
	_bgm_player = BgmPlayerScript.new()
	_bgm_player.name = "BgmPlayer"
	add_child(_bgm_player)
	_bgm_player.load_stream(MAIN_BGM_PATH)
	_bgm_player.play_loop(-6.0)
	# 音频通路探针：开战时立即播一声 tap，能听到 = 系统音频通畅
	if _tap_sfx != null:
		_tap_sfx.volume_db = -6.0
		_tap_sfx.play()
		print("[phigros] audio probe: tap played, master_db=%s, master_mute=%s" % [str(AudioServer.get_bus_volume_db(0)), str(AudioServer.is_bus_mute(0))])
	start_battle_demo()
	print("[phigros] scene ready, battle_started=%s" % str(_battle_started))


func _build_visuals() -> void:
	var bg := ColorRect.new()
	bg.size = VIEWPORT
	bg.color = Color(0.075, 0.08, 0.09)
	add_child(bg)

	# Momentum / break HUD 不属于任何 view 容器，浮在 scene 根上
	_momentum_bar_bg = ColorRect.new()
	_momentum_bar_bg.position = Vector2(VIEWPORT.x * 0.5 - MOMENTUM_BAR_WIDTH * 0.5, MOMENTUM_BAR_TOP)
	_momentum_bar_bg.size = Vector2(MOMENTUM_BAR_WIDTH, MOMENTUM_BAR_HEIGHT)
	_momentum_bar_bg.color = Color(0.18, 0.18, 0.22, 0.85)
	add_child(_momentum_bar_bg)
	_momentum_fill = ColorRect.new()
	_momentum_fill.position = Vector2(VIEWPORT.x * 0.5, MOMENTUM_BAR_TOP)
	_momentum_fill.size = Vector2(0, MOMENTUM_BAR_HEIGHT)
	_momentum_fill.color = Color(0.4, 0.85, 0.4)
	add_child(_momentum_fill)
	_momentum_mid_marker = ColorRect.new()
	_momentum_mid_marker.position = Vector2(VIEWPORT.x * 0.5 - 1, MOMENTUM_BAR_TOP - 2)
	_momentum_mid_marker.size = Vector2(2, MOMENTUM_BAR_HEIGHT + 4)
	_momentum_mid_marker.color = Color(0.95, 0.9, 0.6, 0.9)
	add_child(_momentum_mid_marker)

	# 玩家视图容器（默认主屏 transform）
	_player_view = Node2D.new()
	_player_view.name = "PlayerView"
	_player_view.transform = _view_layout.target_main_transform()
	_player_view.modulate = Color(1, 1, 1, _view_layout.target_main_alpha())
	add_child(_player_view)

	# 敌人视图容器（默认副屏 transform）
	_enemy_view = Node2D.new()
	_enemy_view.name = "EnemyView"
	_enemy_view.transform = _view_layout.target_sub_transform()
	_enemy_view.modulate = Color(1, 1, 1, _view_layout.target_sub_alpha())
	add_child(_enemy_view)

	# 玩家视图内容：角色 + 玩家判定线 + 玩家 note 层（接 enemy 攻击）+ hit_effects
	_player_character = PokemonCharacter.new()
	_player_character.side = PokemonCharacter.Side.PLAYER
	_player_character.character_name = "Player"
	_player_character.position = Vector2(110, 160)
	_player_view.add_child(_player_character)

	_judge_line = ColorRect.new()
	_judge_line.position = Vector2(LANE_X[0] - 24, JUDGE_LINE_Y - 2)
	_judge_line.size = Vector2(LANE_X[3] - LANE_X[0] + 48, 4)
	_judge_line.color = JUDGE_LINE_COLOR
	_player_view.add_child(_judge_line)

	for i in range(4):
		var lbl := Label.new()
		lbl.text = _key_config.lane_label(i)
		lbl.position = Vector2(LANE_X[i] - 6, JUDGE_LINE_Y + 12)
		_player_view.add_child(lbl)

	_note_layer = Node2D.new()
	_note_layer.name = "NoteLayer"
	_player_view.add_child(_note_layer)

	_hit_effects = HitEffectsScene.instantiate()
	_player_view.add_child(_hit_effects)

	# 敌人视图内容：敌人角色（D1 暂时只放角色，副屏 note/判定线在 Task 3 加）
	_enemy_character = PokemonCharacter.new()
	_enemy_character.side = PokemonCharacter.Side.ENEMY
	_enemy_character.character_name = "Phigros Dummy"
	_enemy_character.position = Vector2(240, 160)
	_enemy_view.add_child(_enemy_character)

	_enemy_judge_line = ColorRect.new()
	_enemy_judge_line.position = Vector2(LANE_X[0] - 24, JUDGE_LINE_Y - 2)
	_enemy_judge_line.size = Vector2(LANE_X[3] - LANE_X[0] + 48, 4)
	_enemy_judge_line.color = JUDGE_LINE_COLOR
	_enemy_view.add_child(_enemy_judge_line)

	_enemy_note_layer = Node2D.new()
	_enemy_note_layer.name = "EnemyNoteLayer"
	_enemy_view.add_child(_enemy_note_layer)

	_tap_sfx = AudioStreamPlayer.new()
	_tap_sfx.stream = TapHitSound
	_tap_sfx.volume_db = -6.0
	add_child(_tap_sfx)


func _process(_delta: float) -> void:
	if not _battle_started:
		return
	_sway_time += _delta
	_apply_judge_line_sway()
	var now := _elapsed_ms()
	_update_enemy_note_positions(now)
	_update_player_note_positions(now)
	_router.resolve_misses_until(now)
	_tick_player_chart(now)
	_check_enemy_chart_complete()
	_check_player_chart_complete()
	_tick_enemy_attack(now)


func _current_judge_y() -> float:
	return JUDGE_LINE_Y + SWAY_AMPLITUDE * sin(TAU * _sway_time / SWAY_PERIOD) + _choreo_offset


func _apply_judge_line_sway() -> void:
	if _judge_line == null:
		return
	_judge_line.position.y = _current_judge_y() - 2.0


func _play_choreography(events: Array) -> void:
	if events == null or events.is_empty():
		return
	if not is_inside_tree():
		return
	var tw := create_tween()
	var cursor_ms := 0
	for ev in events:
		var delay_ms := int(ev.get("delay_ms", 0))
		if delay_ms > cursor_ms:
			tw.tween_interval(float(delay_ms - cursor_ms) / 1000.0)
			cursor_ms = delay_ms
		var duration_ms := int(ev.get("duration_ms", 200))
		var dur_s := float(duration_ms) / 1000.0
		match str(ev.get("type", "")):
			"move_y":
				var offset := float(ev.get("offset", 0.0))
				tw.tween_property(self, "_choreo_offset", offset, dur_s)
				cursor_ms += duration_ms
			"rotate":
				var deg := float(ev.get("degrees", 0.0))
				tw.tween_property(_judge_line, "rotation_degrees", deg, dur_s)
				cursor_ms += duration_ms
			"alpha":
				var a := float(ev.get("value", 1.0))
				tw.tween_property(_judge_line, "modulate:a", a, dur_s)
				cursor_ms += duration_ms
			"scale_x":
				var sx := float(ev.get("value", 1.0))
				tw.tween_property(_judge_line, "scale:x", sx, dur_s)
				cursor_ms += duration_ms
			"color_flash":
				var c := Color(str(ev.get("color", "#ffffff")))
				tw.tween_property(_judge_line, "color", c, dur_s)
				cursor_ms += duration_ms
	tw.tween_property(self, "_choreo_offset", 0.0, 0.15)
	tw.tween_property(_judge_line, "rotation_degrees", 0.0, 0.15)
	tw.tween_property(_judge_line, "modulate:a", 1.0, 0.1)
	tw.tween_property(_judge_line, "scale:x", 1.0, 0.1)
	tw.tween_property(_judge_line, "color", JUDGE_LINE_COLOR, 0.15)


func _update_enemy_note_positions(now: int) -> void:
	var judge_y := _current_judge_y()
	for np in _enemy_notes:
		if not is_instance_valid(np) or np.judged:
			continue
		var travel := float(now - (int(np.note_time_ms) - NOTE_TRAVEL_MS))
		var f := clampf(travel / float(NOTE_TRAVEL_MS), 0.0, 1.2)
		np.position.y = lerpf(SPAWN_TOP_Y, judge_y, f)


func _update_player_note_positions(now: int) -> void:
	for np in _player_notes:
		if not is_instance_valid(np) or np.judged:
			continue
		var travel := float(now - (int(np.note_time_ms) - NOTE_TRAVEL_MS))
		var f := clampf(travel / float(NOTE_TRAVEL_MS), 0.0, 1.2)
		# 副屏 note 在副屏局部坐标系下从 SPAWN_TOP_Y 下落到 JUDGE_LINE_Y
		np.position.y = lerpf(SPAWN_TOP_Y, JUDGE_LINE_Y, f)


func _tick_player_chart(now: int) -> void:
	for np in _player_notes:
		if not is_instance_valid(np) or np.judged:
			continue
		if now >= int(np.note_time_ms):
			var verdict: String = np.judge_at(int(np.note_time_ms), false)
			if verdict == "":
				continue
			_player_summary[verdict] = int(_player_summary.get(verdict, 0)) + 1
			_record_judgment(BattleLogicScript.ENEMY, verdict, _bottom_chart_no_credit)
			_bottom_chart_score += _score_for_verdict(verdict)
			if verdict != "miss":
				var time_in_chart := int(np.note_time_ms) - _beat_phase_ms_player_chart
				if BeatClockScript.is_on_beat(time_in_chart, MAIN_BGM_BEAT_MS, 0, ON_BEAT_WINDOW_MS):
					_bottom_chart_score += 1
					_hit_effects.emit_at(Vector2(np.position.x, _current_judge_y()), COLOR_ON_BEAT)
			if verdict != "miss":
				_play_tap_sfx()
			_hit_effects.emit_at(Vector2(np.position.x, _current_judge_y()), LaneNotePart.COLOR_PERFECT)
			if _enemy_character != null:
				_enemy_character.modulate = Color(1.4, 1.4, 1.4)
				if is_inside_tree():
					var tw := create_tween()
					tw.tween_property(_enemy_character, "modulate", Color.WHITE, 0.12)
				_enemy_character.play_judge_feedback(verdict)
			np.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_swap_main_sub_view()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_P:
			play_performance_demo()
			get_viewport().set_input_as_handled()
			return
		if _handle_skill_key(event.keycode, _elapsed_ms()):
			get_viewport().set_input_as_handled()
			return
	var result: Dictionary = _router.handle_input_event(event, _elapsed_ms())
	if not result.is_empty():
		get_viewport().set_input_as_handled()


func _swap_main_sub_view() -> void:
	_view_layout.swap()
	var main_target_t: Transform2D = _view_layout.target_main_transform()
	var sub_target_t: Transform2D = _view_layout.target_sub_transform()
	var main_alpha: float = _view_layout.target_main_alpha()
	var sub_alpha: float = _view_layout.target_sub_alpha()
	if _swap_tween != null and _swap_tween.is_valid():
		_swap_tween.kill()
	if not is_inside_tree():
		_player_view.transform = main_target_t
		_enemy_view.transform = sub_target_t
		_player_view.modulate.a = main_alpha
		_enemy_view.modulate.a = sub_alpha
		return
	_swap_tween = create_tween().set_parallel(true)
	_swap_tween.tween_property(_player_view, "transform", main_target_t, SWAP_TWEEN_SEC)
	_swap_tween.tween_property(_enemy_view, "transform", sub_target_t, SWAP_TWEEN_SEC)
	_swap_tween.tween_property(_player_view, "modulate:a", main_alpha, SWAP_TWEEN_SEC)
	_swap_tween.tween_property(_enemy_view, "modulate:a", sub_alpha, SWAP_TWEEN_SEC)


func _on_note_judged(np, verdict: String, offset_ms: int) -> void:
	_enemy_summary[verdict] = int(_enemy_summary.get(verdict, 0)) + 1
	_record_judgment(BattleLogicScript.PLAYER, verdict, _top_chart_no_credit)
	_top_chart_score += _score_for_verdict(verdict)
	if verdict != "miss":
		var time_in_chart := int(np.note_time_ms) - _beat_phase_ms_enemy_chart
		if BeatClockScript.is_on_beat(time_in_chart, MAIN_BGM_BEAT_MS, 0, ON_BEAT_WINDOW_MS):
			_top_chart_score += 1
			_hit_effects.emit_at(Vector2(np.position.x, _current_judge_y()), COLOR_ON_BEAT)
	note_hit.emit(int(np.note_id), verdict, offset_ms)
	if verdict != "miss":
		var color := LaneNotePart.COLOR_PERFECT
		if verdict == "good":
			color = LaneNotePart.COLOR_GOOD
		elif verdict == "bad":
			color = LaneNotePart.COLOR_BAD
		_hit_effects.emit_at(Vector2(np.position.x, _current_judge_y()), color)
		_play_tap_sfx()
		if _player_character != null:
			_player_character.modulate = Color(1.4, 1.4, 1.4)
			if is_inside_tree():
				var tw := create_tween()
				tw.tween_property(_player_character, "modulate", Color.WHITE, 0.12)
	if _player_character != null:
		_player_character.play_judge_feedback(verdict)
	if np != null and is_instance_valid(np):
		np.queue_free()


func _check_enemy_chart_complete() -> void:
	if not _enemy_active or _enemy_notes.is_empty():
		return
	for np in _enemy_notes:
		if is_instance_valid(np) and not np.judged:
			return
	var summary := _enemy_summary.duplicate(true)
	_enemy_notes.clear()
	_enemy_summary = _blank_summary()
	_enemy_active = false
	_router.clear()
	_apply_chart_momentum(_top_chart_score, BattleLogicScript.PLAYER)
	_top_chart_score = 0
	_top_chart_no_credit = false
	_battle_flow_summary["charts_completed"] = int(_battle_flow_summary.get("charts_completed", 0)) + 1
	chart_finished.emit(summary, BattleLogicScript.PLAYER)
	_resolve_chart_locally(summary, BattleLogicScript.ENEMY, BattleLogicScript.PLAYER)


func _check_player_chart_complete() -> void:
	if not _player_active or _player_notes.is_empty():
		return
	for np in _player_notes:
		if is_instance_valid(np) and not np.judged:
			return
	var summary := _player_summary.duplicate(true)
	_player_notes.clear()
	_player_summary = _blank_summary()
	_player_active = false
	_apply_chart_momentum(_bottom_chart_score, BattleLogicScript.ENEMY)
	_bottom_chart_score = 0
	_bottom_chart_no_credit = false
	_battle_flow_summary["charts_completed"] = int(_battle_flow_summary.get("charts_completed", 0)) + 1
	chart_finished.emit(summary, BattleLogicScript.ENEMY)
	_resolve_chart_locally(summary, BattleLogicScript.PLAYER, BattleLogicScript.ENEMY)
	if not _skill_queue.is_empty():
		var next_action: Dictionary = _skill_queue.pop_front()
		_dispatch_skill_action(next_action)


func _resolve_chart_locally(summary: Dictionary, attacker: String, target: String) -> void:
	if _battle_logic == null or not _battle_logic.combatants.has(target):
		return
	var perfect := int(summary.get("perfect", 0))
	var good := int(summary.get("good", 0))
	var bad := int(summary.get("bad", 0))
	var miss := int(summary.get("miss", 0))
	var total := maxi(perfect + good + bad + miss, 1)
	var defense_score := (float(perfect) * 1.0 + float(good) * 0.5 + float(bad) * 0.2) / float(total)
	var atk: int = int(_battle_logic.combatants[attacker].atk)
	var dmg := maxi(int(float(atk) * (1.0 - defense_score)), 0)
	if dmg <= 0:
		return
	var current_hp: int = int(_battle_logic.combatants[target].hp)
	var new_hp: int = maxi(current_hp - dmg, 0)
	_battle_logic.combatants[target].hp = new_hp
	_battle_logic.hp_updated.emit(target, new_hp, int(_battle_logic.combatants[target].max_hp))


func _spawn_chart(chart, direction: int, target: String) -> void:
	_play_choreography(chart.choreography)
	var spawn_offset := _elapsed_ms()
	if direction == 1:
		_beat_phase_ms_enemy_chart = spawn_offset
	else:
		_beat_phase_ms_player_chart = spawn_offset
	var notes_built: Array = []
	if direction == 1:
		# 敌方攻击：主屏顶部下落 note，玩家接
		for note in chart.notes:
			var np = NotePartScene.instantiate()
			_note_layer.add_child(np)
			np.setup(int(note.id), int(note.time_ms) + spawn_offset, int(note.lane), direction)
			np.position = Vector2(LANE_X[np.lane], SPAWN_TOP_Y)
			notes_built.append(np)
		for old in _enemy_notes:
			if is_instance_valid(old):
				old.queue_free()
		_enemy_notes = notes_built
		_enemy_summary = _blank_summary()
		_enemy_active = true
		_top_chart_score = 0
		_top_chart_no_credit = bool(chart.modifiers.get("no_break_credit", false))
		var by_lane: Dictionary = {0: [], 1: [], 2: [], 3: []}
		for np in notes_built:
			by_lane[np.lane].append(np)
		_router.clear()
		for lane in by_lane.keys():
			_router.set_lane_notes(int(lane), by_lane[lane])
	else:
		# 玩家攻击：副屏顶部下落 note 给敌人接（主屏不下落）
		for note in chart.notes:
			var np = NotePartScene.instantiate()
			_enemy_note_layer.add_child(np)
			np.setup(int(note.id), int(note.time_ms) + spawn_offset, int(note.lane), direction)
			np.position = Vector2(LANE_X[np.lane], SPAWN_TOP_Y)
			notes_built.append(np)
		_player_notes = notes_built
		_player_summary = _blank_summary()
		_player_active = true
		_bottom_chart_score = 0
		_bottom_chart_no_credit = bool(chart.modifiers.get("no_break_credit", false))
	_battle_flow_summary["charts_requested"] = int(_battle_flow_summary.get("charts_requested", 0)) + 1
	if str(_battle_flow_summary.get("first_chart_target", "")) == "":
		_battle_flow_summary["first_chart_target"] = target


func _on_bridge_chart_request(chart, target: String, direction: int) -> void:
	_spawn_chart(chart, direction, target)


func _handle_skill_key(keycode: int, input_time_ms: int) -> bool:
	if not _battle_started:
		start_battle_demo()
	var action := _skill_action_for_key(keycode)
	if action.is_empty():
		return false
	if _qte_active:
		return true
	_battle_logic.ap[BattleLogicScript.PLAYER] = 9999
	_battle_logic.max_ap_granted[BattleLogicScript.PLAYER] = 9999
	if _player_active:
		_skill_queue.append(action)
		return true
	_dispatch_skill_action(action)
	return true


func _dispatch_skill_action(action: Dictionary) -> void:
	_intro_blocking = true
	# 弹弓 = 主屏（玩家）判定线；接收方 = 副屏（敌人）判定线
	var attacker_world_pos: Vector2 = Vector2.ZERO
	if _judge_line != null:
		var local_center := _judge_line.position + _judge_line.size * 0.5
		attacker_world_pos = _player_view.transform * local_center
	var defender_world_pos: Vector2 = Vector2.ZERO
	if _enemy_judge_line != null:
		var local_center := _enemy_judge_line.position + _enemy_judge_line.size * 0.5
		defender_world_pos = _enemy_view.transform * local_center
	await _intro_animator.play(get_tree(), _player_character, _judge_line, _enemy_judge_line, self, attacker_world_pos, defender_world_pos)
	_intro_blocking = false
	var chart = _generate_chart_for_action(action, BattleLogicScript.PLAYER)
	action["chart"] = chart
	action["chart_target"] = BattleLogicScript.ENEMY
	action["reaction_receiver"] = BattleLogicScript.ENEMY
	action["target"] = BattleLogicScript.ENEMY
	_battle_logic.phase = BattleLogicScript.Phase.ACTION_SELECT
	_battle_logic.set("_active_combatant", BattleLogicScript.PLAYER)
	_battle_logic.select_action(action)


func _skill_action_for_key(keycode: int) -> Dictionary:
	match keycode:
		KEY_Q:
			return {
				"name": "直线试探", "type": "phigros_attack", "cost_ap": 1,
				"power": 0.8, "element": "physical", "template_id": "T1",
				"chart_params": {"note_count": 3, "interval_ms": 320, "lane": 0, "start_ms": 1200, "bpm": 90},
			}
		KEY_E:
			return {
				"name": "交替连击", "type": "phigros_attack", "cost_ap": 2,
				"power": 1.0, "element": "physical", "template_id": "T2",
				"chart_params": {"beat_count": 6, "interval_ms": 293, "lanes": [0, 3], "start_ms": 1200, "bpm": 90},
			}
		KEY_R:
			return {
				"name": "四轨横扫", "type": "phigros_attack", "cost_ap": 3,
				"power": 1.25, "element": "physical", "template_id": "T3",
				"chart_params": {"repeat_count": 2, "interval_ms": 240, "direction": "forward", "start_ms": 1200, "bpm": 90},
			}
	return {}


func _generate_chart_for_action(action: Dictionary, source_id: String):
	var generator = ChartGenerator.new()
	var momentum_value := int(_battle_logic.momentum.get(source_id, 30))
	var chart = generator.generate(str(action.get("template_id", "T1")), action.get("chart_params", {}), momentum_value)
	if bool(action.get("no_break_credit", false)):
		chart.modifiers["no_break_credit"] = true
	return chart


func _tick_enemy_attack(now: int) -> void:
	if _intro_blocking:
		_next_enemy_attack_ms = maxi(_next_enemy_attack_ms, now + 50)
		return
	if _break_performance_active:
		_next_enemy_attack_ms = maxi(_next_enemy_attack_ms, now + 50)
		return
	if _qte_active:
		_next_enemy_attack_ms = maxi(_next_enemy_attack_ms, now + 50)
		return
	if now < _next_enemy_attack_ms or _enemy_active:
		return
	_emit_enemy_attack_chart(now)
	_next_enemy_attack_ms = now + ENEMY_ATTACK_INTERVAL_MS


func _emit_enemy_attack_chart(now: int) -> void:
	var beat_count := 6
	var interval_ms := 307
	var no_break_credit := false
	var name := "敌方交替压迫"
	if _pending_player_punishment:
		beat_count = 9
		interval_ms = 173
		no_break_credit = true
		name = "敌方乘势追击"
		_pending_player_punishment = false
	var action := {
		"name": name, "type": "phigros_attack", "cost_ap": 1,
		"power": 0.9, "element": "physical", "template_id": "T2",
		"chart_params": {"beat_count": beat_count, "interval_ms": interval_ms, "lanes": [1, 2], "start_ms": 1200, "bpm": 90},
		"no_break_credit": no_break_credit,
	}
	_intro_blocking = true
	# 弹弓 = 副屏（敌方）判定线；接收方 = 主屏（玩家）判定线
	var attacker_world_pos: Vector2 = Vector2.ZERO
	if _enemy_judge_line != null:
		var local_center := _enemy_judge_line.position + _enemy_judge_line.size * 0.5
		attacker_world_pos = _enemy_view.transform * local_center
	var defender_world_pos: Vector2 = Vector2.ZERO
	if _judge_line != null:
		var local_center := _judge_line.position + _judge_line.size * 0.5
		defender_world_pos = _player_view.transform * local_center
	await _intro_animator.play(get_tree(), _enemy_character, _enemy_judge_line, _judge_line, self, attacker_world_pos, defender_world_pos)
	_intro_blocking = false
	var chart = _generate_chart_for_action(action, BattleLogicScript.ENEMY)
	action["chart"] = chart
	action["chart_target"] = BattleLogicScript.PLAYER
	action["reaction_receiver"] = BattleLogicScript.PLAYER
	action["target"] = BattleLogicScript.PLAYER
	_battle_logic.phase = BattleLogicScript.Phase.ACTION_SELECT
	_battle_logic.set("_active_combatant", BattleLogicScript.ENEMY)
	_battle_logic.call("_execute_action", BattleLogicScript.ENEMY, action)


func _spawn_enemy_punishment_chart() -> void:
	var action := {
		"name": "击破追击", "type": "phigros_attack", "cost_ap": 0,
		"power": 1.1, "element": "physical", "template_id": "T2",
		"chart_params": {"beat_count": 8, "interval_ms": 200, "lanes": [0, 3], "start_ms": 600, "bpm": 90},
		"no_break_credit": true,
	}
	if _player_active:
		_skill_queue.append(action)
		return
	_dispatch_skill_action(action)


# ============ public test API ============

func play_performance_demo() -> void:
	if not _battle_started:
		start_battle_demo()
	var action := {
		"name": "演出测试", "type": "phigros_attack", "cost_ap": 0,
		"power": 1.0, "element": "physical", "template_id": "PERF",
		"chart_params": {"bpm": 120},
		"no_break_credit": true,
	}
	var chart = _generate_chart_for_action(action, BattleLogicScript.ENEMY)
	_spawn_chart(chart, 1, BattleLogicScript.PLAYER)
	print("[phigros] Performance demo chart launched (20s, DFJK to play)")


func start_battle_demo() -> void:
	if _battle_started:
		return
	if _player_character == null:
		_build_visuals()
		_router.key_config = _key_config
		if not _router.note_judged.is_connected(_on_note_judged):
			_router.note_judged.connect(_on_note_judged)
		if not _bridge.chart_request.is_connected(_on_bridge_chart_request):
			_bridge.chart_request.connect(_on_bridge_chart_request)
	_battle_flow_summary = _blank_flow_summary()
	_next_enemy_attack_ms = ENEMY_ATTACK_INTERVAL_MS
	_break_progress = {BattleLogicScript.PLAYER: 0, BattleLogicScript.ENEMY: 0}
	_shared_momentum = 0
	_pending_player_punishment = false
	_pending_enemy_punishment = false
	_top_chart_no_credit = false
	_bottom_chart_no_credit = false
	_top_chart_score = 0
	_bottom_chart_score = 0
	_beat_phase_ms_player_chart = 0
	_beat_phase_ms_enemy_chart = 0
	_break_performance_active = false
	_battle_logic = BattleLogicScript.new()
	_bridge.connect_battle_logic(_battle_logic)
	if not _battle_logic.hp_updated.is_connected(_on_battle_hp_updated):
		_battle_logic.hp_updated.connect(_on_battle_hp_updated)
	var player_data := {
		"name": "Player", "hp": 180, "max_hp": 180, "mp": 30, "max_mp": 30,
		"atk": 22, "def": 8, "spd": 12, "skills": [],
	}
	var enemy_data := {
		"name": "Phigros Dummy", "hp": 180, "max_hp": 180, "mp": 20, "max_mp": 20,
		"atk": 16, "def": 6, "spd": 10, "shield_points": 1,
		"weaknesses": ["physical"], "skills": [],
	}
	_battle_logic.start(player_data, enemy_data)
	_battle_logic.ap[BattleLogicScript.PLAYER] = 9999
	_battle_logic.max_ap_granted[BattleLogicScript.PLAYER] = 9999
	_battle_logic.ap[BattleLogicScript.ENEMY] = 9999
	_battle_logic.max_ap_granted[BattleLogicScript.ENEMY] = 9999
	_player_character.max_hp = 180
	_player_character.set_hp(180)
	_player_character.set_break_progress(0)
	_enemy_character.max_hp = 180
	_enemy_character.set_hp(180)
	_enemy_character.set_break_progress(0)
	_apply_momentum_to_ui()
	_battle_started = true


func simulate_battle_for_ms(duration_ms: int) -> void:
	if not _battle_started:
		start_battle_demo()
	var end_ms := _elapsed_ms() + duration_ms
	while _next_enemy_attack_ms <= end_ms:
		_test_elapsed_ms = _next_enemy_attack_ms
		_emit_enemy_attack_chart(_next_enemy_attack_ms)
		_next_enemy_attack_ms = _test_elapsed_ms + ENEMY_ATTACK_INTERVAL_MS
	_test_elapsed_ms = end_ms


func handle_skill_key_at_ms(keycode: int, input_time_ms: int) -> bool:
	_test_elapsed_ms = input_time_ms
	var handled := _handle_skill_key(keycode, input_time_ms)
	_test_elapsed_ms = -1
	return handled


# ============ test hooks ============

func test_swap_main_sub_view() -> void:
	_swap_main_sub_view()


func test_player_is_main() -> bool:
	return _view_layout.player_is_main


func test_player_view_transform() -> Transform2D:
	return _player_view.transform


func test_enemy_view_transform() -> Transform2D:
	return _enemy_view.transform


func test_break_progress(side: String) -> int:
	return int(_break_progress.get(side, 0))


func test_shared_momentum() -> int:
	return _shared_momentum


func test_record_judgment(judger: String, verdict: String, no_break_credit: bool = false) -> void:
	_record_judgment(judger, verdict, no_break_credit)


func test_apply_chart_momentum(score: int, judger: String) -> void:
	_apply_chart_momentum(score, judger)


func test_pending_player_punishment() -> bool:
	return _pending_player_punishment


func test_break_performance_active() -> bool:
	return _break_performance_active


func test_qte_active() -> bool:
	return _qte_active


func test_top_chart_score() -> int:
	return _top_chart_score


func handle_key_hit_at_ms(keycode: int, input_time_ms: int) -> Dictionary:
	_test_elapsed_ms = input_time_ms
	var r: Dictionary = _router.handle_keycode(keycode, input_time_ms)
	_test_elapsed_ms = -1
	return r


func resolve_misses_until(input_time_ms: int) -> void:
	_router.resolve_misses_until(input_time_ms)


func get_battle_flow_summary() -> Dictionary:
	return _battle_flow_summary.duplicate(true)


# ============ break + momentum core ============

func _record_judgment(judger: String, verdict: String, no_break_credit: bool) -> void:
	if no_break_credit:
		return
	var delta := 0
	if verdict == "miss":
		delta = BREAK_PER_MISS
	elif verdict == "bad":
		delta = BREAK_PER_BAD
	if delta <= 0:
		return
	var current: int = int(_break_progress.get(judger, 0))
	var next_val := current + delta
	_break_progress[judger] = next_val
	_apply_break_to_ui(judger)
	if next_val >= BREAK_MAX:
		_break_progress[judger] = 0
		_apply_break_to_ui(judger)
		_play_break_performance_then_punish(judger)


func _play_break_performance_then_punish(side: String) -> void:
	if _break_performance_active:
		_trigger_break_punishment(side)
		return
	_break_performance_active = true
	var perf = BreakPerformanceScript.new()
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	layer.add_child(perf)
	var broken = _player_character if side == BattleLogicScript.PLAYER else _enemy_character
	await perf.play(_judge_line, broken)
	if is_instance_valid(layer):
		layer.queue_free()
	_break_performance_active = false
	_trigger_break_punishment(side)


func _trigger_break_punishment(side: String) -> void:
	print("[phigros] break punishment for %s" % side)
	if side == BattleLogicScript.PLAYER:
		_pending_player_punishment = true
		_next_enemy_attack_ms = mini(_next_enemy_attack_ms, _elapsed_ms() + PUNISHMENT_DELAY_MS)
	else:
		_pending_enemy_punishment = true
		_spawn_enemy_punishment_chart()
		_pending_enemy_punishment = false


func _score_for_verdict(verdict: String) -> int:
	match verdict:
		"perfect":
			return SCORE_PERFECT
		"good":
			return SCORE_GOOD
		"bad":
			return SCORE_BAD
		"miss":
			return SCORE_MISS
	return 0


func _apply_chart_momentum(score: int, judger: String) -> void:
	var sign_dir := 1 if judger == BattleLogicScript.PLAYER else -1
	_shared_momentum = clampi(_shared_momentum + score * sign_dir, -MOMENTUM_RANGE, MOMENTUM_RANGE)
	_apply_momentum_to_ui()
	if _shared_momentum >= MOMENTUM_RANGE:
		_trigger_qte(BattleLogicScript.PLAYER)
	elif _shared_momentum <= -MOMENTUM_RANGE:
		_trigger_qte(BattleLogicScript.ENEMY)


func _trigger_qte(winner: String) -> void:
	if _qte_active:
		return
	_qte_active = true
	var sign_dir := 1 if winner == BattleLogicScript.PLAYER else -1
	await _qte_director.run(self, sign_dir)
	_shared_momentum = 0
	_apply_momentum_to_ui()
	_qte_active = false


func make_qte_choice_ui() -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var ui = QteChoiceUiScript.new()
	layer.add_child(ui)
	if DisplayServer.get_name() == "headless":
		_press_headless_qte_duel_key.call_deferred()
	return ui


func _press_headless_qte_duel_key() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_1
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_1
	release.pressed = false
	Input.parse_input_event(release)


func play_duel(tree: SceneTree) -> Dictionary:
	var duel = DuelDirectorScript.new()
	var gen = ChartGenerator.new()
	# 视觉切换：对称双屏
	var saved_player_t: Transform2D = _player_view.transform
	var saved_player_a: float = _player_view.modulate.a
	var saved_enemy_t: Transform2D = _enemy_view.transform
	var saved_enemy_a: float = _enemy_view.modulate.a
	var duel_player_t := Transform2D(0.0, Vector2(1.0, 1.0), 0.0, Vector2(0, 0))
	var duel_enemy_t := Transform2D(PI, Vector2(-1.0, 1.0), 0.0, Vector2(VIEWPORT.x, 0))
	if tree != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_player_view, "transform", duel_player_t, 0.3)
		tw.tween_property(_player_view, "modulate:a", 1.0, 0.3)
		tw.tween_property(_enemy_view, "transform", duel_enemy_t, 0.3)
		tw.tween_property(_enemy_view, "modulate:a", 1.0, 0.3)
	# 切 BGM
	if _bgm_player != null:
		_bgm_player.stop()
	var duel_bgm = BgmPlayerScript.new()
	add_child(duel_bgm)
	duel_bgm.load_stream(DUEL_BGM_PATH)
	duel_bgm.play_loop(-6.0)
	# 推条 UI
	var bar_layer := CanvasLayer.new()
	bar_layer.layer = 80
	add_child(bar_layer)
	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(600, 24)
	bar_bg.position = Vector2(VIEWPORT.x * 0.5 - 300, VIEWPORT.y * 0.5 - 12)
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.85)
	bar_layer.add_child(bar_bg)
	var bar_pointer := ColorRect.new()
	bar_pointer.size = Vector2(8, 32)
	bar_pointer.position = Vector2(VIEWPORT.x * 0.5 - 4, VIEWPORT.y * 0.5 - 16)
	bar_pointer.color = Color(1, 0.95, 0.4)
	bar_layer.add_child(bar_pointer)
	var bar_label := Label.new()
	bar_label.text = "决斗对拼"
	bar_label.add_theme_font_size_override("font_size", 32)
	bar_label.position = Vector2(VIEWPORT.x * 0.5 - 80, VIEWPORT.y * 0.5 - 60)
	bar_layer.add_child(bar_label)

	for seg in range(duel.SEGMENTS):
		var chart_notes: Array = gen.generate_duel_chart()
		var player_summary := _simulate_duel_segment_player(chart_notes)
		var enemy_summary := _simulate_duel_segment_ai(chart_notes)
		var player_score := duel.score_for_summary(player_summary)
		var enemy_score := duel.score_for_summary(enemy_summary)
		duel.apply_segment(player_score, enemy_score)
		# 推条平滑过渡到当前 bar_value
		var target_x: float = VIEWPORT.x * 0.5 - 4.0 + duel.bar_value * 290.0
		if tree != null:
			var ptw := bar_pointer.create_tween()
			ptw.tween_property(bar_pointer, "position:x", target_x, 0.5)
			await tree.create_timer(2.0).timeout
	bar_label.text = "结算 %s" % duel.outcome()
	if tree != null:
		await tree.create_timer(1.0).timeout
	if is_instance_valid(bar_layer):
		bar_layer.queue_free()
	if is_instance_valid(duel_bgm):
		duel_bgm.stop()
		duel_bgm.queue_free()
	if _bgm_player != null:
		_bgm_player.play_loop(-6.0)
	# 视图复原
	if tree != null:
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(_player_view, "transform", saved_player_t, 0.3)
		tw2.tween_property(_player_view, "modulate:a", saved_player_a, 0.3)
		tw2.tween_property(_enemy_view, "transform", saved_enemy_t, 0.3)
		tw2.tween_property(_enemy_view, "modulate:a", saved_enemy_a, 0.3)
		await tree.create_timer(0.35).timeout
	var damage := duel.resolve_damage()
	_apply_qte_damage(damage)
	return damage


func play_execute_punish(tree: SceneTree) -> Dictionary:
	var exec = ExecuteDirectorScript.new()
	var gen = ChartGenerator.new()
	var total_enemy_damage := 0.0
	# 撕屏视觉：副屏 modulate 闪 + 抖动
	var tear_layer := CanvasLayer.new()
	tear_layer.layer = 80
	add_child(tear_layer)
	var tear_label := Label.new()
	tear_label.text = "处决·惩罚"
	tear_label.add_theme_font_size_override("font_size", 48)
	tear_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	tear_label.position = Vector2(VIEWPORT.x * 0.5 - 100, 80)
	tear_layer.add_child(tear_label)
	for phase_idx in range(exec.phase_count()):
		var params: Dictionary = exec.phase_params(phase_idx)
		var notes: Array = gen.generate_execute_chart_phase(
			int(params.get("axes", 6)),
			int(params.get("beat_count", 12)),
			int(params.get("interval_ms", 180)),
			bool(params.get("double_tap", false))
		)
		tear_label.text = "处决·惩罚 P%d (%d轨)" % [phase_idx + 1, int(params.get("axes", 6))]
		# 副屏闪烁红
		if tree != null and is_instance_valid(_enemy_view):
			var tw := _enemy_view.create_tween()
			tw.tween_property(_enemy_view, "modulate", Color(1.6, 0.5, 0.5, 0.8), 0.2)
			tw.tween_property(_enemy_view, "modulate", Color(1, 1, 1, _view_layout.target_sub_alpha()), 0.4)
		var ai_perfect := int(float(notes.size()) * randf_range(0.30, 0.50))
		var ratio := exec.punish_segment_damage_ratio(ai_perfect, notes.size())
		total_enemy_damage += ratio
		if tree != null:
			await tree.create_timer(2.5).timeout
	if is_instance_valid(tear_layer):
		tear_layer.queue_free()
	_apply_execute_damage_to_enemy(total_enemy_damage)
	return {"enemy_hp_loss_ratio": total_enemy_damage}


func play_execute_challenge(tree: SceneTree) -> Dictionary:
	var exec = ExecuteDirectorScript.new()
	var gen = ChartGenerator.new()
	var total_enemy_damage := 0.0
	var total_backfire := 0.0
	var tear_layer := CanvasLayer.new()
	tear_layer.layer = 80
	add_child(tear_layer)
	var tear_label := Label.new()
	tear_label.text = "处决·挑战自己"
	tear_label.add_theme_font_size_override("font_size", 48)
	tear_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	tear_label.position = Vector2(VIEWPORT.x * 0.5 - 140, 80)
	tear_layer.add_child(tear_label)
	for phase_idx in range(exec.phase_count()):
		var params: Dictionary = exec.phase_params(phase_idx)
		var notes: Array = gen.generate_execute_chart_phase(
			int(params.get("axes", 6)),
			int(params.get("beat_count", 12)),
			int(params.get("interval_ms", 180)),
			bool(params.get("double_tap", false))
		)
		tear_label.text = "处决·挑战自己 P%d (%d轨)" % [phase_idx + 1, int(params.get("axes", 6))]
		if tree != null and is_instance_valid(_player_view):
			var tw := _player_view.create_tween()
			tw.tween_property(_player_view, "modulate", Color(1.6, 1.2, 0.4, 1.0), 0.2)
			tw.tween_property(_player_view, "modulate", Color(1, 1, 1, _view_layout.target_main_alpha()), 0.4)
		var player_perfect := int(float(notes.size()) * 0.6)
		var dmg: Dictionary = exec.challenge_segment_damage(player_perfect, notes.size())
		total_enemy_damage += float(dmg.get("enemy_ratio", 0.0))
		total_backfire += float(dmg.get("player_backfire_ratio", 0.0))
		if tree != null:
			await tree.create_timer(2.5).timeout
	if is_instance_valid(tear_layer):
		tear_layer.queue_free()
	_apply_execute_damage_to_enemy(total_enemy_damage)
	if total_backfire > 0.0:
		_apply_execute_backfire(total_backfire)
	return {"enemy_hp_loss_ratio": total_enemy_damage, "player_backfire_ratio": total_backfire}


func _simulate_duel_segment_player(notes: Array) -> Dictionary:
	var total := notes.size()
	var perfect := int(float(total) * 0.7)
	var good := total - perfect
	return {"perfect": perfect, "good": good, "bad": 0, "miss": 0}


func _simulate_duel_segment_ai(notes: Array) -> Dictionary:
	var total := notes.size()
	var perfect := int(float(total) * 0.5)
	var miss := total - perfect
	return {"perfect": perfect, "good": 0, "bad": 0, "miss": miss}


func _apply_qte_damage(damage: Dictionary) -> void:
	if _battle_logic == null:
		return
	var player_loss := float(damage.get("player_hp_loss_ratio", 0.0))
	var enemy_loss := float(damage.get("enemy_hp_loss_ratio", 0.0))
	if player_loss > 0.0:
		var hp: int = int(_battle_logic.combatants[BattleLogicScript.PLAYER].hp)
		var dmg := maxi(int(float(hp) * player_loss), 1)
		var new_hp := maxi(hp - dmg, 0)
		_battle_logic.combatants[BattleLogicScript.PLAYER].hp = new_hp
		_battle_logic.hp_updated.emit(BattleLogicScript.PLAYER, new_hp, int(_battle_logic.combatants[BattleLogicScript.PLAYER].max_hp))
	if enemy_loss > 0.0:
		var hp: int = int(_battle_logic.combatants[BattleLogicScript.ENEMY].hp)
		var dmg := maxi(int(float(hp) * enemy_loss), 1)
		var new_hp := maxi(hp - dmg, 0)
		_battle_logic.combatants[BattleLogicScript.ENEMY].hp = new_hp
		_battle_logic.hp_updated.emit(BattleLogicScript.ENEMY, new_hp, int(_battle_logic.combatants[BattleLogicScript.ENEMY].max_hp))


func _apply_execute_damage_to_enemy(total_ratio: float) -> void:
	_apply_qte_damage({"player_hp_loss_ratio": 0.0, "enemy_hp_loss_ratio": total_ratio})


func _apply_execute_backfire(ratio: float) -> void:
	_apply_qte_damage({"player_hp_loss_ratio": ratio, "enemy_hp_loss_ratio": 0.0})


func _apply_break_to_ui(side: String) -> void:
	var value: int = int(_break_progress.get(side, 0))
	if side == BattleLogicScript.PLAYER and _player_character != null:
		_player_character.set_break_progress(value)
	elif side == BattleLogicScript.ENEMY and _enemy_character != null:
		_enemy_character.set_break_progress(value)


func _apply_momentum_to_ui() -> void:
	if _momentum_fill == null:
		return
	var half_w := MOMENTUM_BAR_WIDTH * 0.5
	var ratio := float(_shared_momentum) / float(MOMENTUM_RANGE)
	if ratio >= 0.0:
		_momentum_fill.position.x = VIEWPORT.x * 0.5
		_momentum_fill.size.x = half_w * ratio
		_momentum_fill.color = Color(0.4, 0.85, 0.4)
	else:
		var w := half_w * -ratio
		_momentum_fill.position.x = VIEWPORT.x * 0.5 - w
		_momentum_fill.size.x = w
		_momentum_fill.color = Color(0.9, 0.35, 0.35)


func _flash_qte() -> void:
	if _judge_line == null:
		return
	_judge_line.color = QTE_FLASH_COLOR
	if not is_inside_tree():
		_judge_line.color = JUDGE_LINE_COLOR
		return
	get_tree().create_timer(float(QTE_FLASH_MS) / 1000.0).timeout.connect(func() -> void:
		if _judge_line != null:
			_judge_line.color = JUDGE_LINE_COLOR
	)


func _play_tap_sfx() -> void:
	if _tap_sfx == null:
		return
	_tap_sfx.stop()
	_tap_sfx.play()


func _on_battle_hp_updated(id: String, hp: int, _max_hp: int) -> void:
	if id == BattleLogicScript.PLAYER:
		if _player_character != null:
			_player_character.set_hp(hp)
	else:
		if _enemy_character != null:
			_enemy_character.set_hp(hp)


func _elapsed_ms() -> int:
	if _test_elapsed_ms >= 0:
		return _test_elapsed_ms
	return Time.get_ticks_msec() - _scene_start_ms


func _blank_summary() -> Dictionary:
	return {"perfect": 0, "good": 0, "bad": 0, "miss": 0}


func _blank_flow_summary() -> Dictionary:
	return {
		"charts_requested": 0,
		"charts_completed": 0,
		"first_chart_target": "",
	}
