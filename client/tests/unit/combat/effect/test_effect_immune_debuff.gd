extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_immune_debuff.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0, 0)
	var immune = _effect_card("immune_poison", [{"id": "immune_debuff", "types": ["poison"], "duration": 3}])
	var poison = _effect_card("incoming_poison", [{"id": "poison", "duration": 2, "magnitude": 3}])
	var battle = _start_battle([immune, poison], player, enemy)
	assert_true(battle.play_card(immune, player), "immune_debuff card can be played")
	assert_true(player.has_status("immune_debuff"), "immune_debuff status is stored")
	assert_true(battle.play_card(poison, player), "incoming poison card can be played")
	assert_true(not player.has_status("poison"), "immune_debuff blocks listed debuff")
	assert_true(player.has_status("immune_debuff"), "immune_debuff persists after blocking")
	return _result()
