class_name FateMinigame
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const GAME_ID := "fate_cards"
const FIXED_BET := 200
const CYCLE_LIMIT := 2


func play(game_state, options: Dictionary) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if int(game_state.day) < 5:
		return {"ok": false, "reason": "day_locked", "day_required": 5}
	if int(options.get("bet", FIXED_BET)) != FIXED_BET:
		return {"ok": false, "reason": "fixed_bet_required", "bet": FIXED_BET}
	if _cycle_count(game_state) >= CYCLE_LIMIT:
		return {"ok": false, "reason": "cycle_limit", "limit": CYCLE_LIMIT}
	if int(game_state.ap) < ApServiceScript.casino_round_cost():
		return {"ok": false, "reason": "ap_short", "cost": ApServiceScript.casino_round_cost(), "remaining": int(game_state.ap)}
	if int(game_state.lingstones) < FIXED_BET:
		return {"ok": false, "reason": "lingstones_short", "bet": FIXED_BET, "lingstones": int(game_state.lingstones)}
	game_state.spend_ap(ApServiceScript.casino_round_cost())
	game_state.lingstones -= FIXED_BET
	var correct := str(options.get("choice_id", "")) == str(options.get("truth_id", ""))
	if game_state.has_method("adjust_church_awareness"):
		game_state.adjust_church_awareness(5, GAME_ID)
	else:
		game_state.church_awareness = clampi(int(game_state.church_awareness) + 5, 0, 100)
	_record_cycle_use(game_state)
	if correct:
		game_state.dao_pages += 1
		var node_id := str(options.get("advance_node_id", "node_fate_cards_%d" % _cycle_count(game_state)))
		_record_mainline_node(game_state, node_id)
		return {
			"ok": true,
			"id": GAME_ID,
			"grade": "correct",
			"mainline_advanced": true,
			"advanced_node_id": node_id,
			"church_awareness_delta": 5,
			"dao_pages_delta": 1,
		}
	_add_suspicion(game_state, "eel_fan", 3)
	return {
		"ok": true,
		"id": GAME_ID,
		"grade": "wrong",
		"mainline_advanced": false,
		"church_awareness_delta": 5,
		"suspicion_delta": 3,
	}


func _cycle_count(game_state) -> int:
	var history := _history(game_state)
	var bucket: Dictionary = history.get("cycle", {}) if history.get("cycle", {}) is Dictionary else {}
	return int(bucket.get(_cycle_key(game_state), 0))


func _record_cycle_use(game_state) -> void:
	var history := _history(game_state)
	var bucket: Dictionary = history.get("cycle", {}) if history.get("cycle", {}) is Dictionary else {}
	var key := _cycle_key(game_state)
	bucket[key] = int(bucket.get(key, 0)) + 1
	history["cycle"] = bucket


func _history(game_state) -> Dictionary:
	if not game_state.minigame_history is Dictionary:
		game_state.minigame_history = {}
	if not game_state.minigame_history.has("cycle") or not game_state.minigame_history["cycle"] is Dictionary:
		game_state.minigame_history["cycle"] = {}
	return game_state.minigame_history


func _cycle_key(game_state) -> String:
	return "%d:%s" % [int(game_state.cycle), GAME_ID]


func _record_mainline_node(game_state, node_id: String) -> void:
	if node_id == "":
		return
	var nodes: Array = []
	if game_state.daodian.get("completed_main_story_nodes", []) is Array:
		nodes = game_state.daodian.get("completed_main_story_nodes", [])
	if not nodes.has(node_id):
		nodes.append(node_id)
	game_state.daodian["completed_main_story_nodes"] = nodes


func _add_suspicion(game_state, npc_id: String, amount: int) -> void:
	var state = game_state.npc_relations.get(npc_id, null)
	if state == null or not state is NpcKnowledgeState:
		state = NpcKnowledgeStateScript.new()
		game_state.npc_relations[npc_id] = state
	state.suspicion = clampi(int(state.suspicion) + amount, 0, 100)
