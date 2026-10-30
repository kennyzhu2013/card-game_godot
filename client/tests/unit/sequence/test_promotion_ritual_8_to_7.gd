extends RefCounted

const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")
const GateScript = preload("res://scripts/sequence/sequence_promotion_gate.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")
const BrandWorkshopScript = preload("res://scripts/hub/brand_workshop_panel.gd")

const RUNNER_SCENE := "res://scenes/tower/tower_runner.tscn"
const RITUAL_DATA_PATH := "res://data/towers/ritual_paper_blade.json"
const SERVICE_PATH := "res://scripts/sequence/promotion_ritual_service.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_promotion_ritual_8_to_7.gd --")
	test_gate_8_to_7_data_matches_r07_thresholds()
	test_ritual_paper_blade_data_file_has_four_floors()
	test_service_requires_paper_blade_kill_before_8_to_7()
	test_turn_battle_records_paper_blade_kill()
	test_paper_blade_kill_requires_explicit_tag_not_name_fallback()
	test_real_paper_blade_json_tag_counts_for_ritual_unlock()
	await test_runner_completion_promotes_8_to_7_and_unlocks_sequence_7()
	await test_runner_failure_sets_ritual_cooldown()
	await test_ritual_completion_restores_pre_entry_active_contract()
	await test_ritual_failure_restores_pre_entry_active_contract()
	return {"passed": _passed, "failed": _failed}


func test_gate_8_to_7_data_matches_r07_thresholds() -> void:
	var gate: SequencePromotionGate = _gate_8_to_7()
	assert_eq(int(gate.from_sequence), 8, "gate from sequence is 8")
	assert_eq(int(gate.to_sequence), 7, "gate to sequence is 7")
	assert_eq(int(gate.sequence_exp_required), 250, "gate requires 250 sequence_exp")
	assert_eq(int(gate.reactions_required), 18, "gate requires 18 reactions")
	assert_eq(int(gate.pollution_max), 60, "gate pollution max is 60")
	assert_eq(str(gate.story_node_id), "node_4b_promotion_87", "gate requires node_4b_promotion_87")
	assert_eq(str(gate.ritual_tower_id), "ritual_tower_paper_blade_4f", "gate points to 4f paper blade tower")


func test_ritual_paper_blade_data_file_has_four_floors() -> void:
	assert_true(FileAccess.file_exists(RITUAL_DATA_PATH), "ritual_paper_blade tower data exists")
	var data: Dictionary = _json(RITUAL_DATA_PATH)
	assert_eq(str(data.get("tower_id", "")), "ritual_tower_paper_blade_4f", "paper blade data stores tower id")
	var floors: Array = data.get("floors", [])
	assert_eq(floors.size(), 4, "paper blade tower data has 4 floors")
	if floors.size() == 4:
		assert_eq(str(floors[0].get("event_type", "")), "event", "paper blade floor 1 is event")
		assert_eq(str(floors[1].get("event_type", "")), "battle", "paper blade floor 2 is battle")
		assert_eq(str(floors[2].get("event_type", "")), "battle", "paper blade floor 3 is battle")
		assert_eq(str(floors[3].get("event_type", "")), "boss", "paper blade floor 4 is boss")


func test_service_requires_paper_blade_kill_before_8_to_7() -> void:
	var gs = _promotable_8_state(false)
	var blocked: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	assert_true(not bool(blocked.get("ok", false)), "8->7 ritual blocks without paper blade kill")
	assert_eq(str(blocked.get("error", "")), "paper_blade_kill_required", "8->7 block reason is paper_blade_kill_required")
	_mark_paper_blade_kill(gs)
	var allowed: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	assert_true(bool(allowed.get("ok", false)), "8->7 ritual starts after paper blade kill")


