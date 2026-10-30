extends "res://tests/unit/combat/effect/test_effect_harness.gd"

func run() -> Dictionary:
	print("\n-- test_effect_weak_if_status.gd --")
	var player = _make_player(30)
	var enemy = _make_enemy("dummy", 30, 0)
	var status_card = _tagged_card("top_status", ["status"])
	var card = _effect_card("paper_arsenal", [
		{"id": "discard_top_deck"},
		{"id": "weak_if_status", "duration": 2},
	])
	var battle = _start_battle([card], player, enemy)
	battle.draw_pile = [status_card]
	battle.discard_pile.clear()
	battle.hand.clear()
	battle.hand.append(card)

	assert_true(battle.play_card(card, enemy), "weak_if_status card can be played")
	assert_true(enemy.has_status("weak"), "weak_if_status applies weak")
	if enemy.has_status("weak"):
		assert_eq(int(enemy.statuses["weak"].get("duration", 0)), 2, "weak_if_status keeps the requested duration")
	else:
		assert_true(false, "weak_if_status keeps the requested duration")
	assert_true(battle.field_state.get("last_discarded", null) == status_card, "discard_top_deck records a status card")
	return _result()


func _tagged_card(id: String, tags: Array) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": tags,
	})
