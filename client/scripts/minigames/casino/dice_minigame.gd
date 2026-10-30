class_name DiceMinigame
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")

const BET_MIN := 3
const BET_MAX := 30
const CHOICE_BIG := "big"
const CHOICE_SMALL := "small"
const CHOICE_TRIPLE := "triple"


func expected_return(choice: String) -> float:
	var net := 0.0
	for d1 in range(1, 7):
		for d2 in range(1, 7):
			for d3 in range(1, 7):
				net += float(_net_for_choice(str(choice), [d1, d2, d3], 1))
	return net / 216.0


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
	var dice := _dice_values(options.get("dice", []))
	if dice.size() != 3:
		return {"ok": false, "reason": "invalid_dice"}
	var choice := str(options.get("choice", ""))
	if not [CHOICE_BIG, CHOICE_SMALL, CHOICE_TRIPLE].has(choice):
		return {"ok": false, "reason": "invalid_choice"}
	game_state.spend_ap(ApServiceScript.casino_round_cost())
	game_state.lingstones -= bet
	var payout := _payout_for_choice(choice, dice, bet)
	game_state.lingstones += payout
	return {
		"ok": true,
		"id": "dice_cup",
		"choice": choice,
		"dice": dice,
		"total": _sum(dice),
		"grade": _grade(choice, dice),
		"payout": payout,
		"net_delta": payout - bet,
		"animation_state": "shake_reveal",
	}


func _payout_for_choice(choice: String, dice: Array, bet: int) -> int:
	var grade := _grade(choice, dice)
	match grade:
		"big_win", "small_win":
			return bet * 2
		"triple_win":
			return bet * 30
		_:
			return 0


func _net_for_choice(choice: String, dice: Array, bet: int) -> int:
	return _payout_for_choice(choice, dice, bet) - bet


func _grade(choice: String, dice: Array) -> String:
	var triple := _is_triple(dice)
	var total := _sum(dice)
	if choice == CHOICE_TRIPLE:
		return "triple_win" if triple else "loss"
	if triple:
		return "loss"
	if choice == CHOICE_BIG and total >= 11:
		return "big_win"
	if choice == CHOICE_SMALL and total <= 10:
		return "small_win"
	return "loss"


func _dice_values(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for item in value:
		var v := int(item)
		if v < 1 or v > 6:
			return []
		result.append(v)
	return result


func _is_triple(dice: Array) -> bool:
	return dice.size() == 3 and int(dice[0]) == int(dice[1]) and int(dice[1]) == int(dice[2])


func _sum(dice: Array) -> int:
	var total := 0
	for value in dice:
		total += int(value)
	return total
