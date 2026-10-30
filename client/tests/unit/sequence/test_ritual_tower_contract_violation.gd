extends RefCounted

const RUNNER_SCENE := "res://scenes/tower/tower_runner.tscn"
const TowerScript = preload("res://scripts/tower/tower.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_ritual_tower_contract_violation.gd --")
	await test_ritual_tower_contract_full_victory_completes_promotion()
	await test_ritual_tower_contract_partial_violation_triggers_fail()
	await test_ritual_tower_contract_broken_triggers_fail()
	await test_normal_tower_contract_violation_does_not_trigger_promotion_fail()
	return {"passed": _passed, "failed": _failed}


func test_ritual_tower_contract_full_victory_completes_promotion() -> void:
	var setup: Dictionary = _ritual_setup(3)
	var gs = setup.get("game_state", null)
	var tower = setup.get("tower", null)
	var pre_contract: Array = setup.get("pre_contract", [])
	if gs == null or tower == null:
		assert_true(false, "ritual setup prepares full victory path")
		return
	var runner = await _runner()
	if runner == null:
		return
	runner.open(tower, gs)
	assert_eq(int(runner.get_current_floor_index()), 3, "full ritual victory starts on final floor")
	runner.enter_current_floor()
	runner.handle_battle_result(_battle_result("full"))
	assert_eq(int(gs.sequence), 7, "full ritual victory promotes sequence 8->7")
	assert_eq(int(gs.pollution), 10, "full ritual victory does not add ritual fail pollution")
	assert_eq(Array(gs.active_contract), pre_contract, "full ritual victory restores pre-entry active_contract")
	assert_true(not gs.has_meta("ritual_pre_active_contract"), "full ritual victory clears ritual snapshot meta")
	assert_eq(str(runner.get_last_return_reason()), "completed", "full ritual victory returns completed")
	assert_eq(str(tower.resolution), "cleared", "full ritual victory clears ritual tower")
	_free_runner(runner)


func test_ritual_tower_contract_partial_violation_triggers_fail() -> void:
	var setup: Dictionary = _ritual_setup(1)
	var gs = setup.get("game_state", null)
	var tower = setup.get("tower", null)
	var pre_contract: Array = setup.get("pre_contract", [])
	if gs == null or tower == null:
		assert_true(false, "ritual setup prepares partial fail path")
		return
	var runner = await _runner()
	if runner == null:
		return
	runner.open(tower, gs)
	assert_eq(int(runner.get_current_floor_index()), 1, "partial ritual violation starts on a battle floor")
	runner.enter_current_floor()
	runner.handle_battle_result(_battle_result("partial", 2, 1))
	assert_eq(str(runner.get_last_return_reason()), "collapsed", "partial ritual violation returns collapsed")
	assert_eq(int(gs.pollution), 30, "partial ritual violation adds +20 pollution")
	assert_eq(int(gs.sequence), 8, "partial ritual violation does not change sequence")
	assert_eq(int(gs.promotion_cooldown_until_day), 12, "partial ritual violation sets 7 day cooldown")
	assert_eq(Array(gs.active_contract), pre_contract, "partial ritual violation restores pre-entry active_contract")
	assert_true(not gs.has_meta("ritual_pre_active_contract"), "partial ritual violation clears ritual snapshot meta")
	assert_eq(str(tower.resolution), "collapsed", "partial ritual violation collapses ritual tower")
	_free_runner(runner)


