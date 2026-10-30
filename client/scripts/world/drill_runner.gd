class_name DrillRunner
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const TimeAdvanceServiceScript = preload("res://scripts/world/time_advance_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")
const EncounterChainStateScript = preload("res://scripts/world/encounter_chain_state.gd")

const DRILL_DEFINITION_PATHS := {
	"street_debate": "res://data/minigames/drills/street_debate.json",
	"underground_signal": "res://data/minigames/drills/underground_signal.json",
	"smuggle_role": "res://data/minigames/drills/smuggle_role.json",
	"confess_innocent": "res://data/minigames/drills/confess_innocent.json",
	"confession_room": "res://data/minigames/drills/confession_room.json",
	"mirror_step": "res://data/minigames/drills/mirror_step.json",
	"foreman_dialogue": "res://data/minigames/drills/foreman_dialogue.json",
	"tavern_brag": "res://data/minigames/drills/tavern_brag.json",
	"noble_salon": "res://data/minigames/drills/noble_salon.json",
}

const DRILL_INTEL_REWARDS := {
	"tavern_brag": ["intel_tavern_brag_001", "intel_tavern_brag_002"],
	"smuggle_role": ["intel_smuggle_mainline_001"],
}

const DRILL_CHAIN_PROGRESSIONS := {
	"mirror_step": {"chain_id": "reflection_chain", "required_step": 2, "unlock_chain_step": 3},
	"noble_salon": {"chain_id": "reflection_chain", "required_step": 3, "unlock_chain_step": 4},
}

var _ai_gm_service = null


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func load_drill_definition(drill_id: String) -> Dictionary:
	var path := str(DRILL_DEFINITION_PATHS.get(drill_id, ""))
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed.duplicate(true)
	return {}


