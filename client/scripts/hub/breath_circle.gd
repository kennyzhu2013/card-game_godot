extends Control

var _breath_amount: float = 0.0


func set_breath_amount(value: float) -> void:
	_breath_amount = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var max_radius := minf(size.x, size.y) * 0.42
	var radius := lerpf(max_radius * 0.48, max_radius, _breath_amount)
	draw_circle(center, radius + 8.0, Color(0.25, 0.42, 0.58, 0.18))
	draw_circle(center, radius, Color(0.38, 0.72, 0.86, 0.75))
	draw_arc(center, max_radius, 0.0, TAU, 96, Color(0.85, 0.92, 0.95, 0.45), 2.0)
