extends RefCounted

const ChartGeneratorScript = preload("res://scripts/battle/phigros/stage/chart_generator.gd")

var _passed := 0
var _failed := 0
var _generator = ChartGeneratorScript.new()


func run() -> Dictionary:
	print("\n-- test_chart_generator.gd --")
	test_t1_baseline_generates_straight_chain()
	test_t1_suppressed_momentum_increases_density()
	test_t1_after_refactor_unchanged()
	test_t2_baseline_generates_alternating_pair()
	test_t2_suppressed_momentum_increases_density()
	test_t3_baseline_generates_four_lane_cascade()
	test_t3_suppressed_momentum_increases_density()
	test_duel_chart_has_8_notes_alternating_lanes()
	test_execute_chart_phase_count_and_lanes()
	test_execute_chart_double_tap_doubles_count()
	test_whisper_template()
	test_breath_template()
	test_weave_template()
	test_mirror_template()
	test_whisper_has_default_choreography()
	test_breath_has_default_choreography()
	test_weave_has_default_choreography()
	test_mirror_has_default_choreography()
	test_whisper_high_momentum_scales_count()
	test_weave_high_momentum_scales_count()
	test_breath_ignores_momentum()
	return {"passed": _passed, "failed": _failed}


func test_t1_after_refactor_unchanged() -> void:
	var gen = ChartGeneratorScript.new()
	var chart = gen.generate("T1", {"note_count": 3, "interval_ms": 333, "start_ms": 0, "lane": 0}, 50)
	assert_eq(chart.notes.size(), 3, "T1 should still produce 3 notes at momentum 50")
	assert_eq(int(chart.notes[0].lane), 0, "First note should be on lane 0")
	assert_eq(int(chart.notes[1].time_ms), 333, "Second note at 333ms")


func test_t1_baseline_generates_straight_chain() -> void:
	var chart = _generator.generate("T1", {
		"note_count": 3,
		"lane": 2,
		"start_ms": 500,
	}, 30)
	assert_eq(chart.template_id, "T1", "T1 chart records template id")
	assert_eq(chart.notes.size(), 3, "T1 baseline keeps requested note count")
	assert_lanes(chart.notes, [2, 2, 2], "T1 baseline uses one lane")
	assert_times(chart.notes, [500, 833, 1166], "T1 baseline times follow interval")
	assert_monotonic(chart.notes, "T1 baseline times are monotonic")


func test_t1_suppressed_momentum_increases_density() -> void:
	var chart = _generator.generate("T1", {
		"note_count": 5,
		"interval_ms": 200,
		"lane": 1,
		"start_ms": 0,
	}, 85)
	assert_eq(chart.notes.size(), 7, "T1 suppressed momentum applies +40 percent density")
	assert_lanes(chart.notes, [1, 1, 1, 1, 1, 1, 1], "T1 suppressed keeps one lane")
	assert_monotonic(chart.notes, "T1 suppressed times are monotonic")


func test_t2_baseline_generates_alternating_pair() -> void:
	var chart = _generator.generate("T2", {
		"beat_count": 6,
		"lanes": [0, 3],
		"start_ms": 120,
	}, 40)
	assert_eq(chart.notes.size(), 6, "T2 baseline keeps requested beat count")
	assert_lanes(chart.notes, [0, 3, 0, 3, 0, 3], "T2 baseline alternates lanes")
	assert_times(chart.notes, [120, 360, 600, 840, 1080, 1320], "T2 baseline times follow interval")
	assert_monotonic(chart.notes, "T2 baseline times are monotonic")


func test_t2_suppressed_momentum_increases_density() -> void:
	var chart = _generator.generate("T2", {
		"beat_count": 5,
		"interval_ms": 160,
		"lanes": [1, 2],
		"start_ms": 0,
	}, 90)
	assert_eq(chart.notes.size(), 7, "T2 suppressed momentum applies +40 percent density")
	assert_lanes(chart.notes, [1, 2, 1, 2, 1, 2, 1], "T2 suppressed extends alternating pattern")
	assert_monotonic(chart.notes, "T2 suppressed times are monotonic")


