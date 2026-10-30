extends RefCounted

const CommissionActionServiceScript = preload("res://scripts/world/commission_action_service.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_commission_action_service.gd --")
	test_commission_execution_spends_1_ap_advances_time_and_marks_pending()
	test_commission_execution_stacks_tower_ap_when_requested()
	test_commission_execution_requires_accepted_commission()
	test_repeated_commission_execute_is_rejected_while_pending()
	test_commission_complete_grants_exp_once_and_moves_lists()
	return {"passed": _passed, "failed": _failed}


func test_commission_execution_spends_1_ap_advances_time_and_marks_pending() -> void:
	var gs = _state()
	gs.ap = 4
	gs.time_of_day = "morning"
	gs.accepted_commissions.append("runner_job")
	var result: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "runner_job", false, "")
	assert_true(bool(result.get("ok", false)), "non-tower commission executes")
	assert_eq(int(result.get("ap_cost", 0)), 1, "non-tower commission reports 1 AP cost")
	assert_eq(int(gs.ap), 3, "non-tower commission spends 1 AP")
	assert_eq(int(gs.sequence_exp), 0, "execute does not grant sequence_exp before completion")
	assert_eq(str(gs.get_meta("commission_pending_completion", "")), "runner_job", "execute marks commission pending completion")
	assert_eq(str(gs.time_of_day), "noon", "commission execution advances morning to noon")


func test_commission_execution_stacks_tower_ap_when_requested() -> void:
	var gs = _state()
	gs.ap = 6
	gs.accepted_commissions.append("tower_job")
	var result: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "tower_job", true, "medium")
	assert_true(bool(result.get("ok", false)), "tower commission executes")
	assert_eq(int(result.get("ap_cost", 0)), 5, "tower commission reports 1+medium tower AP")
	assert_eq(int(gs.ap), 1, "tower commission spends stacked AP")
	assert_eq(int(gs.sequence_exp), 0, "tower commission execute still waits for explicit completion")


func test_commission_execution_requires_accepted_commission() -> void:
	var gs = _state()
	gs.ap = 6
	var result: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "missing_job", false, "")
	assert_true(not bool(result.get("ok", true)), "missing commission is rejected")
	assert_eq(str(result.get("reason", "")), "not_accepted", "missing commission reports not_accepted")
	assert_eq(int(gs.ap), 6, "rejected commission does not spend AP")


func test_repeated_commission_execute_is_rejected_while_pending() -> void:
	var gs = _state()
	gs.ap = 6
	gs.accepted_commissions.append("runner_job")
	var first: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "runner_job", false, "")
	assert_true(bool(first.get("ok", false)), "first execute marks pending")
	var second: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "runner_job", false, "")
	assert_true(not bool(second.get("ok", true)), "second execute for same pending commission is rejected")
	assert_eq(str(second.get("reason", "")), "already_pending", "pending execute rejection reason")


func test_commission_complete_grants_exp_once_and_moves_lists() -> void:
	if not _script_defines_method("complete_placeholder"):
		assert_true(false, "CommissionActionService exposes complete_placeholder")
		return
	var gs = _state()
	gs.ap = 6
	gs.current_weather = "fog"
	gs.accepted_commissions.append("runner_job")
	var executed: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "runner_job", false, "")
	assert_true(bool(executed.get("ok", false)), "commission execute succeeds before completion")
	var complete_callable := Callable(CommissionActionServiceScript, "complete_placeholder")
	assert_true(complete_callable.is_valid(), "complete_placeholder callable is valid")
	var completed: Dictionary = complete_callable.call(gs, "runner_job")
	assert_true(bool(completed.get("ok", false)), "commission complete succeeds")
	assert_eq(int(completed.get("base_sequence_exp", 0)), 5, "non-tower commission completion base sequence_exp is 5")
	assert_eq(int(completed.get("sequence_exp_delta", 0)), 6, "fog/fool bonus raises completed commission exp 5 -> 6")
	assert_eq(int(gs.sequence_exp), 6, "commission complete writes sequence_exp")
	assert_true(not "runner_job" in gs.accepted_commissions, "complete removes id from accepted_commissions")
	assert_true("runner_job" in gs.completed_commissions, "complete adds id to completed_commissions")
	var repeated: Dictionary = complete_callable.call(gs, "runner_job")
	assert_true(not bool(repeated.get("ok", true)), "repeated complete is rejected")
	assert_eq(str(repeated.get("reason", "")), "already_completed", "repeated complete reason already_completed")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


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
