extends "res://tests/unit/combat/effect/test_effect_harness.gd"

func run() -> Dictionary:
	print("\n-- test_effect_create_random_temp_card.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0)
	var existing_card = _tagged_card("existing_bottom", ["skill"])
	var temp_option = {
		"id": "temp_draw",
		"template_id": "temp_draw",
		"display_name": "temp_draw",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["skill"],
	}
	var card = _effect_card("minor_trick", [{"id": "create_random_temp_card", "options": [temp_option]}])
	var battle = _start_battle([card], player, enemy)
	battle.draw_pile = [existing_card]
	battle.discard_pile.clear()
	battle.hand.clear()
	battle.hand.append(card)

	assert_true(battle.play_card(card, enemy), "create_random_temp_card can be played")
	assert_eq(battle.draw_pile.size(), 2, "create_random_temp_card inserts one card into draw pile")
	if battle.draw_pile.size() > 0:
		assert_true(battle.draw_pile[0].id == "temp_draw", "create_random_temp_card pushes the temp card to the top")
	else:
		assert_true(false, "create_random_temp_card pushes the temp card to the top")
	if battle.draw_pile.size() > 1:
		assert_true(battle.draw_pile[1] == existing_card, "create_random_temp_card preserves the previous draw pile order")
	else:
		assert_true(false, "create_random_temp_card preserves the previous draw pile order")
	return _result()


func _tagged_card(id: String, tags: Array) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": tags,
	})
