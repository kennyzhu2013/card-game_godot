extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")
const EncounterChainStateScript = preload("res://scripts/world/encounter_chain_state.gd")

const PACK_PATH := "res://data/encounters/chain_redhand_step1-3.json"
const EXPECTED_IDS := [
	"enc_red_hand_proof_2",
	"enc_red_hand_proof_3",
	"enc_red_hand_join",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_chain_redhand_full.gd --")
	test_redhand_step_pack_file_exists()
	test_redhand_step_pack_loads_through_encounter_pool()
	await test_redhand_proof_steps_progress_independently()
	await test_redhand_exposure_ending_sets_flag_and_awareness()
	return {"passed": _passed, "failed": _failed}


func test_redhand_step_pack_file_exists() -> void:
	assert_true(FileAccess.file_exists(PACK_PATH), "T11.C pack file exists at planned path")


func test_redhand_step_pack_loads_through_encounter_pool() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	for encounter_id in EXPECTED_IDS:
		assert_true(pool.encounter_by_id(encounter_id) != null, "red hand chain pool loads %s" % encounter_id)


func test_redhand_proof_steps_progress_independently() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	var proof_2 = pool.encounter_by_id("enc_red_hand_proof_2")
	var proof_3 = pool.encounter_by_id("enc_red_hand_proof_3")
	if proof_2 == null or proof_3 == null:
		assert_true(false, "red hand proof 2 and 3 data exist")
		return
	var gs = _state()
	gs.ap = 12
	gs.current_district = "steelworks"
	gs.time_of_day = "night"
	_set_chain_step(gs, "red_hand_chain", 2)
	var ctx := {"district_id": "steelworks", "time_of_day": "night", "game_state": gs}
	assert_eq(_ids(pool.filter_candidates([proof_2, proof_3], ctx)), ["enc_red_hand_proof_2"], "only red hand proof 2 appears at chain step 2")
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	runner.start(proof_2, gs)
	await Engine.get_main_loop().process_frame
	runner.resolve_choice("accept")
	await Engine.get_main_loop().process_frame
	assert_eq(_ids(pool.filter_candidates([proof_2, proof_3], ctx)), ["enc_red_hand_proof_3"], "red hand proof 3 appears after proof 2 resolves")
	runner.queue_free()


func test_redhand_exposure_ending_sets_flag_and_awareness() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	var encounter = pool.encounter_by_id("enc_red_hand_join")
	if encounter == null:
		assert_true(false, "enc_red_hand_join exists for ending test")
		return
	var ids := _choice_ids(encounter)
	for choice_id in ["join", "refuse", "expose"]:
		assert_true(choice_id in ids, "red hand ending exposes %s choice" % choice_id)
	var gs = _state()
	gs.ap = 12
	gs.church_awareness = 2
	gs.current_district = "steelworks"
	gs.time_of_day = "night"
	_set_chain_step(gs, "red_hand_chain", 4)
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	runner.start(encounter, gs)
	await Engine.get_main_loop().process_frame
	var result: Dictionary = runner.resolve_choice("expose")
	assert_true(bool(result.get("ok", false)), "red hand expose ending resolves")
	var flags: Variant = gs.get("story_flags")
	assert_true(flags is Dictionary, "GameState exposes story_flags for red hand ending")
	if flags is Dictionary:
		assert_eq(str((flags as Dictionary).get("redhand_ending", "")), "exposed", "red hand ending records exposed")
	assert_eq(int(gs.church_awareness), 14, "red hand expose ending applies church awareness +12")
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


func _ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(str(value.get("id")))
	return result


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
