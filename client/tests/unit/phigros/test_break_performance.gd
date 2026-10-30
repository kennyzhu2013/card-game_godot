extends RefCounted

const BreakPerformance = preload("res://scripts/battle/phigros/stage/break_performance.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_break_performance.gd --")
	test_total_duration_is_1500ms()
	test_phase_constants()
	test_finished_signal_exists()
	test_initial_state_idle()
	return {"passed": _passed, "failed": _failed}


func test_total_duration_is_1500ms() -> void:
	var perf = BreakPerformance.new()
	assert_eq(perf.total_duration_ms(), 1500, "total_duration_ms = 1500")


func test_phase_constants() -> void:
	var perf = BreakPerformance.new()
	assert_eq(perf.LINE_SHRINK_MS, 180, "LINE_SHRINK_MS = 180")
	assert_eq(perf.FLASH_MS, 200, "FLASH_MS = 200")
	assert_eq(perf.PARTICLE_MS, 600, "PARTICLE_MS = 600")
	assert_eq(perf.LABEL_MS, 800, "LABEL_MS = 800")


func test_finished_signal_exists() -> void:
	var perf = BreakPerformance.new()
	assert_true(perf.has_signal("finished"), "exposes finished signal")


func test_initial_state_idle() -> void:
	var perf = BreakPerformance.new()
	assert_true(not perf.is_playing(), "is_playing false initially")


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
