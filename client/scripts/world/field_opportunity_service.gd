class_name FieldOpportunityService
extends RefCounted

const IntelSourceServiceScript = preload("res://scripts/world/intel_source_service.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")

const OPPORTUNITIES_PATH := "res://data/field_loop/opportunities.json"

const INTEL_LABELS := {
	"intel_shadow_alley_church_patrol_001": "\u6559\u4f1a\u5de1\u903b\u60c5\u62a5",
	"intel_xiao_ran_well_node4_001": "\u4e95\u8fb9\u7b2c\u56db\u8282\u70b9\u60c5\u62a5",
	"intel_shadow_story_001": "\u5f71\u5df7\u4e3b\u7ebf\u60c5\u62a5",
	"intel_vera_lighthouse_tide_001": "\u706f\u5854\u6f6e\u6c50\u60c5\u62a5",
	"intel_vera_lighthouse_moonlight_001": "\u6708\u5149\u8349\u60c5\u62a5",
	"intel_carl_smuggler_auction_001": "\u4e0b\u4e00\u573a\u62cd\u5356\u60c5\u62a5",
	"intel_carl_smuggler_port_gate_001": "\u96fe\u6e2f\u5c01\u95e8\u60c5\u62a5",
}

const COMMISSION_LABELS := {
	"commission_old_li_letter_001": "\u8001\u674e\u7684\u9001\u4fe1\u59d4\u6258",
}

const JOB_LABELS := {
	"fishing_shift": "\u9493\u9c7c\u77ed\u5de5",
	"factory_shift": "\u5de5\u5382\u6253\u5de5",
	"dock_shift": "\u7801\u5934\u6253\u5de5",
	"errand_runner": "\u8dd1\u817f\u9001\u4fe1",
}

const ENCOUNTER_LABELS := {
	"enc_shadow_alley_needle_lamp": "\u9488\u706f\u5f02\u52a8",
	"enc_shadow_alley_rag_picker": "\u62fe\u8352\u8005\u8d44\u6e90",
	"enc_shadow_alley_old_li_relay": "\u8001\u674e\u7684\u5df7\u53e3\u8f6c\u8fbe",
	"enc_shadow_alley_church_tail": "\u6559\u4f1a\u5c3e\u968f\u98ce\u9669",
	"enc_misty_port_tide_light": "\u96fe\u6e2f\u6f6e\u5149",
	"enc_misty_port_moonlight_grass": "\u6708\u5149\u8349\u8d44\u6e90",
	"enc_misty_port_carl_manifest": "\u5361\u5c14\u7684\u8231\u5355\u7ebf\u7d22",
	"enc_misty_port_smuggler_check": "\u8d70\u79c1\u68c0\u67e5\u98ce\u9669",
}

var _definitions: Dictionary = {}
var _loaded := false