func test_t3_baseline_generates_four_lane_cascade() -> void:
	var chart = _generator.generate("T3", {
		"repeat_count": 2,
		"direction": "forward",
		"start_ms": 100,
	}, 35)
	assert_eq(chart.notes.size(), 8, "T3 baseline expands repeats across four lanes")
	assert_lanes(chart.notes, [0, 1, 2, 3, 0, 1, 2, 3], "T3 baseline cascades forward")
	assert_times(chart.notes, [100, 300, 500, 700, 900, 1100, 1300, 1500], "T3 baseline times follow interval")
	assert_monotonic(chart.notes, "T3 baseline times are monotonic")


func test_t3_suppressed_momentum_increases_density() -> void:
	var chart = _generator.generate("T3", {
		"repeat_count": 2,
		"interval_ms": 140,
		"direction": "reverse",
		"start_ms": 0,
	}, 100)
	assert_eq(chart.notes.size(), 11, "T3 suppressed momentum applies +40 percent density")
	assert_lanes(chart.notes, [3, 2, 1, 0, 3, 2, 1, 0, 3, 2, 1], "T3 suppressed extends reverse cascade")
	assert_monotonic(chart.notes, "T3 suppressed times are monotonic")


func test_duel_chart_has_8_notes_alternating_lanes() -> void:
	var gen = ChartGeneratorScript.new()
	var notes: Array = gen.generate_duel_chart()
	assert_eq(notes.size(), 8, "duel chart 8 notes")
	assert_eq(int(notes[0].lane), 0, "lane 0 first")
	assert_eq(int(notes[1].lane), 3, "lane 3 second")
	assert_eq(int(notes[2].lane), 0, "lane 0 third (alt)")


func test_execute_chart_phase_count_and_lanes() -> void:
	var gen = ChartGeneratorScript.new()
	var notes: Array = gen.generate_execute_chart_phase(6, 12, 180, false)
	assert_eq(notes.size(), 12, "phase1 12 notes")
	assert_eq(int(notes[0].lane), 0, "lane 0")
	assert_eq(int(notes[5].lane), 5, "lane 5 (last in cycle)")
	assert_eq(int(notes[6].lane), 0, "wraps back to lane 0")


func test_execute_chart_double_tap_doubles_count() -> void:
	var gen = ChartGeneratorScript.new()
	var notes: Array = gen.generate_execute_chart_phase(8, 20, 120, true)
	assert_eq(notes.size(), 40, "double tap doubles to 40 notes")


func test_whisper_template() -> void:
	var chart = _generator.generate("WHISPER", {
		"note_count": 4,
		"interval_ms": 600,
		"start_ms": 0,
		"lane": 1,
	}, 50)
	assert_eq(chart.template_id, "WHISPER", "template_id preserved")
	assert_eq(chart.notes.size(), 4, "WHISPER should produce 4 notes")
	assert_lanes(chart.notes, [1, 1, 1, 1], "WHISPER keeps single lane 1")
	assert_eq(int(chart.notes[1].time_ms), 600, "Second note at 600ms (offbeat)")
	assert_monotonic(chart.notes, "WHISPER times are monotonic")


