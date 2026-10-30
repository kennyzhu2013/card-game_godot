extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const CommissionActionServiceScript = preload("res://scripts/world/commission_action_service.gd")
const MeditationServiceScript = preload("res://scripts/world/meditation_service.gd")

const SEQUENCE_EXP_SERVICE_PATH := "res://scripts/sequence/sequence_exp_service.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_sequence_exp_multi_source.gd --")
	test_sequence_exp_service_adds_exp_and_checks_gate()
	test_battle_victory_adds_tier_based_sequence_exp()
	test_commission_completion_adds_sequence_exp()
	test_meditation_uses_sequence_exp_service()
	test_battle_victory_base_exp_scores_tier_1_2_3()
	test_commission_base_exp_has_no_unused_tower_size_parameter()
	return {"passed": _passed, "failed": _failed}


func test_sequence_exp_service_adds_exp_and_checks_gate() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _gate_ready_state()
	gs.sequence_exp = 95
	var result: Dictionary = service.add_exp(gs, 5, "manual_test")
	assert_true(bool(result.get("ok", false)), "SequenceExpService.add_exp returns ok")
	assert_eq(int(gs.sequence_exp), 100, "SequenceExpService adds base exp")
	assert_eq(str(gs.get_meta("last_sequence_exp_source", "")), "manual_test", "SequenceExpService records source meta")
	assert_true(bool(result.get("promotion_available", false)), "SequenceExpService checks promotion gate after add")
	assert_eq(str(result.get("promotion_gate_id", "")), "fool_9_to_8", "SequenceExpService reports promotion gate")
	assert_true(bool(gs.get_meta("promotion_prompt_pending", false)), "SequenceExpService writes promotion prompt meta")


func test_battle_victory_adds_tier_based_sequence_exp() -> void:
	var gs = _gate_ready_state()
	gs.sequence_exp = 95
	var battle = TurnBattleScript.new()
	battle.setup_battle([_card("starter")], [], [_enemy("tier1_enemy", 1)], [], null, gs)
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)
	assert_eq(int(gs.sequence_exp), 100, "tier 1 battle victory adds 5 sequence_exp")
	assert_eq(int(result.get("sequence_exp_delta", 0)), 5, "battle result reports sequence_exp delta")
	assert_true(bool(result.get("promotion_available", false)), "battle victory checks promotion gate")


func test_commission_completion_adds_sequence_exp() -> void:
	var gs = _state()
	gs.ap = 4
	gs.current_weather = "fog"
	gs.accepted_commissions.append("runner_job")
	var executed: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "runner_job", false, "")
	assert_true(bool(executed.get("ok", false)), "commission executes before exp completion")
	if not _script_defines_method("complete_placeholder"):
		assert_true(false, "CommissionActionService exposes complete_placeholder for exp source")
		return
	var complete_callable := Callable(CommissionActionServiceScript, "complete_placeholder")
	assert_true(complete_callable.is_valid(), "CommissionActionService complete_placeholder callable is valid")
	var result: Dictionary = complete_callable.call(gs, "runner_job")
	assert_true(bool(result.get("ok", false)), "commission completion grants exp source")
	assert_eq(int(result.get("base_sequence_exp", 0)), 5, "non-tower commission base sequence_exp is 5")
	assert_eq(int(result.get("sequence_exp_delta", 0)), 6, "fog/fool bonus raises commission exp 5 -> 6")
	assert_eq(int(gs.sequence_exp), 6, "commission writes sequence_exp")
	assert_eq(str(gs.get_meta("last_sequence_exp_source", "")), "commission", "commission records exp source")


func test_meditation_uses_sequence_exp_service() -> void:
	var gs = _state()
	gs.current_weather = "fog"
	var result: Dictionary = MeditationServiceScript.resolve_started_session(gs, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
	assert_true(bool(result.get("ok", false)), "meditation resolve succeeds")
	assert_eq(int(result.get("sequence_exp_delta", 0)), 24, "fog/fool perfect meditation still gives 24 exp")
	assert_eq(str(gs.get_meta("last_sequence_exp_source", "")), "meditation", "meditation records exp source through service")


func test_battle_victory_base_exp_scores_tier_1_2_3() -> void:
	var service = _service()
	if service == null:
		return
	assert_eq(service.battle_victory_base_exp([_enemy("tier1_enemy", 1)]), 5, "tier 1 battle base exp is 5")
	assert_eq(service.battle_victory_base_exp([_enemy("tier2_enemy", 2)]), 8, "tier 2 battle base exp is 8")
	assert_eq(service.battle_victory_base_exp([_enemy("tier3_enemy", 3)]), 10, "tier 3 battle base exp is 10")


func test_commission_base_exp_has_no_unused_tower_size_parameter() -> void:
	var service = _service()
	if service == null:
		return
	assert_eq(service.commission_base_exp(false), 5, "non-tower commission base exp remains 5")
	assert_eq(service.commission_base_exp(true), 10, "tower commission base exp remains 10")
	var source := FileAccess.get_file_as_string(SEQUENCE_EXP_SERVICE_PATH)
	assert_true(not source.contains("tower_size"), "commission_base_exp no longer exposes unused tower_size parameter")


func _service():
	var script = load(SEQUENCE_EXP_SERVICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "SequenceExpService script loads")
		return null
	return script


func _gate_ready_state():
	var gs = _state()
	gs.sequence = 9
	gs.sequence_exp = 0
	gs.pollution = 10
	gs.known_reactions.clear()
	for i in range(8):
		gs.known_reactions.append("rx_%d" % i)
	gs.active_contract.clear()
	for rule in ["永远多一个面具", "旁观者守则", "不直呼神名"]:
		gs.active_contract.append(rule)
	gs.daodian["completed_main_story_nodes"] = ["node_4_promotion_98"]
	return gs


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _card(id: String):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"sequence": 9,
		"energy_cost": 1,
		"combat_effect": {"damage": 1, "heal": 0, "target": "single", "range": 1, "status_effects": []},
		"tags": [],
	})


func _enemy(id: String, tier: int):
	return EnemyScript.from_json({
		"id": id,
		"display_name": id,
		"tier": tier,
		"stats": {"hp": 10, "max_hp": 10, "atk": 0, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [],
	})


func _script_defines_method(method_name: String) -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/world/commission_action_service.gd")
	return source.contains("func %s" % method_name)


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
