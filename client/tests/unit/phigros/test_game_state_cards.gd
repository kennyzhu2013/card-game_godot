extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0
var _gs


func run() -> Dictionary:
	print("\n-- test_game_state_cards.gd --")
	test_legacy_atb_slots_initialized()
	test_card_inventory_add_and_capacity()
	test_card_inventory_get_and_remove()
	test_active_deck_validates_card_existence()
	test_active_deck_size_limit()
	test_reset_clears_both_old_and_new()
	return {"passed": _passed, "failed": _failed}


func _new_state():
	# Direct script instance, bypasses autoload (autoload not started in test mode)
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func test_legacy_atb_slots_initialized() -> void:
	_gs = _new_state()
	assert_eq(_gs.equipped_skills.size(), 4, "MAX_SLOTS = 4")
	assert_eq(_gs.equipped_count(), 0, "no slots filled at init")


func test_card_inventory_add_and_capacity() -> void:
	_gs = _new_state()
	var c1 = CardScript.from_json({"id": "c1", "quality": 1})
	assert_true(_gs.add_card(c1), "add_card returns true")
	assert_eq(_gs.cards_inventory.size(), 1, "inventory size 1")


func test_card_inventory_get_and_remove() -> void:
	_gs = _new_state()
	var c2 = CardScript.from_json({"id": "c2", "quality": 2})
	_gs.add_card(c2)
	var got = _gs.get_card("c2")
	assert_true(got != null, "get_card returns object")
	assert_eq(got.quality, 2, "got.quality = 2")
	assert_true(_gs.remove_card("c2"), "remove_card returns true")
	assert_true(_gs.get_card("c2") == null, "card gone after remove")


func test_active_deck_validates_card_existence() -> void:
	_gs = _new_state()
	var c3 = CardScript.from_json({"id": "c3"})
	_gs.add_card(c3)
	var valid: Array[String] = ["c3"]
	assert_true(_gs.set_active_deck(valid), "set_active_deck with existing id")
	var invalid: Array[String] = ["nonexistent"]
	assert_true(not _gs.set_active_deck(invalid), "set_active_deck rejects unknown id")


func test_active_deck_size_limit() -> void:
	_gs = _new_state()
	_gs.sequence = 7  # capacity = 15 per R07 §2
	var ids: Array[String] = []
	for i in 16:
		var c = CardScript.from_json({"id": "deck_%d" % i})
		_gs.add_card(c)
		ids.append("deck_%d" % i)
	var ok: Array[String] = []
	for i in 15:
		ok.append(ids[i])
	assert_true(_gs.set_active_deck(ok), "15 cards accepted")
	assert_true(not _gs.set_active_deck(ids), "16 cards rejected")


func test_reset_clears_both_old_and_new() -> void:
	_gs = _new_state()
	_gs.equipped_skills[0] = "placeholder"
	var c = CardScript.from_json({"id": "to_reset"})
	_gs.add_card(c)
	var ids: Array[String] = ["to_reset"]
	_gs.set_active_deck(ids)
	_gs.reset()
	assert_eq(_gs.cards_inventory.size(), 0, "inventory cleared")
	assert_eq(_gs.active_deck.size(), 0, "active_deck cleared")
	assert_true(_gs.get_equipped_slot(0) == null, "slot 0 cleared")


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
