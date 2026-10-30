extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_fatal_damage_convert.gd --")
	var player = _make_player(20)
	var enemy = _make_enemy("lethal_attacker", 30, 0, 50)
	var card = _effect_card("apply_fatal_convert", [{"id": "fatal_damage_convert", "magnitude": 0.5, "uses_per_battle": 2}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "fatal_damage_convert card can be played")
	assert_true(player.has_status("fatal_damage_convert"), "fatal_damage_convert status is stored")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 10, "fatal_damage_convert turns lethal hit into proportional damage")
	assert_eq(int(player.statuses["fatal_damage_convert"].get("uses_per_battle", 0)), 1, "fatal_damage_convert consumes one use")
	return _result()
