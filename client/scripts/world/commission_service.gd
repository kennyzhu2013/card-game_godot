class_name CommissionService
extends RefCounted

const CommissionScript = preload("res://scripts/world/commission.gd")
const CommissionLibraryScript = preload("res://scripts/world/commission_library.gd")
const CommissionModifierServiceScript = preload("res://scripts/world/commission_modifier_service.gd")
const CompletionMatcherScript = preload("res://scripts/world/completion_matcher.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")
const CardScript = preload("res://scripts/combat/card.gd")

const MAINLINE_REJECT_REASON := "cannot_reject_main_story"

var _library = null


func get_library():
	return _get_library()


func refresh_daily(game_state, seed: int = 0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var library = _get_library()
	var loaded: Dictionary = library.load_all()
	if not bool(loaded.get("ok", false)):
		return loaded
	expire_overdue(game_state)
	var slot_count = _slot_count(game_state)
	var preserved = _accepted_visible_commissions(game_state)
	var chosen_by_id = {}
	var chosen: Array = []
	for commission in preserved:
		if commission != null and commission.has_method("to_dict"):
			chosen.append(commission.to_dict())
			chosen_by_id[str(commission.id)] = true
	var due_main = library.main_story_templates_for_day(int(game_state.day), int(game_state.sequence))
	due_main.sort_custom(_commission_before)
	for commission in due_main:
		if commission == null:
			continue
		if chosen_by_id.has(str(commission.id)) or _is_completed(game_state, str(commission.id)):
			continue
		chosen.append(_available_dict(commission, "available"))
		chosen_by_id[str(commission.id)] = true
	var candidates = library.due_templates(int(game_state.day), int(game_state.sequence))
	candidates.sort_custom(_commission_before)
	for commission in candidates:
		if chosen.size() >= slot_count:
			break
		if str(commission.main_story_hook) != "":
			continue
		if chosen_by_id.has(str(commission.id)) or _is_completed(game_state, str(commission.id)):
			continue
		chosen.append(_available_dict(_decorate_commission(commission, game_state, seed), "available"))
		chosen_by_id[str(commission.id)] = true
	game_state.available_commissions = chosen
	return {"ok": true, "slot_count": slot_count, "available_ids": _ids_from_available(game_state), "seed": seed}


func accept(game_state, commission_id: String) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if commission_id == "":
		return {"ok": false, "reason": "missing_id"}
	if _is_completed(game_state, commission_id):
		return {"ok": false, "reason": "already_completed", "commission_id": commission_id}
	var commission = _commission_for_state(game_state, commission_id)
	if commission.is_empty():
		return {"ok": false, "reason": "unknown_commission", "commission_id": commission_id}
	commission.status = "accepted"
	commission.accepted_day = int(game_state.day)
	if not commission_id in game_state.accepted_commissions:
		game_state.accepted_commissions.append(commission_id)
	_upsert_available(game_state, commission)
	return {"ok": true, "reason": "ok", "commission_id": commission_id, "accepted_day": commission.accepted_day}


func reject(game_state, commission_id: String) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var commission = _commission_for_state(game_state, commission_id)
	if commission.is_empty():
		return {"ok": false, "reason": "unknown_commission", "commission_id": commission_id}
	if commission.main_story_hook != "":
		return {"ok": false, "reason": MAINLINE_REJECT_REASON, "commission_id": commission_id}
	_remove_available(game_state, commission_id)
	return {"ok": true, "reason": "ok", "commission_id": commission_id}


func execute(game_state, commission_id: String, options: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if not commission_id in game_state.accepted_commissions:
		return {"ok": false, "reason": "not_accepted", "commission_id": commission_id}
	var commission = _commission_for_state(game_state, commission_id)
	if commission.is_empty():
		return {"ok": false, "reason": "unknown_commission", "commission_id": commission_id}
	var dispatch_kind = _dispatch_kind_for(commission)
	var dispatch = {
		"commission_id": commission.id,
		"commission_type": commission.commission_type,
		"dispatch_kind": dispatch_kind,
		"dispatch_target": commission.dispatch_target.duplicate(true),
		"district": commission.district,
	}
	if game_state.has_method("set_meta"):
		game_state.set_meta("commission_active_dispatch", dispatch.duplicate(true))
	commission.status = "in_progress"
	_upsert_available(game_state, commission)
	var result = {
		"ok": true,
		"reason": "ok",
		"commission_id": commission_id,
		"dispatch_kind": dispatch_kind,
		"dispatch_target": commission.dispatch_target.duplicate(true),
	}
	if options.has("count_added") and commission.commission_type == "gather":
		var event = {
			"event": "loot_resolved",
			"district": commission.district,
			"time": str(commission.dispatch_target.get("time", "")),
			"item_id": str(commission.dispatch_target.get("item_id", "")),
			"count_added": int(options.get("count_added", 0)),
		}
		result["completion_event"] = record_completion_event(game_state, event)
	return result


func record_completion_event(game_state, event: Dictionary) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "completed_ids": []}
	var completed_ids: Array[String] = []
	var progress_ids: Array[String] = []
	for commission_id in game_state.accepted_commissions.duplicate():
		var commission = _commission_for_state(game_state, str(commission_id))
		if commission.is_empty():
			continue
		var matched = CompletionMatcherScript.matches(commission, event)
		_upsert_available(game_state, commission)
		if matched:
			commission.status = "completed"
			_upsert_available(game_state, commission)
			completed_ids.append(commission.id)
		elif commission.commission_type == "gather":
			progress_ids.append(commission.id)
	return {"ok": true, "completed_ids": completed_ids, "progress_ids": progress_ids}


func claim(game_state, commission_id: String) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if commission_id in game_state.completed_commissions:
		return {"ok": false, "reason": "already_completed", "commission_id": commission_id}
	var commission = _commission_for_state(game_state, commission_id)
	if commission.is_empty():
		return {"ok": false, "reason": "unknown_commission", "commission_id": commission_id}
	if commission.status != "completed":
		return {"ok": false, "reason": "not_completed", "commission_id": commission_id, "status": commission.status}
	var reward_result = _apply_rewards(game_state, commission)
	game_state.accepted_commissions.erase(commission_id)
	if not commission_id in game_state.completed_commissions:
		game_state.completed_commissions.append(commission_id)
	commission.status = "claimed"
	if game_state.has_method("remove_meta") and game_state.has_meta("commission_active_dispatch"):
		game_state.remove_meta("commission_active_dispatch")
	_upsert_available(game_state, commission)
	return {"ok": true, "reason": "ok", "commission_id": commission_id, "rewards": reward_result}


func expire_overdue(game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "expired_ids": []}
	var expired_ids: Array[String] = []
	for commission_id in game_state.accepted_commissions.duplicate():
		var commission = _commission_for_state(game_state, str(commission_id))
		if commission.is_empty() or commission.status == "completed" or commission.status == "claimed":
			continue
		if commission.accepted_day < 0:
			continue
		if commission.accepted_day + commission.time_limit_days < int(game_state.day):
			commission.status = "expired"
			game_state.accepted_commissions.erase(commission.id)
			_adjust_trust(game_state, commission.issuer_npc, CommissionModifierServiceScript.new().expire_trust_delta(commission))
			_upsert_available(game_state, commission)
			expired_ids.append(commission.id)
	return {"ok": true, "expired_ids": expired_ids}


func status_for(game_state, commission_id: String) -> String:
	var commission = _commission_for_state(game_state, commission_id)
	return "" if commission.is_empty() else commission.status


func _get_library():
	if _library == null:
		_library = CommissionLibraryScript.new()
	return _library


func _slot_count(game_state) -> int:
	return 3 if int(game_state.day) <= 3 else 5


func _accepted_visible_commissions(game_state) -> Array:
	var result: Array = []
	for commission_id in game_state.accepted_commissions:
		var commission = _commission_for_state(game_state, str(commission_id))
		if commission.is_empty():
			continue
		if commission.status == "claimed" or commission.status == "expired":
			continue
		result.append(commission)
	return result


func _commission_for_state(game_state, commission_id: String):
	for item in _available_array(game_state):
		if item is Dictionary and str((item as Dictionary).get("id", "")) == commission_id:
			return CommissionScript.from_dict(item)
	var template = _get_library().get_template(commission_id)
	if template != null and template.has_method("copy"):
		return template.copy()
	return CommissionScript.new()


func _available_dict(commission, status_value: String) -> Dictionary:
	var data = commission.to_dict()
	data["status"] = status_value
	return data


func _decorate_commission(commission, game_state, seed: int):
	var data: Dictionary = CommissionModifierServiceScript.new().decorate_available(game_state, commission, seed)
	if data.is_empty():
		return commission
	return CommissionScript.from_dict(data)


func _upsert_available(game_state, commission) -> void:
	var data = commission.to_dict()
	var available: Array = _available_array(game_state)
	for i in range(available.size()):
		if available[i] is Dictionary and str((available[i] as Dictionary).get("id", "")) == commission.id:
			available[i] = data
			game_state.available_commissions = available
			return
	available.append(data)
	game_state.available_commissions = available


func _remove_available(game_state, commission_id: String) -> void:
	var next: Array = []
	for item in _available_array(game_state):
		if item is Dictionary and str((item as Dictionary).get("id", "")) == commission_id:
			continue
		next.append(item)
	game_state.available_commissions = next


func _available_array(game_state) -> Array:
	var value: Variant = game_state.get("available_commissions")
	return value.duplicate(true) if value is Array else []


func _is_completed(game_state, commission_id: String) -> bool:
	return commission_id in game_state.completed_commissions


func _dispatch_kind_for(commission) -> String:
	match commission.commission_type:
		"battle":
			return "tower"
		"gather":
			return str(commission.dispatch_target.get("kind", "encounter"))
		"investigate":
			return "tower_event"
		"perform":
			return str(commission.dispatch_target.get("kind", "drill"))
		_:
			return "unknown"


func _apply_rewards(game_state, commission) -> Dictionary:
	var applied: Array = []
	var modifier = _reward_modifier(game_state, commission.issuer_npc) * CommissionModifierServiceScript.new().reward_multiplier(commission)
	for reward in commission.rewards:
		if not reward is Dictionary:
			continue
		var entry: Dictionary = (reward as Dictionary).duplicate(true)
		var reward_type = str(entry.get("type", ""))
		var base_amount = int(entry.get("amount", 1))
		var amount = _modified_amount(base_amount, modifier, reward_type)
		match reward_type:
			"lingstones":
				game_state.lingstones += amount
				entry["applied_amount"] = amount
			"dao_pages":
				game_state.dao_pages += amount
				entry["applied_amount"] = amount
			"material":
				var material_id = str(entry.get("id", ""))
				if material_id != "":
					game_state.forge_materials[material_id] = int(game_state.forge_materials.get(material_id, 0)) + amount
					entry["applied_amount"] = amount
			"brand":
				for i in range(maxi(1, amount)):
					game_state.brands_inventory.append(_brand_from_reward(entry))
			"rule_unlock":
				var rule_id = str(entry.get("id", commission.contract_rule_hook))
				if rule_id != "" and not rule_id in game_state.learned_rules:
					game_state.learned_rules.append(rule_id)
			"temp_card":
				var card = _card_from_reward(entry)
				if game_state.has_method("add_temp_card"):
					game_state.add_temp_card(card)
				else:
					game_state.temp_picked_cards.append(card)
			"mainline_node":
				_record_mainline_node(game_state, str(entry.get("id", commission.main_story_hook)))
			"halfmoon_trust":
				game_state.halfmoon_trust = clampi(int(game_state.halfmoon_trust) + amount, 0, 100)
			"church_awareness":
				if game_state.has_method("adjust_church_awareness"):
					game_state.adjust_church_awareness(amount, "commission:%s" % str(commission.id))
				else:
					game_state.church_awareness = clampi(int(game_state.church_awareness) + amount, 0, 100)
			_:
				continue
		applied.append(entry)
	if commission.contract_rule_hook != "" and not commission.contract_rule_hook in game_state.learned_rules:
		game_state.learned_rules.append(commission.contract_rule_hook)
	if commission.main_story_hook != "":
		_record_mainline_node(game_state, commission.main_story_hook)
	return {"applied": applied, "modifier": modifier}


func _reward_modifier(game_state, issuer_npc: String) -> float:
	var trust = _trust_for(game_state, issuer_npc)
	if trust >= 60:
		return 1.2
	if trust <= -20:
		return 0.9
	return 1.0


func _modified_amount(amount: int, modifier: float, reward_type: String) -> int:
	if not ["lingstones", "dao_pages", "material"].has(reward_type):
		return amount
	return maxi(0, int(round(float(amount) * modifier)))


func _trust_for(game_state, npc_id: String) -> int:
	if game_state == null or npc_id == "":
		return 0
	var relation: Variant = game_state.npc_relations.get(npc_id, null)
	if relation is Dictionary:
		return int((relation as Dictionary).get("trust", 0))
	if relation != null:
		var value: Variant = relation.get("trust")
		return int(value if value != null else 0)
	return 0


func _adjust_trust(game_state, npc_id: String, delta: int) -> void:
	if npc_id == "":
		return
	var relation: Variant = game_state.npc_relations.get(npc_id, null)
	if relation == null or not relation is NpcKnowledgeState:
		relation = NpcKnowledgeStateScript.new()
		game_state.npc_relations[npc_id] = relation
	relation.trust = clampi(int(relation.trust) + delta, -100, 100)


func _brand_from_reward(reward: Dictionary):
	var brand_id = str(reward.get("id", "commission_brand_low"))
	return BrandScript.from_dict({
		"id": brand_id,
		"display_name": str(reward.get("display_name", brand_id)),
		"pathway_affinity": str(reward.get("pathway_affinity", "any")),
		"sequence_min": int(reward.get("sequence_min", 9)),
		"effect_type": "commission_reward",
		"effect_payload": {},
		"description": "R17 commission reward",
	})


func _card_from_reward(reward: Dictionary):
	var card_id = str(reward.get("id", "commission_temp_card"))
	return CardScript.from_json({
		"id": card_id,
		"template_id": card_id,
		"display_name": str(reward.get("display_name", card_id)),
		"pathway": str(reward.get("pathway", "fool")),
		"sequence": int(reward.get("sequence", 9)),
		"quality": int(reward.get("quality", 1)),
		"rarity": str(reward.get("rarity", "common")),
		"energy_cost": 1,
		"combat_effect": {"damage": int(reward.get("damage", 1)), "target": "single"},
	})


func _record_mainline_node(game_state, node_id: String) -> void:
	if node_id == "":
		return
	var daodian: Dictionary = game_state.daodian if game_state.daodian is Dictionary else {}
	var nodes: Array = daodian.get("completed_main_story_nodes", []) if daodian.get("completed_main_story_nodes", []) is Array else []
	if not node_id in nodes:
		nodes.append(node_id)
	daodian["completed_main_story_nodes"] = nodes
	game_state.daodian = daodian


func _ids_from_available(game_state) -> Array[String]:
	var result: Array[String] = []
	for item in _available_array(game_state):
		if item is Dictionary:
			result.append(str((item as Dictionary).get("id", "")))
	return result


static func _commission_before(a, b) -> bool:
	var a_priority = int(a.get("refresh_priority"))
	var b_priority = int(b.get("refresh_priority"))
	if a_priority != b_priority:
		return a_priority < b_priority
	return str(a.get("id")) < str(b.get("id"))
