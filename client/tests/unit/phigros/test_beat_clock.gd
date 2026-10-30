extends RefCounted

const BeatClock = preload("res://scripts/battle/phigros/stage/beat_clock.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_beat_clock.gd --")
	test_beat_ms_for_bpm_90()
	test_beat_ms_for_bpm_120()
	test_on_beat_at_zero()
	test_on_beat_at_first_beat()
	test_on_beat_at_negative_offset()
	test_off_beat_in_middle()
	test_on_beat_window_boundary()
	test_on_beat_just_outside_window()
	return {"passed": _passed, "failed": _failed}


func test_beat_ms_for_bpm_90() -> void:
	assert_eq(BeatClock.beat_ms_for_bpm(90), 667, "90 BPM -> 667ms beat")


func test_beat_ms_for_bpm_120() -> void:
	assert_eq(BeatClock.beat_ms_for_bpm(120), 500, "120 BPM -> 500ms beat")


func test_on_beat_at_zero() -> void:
	# beat_phase 0, beat_ms 667, window 50: time 0 hit beat 0
	assert_true(BeatClock.is_on_beat(0, 667, 0, 50), "time 0 is on beat 0")


func test_on_beat_at_first_beat() -> void:
	# time 667 hits beat 1 exactly
	assert_true(BeatClock.is_on_beat(667, 667, 0, 50), "time 667 is on beat 1")


func test_on_beat_at_negative_offset() -> void:
	# time 620 = beat 1 (667) - 47, within window
	assert_true(BeatClock.is_on_beat(620, 667, 0, 50), "time 620 ~= beat 1 - 47ms")


func test_off_beat_in_middle() -> void:
	# time 333 is exactly between beat 0 and beat 1, distance 333 from both
	assert_true(not BeatClock.is_on_beat(333, 667, 0, 50), "time 333 is off beat (mid)")


func test_on_beat_window_boundary() -> void:
	# distance exactly 50ms is on beat
	assert_true(BeatClock.is_on_beat(50, 667, 0, 50), "time 50 within 50ms window")
	assert_true(BeatClock.is_on_beat(617, 667, 0, 50), "time 617 = 667 - 50 within window")


func test_on_beat_just_outside_window() -> void:
	# distance 51ms is off beat
	assert_true(not BeatClock.is_on_beat(51, 667, 0, 50), "time 51 outside 50ms window")


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
