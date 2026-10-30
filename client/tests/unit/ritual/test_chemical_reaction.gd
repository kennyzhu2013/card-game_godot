extends RefCounted

const ChemicalReactionScript = preload("res://scripts/ritual/chemical_reaction.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_chemical_reaction.gd --")
	test_constructor_populates_fields()
	test_matches_same_order_returns_true()
	test_matches_reversed_order_returns_true()
	test_matches_different_elements_returns_false()
	test_matches_different_size_returns_false()
	test_matches_subset_returns_false()
	test_matches_superset_returns_false()
	test_matches_empty_with_empty_returns_true()
	test_from_dict_populates_fields()
	test_to_dict_round_trip()
	return {"passed": _passed, "failed": _failed}


func test_constructor_populates_fields() -> void:
	var rx = ChemicalReactionScript.new("shadow_jester", ["shadow", "jester"], "影代身位", "目标把你看成另一个人", 3)
	assert_eq(rx.id, "shadow_jester", "ChemicalReaction.id set from constructor")
	assert_eq(rx.display_name, "影代身位", "ChemicalReaction.display_name set from constructor")
	assert_eq(rx.description, "目标把你看成另一个人", "ChemicalReaction.description set from constructor")
	assert_eq(rx.pollution_delta, 3, "ChemicalReaction.pollution_delta set from constructor")
	assert_eq(rx.required_symbols.size(), 2, "ChemicalReaction.required_symbols has 2 entries")
	assert_eq(rx.required_symbols[0], "shadow", "required_symbols[0] == shadow")
	assert_eq(rx.required_symbols[1], "jester", "required_symbols[1] == jester")


func test_matches_same_order_returns_true() -> void:
	var rx = ChemicalReactionScript.new("rx1", ["a", "b"], "name", "desc", 1)
	assert_true(rx.matches(["a", "b"]), "matches same-order [a,b] returns true")


func test_matches_reversed_order_returns_true() -> void:
	var rx = ChemicalReactionScript.new("rx1", ["a", "b"], "name", "desc", 1)
	assert_true(rx.matches(["b", "a"]), "matches reversed-order [b,a] returns true (ORDER-AGNOSTIC)")


func test_matches_different_elements_returns_false() -> void:
	var rx = ChemicalReactionScript.new("rx1", ["a", "b"], "name", "desc", 1)
	assert_true(not rx.matches(["a", "c"]), "matches [a,c] returns false (different elements)")
	assert_true(not rx.matches(["x", "y"]), "matches [x,y] returns false (all different)")


func test_matches_different_size_returns_false() -> void:
	var rx = ChemicalReactionScript.new("rx1", ["a", "b"], "name", "desc", 1)
	assert_true(not rx.matches(["a"]), "matches [a] alone returns false (smaller size)")


func test_matches_subset_returns_false() -> void:
	var rx = ChemicalReactionScript.new("rx1", ["a", "b", "c"], "name", "desc", 1)
	assert_true(not rx.matches(["a", "b"]), "matches subset returns false")


func test_matches_superset_returns_false() -> void:
	var rx = ChemicalReactionScript.new("rx1", ["a", "b"], "name", "desc", 1)
	assert_true(not rx.matches(["a", "b", "c"]), "matches superset returns false")


func test_matches_empty_with_empty_returns_true() -> void:
	var rx = ChemicalReactionScript.new("rx_empty", [], "name", "desc", 0)
	assert_true(rx.matches([]), "matches empty arrays returns true")


func test_from_dict_populates_fields() -> void:
	var data := {
		"id": "jester_name",
		"required_symbols": ["jester", "name"],
		"display_name": "夺名之诡",
		"description": "借走目标记忆中某人的名字",
		"pollution_delta": 5,
	}
	var rx = ChemicalReactionScript.from_dict(data)
	assert_eq(rx.id, "jester_name", "from_dict sets id")
	assert_eq(rx.display_name, "夺名之诡", "from_dict sets display_name")
	assert_eq(rx.description, "借走目标记忆中某人的名字", "from_dict sets description")
	assert_eq(rx.pollution_delta, 5, "from_dict sets pollution_delta")
	assert_eq(rx.required_symbols.size(), 2, "from_dict sets required_symbols size")
	assert_true(rx.matches(["name", "jester"]), "from_dict-built reaction matches reversed")


func test_to_dict_round_trip() -> void:
	var rx = ChemicalReactionScript.new("rx_round", ["x", "y"], "测试", "round-trip desc", 4)
	var dict := rx.to_dict()
	assert_eq(String(dict.get("id", "")), "rx_round", "to_dict id")
	assert_eq(String(dict.get("display_name", "")), "测试", "to_dict display_name")
	assert_eq(String(dict.get("description", "")), "round-trip desc", "to_dict description")
	assert_eq(int(dict.get("pollution_delta", 0)), 4, "to_dict pollution_delta")
	var required: Array = dict.get("required_symbols", [])
	assert_eq(required.size(), 2, "to_dict required_symbols size")
	# Round-trip via from_dict
	var rebuilt = ChemicalReactionScript.from_dict(dict)
	assert_eq(rebuilt.id, rx.id, "round-trip id")
	assert_eq(rebuilt.display_name, rx.display_name, "round-trip display_name")
	assert_eq(rebuilt.description, rx.description, "round-trip description")
	assert_eq(rebuilt.pollution_delta, rx.pollution_delta, "round-trip pollution_delta")
	assert_true(rebuilt.matches(["y", "x"]), "round-trip matches order-agnostic")


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
