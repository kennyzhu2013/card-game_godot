# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Original author: Naptie (https://github.com/Naptie/godot-phigros)
# Adapted for TurnBasedOpenWorld phigros Pokemon rehost, 2026-05-13.
extends Node2D

const SQUARE_SCENE = preload("res://scripts/battle/phigros/phigros_lane/square.tscn")
const COUNT_PER_HIT := 6


func emit_at(world_pos: Vector2, color: Color) -> void:
	for i in range(COUNT_PER_HIT):
		var sq = SQUARE_SCENE.instantiate()
		sq.position = world_pos
		sq.travel = Vector2(randf_range(-20, 20), randf_range(-30, -10))
		sq.modulate = color
		add_child(sq)
