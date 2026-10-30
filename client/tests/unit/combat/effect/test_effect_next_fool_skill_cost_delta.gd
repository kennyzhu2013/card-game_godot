extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_next_fool_skill_cost_delta.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0)
	var buff_card = _effect_card("swift_cast", [{"id": "next_fool_skill_cost_delta", "magnitude": -1}])
	buff_card.tags.assign(["skill"])
	var first_skill = _skill_card("fool_skill_one", 1)
	var second_skill = _skill_card("fool_skill_two", 1)
	var battle = _start_battle([buff_card, first_skill, second_skill], player, enemy)
	battle.energy = 1
	battle.hand.clear()
	battle.hand.append(buff_card)
	battle.hand.append(first_skill)
	battle.hand.append(second_skill)

	assert_true(battle.play_card(buff_card, enemy), "next_fool_skill_cost_delta buff card can be played")
	assert_true(player.has_status("next_card_cost_delta"), "buff applies a next-card cost delta status")
	assert_true(battle.play_card(first_skill, enemy), "first fool skill is discounted to zero")
	assert_true(not player.has_status("next_card_cost_delta"), "buff is consumed after the next fool skill")
	assert_true(battle.play_card(second_skill, enemy), "second fool skill still plays after the buff is consumed")
	assert_eq(battle.energy, 0, "only the first fool skill receives the discount")
	return _result()


func _skill_card(id: String, energy_cost: int) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": energy_cost,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["skill"],
	})
