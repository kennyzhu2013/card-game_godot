class_name ExecuteDirector
extends RefCounted

const PHASE_AXES_NOTES_INTERVAL := [
	[6, 12, 180, false],
	[8, 16, 150, false],
	[8, 20, 120, true],
]
const BACKFIRE_RATIO := 0.10


func punish_segment_damage_ratio(perfect: int, total: int) -> float:
	if total <= 0:
		return 0.0
	var pct := float(perfect) / float(total)
	if pct >= 0.50:
		return 0.05
	if pct >= 0.25:
		return 0.15
	return 0.25


func challenge_segment_damage(perfect: int, total: int) -> Dictionary:
	if total <= 0:
		return {"enemy_ratio": 0.0, "player_backfire_ratio": 0.0}
	var pct := float(perfect) / float(total)
	var enemy_ratio := 0.05
	var backfire := 0.0
	if pct >= 0.80:
		enemy_ratio = 0.50
	elif pct >= 0.60:
		enemy_ratio = 0.30
	elif pct >= 0.40:
		enemy_ratio = 0.20
	elif pct >= 0.20:
		enemy_ratio = 0.10
	else:
		enemy_ratio = 0.05
		backfire = BACKFIRE_RATIO
	return {"enemy_ratio": enemy_ratio, "player_backfire_ratio": backfire}


func phase_count() -> int:
	return PHASE_AXES_NOTES_INTERVAL.size()


func phase_params(idx: int) -> Dictionary:
	if idx < 0 or idx >= PHASE_AXES_NOTES_INTERVAL.size():
		return {}
	var entry: Array = PHASE_AXES_NOTES_INTERVAL[idx]
	return {
		"axes": int(entry[0]),
		"beat_count": int(entry[1]),
		"interval_ms": int(entry[2]),
		"double_tap": bool(entry[3]),
	}
