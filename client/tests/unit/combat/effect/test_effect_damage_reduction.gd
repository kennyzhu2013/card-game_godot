extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_damage_reduction.gd --")
	test_flat_damage_reduction_lowers_next_incoming_hit_by_magnitude()
	test_fractional_damage_reduction_lowers_next_incoming_hit_by_percent()
	test_dodge_counter_negates_next_hit_and_reflects_damage()
	return _result()


func test_flat_damage_reduction_lowers_next_incoming_hit_by_magnitude() -> void:
	var player = _make_player(30)
	var enemy = _make_enemy("attacker", 30, 0, 10)
	var card = _effect_card("apply_damage_reduction", [{"id": "damage_reduction", "magnitude": 4, "duration": 1}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "damage_reduction card can be played")
	assert_true(player.has_status("damage_reduction"), "damage_reduction status is applied")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 24, "damage_reduction lowers next incoming hit by magnitude")


func test_fractional_damage_reduction_lowers_next_incoming_hit_by_percent() -> void:
	var player = _make_player(30)
	var enemy = _make_enemy("percent_reducer_attacker", 30, 0, 10)
	var card = _effect_card("apply_percent_damage_reduction", [{"id": "damage_reduction", "magnitude": 0.5, "duration": 1}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "fractional damage_reduction card can be played")
	assert_true(player.has_status("damage_reduction"), "fractional damage_reduction status is applied")
	var intent: Dictionary = battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 5, "fractional damage_reduction changes revealed incoming damage")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 25, "magnitude 0.5 damage_reduction halves the next incoming hit")


func test_dodge_counter_negates_next_hit_and_reflects_damage() -> void:
	var player = _make_player(30)
	var enemy = _make_enemy("countered_attacker", 30, 0, 10)
	var card = _effect_card("apply_dodge_counter", [{"id": "dodge_counter", "magnitude": 3, "duration": 1}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, player), "dodge_counter card can be played")
	assert_true(player.has_status("dodge_counter"), "dodge_counter status is applied")
	var intent: Dictionary = battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 0, "dodge_counter previews the next incoming hit as dodged")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 30, "dodge_counter prevents the next incoming hit")
	assert_eq(enemy.hp, 27, "dodge_counter reflects its magnitude to the attacker")
	assert_true(not player.has_status("dodge_counter"), "dodge_counter is consumed by the next incoming hit")
