class_name PseudoGodContractService
extends RefCounted

const CardLibraryScript = preload("res://scripts/combat/card_library.gd")
const CardScript = preload("res://scripts/combat/card.gd")

const CONTRACT_ID := "pseudo_god_contract"
const REQUIRED_SEQUENCE := 8
const TRUST_STRICT_DELTA := 50
const TRUST_VIOLATION_DELTA := -20
const DEFAULT_RULE_IDS: Array[String] = [
	"永远多一个面具",
	"旁观者守则",
	"不承诺真相",
	"第一句永远是问",
	"不直呼神名",
]
const REWARD_CARD_IDS: Array[String] = [
	"fool_s7_wound_displacement",
	"fool_s7_flame_jump",
	"fool_s7_air_bullet",
]
const HALFMOON_THRESHOLDS := [
	{"id": "acquainted", "trust": 30},
	{"id": "friend", "trust": 60},
	{"id": "trusted", "trust": 80},
	{"id": "kin", "trust": 95},
]


func ensure_unlocked_for_state(game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "unlocked": false, "reason": "missing_state"}
	if int(game_state.sequence) > REQUIRED_SEQUENCE:
		return {"ok": true, "unlocked": false, "reason": "sequence_locked", "required_sequence": REQUIRED_SEQUENCE}
	var contract := _contract(game_state)
	var rule_ids := _five_rule_ids(game_state)
	if not bool(contract.get("unlocked", false)):
		contract = {
			"contract_id": CONTRACT_ID,
			"unlocked": true,
			"rule_ids": rule_ids.duplicate(),
			"strictly_observed": false,
			"violated": false,
			"reward_claimed": false,
			"breach_day": 0,
			"unlocked_card_ids": [],
		}
	else:
		contract["contract_id"] = CONTRACT_ID
		contract["unlocked"] = true
		if _array(contract.get("rule_ids", [])).size() != 5:
			contract["rule_ids"] = rule_ids.duplicate()
	_set_contract(game_state, contract)
	_apply_active_contract(game_state, _array(contract.get("rule_ids", [])))
	return {
		"ok": true,
		"unlocked": true,
		"contract_id": CONTRACT_ID,
		"rule_ids": _array(contract.get("rule_ids", [])),
		"contract": contract.duplicate(true),
	}


func settle_rule_outcomes(game_state, rule_outcomes: Dictionary) -> Dictionary:
	var unlock_result := ensure_unlocked_for_state(game_state)
	if not bool(unlock_result.get("unlocked", false)):
		return unlock_result
	var contract := _contract(game_state)
	var rule_ids: Array = _array(contract.get("rule_ids", []))
	var satisfied: Array[String] = []
	var violated: Array[String] = []
	for rule_id_value in rule_ids:
		var rule_id := str(rule_id_value)
		var outcome := str(rule_outcomes.get(rule_id, "violated"))
		if outcome == "satisfied":
			satisfied.append(rule_id)
		else:
			violated.append(rule_id)
	var previous_trust := int(game_state.halfmoon_trust)
	var crossed_thresholds: Array[String] = []
	var unlocked_card_ids: Array[String] = []
	if violated.is_empty() and satisfied.size() == rule_ids.size():
		if not bool(contract.get("reward_claimed", false)):
			game_state.halfmoon_trust = clampi(previous_trust + TRUST_STRICT_DELTA, 0, 100)
			crossed_thresholds = _crossed_thresholds(previous_trust, int(game_state.halfmoon_trust))
			unlocked_card_ids = _grant_reward_cards(game_state)
			contract["reward_claimed"] = true
			contract["strictly_observed"] = true
			contract["unlocked_card_ids"] = unlocked_card_ids.duplicate()
		else:
			unlocked_card_ids = _string_array(contract.get("unlocked_card_ids", []))
		_set_contract(game_state, contract)
		return {
			"ok": true,
			"contract_id": CONTRACT_ID,
			"outcome": "strict",
			"previous_halfmoon_trust": previous_trust,
			"halfmoon_trust": int(game_state.halfmoon_trust),
			"crossed_thresholds": crossed_thresholds,
			"unlocked_card_ids": unlocked_card_ids,
			"satisfied": satisfied.size(),
			"violated": 0,
		}
	if not bool(contract.get("violated", false)):
		game_state.halfmoon_trust = clampi(previous_trust + TRUST_VIOLATION_DELTA, 0, 100)
		contract["violated"] = true
		contract["breach_day"] = int(game_state.day)
	_set_contract(game_state, contract)
	return {
		"ok": true,
		"contract_id": CONTRACT_ID,
		"outcome": "violated",
		"previous_halfmoon_trust": previous_trust,
		"halfmoon_trust": int(game_state.halfmoon_trust),
		"violated_rule_ids": violated,
		"satisfied": satisfied.size(),
		"violated": violated.size(),
	}


static func is_unlocked(game_state) -> bool:
	if game_state == null:
		return false
	var contract := _contract_static(game_state)
	return bool(contract.get("unlocked", false)) or int(game_state.sequence) <= REQUIRED_SEQUENCE


static func is_violated(game_state) -> bool:
	if game_state == null:
		return false
	return bool(_contract_static(game_state).get("violated", false))


func _five_rule_ids(game_state) -> Array[String]:
	var result: Array[String] = []
	var source: Array = []
	if game_state != null:
		var learned = game_state.get("learned_rules")
		if learned is Array:
			source = learned
	for rule in source:
		var id := str(rule)
		if id != "" and not result.has(id):
			result.append(id)
		if result.size() >= 5:
			return result
	for rule in DEFAULT_RULE_IDS:
		if not result.has(rule):
			result.append(rule)
		if result.size() >= 5:
			return result
	return result


func _apply_active_contract(game_state, rule_ids: Array) -> void:
	if game_state == null:
		return
	game_state.active_contract.clear()
	for rule in rule_ids:
		game_state.active_contract.append(str(rule))


func _grant_reward_cards(game_state) -> Array[String]:
	var result: Array[String] = []
	if game_state == null:
		return result
	var library = CardLibraryScript.new()
	library.load_all()
	for card_id in REWARD_CARD_IDS:
		if game_state.get_card(card_id) != null:
			result.append(card_id)
			continue
		var template = library.get_card(card_id)
		if template == null:
			continue
		var card = CardScript.from_json(template.to_dict())
		card.id = card_id
		card.template_id = str(template.template_id)
		if game_state.add_card(card):
			result.append(card_id)
	return result


func _crossed_thresholds(previous_trust: int, new_trust: int) -> Array[String]:
	var result: Array[String] = []
	for threshold in HALFMOON_THRESHOLDS:
		var required := int(threshold.get("trust", 0))
		if previous_trust < required and new_trust >= required:
			result.append(str(threshold.get("id", "")))
	return result


func _contract(game_state) -> Dictionary:
	return _contract_static(game_state)


static func _contract_static(game_state) -> Dictionary:
	if game_state == null:
		return {}
	var value = game_state.get("pseudo_god_contract")
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _set_contract(game_state, contract: Dictionary) -> void:
	if game_state != null:
		game_state.set("pseudo_god_contract", contract.duplicate(true))


static func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate()
	return []


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
