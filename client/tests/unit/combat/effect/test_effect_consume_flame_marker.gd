extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_consume_flame_marker.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0, 0)
	var card = _effect_card("consume_flame", [{"id": "consume_flame_marker"}])
	var battle = _start_battle([card], player, enemy)
	assert_true(not battle.play_card(card, enemy), "consume_flame_marker card is rejected without flame marker")
	battle.add_field_marker("flame_markers", 2)
	assert_true(battle.play_card(card, enemy), "consume_flame_marker card can be played with flame marker")
	assert_eq(battle.get_field_marker_count("flame_markers"), 1, "consume_flame_marker spends one flame marker")
	return _result()
