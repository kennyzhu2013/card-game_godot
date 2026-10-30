extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "church threshold text"


func run() -> Dictionary:
	print("\n-- test_church_threshold_full.gd --")
	test_threshold_events_record_structured_timing_for_10_25_50()
	test_threshold_25_triggers_mainline_node_4_early_and_pollution()
	test_threshold_50_triggers_church_boss_eve_once()
	return {"passed": _passed, "failed": _failed}


func test_threshold_events_record_structured_timing_for_10_25_50() -> void:
	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	gs.set_ai_gm_service(fake_service)
	gs.church_awareness = 9
	gs.adjust_church_awareness(41, "r20:threshold_batch")
	assert_eq(gs.church_awareness_events.size(), 3, "single awareness jump records all crossed thresholds")
	assert_eq(_church_ai_count(fake_service.calls), 3, "single awareness jump calls church AI GM once per crossed threshold")
	_assert_event(gs, 10, "church_investigator_visit", "")
	_assert_event(gs, 25, "bishop_victor_direct_investigation", "node_4")
	_assert_event(gs, 50, "church_purge_boss_eve", "")
	gs.queue_free()


func test_threshold_25_triggers_mainline_node_4_early_and_pollution() -> void:
	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	gs.set_ai_gm_service(fake_service)
	gs.pollution = 20
	gs.pollution_stage = 0
	var emitted: Array = []
	gs.pollution_stage_changed.connect(Callable(self, "_record_stage_signal").bind(emitted))

	gs.church_awareness = 24
	gs.adjust_church_awareness(1, "r20:mirror_face")
	assert_true(_completed_nodes(gs).has("node_4"), "threshold 25 records generic mainline node 4 early")
	assert_true(_completed_nodes(gs).has("node_4_early_church_investigation"), "threshold 25 records concrete early church investigation node")
	assert_eq(str(gs.story_flags.get("church_threshold_25_event", "")), "mainline_node_4_early", "threshold 25 stores story flag")
	assert_true(bool(gs.get_meta("church_threshold_25_mainline_pending", false)), "threshold 25 marks pending mainline prompt metadata")
	assert_eq(int(gs.pollution), 50, "threshold 25 adds R08 church-trigger pollution +30")
	assert_eq(int(gs.pollution_stage), 2, "threshold 25 pollution uses set_pollution stage recalculation")
	assert_eq(emitted, [[0, 2]], "threshold 25 pollution emits one stage-change signal")
	var event: Dictionary = _event(gs, 25)
	assert_eq(int(_dict(event.get("pollution_result", {})).get("pollution", -1)), 50, "threshold 25 event stores pollution_result")
	gs.queue_free()


func test_threshold_50_triggers_church_boss_eve_once() -> void:
	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	gs.set_ai_gm_service(fake_service)
	gs.church_awareness = 49
	gs.adjust_church_awareness(1, "r20:inquiry_name")
	gs.adjust_church_awareness(20, "r20:duplicate")
	assert_eq(_threshold_count(gs, 50), 1, "threshold 50 event records only once")
	assert_eq(str(gs.story_flags.get("church_threshold_50_event", "")), "church_purge_boss_eve", "threshold 50 stores boss-eve story flag")
	assert_true(bool(gs.get_meta("church_boss_eve_pending", false)), "threshold 50 marks boss-eve pending metadata")
	var event: Dictionary = _event(gs, 50)
	assert_eq(str(event.get("event_id", "")), "church_purge_boss_eve", "threshold 50 event stores event_id")
	assert_eq(str(event.get("boss_event_id", "")), "church_purge_boss_eve", "threshold 50 event stores boss_event_id")
	gs.queue_free()


func _record_stage_signal(from_stage: int, to_stage: int, emitted: Array) -> void:
	emitted.append([from_stage, to_stage])


func _assert_event(gs, threshold: int, event_id: String, mainline_node_id: String) -> void:
	var event: Dictionary = _event(gs, threshold)
	assert_true(not event.is_empty(), "threshold %d event exists" % threshold)
	assert_eq(str(event.get("event_id", "")), event_id, "threshold %d event_id" % threshold)
	assert_eq(int(event.get("day", -1)), 9, "threshold %d records trigger day" % threshold)
	assert_eq(str(event.get("source", "")), "r20:threshold_batch", "threshold %d records source" % threshold)
	if mainline_node_id != "":
		assert_eq(str(event.get("mainline_node_id", "")), mainline_node_id, "threshold %d records mainline node id" % threshold)


func _event(gs, threshold: int) -> Dictionary:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return (event as Dictionary)
	return {}


func _threshold_count(gs, threshold: int) -> int:
	var count := 0
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			count += 1
	return count


func _church_ai_count(calls: Array) -> int:
	var count := 0
	for ctx in calls:
		if ctx != null and str(ctx.scene).begins_with("church_threshold_"):
			count += 1
	return count


func _completed_nodes(gs) -> Array:
	var raw: Variant = gs.daodian.get("completed_main_story_nodes", [])
	return raw.duplicate(true) if raw is Array else []


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.day = 9
	gs.time_of_day = "night"
	gs.current_district = "sacred_seven"
	return gs


func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


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
