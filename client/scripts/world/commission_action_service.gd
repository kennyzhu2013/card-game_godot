class_name CommissionActionService
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const SequenceExpServiceScript = preload("res://scripts/sequence/sequence_exp_service.gd")
const TimeAdvanceServiceScript = preload("res://scripts/world/time_advance_service.gd")


static func execute_placeholder(game_state, commission_id: String, includes_tower: bool = false, tower_size: String = "") -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if commission_id in game_state.completed_commissions:
		return {"ok": false, "reason": "already_completed"}
	if commission_id == "" or not commission_id in game_state.accepted_commissions:
		return {"ok": false, "reason": "not_accepted"}
	var pending_id := _pending_commission_id(game_state)
	if pending_id == commission_id:
		return {"ok": false, "reason": "already_pending"}
	if pending_id != "":
		return {"ok": false, "reason": "pending_exists", "pending_commission_id": pending_id}
	var cost := ApServiceScript.commission_execution_cost(includes_tower, tower_size)
	var spend: Dictionary = ApServiceScript.try_spend(game_state, cost, "commission_execution")
	if not bool(spend.get("ok", false)):
		return spend
	if game_state.has_method("set_meta"):
		game_state.set_meta("commission_pending_completion", commission_id)
		game_state.set_meta("commission_pending_includes_tower", includes_tower)
	var time_result: Dictionary = TimeAdvanceServiceScript.advance_for_action(game_state, "job")
	return {
		"ok": true,
		"reason": "ok",
		"commission_id": commission_id,
		"ap_cost": cost,
		"includes_tower": includes_tower,
		"tower_size": tower_size,
		"pending_completion": true,
		"time_result": time_result,
	}


static func complete_placeholder(game_state, commission_id: String) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if commission_id in game_state.completed_commissions:
		return {"ok": false, "reason": "already_completed"}
	if commission_id == "" or not commission_id in game_state.accepted_commissions:
		return {"ok": false, "reason": "not_accepted"}
	var pending_id := _pending_commission_id(game_state)
	if pending_id != commission_id:
		return {"ok": false, "reason": "not_pending", "pending_commission_id": pending_id}
	var includes_tower := false
	if game_state.has_method("get_meta"):
		includes_tower = bool(game_state.get_meta("commission_pending_includes_tower", false))
	var exp_result: Dictionary = SequenceExpServiceScript.add_exp(
		game_state,
		SequenceExpServiceScript.commission_base_exp(includes_tower),
		"commission"
	)
	game_state.accepted_commissions.erase(commission_id)
	if not commission_id in game_state.completed_commissions:
		game_state.completed_commissions.append(commission_id)
	_clear_pending_completion(game_state)
	return {
		"ok": true,
		"reason": "ok",
		"commission_id": commission_id,
		"includes_tower": includes_tower,
		"base_sequence_exp": int(exp_result.get("base_sequence_exp", 0)),
		"sequence_exp_delta": int(exp_result.get("sequence_exp_delta", 0)),
		"promotion_available": bool(exp_result.get("promotion_available", false)),
		"promotion_gate_id": str(exp_result.get("promotion_gate_id", "")),
	}


static func _pending_commission_id(game_state) -> String:
	if game_state == null or not game_state.has_method("get_meta"):
		return ""
	return str(game_state.get_meta("commission_pending_completion", ""))


static func _clear_pending_completion(game_state) -> void:
	if game_state == null:
		return
	for key in ["commission_pending_completion", "commission_pending_includes_tower"]:
		if game_state.has_method("remove_meta") and game_state.has_meta(key):
			game_state.remove_meta(key)
		elif game_state.has_method("set_meta"):
			game_state.set_meta(key, null)