func test_turn_battle_records_paper_blade_kill() -> void:
	var gs = _promotable_8_state(false)
	var enemy = EnemyScript.from_json({
		"id": "paper_target",
		"display_name": "纸刃目标",
		"tier": 1,
		"stats": {"hp": 5, "max_hp": 5, "atk": 0, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [],
	})
	var card = _paper_blade_card()
	var battle = TurnBattleScript.new()
	battle.setup_battle([card], [], [enemy], [], null, gs)
	assert_true(battle.play_card(card, enemy), "paper blade card can be played")
	assert_true(enemy.is_dead(), "paper blade card kills target")
	assert_eq(_state_int(gs, "paper_blade_kill_count"), 1, "paper blade kill increments GameState counter")
	assert_eq(_state_int(gs, "last_paper_blade_kill_day"), int(gs.day), "paper blade kill records current day")


func test_paper_blade_kill_requires_explicit_tag_not_name_fallback() -> void:
	var gs = _promotable_8_state(false)
	var enemy = EnemyScript.from_json({
		"id": "fake_paper_target",
		"display_name": "fake_paper_target",
		"tier": 1,
		"stats": {"hp": 5, "max_hp": 5, "atk": 0, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [],
	})
	var fake_card = CardScript.from_json({
		"id": "fake_card",
		"template_id": "fake_card",
		"display_name": "化纸为刃伪装卡",
		"pathway": "fool",
		"sequence": 8,
		"energy_cost": 1,
		"combat_effect": {"damage": 10, "heal": 0, "target": "single", "range": 4, "status_effects": []},
		"tags": ["multi_target"],
	})
	var battle = TurnBattleScript.new()
	battle.setup_battle([fake_card], [], [enemy], [], null, gs)
	assert_true(battle.play_card(fake_card, enemy), "fake paper-name card can be played")
	assert_true(enemy.is_dead(), "fake paper-name card kills target")
	assert_eq(_state_int(gs, "paper_blade_kill_count"), 0, "paper_blade kill count ignores display_name without tag")
	var blocked: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	assert_eq(str(blocked.get("error", "")), "paper_blade_kill_required", "ritual remains blocked after fake name-only kill")


func test_real_paper_blade_json_tag_counts_for_ritual_unlock() -> void:
	var gs = _promotable_8_state(false)
	var enemy = EnemyScript.from_json({
		"id": "real_paper_target",
		"display_name": "real_paper_target",
		"tier": 1,
		"stats": {"hp": 5, "max_hp": 5, "atk": 0, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [],
	})
	var card = _paper_blade_card()
	assert_true("paper_blade" in card.tags, "real fool_s8_paper_blade_volley JSON carries paper_blade tag")
	var battle = TurnBattleScript.new()
	battle.setup_battle([card], [], [enemy], [], null, gs)
	assert_true(battle.play_card(card, enemy), "real paper_blade tagged card can be played")
	assert_eq(_state_int(gs, "paper_blade_kill_count"), 1, "real paper_blade tagged card increments kill count")
	var allowed: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	assert_true(bool(allowed.get("ok", false)), "real paper_blade kill unlocks ritual start")


func test_runner_completion_promotes_8_to_7_and_unlocks_sequence_7() -> void:
	var gs = _promotable_8_state(true)
	gs.ap = 12
	gs.ap_max = 10
	gs.last_sleep_ap_deficit = 2
	var result: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	var tower = result.get("tower", null)
	assert_true(bool(result.get("ok", false)) and tower != null, "8->7 ritual tower starts for runner completion")
	if tower == null:
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
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "victory"})
	assert_eq(int(gs.sequence), 7, "ritual completion promotes sequence 8->7")
	assert_eq(int(gs.sequence_exp), 0, "8->7 ritual completion resets sequence_exp")
	assert_eq(int(gs.ap_max), 12, "8->7 completion restores AP deficit max")
	assert_eq(int(gs.last_sleep_ap_deficit), 0, "8->7 completion clears AP deficit marker")
	assert_eq(int(gs.get_active_deck_capacity()), 15, "sequence 7 active deck capacity is 15")
	assert_eq(TurnBattleScript.energy_for_sequence(gs.sequence), 4, "sequence 7 energy max is 4")
	assert_true(bool(BrandWorkshopScript.can_mount_brand(_sequence_7_card(), _sequence_7_brand(), gs).get("ok", false)), "sequence 7 unlocks brand mounting")
	assert_eq(str(runner.get_last_return_reason()), "completed", "8->7 ritual completion returns to hub")
	runner.queue_free()


func test_runner_failure_sets_ritual_cooldown() -> void:
	var gs = _promotable_8_state(true)
	gs.day = 5
	gs.ap = 12
	gs.pollution = 10
	var result: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	var tower = result.get("tower", null)
	if tower == null:
		assert_true(false, "8->7 ritual tower starts for failure path")
		return
	var runner = await _runner()
	if runner == null:
		return
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.choose_event_option(0)
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "defeat"})
	assert_eq(str(tower.resolution), "collapsed", "ritual failure collapses tower immediately")
	assert_eq(int(gs.pollution), 30, "ritual failure adds exactly 20 pollution")
	assert_eq(_state_int(gs, "promotion_cooldown_until_day"), 12, "ritual failure sets 7 day cooldown")
	assert_eq(str(gs.get("promotion_cooldown_gate_id")), "fool_8_to_7", "ritual failure stores cooldown gate id")
	assert_eq(str(runner.get_last_return_reason()), "collapsed", "ritual failure returns collapsed")
	runner.queue_free()


