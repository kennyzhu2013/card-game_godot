extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_cleanse_incoming_debuff.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0, 0)
	var guard = _effect_card("cleanse_next_weak", [{"id": "cleanse_incoming_debuff", "types": ["weak"], "duration": 1}])
	var weak_card = _effect_card("incoming_weak", [{"id": "weak", "duration": 2}])
	var battle = _start_battle([guard, weak_card], player, enemy)
	assert_true(battle.play_card(guard, player), "cleanse_incoming_debuff card can be played")
	assert_true(player.has_status("cleanse_incoming_debuff"), "cleanse_incoming_debuff guard is stored")
	assert_true(battle.play_card(weak_card, player), "incoming weak card can be played")
	assert_true(not player.has_status("weak"), "cleanse_incoming_debuff blocks incoming listed debuff")
	assert_true(not player.has_status("cleanse_incoming_debuff"), "cleanse_incoming_debuff is one-shot")
	return _result()
