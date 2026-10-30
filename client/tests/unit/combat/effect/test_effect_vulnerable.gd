extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_vulnerable.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("vulnerable_target", 30, 0, 0)
	var mark = _effect_card("apply_vulnerable", [{"id": "vulnerable", "duration": 2}])
	var strike = _effect_card("strike_vulnerable", [], 10)
	var battle = _start_battle([mark, strike], player, enemy)
	assert_true(battle.play_card(mark, enemy), "vulnerable card can be played")
	assert_true(enemy.has_status("vulnerable"), "vulnerable status is applied")
	assert_true(battle.play_card(strike, enemy), "follow-up strike can be played")
	assert_eq(enemy.hp, 15, "vulnerable target takes 150 percent damage")
	return _result()
