extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_obscure_intent.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("obscured_enemy", 30, 0, 0)
	var card = _effect_card("apply_obscure_intent", [{"id": "obscure_intent", "duration": 2}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "obscure_intent card can be played")
	assert_true(enemy.has_status("obscure_intent"), "obscure_intent status is applied")
	return _result()