func refresh_daily(game_state, seed: int = 0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_game_state"}
	var load_result := load_definitions()
	if not bool(load_result.get("ok", false)):
		return load_result
	var daily_key := _daily_key(game_state, seed)
	var npc_source: Dictionary = _dict(_definitions.get("npc_opportunities", {}))
	var district_source: Dictionary = _dict(_definitions.get("district_opportunities", {}))
	var stored := {
		"day": int(game_state.day),
		"seed": int(seed),
		"daily_key": daily_key,
		"npc": npc_source.duplicate(true),
		"districts": _district_entries_for_storage(district_source),
	}
	game_state.daily_field_opportunities = stored
	_sync_existing_npc_today_opportunities(game_state, npc_source)
	return {"ok": true, "daily_key": daily_key, "npc_count": npc_source.size(), "district_count": district_source.size()}


func available_npc_opportunities(npc_id: String, game_state) -> Array:
	if game_state == null or npc_id == "":
		return []
	var stored: Dictionary = _dict(game_state.daily_field_opportunities)
	var npc_store: Dictionary = _dict(stored.get("npc", {}))
	var entries: Array = _array(npc_store.get(npc_id, []))
	return _filter_npc_entries(entries, npc_id, game_state)


func available_district_opportunities(district_id: String, game_state) -> Array:
	if game_state == null or district_id == "":
		return []
	_ensure_daily(game_state)
	var stored: Dictionary = _dict(game_state.daily_field_opportunities)
	var district_map: Dictionary = _dict(stored.get("districts", {}))
	var resolved_ids := _string_array(stored.get("resolved_event_ids", []))
	var result: Array = []
	for entry in _array(district_map.get(district_id, [])):
		if not entry is Dictionary:
			continue
		var candidate: Dictionary = (entry as Dictionary).duplicate(true)
		if _district_entry_is_resolved(candidate, resolved_ids):
			continue
		result.append(candidate)
	return result


func visible_district_opportunities(district_id: String, game_state) -> Array:
	var result: Array = []
	for entry in available_district_opportunities(district_id, game_state):
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		if not bool(data.get("hidden", false)) or bool(data.get("revealed", false)):
			result.append(data.duplicate(true))
	return result


func reveal_hidden_district_opportunity(game_state, district_id: String, source: String = "") -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_game_state", "district_id": district_id}
	_ensure_daily(game_state)
	var stored: Dictionary = _dict(game_state.daily_field_opportunities)
	var district_map: Dictionary = _dict(stored.get("districts", {}))
	var entries: Array = _array(district_map.get(district_id, []))
	var resolved_ids := _string_array(stored.get("resolved_event_ids", []))
	for i in range(entries.size()):
		if not entries[i] is Dictionary:
			continue
		var entry: Dictionary = (entries[i] as Dictionary).duplicate(true)
		if _district_entry_is_resolved(entry, resolved_ids):
			continue
		if not bool(entry.get("hidden", false)) or bool(entry.get("revealed", false)):
			continue
		entry["revealed"] = true
		entry["revealed_by"] = source
		entries[i] = entry
		district_map[district_id] = entries
		stored["districts"] = district_map
		var revealed: Array = _array(stored.get("revealed_event_ids", []))
		var entry_id := str(entry.get("id", ""))
		if entry_id != "" and not revealed.has(entry_id):
			revealed.append(entry_id)
		stored["revealed_event_ids"] = revealed
		game_state.daily_field_opportunities = stored
		return {"ok": true, "district_id": district_id, "opportunity_id": entry_id, "entry": entry}
	return {"ok": false, "reason": "no_hidden_opportunity", "district_id": district_id}


func encounter_for_district_opportunity(game_state, district_id: String, opportunity_id: String):
	for entry in available_district_opportunities(district_id, game_state):
		if not entry is Dictionary:
			continue
		if str((entry as Dictionary).get("id", "")) != opportunity_id:
			continue
		return EncounterPoolScript.new().encounter_by_id(str((entry as Dictionary).get("encounter_id", "")))
	return null


func resolve_district_opportunity(game_state, district_id: String, opportunity_id: String, result: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_game_state", "district_id": district_id, "opportunity_id": opportunity_id}
	if district_id == "" or opportunity_id == "":
		return {"ok": false, "reason": "missing_target", "district_id": district_id, "opportunity_id": opportunity_id}
	_ensure_daily(game_state)
	var stored: Dictionary = _dict(game_state.daily_field_opportunities)
	var district_map: Dictionary = _dict(stored.get("districts", {}))
	var entries: Array = _array(district_map.get(district_id, []))
	var resolved_ids := _string_array(stored.get("resolved_event_ids", []))
	for i in range(entries.size()):
		if not entries[i] is Dictionary:
			continue
		var entry: Dictionary = (entries[i] as Dictionary).duplicate(true)
		if str(entry.get("id", "")) != opportunity_id:
			continue
		if _district_entry_is_resolved(entry, resolved_ids):
			return {"ok": false, "reason": "already_resolved", "district_id": district_id, "opportunity_id": opportunity_id}
		entry["resolved"] = true
		entry["resolved_day"] = int(game_state.day)
		var choice_id := str(result.get("choice_id", ""))
		if choice_id != "":
			entry["resolved_choice_id"] = choice_id
		var outcome: Dictionary = _dict(result.get("outcome", {}))
		if not outcome.is_empty():
			entry["resolved_outcome"] = outcome
		entries[i] = entry
		district_map[district_id] = entries
		stored["districts"] = district_map
		if not resolved_ids.has(opportunity_id):
			resolved_ids.append(opportunity_id)
		stored["resolved_event_ids"] = resolved_ids
		game_state.daily_field_opportunities = stored
		return {"ok": true, "district_id": district_id, "opportunity_id": opportunity_id, "entry": entry}
	return {"ok": false, "reason": "unknown_opportunity", "district_id": district_id, "opportunity_id": opportunity_id}


func resolve_npc_opportunity(game_state, npc_id: String, opportunity_id: String = "") -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_game_state", "npc_id": npc_id}
	var entries := available_npc_opportunities(npc_id, game_state)
	if entries.is_empty():
		var refresh: Dictionary = refresh_daily(game_state, _default_seed(game_state))
		if not bool(refresh.get("ok", false)):
			return refresh
		entries = available_npc_opportunities(npc_id, game_state)
	if opportunity_id == "" and not entries.is_empty():
		opportunity_id = str((entries[0] as Dictionary).get("id", ""))
	for entry in entries:
		if not entry is Dictionary:
			continue
		var source: Dictionary = (entry as Dictionary).duplicate(true)
		if str(source.get("id", "")) != opportunity_id:
			continue
		source["npc_id"] = npc_id
		if str(source.get("source_district", "")) == "":
			source["source_district"] = str(game_state.current_district)
		var result: Dictionary = _resolve_commission_npc_opportunity(game_state, npc_id, source) if _source_is_commission(source) else IntelSourceServiceScript.new().resolve(game_state, npc_id, source)
		result["opportunity_id"] = opportunity_id
		result["display_name"] = player_title_for_opportunity(source)
		if bool(result.get("ok", false)):
			result["display_text"] = player_result_text_for_opportunity(source, result)
		return result
	return {"ok": false, "reason": "unknown_opportunity", "npc_id": npc_id, "opportunity_id": opportunity_id}


func player_title_for_opportunity(entry: Dictionary) -> String:
	var grant: Dictionary = _dict(entry.get("grant", {}))
	var intel_id := str(grant.get("intel_id", ""))
	if intel_id != "":
		return _intel_label(intel_id)
	var commission_id := str(entry.get("commission_id", ""))
	if commission_id != "":
		return str(COMMISSION_LABELS.get(commission_id, "\u59d4\u6258"))
	var job_id := str(entry.get("job_id", ""))
	if job_id != "":
		return str(JOB_LABELS.get(job_id, "\u6253\u5de5"))
	var encounter_id := str(entry.get("encounter_id", ""))
	if encounter_id != "":
		return str(ENCOUNTER_LABELS.get(encounter_id, "\u57ce\u533a\u5f02\u52a8"))
	var display_name := str(entry.get("display_name", entry.get("name", ""))).strip_edges()
	if display_name != "" and _has_cjk(display_name):
		return display_name
	return "\u4eca\u65e5\u673a\u4f1a"


func player_tooltip_for_opportunity(entry: Dictionary) -> String:
	var title := player_title_for_opportunity(entry)
	var parts: Array[String] = []
	var grant: Dictionary = _dict(entry.get("grant", {}))
	var intel_id := str(grant.get("intel_id", ""))
	if intel_id != "":
		parts.append("\u5956\u52b1\uff1a\u83b7\u5f97\u60c5\u62a5\u300c%s\u300d" % title)
	var commission_id := str(entry.get("commission_id", ""))
	if commission_id != "":
		parts.append("\u4e8b\u4ef6\uff1a\u53ef\u63a5\u59d4\u6258\u300c%s\u300d" % title)
	var job_id := str(entry.get("job_id", ""))
	if job_id != "":
		parts.append("\u4e8b\u52a1\uff1a\u6307\u5411\u300c%s\u300d" % title)
	var encounter_id := str(entry.get("encounter_id", ""))
	if encounter_id != "":
		parts.append("\u906d\u9047\uff1a%s" % title)
	var cost_text := _cost_text(_dict(entry.get("cost", {})))
	if cost_text != "":
		parts.append(cost_text)
	if parts.is_empty():
		parts.append("\u8fd9\u4e2a\u673a\u4f1a\u4f1a\u6539\u53d8\u5173\u7cfb\u3001\u98ce\u9669\u6216\u5f53\u65e5\u8d44\u6e90")
	return "\n".join(parts)


func player_result_text_for_opportunity(entry: Dictionary, result: Dictionary = {}) -> String:
	var title := player_title_for_opportunity(entry)
	var grant: Dictionary = _dict(entry.get("grant", {}))
	if str(grant.get("intel_id", "")) != "":
		return "\u83b7\u5f97\u60c5\u62a5\uff1a%s" % title
	if str(entry.get("commission_id", "")) != "":
		return "\u59d4\u6258\u5df2\u8bb0\u5f55\uff1a%s" % title
	if str(entry.get("job_id", "")) != "":
		return "\u4e8b\u52a1\u5df2\u6307\u5411\uff1a%s" % title
	if str(entry.get("encounter_id", "")) != "":
		return "\u5df2\u6807\u8bb0\u57ce\u533a\u906d\u9047\uff1a%s" % title
	var display_text := str(result.get("display_text", entry.get("result_text", ""))).strip_edges()
	if display_text != "" and _has_cjk(display_text):
		return display_text
	return title


func load_definitions(path: String = OPPORTUNITIES_PATH) -> Dictionary:
	if _loaded:
		return {"ok": true, "definitions": _definitions, "count": _definitions.size()}
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing_opportunities", "path": path}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {"ok": false, "reason": "invalid_opportunities_json", "path": path}
	_definitions = (parsed as Dictionary).duplicate(true)
	_loaded = true
	return {"ok": true, "definitions": _definitions, "count": _definitions.size()}


func _sync_existing_npc_today_opportunities(game_state, npc_source: Dictionary) -> void:
	if not game_state.npc_relations is Dictionary:
		return
	for npc_id in npc_source.keys():
		if not game_state.npc_relations.has(npc_id):
			continue
		var state = game_state.npc_relations[npc_id]
		if state == null:
			continue
		state.today_opportunities = _filter_npc_entries(_array(npc_source.get(npc_id, [])), str(npc_id), game_state)


func _filter_npc_entries(entries: Array, npc_id: String, game_state) -> Array:
	var result: Array = []
	var state = _npc_state(game_state, npc_id)
	for entry in entries:
		if not entry is Dictionary:
			continue
		var candidate: Dictionary = (entry as Dictionary).duplicate(true)
		if _npc_entry_is_consumed(candidate, game_state):
			continue
		if not _passes_trust_gate(candidate, state):
			continue
		if not _passes_fatigue_gate(candidate, state, game_state):
			continue
		result.append(candidate)
	return result


func _passes_trust_gate(entry: Dictionary, state) -> bool:
	var gates: Dictionary = _dict(entry.get("gates", {}))
	var trust_min := int(gates.get("trust_min", 0))
	return _trust(state) >= trust_min


func _passes_fatigue_gate(entry: Dictionary, state, game_state) -> bool:
	if state == null:
		return true
	var fatigue_max := int(entry.get("fatigue_max", 999))
	if int(state.last_seen_day) != int(game_state.day):
		return true
	return int(state.interaction_fatigue) <= fatigue_max


func _npc_state(game_state, npc_id: String):
	if game_state == null or not game_state.npc_relations is Dictionary:
		return null
	if game_state.npc_relations.has(npc_id):
		return game_state.npc_relations[npc_id]
	return null


func _trust(state) -> int:
	if state == null:
		return 0
	return int(state.trust)


func _daily_key(game_state, seed: int) -> String:
	return "day:%d|seed:%d|district:%s|time:%s" % [
		int(game_state.day),
		int(seed),
		str(game_state.current_district),
		str(game_state.time_of_day),
	]


func _default_seed(game_state) -> int:
	if game_state == null:
		return 0
	return int(game_state.day) * 10000 + int(game_state.sequence) * 100 + (abs(str(game_state.time_of_day).hash()) % 100)


func _district_entries_for_storage(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for district_id in source.keys():
		var stored_entries: Array = []
		for entry in _array(source.get(district_id, [])):
			if not entry is Dictionary:
				continue
			var candidate: Dictionary = (entry as Dictionary).duplicate(true)
			candidate["district_id"] = str(district_id)
			if not candidate.has("revealed"):
				candidate["revealed"] = not bool(candidate.get("hidden", false))
			stored_entries.append(candidate)
		result[district_id] = stored_entries
	return result


func _ensure_daily(game_state) -> void:
	if game_state == null:
		return
	var stored: Dictionary = _dict(game_state.daily_field_opportunities)
	if stored.is_empty() or int(stored.get("day", -1)) != int(game_state.day):
		refresh_daily(game_state, _default_seed(game_state))


func _source_is_commission(source: Dictionary) -> bool:
	return str(source.get("commission_id", "")) != "" or str(source.get("source_type", "")) == "npc_commission"


func _resolve_commission_npc_opportunity(game_state, npc_id: String, source: Dictionary) -> Dictionary:
	var commission_id := str(source.get("commission_id", ""))
	if commission_id == "":
		return {"ok": false, "reason": "missing_commission_id", "npc_id": npc_id, "source_id": str(source.get("id", ""))}
	var ownership := _validate_npc_commission_ownership(npc_id, commission_id)
	if not bool(ownership.get("ok", false)):
		return ownership
	var cost: Dictionary = _dict(source.get("cost", {}))
	var affordability := _can_spend_source_cost(game_state, npc_id, cost)
	if not bool(affordability.get("ok", false)):
		return affordability
	var accept_result: Dictionary = CommissionServiceScript.new().accept(game_state, commission_id)
	if not bool(accept_result.get("ok", false)):
		accept_result["npc_id"] = npc_id
		accept_result["source_id"] = str(source.get("id", ""))
		return accept_result
	_spend_source_cost(game_state, cost)
	_apply_npc_source_side_effects(game_state, npc_id, source, cost)
	accept_result["npc_id"] = npc_id
	accept_result["source_id"] = str(source.get("id", ""))
	accept_result["source_type"] = str(source.get("source_type", ""))
	accept_result["commission_id"] = commission_id
	return accept_result


func _validate_npc_commission_ownership(npc_id: String, commission_id: String) -> Dictionary:
	if npc_id == "":
		return {"ok": false, "reason": "missing_npc", "commission_id": commission_id}
	var npc_def := NpcLibraryScript.new().get_definition(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id, "commission_id": commission_id}
	var listed := false
	for raw_id in _array(npc_def.get("commission_templates", [])):
		if str(raw_id) == commission_id:
			listed = true
			break
	if not listed:
		return {"ok": false, "reason": "not_from_npc", "npc_id": npc_id, "commission_id": commission_id}
	return {"ok": true, "npc_id": npc_id, "commission_id": commission_id}


func _can_spend_source_cost(game_state, npc_id: String, cost: Dictionary) -> Dictionary:
	var ap_cost := maxi(0, int(cost.get("ap", 0)))
	var stone_cost := maxi(0, int(cost.get("lingstones", 0)))
	var mana_cost := maxi(0, int(cost.get("hub_mana", 0)))
	if ap_cost > 0 and int(game_state.ap) < ap_cost:
		return {"ok": false, "reason": "ap_short", "npc_id": npc_id, "ap_cost": ap_cost, "ap": int(game_state.ap)}
	if stone_cost > 0 and int(game_state.lingstones) < stone_cost:
		return {"ok": false, "reason": "lingstones_short", "npc_id": npc_id, "lingstones_cost": stone_cost, "lingstones": int(game_state.lingstones)}
	if mana_cost > 0 and int(game_state.hub_mana) < mana_cost:
		return {"ok": false, "reason": "hub_mana_short", "npc_id": npc_id, "hub_mana_cost": mana_cost, "hub_mana": int(game_state.hub_mana)}
	return {"ok": true, "ap_cost": ap_cost, "lingstones_cost": stone_cost, "hub_mana_cost": mana_cost}


func _spend_source_cost(game_state, cost: Dictionary) -> void:
	var ap_cost := maxi(0, int(cost.get("ap", 0)))
	var stone_cost := maxi(0, int(cost.get("lingstones", 0)))
	var mana_cost := maxi(0, int(cost.get("hub_mana", 0)))
	if ap_cost > 0:
		if game_state.has_method("spend_ap"):
			game_state.spend_ap(ap_cost)
		else:
			game_state.ap = maxi(0, int(game_state.ap) - ap_cost)
	if stone_cost > 0:
		game_state.lingstones = maxi(0, int(game_state.lingstones) - stone_cost)
	if mana_cost > 0:
		game_state.hub_mana = maxi(0, int(game_state.hub_mana) - mana_cost)


func _apply_npc_source_side_effects(game_state, npc_id: String, source: Dictionary, cost: Dictionary) -> void:
	var state = _ensure_npc_state(game_state, npc_id)
	if state == null:
		return
	var source_type := str(source.get("source_type", ""))
	if ["npc_deep_chat", "job_result", "drill_result", "npc_commission"].has(source_type):
		state.interaction_fatigue = int(state.interaction_fatigue) + 1
		state.last_seen_day = int(game_state.day)
	var favor_debt := int(cost.get("favor_debt", 0))
	if favor_debt > 0:
		state.favor_debt = int(state.favor_debt) + favor_debt


func _ensure_npc_state(game_state, npc_id: String):
	if game_state == null or npc_id == "":
		return null
	if not game_state.npc_relations.has(npc_id):
		game_state.npc_relations[npc_id] = NpcKnowledgeStateScript.new()
	var state = game_state.npc_relations[npc_id]
	if state is Dictionary:
		state = NpcKnowledgeStateScript.from_dict(state)
		game_state.npc_relations[npc_id] = state
	return state


func _npc_entry_is_consumed(entry: Dictionary, game_state) -> bool:
	var commission_id := str(entry.get("commission_id", ""))
	if commission_id == "" or game_state == null:
		return false
	if commission_id in game_state.accepted_commissions or commission_id in game_state.completed_commissions:
		return true
	var available: Variant = game_state.get("available_commissions")
	if available is Array:
		for item in available:
			if not item is Dictionary:
				continue
			if str((item as Dictionary).get("id", "")) != commission_id:
				continue
			return ["accepted", "in_progress", "completed", "claimed", "expired"].has(str((item as Dictionary).get("status", "")))
	return false


func _district_entry_is_resolved(entry: Dictionary, resolved_ids: Array[String]) -> bool:
	var entry_id := str(entry.get("id", ""))
	if entry_id != "" and resolved_ids.has(entry_id):
		return true
	return bool(entry.get("resolved", false))


func _intel_label(intel_id: String) -> String:
	return str(INTEL_LABELS.get(intel_id, "\u60c5\u62a5"))


func _cost_text(cost: Dictionary) -> String:
	var pieces: Array[String] = []
	if int(cost.get("ap", 0)) > 0:
		pieces.append("%d AP" % int(cost.get("ap", 0)))
	if int(cost.get("lingstones", 0)) > 0:
		pieces.append("%d \u7075\u77f3" % int(cost.get("lingstones", 0)))
	if int(cost.get("hub_mana", 0)) > 0:
		pieces.append("%d \u6d1e\u5e9c\u80fd\u91cf" % int(cost.get("hub_mana", 0)))
	if int(cost.get("favor_debt", 0)) > 0:
		pieces.append("\u4eba\u60c5\u503a +%d" % int(cost.get("favor_debt", 0)))
	if pieces.is_empty():
		return ""
	return "\u82b1\u8d39\uff1a%s" % " / ".join(pieces)


func _has_cjk(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x3400 and code <= 0x9fff:
			return true
	return false


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item)
			if text != "":
				result.append(text)
	return result
