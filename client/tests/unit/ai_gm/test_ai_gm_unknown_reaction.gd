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
		return "{\"reaction\":\"unstable\",\"hint\":\"burn\"}"


func run() -> Dictionary:
	print("\n-- test_ai_gm_unknown_reaction.gd --")
	test_unknown_reaction_builds_json_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_unknown_reaction_builds_json_prompt_context() -> void:
	var scene = ForgeSceneScript.new()
	assert_true(scene.has_method("set_ai_gm_service"), "ForgeScene exposes set_ai_gm_service() for unknown reaction")
	assert_true(scene.has_method("request_unknown_reaction_ai_gm"), "ForgeScene exposes request_unknown_reaction_ai_gm()")
	if not scene.has_method("set_ai_gm_service") or not scene.has_method("request_unknown_reaction_ai_gm"):
		scene.free()
		return

	var fake_service := FakeAIGMService.new()
	scene.call("set_ai_gm_service", fake_service)
	scene.arrangement = _arrangement(["shadow", "blood", "touch"])
	scene.set_game_state(_game_state())

	var text: String = str(scene.call("request_unknown_reaction_ai_gm", {
		"base_damage": 12,
		"base_status_hint": "burn",
	}))

	assert_eq(text, "{\"reaction\":\"unstable\",\"hint\":\"burn\"}", "unknown_reaction returns AI GM JSON text")
	assert_eq(fake_service.calls.size(), 1, "unknown_reaction calls AI GM once")
	if fake_service.calls.is_empty():
		scene.free()
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "unknown_reaction", "UNKNOWN_REACTION_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(_string_array(payload.get("glyph_arrangement", [])), ["shadow", "blood", "touch"], "unknown_reaction payload includes glyph_arrangement")
	assert_eq(int(payload.get("base_damage", 0)), 12, "unknown_reaction payload includes base_damage")
	assert_eq(str(payload.get("base_status_hint", "")), "burn", "unknown_reaction payload includes base_status_hint")
	scene.free()


func _arrangement(symbol_ids: Array) -> GlyphArrangement:
	var arrangement = GlyphArrangementScript.new(symbol_ids.size(), GlyphArrangementScript.SHAPE_LINE)
	for i in range(symbol_ids.size()):
		arrangement.place(i, str(symbol_ids[i]))
	return arrangement


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 9
	gs.pollution = 11
	gs.pollution_stage = 0
	gs.cycle = 1
	gs.day = 2
	gs.time_of_day = "morning"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 9, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), 11, "%s player_state.pollution" % expected_scene)


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
