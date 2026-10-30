extends RefCounted

const SymbolScript = preload("res://scripts/ritual/symbol.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_symbol.gd --")
	test_constructor_populates_fields()
	test_has_aspect_returns_true_when_present()
	test_has_aspect_returns_false_when_absent()
	test_from_dict_populates_fields()
	test_to_dict_round_trip()
	return {"passed": _passed, "failed": _failed}


func test_constructor_populates_fields() -> void:
	var sym = SymbolScript.new("shadow", "影", ["影", "恐", "失"], "fool")
	assert_eq(sym.id, "shadow", "Symbol.id set from constructor")
	assert_eq(sym.display_name, "影", "Symbol.display_name set from constructor")
	assert_eq(sym.pathway, "fool", "Symbol.pathway set from constructor")
	assert_eq(sym.aspects.size(), 3, "Symbol.aspects has 3 entries")
	assert_eq(sym.aspects[0], "影", "Symbol.aspects[0] == 影")
	assert_eq(sym.aspects[1], "恐", "Symbol.aspects[1] == 恐")
	assert_eq(sym.aspects[2], "失", "Symbol.aspects[2] == 失")


func test_has_aspect_returns_true_when_present() -> void:
	var sym = SymbolScript.new("shadow", "影", ["影", "恐", "失"], "fool")
	assert_true(sym.has_aspect("影"), "has_aspect 影 returns true")
	assert_true(sym.has_aspect("恐"), "has_aspect 恐 returns true")
	assert_true(sym.has_aspect("失"), "has_aspect 失 returns true")


func test_has_aspect_returns_false_when_absent() -> void:
	var sym = SymbolScript.new("shadow", "影", ["影", "恐", "失"], "fool")
	assert_true(not sym.has_aspect("光"), "has_aspect 光 returns false (not present)")
	assert_true(not sym.has_aspect(""), "has_aspect empty string returns false")


func test_from_dict_populates_fields() -> void:
	var data := {
		"id": "thread",
		"display_name": "线",
		"aspects": ["牵", "缘", "誓"],
		"pathway": "fool",
	}
	var sym = SymbolScript.from_dict(data)
	assert_eq(sym.id, "thread", "from_dict sets id")
	assert_eq(sym.display_name, "线", "from_dict sets display_name")
	assert_eq(sym.pathway, "fool", "from_dict sets pathway")
	assert_eq(sym.aspects.size(), 3, "from_dict sets aspects size")
	assert_true(sym.has_aspect("缘"), "from_dict-built symbol has 缘")


func test_to_dict_round_trip() -> void:
	var sym = SymbolScript.new("jester", "愚", ["失", "转", "笑"], "fool")
	var dict := sym.to_dict()
	assert_eq(String(dict.get("id", "")), "jester", "to_dict id")
	assert_eq(String(dict.get("display_name", "")), "愚", "to_dict display_name")
	assert_eq(String(dict.get("pathway", "")), "fool", "to_dict pathway")
	var aspects: Array = dict.get("aspects", [])
	assert_eq(aspects.size(), 3, "to_dict aspects size")
	# Round-trip via from_dict
	var rebuilt = SymbolScript.from_dict(dict)
	assert_eq(rebuilt.id, sym.id, "round-trip id")
	assert_eq(rebuilt.display_name, sym.display_name, "round-trip display_name")
	assert_eq(rebuilt.pathway, sym.pathway, "round-trip pathway")
	assert_true(rebuilt.has_aspect("失"), "round-trip has_aspect 失")
	assert_true(rebuilt.has_aspect("转"), "round-trip has_aspect 转")
	assert_true(rebuilt.has_aspect("笑"), "round-trip has_aspect 笑")


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
