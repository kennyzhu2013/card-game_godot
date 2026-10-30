extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_absorb_fatal_or_curse.gd --")
	var player = _make_player(20)
	var enemy = _make_enemy("lethal_attacker", 30, 0, 50)
	var card = _effect_card("paper_doll_guard", [
		{"id": "paper_doll_marker", "magnitude": 1, "max_stacks": 3},
		{"id": "absorb_fatal_or_curse"},
	])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "paper doll guard can be played")
	assert_eq(player.get_marker_count("paper_doll"), 1, "paper_doll marker is placed")
	assert_true(player.has_status("absorb_fatal_or_curse"), "absorb_fatal_or_curse trigger flag is stored")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 20, "paper doll absorbs the lethal hit")
	assert_eq(player.get_marker_count("paper_doll"), 0, "paper doll marker is consumed by lethal absorption")
	return _result()
