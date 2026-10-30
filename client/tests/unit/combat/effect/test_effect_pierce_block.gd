extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_pierce_block.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("armored_enemy", 20, 5, 0)
	var card = _effect_card("piercing_strike", [{"id": "pierce_block", "magnitude": 3}], 8)
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "pierce_block card can be played")
	assert_eq(enemy.hp, 14, "pierce_block ignores magnitude points of defense")
	return _result()
