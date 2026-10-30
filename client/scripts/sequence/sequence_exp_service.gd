class_name SequenceExpService
extends RefCounted

const WeatherEffectsApplierScript = preload("res://scripts/state/weather_effects_applier.gd")
const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")


static func add_exp(game_state, base_amount: int, source: String) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var base_exp := maxi(0, base_amount)
	var bonus_percent := WeatherEffectsApplierScript.get_bonus(str(game_state.current_weather), str(game_state.pathway), "sequence_exp")
	var delta := int(round(float(base_exp) * (1.0 + float(bonus_percent) / 100.0)))
	game_state.sequence_exp = int(game_state.sequence_exp) + delta
	if game_state.has_method("set_meta"):
		game_state.set_meta("last_sequence_exp_source", source)
		game_state.set_meta("last_sequence_exp_base", base_exp)
		game_state.set_meta("last_sequence_exp_delta", delta)
	var gate_result: Dictionary = PromotionRitualServiceScript.check_after_exp_gain(game_state)
	return {
		"ok": true,
		"source": source,
		"base_sequence_exp": base_exp,
		"sequence_exp_bonus_percent": bonus_percent,
		"sequence_exp_delta": delta,
		"sequence_exp_total": int(game_state.sequence_exp),
		"promotion_available": bool(gate_result.get("can_promote", false)),
		"promotion_gate_id": str(gate_result.get("gate_id", "")),
	}


static func battle_victory_base_exp(enemies: Array) -> int:
	var max_tier := 1
	for enemy in enemies:
		if enemy != null:
			max_tier = maxi(max_tier, int(enemy.tier))
	if max_tier >= 3:
		return 10
	if max_tier == 2:
		return 8
	return 5


static func commission_base_exp(includes_tower: bool) -> int:
	if includes_tower:
		return 10
	return 5
