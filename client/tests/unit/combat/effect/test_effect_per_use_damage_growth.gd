extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_per_use_damage_growth.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 100, 0, 0)
	var card = _effect_card("paper_blade", [{"id": "per_use_damage_growth", "magnitude": 1, "cap": 3}], 5)
	card.tags.assign(["attack"])
	var battle = _start_battle([card], player, enemy)
	battle.hand.clear()

	for i in range(4):
		battle.discard_pile.erase(card)
		battle.hand.append(card)
		assert_true(battle.play_card(card, enemy), "per-use growth play %d succeeds" % [i + 1])
	assert_eq(enemy.hp, 74, "per_use_damage_growth deals 5, 6, 7, then capped 8 damage")
	return _result()
