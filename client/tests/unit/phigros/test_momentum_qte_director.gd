extends RefCounted

const MomentumQteDirector = preload("res://scripts/battle/phigros/stage/momentum_qte_director.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_momentum_qte_director.gd --")
	test_initial_state_idle()
	test_signals_exist()
	test_route_decides_branch_for_choice()
	return {"passed": _passed, "failed": _failed}


func test_initial_state_idle() -> void:
	var d = MomentumQteDirector.new()
	assert_eq(d.current_phase, "idle", "current_phase starts idle")


func test_signals_exist() -> void:
	var d = MomentumQteDirector.new()
	assert_true(d.has_signal("qte_finished"), "qte_finished signal exposed")


func test_route_decides_branch_for_choice() -> void:
	var d = MomentumQteDirector.new()
	assert_eq(d.branch_for_choice("DUEL", ""), "DUEL", "primary DUEL -> DUEL")
	assert_eq(d.branch_for_choice("EXECUTE", "EXECUTE_A"), "EXECUTE_A", "secondary A -> EXECUTE_A")
	assert_eq(d.branch_for_choice("EXECUTE", "EXECUTE_B"), "EXECUTE_B", "secondary B -> EXECUTE_B")
	assert_eq(d.branch_for_choice("EXECUTE", ""), "EXECUTE_A", "missing secondary defaults to A")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s expected '%s' got '%s'" % [msg, str(expected), str(actual)])
