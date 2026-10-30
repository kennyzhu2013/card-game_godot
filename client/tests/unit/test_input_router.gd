extends RefCounted

const RouterScript = preload("res://scripts/battle/phigros/stage/input_router.gd")
const KeyRemapConfigScript = preload("res://scripts/battle/phigros/stage/key_remap_config.gd")
const NotePartScript = preload("res://scripts/battle/phigros/phigros_lane/note_part.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_input_router.gd --")
	test_default_config_maps_dfjk_to_lanes()
	test_router_judges_earliest_unjudged_note_in_lane()
	test_router_ignores_wrong_lane_and_outside_window()
	test_set_lane_count_6()
	test_set_lane_count_8()
	test_set_lane_count_invalid_ignored()
	return {"passed": _passed, "failed": _failed}


func test_default_config_maps_dfjk_to_lanes() -> void:
	var config = KeyRemapConfigScript.new()
	assert_eq(config.lane_for_key(KEY_D), 0, "D maps to lane 0")
	assert_eq(config.lane_for_key(KEY_F), 1, "F maps to lane 1")
	assert_eq(config.lane_for_key(KEY_J), 2, "J maps to lane 2")
	assert_eq(config.lane_for_key(KEY_K), 3, "K maps to lane 3")
	assert_eq(config.key_for_lane(0), KEY_D, "lane 0 maps back to D")
	assert_eq(config.key_for_lane(3), KEY_K, "lane 3 maps back to K")


func test_router_judges_earliest_unjudged_note_in_lane() -> void:
	var router = RouterScript.new()
	var first = _make_note(10, 1000, 0)
	var second = _make_note(11, 1050, 0)
	var other_lane = _make_note(12, 950, 1)
	router.set_lane_notes(0, [first, second])
	router.set_lane_notes(1, [other_lane])

	var first_result: Dictionary = router.handle_keycode(KEY_D, 1000)
	assert_true(not first_result.is_empty(), "router returns a result for the first lane hit")
	if not first_result.is_empty():
		assert_eq(first_result["verdict"], "perfect", "router delegates timing to judge")
	assert_true(first.judged, "first note is marked judged")
	assert_true(not second.judged, "later same-lane note remains unjudged")
	assert_true(not other_lane.judged, "other-lane note remains unjudged")

	var second_result: Dictionary = router.handle_keycode(KEY_D, 1050)
	assert_true(not second_result.is_empty(), "router can judge the next same-lane note")
	if not second_result.is_empty():
		assert_eq(second_result["verdict"], "perfect", "next note receives its own judge result")
	assert_true(second.judged, "router advances to the next same-lane note")


func test_router_ignores_wrong_lane_and_outside_window() -> void:
	var router = RouterScript.new()
	var note = _make_note(20, 1000, 0)
	router.set_lane_notes(0, [note])

	var wrong_lane: Dictionary = router.handle_keycode(KEY_F, 1000)
	assert_true(wrong_lane.is_empty(), "wrong lane does not judge the note")
	assert_true(not note.judged, "wrong lane leaves note unjudged")

	var outside_window: Dictionary = router.handle_keycode(KEY_D, 1121)
	assert_true(outside_window.is_empty(), "outside bad window does not judge the note")
	assert_true(not note.judged, "outside window leaves note unjudged")

	var boundary_result: Dictionary = router.handle_keycode(KEY_D, 1120)
	assert_true(not boundary_result.is_empty(), "bad boundary remains judgeable")
	if not boundary_result.is_empty():
		assert_eq(boundary_result["verdict"], "bad", "bad boundary verdict is preserved")


func test_set_lane_count_6() -> void:
	var router = RouterScript.new()
	var config = KeyRemapConfigScript.new()
	router.key_config = config
	router.set_lane_count(6)
	assert_eq(config.lane_count, 6, "lane_count switched to 6")
	assert_eq(config.lane_for_keycode(KEY_A), 0, "lane A=0")
	assert_eq(config.lane_for_keycode(KEY_K), 5, "lane K=5")


func test_set_lane_count_8() -> void:
	var router = RouterScript.new()
	var config = KeyRemapConfigScript.new()
	router.key_config = config
	router.set_lane_count(8)
	assert_eq(config.lane_count, 8, "lane_count switched to 8")
	assert_eq(config.lane_for_keycode(KEY_I), 7, "lane I=7")


func test_set_lane_count_invalid_ignored() -> void:
	var router = RouterScript.new()
	var config = KeyRemapConfigScript.new()
	router.key_config = config
	router.set_lane_count(5)
	assert_eq(config.lane_count, 4, "invalid count ignored, stays 4")


func _make_note(id: int, time_ms: int, lane: int) -> NotePartScript:
	var np = NotePartScript.new()
	np.setup(id, time_ms, lane, 1)
	return np


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
