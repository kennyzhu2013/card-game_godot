extends RefCounted

var _passed := 0
var _failed := 0

const NotePart = preload("res://scripts/battle/phigros/phigros_lane/note_part.gd")


func run() -> Dictionary:
	print("\n-- test_note_part_judge.gd --")
	test_perfect_within_40ms()
	test_good_between_40_and_80ms()
	test_bad_between_80_and_120ms()
	test_miss_beyond_120ms()
	test_break_window_shrinks_perfect()
	test_already_judged_note_ignored()
	return {"passed": _passed, "failed": _failed}


func test_perfect_within_40ms() -> void:
	var np = NotePart.new()
	np.note_time_ms = 1000
	var verdict := np.judge_at(1020, false)
	assert_eq(verdict, "perfect", "+20ms -> perfect")


func test_good_between_40_and_80ms() -> void:
	var np = NotePart.new()
	np.note_time_ms = 1000
	var verdict := np.judge_at(1060, false)
	assert_eq(verdict, "good", "+60ms -> good")


func test_bad_between_80_and_120ms() -> void:
	var np = NotePart.new()
	np.note_time_ms = 1000
	var verdict := np.judge_at(1100, false)
	assert_eq(verdict, "bad", "+100ms -> bad")


func test_miss_beyond_120ms() -> void:
	var np = NotePart.new()
	np.note_time_ms = 1000
	var verdict := np.judge_at(1200, false)
	assert_eq(verdict, "miss", "+200ms -> miss")


func test_break_window_shrinks_perfect() -> void:
	var np = NotePart.new()
	np.note_time_ms = 1000
	var verdict := np.judge_at(1030, true)
	assert_eq(verdict, "good", "+30ms in break window -> good (perfect shrunk)")


func test_already_judged_note_ignored() -> void:
	var np = NotePart.new()
	np.note_time_ms = 1000
	np.judge_at(1010, false)
	var second := np.judge_at(1010, false)
	assert_eq(second, "", "second judge on same note returns empty verdict")


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - condition false" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
