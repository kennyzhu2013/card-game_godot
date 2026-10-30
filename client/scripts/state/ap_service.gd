class_name ApService
extends RefCounted

const FORGE_COST_BY_CAPACITY := {3: 2, 4: 3, 6: 3}
const TOWER_COST_BY_SIZE := {"small": 2, "medium": 4, "large": 6}
const REMOTE_DISTRICT_COSTS := {"stone_tower": 2, "ascetic_mountain": 2}
const WORK_COST_BY_TYPE := {"factory": 3, "dock": 2, "mountain": 3, "errand": 1, "worship_observe": 1}
const DRILL_COST_BY_TYPE := {"short": 1, "noble_salon": 2, "smuggling_roleplay": 2}
const CITY_ROAM_COST := 0
const NPC_DEEP_DIALOGUE_COST := 1
const NPC_SHORT_CHAT_MAX_ROUNDS := 2
const LISTEN_RUMOR_COST := 1
const CASINO_ROUND_COST := 1
const AUCTION_COST := 1
const MEDITATION_COST := 3
const SLEEP_COST := 3
const COMMISSION_EXECUTION_COST := 1


static func city_roam_cost() -> int:
	return CITY_ROAM_COST


static func forge_cost_for_capacity(capacity: int) -> int:
	return int(FORGE_COST_BY_CAPACITY.get(capacity, 0))


static func tower_cost_for_size(size: String) -> int:
	return int(TOWER_COST_BY_SIZE.get(size, 2))


static func district_travel_cost(district_id: String) -> int:
	return int(REMOTE_DISTRICT_COSTS.get(district_id, 0))


static func npc_dialogue_cost(round_count: int, relation_threshold_changed: bool = false) -> int:
	if relation_threshold_changed or int(round_count) > NPC_SHORT_CHAT_MAX_ROUNDS:
		return NPC_DEEP_DIALOGUE_COST
	return 0


static func listen_rumor_cost() -> int:
	return LISTEN_RUMOR_COST


static func casino_round_cost() -> int:
	return CASINO_ROUND_COST


static func auction_cost() -> int:
	return AUCTION_COST


static func work_cost(work_type: String) -> int:
	return int(WORK_COST_BY_TYPE.get(work_type, 0))


static func drill_cost(drill_type: String) -> int:
	return int(DRILL_COST_BY_TYPE.get(drill_type, 1))


static func passive_encounter_cost(step_count: int) -> int:
	return clampi(int(step_count) - 1, 0, 2)


static func commission_execution_cost(includes_tower: bool, tower_size: String) -> int:
	var cost := COMMISSION_EXECUTION_COST
	if includes_tower:
		cost += tower_cost_for_size(tower_size)
	return cost


static func can_afford(game_state, cost: int) -> bool:
	if game_state == null:
		return false
	return cost <= 0 or int(game_state.ap) >= cost


static func try_spend(game_state, cost: int, reason: String = "") -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "cost": cost}
	if cost <= 0:
		return {"ok": true, "reason": reason, "cost": 0, "remaining": int(game_state.ap)}
	if int(game_state.ap) < cost:
		return {
			"ok": false,
			"reason": "ap_short",
			"cost": cost,
			"missing": cost - int(game_state.ap),
			"remaining": int(game_state.ap),
		}
	if game_state.has_method("spend_ap"):
		game_state.spend_ap(cost)
	else:
		game_state.ap = max(0, int(game_state.ap) - cost)
	return {"ok": true, "reason": reason, "cost": cost, "remaining": int(game_state.ap)}


static func try_spend_forge(game_state, capacity: int) -> Dictionary:
	return try_spend(game_state, forge_cost_for_capacity(capacity), "forge")


static func try_spend_meditation(game_state) -> Dictionary:
	return try_spend(game_state, MEDITATION_COST, "meditation")


static func try_spend_tower(game_state, size: String) -> Dictionary:
	return try_spend(game_state, tower_cost_for_size(size), "tower")


static func try_spend_district_travel(game_state, district_id: String) -> Dictionary:
	return try_spend(game_state, district_travel_cost(district_id), "district_travel")


static func try_spend_npc_dialogue(game_state, round_count: int, relation_threshold_changed: bool = false) -> Dictionary:
	return try_spend(game_state, npc_dialogue_cost(round_count, relation_threshold_changed), "npc_deep_dialogue")


static func try_spend_passive_encounter(game_state, step_count: int) -> Dictionary:
	return try_spend(game_state, passive_encounter_cost(step_count), "passive_encounter")


static func try_spend_commission_execution(game_state, includes_tower: bool, tower_size: String) -> Dictionary:
	return try_spend(game_state, commission_execution_cost(includes_tower, tower_size), "commission_execution")


static func spend_sleep_cost_or_deficit(game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "cost": SLEEP_COST, "paid": 0, "deficit": SLEEP_COST}
	var before_ap := int(game_state.ap)
	var paid := mini(before_ap, SLEEP_COST)
	if paid > 0:
		try_spend(game_state, paid, "sleep")
	var deficit := maxi(0, SLEEP_COST - paid)
	if game_state.has_method("record_sleep_deficit"):
		game_state.record_sleep_deficit(deficit)
	else:
		game_state.last_sleep_ap_deficit = deficit
	return {"ok": true, "reason": "sleep", "cost": SLEEP_COST, "paid": paid, "deficit": deficit}
