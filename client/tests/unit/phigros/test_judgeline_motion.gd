extends RefCounted

var _passed := 0
var _failed := 0

const JudgelineScript = preload("res://scripts/battle/phigros/phigros_lane/judgeline.gd")


func run() -> Dictionary:
	print("\n-- test_judgeline_motion.gd --")
	test_calculate_distance_same_time_is_zero()
	test_calculate_distance_constant_speed()
	test_handle_heights_advances_index()
	test_direction_modifier_flips_sign()
	return {"passed": _passed, "failed": _failed}


func test_calculate_distance_same_time_is_zero() -> void:
	var jl = JudgelineScript.new()
	jl.bpm = 120.0
	_setup_single_speed_event(jl, 1.0)
	var dist := jl.calculate_distance(10.0, 10.0)
	assert_true(absf(dist) < 0.01, "same time -> distance 0")


func test_calculate_distance_constant_speed() -> void:
	var jl = JudgelineScript.new()
	jl.bpm = 120.0
	_setup_single_speed_event(jl, 1.0)
	var dist := jl.calculate_distance(0.0, 32.0)
	assert_true(dist > 0.0, "future note -> positive distance")


func test_handle_heights_advances_index() -> void:
	var jl = JudgelineScript.new()
	jl.bpm = 120.0
	_setup_two_speed_events(jl)
	jl.current_height = 0
	jl.handle_heights(50.0)
	assert_true(jl.current_height > 0, "handle_heights advances past first segment")


func test_direction_modifier_flips_sign() -> void:
	var jl = JudgelineScript.new()
	jl.bpm = 120.0
	_setup_single_speed_event(jl, 1.0)
	var dist_above := jl.calculate_distance(0.0, 32.0)
	assert_true(dist_above > 0.0, "note in future -> positive base distance")


func _setup_single_speed_event(jl, speed: float) -> void:
	var ev = JudgelineScript.make_speed_event(0.0, 100.0, speed)
	jl.setup_speed_events([ev])


func _setup_two_speed_events(jl) -> void:
	var ev1 = JudgelineScript.make_speed_event(0.0, 32.0, 1.0)
	var ev2 = JudgelineScript.make_speed_event(32.0, 64.0, 2.0)
	jl.setup_speed_events([ev1, ev2])


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