func can_start(game_state, drill_id: String, _options: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var definition := load_drill_definition(drill_id)
	if definition.is_empty():
		return {"ok": false, "reason": "missing_definition", "id": drill_id}
	var ap_cost := int(definition.get("ap_cost", 1))
	if int(game_state.ap) < ap_cost:
		return {"ok": false, "reason": "ap_short", "cost": ap_cost, "remaining": int(game_state.ap)}
	return {"ok": true, "definition": definition, "ap_cost": ap_cost}


func resolve_drill(game_state, drill_id: String, options: Dictionary = {}) -> Dictionary:
	var check := can_start(game_state, drill_id, options)
	if not bool(check.get("ok", false)):
		return check
	var definition: Dictionary = check.get("definition", {})
	var ap_cost := int(check.get("ap_cost", 1))
	var spend: Dictionary = ApServiceScript.try_spend(game_state, ap_cost, "drill:%s" % drill_id)
	if not bool(spend.get("ok", false)):
		return spend
	var rules: Array = definition.get("rules", []) if definition.get("rules", []) is Array else []
	var satisfied_rule_ids := _string_array(options.get("satisfied_rule_ids", []))
	var satisfied_count := _count_satisfied_rules(rules, satisfied_rule_ids)
	var ratio := 0.0
	if rules.size() > 0:
		ratio = float(satisfied_count) / float(rules.size())
	var outcome := _outcome_for_ratio(ratio)
	var reward_key := "punishment_fail"
	if outcome == "perfect":
		reward_key = "rewards_perfect"
	elif outcome == "partial":
		reward_key = "rewards_partial"
	var rewards: Array = definition.get(reward_key, []) if definition.get(reward_key, []) is Array else []
	var reward_result := _apply_rewards(game_state, rewards, definition)
	if outcome != "fail" and drill_id == "smuggle_role":
		_merge_granted_intels(reward_result, _grant_activity_intels(game_state, drill_id, 1))
	var exp_result := {"acting_exp_card_ids": [], "upgraded_card_ids": []}
	if outcome == "perfect" or outcome == "partial":
		_apply_success_trust(game_state, definition)
		exp_result = _grant_acting_exp(game_state, outcome, satisfied_rule_ids, options)
	_record_use(game_state, drill_id)
	var time_result: Dictionary = TimeAdvanceServiceScript.advance_for_action(game_state, "drill")
	var result := {
		"ok": true,
		"id": drill_id,
		"drill_id": drill_id,
		"outcome": outcome,
		"satisfaction_ratio": ratio,
		"satisfied_count": satisfied_count,
		"rule_count": rules.size(),
		"reward_scale": 1.0 if outcome == "perfect" else (0.5 if outcome == "partial" else 0.0),
		"ap_cost": ap_cost,
		"ap_remaining": int(game_state.ap),
		"rewards": rewards,
		"applied_rewards": reward_result.get("applied_rewards", []),
		"granted_intel_ids": reward_result.get("granted_intel_ids", []),
		"granted_intel_texts": reward_result.get("granted_intel_texts", []),
		"acting_exp_card_ids": exp_result.get("acting_exp_card_ids", []),
		"upgraded_card_ids": exp_result.get("upgraded_card_ids", []),
		"time_result": time_result,
	}
	var chain_result := _apply_drill_chain_progression(game_state, drill_id, outcome)
	for key in chain_result.keys():
		result[key] = chain_result[key]
	if outcome == "fail":
		result["ai_gm_text"] = request_acting_drill_collapse_ai_gm(game_state, drill_id, result)
	return result


func available_drills(game_state, drill_ids: Array = []) -> Array:
	var ids := drill_ids.duplicate()
	if ids.is_empty():
		ids = DRILL_DEFINITION_PATHS.keys()
	var result: Array = []
	for raw_id in ids:
		var drill_id := str(raw_id)
		var definition := load_drill_definition(drill_id)
		if definition.is_empty():
			continue
		var check := can_start(game_state, drill_id)
		result.append({
			"id": drill_id,
			"display_name": str(definition.get("display_name", drill_id)),
			"city": str(definition.get("city", "")),
			"ap_cost": int(definition.get("ap_cost", 1)),
			"witness_npc_id": str(definition.get("witness_npc_id", "")),
			"available": bool(check.get("ok", false)),
			"reason": str(check.get("reason", "")),
		})
	return result


func request_acting_drill_collapse_ai_gm(game_state, drill_id: String, result: Dictionary = {}) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "acting_drill_collapse"
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"drill_id": drill_id,
		"outcome": str(result.get("outcome", "fail")),
		"satisfaction_ratio": float(result.get("satisfaction_ratio", 0.0)),
		"satisfied_count": int(result.get("satisfied_count", 0)),
		"rule_count": int(result.get("rule_count", 0)),
	}
	ctx.fallback_template_pool = "ACTING_DRILL_COLLAPSE_TEMPLATES"
	return _call_ai_gm(ctx)


func _count_satisfied_rules(rules: Array, satisfied_rule_ids: Array[String]) -> int:
	var count := 0
	for rule in rules:
		if not rule is Dictionary:
			continue
		if str((rule as Dictionary).get("id", "")) in satisfied_rule_ids:
			count += 1
	return count


func _outcome_for_ratio(ratio: float) -> String:
	if is_equal_approx(ratio, 1.0) or ratio >= 0.999:
		return "perfect"
	if ratio >= 0.6:
		return "partial"
	return "fail"


func _grant_acting_exp(game_state, outcome: String, satisfied_rule_ids: Array[String], options: Dictionary) -> Dictionary:
	var target_ids: Array[String] = []
	var thought_ids := _referenced_card_ids(options)
	if outcome == "perfect":
		target_ids = thought_ids
	else:
		var rule_map: Dictionary = _rule_card_map_with_references(options, satisfied_rule_ids, thought_ids)
		for rule_id in satisfied_rule_ids:
			var card_id := str(rule_map.get(rule_id, ""))
			if card_id != "" and not card_id in target_ids:
				target_ids.append(card_id)
		if target_ids.is_empty():
			target_ids = thought_ids
	var applied: Array[String] = []
	var upgraded: Array[String] = []
	for card_id in target_ids:
		var card = _card_by_id(game_state, card_id)
		if card == null:
			continue
		var did_upgrade := bool(card.grant_acting_exp(1))
		applied.append(card_id)
		if did_upgrade:
			upgraded.append(card_id)
	return {"acting_exp_card_ids": applied, "upgraded_card_ids": upgraded}


