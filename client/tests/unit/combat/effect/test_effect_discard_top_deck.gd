extends "res://tests/unit/combat/effect/test_effect_harness.gd"

func run() -> Dictionary:
	print("\n-- test_effect_discard_top_deck.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0)
	var top_card = _tagged_card("top_attack", ["attack"])
	var next_card = _tagged_card("next_card", ["skill"])
	var card = _effect_card("paper_arsenal", [{"id": "discard_top_deck"}])
	var battle = _start_battle([card], player, enemy)
	battle.draw_pile = [top_card, next_card]
	battle.discard_pile.clear()
	battle.hand.clear()
	battle.hand.append(card)

	assert_true(battle.play_card(card, enemy), "discard_top_deck card can be played")
	assert_eq(battle.discard_pile.size(), 2, "discard_top_deck moves one extra card to discard")
	assert_true(battle.discard_pile[0] == top_card, "discard_top_deck pops the top card")
	assert_true(battle.field_state.get("last_discarded", null) == top_card, "last_discarded records the popped card")
	assert_eq(battle.draw_pile.size(), 1, "discard_top_deck leaves the remaining draw pile intact")
	assert_true(battle.draw_pile[0] == next_card, "discard_top_deck keeps the second card in draw pile")
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
