extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")
const EncounterChainStateScript = preload("res://scripts/world/encounter_chain_state.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")

const PACK_PATH := "res://data/encounters/chain_reflection_step1-N.json"
const EXPECTED_IDS := [
	"enc_reflection_drill_mirror_step",
	"enc_reflection_drill_noble_salon",
	"enc_reflection_confess",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_chain_reflection_full.gd --")
	test_reflection_step_pack_file_exists()
	test_reflection_step_pack_loads_through_encounter_pool()
	test_reflection_drill_success_advances_subchain()
	await test_reflection_final_choices_write_ending()
	return {"passed": _passed, "failed": _failed}


func test_reflection_step_pack_file_exists() -> void:
	assert_true(FileAccess.file_exists(PACK_PATH), "T11.B pack file exists at planned path")


func test_reflection_step_pack_loads_through_encounter_pool() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	for encounter_id in EXPECTED_IDS:
		assert_true(pool.encounter_by_id(encounter_id) != null, "reflection chain pool loads %s" % encounter_id)


func test_reflection_drill_success_advances_subchain() -> void:
	var gs = _state()
	gs.ap = 12
	_set_chain_step(gs, "reflection_chain", 2)
	var result: Dictionary = DrillRunnerScript.new().resolve_drill(gs, "mirror_step", {
		"satisfied_rule_ids": ["match_stride", "no_eye_contact", "leave_no_name"],
	})
	assert_true(bool(result.get("ok", false)), "mirror_step drill resolves")
	assert_eq(str(result.get("outcome", "")), "perfect", "mirror_step perfect outcome counts as reflection subchain success")
	assert_eq(str(result.get("chain_id", "")), "reflection_chain", "drill result reports reflection chain id")
	assert_eq(int(result.get("chain_step", 0)), 3, "mirror_step drill advances reflection chain to step 3")
	var chain = gs.encounter_chains.get("reflection_chain", null)
	assert_true(chain != null, "reflection chain state exists after drill")
	if chain != null:
		assert_eq(int(chain.get("current_step")), 3, "reflection chain current_step is 3 after drill success")


func test_reflection_final_choices_write_ending() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	var encounter = pool.encounter_by_id("enc_reflection_confess")
	if encounter == null:
		assert_true(false, "enc_reflection_confess exists for ending test")
		return
	var ids := _choice_ids(encounter)
	for choice_id in ["merge", "refuse", "sink"]:
		assert_true(choice_id in ids, "reflection ending exposes %s choice" % choice_id)
	var gs = _state()
	gs.day = 11
	gs.ap = 12
	gs.current_district = "misty_port"
	gs.time_of_day = "night"
	_set_chain_step(gs, "reflection_chain", 4)
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	runner.start(encounter, gs)
	await Engine.get_main_loop().process_frame
	var result: Dictionary = runner.resolve_choice("sink")
	assert_true(bool(result.get("ok", false)), "reflection sink ending resolves")
	var flags: Variant = gs.get("story_flags")
	assert_true(flags is Dictionary, "GameState exposes story_flags for reflection ending")
	if flags is Dictionary:
		assert_eq(str((flags as Dictionary).get("reflection_ending", "")), "sink", "reflection ending records sink")
	var chain = gs.encounter_chains.get("reflection_chain", null)
	if chain != null:
		assert_eq(int(chain.get("current_step")), 5, "reflection ending advances chain past confession step")
	runner.queue_free()


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _set_chain_step(gs, chain_id: String, step: int) -> void:
	var chain = EncounterChainStateScript.new()
	chain.chain_id = chain_id
	chain.current_step = step
	gs.encounter_chains[chain_id] = chain


func _choice_ids(encounter) -> Array:
	var payload = encounter.get("scene_payload")
	var result: Array = []
	if payload is Dictionary:
		var choices: Variant = (payload as Dictionary).get("choices", [])
		if choices is Array:
			for choice in choices:
				if choice is Dictionary:
					result.append(str((choice as Dictionary).get("id", "")))
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
