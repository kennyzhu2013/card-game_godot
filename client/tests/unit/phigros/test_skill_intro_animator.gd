# client/tests/unit/phigros/test_skill_intro_animator.gd
extends RefCounted

const SkillIntroAnimator = preload("res://scripts/battle/phigros/stage/skill_intro_animator.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_skill_intro_animator.gd --")
	test_total_duration_is_1000ms()
	test_phase_breakdown()
	test_initial_state_idle()
	test_finished_signal_exists()
	return {"passed": _passed, "failed": _failed}


func test_total_duration_is_1000ms() -> void:
	var animator = SkillIntroAnimator.new()
	assert_eq(animator.total_duration_ms(), 1000, "total_duration_ms = 1000")


func test_phase_breakdown() -> void:
	var animator = SkillIntroAnimator.new()
	assert_eq(animator.STAGE_POSE_MS, 300, "STAGE_POSE_MS = 300")
	assert_eq(animator.STAGE_FLY_OUT_MS, 300, "STAGE_FLY_OUT_MS = 300")
	assert_eq(animator.STAGE_HIT_MS, 200, "STAGE_HIT_MS = 200")
	assert_eq(animator.STAGE_RETURN_MS, 200, "STAGE_RETURN_MS = 200")


func test_initial_state_idle() -> void:
	var animator = SkillIntroAnimator.new()
	assert_true(not animator.is_playing(), "is_playing false initially")


func test_finished_signal_exists() -> void:
	var animator = SkillIntroAnimator.new()
	assert_true(animator.has_signal("finished"), "exposes finished signal")


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
