extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_burn.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("burning_enemy", 20, 0, 0)
	var card = _effect_card("apply_burn", [{"id": "burn", "duration": 2, "magnitude": 3}])
	var battle = _start_battle([card], player, enemy)
	assert_true(battle.play_card(card, enemy), "burn card can be played")
	assert_true(enemy.has_status("burn"), "burn status is applied")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(enemy.hp, 17, "burn deals turn-start damage")
	assert_eq(int(enemy.statuses["burn"].get("duration", 0)), 1, "burn duration ticks down")

	var miss_enemy = _make_enemy("burn_chance_miss_enemy", 20, 0, 0)
	var miss_card = _effect_card("burn_chance_miss", [{"id": "burn", "chance": 0.0, "duration": 2, "magnitude": 3}])
	var miss_battle = _start_battle([miss_card], _make_player(30), miss_enemy)
	assert_true(miss_battle.play_card(miss_card, miss_enemy), "burn chance miss card can be played")
	assert_true(not miss_enemy.has_status("burn"), "chance 0 burn is not applied")
	assert_eq(str(miss_battle.last_effect_results[0].get("reason", "")), "chance_missed", "chance 0 records a missed effect result")

	var hit_enemy = _make_enemy("burn_chance_hit_enemy", 20, 0, 0)
	var hit_card = _effect_card("burn_chance_hit", [{"id": "burn", "chance": 1.0, "duration": 2, "magnitude": 3}])
	var hit_battle = _start_battle([hit_card], _make_player(30), hit_enemy)
	assert_true(hit_battle.play_card(hit_card, hit_enemy), "burn chance hit card can be played")
	assert_true(hit_enemy.has_status("burn"), "chance 1 burn is applied")
	return _result()
