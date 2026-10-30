extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_select_targets.gd --")
	var player = _make_player(30)
	var enemy_a = _make_enemy("multi_a", 40, 0, 0)
	var enemy_b = _make_enemy("multi_b", 40, 0, 0)
	var enemy_c = _make_enemy("multi_c", 40, 0, 0)
	var card = _effect_card("paper_blade_volley", [{"id": "select_targets", "min": 1, "max": 3}], 10)
	card.tags.assign(["attack"])
	var battle = TurnBattleScript.new()
	battle.setup_battle([card], [], [enemy_a, enemy_b, enemy_c], [], player, _game_state())
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	battle.field_state["selected_targets"] = [enemy_a, enemy_b, enemy_c]

	assert_true(battle.play_card(card, enemy_a), "select_targets card can be played with three selected targets")
	assert_eq(enemy_a.hp, 35, "selected target A takes 50 percent damage at three targets")
	assert_eq(enemy_b.hp, 35, "selected target B takes 50 percent damage at three targets")
	assert_eq(enemy_c.hp, 35, "selected target C takes 50 percent damage at three targets")
	return _result()
