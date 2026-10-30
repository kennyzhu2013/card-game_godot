class_name DuelDirector
extends RefCounted

const SEGMENT_DELTA_CAP := 0.5
const BAR_RANGE := 1.0
const THRESHOLD := 0.6
const HP_DAMAGE_WIN := 0.30
const HP_DAMAGE_LOSE := 0.20
const HP_DAMAGE_DRAW := 0.05
const SEGMENTS := 3

var bar_value: float = 0.0
var current_segment: int = 0


func score_for_summary(summary: Dictionary) -> int:
	var p := int(summary.get("perfect", 0))
	var g := int(summary.get("good", 0))
	var b := int(summary.get("bad", 0))
	var m := int(summary.get("miss", 0))
	return p * 3 + g * 1 + b * 0 + m * -2


func normalized_delta(player_score: int, enemy_score: int) -> float:
	var raw := float(player_score - enemy_score) / 16.0
	return clampf(raw, -SEGMENT_DELTA_CAP, SEGMENT_DELTA_CAP)


func apply_segment(player_score: int, enemy_score: int) -> void:
	bar_value = clampf(bar_value + normalized_delta(player_score, enemy_score), -BAR_RANGE, BAR_RANGE)
	current_segment += 1


func outcome() -> String:
	if bar_value >= THRESHOLD:
		return "PLAYER_WIN"
	if bar_value <= -THRESHOLD:
		return "PLAYER_LOSE"
	return "DRAW"


func resolve_damage() -> Dictionary:
	match outcome():
		"PLAYER_WIN":
			return {
				"player_hp_loss_ratio": 0.0,
				"enemy_hp_loss_ratio": HP_DAMAGE_WIN,
				"debuff_target": "enemy",
			}
		"PLAYER_LOSE":
			return {
				"player_hp_loss_ratio": HP_DAMAGE_LOSE,
				"enemy_hp_loss_ratio": 0.0,
				"debuff_target": "player",
			}
	return {
		"player_hp_loss_ratio": HP_DAMAGE_DRAW,
		"enemy_hp_loss_ratio": HP_DAMAGE_DRAW,
		"debuff_target": "",
	}
