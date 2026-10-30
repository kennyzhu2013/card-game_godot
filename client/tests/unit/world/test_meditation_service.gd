extends RefCounted

const MeditationServiceScript = preload("res://scripts/world/meditation_service.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_meditation_service.gd --")
	test_meditation_spends_3_ap_and_increments_daily_count()
	test_meditation_blocks_after_three_attempts_per_day()
	test_meditation_blocks_when_ap_is_short()
	return {"passed": _passed, "failed": _failed}


func test_meditation_spends_3_ap_and_increments_daily_count() -> void:
	var gs = _state()
	gs.ap = 12
	var result: Dictionary = MeditationServiceScript.start_placeholder_session(gs)
	assert_true(bool(result.get("ok", false)), "meditation placeholder starts")
	assert_eq(int(gs.ap), 9, "meditation spends 3 AP")
	assert_eq(int(gs.meditation_count_today), 1, "meditation_count_today increments")


func test_meditation_blocks_after_three_attempts_per_day() -> void:
	var gs = _state()
	gs.ap = 12
	for i in range(3):
		assert_true(bool(MeditationServiceScript.start_placeholder_session(gs).get("ok", false)), "meditation #%d succeeds" % [i + 1])
	var fourth: Dictionary = MeditationServiceScript.start_placeholder_session(gs)
	assert_true(not bool(fourth.get("ok", true)), "fourth meditation is blocked")
	assert_eq(str(fourth.get("reason", "")), "daily_limit", "fourth meditation reports daily_limit")
	assert_eq(int(gs.meditation_count_today), 3, "blocked meditation does not increment count")


func test_meditation_blocks_when_ap_is_short() -> void:
	var gs = _state()
	gs.ap = 2
	var result: Dictionary = MeditationServiceScript.start_placeholder_session(gs)
	assert_true(not bool(result.get("ok", true)), "meditation blocks with AP short")
	assert_eq(str(result.get("reason", "")), "ap_short", "short meditation reports ap_short")
	assert_eq(int(gs.meditation_count_today), 0, "short meditation does not increment count")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


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
