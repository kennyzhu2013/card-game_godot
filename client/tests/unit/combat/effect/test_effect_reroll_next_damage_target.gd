extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_reroll_next_damage_target.gd --")
	var player = _make_player(30)
	var enemy_a = _make_enemy("reroll_a", 40, 0, 0)
	var enemy_b = _make_enemy("reroll_b", 40, 0, 0)
	var illusion = _effect_card("illusion_weave", [{"id": "reroll_next_damage_target"}], 0)
	illusion.tags.assign(["skill"])
	var strike = _effect_card("followup_strike", [], 10)
	strike.tags.assign(["attack"])
	var battle = TurnBattleScript.new()
	battle.setup_battle([illusion, strike], [], [enemy_a, enemy_b], [], player, _game_state())
	battle.hand.clear()
	battle.hand.append(illusion)
	battle.hand.append(strike)
	battle.energy = 99

	assert_true(battle.play_card(illusion, player), "reroll setup card can be played")
	assert_true(player.has_status("reroll_next_target"), "reroll_next_damage_target applies the player buff")
	assert_true(battle.play_card(strike, enemy_a), "follow-up damage card can be played")
	assert_eq(enemy_a.hp, 40, "reroll_next_target redirects away from the chosen target when another living enemy exists")
	assert_eq(enemy_b.hp, 30, "reroll_next_target sends the next damage to another living enemy")
	assert_true(not player.has_status("reroll_next_target"), "reroll_next_target is consumed by the next damage event")
	return _result()
