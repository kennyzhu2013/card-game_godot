class_name QteController
extends RefCounted

const BAR_LENGTH := 2.0
const PERFECT_MIN := 0.85
const PERFECT_MAX := 1.05
const GOOD_MIN := 0.55
const GOOD_MAX := 1.35


static func resolve(cursor_at_press: float) -> Dictionary:
	if cursor_at_press >= PERFECT_MIN and cursor_at_press <= PERFECT_MAX:
		return {"grade": "Perfect", "mult": 1.5}
	if cursor_at_press >= GOOD_MIN and cursor_at_press <= GOOD_MAX:
		return {"grade": "Good", "mult": 1.0}
	return {"grade": "Bad", "mult": 0.5}
