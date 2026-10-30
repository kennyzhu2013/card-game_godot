extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_poison.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("poisoned_enemy", 4, 0, 0)
	var card = _effect_card("apply_poison", [{"id": "poison", "duration": 1, "magnitude": 5}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "poison card can be played")
	assert_true(enemy.has_status("poison"), "poison status is applied")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_true(enemy.is_dead(), "poison can kill before enemy intent")
	assert_true(not enemy.has_status("poison"), "poison duration 1 is removed after tick")
	return _result()
