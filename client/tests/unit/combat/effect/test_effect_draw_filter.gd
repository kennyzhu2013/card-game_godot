extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_draw_filter.gd --")
	test_draw_filter_peeks_top_cards_and_draws_default_choice()
	return _result()


func test_draw_filter_peeks_top_cards_and_draws_default_choice() -> void:
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0)
	var chosen_card = _tagged_card("top_skill", ["skill"])
	var returned_card = _tagged_card("second_attack", ["attack"])
	var untouched_card = _tagged_card("third_status", ["status"])
	var card = _effect_card("draw_filter_probe", [{"id": "draw_filter", "peek": 2, "choose": 1, "rest_policy": "return_top"}])
	var battle = TurnBattleScript.new()
	battle.player = player
	battle._game_state = _game_state()
	battle.phase = battle.Phase.PLAYER_TURN
	battle.energy = 99
	battle.energy_max = 99
	battle.battle_sequence = 9
	battle.draw_pile = [chosen_card, returned_card, untouched_card]
	battle.hand = [card]
	battle.discard_pile = []
	battle.exhaust_pile = []
	battle.enemies = [enemy]
	battle.temp_picked_cards = []
	battle.current_enemy_intents = {}
	battle.used_cards = {}
	battle.disabled_in_floor = {}
	battle.last_effect_results = []
	battle.clear_field_state()

	assert_true(battle.play_card(card, enemy), "draw_filter card can be played")
	assert_eq(battle.hand.size(), 1, "draw_filter adds one selected card to hand")
	if battle.hand.size() > 0:
		assert_true(battle.hand[0] == chosen_card, "draw_filter selects the first peeked top card without UI")
	else:
		assert_true(false, "draw_filter selects the first peeked top card without UI")
	assert_eq(battle.draw_pile.size(), 2, "draw_filter returns unchosen peeked cards and leaves untouched cards")
	assert_true(battle.draw_pile[0] == returned_card, "draw_filter keeps the unchosen peeked card on top")
	assert_true(battle.draw_pile[1] == untouched_card, "draw_filter keeps untouched draw pile order")
	assert_true(card in battle.discard_pile, "draw_filter source card still enters discard")
	var result: Dictionary = battle.last_effect_results[0] if battle.last_effect_results.size() > 0 else {}
	assert_eq(str(result.get("id", "")), "draw_filter", "draw_filter records its effect result")
	assert_eq(str(result.get("selected_card_id", "")), "top_skill", "draw_filter result records selected card id")


func _tagged_card(id: String, tags: Array):
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
