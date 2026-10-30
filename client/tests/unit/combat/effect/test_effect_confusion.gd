extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_confusion.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("confused_target", 30, 0, 0)
	var card = _effect_card("apply_confusion", [{"id": "confusion", "duration": 2}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "confusion card can be played")
	assert_true(enemy.has_status("confusion"), "confusion status is applied")
	assert_eq(int(enemy.statuses["confusion"].get("duration", 0)), 2, "confusion duration is stored")
	return _result()
