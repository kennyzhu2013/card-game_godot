extends RefCounted

const MeditationServiceScript = preload("res://scripts/world/meditation_service.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_meditation_minigame.gd --")
	await test_cushion_meditation_scene_uses_breathing_stage()
	test_rating_thresholds_cover_four_outcomes()
	test_resolve_session_awards_exp_and_pollution()
	test_fog_weather_adds_twenty_percent_exp()
	test_daily_limit_blocks_fourth_full_session()
	test_promotion_gate_check_runs_after_meditation_exp()
	test_three_real_meditation_settlements_advance_time_to_night()
	return {"passed": _passed, "failed": _failed}


func test_cushion_meditation_scene_uses_breathing_stage() -> void:
	var scene = load("res://scenes/hub/cushion_meditation.tscn")
	assert_true(scene != null and scene.can_instantiate(), "cushion meditation scene exists")
	if scene == null or not scene.can_instantiate():
		return
	var panel = scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	var circle = panel.find_child("BreathCircle", true, false)
	var hit_button = panel.find_child("BreathHitButton", true, false)
	var exit_button = panel.find_child("MeditationExitButton", true, false)
	assert_true(circle != null, "cushion meditation mounts breathing circle")
	assert_true(hit_button is Button, "cushion meditation exposes hit button")
	assert_true(exit_button is Button, "cushion meditation exposes exit button")
	assert_true(panel.find_child("MeditationForgeStage", true, false) == null, "cushion meditation no longer mounts ForgeStage")
	assert_true(panel.has_method("breath_cycle_count"), "cushion meditation exposes breath_cycle_count")
	assert_true(panel.has_method("breath_duration_ms"), "cushion meditation exposes breath_duration_ms")
	if panel.has_method("breath_cycle_count"):
		var cycles := int(panel.call("breath_cycle_count"))
		assert_true(cycles >= 4 and cycles <= 6, "breathing meditation has 4-6 cycles")
	if panel.has_method("breath_duration_ms"):
		var duration := int(panel.call("breath_duration_ms"))
		assert_true(duration >= 29000 and duration <= 31000, "breathing meditation lasts about 30 seconds")
	panel.queue_free()


func test_rating_thresholds_cover_four_outcomes() -> void:
	if not _script_defines_method("rating_from_summary"):
		assert_true(false, "MeditationService exposes rating_from_summary")
		return
	assert_eq(str(MeditationServiceScript.rating_from_summary({"perfect": 6, "good": 0, "bad": 0, "miss": 0})), "perfect", "all perfect gives perfect rating")
	assert_eq(str(MeditationServiceScript.rating_from_summary({"perfect": 4, "good": 2, "bad": 0, "miss": 0})), "good", "mostly good gives good rating")
	assert_eq(str(MeditationServiceScript.rating_from_summary({"perfect": 2, "good": 1, "bad": 2, "miss": 1})), "ok", "mixed hits gives ok rating")
	assert_eq(str(MeditationServiceScript.rating_from_summary({"perfect": 0, "good": 1, "bad": 1, "miss": 4})), "failed", "many misses gives failed rating")


func test_resolve_session_awards_exp_and_pollution() -> void:
	if not _script_defines_method("resolve_session"):
		assert_true(false, "MeditationService exposes resolve_session")
		return
	var cases: Array = [
		{"summary": {"perfect": 6, "good": 0, "bad": 0, "miss": 0}, "rating": "perfect", "exp": 20, "pollution_delta": -1},
		{"summary": {"perfect": 4, "good": 2, "bad": 0, "miss": 0}, "rating": "good", "exp": 15, "pollution_delta": 0},
		{"summary": {"perfect": 2, "good": 1, "bad": 2, "miss": 1}, "rating": "ok", "exp": 10, "pollution_delta": 0},
		{"summary": {"perfect": 0, "good": 1, "bad": 1, "miss": 4}, "rating": "failed", "exp": 3, "pollution_delta": 2},
	]
	for entry in cases:
		var gs = _state()
		gs.ap = 12
		gs.pollution = 1
		var result: Dictionary = MeditationServiceScript.resolve_session(gs, entry["summary"])
		assert_eq(str(result.get("rating", "")), str(entry["rating"]), "rating %s resolves" % str(entry["rating"]))
		assert_eq(int(result.get("sequence_exp_delta", 0)), int(entry["exp"]), "rating %s exp delta" % str(entry["rating"]))
		assert_eq(int(result.get("pollution_delta", 99)), int(entry["pollution_delta"]), "rating %s pollution delta" % str(entry["rating"]))
		assert_eq(int(gs.sequence_exp), int(entry["exp"]), "rating %s writes sequence_exp" % str(entry["rating"]))
		assert_eq(int(gs.ap), 9, "rating %s spends 3 AP" % str(entry["rating"]))
		assert_eq(int(gs.meditation_count_today), 1, "rating %s increments daily count" % str(entry["rating"]))


