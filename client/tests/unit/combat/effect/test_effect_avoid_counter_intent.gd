extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_avoid_counter_intent.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("counter_dummy", 30, 0, 0)
	var normal_card = _effect_card("plain_skill", [], 0)
	var avoid_card = _effect_card("swift_cast", [{"id": "avoid_counter_intent", "duration": 1}], 0)
	var battle = _start_battle([normal_card, avoid_card], player, enemy)
	battle.current_enemy_intents[enemy.id] = {"type": "counter", "damage": 5}
	battle.hand.clear()
	battle.hand.append(normal_card)

	assert_true(battle.play_card(normal_card, enemy), "normal card can be played into a counter intent")
	assert_eq(player.hp, 25, "normal card triggers counter-intent damage")

	player.hp = 30
	battle.current_enemy_intents[enemy.id] = {"type": "counter", "damage": 5}
	battle.hand.append(avoid_card)
	assert_true(battle.play_card(avoid_card, enemy), "avoid_counter_intent card can be played into a counter intent")
	assert_eq(player.hp, 30, "avoid_counter_intent skips counter-intent damage")
	return _result()
