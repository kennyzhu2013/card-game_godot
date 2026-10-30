extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_create_or_move_flame_markers.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0, 0)
	var card = _effect_card("create_flames", [{"id": "create_or_move_flame_markers", "magnitude": 2}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "create_or_move_flame_markers card can be played")
	assert_eq(battle.get_field_marker_count("flame_markers"), 2, "flame markers are added to field_state")
	return _result()
