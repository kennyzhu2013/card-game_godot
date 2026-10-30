extends RefCounted

const SymbolLibraryScript = preload("res://scripts/ritual/symbol_library.gd")
const ReactionTableScript = preload("res://scripts/ritual/reaction_table.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_forge_data_expansion.gd --")
	test_symbol_library_loads_4_new_symbols()
	test_reaction_table_finds_shadow_arrow()
	test_reaction_table_finds_water_touch()
	return {"passed": _passed, "failed": _failed}


func test_symbol_library_loads_4_new_symbols() -> void:
	var lib = SymbolLibraryScript.new()
	lib.clear()
	lib.load_from_file("res://data/ritual/fool_symbols.json")
	for symbol_id in ["arrow", "touch", "flame", "water"]:
		assert_true(lib.get_by_id(symbol_id) != null, "symbol '%s' loads" % symbol_id)
	lib.queue_free()


func test_reaction_table_finds_shadow_arrow() -> void:
	var table = _fresh_reaction_table()
	var reaction = table.find_by_symbols(["shadow", "arrow"])
	assert_true(reaction != null, "shadow + arrow returns a reaction")
	if reaction != null:
		assert_eq(reaction.id, "shadow_arrow", "shadow + arrow reaction id")
	table.queue_free()


func test_reaction_table_finds_water_touch() -> void:
	var table = _fresh_reaction_table()
	var reaction = table.find_by_symbols(["water", "touch"])
	assert_true(reaction != null, "water + touch returns a reaction")
	if reaction != null:
		assert_eq(reaction.id, "water_touch", "water + touch reaction id")
	table.queue_free()


func _fresh_reaction_table() -> Node:
	var table = ReactionTableScript.new()
	table.clear()
	table.load_from_file("res://data/ritual/fool_reactions.json")
	return table


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
