extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")

const MATERIAL_ID := "愚者残页"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_card_destroy.gd --")
	test_destroy_card_refunds_materials_by_quality()
	test_destroy_card_removes_inventory_and_active_deck()
	test_destroy_card_daodian_unchanged()
	test_destroy_nonexistent_returns_false_and_keeps_materials()
	return {"passed": _passed, "failed": _failed}


func _new_gs():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func test_destroy_card_refunds_materials_by_quality() -> void:
	for quality in [1, 2, 3, 4, 5]:
		var gs = _new_gs()
		var card_id := "destroy_quality_%d" % int(quality)
		var c = CardScript.from_json({"id": card_id, "quality": int(quality)})
		gs.add_card(c)
		var before := int(gs.forge_materials.get(MATERIAL_ID, 0))
		var result = gs.destroy_card(card_id)
		var after := int(gs.forge_materials.get(MATERIAL_ID, 0))
		assert_true(result, "destroy_card succeeds for quality %d" % int(quality))
		assert_eq(after - before, _expected_refund_for_quality(int(quality)), "quality %d refund follows floor(base * multiplier * 0.5)" % int(quality))


func test_destroy_card_removes_inventory_and_active_deck() -> void:
	var gs = _new_gs()
	var card_id := "destroy_test_active_deck"
	var c = CardScript.from_json({"id": card_id, "quality": 3})
	gs.add_card(c)
	assert_true(gs.set_active_deck([card_id]), "setup active_deck for destroy test")
	var before_size: int = gs.cards_inventory.size()
	gs.destroy_card(card_id)
	assert_true(gs.cards_inventory.size() == before_size - 1 and not (card_id in gs.active_deck), "destroy removes card from inventory and active_deck")


func test_destroy_card_daodian_unchanged() -> void:
	var gs = _new_gs()
	gs.daodian["discovered_cards"] = ["destroy_test_c"]
	var c = CardScript.from_json({"id": "destroy_test_c", "quality": 2})
	gs.add_card(c)
	gs.destroy_card("destroy_test_c")
	assert_true("destroy_test_c" in gs.daodian["discovered_cards"], "daodian.discovered_cards unchanged after destroy")


func test_destroy_nonexistent_returns_false_and_keeps_materials() -> void:
	var gs = _new_gs()
	var before_materials := int(gs.forge_materials.get(MATERIAL_ID, 0))
	var result = gs.destroy_card("nonexistent_card")
	assert_true(not result, "destroy nonexistent returns false")
	assert_eq(int(gs.forge_materials.get(MATERIAL_ID, 0)), before_materials, "forge_materials unchanged on failed destroy")
	assert_eq(gs.cards_inventory.size(), 0, "inventory unchanged on failed destroy")


func _expected_refund_for_quality(quality: int) -> int:
	var expected_by_quality := {
		1: 0,
		2: 0,
		3: 1,
		4: 1,
		5: 1,
	}
	return int(expected_by_quality.get(quality, 0))


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
