class_name TarotMinigame
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")

const BET_MIN := 50
const BET_MAX := 200


func major_arcana_deck() -> Array:
	return [
		{"id": "fool", "family": "mystic"},
		{"id": "magician", "family": "mystic"},
		{"id": "high_priestess", "family": "mystic"},
		{"id": "empress", "family": "court"},
		{"id": "emperor", "family": "court"},
		{"id": "hierophant", "family": "church"},
		{"id": "lovers", "family": "human"},
		{"id": "chariot", "family": "force"},
		{"id": "strength", "family": "force"},
		{"id": "hermit", "family": "mystic"},
		{"id": "wheel_of_fortune", "family": "fate"},
		{"id": "justice", "family": "church"},
		{"id": "hanged_man", "family": "fate"},
		{"id": "death", "family": "fate"},
		{"id": "temperance", "family": "church"},
		{"id": "devil", "family": "shadow"},
		{"id": "tower", "family": "shadow"},
		{"id": "star", "family": "mystic"},
		{"id": "moon", "family": "mystic"},
		{"id": "sun", "family": "force"},
		{"id": "judgement", "family": "church"},
		{"id": "world", "family": "fate"},
	]


func outcome_modes() -> Array:
	return [
		{"id": "no_relation", "chance_pct": 60.0, "payout_multiplier": 0.0},
		{"id": "one_relation", "chance_pct": 25.0, "payout_multiplier": 0.5},
		{"id": "mystic_three", "chance_pct": 8.0, "payout_multiplier": 2.0},
		{"id": "same_polarity_three", "chance_pct": 5.0, "payout_multiplier": 3.0},
		{"id": "fool_mystic", "chance_pct": 1.5, "payout_multiplier": 4.0},
		{"id": "major_same_polarity", "chance_pct": 0.5, "payout_multiplier": 10.0},
	]


func grade_for_roll(roll: float) -> String:
	var r := clampf(roll, 0.0, 0.999999)
	var cumulative := 0.0
	var modes := outcome_modes()
	for mode in modes:
		cumulative += float(mode.get("chance_pct", 0.0)) / 100.0
		if r < cumulative:
			return str(mode.get("id", ""))
	return str((modes.back() as Dictionary).get("id", "major_same_polarity"))


func play(game_state, options: Dictionary) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var bet := int(options.get("bet", 0))
	if bet < BET_MIN or bet > BET_MAX:
		return {"ok": false, "reason": "bet_out_of_range", "bet_min": BET_MIN, "bet_max": BET_MAX}
	if int(game_state.lingstones) < bet:
		return {"ok": false, "reason": "lingstones_short", "bet": bet, "lingstones": int(game_state.lingstones)}
	if int(game_state.ap) < ApServiceScript.casino_round_cost():
		return {"ok": false, "reason": "ap_short", "cost": ApServiceScript.casino_round_cost(), "remaining": int(game_state.ap)}
	var grade := grade_for_roll(float(options.get("roll", 0.0)))
	game_state.spend_ap(ApServiceScript.casino_round_cost())
	game_state.lingstones -= bet
	var payout := int(floor(float(bet) * _payout_multiplier(grade)))
	game_state.lingstones += payout
	_apply_grade_reward(game_state, grade, float(options.get("reward_roll", 1.0)))
	return {
		"ok": true,
		"id": "tarot_divination",
		"grade": grade,
		"payout": payout,
		"net_delta": payout - bet,
		"draw": _draw_for_grade(grade),
	}


func _payout_multiplier(grade: String) -> float:
	for mode in outcome_modes():
		if mode is Dictionary and str(mode.get("id", "")) == grade:
			return float(mode.get("payout_multiplier", 0.0))
	return 0.0


func _apply_grade_reward(game_state, grade: String, reward_roll: float) -> void:
	match grade:
		"mystic_three":
			game_state.forge_materials["tarot_residue"] = int(game_state.forge_materials.get("tarot_residue", 0)) + 1
		"same_polarity_three":
			if reward_roll < 0.5:
				_add_temp_card(game_state, "temp_tarot_same_polarity", "塔罗同色临时牌", "rare")
		"fool_mystic":
			_add_temp_card(game_state, "temp_tarot_fool_rare", "愚者潮汐临时牌", "rare")
		"major_same_polarity":
			game_state.brands_inventory.append(BrandScript.from_dict({
				"id": "tarot_low_brand",
				"display_name": "塔罗低阶烙印",
				"pathway_affinity": "any",
				"sequence_min": 9,
				"effect_type": "tarot_reward",
				"effect_payload": {},
				"description": "R25 tarot jackpot reward",
			}))


func _add_temp_card(game_state, card_id: String, display_name: String, rarity: String) -> void:
	var card = CardScript.from_json({
		"id": card_id,
		"template_id": card_id,
		"display_name": display_name,
		"pathway": "fool",
		"sequence": 9,
		"rarity": rarity,
		"quality": 1,
		"energy_cost": 1,
		"combat_effect": {"damage": 3, "target": "single"},
	})
	if game_state.has_method("add_temp_card"):
		game_state.add_temp_card(card)
	else:
		game_state.temp_picked_cards.append(card)


func _draw_for_grade(grade: String) -> Array:
	match grade:
		"fool_mystic":
			return ["fool", "moon", "star"]
		"mystic_three":
			return ["magician", "high_priestess", "hermit"]
		"same_polarity_three":
			return ["empress", "emperor", "strength"]
		"major_same_polarity":
			return ["sun", "judgement", "world"]
		"one_relation":
			return ["wheel_of_fortune", "hanged_man", "death"]
		_:
			return ["devil", "tower", "lovers"]
