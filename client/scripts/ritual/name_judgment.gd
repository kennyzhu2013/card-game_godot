class_name NameJudgment
extends RefCounted

const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")

const CHAIN_ID := "pendulum_chain"
const REQUIRED_STEP := 3
const NEXT_STEP := 4
const PROMOTION_NODE_ID := "node_4b_promotion_87"
const PROMOTION_GATE_ID := "fool_8_to_7"


func can_start(game_state) -> bool:
	if game_state == null:
		return false
	var state = _chain_state(game_state)
	if state == null:
		return false
	if bool(state.get("locked")):
		return false
	return int(state.get("current_step")) >= REQUIRED_STEP


func resolve_judgment(game_state, choice_id: String) -> Dictionary:
	if not can_start(game_state):
		return {"ok": false, "reason": "chain_step_locked"}
	match choice_id:
		"speak_true_name":
			_set_story_flag(game_state, "pendulum_ending", "true_name_judged")
			_record_completed_node(game_state, PROMOTION_NODE_ID)
			_advance_chain(game_state, choice_id)
			var promotion_check: Dictionary = PromotionRitualServiceScript.check_after_exp_gain(game_state)
			return {
				"ok": true,
				"choice_id": choice_id,
				"story_flag": "true_name_judged",
				"completed_node_id": PROMOTION_NODE_ID,
				"promotion_gate_id": PROMOTION_GATE_ID,
				"promotion_check": promotion_check,
			}
		"hide_name":
			_set_story_flag(game_state, "pendulum_ending", "name_hidden")
			_advance_chain(game_state, choice_id)
			return {
				"ok": true,
				"choice_id": choice_id,
				"story_flag": "name_hidden",
			}
		_:
			return {"ok": false, "reason": "unknown_choice", "choice_id": choice_id}


func _chain_state(game_state):
	var chains: Variant = game_state.get("encounter_chains")
	if not chains is Dictionary:
		return null
	return (chains as Dictionary).get(CHAIN_ID, null)


func _advance_chain(game_state, choice_id: String) -> void:
	var state = _chain_state(game_state)
	if state == null:
		return
	if state is Object and state.has_method("record_step"):
		state.record_step(REQUIRED_STEP, "name_judgment", choice_id, int(game_state.day))
	var next_step: int = maxi(int(state.get("current_step")), NEXT_STEP)
	if state is Dictionary:
		state["current_step"] = next_step
	else:
		state.current_step = next_step


func _set_story_flag(game_state, key: String, value: String) -> void:
	var flags: Variant = game_state.get("story_flags")
	var target: Dictionary = {}
	if flags is Dictionary:
		target = (flags as Dictionary)
	target[key] = value
	game_state.set("story_flags", target)


func _record_completed_node(game_state, node_id: String) -> void:
	var daodian: Variant = game_state.get("daodian")
	var target: Dictionary = {}
	if daodian is Dictionary:
		target = (daodian as Dictionary)
	var raw_nodes: Variant = target.get("completed_main_story_nodes", [])
	var completed: Array = []
	if raw_nodes is Array:
		completed = (raw_nodes as Array).duplicate()
	if not node_id in completed:
		completed.append(node_id)
	target["completed_main_story_nodes"] = completed
	game_state.set("daodian", target)
