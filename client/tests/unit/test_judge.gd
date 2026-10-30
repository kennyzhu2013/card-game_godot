extends RefCounted

const JudgeScript = preload("res://scripts/battle/phigros/stage/judge.gd")

var _passed := 0
var _failed := 0
var _judge = JudgeScript.new()


func run() -> Dictionary:
	print("\n-- test_judge.gd --")
	test_perfect_cases()
	test_good_cases()
	test_bad_cases()
	test_miss_cases()
	test_break_shrinks_all_windows_by_20ms()
	return {"passed": _passed, "failed": _failed}


func test_perfect_cases() -> void:
	assert_judge(1000, 1000, "perfect", 0, "Perfect at exact time")
	assert_judge(1000, 1040, "perfect", 40, "Perfect includes +40ms boundary")
	assert_judge(1000, 961, "perfect", -39, "Perfect includes inside negative boundary")


func test_good_cases() -> void:
	assert_judge(1000, 1041, "good", 41, "Good starts just outside Perfect")
	assert_judge(1000, 1080, "good", 80, "Good includes +80ms boundary")
	assert_judge(1000, 921, "good", -79, "Good includes inside negative boundary")


func test_bad_cases() -> void:
	assert_judge(1000, 1081, "bad", 81, "Bad starts just outside Good")
	assert_judge(1000, 1120, "bad", 120, "Bad includes +120ms boundary")
	assert_judge(1000, 881, "bad", -119, "Bad includes inside negative boundary")


func test_miss_cases() -> void:
	assert_judge(1000, 1121, "miss", 121, "Miss starts outside Bad")
	assert_judge(1000, 879, "miss", -121, "Miss starts outside negative Bad")
	assert_judge(1000, 1000, "miss", 0, "Unsupported note kind is Miss", "hold")


func test_break_shrinks_all_windows_by_20ms() -> void:
	var result_perfect_edge = _judge.judge_hit(1000, 1020, "tap", true)
	assert_eq(result_perfect_edge.verdict, "perfect", "Break Perfect includes shrunk +20ms boundary")
	var result_good_edge = _judge.judge_hit(1000, 1060, "tap", true)
	assert_eq(result_good_edge.verdict, "good", "Break Good includes shrunk +60ms boundary")
	var result_bad_edge = _judge.judge_hit(1000, 1100, "tap", true)
	assert_eq(result_bad_edge.verdict, "bad", "Break Bad includes shrunk +100ms boundary")
	var result_miss = _judge.judge_hit(1000, 1101, "tap", true)
	assert_eq(result_miss.verdict, "miss", "Break Miss starts after shrunk Bad window")


func assert_judge(
	note_time_ms: int,
	input_time_ms: int,
	expected_verdict: String,
	expected_offset: int,
	message: String,
	note_kind: String = "tap"
) -> void:
	var result = _judge.judge_hit(note_time_ms, input_time_ms, note_kind)
	assert_eq(result.verdict, expected_verdict, "%s verdict" % message)
	assert_eq(result.offset_ms, expected_offset, "%s offset" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
