extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_draw_if_no_cleanse.gd --")
	test_draw_if_no_cleanse_draws_when_cleanse_removes_nothing()
	test_draw_if_no_cleanse_skips_draw_when_cleanse_clears_status()
	return _result()


func test_draw_if_no_cleanse_draws_when_cleanse_removes_nothing() -> void:
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0)
	var drawn_card = _blank_card("drawn_card")
	var card = _effect_card("bone_softening", [
		{"id": "cleanse_debuff", "types": ["poison"]},
		{"id": "draw_if_no_cleanse", "magnitude": 1},
	])
	var battle = _start_battle([card], player, enemy)
	battle.draw_pile = [drawn_card]
	battle.discard_pile.clear()
	battle.hand.clear()
	battle.hand.append(card)

	assert_true(battle.play_card(card, player), "draw_if_no_cleanse card can be played when cleanse removes nothing")
	assert_eq(battle.draw_pile.size(), 0, "draw_if_no_cleanse consumes one draw when cleanse fails")
	assert_eq(battle.hand.size(), 1, "draw_if_no_cleanse replenishes the hand by one")
	if battle.hand.size() > 0:
		assert_true(battle.hand[0] == drawn_card, "draw_if_no_cleanse draws the top card")
	else:
		assert_true(false, "draw_if_no_cleanse draws the top card")


func test_draw_if_no_cleanse_skips_draw_when_cleanse_clears_status() -> void:
	var player = _make_player(30)
	player.add_status("poison", {"duration": 2, "magnitude": 1})
	var enemy = _make_enemy("dummy", 30, 0)
	var drawn_card = _blank_card("drawn_card")
	var card = _effect_card("bone_softening", [
		{"id": "cleanse_debuff", "types": ["poison"]},
		{"id": "draw_if_no_cleanse", "magnitude": 1},
	])
	var battle = _start_battle([card], player, enemy)
	battle.draw_pile = [drawn_card]
	battle.discard_pile.clear()
	battle.hand.clear()
	battle.hand.append(card)

	assert_true(battle.play_card(card, player), "draw_if_no_cleanse card can be played when cleanse clears status")
	assert_true(not player.has_status("poison"), "cleanse_debuff removes poison before the draw check")
	assert_eq(battle.draw_pile.size(), 1, "draw_if_no_cleanse leaves the draw pile untouched after a real cleanse")
	assert_true(battle.hand.is_empty(), "draw_if_no_cleanse does not draw when cleanse succeeds")
