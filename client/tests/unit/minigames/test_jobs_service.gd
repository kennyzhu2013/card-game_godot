extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const SERVICE_PATH := "res://scripts/world/job_service.gd"
const EXPECTED_JOBS := {
	"factory_shift": {"city": "steelworks", "ap_cost": 3, "mechanic": "phigros_simple"},
	"dock_shift": {"city": "misty_port", "ap_cost": 2, "mechanic": "dock_work"},
	"fishing_shift": {"city": "misty_port", "ap_cost": 2, "mechanic": "dock_work"},
	"errand_runner": {"city": "shadow_alley", "ap_cost": 1, "mechanic": "errand_route"},
	"worship_observation": {"city": "sacred_seven", "ap_cost": 1, "mechanic": "worship_rhythm"},
	"mountain_solitary_walk": {"city": "ascetic_mountain", "ap_cost": 3, "mechanic": "mountain_dodge"},
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_jobs_service.gd --")
	test_all_job_definitions_are_structured()
	test_factory_job_reuses_phigros_chart_and_applies_outcome()
	test_dock_errand_worship_and_mountain_jobs()
	test_job_failures_apply_penalties()
	return {"passed": _passed, "failed": _failed}


func test_all_job_definitions_are_structured() -> void:
	var service = _service()
	if service == null:
		return
	assert_true(service.has_method("load_job_definition"), "JobService exposes load_job_definition")
	if not service.has_method("load_job_definition"):
		return
	for job_id in EXPECTED_JOBS.keys():
		var definition: Dictionary = service.call("load_job_definition", job_id)
		var spec: Dictionary = EXPECTED_JOBS[job_id]
		assert_eq(str(definition.get("id", "")), job_id, "%s definition loads by structured id" % job_id)
		assert_eq(str(definition.get("type", "")), "job", "%s definition type is job" % job_id)
		assert_eq(str(definition.get("city", "")), str(spec.get("city", "")), "%s city matches R25 table" % job_id)
		assert_eq(int(definition.get("ap_cost", -1)), int(spec.get("ap_cost", -1)), "%s AP matches R25 table" % job_id)
		assert_eq(str(definition.get("mechanic", "")), str(spec.get("mechanic", "")), "%s mechanic is structured" % job_id)
		assert_true(definition.get("outcome_table", []) is Array and (definition.get("outcome_table", []) as Array).size() > 0, "%s has outcome_table" % job_id)


func test_factory_job_reuses_phigros_chart_and_applies_outcome() -> void:
	var service = _service()
	if service == null or not service.has_method("start_job"):
		assert_true(false, "JobService exposes start_job")
		return
	var gs = _state()
	gs.day = 4
	gs.time_of_day = "morning"
	gs.ap = 12
	gs.lingstones = 0
	var result: Dictionary = service.call("start_job", gs, "factory_shift", {"grade": "perfect"})
	assert_true(bool(result.get("ok", false)), "factory_shift perfect starts and settles")
	assert_eq(str(result.get("mechanic", "")), "phigros_simple", "factory_shift reports phigros_simple mechanic")
	assert_eq(int(result.get("chart_note_count", 0)), 6, "factory_shift reuses a 6-beat Phigros chart")
	assert_eq(int(result.get("ap_cost", 0)), 3, "factory_shift reports 3 AP cost")
	assert_eq(int(gs.ap), 9, "factory_shift spends 3 AP")
	assert_eq(int(gs.lingstones), 120, "factory perfect pays 120 lingstones")
	assert_eq(int(gs.forge_materials.get("steel_fiber", 0)), 1, "factory perfect grants steel_fiber")
	var blocked: Dictionary = service.call("start_job", gs, "factory_shift", {"grade": "perfect"})
	assert_true(not bool(blocked.get("ok", true)), "factory_shift second same-day run is blocked")
	assert_eq(str(blocked.get("reason", "")), "daily_limit", "factory_shift daily limit reason")
	gs.queue_free()


func test_dock_errand_worship_and_mountain_jobs() -> void:
	var service = _service()
	if service == null or not service.has_method("start_job"):
		assert_true(false, "JobService exposes start_job for non-factory jobs")
		return
	var dock = _state()
	dock.ap = 12
	var cargo: Dictionary = service.call("start_job", dock, "dock_shift", {"mode": "cargo"})
	assert_true(bool(cargo.get("ok", false)), "dock cargo shift settles")
	assert_eq(int(dock.ap), 10, "dock cargo spends 2 AP")
	assert_eq(int(dock.lingstones), 60, "dock cargo pays 50 lingstones over the 10 starting balance")
	assert_eq(int(dock.forge_materials.get("mist_salt", 0)), 1, "dock cargo grants mist_salt")
	dock.queue_free()

	var fishing = _state()
	fishing.ap = 12
	var fish: Dictionary = service.call("start_job", fishing, "dock_shift", {"mode": "fishing", "roll": 0.01})
	assert_true(bool(fish.get("ok", false)), "dock fishing shift settles")
	assert_eq(int(fishing.dao_pages), 1, "dock fishing can catch a dao page at 5 percent roll")
	fishing.queue_free()

	var npc_fishing = _state()
	npc_fishing.ap = 12
	var npc_fish: Dictionary = service.call("start_job", npc_fishing, "fishing_shift", {"mode": "fishing", "roll": 0.01})
	assert_true(bool(npc_fish.get("ok", false)), "NPC fishing_shift settles as a real job module")
	assert_eq(int(npc_fish.get("ap_cost", 0)), 2, "NPC fishing_shift reports 2 AP cost")
	assert_eq(int(npc_fishing.ap), 10, "NPC fishing_shift spends 2 AP")
	assert_eq(int(npc_fishing.dao_pages), 1, "NPC fishing_shift can catch a dao page")
	npc_fishing.queue_free()

	var errand = _state()
	errand.ap = 1
	var letter: Dictionary = service.call("start_job", errand, "errand_runner", {"same_district": true})
	assert_true(bool(letter.get("ok", false)), "same-district errand uses the low AP option")
	assert_eq(int(letter.get("ap_cost", -1)), 0, "same-district errand rounds 0.5 AP down to 0 in the integer AP table")
	assert_eq(int(errand.ap), 1, "same-district errand does not spend whole AP")
	assert_true((errand.daodian.get("pending_intel_rewards", []) as Array).size() == 1, "errand queues one R26 intel reward placeholder")
	errand.queue_free()

	var worship = _state()
	worship.day = 7
	worship.time_of_day = "morning"
	worship.ap = 12
	worship.church_awareness = 5
	var prayer: Dictionary = service.call("start_job", worship, "worship_observation", {"grade": "perfect"})
	assert_true(bool(prayer.get("ok", false)), "worship observation succeeds on Sunday morning")
	assert_eq(int(worship.sequence_exp), 5, "worship perfect grants 5 sequence exp")
	assert_eq(int(worship.church_awareness), 3, "worship perfect lowers church awareness by 2")
	worship.time_of_day = "morning"
	var weekly_block: Dictionary = service.call("start_job", worship, "worship_observation", {"grade": "perfect"})
	assert_eq(str(weekly_block.get("reason", "")), "weekly_limit", "worship observation is weekly-limited")
	worship.queue_free()

	var polluted = _state()
	polluted.day = 7
	polluted.time_of_day = "morning"
	polluted.pollution = 50
	var pollution_block: Dictionary = service.call("start_job", polluted, "worship_observation", {"grade": "perfect"})
	assert_eq(str(pollution_block.get("reason", "")), "pollution_blocked", "pollution >=50 blocks worship observation")
	polluted.queue_free()

	var mountain = _state()
	mountain.current_weather = "fog"
	mountain.ap = 12
	mountain.daodian["completed_main_story_nodes"] = ["node_4"]
	var walk: Dictionary = service.call("start_job", mountain, "mountain_solitary_walk", {"grade": "perfect"})
	assert_true(bool(walk.get("ok", false)), "mountain solitary walk succeeds")
	assert_eq(int(walk.get("sequence_exp_delta", 0)), 24, "fog weather applies +20 percent sequence exp to mountain walk")
	assert_eq(int(mountain.forge_materials.get("mica_powder", 0)), 1, "mountain perfect grants mica_powder")
	mountain.queue_free()


func test_job_failures_apply_penalties() -> void:
	var service = _service()
	if service == null or not service.has_method("start_job"):
		assert_true(false, "JobService exposes start_job for failure paths")
		return
	var factory = _state()
	factory.ap = 12
	var failed_factory: Dictionary = service.call("start_job", factory, "factory_shift", {"grade": "fail"})
	assert_true(bool(failed_factory.get("ok", false)), "factory fail still settles")
	assert_eq(int(factory.lingstones), 40, "factory fail pays 30 lingstones over starting balance")
	assert_eq(int(factory.pollution), 1, "factory fail adds pollution +1")
	factory.queue_free()

	var worship = _state()
	worship.day = 7
	worship.time_of_day = "morning"
	worship.ap = 12
	worship.church_awareness = 9
	worship.set_ai_gm_service(FakeThresholdAIGMService.new())
	var failed_worship: Dictionary = service.call("start_job", worship, "worship_observation", {"grade": "fail"})
	assert_true(bool(failed_worship.get("ok", false)), "worship fail settles")
	assert_eq(int(worship.sequence_exp), 0, "worship fail grants no sequence exp")
	assert_eq(int(worship.church_awareness), 12, "worship fail raises church awareness by 3")
	assert_true(_has_threshold(worship, 10), "worship failure crossing 10 records church threshold event")
	assert_true(_threshold_ai_text(worship, 10) != "", "worship failure threshold event stores AI GM text")
	worship.queue_free()


func _service():
	var script = load(SERVICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "JobService script loads and can instantiate")
		return null
	return script.new()


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _has_threshold(gs, threshold: int) -> bool:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return true
	return false


func _threshold_ai_text(gs, threshold: int) -> String:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return str((event as Dictionary).get("ai_gm_text", "")).strip_edges()
	return ""


class FakeThresholdAIGMService:
	extends RefCounted

	func call_ai_gm(_ctx) -> String:
		return "church threshold test text"


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
