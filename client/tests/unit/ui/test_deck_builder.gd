extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const DeckBuilderScript = preload("res://scripts/ui/deck_builder.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_deck_builder.gd --")
	test_initial_selection_loads_existing_active_deck()
	test_capacity_limit_rejects_extra_card()
	test_sequence_locked_card_rejected_by_builder()
	test_mechanic_locked_card_rejected_by_builder()
	test_same_template_cards_are_allowed()
	test_legendary_quota_caps_to_capacity_ratio()
	test_unique_card_limited_to_one_per_deck()
	test_confirm_writes_active_deck()
	test_confirm_rejects_locked_card()
	test_sort_modes_order_inventory_cards()
	return {"passed": _passed, "failed": _failed}


func test_initial_selection_loads_existing_active_deck() -> void:
	var gs = _state()
	gs.cards_inventory = [
		_card("c1", "shadow_arrow", "fool", 2, 1),
		_card("c2", "flame_arrow", "fool", 1, 2),
		_card("c3", "shadow_arrow", "fool", 3, 0),
	]
	gs.active_deck.clear()
	gs.active_deck.append("c3")
	gs.active_deck.append("missing")
	gs.active_deck.append("c1")
	var selected: Array[String] = DeckBuilderScript.initial_selected_ids(gs)
	assert_eq(selected, ["c3", "c1"], "initial selection keeps valid existing active deck ids")


func test_capacity_limit_rejects_extra_card() -> void:
	var gs = _state()
	gs.sequence = 9
	var selected: Array[String] = []
	for i in range(12):
		var id := "c%d" % i
		gs.cards_inventory.append(_card(id, "template_%d" % i, "fool", 1, 1))
		selected.append(id)
	var extra = _card("c_extra", "extra", "fool", 1, 1)
	gs.cards_inventory.append(extra)
	var result: Dictionary = DeckBuilderScript.can_add_card(extra, selected, gs)
	assert_true(not bool(result.get("ok", true)), "capacity limit rejects 13th card at sequence 9")
	assert_eq(result.get("reason", ""), "capacity_full", "capacity rejection reason")


func test_sequence_locked_card_rejected_by_builder() -> void:
	var gs = _state()
	gs.sequence = 9
	var locked = _card_with_sequence_tags("seq8_locked", 8, ["attack", "multi_strike"])
	gs.cards_inventory.append(locked)
	var result: Dictionary = DeckBuilderScript.can_add_card(locked, [], gs)
	assert_true(not bool(result.get("ok", true)), "deck builder rejects cards above the player's current sequence")
	assert_eq(result.get("reason", ""), "sequence_locked", "sequence lock rejection reason")


func test_mechanic_locked_card_rejected_by_builder() -> void:
	var gs = _state()
	gs.sequence = 9
	var locked = _card_with_sequence_tags("mechanic_locked", 9, ["attack", "multi_strike"])
	gs.cards_inventory.append(locked)
	var result: Dictionary = DeckBuilderScript.can_add_card(locked, [], gs)
	assert_true(not bool(result.get("ok", true)), "deck builder rejects cards using locked combat mechanisms")
	assert_eq(result.get("reason", ""), "mechanic_locked", "mechanic lock rejection reason")


func test_same_template_cards_are_allowed() -> void:
	var gs = _state()
	gs.cards_inventory = [
		_card("c1", "same_template", "fool", 1, 1),
		_card("c2", "same_template", "fool", 1, 1),
		_card("c3", "same_template", "fool", 1, 1),
		_card("c4", "same_template", "fool", 1, 1),
	]
	var result: Dictionary = DeckBuilderScript.can_add_card(gs.cards_inventory[3], ["c1", "c2", "c3"], gs)
	assert_true(bool(result.get("ok", false)), "R01 §2.2 allows multiple same-template cards in active_deck")


