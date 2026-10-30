extends RefCounted

const GlyphArrangementScript = preload("res://scripts/ritual/glyph_arrangement.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_glyph_arrangement.gd --")
	test_empty_arrangement()
	test_place_single_symbol()
	test_clear_slot()
	test_get_at_out_of_range()
	test_shape_line_adjacent_pairs_full()
	test_shape_line_adjacent_pairs_partial()
	test_shape_l_adjacent_pairs_full()
	test_shape_hex_adjacent_pairs_full()
	test_to_dict()
	return {"passed": _passed, "failed": _failed}


func test_empty_arrangement() -> void:
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	assert_eq(ga.placed_count(), 0, "empty placed_count == 0")
	assert_eq(ga.get_at(0), "", "empty get_at(0) == ''")
	assert_eq(ga.adjacent_symbol_pairs().size(), 0, "empty adjacent_symbol_pairs is empty")


func test_place_single_symbol() -> void:
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	assert_eq(ga.placed_count(), 1, "placed_count == 1 after single place")
	assert_eq(ga.get_at(0), "shadow", "get_at(0) == 'shadow'")
	assert_eq(ga.get_at(1), "", "get_at(1) still empty")


func test_clear_slot() -> void:
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.clear_slot(0)
	assert_eq(ga.placed_count(), 0, "placed_count == 0 after clear_slot")
	assert_eq(ga.get_at(0), "", "get_at(0) == '' after clear_slot")


func test_get_at_out_of_range() -> void:
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	assert_eq(ga.get_at(-1), "", "get_at(-1) returns ''")
	assert_eq(ga.get_at(99), "", "get_at(99) returns ''")


func test_shape_line_adjacent_pairs_full() -> void:
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.place(1, "jester")
	ga.place(2, "name")
	var pairs: Array = ga.adjacent_symbol_pairs()
	assert_eq(pairs.size(), 2, "SHAPE_LINE full: 2 adjacent pairs")
	assert_eq(String(pairs[0][0]), "shadow", "pair0[0] == shadow")
	assert_eq(String(pairs[0][1]), "jester", "pair0[1] == jester")
	assert_eq(String(pairs[1][0]), "jester", "pair1[0] == jester")
	assert_eq(String(pairs[1][1]), "name", "pair1[1] == name")


func test_shape_line_adjacent_pairs_partial() -> void:
	# Place only slots 0 and 2, not slot 1 → no adjacent pair
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.place(2, "name")
	var pairs: Array = ga.adjacent_symbol_pairs()
	assert_eq(pairs.size(), 0, "SHAPE_LINE partial (slots 0,2): 0 pairs (no adjacency)")


func test_shape_l_adjacent_pairs_full() -> void:
	var ga = GlyphArrangementScript.new(4, GlyphArrangementScript.SHAPE_L)
	ga.place(0, "a")
	ga.place(1, "b")
	ga.place(2, "c")
	ga.place(3, "d")
	var pairs: Array = ga.adjacent_symbol_pairs()
	assert_eq(pairs.size(), 3, "SHAPE_L full: 3 adjacent pairs")


func test_shape_hex_adjacent_pairs_full() -> void:
	var ga = GlyphArrangementScript.new(6, GlyphArrangementScript.SHAPE_HEX)
	ga.place(0, "a")
	ga.place(1, "b")
	ga.place(2, "c")
	ga.place(3, "d")
	ga.place(4, "e")
	ga.place(5, "f")
	var pairs: Array = ga.adjacent_symbol_pairs()
	assert_eq(pairs.size(), 6, "SHAPE_HEX full: 6 adjacent pairs (closed loop)")


func test_to_dict() -> void:
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.place(2, "name")
	var d := ga.to_dict()
	assert_eq(int(d.get("capacity", 0)), 3, "to_dict capacity == 3")
	assert_eq(int(d.get("shape", -1)), int(GlyphArrangementScript.SHAPE_LINE), "to_dict shape == SHAPE_LINE")
	var slots: Array = d.get("slots", [])
	assert_eq(slots.size(), 3, "to_dict slots size == 3")
	assert_eq(String(slots[0]), "shadow", "to_dict slots[0] == shadow")
	assert_eq(String(slots[1]), "", "to_dict slots[1] == ''")
	assert_eq(String(slots[2]), "name", "to_dict slots[2] == name")


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
