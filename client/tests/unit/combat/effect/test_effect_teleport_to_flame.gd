extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_teleport_to_flame.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("flame_target", 30, 0, 0)
	var card = _effect_card("flame_jump", [{"id": "teleport_to_flame"}])
	var battle = _start_battle([card], player, enemy)
	battle.add_field_marker("flame_markers", 1)
	assert_true(battle.play_card(card, enemy), "teleport_to_flame card can be played with flame marker")
	assert_eq(battle.get_field_marker_count("flame_markers"), 0, "teleport_to_flame consumes one flame marker")
	assert_eq(enemy.hp, 24, "teleport_to_flame deals 6 direct damage")
	return _result()
