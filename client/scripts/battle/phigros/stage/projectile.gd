class_name Projectile
extends Node2D

signal completed

const SIZE := Vector2(28, 28)
const FLY_OUT_MS := 300
const HIT_PAUSE_MS := 200
const RETURN_MS := 200


func setup(start_pos: Vector2, hit_pos: Vector2, return_pos: Vector2, color: Color = Color(1.0, 0.95, 0.5, 0.95)) -> void:
	position = start_pos
	var rect := ColorRect.new()
	rect.size = SIZE
	rect.position = -SIZE * 0.5
	rect.color = color
	add_child(rect)
	if not is_inside_tree():
		_emit_completed_deferred()
		return
	var tw := create_tween()
	tw.tween_property(self, "position", hit_pos, float(FLY_OUT_MS) / 1000.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(float(HIT_PAUSE_MS) / 1000.0)
	tw.tween_property(self, "position", return_pos, float(RETURN_MS) / 1000.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		completed.emit()
		queue_free()
	)


func _emit_completed_deferred() -> void:
	call_deferred("emit_signal", "completed")
