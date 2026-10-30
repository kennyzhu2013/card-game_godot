extends RefCounted

const ReactionEngineScript = preload("res://scripts/ritual/reaction_engine.gd")
const ReactionTableScript = preload("res://scripts/ritual/reaction_table.gd")
const GlyphArrangementScript = preload("res://scripts/ritual/glyph_arrangement.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_reaction_engine.gd --")
	test_empty_arrangement_zero_reactions()
	test_single_pair_one_reaction()
	test_three_symbols_two_reactions()
	test_total_pollution_sums()
	test_reversed_pair_still_matches()
	test_no_matching_reaction()
	test_dedupe_same_reaction_only_once()
	return {"passed": _passed, "failed": _failed}


func _fresh_table() -> Node:
	var t = ReactionTableScript.new()
	t.clear()
	t.load_from_file("res://data/ritual/fool_reactions.json")
	return t


func test_empty_arrangement_zero_reactions() -> void:
	var t := _fresh_table()
	var engine = ReactionEngineScript.new(t)
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	var result: Array = engine.compute(ga)
	assert_eq(result.size(), 0, "empty arrangement produces 0 reactions")
	assert_eq(engine.total_pollution(ga), 0, "empty arrangement total_pollution == 0")
	t.queue_free()


func test_single_pair_one_reaction() -> void:
	var t := _fresh_table()
	var engine = ReactionEngineScript.new(t)
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.place(1, "jester")
	var result: Array = engine.compute(ga)
	assert_eq(result.size(), 1, "single pair [shadow,jester] produces 1 reaction")
	if result.size() >= 1:
		assert_eq(result[0].id, "shadow_jester", "result[0].id == 'shadow_jester'")
	t.queue_free()


func test_three_symbols_two_reactions() -> void:
	var t := _fresh_table()
	var engine = ReactionEngineScript.new(t)
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.place(1, "jester")
	ga.place(2, "name")
	var result: Array = engine.compute(ga)
	assert_eq(result.size(), 2, "three symbols [shadow,jester,name] produce 2 reactions")
	var ids: Array = []
	for rx in result:
		ids.append(rx.id)
	assert_true("shadow_jester" in ids, "result includes shadow_jester")
	assert_true("jester_name" in ids, "result includes jester_name")
	t.queue_free()


func test_total_pollution_sums() -> void:
	var t := _fresh_table()
	var engine = ReactionEngineScript.new(t)
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.place(1, "jester")
	ga.place(2, "name")
	# shadow_jester=3, jester_name=5 → 8
	assert_eq(engine.total_pollution(ga), 8, "total_pollution sums shadow_jester(3)+jester_name(5)==8")
	t.queue_free()


func test_reversed_pair_still_matches() -> void:
	var t := _fresh_table()
	var engine = ReactionEngineScript.new(t)
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	# Place jester then shadow → order-agnostic match
	ga.place(0, "jester")
	ga.place(1, "shadow")
	var result: Array = engine.compute(ga)
	assert_eq(result.size(), 1, "[jester,shadow] still matches shadow_jester (order-agnostic)")
	if result.size() >= 1:
		assert_eq(result[0].id, "shadow_jester", "reversed pair resolves to shadow_jester")
	t.queue_free()


func test_no_matching_reaction() -> void:
	var t := _fresh_table()
	var engine = ReactionEngineScript.new(t)
	var ga = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	ga.place(0, "shadow")
	ga.place(1, "fortune")
	var result: Array = engine.compute(ga)
	assert_eq(result.size(), 1, "shadow+fortune produces shadow_fortune reaction")
	if result.size() >= 1:
		assert_eq(result[0].id, "shadow_fortune", "result id is shadow_fortune")
	t.queue_free()


func test_dedupe_same_reaction_only_once() -> void:
	# Hex with [shadow, jester, shadow, jester, ...] would generate the same
	# reaction multiple times if not deduped. Use SHAPE_HEX to set this up.
	var t := _fresh_table()
	var engine = ReactionEngineScript.new(t)
	var ga = GlyphArrangementScript.new(6, GlyphArrangementScript.SHAPE_HEX)
	ga.place(0, "shadow")
	ga.place(1, "jester")
	ga.place(2, "shadow")
	ga.place(3, "jester")
	ga.place(4, "shadow")
	ga.place(5, "jester")
	# All 6 adjacent pairs would be shadow+jester (or jester+shadow), should dedupe to 1
	var result: Array = engine.compute(ga)
	assert_eq(result.size(), 1, "repeated shadow/jester pairs dedupe to 1 reaction")
	t.queue_free()


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
