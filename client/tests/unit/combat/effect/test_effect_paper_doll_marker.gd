extends "res://tests/unit/combat/effect/test_effect_harness.gd"


func run() -> Dictionary:
	print("\n-- test_effect_paper_doll_marker.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0, 0)
	var cards := [
		_effect_card("paper_doll_0", [{"id": "paper_doll_marker", "magnitude": 1, "max_stacks": 3}]),
		_effect_card("paper_doll_1", [{"id": "paper_doll_marker", "magnitude": 1, "max_stacks": 3}]),
		_effect_card("paper_doll_2", [{"id": "paper_doll_marker", "magnitude": 1, "max_stacks": 3}]),
		_effect_card("paper_doll_3", [{"id": "paper_doll_marker", "magnitude": 1, "max_stacks": 3}]),
	]
	var battle = _start_battle(cards, player, enemy)
	for card in cards:
		assert_true(battle.play_card(card, player), "%s can be played" % card.id)
	assert_eq(player.get_marker_count("paper_doll"), 3, "paper_doll_marker increments and caps at max_stacks")
	battle.resolve_battle(false, [], 0, null)
	assert_eq(player.get_marker_count("paper_doll"), 0, "paper_doll_marker is battle-scoped and clears on battle end")
	return _result()
