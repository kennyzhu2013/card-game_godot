extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_consume_on_trigger.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("trigger_attacker", 30, 0, 10)
	var card = _effect_card("consume_reduction", [
		{"id": "damage_reduction", "magnitude": 4, "duration": 2},
		{"id": "consume_on_trigger"},
	])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "consume_on_trigger card can be played")
	assert_true(player.has_status("damage_reduction"), "trigger status is stored before hit")
	assert_true(player.has_status("consume_on_trigger"), "consume_on_trigger marker is stored before hit")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 24, "triggered status still affects the hit")
	assert_true(not player.has_status("damage_reduction"), "triggered status is removed after trigger")
	assert_true(not player.has_status("consume_on_trigger"), "consume_on_trigger marker is removed after trigger")
	return _result()
