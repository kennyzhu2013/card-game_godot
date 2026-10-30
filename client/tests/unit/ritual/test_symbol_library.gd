extends RefCounted

const SymbolLibraryScript = preload("res://scripts/ritual/symbol_library.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_symbol_library.gd --")
	test_load_from_file_loads_at_least_eight_fool_symbols()
	test_get_by_id_returns_shadow()
	test_get_by_id_unknown_returns_null()
	test_list_for_pathway_fool_includes_eight_core_symbols()
	test_list_for_pathway_unknown_returns_zero()
	test_clear_resets_library()
	return {"passed": _passed, "failed": _failed}


const CORE_FOOL_SYMBOLS := ["shadow", "thread", "jester", "mirror", "inquiry", "name", "fortune", "face"]


func _fresh_library() -> Node:
	var lib = SymbolLibraryScript.new()
	lib.clear()
	var loaded := lib.load_from_file("res://data/ritual/fool_symbols.json")
	assert_true(loaded >= 8, "load_from_file returns >= 8 for fool_symbols.json")
	return lib


func test_load_from_file_loads_at_least_eight_fool_symbols() -> void:
	var lib := _fresh_library()
	assert_true(lib.count() >= 8, "count() >= 8 after loading fool_symbols.json")
	for sym_id in CORE_FOOL_SYMBOLS:
		assert_true(lib.get_by_id(sym_id) != null, "core symbol '%s' loaded" % sym_id)
	lib.queue_free()


func test_get_by_id_returns_shadow() -> void:
	var lib := _fresh_library()
	var sym = lib.get_by_id("shadow")
	assert_true(sym != null, "get_by_id('shadow') returns non-null")
	if sym != null:
		assert_eq(sym.id, "shadow", "shadow.id == 'shadow'")
		assert_eq(sym.display_name, "影", "shadow.display_name == '影'")
		assert_eq(sym.pathway, "fool", "shadow.pathway == 'fool'")
	lib.queue_free()


func test_get_by_id_unknown_returns_null() -> void:
	var lib := _fresh_library()
	var sym = lib.get_by_id("nonexistent")
	assert_true(sym == null, "get_by_id('nonexistent') returns null")
	lib.queue_free()


func test_list_for_pathway_fool_includes_eight_core_symbols() -> void:
	var lib := _fresh_library()
	var list: Array = lib.list_for_pathway("fool")
	assert_true(list.size() >= 8, "list_for_pathway('fool') returns >= 8 symbols")
	var ids: Array = []
	for sym in list:
		ids.append(sym.id)
	for sym_id in CORE_FOOL_SYMBOLS:
		assert_true(ids.has(sym_id), "list_for_pathway('fool') includes core symbol '%s'" % sym_id)
	lib.queue_free()


func test_list_for_pathway_unknown_returns_zero() -> void:
	var lib := _fresh_library()
	var list: Array = lib.list_for_pathway("nonexistent")
	assert_eq(list.size(), 0, "list_for_pathway('nonexistent') returns 0")
	lib.queue_free()


func test_clear_resets_library() -> void:
	var lib := _fresh_library()
	lib.clear()
	assert_eq(lib.count(), 0, "count() == 0 after clear()")
	var sym = lib.get_by_id("shadow")
	assert_true(sym == null, "get_by_id after clear() returns null")
	lib.queue_free()


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