func _referenced_card_ids(options: Dictionary) -> Array[String]:
	var result := _string_array(options.get("thought_card_ids", []))
	_merge_referenced_cards(result, options.get("card_referenced", null))
	_merge_referenced_cards(result, options.get("card_references", null))
	return result


func _rule_card_map_with_references(options: Dictionary, satisfied_rule_ids: Array[String], thought_ids: Array[String]) -> Dictionary:
	var result: Dictionary = options.get("rule_card_map", {}) if options.get("rule_card_map", {}) is Dictionary else {}
	var referenced: Variant = options.get("card_referenced", null)
	if referenced is Dictionary:
		for key in (referenced as Dictionary).keys():
			var card_id := str((referenced as Dictionary).get(key, ""))
			if card_id != "":
				result[str(key)] = card_id
	if result.is_empty() and not thought_ids.is_empty():
		for rule_id in satisfied_rule_ids:
			result[str(rule_id)] = str(thought_ids[0])
	return result


func _merge_referenced_cards(target: Array[String], value: Variant) -> void:
	if value == null:
		return
	if value is String or value is StringName:
		var text := str(value)
		if text != "" and not text in target:
			target.append(text)
		return
	if value is Array:
		for item in value:
			_merge_referenced_cards(target, item)
		return
	if value is Dictionary:
		for item in (value as Dictionary).values():
			_merge_referenced_cards(target, item)


func _card_by_id(game_state, card_id: String):
	if game_state == null or card_id == "":
		return null
	for collection_name in ["cards_inventory", "temp_picked_cards"]:
		var collection: Variant = game_state.get(collection_name)
		if not collection is Array:
			continue
		for card in collection:
			if card != null and str(card.get("id")) == card_id:
				return card
	return null


func _apply_success_trust(game_state, definition: Dictionary) -> void:
	var witness_id := str(definition.get("witness_npc_id", ""))
	var amount := int(definition.get("success_trust_delta", 5))
	if witness_id == "" or amount == 0:
		return
	_add_trust(game_state, witness_id, amount)


func _apply_rewards(game_state, rewards: Array, definition: Dictionary) -> Dictionary:
	var applied: Array = []
	var applied_summary := {}
	for reward in rewards:
		if not reward is Dictionary:
			continue
		var entry: Dictionary = reward
		var amount := int(entry.get("amount", 1))
		match str(entry.get("type", "")):
			"rule_unlock":
				var rule_id := str(entry.get("id", ""))
				if rule_id != "" and not rule_id in game_state.learned_rules:
					game_state.learned_rules.append(rule_id)
			"shop_discount":
				ShopServiceScript.apply_discount(game_state, str(entry.get("shop_id", "")), int(entry.get("pct", 0)))
			"npc_trust_delta":
				_add_trust(game_state, str(entry.get("npc_id", definition.get("witness_npc_id", ""))), amount)
			"church_awareness":
				if game_state.has_method("adjust_church_awareness"):
					game_state.adjust_church_awareness(amount, "drill:%s" % str(definition.get("id", "")))
				else:
					game_state.church_awareness = clampi(int(game_state.church_awareness) + amount, 0, 100)
			"pollution":
				game_state.pollution = clampi(int(game_state.pollution) + amount, 0, 100)
			"dao_pages":
				game_state.dao_pages += amount
			"temp_card":
				_add_temp_card(game_state, entry)
			"job_bonus":
				_apply_job_bonus(game_state, entry)
			"auction_ticket":
				_activity_modifiers(game_state)["auction_ticket"] = str(entry.get("id", "auction_entry"))
			"district_block":
				var district_id := str(entry.get("district_id", ""))
				if district_id != "":
					_activity_modifiers(game_state)["%s_blocked_until_day" % district_id] = int(game_state.day) + int(entry.get("days", 7))
			"intel_stub":
				_merge_granted_intels(applied_summary, _queue_intel_reward(game_state, str(definition.get("id", "")), maxi(1, amount)))
			_:
				continue
		applied.append(entry.duplicate(true))
	applied_summary["applied_rewards"] = applied
	return applied_summary