func test_fog_weather_adds_twenty_percent_exp() -> void:
	if not _script_defines_method("resolve_session"):
		assert_true(false, "MeditationService exposes resolve_session for fog bonus")
		return
	var gs = _state()
	gs.current_weather = "fog"
	gs.pathway = "fool"
	var result: Dictionary = MeditationServiceScript.resolve_session(gs, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
	assert_eq(int(result.get("base_sequence_exp", 0)), 20, "perfect base exp is 20")
	assert_eq(int(result.get("sequence_exp_bonus_percent", 0)), 20, "fog fool bonus is 20 percent")
	assert_eq(int(result.get("sequence_exp_delta", 0)), 24, "fog perfect meditation grants 24 exp")
	assert_eq(int(gs.sequence_exp), 24, "fog bonus writes boosted sequence_exp")


func test_daily_limit_blocks_fourth_full_session() -> void:
	if not _script_defines_method("resolve_session"):
		assert_true(false, "MeditationService exposes resolve_session for daily limit")
		return
	var gs = _state()
	for i in range(3):
		var result: Dictionary = MeditationServiceScript.resolve_session(gs, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
		assert_true(bool(result.get("ok", false)), "full meditation #%d succeeds" % [i + 1])
	var fourth: Dictionary = MeditationServiceScript.resolve_session(gs, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
	assert_true(not bool(fourth.get("ok", true)), "fourth full meditation is blocked")
	assert_eq(str(fourth.get("reason", "")), "daily_limit", "fourth full meditation reports daily_limit")
	assert_eq(int(gs.meditation_count_today), 3, "blocked full meditation keeps count at 3")


func test_promotion_gate_check_runs_after_meditation_exp() -> void:
	if not _script_defines_method("resolve_session"):
		assert_true(false, "MeditationService exposes resolve_session for gate check")
		return
	var gs = _state()
	gs.sequence = 9
	gs.sequence_exp = 80
	gs.pollution = 10
	gs.known_reactions.clear()
	for reaction_id in ["rx0", "rx1", "rx2", "rx3", "rx4", "rx5", "rx6", "rx7"]:
		gs.known_reactions.append(reaction_id)
	gs.active_contract.clear()
	for rule_id in ["rule_a", "rule_b", "rule_c"]:
		gs.active_contract.append(rule_id)
	gs.daodian["completed_main_story_nodes"] = ["node_4_promotion_98"]
	var result: Dictionary = MeditationServiceScript.resolve_session(gs, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
	assert_eq(int(gs.sequence_exp), 100, "meditation reaches 9 to 8 exp threshold")
	assert_true(bool(result.get("promotion_available", false)), "meditation result reports promotion availability")
	assert_eq(str(result.get("promotion_gate_id", "")), "fool_9_to_8", "meditation result names available gate")
	assert_true(bool(gs.get_meta("promotion_prompt_pending", false)), "GameState meta marks promotion prompt pending")


func test_three_real_meditation_settlements_advance_time_to_night() -> void:
	var gs = _state()
	gs.ap = 12
	gs.time_of_day = "morning"
	for i in range(3):
		var result: Dictionary = MeditationServiceScript.resolve_session(gs, {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
		assert_true(bool(result.get("ok", false)), "meditation gameplay settlement #%d succeeds" % [i + 1])
	assert_eq(str(gs.time_of_day), "night", "three meditation gameplay settlements advance morning -> night")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _script_defines_method(method_name: String) -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/world/meditation_service.gd")
	return source.contains("func %s" % method_name)


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
