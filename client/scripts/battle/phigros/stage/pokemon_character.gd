class_name PokemonCharacter
extends Node2D

enum Side { PLAYER, ENEMY }

# Sheet 布局：1024×320，5 行 × 16 列，单帧 64×64。
# 行：idle / walk / attack / hit / cast
# 列：down_0..3 / left_0..3 / right_0..3 / up_0..3
const FRAME_SIZE := 64
const ROW_IDLE := 0
const COL_LEFT_0 := 4
const COL_RIGHT_0 := 8
const DEFAULT_PLAYER_SHEET := "res://assets/sprites/characters/player_mist_iron_adventurer_sheet.png"
const DEFAULT_ENEMY_SHEET := "res://assets/sprites/characters/enemy_shadow_wolf_sheet.png"

@export var side: int = Side.PLAYER
@export var character_name: String = ""
# 允许场景层切换敌方贴图，留空走默认。
@export var sheet_path: String = ""

var _sprite: Sprite2D
var _name_label: Label
var _hp_bar: ColorRect
var _hp_fill: ColorRect
var _break_bar: ColorRect
var _break_fill: ColorRect
var max_hp: int = 180
var current_hp: int = 180
var max_break: int = 100
var current_break: int = 0
const PULSE_SCALE_PEAK := 1.05
const PULSE_TWEEN_MS := 200
const JUDGE_FEEDBACK_PERFECT_SCALE := 1.15
const JUDGE_FEEDBACK_GOOD_SCALE := 1.08
const JUDGE_FEEDBACK_TWEEN_MS := 150
const JUDGE_FEEDBACK_SHAKE_PX := 4

var _pulse_timer: Timer = null
var _pulse_tween: Tween = null
var last_judge_verdict: String = ""
var shake_pending: bool = false


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = _profile_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 64×64 原图按 2× 渲染，最终 128×128，和血条/势条比例匹配。
	_sprite.scale = Vector2(2.0, 2.0)
	add_child(_sprite)

	_name_label = Label.new()
	_name_label.text = character_name
	_name_label.position = Vector2(-48, 72)
	_name_label.size = Vector2(96, 20)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)

	# 血条 / 击破条放到角色头顶。sprite 中心 0,0，向上 64px 是头顶外缘。
	_hp_bar = ColorRect.new()
	_hp_bar.position = Vector2(-40, -88)
	_hp_bar.size = Vector2(80, 6)
	_hp_bar.color = Color(0.2, 0.2, 0.2)
	add_child(_hp_bar)

	_hp_fill = ColorRect.new()
	_hp_fill.position = Vector2(-40, -88)
	_hp_fill.size = Vector2(80, 6)
	_hp_fill.color = Color(0.2, 0.85, 0.3) if side == Side.PLAYER else Color(0.9, 0.2, 0.2)
	add_child(_hp_fill)

	_break_bar = ColorRect.new()
	_break_bar.position = Vector2(-40, -80)
	_break_bar.size = Vector2(80, 4)
	_break_bar.color = Color(0.18, 0.18, 0.22)
	add_child(_break_bar)

	_break_fill = ColorRect.new()
	_break_fill.position = Vector2(-40, -80)
	_break_fill.size = Vector2(0, 4)
	_break_fill.color = Color(0.85, 0.25, 0.85)
	add_child(_break_fill)


func set_hp(hp: int) -> void:
	current_hp = clampi(hp, 0, max_hp)
	if _hp_fill != null:
		_hp_fill.size.x = 80.0 * float(current_hp) / float(max_hp)


func set_break_progress(value: int) -> void:
	current_break = clampi(value, 0, max_break)
	if _break_fill != null:
		_break_fill.size.x = 80.0 * float(current_break) / float(max_break)
		var ratio := float(current_break) / float(max_break)
		if ratio >= 0.99:
			_break_fill.color = Color(1.0, 0.35, 0.25)
		else:
			_break_fill.color = Color(0.85, 0.25, 0.85)


