extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")
const EncounterChainStateScript = preload("res://scripts/world/encounter_chain_state.gd")

const PACK_PATH := "res://data/encounters/chain_widow_child_step2-5.json"
const EXPECTED_IDS := [
	"enc_widow_child_calls_dad",
	"enc_widow_pollution_50",
	"enc_widow_pollution_80",
	"enc_widow_truth_reveal",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_chain_widow_full.gd --")
	test_widow_step_pack_file_exists()
	test_widow_step_pack_loads_through_encounter_pool()
	await test_widow_pollution_gate_and_variant_text()
	await test_widow_final_branch_writes_story_flag()
	return {"passed": _passed, "failed": _failed}


func test_widow_step_pack_file_exists() -> void:
	assert_true(FileAccess.file_exists(PACK_PATH), "T11.A pack file exists at planned path")


func test_widow_step_pack_loads_through_encounter_pool() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	for encounter_id in EXPECTED_IDS:
		assert_true(pool.encounter_by_id(encounter_id) != null, "widow chain pool loads %s" % encounter_id)


func test_widow_pollution_gate_and_variant_text() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	var encounter = pool.encounter_by_id("enc_widow_child_calls_dad")
	if encounter == null:
		assert_true(false, "enc_widow_child_calls_dad exists for pollution gate test")
		return
	var gs = _state()
	gs.day = 5
	gs.ap = 12
	gs.current_district = "shadow_alley"
	gs.time_of_day = "night"
	_set_chain_step(gs, "widow_child_chain", 2)
	gs.pollution = 29
	gs.pollution_stage = 0
	var ctx := {"district_id": "shadow_alley", "time_of_day": "night", "game_state": gs}
	assert_eq(_ids(pool.filter_candidates([encounter], ctx)), [], "widow step 2 stays hidden below pollution 30")
	gs.pollution = 30
	gs.pollution_stage = 1
	assert_eq(_ids(pool.filter_candidates([encounter], ctx)), ["enc_widow_child_calls_dad"], "widow step 2 appears at pollution 30")

	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	var stage_1_text := str(runner.render_text(encounter, gs))
	gs.pollution = 90
	gs.pollution_stage = 3
	var stage_3_text := str(runner.render_text(encounter, gs))
	assert_true(stage_1_text != stage_3_text, "widow child text changes at high pollution stage")
	assert_true(_has_cjk(stage_3_text), "widow high-pollution variant remains Chinese player-facing text")
	runner.queue_free()


func test_widow_final_branch_writes_story_flag() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	var encounter = pool.encounter_by_id("enc_widow_truth_reveal")
	if encounter == null:
		assert_true(false, "enc_widow_truth_reveal exists for ending branch test")
		return
	var gs = _state()
	gs.day = 9
	gs.ap = 12
	gs.current_district = "shadow_alley"
	gs.time_of_day = "night"
	gs.sequence = 8
	gs.pollution = 55
	gs.pollution_stage = 2
	_set_chain_step(gs, "widow_child_chain", 5)
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	runner.start(encounter, gs)
	await Engine.get_main_loop().process_frame
	var result: Dictionary = runner.resolve_choice("accept_shadow")
	assert_true(bool(result.get("ok", false)), "widow ending choice resolves")
	var flags: Variant = gs.get("story_flags")
	assert_true(flags is Dictionary, "GameState exposes story_flags for R27 endings")
	if flags is Dictionary:
		assert_eq(str((flags as Dictionary).get("widow_child_ending", "")), "polluted_family", "widow ending branch records polluted_family")
	var chain = gs.encounter_chains.get("widow_child_chain", null)
	assert_true(chain != null, "widow chain state remains available after ending")
	if chain != null:
		assert_eq(int(chain.get("current_step")), 6, "widow ending advances chain past step 5")
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


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


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