func test_breath_template() -> void:
	var chart = _generator.generate("BREATH", {
		"start_ms": 0,
		"hold_count": 3,
		"hold_duration_ms": 2000,
		"gap_ms": 500,
		"lane": 1,
	}, 50)
	assert_eq(chart.template_id, "BREATH", "template_id preserved")
	assert_eq(chart.notes.size(), 3, "BREATH produces hold_count notes (no momentum scaling)")
	assert_lanes(chart.notes, [1, 1, 1], "BREATH keeps single lane 1")
	assert_times(chart.notes, [0, 2500, 5000], "BREATH spaces holds by hold_duration_ms+gap_ms")
	assert_eq(String(chart.notes[0].kind), "hold", "First BREATH note is hold kind")
	assert_eq(String(chart.notes[1].kind), "hold", "Second BREATH note is hold kind")
	assert_eq(String(chart.notes[2].kind), "hold", "Third BREATH note is hold kind")
	assert_eq(int(chart.notes[0].hold_duration_ms), 2000, "First hold has 2000ms duration")
	assert_eq(int(chart.notes[1].hold_duration_ms), 2000, "Second hold has 2000ms duration")
	assert_eq(int(chart.notes[2].hold_duration_ms), 2000, "Third hold has 2000ms duration")
	assert_monotonic(chart.notes, "BREATH times are monotonic")


func test_weave_template() -> void:
	var chart = _generator.generate("WEAVE", {
		"start_ms": 0,
		"note_count": 6,
		"interval_ms": 200,
		"lane_a": 1,
		"lane_b": 2,
	}, 50)
	assert_eq(chart.template_id, "WEAVE", "template_id preserved")
	assert_eq(chart.notes.size(), 6, "WEAVE produces 6 notes at momentum 50")
	assert_lanes(chart.notes, [1, 2, 1, 2, 1, 2], "WEAVE alternates between lane_a(1) and lane_b(2)")
	assert_times(chart.notes, [0, 200, 400, 600, 800, 1000], "WEAVE times follow interval_ms")
	assert_eq(int(chart.notes[3].time_ms), 600, "Fourth note at 3 * 200 = 600ms")
	assert_monotonic(chart.notes, "WEAVE times are monotonic")


func test_mirror_template() -> void:
	var chart = _generator.generate("MIRROR", {
		"start_ms": 0,
		"note_count": 4,
		"interval_ms": 250,
		"outer_lane": 0,
		"inner_lane": 1,
	}, 50)
	assert_eq(chart.template_id, "MIRROR", "template_id preserved")
	assert_eq(chart.notes.size(), 8, "MIRROR produces 4 beats * 2 notes = 8 notes")

	# Collect lanes at each beat time
	var t0_lanes: Array[int] = []
	var t250_lanes: Array[int] = []
	var t500_lanes: Array[int] = []
	var t750_lanes: Array[int] = []
	for note in chart.notes:
		var t := int(note.time_ms)
		var lane := int(note.lane)
		if t == 0:
			t0_lanes.append(lane)
		elif t == 250:
			t250_lanes.append(lane)
		elif t == 500:
			t500_lanes.append(lane)
		elif t == 750:
			t750_lanes.append(lane)

	t0_lanes.sort()
	t250_lanes.sort()
	t500_lanes.sort()
	t750_lanes.sort()

	assert_eq(t0_lanes, [0, 3] as Array[int], "Beat 0 outer pair = [0, 3]")
	assert_eq(t250_lanes, [1, 2] as Array[int], "Beat 1 inner pair = [1, 2]")
	assert_eq(t500_lanes, [0, 3] as Array[int], "Beat 2 outer pair = [0, 3] (alternates back)")
	assert_eq(t750_lanes, [1, 2] as Array[int], "Beat 3 inner pair = [1, 2] (alternates back)")


func test_whisper_has_default_choreography() -> void:
	var chart = _generator.generate("WHISPER", {"note_count": 4, "interval_ms": 600, "start_ms": 0, "lane": 1}, 50)
	assert_eq(int(chart.choreography.size() > 0), 1, "WHISPER should have non-empty default choreography")
	var has_move_y := false
	for entry in chart.choreography:
		if entry.get("type") == "move_y":
			has_move_y = true
	assert_eq(int(has_move_y), 1, "WHISPER choreography should include move_y for drift feel")