func _profile_texture() -> Texture2D:
	# 玩家在左侧，用 right_0 帧（侧脸朝右）；敌人在右侧，用 left_0 帧（侧脸朝左）——形成面对面。
	var path := sheet_path
	if path.is_empty():
		path = DEFAULT_PLAYER_SHEET if side == Side.PLAYER else DEFAULT_ENEMY_SHEET
	var sheet: Texture2D = load(path)
	if sheet == null:
		return _fallback_texture()
	var col := COL_RIGHT_0 if side == Side.PLAYER else COL_LEFT_0
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * FRAME_SIZE, ROW_IDLE * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
	return atlas


func _fallback_texture() -> Texture2D:
	# 资源缺失兜底：纯色方块，避免渲染空。
	var image := Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	var color := Color(0.22, 0.48, 0.95) if side == Side.PLAYER else Color(0.9, 0.2, 0.24)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func compute_pulse_period_ms(bpm: int) -> int:
	if bpm <= 0:
		return 0
	return int(round(60000.0 / float(bpm)))


func is_pulsing() -> bool:
	return _pulse_timer != null and is_instance_valid(_pulse_timer) and not _pulse_timer.is_stopped()


func start_bpm_pulse(bpm: int) -> void:
	stop_bpm_pulse()
	var period_ms := compute_pulse_period_ms(bpm)
	if period_ms <= 0:
		return
	if not is_inside_tree():
		_pulse_timer = Timer.new()
		_pulse_timer.wait_time = float(period_ms) / 1000.0
		return
	_pulse_timer = Timer.new()
	_pulse_timer.wait_time = float(period_ms) / 1000.0
	_pulse_timer.autostart = true
	_pulse_timer.one_shot = false
	add_child(_pulse_timer)
	_pulse_timer.timeout.connect(_on_pulse_tick)


func stop_bpm_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if _pulse_timer != null:
		if is_instance_valid(_pulse_timer) and _pulse_timer.is_inside_tree():
			_pulse_timer.stop()
			_pulse_timer.queue_free()
		_pulse_timer = null
	if _sprite != null:
		_sprite.scale = Vector2(2.0, 2.0)


func _on_pulse_tick() -> void:
	if _sprite == null or not is_inside_tree():
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	var half := float(PULSE_TWEEN_MS) * 0.5 / 1000.0
	_pulse_tween.tween_property(_sprite, "scale", Vector2(2.0 * PULSE_SCALE_PEAK, 2.0 * PULSE_SCALE_PEAK), half)
	_pulse_tween.tween_property(_sprite, "scale", Vector2(2.0, 2.0), half)


func play_judge_feedback(verdict: String) -> void:
	last_judge_verdict = verdict
	shake_pending = (verdict == "miss")
	if _sprite == null or not is_inside_tree():
		return
	var dur := float(JUDGE_FEEDBACK_TWEEN_MS) * 0.5 / 1000.0
	var tw := create_tween()
	match verdict:
		"perfect":
			tw.tween_property(_sprite, "scale", Vector2(2.0 * JUDGE_FEEDBACK_PERFECT_SCALE, 2.0 * JUDGE_FEEDBACK_PERFECT_SCALE), dur)
			tw.tween_property(_sprite, "scale", Vector2(2.0, 2.0), dur)
		"good":
			tw.tween_property(_sprite, "scale", Vector2(2.0 * JUDGE_FEEDBACK_GOOD_SCALE, 2.0 * JUDGE_FEEDBACK_GOOD_SCALE), dur)
			tw.tween_property(_sprite, "scale", Vector2(2.0, 2.0), dur)
		"bad":
			tw.tween_property(_sprite, "modulate", Color(1.4, 1.0, 0.4), dur)
			tw.tween_property(_sprite, "modulate", Color.WHITE, dur)
		"miss":
			tw.tween_property(_sprite, "modulate", Color(1.6, 0.5, 0.5), dur)
			tw.tween_property(_sprite, "position:x", _sprite.position.x + JUDGE_FEEDBACK_SHAKE_PX, dur * 0.5)
			tw.tween_property(_sprite, "position:x", _sprite.position.x, dur * 0.5)
			tw.tween_property(_sprite, "modulate", Color.WHITE, dur)


func play_attack_pose() -> void:
	if _sprite == null or not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(2.2, 2.2), 0.15)
	tw.tween_property(_sprite, "scale", Vector2(2.0, 2.0), 0.15)
