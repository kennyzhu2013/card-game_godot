class_name TimeAdvanceService
extends RefCounted

const DayCycleServiceScript = preload("res://scripts/world/day_cycle_service.gd")

const ADVANCING_ACTIONS := {
	"job": true,
	"meditation": true,
	"drill": true,
	"tower_return": true,
	"debug_wait": true,
}
const NON_ADVANCING_ACTIONS := {
	"roam": true,
	"short_chat": true,
	"listen_rumor": true,
	"casino_round": true,
}


static func should_advance(action_id: String) -> bool:
	return bool(ADVANCING_ACTIONS.get(action_id, false))


static func advance_for_action(game_state, action_id: String, auto_save_path: String = "user://day_cycle_auto.json", weather_roll: float = -1.0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "advanced": false}
	var id := str(action_id)
	if bool(NON_ADVANCING_ACTIONS.get(id, false)) or not should_advance(id):
		return {
			"ok": true,
			"reason": "no_advance",
			"action_id": id,
			"advanced": false,
			"time_of_day": str(game_state.time_of_day),
		}
	if str(game_state.time_of_day) == "night":
		if game_state.has_method("set_meta"):
			game_state.set_meta("force_sleep_pending", true)
		return {
			"ok": true,
			"reason": "forced_sleep_required",
			"action_id": id,
			"advanced": false,
			"forced_sleep_required": true,
			"time_of_day": str(game_state.time_of_day),
		}
	var result: Dictionary = DayCycleServiceScript.advance_time_segment(game_state, auto_save_path, weather_roll)
	result["action_id"] = id
	result["advanced"] = bool(result.get("ok", false)) and not bool(result.get("forced_sleep_required", false))
	return result
