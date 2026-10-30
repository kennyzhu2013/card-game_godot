# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Original author: Naptie (https://github.com/Naptie/godot-phigros)
# Adapted for TurnBasedOpenWorld phigros Pokemon rehost, 2026-05-13.
# Modified 2026-05-26: self-rendering via _draw() to remove Tap.png dependency.
class_name LaneNotePart
extends Node2D

signal on_judge(verdict: String, offset_ms: int, lane: int)

const PERFECT_WINDOW_MS := 40
const GOOD_WINDOW_MS := 80
const BAD_WINDOW_MS := 120
const BREAK_SHRINK_MS := 20

const COLOR_PERFECT := Color8(255, 255, 180)
const COLOR_GOOD := Color8(179, 236, 255)
const COLOR_BAD := Color8(255, 255, 255)

const NOTE_SIZE := Vector2(56, 14)
var note_color := Color(1.0, 1.0, 0.7, 0.95)

var note_id: int = 0
var note_time_ms: int = 0
var lane: int = 0
var direction: int = 1
var judged: bool = false
var current_verdict: String = ""


func _ready() -> void:
	queue_redraw()


func setup(p_id: int, p_time_ms: int, p_lane: int, p_direction: int) -> void:
	note_id = p_id
	note_time_ms = p_time_ms
	lane = p_lane
	direction = p_direction


func _draw() -> void:
	if judged:
		return
	draw_rect(Rect2(-NOTE_SIZE.x * 0.5, -NOTE_SIZE.y * 0.5, NOTE_SIZE.x, NOTE_SIZE.y), note_color, true)
	draw_rect(Rect2(-NOTE_SIZE.x * 0.5, -NOTE_SIZE.y * 0.5, NOTE_SIZE.x, NOTE_SIZE.y), Color(1, 1, 1, 0.3), false)


func flash_verdict(verdict: String) -> void:
	match verdict:
		"perfect": note_color = Color(1.0, 1.0, 0.3, 0.95)
		"good":    note_color = Color(0.4, 0.9, 1.0, 0.95)
		"bad":     note_color = Color(0.7, 0.7, 0.7, 0.95)
		_:         note_color = Color(0.9, 0.3, 0.3, 0.95)
	queue_redraw()


func judge_at(input_time_ms: int, break_window_active: bool) -> String:
	if judged:
		return ""
	var offset := input_time_ms - note_time_ms
	var abs_offset := absi(offset)
	var shrink := BREAK_SHRINK_MS if break_window_active else 0
	var perfect_w := maxi(PERFECT_WINDOW_MS - shrink, 0)
	var good_w := maxi(GOOD_WINDOW_MS - shrink, 0)
	var bad_w := maxi(BAD_WINDOW_MS - shrink, 0)
	var verdict: String
	if abs_offset <= perfect_w:
		verdict = "perfect"
	elif abs_offset <= good_w:
		verdict = "good"
	elif abs_offset <= bad_w:
		verdict = "bad"
	else:
		verdict = "miss"
	judged = true
	current_verdict = verdict
	on_judge.emit(verdict, offset, lane)
	queue_redraw()
	return verdict


func mark_miss() -> void:
	if judged:
		return
	judged = true
	current_verdict = "miss"
	on_judge.emit("miss", BAD_WINDOW_MS + 1, lane)
	queue_redraw()