func test_breath_has_default_choreography() -> void:
	var chart = _generator.generate("BREATH", {"hold_count": 3, "hold_duration_ms": 2000, "gap_ms": 500, "start_ms": 0, "lane": 1}, 50)
	assert_eq(int(chart.choreography.size() > 0), 1, "BREATH should have non-empty default choreography")
	var has_scale := false
	for entry in chart.choreography:
		if entry.get("type") == "scale_x":
			has_scale = true
	assert_eq(int(has_scale), 1, "BREATH choreography should include scale_x for breathing")


func test_weave_has_default_choreography() -> void:
	var chart = _generator.generate("WEAVE", {"note_count": 6, "interval_ms": 200, "lane_a": 1, "lane_b": 2, "start_ms": 0}, 50)
	assert_eq(int(chart.choreography.size() > 0), 1, "WEAVE should have non-empty default choreography")
	var has_rotate := false
	for entry in chart.choreography:
		if entry.get("type") == "rotate":
			has_rotate = true
	assert_eq(int(has_rotate), 1, "WEAVE choreography should include rotate for weaving feel")


func test_mirror_has_default_choreography() -> void:
	var chart = _generator.generate("MIRROR", {"note_count": 4, "interval_ms": 250, "outer_lane": 0, "inner_lane": 1, "start_ms": 0}, 50)
	assert_eq(int(chart.choreography.size() > 0), 1, "MIRROR should have non-empty default choreography")
	var has_scale := false
	for entry in chart.choreography:
		if entry.get("type") == "scale_x":
			has_scale = true
	assert_eq(int(has_scale), 1, "MIRROR choreography should include scale_x for symmetric pulse")


func test_whisper_high_momentum_scales_count() -> void:
	var chart = _generator.generate("WHISPER", {"note_count": 4, "interval_ms": 600, "start_ms": 0, "lane": 1}, 85)
	# momentum 85 is in [80, ...] bracket → density 1.4× → 4 * 1.4 = 5.6 → round to 6
	assert_eq(chart.notes.size(), 6, "WHISPER high momentum scales 4 -> 6 notes (~1.4x)")


func test_weave_high_momentum_scales_count() -> void:
	var chart = _generator.generate("WEAVE", {"note_count": 6, "interval_ms": 200, "lane_a": 1, "lane_b": 2, "start_ms": 0}, 85)
	# momentum 85 → density 1.4× → 6 * 1.4 = 8.4 → round to 8
	assert_eq(chart.notes.size(), 8, "WEAVE high momentum scales 6 -> 8 notes (~1.4x)")
	assert_lanes(chart.notes, [1, 2, 1, 2, 1, 2, 1, 2], "WEAVE keeps alternating when scaled")


func test_breath_ignores_momentum() -> void:
	# BREATH intentionally bypasses _scaled_count (hold-based rituals stay at fixed pacing)
	var chart_low = _generator.generate("BREATH", {"hold_count": 3, "hold_duration_ms": 2000, "gap_ms": 500, "start_ms": 0, "lane": 1}, 10)
	var chart_high = _generator.generate("BREATH", {"hold_count": 3, "hold_duration_ms": 2000, "gap_ms": 500, "start_ms": 0, "lane": 1}, 85)
	assert_eq(chart_low.notes.size(), 3, "BREATH at low momentum still has 3 holds")
	assert_eq(chart_high.notes.size(), 3, "BREATH at high momentum still has 3 holds (no scaling)")


func assert_lanes(notes: Array, expected: Array[int], message: String) -> void:
	var actual: Array[int] = []
	for note in notes:
		actual.append(int(note.lane))
	assert_eq(actual, expected, message)


func assert_times(notes: Array, expected: Array[int], message: String) -> void:
	var actual: Array[int] = []
	for note in notes:
		actual.append(int(note.time_ms))
	assert_eq(actual, expected, message)


func assert_monotonic(notes: Array, message: String) -> void:
	var previous := -1
	for note in notes:
		if int(note.time_ms) <= previous:
			assert_true(false, message)
			return
		previous = int(note.time_ms)
	assert_true(true, message)


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
