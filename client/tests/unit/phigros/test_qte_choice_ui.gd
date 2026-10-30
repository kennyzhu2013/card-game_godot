extends RefCounted

const QteChoiceUi = preload("res://scripts/battle/phigros/stage/qte_choice_ui.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_qte_choice_ui.gd --")
	test_primary_keys_constants()
	test_secondary_keys_constants()
	test_default_timeout_constant()
	test_initial_state_idle()
	return {"passed": _passed, "failed": _failed}


func test_primary_keys_constants() -> void:
	var ui = QteChoiceUi.new()
	assert_eq(ui.KEY_PRIMARY_DUEL, KEY_1, "primary duel key = 1")
	assert_eq(ui.KEY_PRIMARY_EXECUTE, KEY_2, "primary execute key = 2")


func test_secondary_keys_constants() -> void:
	var ui = QteChoiceUi.new()
	assert_eq(ui.KEY_SECONDARY_PUNISH, KEY_A, "secondary A = punish")
	assert_eq(ui.KEY_SECONDARY_CHALLENGE, KEY_B, "secondary B = challenge")


func test_default_timeout_constant() -> void:
	var ui = QteChoiceUi.new()
	assert_true(is_equal_approx(ui.TIMEOUT_S, 8.0), "TIMEOUT_S = 8.0")


func test_initial_state_idle() -> void:
	var ui = QteChoiceUi.new()
	assert_eq(ui.current_stage, "idle", "current_stage starts idle")


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
