extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_cleanse_debuff.gd --")
	var player = _make_player(30)
	player.add_status("poison", {"duration": 2, "magnitude": 3})
	player.add_status("weak", {"duration": 2})
	var enemy = _make_enemy("dummy", 30, 0, 0)
	var card = _effect_card("cleanse_poison", [{"id": "cleanse_debuff", "types": ["poison"]}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "cleanse_debuff card can be played")
	assert_true(not player.has_status("poison"), "cleanse_debuff removes listed debuff")
	assert_true(player.has_status("weak"), "cleanse_debuff leaves unlisted debuff intact")
	return _result()
