class_name MinigameService
extends RefCounted

const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const DiceMinigameScript = preload("res://scripts/minigames/casino/dice_minigame.gd")
const TarotMinigameScript = preload("res://scripts/minigames/casino/tarot_minigame.gd")
const FateMinigameScript = preload("res://scripts/minigames/casino/fate_minigame.gd")
const AuctionServiceScript = preload("res://scripts/minigames/auction/auction_service.gd")
const JobServiceScript = preload("res://scripts/world/job_service.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")

const DEFINITION_PATHS := {
	"dice_cup": "res://data/minigames/casino/dice.json",
	"tarot_divination": "res://data/minigames/casino/tarot_divination.json",
	"fate_cards": "res://data/minigames/casino/fate_cards.json",
	"misty_port_weekly": "res://data/minigames/auctions/auction_pool_early.json",
	"factory_shift": "res://data/minigames/jobs/factory_shift.json",
	"dock_shift": "res://data/minigames/jobs/dock_shift.json",
	"errand_runner": "res://data/minigames/jobs/errand_runner.json",
	"worship_observation": "res://data/minigames/jobs/worship_observation.json",
	"mountain_solitary_walk": "res://data/minigames/jobs/mountain_solitary_walk.json",
	"street_debate": "res://data/minigames/drills/street_debate.json",
	"underground_signal": "res://data/minigames/drills/underground_signal.json",
	"smuggle_role": "res://data/minigames/drills/smuggle_role.json",
	"confess_innocent": "res://data/minigames/drills/confess_innocent.json",
	"mirror_step": "res://data/minigames/drills/mirror_step.json",
	"foreman_dialogue": "res://data/minigames/drills/foreman_dialogue.json",
	"tavern_brag": "res://data/minigames/drills/tavern_brag.json",
	"noble_salon": "res://data/minigames/drills/noble_salon.json",
}


func load_definition(minigame_id: String) -> Dictionary:
	var path := str(DEFINITION_PATHS.get(minigame_id, ""))
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed.duplicate(true)
	return {}


func available_casino_games(game_state, npc_id: String, game_ids: Array = []) -> Array:
	var ids := game_ids.duplicate()
	if ids.is_empty():
		ids = ["dice_cup", "tarot_divination", "fate_cards"]
	var result: Array = []
	for game_id in ids:
		var id := str(game_id)
		var definition := load_definition(id)
		if definition.is_empty():
			continue
		var check := can_start(game_state, id)
		var params: Dictionary = definition.get("mechanic_params", {}) if definition.get("mechanic_params", {}) is Dictionary else {}
		result.append({
			"id": id,
			"display_name": str(definition.get("display_name", id)),
			"npc_id": npc_id,
			"ap_cost": int(definition.get("ap_cost", 0)),
			"bet_min": int(params.get("bet_min", 0)),
			"bet_max": int(params.get("bet_max", 0)),
			"available": bool(check.get("ok", false)),
			"reason": str(check.get("reason", "")),
		})
	return result


