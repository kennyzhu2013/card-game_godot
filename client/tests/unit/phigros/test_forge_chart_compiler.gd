extends RefCounted

const GlyphArrangementScript = preload("res://scripts/ritual/glyph_arrangement.gd")
const ChemicalReactionScript = preload("res://scripts/ritual/chemical_reaction.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_forge_chart_compiler.gd --")
	test_shadow_arrangement_uses_whisper_template()
	test_3_slot_arrangement_duration_30000ms()
	test_reactions_add_5_density_per_reaction()
	test_no_source_returns_empty_params()
	test_water_arrangement_uses_breath_template()
	return {"passed": _passed, "failed": _failed}


func test_shadow_arrangement_uses_whisper_template() -> void:
	var result := _compile(["shadow", "arrow", ""], [])
	assert_eq(result.get("template_id", ""), "WHISPER", "shadow arrangement uses WHISPER")
	assert_eq(result.get("momentum", -1), 0, "momentum fixed at 0")
	assert_eq(result.get("params", {}).get("lane", -1), 1, "params lane defaults to 1")


func test_3_slot_arrangement_duration_30000ms() -> void:
	var result := _compile(["shadow", "arrow", ""], [])
	assert_eq(result.get("duration_ms", 0), 30000, "3-slot arrangement duration")
	assert_eq(result.get("params", {}).get("start_ms", -1), 2000, "params start_ms with lead-in")
	assert_eq(result.get("params", {}).get("interval_ms", 0), 1000, "30 notes over 30000ms")


func test_reactions_add_5_density_per_reaction() -> void:
	var reactions := [ChemicalReactionScript.new(), ChemicalReactionScript.new()]
	var result := _compile(["shadow", "arrow", ""], reactions)
	assert_eq(result.get("total_notes", 0), 42, "two reactions add 12 notes (6 each)")
	assert_eq(result.get("params", {}).get("note_count", 0), 42, "params note_count mirrors total_notes")
	assert_eq(result.get("bpm", 0), 98, "two reactions add 8 bpm (4 each)")


func test_no_source_returns_empty_params() -> void:
	var result := _compile(["", "", ""], [])
	assert_eq(result.get("template_id", "x"), "", "no source template_id")
	assert_eq(result.get("duration_ms", -1), 0, "no source duration")
	assert_eq(result.get("total_notes", -1), 0, "no source total_notes")
	assert_eq(result.get("bpm", -1), 0, "no source bpm")
	assert_eq(result.get("params", {"x": 1}), {}, "no source params")
	assert_eq(result.get("momentum", -1), 0, "no source momentum")


func test_water_arrangement_uses_breath_template() -> void:
	var result := _compile(["water", "touch", ""], [])
	assert_eq(result.get("template_id", ""), "BREATH", "water arrangement uses BREATH")
	assert_eq(result.get("params", {}).get("note_count", 0), 30, "water params note_count")


func _compile(symbol_ids: Array, reactions: Array) -> Dictionary:
	var compiler = load("res://scripts/ritual/forge_chart_compiler.gd")
	if compiler == null:
		assert_true(false, "ForgeChartCompiler script loads")
		return {}
	var arrangement = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	for i in range(symbol_ids.size()):
		arrangement.place(i, String(symbol_ids[i]))
	return compiler.compile(arrangement, reactions)


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
