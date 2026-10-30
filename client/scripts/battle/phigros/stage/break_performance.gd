class_name BreakPerformance
extends Node2D

signal finished

const VIEWPORT := Vector2(960, 540)
const LINE_SHRINK_MS := 180
const FLASH_MS := 200
const PARTICLE_MS := 600
const LABEL_MS := 800
const TOTAL_MS := 1500
const LABEL_FONT_SIZE := 96

var _playing: bool = false


func total_duration_ms() -> int:
	return TOTAL_MS


func is_playing() -> bool:
	return _playing


func play(judge_line, broken_character) -> Signal:
	if _playing:
		return finished
	_playing = true
	var tree := get_tree()
	if tree == null:
		_playing = false
		call_deferred("emit_signal", "finished")
		call_deferred("queue_free")
		return finished
	if judge_line != null:
		var line_tw: Tween = judge_line.create_tween()
		line_tw.tween_property(judge_line, "scale:x", 0.0, float(LINE_SHRINK_MS) / 1000.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tree.create_timer(0.1).timeout
	var flash := ColorRect.new()
	flash.size = VIEWPORT
	flash.color = Color(1, 1, 1, 0)
	add_child(flash)
	var flash_tw: Tween = flash.create_tween()
	var half := float(FLASH_MS) * 0.5 / 1000.0
	flash_tw.tween_property(flash, "color:a", 1.0, half)
	flash_tw.tween_property(flash, "color:a", 0.0, half)
	flash_tw.tween_callback(flash.queue_free)
	await tree.create_timer(0.2).timeout
	if broken_character != null and is_instance_valid(broken_character):
		var particles := CPUParticles2D.new()
		particles.position = broken_character.position
		particles.amount = 32
		particles.lifetime = float(PARTICLE_MS) / 1000.0
		particles.one_shot = true
		particles.emitting = true
		particles.spread = 180.0
		particles.initial_velocity_min = 80.0
		particles.initial_velocity_max = 160.0
		particles.gravity = Vector2(0, 200)
		particles.color = Color(0.6, 0.2, 0.2)
		particles.scale_amount_min = 1.5
		particles.scale_amount_max = 3.0
		add_child(particles)
		var part_timer := tree.create_timer(float(PARTICLE_MS) / 1000.0 + 0.1)
		part_timer.timeout.connect(particles.queue_free)
	await tree.create_timer(0.2).timeout
	var label := Label.new()
	label.text = "BREAK!"
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.position = Vector2(VIEWPORT.x * 0.5 - 160, VIEWPORT.y * 0.5 - 60)
	label.scale = Vector2(0.0, 0.0)
	label.pivot_offset = Vector2(160, 60)
	add_child(label)
	var label_tw: Tween = label.create_tween()
	label_tw.tween_property(label, "scale", Vector2(1.5, 1.5), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	label_tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.12)
	label_tw.tween_interval(0.3)
	label_tw.tween_property(label, "modulate:a", 0.0, 0.2)
	label_tw.tween_callback(label.queue_free)
	await tree.create_timer(float(LABEL_MS) / 1000.0).timeout
	await tree.create_timer(0.2).timeout
	if judge_line != null and is_instance_valid(judge_line):
		judge_line.scale = Vector2(1.0, 1.0)
	_playing = false
	finished.emit()
	queue_free()
	return finished
