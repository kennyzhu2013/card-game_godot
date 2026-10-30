class_name R20FieldHookService
extends RefCounted

const FieldOpportunityServiceScript = preload("res://scripts/world/field_opportunity_service.gd")
const IntelSourceServiceScript = preload("res://scripts/world/intel_source_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const READ_TRUTH_INTEL_BY_NPC := {
	"old_li": "intel_shadow_alley_church_patrol_001",
	"xiao_ran": "intel_xiao_ran_well_node4_001",
	"vera_lighthouse": "intel_vera_lighthouse_moonlight_001",
	"carl_smuggler": "intel_carl_smuggler_port_gate_001",
}


func apply(game_state, target_npc_id: String, card, dispatch_result: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	if game_state == null or card == null:
		return {"ok": false, "reason": "missing_state_or_card"}
	var social: Dictionary = _dict(card.get("social_effect"))
	var world: Dictionary = _dict(card.get("world_effect"))
	var hook_type := _hook_type(social, world)
	match hook_type:
		"read_truth":
			return _read_truth(game_state, target_npc_id)
		"identity_mask":
			return _identity_mask(game_state, target_npc_id, social)
		"premonition":
			return _premonition(game_state, ctx)
		"spawn_event":
			return _spawn_event(game_state, world, ctx)
		"influence_behavior":
			return _influence_behavior(game_state, target_npc_id)
		_:
			return {"ok": true, "reason": "no_field_hook", "hook_type": hook_type}


func _read_truth(game_state, npc_id: String) -> Dictionary:
	var intel_id := str(READ_TRUTH_INTEL_BY_NPC.get(npc_id, ""))
	if intel_id == "":
		var missing := {"ok": false, "reason": "no_gated_intel", "hook_type": "read_truth", "npc_id": npc_id}
		_log(game_state, "read_truth", npc_id, missing)
		return missing
	var source := {
		"id": "r20_read_truth_%s" % npc_id,
		"source_type": "r20_field_effect",
		"cost": {},
		"gates": {"trust_min": 0},
		"grant": {"intel_id": intel_id},
		"result_text": "R20 field hook revealed gated intel.",
	}
	var result: Dictionary = IntelSourceServiceScript.new().resolve(game_state, npc_id, source)
	result["hook_type"] = "read_truth"
	_log(game_state, "read_truth", npc_id, result)
	return result


func _identity_mask(game_state, npc_id: String, effect: Dictionary) -> Dictionary:
	var state = _ensure_npc_state(game_state, npc_id)
	var delta := int(effect.get("field_suspicion_delta", -10 if not effect.has("suspicion_delta") else 0))
	state.suspicion = clampi(int(state.suspicion) + delta, 0, 100)
	var result := {
		"ok": true,
		"hook_type": "identity_mask",
		"npc_id": npc_id,
		"suspicion_delta": delta,
		"suspicion": int(state.suspicion),
	}
	_log(game_state, "identity_mask", npc_id, result)
	return result


func _premonition(game_state, ctx: Dictionary) -> Dictionary:
	var district_id := _district_id(game_state, ctx)
	var result: Dictionary = FieldOpportunityServiceScript.new().reveal_hidden_district_opportunity(game_state, district_id, "premonition")
	result["hook_type"] = "premonition"
	_log(game_state, "premonition", district_id, result)
	return result


func _spawn_event(game_state, effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var district_id := _district_id(game_state, ctx)
	var event_id := _spawn_event_id(effect)
	var source := "spawn_event:%s" % event_id
	var service = FieldOpportunityServiceScript.new()
	var result: Dictionary = service.reveal_hidden_district_opportunity(game_state, district_id, source)
	result["hook_type"] = "spawn_event"
	result["event"] = event_id
	if bool(result.get("ok", false)):
		var entry: Dictionary = _dict(result.get("entry", {}))
		var display_text := str(service.player_title_for_opportunity(entry)).strip_edges()
		if display_text == "":
			display_text = str(entry.get("display_name", entry.get("id", ""))).strip_edges()
		result["display_text"] = display_text
		result["result_text"] = str(service.player_result_text_for_opportunity(entry, result)).strip_edges()
	_log(game_state, "spawn_event", district_id, result)
	return result


func _influence_behavior(game_state, npc_id: String) -> Dictionary:
	var stored: Dictionary = _dict(game_state.daily_field_opportunities)
	var rerolled: Array = _array(stored.get("rerolled_keys", []))
	if not rerolled.has(npc_id):
		rerolled.append(npc_id)
	stored["rerolled_keys"] = rerolled
	game_state.daily_field_opportunities = stored
	var result := {"ok": true, "hook_type": "influence_behavior", "npc_id": npc_id, "rerolled_keys": rerolled.duplicate()}
	_log(game_state, "influence_behavior", npc_id, result)
	return result


func _hook_type(social: Dictionary, world: Dictionary) -> String:
	var social_type := str(social.get("type", ""))
	if ["read_truth", "identity_mask", "premonition", "influence_behavior"].has(social_type):
		return social_type
	var world_type := str(world.get("type", ""))
	if ["premonition", "spawn_event"].has(world_type):
		return world_type
	return ""


func _district_id(game_state, ctx: Dictionary) -> String:
	var district_id := str(ctx.get("district_id", game_state.current_district if game_state != null else "")).strip_edges()
	if district_id == "":
		district_id = "shadow_alley"
	return district_id


func _spawn_event_id(effect: Dictionary) -> String:
	var event_id := str(effect.get("event", "")).strip_edges()
	if event_id == "":
		var params: Dictionary = _dict(effect.get("parameters", {}))
		event_id = str(params.get("event", "")).strip_edges()
	if event_id == "":
		event_id = "r20_spawn_event"
	return event_id


func _log(game_state, hook_type: String, target_id: String, result: Dictionary) -> void:
	var log: Array = _array(game_state.field_hook_log)
	log.append({
		"day": int(game_state.day),
		"hook_type": hook_type,
		"target_id": target_id,
		"ok": bool(result.get("ok", false)),
	})
	game_state.field_hook_log = log


func _ensure_npc_state(game_state, npc_id: String):
	if not game_state.npc_relations.has(npc_id):
		game_state.npc_relations[npc_id] = NpcKnowledgeStateScript.new()
	var state = game_state.npc_relations[npc_id]
	if state is Dictionary:
		state = NpcKnowledgeStateScript.from_dict(state)
		game_state.npc_relations[npc_id] = state
	return state


func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []
