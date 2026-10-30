extends RefCounted

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_lane_globals.gd --")
	test_ct_converts_seconds_to_chart_time()
	test_cs_converts_chart_time_to_seconds()
	test_cs_is_inverse_of_ct()
	test_is_in_screen_center()
	test_is_in_screen_outside()
	return {"passed": _passed, "failed": _failed}


func test_ct_converts_seconds_to_chart_time() -> void:
	var LG = preload("res://scripts/battle/phigros/phigros_lane/lane_globals.gd")
	# 1 second at 120 bpm -> 1 * 120 * 32 / 60 = 64
	assert_eq(LG.ct(1.0, 120.0), 64.0, "ct(1s, 120bpm) = 64")


func test_cs_converts_chart_time_to_seconds() -> void:
	var LG = preload("res://scripts/battle/phigros/phigros_lane/lane_globals.gd")
	# 64 chart_time at 120 bpm -> 64 * 60 / 120 / 32 = 1.0
	assert_eq(LG.cs(64.0, 120.0), 1.0, "cs(64, 120bpm) = 1.0s")


func test_cs_is_inverse_of_ct() -> void:
	var LG = preload("res://scripts/battle/phigros/phigros_lane/lane_globals.gd")
	var original := 2.5
	var bpm := 140.0
	var round_trip := LG.cs(LG.ct(original, bpm), bpm)
	assert_true(absf(round_trip - original) < 0.001, "cs(ct(x)) is approximately x")


func test_is_in_screen_center() -> void:
	var LG = preload("res://scripts/battle/phigros/phigros_lane/lane_globals.gd")
	assert_true(LG.is_in_screen(Vector2(0, 0)), "center is in screen")


func test_is_in_screen_outside() -> void:
	var LG = preload("res://scripts/battle/phigros/phigros_lane/lane_globals.gd")
	assert_true(not LG.is_in_screen(Vector2(2000, 0)), "far right is outside")


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and is_equal_approx(float(actual), float(expected)):
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
