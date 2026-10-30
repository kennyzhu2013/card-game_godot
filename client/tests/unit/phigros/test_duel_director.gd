extends RefCounted

const DuelDirector = preload("res://scripts/battle/phigros/stage/duel_director.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_duel_director.gd --")
	test_score_for_summary()
	test_normalized_delta_clamps()
	test_segment_apply_clamps_bar()
	test_outcome_player_win()
	test_outcome_player_lose()
	test_outcome_draw()
	test_outcome_threshold_inclusive()
	return {"passed": _passed, "failed": _failed}


func test_score_for_summary() -> void:
	var d = DuelDirector.new()
	assert_eq(d.score_for_summary({"perfect": 6, "good": 2, "bad": 0, "miss": 0}), 20, "6p+2g = 20")
	assert_eq(d.score_for_summary({"perfect": 0, "good": 0, "bad": 0, "miss": 4}), -8, "4 miss = -8")


func test_normalized_delta_clamps() -> void:
	var d = DuelDirector.new()
	assert_true(is_equal_approx(d.normalized_delta(20, 4), 0.5), "16-delta -> 1.0 raw clamps to 0.5")
	assert_true(is_equal_approx(d.normalized_delta(-20, 0), -0.5), "-20 raw -> clamps to -0.5")
	assert_true(is_equal_approx(d.normalized_delta(8, 0), 0.5), "8/16 = 0.5")


func test_segment_apply_clamps_bar() -> void:
	var d = DuelDirector.new()
	d.bar_value = 0.7
	d.apply_segment(20, 0)
	assert_true(is_equal_approx(d.bar_value, 1.0), "bar clamped to 1.0")


func test_outcome_player_win() -> void:
	var d = DuelDirector.new()
	d.bar_value = 0.65
	assert_eq(d.outcome(), "PLAYER_WIN", "bar 0.65 -> PLAYER_WIN")


func test_outcome_player_lose() -> void:
	var d = DuelDirector.new()
	d.bar_value = -0.65
	assert_eq(d.outcome(), "PLAYER_LOSE", "bar -0.65 -> PLAYER_LOSE")


func test_outcome_draw() -> void:
	var d = DuelDirector.new()
	d.bar_value = 0.4
	assert_eq(d.outcome(), "DRAW", "bar 0.4 -> DRAW")


func test_outcome_threshold_inclusive() -> void:
	var d = DuelDirector.new()
	d.bar_value = 0.6
	assert_eq(d.outcome(), "PLAYER_WIN", "bar exactly 0.6 -> PLAYER_WIN")
	d.bar_value = -0.6
	assert_eq(d.outcome(), "PLAYER_LOSE", "bar exactly -0.6 -> PLAYER_LOSE")


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
