class_name MeditationService
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const WeatherEffectsApplierScript = preload("res://scripts/state/weather_effects_applier.gd")
const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")
const SequenceExpServiceScript = preload("res://scripts/sequence/sequence_exp_service.gd")
const TimeAdvanceServiceScript = preload("res://scripts/world/time_advance_service.gd")

const DAILY_LIMIT := 3
const RATING_PERFECT := "perfect"
const RATING_GOOD := "good"
const RATING_OK := "ok"
const RATING_FAILED := "failed"

const EXP_BY_RATING := {
	RATING_PERFECT: 20,
	RATING_GOOD: 15,
	RATING_OK: 10,
	RATING_FAILED: 3,
}

const POLLUTION_BY_RATING := {
	RATING_PERFECT: -1,
	RATING_GOOD: 0,
	RATING_OK: 0,
	RATING_FAILED: 2,
}


static func can_start(game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if int(game_state.meditation_count_today) >= DAILY_LIMIT:
		return {"ok": false, "reason": "daily_limit"}
	if not ApServiceScript.can_afford(game_state, ApServiceScript.MEDITATION_COST):
		return {"ok": false, "reason": "ap_short"}
	return {"ok": true, "reason": "ok"}


static func start_session(game_state) -> Dictionary:
	var check: Dictionary = can_start(game_state)
	if not bool(check.get("ok", false)):
		return check
	var spend: Dictionary = ApServiceScript.try_spend_meditation(game_state)
	if not bool(spend.get("ok", false)):
		return spend
	if game_state.has_method("record_meditation_use"):
		game_state.record_meditation_use()
	else:
		game_state.meditation_count_today += 1
	return {
		"ok": true,
		"reason": "ok",
		"ap_cost": ApServiceScript.MEDITATION_COST,
		"meditation_count_today": int(game_state.meditation_count_today),
	}


static func start_placeholder_session(game_state) -> Dictionary:
	return start_session(game_state)


static func resolve_session(game_state, player_summary: Dictionary, mouse_summary: Dictionary = {}) -> Dictionary:
	var start: Dictionary = start_session(game_state)
	if not bool(start.get("ok", false)):
		return start
	var result: Dictionary = resolve_started_session(game_state, player_summary, mouse_summary)
	result["ap_cost"] = ApServiceScript.MEDITATION_COST
	result["meditation_count_today"] = int(game_state.meditation_count_today)
	return result


static func resolve_started_session(game_state, player_summary: Dictionary, mouse_summary: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var summary := _merge_summaries(player_summary, mouse_summary)
	var rating := rating_from_summary(summary)
	var base_exp := int(EXP_BY_RATING.get(rating, 0))
	var pollution_delta := int(POLLUTION_BY_RATING.get(rating, 0))
	game_state.pollution = maxi(0, int(game_state.pollution) + pollution_delta)
	game_state.pollution_stage = _pollution_stage(int(game_state.pollution))
	var exp_result: Dictionary = SequenceExpServiceScript.add_exp(game_state, base_exp, "meditation")
	var bonus_percent := int(exp_result.get("sequence_exp_bonus_percent", 0))
	var exp_delta := int(exp_result.get("sequence_exp_delta", 0))
	var time_result: Dictionary = TimeAdvanceServiceScript.advance_for_action(game_state, "meditation")
	return {
		"ok": true,
		"reason": "ok",
		"rating": rating,
		"summary": summary,
		"base_sequence_exp": base_exp,
		"sequence_exp_bonus_percent": bonus_percent,
		"sequence_exp_delta": exp_delta,
		"pollution_delta": pollution_delta,
		"time_result": time_result,
		"promotion_available": bool(exp_result.get("promotion_available", false)),
		"promotion_gate_id": str(exp_result.get("promotion_gate_id", "")),
	}


static func rating_from_summary(summary: Dictionary) -> String:
	var perfect := int(summary.get("perfect", 0))
	var good := int(summary.get("good", 0))
	var bad := int(summary.get("bad", 0))
	var miss := int(summary.get("miss", 0))
	var total := perfect + good + bad + miss
	if total <= 0:
		return RATING_FAILED
	var score := (float(perfect) + float(good) * 0.8 + float(bad) * 0.45) / float(total)
	if score >= 0.98:
		return RATING_PERFECT
	if score >= 0.8:
		return RATING_GOOD
	if score >= 0.45:
		return RATING_OK
	return RATING_FAILED


static func _merge_summaries(player_summary: Dictionary, mouse_summary: Dictionary) -> Dictionary:
	var result := {"perfect": 0, "good": 0, "bad": 0, "miss": 0}
	for key in result.keys():
		result[key] = int(player_summary.get(key, 0)) + int(mouse_summary.get(key, 0))
	return result


static func _pollution_stage(value: int) -> int:
	if value >= 95:
		return 4
	if value >= 80:
		return 3
	if value >= 50:
		return 2
	if value >= 30:
		return 1
	return 0
