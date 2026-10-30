extends RefCounted

const ForgeSceneScript = preload("res://scripts/ritual/forge_scene.gd")
const GlyphArrangementScript = preload("res://scripts/ritual/glyph_arrangement.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "forge ai gm text"


func run() -> Dictionary:
	print("\n-- test_ai_gm_forge.gd --")
	test_forge_resolve_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_forge_resolve_builds_valid_prompt_context() -> void:
	var scene = ForgeSceneScript.new()
	assert_true(scene.has_method("set_ai_gm_service"), "ForgeScene exposes set_ai_gm_service()")
	assert_true(scene.has_method("request_forge_resolve_ai_gm"), "ForgeScene exposes request_forge_resolve_ai_gm()")
	if not scene.has_method("set_ai_gm_service") or not scene.has_method("request_forge_resolve_ai_gm"):
		scene.free()
		return

	var fake_service := FakeAIGMService.new()
	scene.call("set_ai_gm_service", fake_service)
	scene.arrangement = _arrangement(["shadow", "arrow", "radiance"])
	scene.target_reaction_id = "shadow_arrow"
	scene.set_game_state(_game_state())

	var text: String = str(scene.call("request_forge_resolve_ai_gm", {
		"quality": {"id": 4, "name": "Fine"},
		"perfect_rate": 0.92,
		"dao_choices": ["steady", "hold"],
		"brand_dropped": true,
	}))

	assert_eq(text, "forge ai gm text", "forge_resolve returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "forge_resolve calls AI GM once")
	if fake_service.calls.is_empty():
		scene.free()
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "forge_resolve", "FORGE_RESULT_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(_string_array(payload.get("glyph_arrangement", [])), ["shadow", "arrow", "radiance"], "forge_resolve payload includes glyph_arrangement")
	assert_eq(str(payload.get("primary_source", "")), "shadow", "forge_resolve payload includes primary_source")
	assert_eq(str(payload.get("reaction_id", "")), "shadow_arrow", "forge_resolve payload includes reaction_id")
	assert_almost_eq(float(payload.get("perfect_rate", 0.0)), 0.92, 0.0001, "forge_resolve payload includes perfect_rate")
	assert_eq(int(payload.get("quality", 0)), 4, "forge_resolve payload includes quality id")
	assert_eq(_string_array(payload.get("dao_choices", [])), ["steady", "hold"], "forge_resolve payload includes dao_choices")
	assert_true(bool(payload.get("brand_dropped", false)), "forge_resolve payload includes brand_dropped")
	scene.free()


func _arrangement(symbol_ids: Array) -> GlyphArrangement:
	var arrangement = GlyphArrangementScript.new(symbol_ids.size(), GlyphArrangementScript.SHAPE_LINE)
	for i in range(symbol_ids.size()):
		arrangement.place(i, str(symbol_ids[i]))
	return arrangement


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 42
	gs.pollution_stage = 1
	gs.cycle = 2
	gs.day = 5
	gs.time_of_day = "evening"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 8, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), 42, "%s player_state.pollution" % expected_scene)
	assert_eq(str(ctx.player_state.get("time_of_day", "")), "evening", "%s player_state.time_of_day" % expected_scene)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


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


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected %.4f, got %.4f" % [message, expected, actual])