func test_legendary_quota_caps_to_capacity_ratio() -> void:
	var gs = _state()
	gs.sequence = 9
	var quota: int = DeckBuilderScript.rarity_quota(int(gs.get_active_deck_capacity()), "legendary")
	assert_eq(quota, 2, "sequence 9 capacity 12 → legendary quota = ceil(12*0.10) = 2")
	var selected: Array[String] = []
	for i in range(quota):
		var id := "legendary_%d" % i
		gs.cards_inventory.append(_card_with_rarity(id, "legendary"))
		selected.append(id)
	var extra = _card_with_rarity("legendary_extra", "legendary")
	gs.cards_inventory.append(extra)
	var result: Dictionary = DeckBuilderScript.can_add_card(extra, selected, gs)
	assert_true(not bool(result.get("ok", true)), "exceeding legendary quota rejects card")
	assert_eq(result.get("reason", ""), "rarity_quota", "rarity quota rejection reason")


func test_unique_card_limited_to_one_per_deck() -> void:
	var gs = _state()
	gs.cards_inventory = [
		_card_with_rarity("u1", "unique"),
		_card_with_rarity("u2", "unique"),
	]
	var result: Dictionary = DeckBuilderScript.can_add_card(gs.cards_inventory[1], ["u1"], gs)
	assert_true(not bool(result.get("ok", true)), "second unique card rejected")
	assert_eq(result.get("reason", ""), "unique_limit", "unique limit rejection reason")


func _card_with_rarity(id: String, rarity: String):
	var card = CardScript.from_json({
		"id": id,
		"template_id": id,
		"pathway": "fool",
		"quality": 5,
		"energy_cost": 1,
		"damage": 5,
		"rarity": rarity,
	})
	return card


func test_confirm_writes_active_deck() -> void:
	var gs = _state()
	gs.cards_inventory = [
		_card("c1", "a", "fool", 1, 1),
		_card("c2", "b", "fool", 1, 1),
	]
	var result: Dictionary = DeckBuilderScript.apply_selection(gs, ["c2", "c1"])
	assert_true(bool(result.get("ok", false)), "apply_selection succeeds")
	assert_eq(gs.active_deck, ["c2", "c1"], "active_deck updated in selected order")


func test_confirm_rejects_locked_card() -> void:
	var gs = _state()
	gs.sequence = 9
	var locked = _card_with_sequence_tags("seq8_locked_confirm", 8, ["attack", "multi_strike"])
	gs.cards_inventory.append(locked)
	var result: Dictionary = DeckBuilderScript.apply_selection(gs, ["seq8_locked_confirm"])
	assert_true(not bool(result.get("ok", true)), "confirm rejects an already-selected locked card")
	assert_eq(result.get("reason", ""), "sequence_locked", "confirm preserves sequence lock reason")


func test_sort_modes_order_inventory_cards() -> void:
	var cards := [
		_card("c1", "a", "mist", 1, 2),
		_card("c2", "b", "fool", 4, 1),
		_card("c3", "c", "fool", 2, 0),
	]
	var by_pathway: Array = DeckBuilderScript.sorted_cards(cards, DeckBuilderScript.SortMode.PATHWAY)
	assert_eq([by_pathway[0].id, by_pathway[1].id, by_pathway[2].id], ["c2", "c3", "c1"], "pathway sort keeps fool first")
	var by_quality: Array = DeckBuilderScript.sorted_cards(cards, DeckBuilderScript.SortMode.QUALITY)
	assert_eq([by_quality[0].id, by_quality[1].id, by_quality[2].id], ["c2", "c3", "c1"], "quality sort high to low")
	var by_energy: Array = DeckBuilderScript.sorted_cards(cards, DeckBuilderScript.SortMode.ENERGY)
	assert_eq([by_energy[0].id, by_energy[1].id, by_energy[2].id], ["c3", "c2", "c1"], "energy sort low to high")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _card(id: String, template_id: String, pathway: String, quality: int, energy_cost: int):
	return CardScript.from_json({
		"id": id,
		"template_id": template_id,
		"pathway": pathway,
		"quality": quality,
		"energy_cost": energy_cost,
		"damage": quality * 3,
	})


func _card_with_sequence_tags(id: String, sequence: int, tags: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": sequence,
		"quality": 1,
		"energy_cost": 1,
		"combat_effect": {"damage": 3, "heal": 0, "target": "single", "range": 1, "status_effects": []},
		"tags": tags,
	})


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