func _add_trust(game_state, npc_id: String, amount: int) -> void:
	if npc_id == "":
		return
	var state = game_state.npc_relations.get(npc_id, null)
	if state == null or not state is NpcKnowledgeState:
		state = NpcKnowledgeStateScript.new()
		game_state.npc_relations[npc_id] = state
	state.trust = clampi(int(state.trust) + amount, -100, 100)


func _add_temp_card(game_state, reward: Dictionary) -> void:
	var card_id := str(reward.get("id", "drill_temp_card"))
	var card = CardScript.from_json({
		"id": card_id,
		"template_id": card_id,
		"display_name": str(reward.get("display_name", card_id)),
		"pathway": "fool",
		"sequence": int(reward.get("sequence", 9)),
		"rarity": str(reward.get("rarity", "common")),
		"quality": int(reward.get("quality", 1)),
		"energy_cost": 1,
		"combat_effect": {"damage": int(reward.get("damage", 3)), "target": "single"},
	})
	if game_state.has_method("add_temp_card"):
		game_state.add_temp_card(card)
	else:
		game_state.temp_picked_cards.append(card)


func _apply_job_bonus(game_state, reward: Dictionary) -> void:
	var job_id := str(reward.get("job_id", ""))
	if job_id == "":
		return
	_activity_modifiers(game_state)["job_bonus:%s" % job_id] = {
		"pct": int(reward.get("pct", 0)),
		"expires_day": int(game_state.day) + int(reward.get("days", 7)),
	}


func _queue_intel_reward(game_state, source_id: String, amount: int) -> Dictionary:
	var daodian: Dictionary = game_state.daodian if game_state.daodian is Dictionary else {}
	var pending: Array = daodian.get("pending_intel_rewards", []) if daodian.get("pending_intel_rewards", []) is Array else []
	for i in range(maxi(1, amount)):
		pending.append({"source": source_id, "type": "city_intel_stub"})
	daodian["pending_intel_rewards"] = pending
	game_state.daodian = daodian
	return _grant_activity_intels(game_state, source_id, amount)


func _grant_activity_intels(game_state, source_id: String, amount: int) -> Dictionary:
	var ids_result: Array[String] = []
	var text_result: Array[String] = []
	var ids: Array = DRILL_INTEL_REWARDS.get(source_id, []) if DRILL_INTEL_REWARDS.get(source_id, []) is Array else []
	if ids.is_empty():
		return {"granted_intel_ids": ids_result, "granted_intel_texts": text_result}
	var service = IntelServiceScript.new()
	var limit := mini(maxi(1, amount), ids.size())
	for i in range(limit):
		var intel_id := str(ids[i])
		var grant_result: Dictionary = service.grant(game_state, intel_id, {"source_type": source_id})
		if bool(grant_result.get("ok", false)):
			ids_result.append(intel_id)
			var intel: Dictionary = grant_result.get("intel", {}) if grant_result.get("intel", {}) is Dictionary else {}
			var text := IntelServiceScript.player_display_text(intel)
			if text != "":
				text_result.append(text)
	return {"granted_intel_ids": ids_result, "granted_intel_texts": text_result}


func _merge_granted_intels(target: Dictionary, source: Dictionary) -> void:
	var target_ids: Array = target.get("granted_intel_ids", []) if target.get("granted_intel_ids", []) is Array else []
	var target_texts: Array = target.get("granted_intel_texts", []) if target.get("granted_intel_texts", []) is Array else []
	for id in source.get("granted_intel_ids", []):
		target_ids.append(str(id))
	for text in source.get("granted_intel_texts", []):
		target_texts.append(str(text))
	if not target_ids.is_empty():
		target["granted_intel_ids"] = target_ids
	if not target_texts.is_empty():
		target["granted_intel_texts"] = target_texts


func _activity_modifiers(game_state) -> Dictionary:
	if not game_state.activity_modifiers is Dictionary:
		game_state.activity_modifiers = {}
	return game_state.activity_modifiers


