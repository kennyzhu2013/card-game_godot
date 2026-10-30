extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const EncounterScript = preload("res://scripts/world/encounter.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "encounter resolve narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_encounter_resolve.gd --")
	await test_mystery_seed_encounter_resolve_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_mystery_seed_encounter_resolve_builds_valid_prompt_context() -> void:
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	assert_true(runner.has_method("set_ai_gm_service"), "EncounterRunner exposes set_ai_gm_service()")
	assert_true(runner.has_method("request_encounter_resolve_ai_gm"), "EncounterRunner exposes request_encounter_resolve_ai_gm()")
	if not runner.has_method("set_ai_gm_service") or not runner.has_method("request_encounter_resolve_ai_gm"):
		runner.queue_free()
		return

	var fake_service := FakeAIGMService.new()
	var gs = _game_state()
	runner.call("set_ai_gm_service", fake_service)
	runner.start(_encounter(), gs)
	await Engine.get_main_loop().process_frame
	var result: Dictionary = runner.resolve_choice("approach")
	await Engine.get_main_loop().process_frame

	assert_true(bool(result.get("ok", false)), "resolve_choice succeeds for mystery_seed")
	assert_eq(str(result.get("ai_gm_text", "")), "encounter resolve narration", "encounter resolve returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "encounter_resolve calls AI GM once for mystery_seed")
	if fake_service.calls.is_empty():
		runner.queue_free()
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "encounter_resolve", "ENCOUNTER_RESOLVE_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("encounter_id", "")), "enc_ai_gm_widow_probe", "encounter_resolve payload encounter_id")
	assert_eq(str(payload.get("chosen_choice_id", "")), "approach", "encounter_resolve payload chosen_choice_id")
	assert_eq(str(payload.get("tone", "")), "haunting", "encounter_resolve payload tone")
	assert_eq(int(payload.get("current_pollution_stage", -1)), 2, "encounter_resolve payload pollution stage")
	assert_eq(int(payload.get("chain_step", -1)), 2, "encounter_resolve payload chain_step")
	runner.queue_free()


func _encounter():
	return EncounterScript.new().from_dict({
		"id": "enc_ai_gm_widow_probe",
		"encounter_type": "mystery_seed",
		"display_name": "AI GM Widow Probe",
		"districts": ["shadow_alley"],
		"time_of_day": ["night"],
		"chain_id": "widow_child_chain",
		"chain_step": 2,
		"scene_payload": {
			"text": "The widow waits.",
			"choices": [
				{"id": "approach", "label": "Approach", "outcome": {"ai_gm": {"scene": "encounter_resolve", "tone": "haunting"}}},
			],
		},
	})


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 52
	gs.pollution_stage = 2
	gs.cycle = 1
	gs.day = 9
	gs.time_of_day = "night"
	gs.ap = 12
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)


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
