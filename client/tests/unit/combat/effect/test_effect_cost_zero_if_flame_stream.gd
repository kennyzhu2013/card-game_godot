extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_cost_zero_if_flame_stream.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0, 0)
	var flame_jump = _effect_card("flame_jump", [{"id": "cost_zero_if_flame_stream"}], 0)
	flame_jump.energy_cost = 2
	var flame_stream = _tagged_card("flame_stream_card", ["flame_stream"])
	var battle = _start_battle([flame_jump, flame_stream], player, enemy)
	battle.energy = 0
	battle.hand.clear()
	battle.hand.append(flame_jump)
	battle.hand.append(flame_stream)

	assert_true(battle.play_card(flame_jump, enemy), "flame jump is playable at zero energy when a flame_stream card is in hand")
	assert_eq(battle.energy, 0, "cost_zero_if_flame_stream spends no energy")

	var no_stream_card = _effect_card("flame_jump_without_stream", [{"id": "cost_zero_if_flame_stream"}], 0)
	no_stream_card.energy_cost = 2
	var battle_without_stream = _start_battle([no_stream_card], player, enemy)
	battle_without_stream.energy = 0
	battle_without_stream.hand.clear()
	battle_without_stream.hand.append(no_stream_card)
	assert_true(not battle_without_stream.play_card(no_stream_card, enemy), "flame jump keeps printed cost when no flame_stream tag is present")
	return _result()


func _tagged_card(id: String, tags: Array) -> Card:
	var card = _effect_card(id, [], 0)
	card.tags.assign(tags)
	return card
