extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_multi_strike.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("armored_dummy", 40, 2, 0)
	var card = _effect_card("acrobat_strike", [{"id": "multi_strike", "hits": 3, "damage_each": 4}], 12)
	card.tags.assign(["attack"])
	var battle = _start_battle([card], player, enemy)

	assert_true(battle.play_card(card, enemy), "multi_strike card can be played")
	assert_eq(enemy.hp, 34, "multi_strike resolves three independent 4-damage hits through defense")
	return _result()
