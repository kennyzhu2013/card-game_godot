extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_nightmare.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("nightmare_dummy", 30, 0, 0)
	var card = _effect_card("apply_nightmare", [{"id": "nightmare", "duration": 2}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "nightmare card can be played on player")
	assert_true(player.has_status("nightmare"), "nightmare status is applied")
	assert_true(player.has_status("vulnerable"), "nightmare also applies vulnerable")
	battle.hand.clear()
	battle.discard_pile.clear()
	battle.draw_pile = [
		_blank_card("draw_0"),
		_blank_card("draw_1"),
		_blank_card("draw_2"),
		_blank_card("draw_3"),
		_blank_card("draw_4"),
	]
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(battle.hand.size(), 4, "nightmare reduces next player draw by one")
	return _result()
