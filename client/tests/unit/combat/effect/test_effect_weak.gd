extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_weak.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("weak_attacker", 30, 0, 8)
	var card = _effect_card("apply_weak", [{"id": "weak", "duration": 2}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "weak card can be played")
	assert_true(enemy.has_status("weak"), "weak status is applied through play_card")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 24, "weak attacker deals 75 percent outgoing damage")
	return _result()