func test_ritual_completion_restores_pre_entry_active_contract() -> void:
	var gs = _promotable_8_state(true)
	_replace_string_array(gs.learned_rules, ["A", "B", "C", "D", "E"])
	_replace_string_array(gs.active_contract, ["A", "B", "C"])
	gs.ap = 12
	var pre_contract: Array[String] = gs.active_contract.duplicate()
	var started: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	var tower = started.get("tower", null)
	assert_true(bool(started.get("ok", false)) and tower != null, "ritual starts for active_contract restore completion")
	assert_eq(gs.active_contract, gs.learned_rules, "ritual entry forces all learned rules active")
	if tower == null:
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
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "victory"})
	assert_eq(gs.active_contract, pre_contract, "ritual completion restores pre-entry active_contract snapshot")
	assert_true(not gs.has_meta("ritual_pre_active_contract"), "ritual completion clears active_contract snapshot meta")
	runner.queue_free()


func test_ritual_failure_restores_pre_entry_active_contract() -> void:
	var gs = _promotable_8_state(true)
	_replace_string_array(gs.learned_rules, ["A", "B", "C", "D", "E"])
	_replace_string_array(gs.active_contract, ["A", "B", "C"])
	gs.ap = 12
	var pre_contract: Array[String] = gs.active_contract.duplicate()
	var started: Dictionary = PromotionRitualServiceScript.start_ritual("fool_8_to_7", gs)
	var tower = started.get("tower", null)
	assert_true(bool(started.get("ok", false)) and tower != null, "ritual starts for active_contract restore failure")
	assert_eq(gs.active_contract, gs.learned_rules, "ritual failure path also starts with all learned rules active")
	if tower == null:
		return
	var runner = await _runner()
	if runner == null:
		return
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.choose_event_option(0)
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "defeat"})
	assert_eq(gs.active_contract, pre_contract, "ritual failure restores pre-entry active_contract snapshot")
	assert_true(not gs.has_meta("ritual_pre_active_contract"), "ritual failure clears active_contract snapshot meta")
	runner.queue_free()


func _gate_8_to_7() -> SequencePromotionGate:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/sequence/promotion_gates/fool_8_to_7.json"))
	return GateScript.from_json(parsed if parsed is Dictionary else {})


func _promotable_8_state(with_paper_kill: bool):
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.sequence_exp = 250
	gs.pollution = 20
	gs.known_reactions.clear()
	for reaction_id in _reaction_ids(18):
		gs.known_reactions.append(reaction_id)
	gs.daodian["completed_main_story_nodes"] = ["node_4b_promotion_87"]
	gs.learned_rules.clear()
	for rule in ["永远多一个面具", "旁观者守则", "不直呼神名"]:
		gs.learned_rules.append(str(rule))
	gs.active_contract.clear()
	for rule in gs.learned_rules:
		gs.active_contract.append(str(rule))
	if with_paper_kill:
		_mark_paper_blade_kill(gs)
	return gs


func _mark_paper_blade_kill(gs) -> void:
	if gs.has_method("record_paper_blade_kill"):
		gs.record_paper_blade_kill()
	else:
		gs.set_meta("paper_blade_kill_count", 1)


func _paper_blade_card():
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/fool_s8_paper_blade_volley.json"))
	var data: Dictionary = parsed if parsed is Dictionary else {}
	data["id"] = "paper_blade_test_card"
	data["combat_effect"] = {"damage": 10, "heal": 0, "target": "single", "range": 4, "status_effects": []}
	return CardScript.from_json(data)


func _sequence_7_card():
	return CardScript.from_json({
		"id": "seq7_card",
		"template_id": "seq7_card",
		"display_name": "序列7卡",
		"pathway": "fool",
		"sequence": 7,
		"quality": 3,
		"brand_slots": 4,
	})


func _sequence_7_brand():
	return BrandScript.from_dict({
		"id": "seq7_brand",
		"display_name": "序列7烙印",
		"pathway_affinity": "any",
		"sequence_min": 7,
	})


func _runner():
	var scene = load(RUNNER_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower runner scene loads for 8->7 ritual")
		return null
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	return runner


func _reaction_ids(count: int) -> Array[String]:
	var result: Array[String] = []
	for i in range(count):
		result.append("rx_%d" % i)
	return result


func _replace_string_array(target: Array[String], values: Array) -> void:
	target.clear()
	for value in values:
		target.append(str(value))


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _state_int(gs, property_name: String) -> int:
	var value = gs.get(property_name)
	if value == null:
		return 0
	return int(value)


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
