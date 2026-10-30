extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_adjacent_burn.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("flame_adjacent_enemy", 20, 0, 0)
	var card = _effect_card("flame_command", [
		{"id": "create_or_move_flame_markers", "magnitude": 1},
		{"id": "adjacent_burn", "magnitude": 3},
	])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "adjacent_burn setup card can be played")
	assert_eq(battle.get_field_marker_count("flame_markers"), 1, "flame marker exists before enemy turn")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(enemy.hp, 17, "adjacent_burn damages flame-adjacent enemy at turn start")
	return _result()