func can_start(game_state, minigame_id: String, _options: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var definition := load_definition(minigame_id)
	if definition.is_empty():
		return {"ok": false, "reason": "missing_definition", "id": minigame_id}
	var mechanic := str(definition.get("mechanic", ""))
	if ["phigros_simple", "dock_work", "errand_route", "worship_rhythm", "mountain_dodge"].has(mechanic):
		return JobServiceScript.new().can_start(game_state, minigame_id, _options)
	if mechanic == "dialogue_drill":
		return DrillRunnerScript.new().can_start(game_state, minigame_id, _options)
	var ap_cost := _int_value(definition.get("ap_cost", 0))
	if ap_cost > 0 and int(game_state.ap) < ap_cost:
		return {"ok": false, "reason": "ap_short", "cost": ap_cost, "remaining": int(game_state.ap)}
	var daily_limit := _int_value(definition.get("daily_limit", 0))
	if daily_limit > 0 and _count_for_limit(game_state, "daily", minigame_id) >= daily_limit:
		return {"ok": false, "reason": "daily_limit", "limit": daily_limit}
	var weekly_limit := _int_value(definition.get("weekly_limit", 0))
	if weekly_limit > 0 and _count_for_limit(game_state, "weekly", minigame_id) >= weekly_limit:
		return {"ok": false, "reason": "weekly_limit", "limit": weekly_limit}
	var cycle_limit := _int_value(definition.get("cycle_limit", 0))
	if cycle_limit > 0 and _count_for_limit(game_state, "cycle", minigame_id) >= cycle_limit:
		return {"ok": false, "reason": "cycle_limit", "limit": cycle_limit}
	return {"ok": true, "definition": definition}


func start_game(game_state, minigame_id: String, options: Dictionary = {}) -> Dictionary:
	var check := can_start(game_state, minigame_id, options)
	if not bool(check.get("ok", false)):
		return check
	var definition: Dictionary = check.get("definition", {})
	var mechanic := str(definition.get("mechanic", ""))
	var result: Dictionary = {}
	match mechanic:
		"dice":
			result = DiceMinigameScript.new().play(game_state, options)
		"tarot":
			result = TarotMinigameScript.new().play(game_state, options)
		"fate":
			result = FateMinigameScript.new().play(game_state, options)
		"auction":
			result = AuctionServiceScript.new().start_auction(game_state, minigame_id, options)
		"phigros_simple", "dock_work", "errand_route", "worship_rhythm", "mountain_dodge":
			result = JobServiceScript.new().start_job(game_state, minigame_id, options)
		"dialogue_drill":
			result = DrillRunnerScript.new().resolve_drill(game_state, minigame_id, options)
		_:
			result = {"ok": false, "reason": "unknown_mechanic", "mechanic": mechanic}
	if bool(result.get("ok", false)) and ["dice", "tarot"].has(mechanic):
		_record_use(game_state, minigame_id)
	return result


func apply_rewards(game_state, rewards: Array) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var applied: Array = []
	for reward in rewards:
		if not reward is Dictionary:
			continue
		var entry: Dictionary = reward
		var reward_type := str(entry.get("type", ""))
		var amount := int(entry.get("amount", 1))
		match reward_type:
			"lingstones":
				game_state.lingstones += amount
			"material":
				var material_id := str(entry.get("id", ""))
				if material_id != "":
					game_state.forge_materials[material_id] = int(game_state.forge_materials.get(material_id, 0)) + amount
			"dao_pages":
				game_state.dao_pages += amount
			"church_awareness":
				if game_state.has_method("adjust_church_awareness"):
					game_state.adjust_church_awareness(amount, "minigame:%s" % str(entry.get("id", "minigame_reward")))
				else:
					game_state.church_awareness = clampi(int(game_state.church_awareness) + amount, 0, 100)
			"suspicion_delta":
				_add_suspicion(game_state, str(entry.get("npc_id", "")), amount)
			"brand":
				for _i in range(maxi(1, amount)):
					game_state.brands_inventory.append(_brand_from_id(str(entry.get("id", ""))))
			"temp_card":
				for _i in range(maxi(1, amount)):
					var temp_card = _card_from_reward(entry)
					if game_state.has_method("add_temp_card"):
						game_state.add_temp_card(temp_card)
					else:
						game_state.temp_picked_cards.append(temp_card)
			"card":
				for _i in range(maxi(1, amount)):
					var reward_card = _card_from_reward(entry)
					if game_state.has_method("add_card"):
						game_state.add_card(reward_card)
					else:
						game_state.cards_inventory.append(reward_card)
			"mainline_node":
				_record_mainline_node(game_state, str(entry.get("id", "")))
			_:
				continue
		applied.append(entry.duplicate(true))
	return {"ok": true, "applied": applied}


func _record_use(game_state, minigame_id: String) -> void:
	var history := _history(game_state)
	_increment(history, "daily", _daily_key(game_state, minigame_id))
	_increment(history, "weekly", _weekly_key(game_state, minigame_id))
	_increment(history, "cycle", _cycle_key(game_state, minigame_id))


func _count_for_limit(game_state, bucket: String, minigame_id: String) -> int:
	var history := _history(game_state)
	var key := ""
	match bucket:
		"daily":
			key = _daily_key(game_state, minigame_id)
		"weekly":
			key = _weekly_key(game_state, minigame_id)
		"cycle":
			key = _cycle_key(game_state, minigame_id)
		_:
			return 0
	var bucket_data: Dictionary = history.get(bucket, {}) if history.get(bucket, {}) is Dictionary else {}
	return int(bucket_data.get(key, 0))


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


func _daily_key(game_state, minigame_id: String) -> String:
	return "%d:%d:%s" % [int(game_state.cycle), int(game_state.day), minigame_id]


func _weekly_key(game_state, minigame_id: String) -> String:
	var week_index := int(floor(float(maxi(1, int(game_state.day)) - 1) / 7.0))
	return "%d:%d:%s" % [int(game_state.cycle), week_index, minigame_id]


func _cycle_key(game_state, minigame_id: String) -> String:
	return "%d:%s" % [int(game_state.cycle), minigame_id]


func _add_suspicion(game_state, npc_id: String, amount: int) -> void:
	if npc_id == "":
		return
	var state = game_state.npc_relations.get(npc_id, null)
	if state == null or not state is NpcKnowledgeState:
		state = NpcKnowledgeStateScript.new()
		game_state.npc_relations[npc_id] = state
	state.suspicion = clampi(int(state.suspicion) + amount, 0, 100)


func _record_mainline_node(game_state, node_id: String) -> void:
	if node_id == "":
		return
	var nodes: Array = []
	if game_state.daodian.get("completed_main_story_nodes", []) is Array:
		nodes = game_state.daodian.get("completed_main_story_nodes", [])
	if not nodes.has(node_id):
		nodes.append(node_id)
	game_state.daodian["completed_main_story_nodes"] = nodes


func _brand_from_id(brand_id: String):
	return BrandScript.from_dict({
		"id": brand_id,
		"display_name": brand_id,
		"pathway_affinity": "any",
		"sequence_min": 9,
		"effect_type": "minigame_reward",
		"effect_payload": {},
		"description": "R25 mini-game reward",
	})


func _card_from_reward(reward: Dictionary):
	var card_id := str(reward.get("id", "temp_minigame_card"))
	return CardScript.from_json({
		"id": card_id,
		"template_id": card_id,
		"display_name": str(reward.get("display_name", card_id)),
		"quality": int(reward.get("quality", 1)),
		"pathway": str(reward.get("pathway", "fool")),
		"sequence": int(reward.get("sequence", 9)),
		"rarity": str(reward.get("rarity", "common")),
		"energy_cost": 1,
		"combat_effect": {"damage": int(reward.get("damage", 0)), "target": "single"},
	})


func _int_value(value: Variant) -> int:
	if value == null:
		return 0
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		return int(value)
	return 0
