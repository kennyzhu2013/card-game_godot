extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")
const EncounterChainStateScript = preload("res://scripts/world/encounter_chain_state.gd")

const PACK_PATH := "res://data/encounters/chain_pendulum_step0-N.json"
const NAME_JUDGMENT_PATH := "res://scripts/ritual/name_judgment.gd"
const EXPECTED_IDS := [
	"enc_pendulum_dialog_2",
	"enc_pendulum_name_judgment",
	"enc_pendulum_recluse_lesson",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_chain_pendulum_full.gd --")
	test_pendulum_step_pack_file_exists()
	test_pendulum_step_pack_loads_through_encounter_pool()
	test_name_judgment_script_exists_and_gates_on_chain_step()
	test_name_judgment_unlocks_recluse_promotion_gate()
	return {"passed": _passed, "failed": _failed}


func test_pendulum_step_pack_file_exists() -> void:
	assert_true(FileAccess.file_exists(PACK_PATH), "T11.D pack file exists at planned path")


func test_pendulum_step_pack_loads_through_encounter_pool() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	for encounter_id in EXPECTED_IDS:
		assert_true(pool.encounter_by_id(encounter_id) != null, "pendulum chain pool loads %s" % encounter_id)


func test_name_judgment_script_exists_and_gates_on_chain_step() -> void:
	var service = _name_judgment()
	if service == null:
		return
	assert_true(service.has_method("can_start"), "NameJudgment exposes can_start(game_state)")
	var gs = _promotable_8_state()
	assert_true(not bool(service.call("can_start", gs)), "name judgment blocks before pendulum chain reaches judgment step")
	_set_chain_step(gs, "pendulum_chain", 3)
	assert_true(bool(service.call("can_start", gs)), "name judgment opens when pendulum chain reaches step 3")


func test_name_judgment_unlocks_recluse_promotion_gate() -> void:
	var service = _name_judgment()
	if service == null:
		return
	var gs = _promotable_8_state()
	_set_chain_step(gs, "pendulum_chain", 3)
	var result: Dictionary = service.call("resolve_judgment", gs, "speak_true_name")
	assert_true(bool(result.get("ok", false)), "name judgment resolves true-name ritual")
	var flags: Variant = gs.get("story_flags")
	assert_true(flags is Dictionary, "GameState exposes story_flags for pendulum ending")
	if flags is Dictionary:
		assert_eq(str((flags as Dictionary).get("pendulum_ending", "")), "true_name_judged", "pendulum ending records true_name_judged")
	assert_true(_completed_nodes(gs).has("node_4b_promotion_87"), "name judgment records node_4b_promotion_87 for 8->7 gate")
	assert_true(bool(gs.get_meta("promotion_prompt_pending", false)), "name judgment raises promotion prompt when R07 gate is satisfied")
	assert_eq(str(gs.get_meta("promotion_prompt_gate_id", "")), "fool_8_to_7", "name judgment points prompt at fool_8_to_7 gate")


func _name_judgment():
	assert_true(FileAccess.file_exists(NAME_JUDGMENT_PATH), "name_judgment.gd exists at planned path")
	if not FileAccess.file_exists(NAME_JUDGMENT_PATH):
		return null
	var script = load(NAME_JUDGMENT_PATH)
	assert_true(script != null and script.can_instantiate(), "NameJudgment script loads")
	if script == null or not script.can_instantiate():
		return null
	return script.new()


func _promotable_8_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.sequence_exp = 250
	gs.pollution = 20
	gs.known_reactions.clear()
	for i in range(18):
		gs.known_reactions.append("reaction_%d" % i)
	gs.learned_rules.clear()
	gs.active_contract.clear()
	for rule in ["rule_a", "rule_b", "rule_c"]:
		gs.learned_rules.append(rule)
		gs.active_contract.append(rule)
	if gs.has_method("record_paper_blade_kill"):
		gs.record_paper_blade_kill()
	return gs


func _set_chain_step(gs, chain_id: String, step: int) -> void:
	var chain = EncounterChainStateScript.new()
	chain.chain_id = chain_id
	chain.current_step = step
	gs.encounter_chains[chain_id] = chain


func _completed_nodes(gs) -> Array:
	var daodian: Variant = gs.get("daodian")
	if daodian is Dictionary:
		var nodes: Variant = (daodian as Dictionary).get("completed_main_story_nodes", [])
		if nodes is Array:
			return nodes
	return []


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
