extends RefCounted

const GlyphWorkshopScript = preload("res://scripts/ritual/glyph_workshop.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_forge_ap_entry.gd --")
	test_glyph_workshop_spends_ap_by_shape_before_forge_scene()
	test_glyph_workshop_blocks_confirm_when_forge_ap_is_short()
	return {"passed": _passed, "failed": _failed}


func test_glyph_workshop_spends_ap_by_shape_before_forge_scene() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 5
	GameState.pending_forge_arrangement.clear()
	var workshop := GlyphWorkshopScript.new()
	workshop.set_arrangement_shape(4)
	workshop.call("_on_confirm_pressed")
	assert_eq(int(GameState.ap), 2, "L forge spends 3 AP before changing scene")
	assert_eq(int(GameState.pending_forge_arrangement.get("capacity", 0)), 4, "forge arrangement is still stored after AP spend")
	workshop.queue_free()
	GameState.from_dict(previous)


func test_glyph_workshop_blocks_confirm_when_forge_ap_is_short() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 1
	GameState.pending_forge_arrangement.clear()
	var workshop := GlyphWorkshopScript.new()
	workshop.set_arrangement_shape(3)
	workshop.call("_on_confirm_pressed")
	assert_eq(int(GameState.ap), 1, "failed forge confirm does not spend AP")
	assert_true(GameState.pending_forge_arrangement.is_empty(), "failed forge confirm does not store pending arrangement")
	workshop.queue_free()
	GameState.from_dict(previous)


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
