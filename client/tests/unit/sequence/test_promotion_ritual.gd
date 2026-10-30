extends RefCounted

const GateScript = preload("res://scripts/sequence/sequence_promotion_gate.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const SERVICE_PATH := "res://scripts/sequence/promotion_ritual_service.gd"
const RUNNER_SCENE := "res://scenes/tower/tower_runner.tscn"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_promotion_ritual.gd --")
	test_gate_requires_story_node_when_configured()
	test_service_spawns_fool_9_to_8_ritual_tower()
	await test_runner_completion_promotes_sequence()
	await test_hub_prompt_click_opens_ritual_tower()
	return {"passed": _passed, "failed": _failed}


func test_gate_requires_story_node_when_configured() -> void:
	var gate: SequencePromotionGate = _gate_9_to_8()
	var gs: Dictionary = _promotable_dict()
	var daodian: Dictionary = gs.get("daodian", {})
	daodian["completed_main_story_nodes"] = []
	gs["daodian"] = daodian
	assert_true(not gate.can_promote(gs), "fool 9->8 blocks without node_4_promotion_98")
	daodian["completed_main_story_nodes"] = ["node_4_promotion_98"]
	gs["daodian"] = daodian
	assert_true(gate.can_promote(gs), "fool 9->8 allows when story node is complete")


func test_service_spawns_fool_9_to_8_ritual_tower() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _promotable_state()
	var result: Dictionary = service.start_ritual("fool_9_to_8", gs)
	assert_true(bool(result.get("ok", false)), "promotion ritual service starts when gate is satisfied")
	var tower = result.get("tower", null)
	assert_true(tower != null, "ritual tower returned")
	if tower == null:
		return
	assert_true(bool(tower.is_ritual_tower), "ritual tower flag is true")
	assert_eq(str(tower.tower_id), "ritual_tower_introspection_3f", "ritual tower id from gate")
	assert_eq(int(tower.floor_count), 3, "fool 9->8 ritual tower has exactly 3 floors")
	assert_eq(tower.floors.size(), 3, "ritual tower has 3 floor objects")
	assert_eq(str(tower.floors[0].event_type), "event", "ritual floor 1 is observation event")
	assert_eq(str(tower.floors[1].event_type), "battle", "ritual floor 2 is battle")
	assert_eq(str(tower.floors[2].event_type), "boss", "ritual floor 3 is boss")
	assert_eq(gs.active_contract.size(), gs.learned_rules.size(), "ritual forces all learned rules into active_contract")
	assert_eq(int(tower.promotion_from_sequence), 9, "ritual stores promotion from sequence")
	assert_eq(int(tower.promotion_to_sequence), 8, "ritual stores promotion to sequence")


func test_runner_completion_promotes_sequence() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _promotable_state()
	var result: Dictionary = service.start_ritual("fool_9_to_8", gs)
	var tower = result.get("tower", null)
	if tower == null:
		assert_true(false, "ritual tower returned for runner completion")
		return
	var runner = await _runner()
	if runner == null:
		return
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.choose_event_option(0)
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "victory"})
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "victory"})
	assert_eq(int(gs.sequence), 8, "ritual completion promotes sequence 9->8")
	assert_eq(int(gs.sequence_exp), 0, "ritual completion resets sequence_exp")
	assert_eq(str(tower.resolution), "cleared", "ritual tower is cleared")
	assert_eq(str(runner.get_last_return_reason()), "completed", "ritual completion returns to hub")
	runner.queue_free()


func test_hub_prompt_click_opens_ritual_tower() -> void:
	var previous: Dictionary = GameState.to_dict()
	_configure_promotable_state(GameState)
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for promotion prompt")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var prompt = hub.find_child("PromotionButton", true, false)
	assert_true(prompt != null, "hub creates promotion prompt near clock/status area")
	if prompt != null:
		assert_true(prompt.visible, "promotion prompt visible when gate is satisfied")
		prompt.pressed.emit()
		await Engine.get_main_loop().process_frame
		var runner = hub.get_node_or_null("TowerRunner")
		assert_true(runner != null and runner.visible, "clicking promotion prompt opens TowerRunner")
		if runner != null:
			var tower = runner.get_tower()
			assert_true(tower != null and bool(tower.is_ritual_tower), "TowerRunner receives ritual tower")
			if tower != null:
				assert_eq(int(tower.floor_count), 3, "Hub-spawned ritual tower has 3 floors")
	hub.queue_free()
	GameState.from_dict(previous)


func _gate_9_to_8() -> SequencePromotionGate:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/sequence/promotion_gates/fool_9_to_8.json"))
	if parsed is Dictionary:
		return GateScript.from_json(parsed)
	return GateScript.from_json({})


func _service():
	var script = load(SERVICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "promotion_ritual_service.gd loads")
		return null
	return script


func _runner():
	var scene = load(RUNNER_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower runner scene loads for ritual completion")
		return null
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	return runner


func _promotable_dict() -> Dictionary:
	return {
		"sequence": 9,
		"sequence_exp": 100,
		"known_reactions": _reaction_ids(8),
		"pollution": 20,
		"active_contract": ["永远多一个面具", "旁观者守则", "不直呼神名"],
		"daodian": {"completed_main_story_nodes": ["node_4_promotion_98"]},
	}


func _promotable_state():
	var gs = GameStateScript.new()
	gs._ready()
	_configure_promotable_state(gs)
	return gs


func _configure_promotable_state(gs) -> void:
	gs.sequence = 9
	gs.sequence_exp = 100
	gs.pollution = 20
	gs.known_reactions.clear()
	for reaction_id in _reaction_ids(8):
		gs.known_reactions.append(str(reaction_id))
	gs.active_contract.clear()
	gs.active_contract.append("永远多一个面具")
	gs.active_contract.append("旁观者守则")
	gs.active_contract.append("不直呼神名")
	gs.daodian["completed_main_story_nodes"] = ["node_4_promotion_98"]


func _reaction_ids(count: int) -> Array:
	var result: Array = []
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
