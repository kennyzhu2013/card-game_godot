# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Original author: Naptie (https://github.com/Naptie/godot-phigros)
# Adapted for TurnBasedOpenWorld phigros Pokemon rehost, 2026-05-13.
class_name LaneJudgeline
extends RefCounted

const LG = preload("res://scripts/battle/phigros/phigros_lane/lane_globals.gd")

# Speed events are stored as Dictionaries with keys:
#   start_time: float, end_time: float, value: float
# Move/rotate events use the same Dictionary shape with additional keys
# (start, end, start2, end2) when used as DurationalEvent / DurationalVectorEvent.

var bpm: float = 120.0
var direction: int = 1
var speed_events: Array = []
var move_events: Array = []
var rotate_events: Array = []
var height_time: Array = []
var height_time_cache: Dictionary = {}
var height_cache: Array = []
var current_height: int = 0
var current_move: int = 0
var current_rotate: int = 0


static func make_speed_event(start_time: float, end_time: float, value: float) -> Dictionary:
	return {"start_time": start_time, "end_time": end_time, "value": value}


func setup_speed_events(events: Array) -> void:
	speed_events = events
	height_time.clear()
	height_cache.clear()
	height_time_cache.clear()
	current_height = 0
	var height := 0.0
	height_time.append(0.0)
	height_cache.append(0.0)
	for ev in events:
		var end_time := float(ev["end_time"])
		var start_time := float(ev["start_time"])
		var value := float(ev["value"])
		height_time.append(end_time)
		height += (end_time - start_time) * value
		height_cache.append(height)


func handle_heights(time: float) -> void:
	while current_height < height_time.size() - 2 and time >= height_time[current_height + 1]:
		current_height += 1


func calculate_distance(time: float, note_time: float) -> float:
	if is_equal_approx(time, note_time):
		return 0.0
	var modifier := 1.0
	var t := time
	var nt := note_time
	if t > nt:
		var temp := nt
		nt = t
		t = temp
		modifier = -1.0
	var end_index: int
	if height_time_cache.has(nt):
		end_index = int(height_time_cache[nt])
	else:
		end_index = height_time.bsearch(nt)
		height_time_cache[nt] = end_index
	var remainder_end: float
	if end_index >= height_time.size():
		var event = speed_events[speed_events.size() - 1]
		remainder_end = (nt - float(event["start_time"])) * float(event["value"])
	else:
		remainder_end = float(height_cache[end_index] - height_cache[end_index - 1]) \
			* (nt - float(height_time[end_index - 1])) / float(height_time[end_index] - height_time[end_index - 1])
	var remainder_start: float = float(height_cache[current_height + 1] - height_cache[current_height]) \
		* (float(height_time[current_height + 1]) - t) / float(height_time[current_height + 1] - height_time[current_height])
	var raw: float = modifier * (remainder_start + remainder_end + float(height_cache[end_index - 1]) - float(height_cache[current_height + 1]))
	return LG.cs(raw * 0.6 * LG.BASE_HEIGHT, bpm)


func note_y_position(time: float, note_time: float) -> float:
	return -calculate_distance(time, note_time) * direction