func _record_use(game_state, drill_id: String) -> void:
	var history := _history(game_state)
	_increment(history, "daily", _daily_key(game_state, drill_id))
	_increment(history, "weekly", _weekly_key(game_state, drill_id))
	_increment(history, "cycle", _cycle_key(game_state, drill_id))


func _apply_drill_chain_progression(game_state, drill_id: String, outcome: String) -> Dictionary:
	if game_state == null or outcome == "fail":
		return {}
	var rule: Variant = DRILL_CHAIN_PROGRESSIONS.get(drill_id, null)
	if not rule is Dictionary:
		return {}
	var chain_id := str((rule as Dictionary).get("chain_id", ""))
	var required_step := int((rule as Dictionary).get("required_step", 0))
	var unlock_step := int((rule as Dictionary).get("unlock_chain_step", required_step + 1))
	if chain_id == "":
		return {}
	var chains: Variant = game_state.get("encounter_chains")
	if not chains is Dictionary:
		chains = {}
		game_state.set("encounter_chains", chains)
	var state = (chains as Dictionary).get(chain_id, null)
	if state == null:
		if required_step > 0:
			return {}
		state = EncounterChainStateScript.new()
		state.chain_id = chain_id
		(chains as Dictionary)[chain_id] = state
	if bool(state.get("locked")):
		return {}
	var current_step := int(state.get("current_step"))
	if current_step != required_step:
		return {}
	if state is Object and state.has_method("record_step"):
		state.record_step(required_step, "drill:%s" % drill_id, outcome, int(game_state.day))
	var next_step: int = maxi(int(state.get("current_step")), unlock_step)
	if state is Dictionary:
		state["current_step"] = next_step
	else:
		state.current_step = next_step
	return {
		"chain_id": chain_id,
		"chain_step": int(state.get("current_step")),
		"chain_advanced": true,
	}


func _history(game_state) -> Dictionary:
	if not game_state.minigame_history is Dictionary:
		game_state.minigame_history = {}
	for bucket in ["daily", "weekly", "cycle"]:
		if not game_state.minigame_history.has(bucket) or not game_state.minigame_history[bucket] is Dictionary:
			game_state.minigame_history[bucket] = {}
	return game_state.minigame_history


func _increment(history: Dictionary, bucket: String, key: String) -> void:
	var bucket_data: Dictionary = history.get(bucket, {}) if history.get(bucket, {}) is Dictionary else {}
	bucket_data[key] = int(bucket_data.get(key, 0)) + 1
	history[bucket] = bucket_data


func _daily_key(game_state, drill_id: String) -> String:
	return "%d:%d:%s" % [int(game_state.cycle), int(game_state.day), drill_id]


func _weekly_key(game_state, drill_id: String) -> String:
	var week_index := int(floor(float(maxi(1, int(game_state.day)) - 1) / 7.0))
	return "%d:%d:%s" % [int(game_state.cycle), week_index, drill_id]


func _cycle_key(game_state, drill_id: String) -> String:
	return "%d:%s" % [int(game_state.cycle), drill_id]


func _call_ai_gm(ctx) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var service = _resolve_ai_gm_service()
	if service == null or not service.has_method("call_ai_gm"):
		return ""
	return str(service.call_ai_gm(ctx))


func _resolve_ai_gm_service():
	if _ai_gm_service != null:
		return _ai_gm_service
	_ai_gm_service = AIGMServiceScript.new()
	return _ai_gm_service


func _ai_gm_player_state(game_state) -> Dictionary:
	return {
		"sequence": _state_int(game_state, "sequence", 9),
		"pollution": _state_int(game_state, "pollution", 0),
		"pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"cycle": _state_int(game_state, "cycle", 1),
		"day": _state_int(game_state, "day", 1),
		"time_of_day": _state_string(game_state, "time_of_day", "morning"),
	}


func _state_int(game_state, field_name: String, fallback: int) -> int:
	if game_state == null:
		return fallback
	var value = game_state.get(field_name)
	return fallback if value == null else int(value)


func _state_string(game_state, field_name: String, fallback: String) -> String:
	if game_state == null:
		return fallback
	var value = game_state.get(field_name)
	return fallback if value == null else str(value)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
