extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_charge.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("charged_target", 30, 0, 0)
	var card = _effect_card("charge_burn", [{"id": "charge", "magnitude": 1, "payload": [{"id": "burn", "duration": 2, "magnitude": 4}]}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "charge card can be played")
	assert_eq(battle.charged_zone.size(), 1, "charge enters charged_zone")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(battle.charged_zone.size(), 0, "charge resolves after one player-turn tick")
	assert_true(enemy.has_status("burn"), "charge payload dispatches nested burn effect")
	return _result()
