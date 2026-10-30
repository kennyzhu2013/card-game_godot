extends RefCounted

const ReactionTableScript = preload("res://scripts/ritual/reaction_table.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_reaction_table.gd --")
	test_load_from_file_loads_at_least_twelve_reactions()
	test_find_by_symbols_returns_shadow_jester()
	test_find_by_symbols_reversed_returns_same()
	test_find_by_symbols_missing_returns_null()
	test_all_reactions_includes_core_entries()
	test_clear_resets_table()
	return {"passed": _passed, "failed": _failed}


const CORE_FOOL_REACTIONS := [
	"shadow_jester",
	"jester_name",
	"shadow_name",
	"inquiry_mirror",
	"fortune_thread",
	"mirror_face",
	"inquiry_fortune",
	"shadow_thread",
	"jester_face",
	"inquiry_name",
	"mirror_shadow",
	"jester_fortune",
]


func _fresh_table() -> Node:
	var t = ReactionTableScript.new()
	t.clear()
	var loaded := t.load_from_file("res://data/ritual/fool_reactions.json")
	assert_true(loaded >= 12, "load_from_file returns >= 12 for fool_reactions.json")
	return t


func test_load_from_file_loads_at_least_twelve_reactions() -> void:
	var t := _fresh_table()
	assert_true(t.count() >= 12, "count() >= 12 after loading fool_reactions.json")
	t.queue_free()


func test_find_by_symbols_returns_shadow_jester() -> void:
	var t := _fresh_table()
	var rx = t.find_by_symbols(["shadow", "jester"])
	assert_true(rx != null, "find_by_symbols(['shadow','jester']) returns non-null")
	if rx != null:
		assert_eq(rx.id, "shadow_jester", "rx.id == 'shadow_jester'")
		assert_eq(rx.display_name, "影代身位", "rx.display_name == '影代身位'")
		assert_eq(rx.pollution_delta, 3, "rx.pollution_delta == 3")
	t.queue_free()


func test_find_by_symbols_reversed_returns_same() -> void:
	var t := _fresh_table()
	var rx = t.find_by_symbols(["jester", "shadow"])
	assert_true(rx != null, "find_by_symbols(['jester','shadow']) reversed returns non-null (order-agnostic)")
	if rx != null:
		assert_eq(rx.id, "shadow_jester", "reversed rx.id == 'shadow_jester'")
	t.queue_free()


func test_find_by_symbols_missing_returns_null() -> void:
	var t := _fresh_table()
	var rx = t.find_by_symbols(["shadow", "nonexistent"])
	assert_true(rx == null, "find_by_symbols(['shadow','nonexistent']) returns null")
	t.queue_free()


func test_all_reactions_includes_core_entries() -> void:
	var t := _fresh_table()
	var all_rx: Array = t.all_reactions()
	assert_true(all_rx.size() >= 12, "all_reactions() returns >= 12 entries")
	var ids: Array = []
	for rx in all_rx:
		ids.append(rx.id)
	for rx_id in CORE_FOOL_REACTIONS:
		assert_true(ids.has(rx_id), "all_reactions() includes core reaction '%s'" % rx_id)
	t.queue_free()


func test_clear_resets_table() -> void:
	var t := _fresh_table()
	t.clear()
	assert_eq(t.count(), 0, "count() == 0 after clear()")
	var rx = t.find_by_symbols(["shadow", "jester"])
	assert_true(rx == null, "find_by_symbols after clear() returns null")
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
