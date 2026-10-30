# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Original author: Naptie (https://github.com/Naptie/godot-phigros)
# Adapted for TurnBasedOpenWorld phigros Pokemon rehost, 2026-05-13.
extends Node2D

@export var lifetime: float = 0.5
@export var travel: Vector2 = Vector2(0, -40)
var _t: float = 0.0
var _start_pos: Vector2


func _ready() -> void:
	_start_pos = position


func _process(delta: float) -> void:
	_t += delta
	var f := clampf(_t / lifetime, 0.0, 1.0)
	position = _start_pos + travel * f
	modulate.a = 1.0 - f
	if _t >= lifetime:
		queue_free()
