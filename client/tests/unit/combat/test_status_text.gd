extends RefCounted

const SCRIPT_PATH := "res://scripts/combat/status_text.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_status_text.gd --")
	test_status_text_describes_known_status_with_payload()
	return {"passed": _passed, "failed": _failed}


func test_status_text_describes_known_status_with_payload() -> void:
	var script = load(SCRIPT_PATH)
	assert_true(script != null and script.can_instantiate(), "StatusText helper exists and can instantiate")
	if script == null or not script.can_instantiate():
		return
	var helper = script.new()
	var cases := [
		["flame_wound", {"duration": 2, "magnitude": 5}, ["火焰伤口", "5", "2"]],
		["defense_break", {"duration": 1, "magnitude": 3}, ["破防", "3", "1"]],
		["ward", {"duration": 3, "stacks": 2}, ["守护", "2", "3"]],
		["bleed", {"duration": 2, "magnitude": 4}, ["流血", "4", "2"]],
		["chant_charge", {"duration": 1, "stacks": 2}, ["咏唱蓄力", "2", "1"]],
		["mirror_seal", {"duration": 2, "magnitude": 1}, ["镜封", "1", "2"]],
	]
	for case in cases:
		var status_id := str(case[0])
		var payload: Dictionary = case[1]
		var expected_parts: Array = case[2]
		var text := str(helper.call("describe", status_id, payload))
		for part in expected_parts:
			assert_true(text.contains(str(part)), "StatusText %s includes %s in '%s'" % [status_id, str(part), text])
		for raw in ["duration", "magnitude", "stacks", status_id]:
			assert_true(not text.contains(raw), "StatusText %s hides raw token %s" % [status_id, raw])
	var fallback := str(helper.call("describe", "unknown_status_probe", {}))
	assert_true(fallback.contains("未知状态探针"), "StatusText unknown fallback humanizes unknown ids")
	assert_true(not fallback.contains("unknown_status_probe") and not fallback.contains("_"), "StatusText unknown fallback hides raw id formatting")
	assert_true(fallback.contains("未知效果"), "StatusText unknown fallback still marks the effect as unknown")


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual, expected, message: String) -> void:
	assert_true(actual == expected, "%s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
