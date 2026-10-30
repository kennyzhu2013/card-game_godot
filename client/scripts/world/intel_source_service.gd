class_name IntelSourceService
extends RefCounted

const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const RumorPoolLoaderScript = preload("res://scripts/world/rumor_pool_loader.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")


func resolve(game_state, npc_id: String, source: Dictionary) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if source.is_empty():
		return {"ok": false, "reason": "missing_source", "npc_id": npc_id}
	var state = _ensure_npc_state(game_state, npc_id)
	var gates: Dictionary = _dict(source.get("gates", {}))
	var required_trust := int(gates.get("trust_min", 0))
	if int(state.trust) < required_trust:
		_apply_fail_risk(state, source)
		return {
			"ok": false,
			"reason": "trust_too_low",
			"npc_id": npc_id,
			"source_id": str(source.get("id", "")),
			"required_trust": required_trust,
			"trust": int(state.trust),
		}
	var cost: Dictionary = _dict(source.get("cost", {}))
	var ap_cost := maxi(0, int(cost.get("ap", 0)))
	var stone_cost := maxi(0, int(cost.get("lingstones", 0)))
	var mana_cost := maxi(0, int(cost.get("hub_mana", 0)))
	if ap_cost > 0 and int(game_state.ap) < ap_cost:
		return {"ok": false, "reason": "ap_short", "npc_id": npc_id, "ap_cost": ap_cost, "ap": int(game_state.ap)}
	if stone_cost > 0 and int(game_state.lingstones) < stone_cost:
		return {
			"ok": false,
			"reason": "lingstones_short",
			"npc_id": npc_id,
			"lingstones_cost": stone_cost,
			"lingstones": int(game_state.lingstones),
		}
	if mana_cost > 0 and int(game_state.hub_mana) < mana_cost:
		return {
			"ok": false,
			"reason": "hub_mana_short",
			"npc_id": npc_id,
			"hub_mana_cost": mana_cost,
			"hub_mana": int(game_state.hub_mana),
		}
	_spend_costs(game_state, ap_cost, stone_cost, mana_cost)
	_apply_interaction_side_effects(game_state, state, source, cost)
	var grant_result := _grant_intel(game_state, npc_id, source)
	if not bool(grant_result.get("ok", false)):
		return {
			"ok": false,
			"reason": str(grant_result.get("reason", "grant_failed")),
			"npc_id": npc_id,
			"source_id": str(source.get("id", "")),
			"grant": grant_result,
		}
	var intel: Dictionary = _dict(grant_result.get("intel", {}))
	return {
		"ok": true,
		"reason": "ok",
		"npc_id": npc_id,
		"source_id": str(source.get("id", "")),
		"source_type": str(source.get("source_type", "")),
		"ap_cost": ap_cost,
		"lingstones_cost": stone_cost,
		"hub_mana_cost": mana_cost,
		"remaining_ap": int(game_state.ap),
		"remaining_lingstones": int(game_state.lingstones),
		"remaining_hub_mana": int(game_state.hub_mana),
		"intel": intel.duplicate(true),
		"display_text": IntelServiceScript.player_display_text(intel),
	}


func _spend_costs(game_state, ap_cost: int, stone_cost: int, mana_cost: int) -> void:
	if ap_cost > 0:
		if game_state.has_method("spend_ap"):
			game_state.spend_ap(ap_cost)
		else:
			game_state.ap = maxi(0, int(game_state.ap) - ap_cost)
	if stone_cost > 0:
		game_state.lingstones = maxi(0, int(game_state.lingstones) - stone_cost)
	if mana_cost > 0:
		game_state.hub_mana = maxi(0, int(game_state.hub_mana) - mana_cost)


func _apply_interaction_side_effects(game_state, state, source: Dictionary, cost: Dictionary) -> void:
	var source_type := str(source.get("source_type", ""))
	if ["npc_deep_chat", "job_result", "drill_result"].has(source_type):
		state.interaction_fatigue = int(state.interaction_fatigue) + 1
		state.last_seen_day = int(game_state.day)
	var favor_debt := int(cost.get("favor_debt", 0))
	if favor_debt > 0:
		state.favor_debt = int(state.favor_debt) + favor_debt


func _grant_intel(game_state, npc_id: String, source: Dictionary) -> Dictionary:
	var grant: Dictionary = _dict(source.get("grant", {}))
	var intel_id := str(grant.get("intel_id", ""))
	if intel_id == "":
		return {"ok": false, "reason": "missing_intel_id"}
	var intel := RumorPoolLoaderScript.new().intel_by_id(intel_id)
	if intel.is_empty():
		intel = _fallback_intel(npc_id, source, intel_id)
	var overrides := {"source_type": str(source.get("source_type", ""))}
	if npc_id != "":
		overrides["source_npc"] = npc_id
	return IntelServiceScript.new().grant(game_state, intel, overrides)


func _fallback_intel(npc_id: String, source: Dictionary, intel_id: String) -> Dictionary:
	var display_text := str(source.get("result_text", ""))
	if display_text == "":
		display_text = str(source.get("display_name", intel_id))
	return {
		"id": intel_id,
		"category": str(source.get("source_type", "field")),
		"display_text": display_text,
		"source_type": str(source.get("source_type", "field")),
		"source_npc": npc_id,
		"source_district": str(source.get("source_district", "")),
		"expires_after": "today",
		"apply_target": {
			"kind": "npc_chat.note",
			"payload": {
				"npc_id": npc_id,
				"source_id": str(source.get("id", "")),
			},
		},
		"truth_value": 100,
	}


func _ensure_npc_state(game_state, npc_id: String):
	if npc_id == "":
		return NpcKnowledgeStateScript.new()
	if not game_state.npc_relations.has(npc_id):
		game_state.npc_relations[npc_id] = NpcKnowledgeStateScript.new()
	var state = game_state.npc_relations[npc_id]
	if state is Dictionary:
		state = NpcKnowledgeStateScript.from_dict(state)
		game_state.npc_relations[npc_id] = state
	return state


func _apply_fail_risk(state, source: Dictionary) -> void:
	var risk: Dictionary = _dict(source.get("risk", {}))
	var suspicion_delta := int(risk.get("suspicion_delta_on_fail", 0))
	if suspicion_delta == 0:
		return
	state.suspicion = clampi(int(state.suspicion) + suspicion_delta, 0, 100)


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
