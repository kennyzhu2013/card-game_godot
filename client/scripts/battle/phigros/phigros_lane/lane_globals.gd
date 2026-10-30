# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Original author: Naptie (https://github.com/Naptie/godot-phigros)
# Adapted for TurnBasedOpenWorld phigros Pokemon rehost, 2026-05-13.
class_name LaneGlobals
extends RefCounted

const BASE_WIDTH := 960.0
const BASE_HEIGHT := 540.0
const EPS := 1e-4
const NOTE_SIZE := 0.25


static func ct(time_in_seconds: float, bpm: float) -> float:
	return time_in_seconds * bpm * 32.0 / 60.0


static func cs(chart_time: float, bpm: float) -> float:
	return chart_time * 60.0 / bpm / 32.0


static func is_in_screen(pos: Vector2) -> bool:
	return is_in_area(pos, Vector2(-BASE_WIDTH / 2.0, -BASE_HEIGHT / 2.0), Vector2(BASE_WIDTH / 2.0, BASE_HEIGHT / 2.0))


static func is_in_area(pos: Vector2, top_left: Vector2, bottom_right: Vector2) -> bool:
	return pos.x >= top_left.x - EPS and pos.x <= bottom_right.x + EPS \
		and pos.y >= top_left.y - EPS and pos.y <= bottom_right.y + EPS