func test_ritual_tower_contract_broken_triggers_fail() -> void:
	var setup: Dictionary = _ritual_setup(1)
	var gs = setup.get("game_state", null)
	var tower = setup.get("tower", null)
	var pre_contract: Array = setup.get("pre_contract", [])
	if gs == null or tower == null:
		assert_true(false, "ritual setup prepares broken fail path")
		return
	var runner = await _runner()
	if runner == null:
		return
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.handle_battle_result(_battle_result("broken", 0, 3))
	assert_eq(str(runner.get_last_return_reason()), "collapsed", "broken ritual violation returns collapsed")
	assert_eq(int(gs.pollution), 30, "broken ritual violation adds +20 pollution")
	assert_eq(int(gs.sequence), 8, "broken ritual violation does not change sequence")
	assert_eq(int(gs.promotion_cooldown_until_day), 12, "broken ritual violation sets 7 day cooldown")
	assert_eq(Array(gs.active_contract), pre_contract, "broken ritual violation restores pre-entry active_contract")
	assert_true(not gs.has_meta("ritual_pre_active_contract"), "broken ritual violation clears ritual snapshot meta")
	assert_eq(str(tower.resolution), "collapsed", "broken ritual violation collapses ritual tower")
	_free_runner(runner)


func test_normal_tower_contract_violation_does_not_trigger_promotion_fail() -> void:
	var gs = _base_state()
	var tower = _normal_tower()
	var runner = await _runner()
	if runner == null:
		return
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.handle_battle_result(_battle_result("broken", 0, 3))
	assert_eq(str(runner.get_last_return_reason()), "completed", "normal tower still completes on victory")
	assert_eq(int(gs.sequence), 8, "normal tower does not promote sequence")
	assert_eq(int(gs.pollution), 10, "normal tower does not add ritual fail pollution")
	assert_eq(int(gs.promotion_cooldown_until_day), 0, "normal tower does not set ritual cooldown")
	assert_eq(str(tower.resolution), "cleared", "normal tower clears floor instead of collapsing")
	_free_runner(runner)


func _ritual_setup(progress_cleared_floors: int) -> Dictionary:
	var gs = _base_state()
	var pre_contract: Array = ["A", "B", "C"]
	_replace_string_array(gs.learned_rules, ["A", "B", "C", "D", "E"])
	_replace_string_array(gs.active_contract, pre_contract)
	gs.known_reactions.clear()
	for reaction_id in _reaction_ids(18):
		gs.known_reactions.append(reaction_id)
	gs.daodian["completed_main_story_nodes"] = ["node_4b_promotion_87"]
	gs.record_paper_blade_kill()
	var started: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	var tower = started.get("tower", null)
	if tower == null:
		return {"game_state": gs, "tower": null, "pre_contract": pre_contract}
	for i in range(mini(progress_cleared_floors, tower.floors.size())):
		var floor = tower.floors[i]
		floor.resolution = "cleared"
	return {"game_state": gs, "tower": tower, "pre_contract": pre_contract}


func _base_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.sequence_exp = 250
	gs.day = 5
	gs.pollution = 10
	gs.ap = 12
	gs.ap_max = 12
	return gs


func _normal_tower():
	var tower = TowerScript.new()
	tower.tower_id = "unit_normal_tower"
	tower.tower_name = "Unit Normal Tower"
	tower.size = "small"
	tower.district = "shadow_alley"
	tower.is_ritual_tower = false
	tower.promotion_gate_id = ""
	tower.promotion_from_sequence = -1
	tower.promotion_to_sequence = -1
	var floor = FloorScript.new()
	floor.floor_index = 0
	floor.event_type = "battle"
	floor.event_data = {"enemy_ids": ["drunkard"]}
	tower.floors = [floor]
	tower.floor_count = 1
	return tower


func _battle_result(contract_outcome: String, satisfied: int = 3, violated: int = 0) -> Dictionary:
	return {
		"outcome": "victory",
		"contract": {
			"outcome": contract_outcome,
			"satisfied": satisfied,
			"violated": violated,
		},
	}


func _runner():
	var scene = load(RUNNER_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower_runner.tscn instantiable")
		return null
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	return runner


func _free_runner(runner) -> void:
	if runner != null:
		runner.queue_free()


func _replace_string_array(target: Array[String], values: Array) -> void:
	target.clear()
	for value in values:
		target.append(str(value))


func _reaction_ids(count: int) -> Array[String]:
	var result: Array[String] = []
	for i in range(count):
		result.append("rx_%d" % i)
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
