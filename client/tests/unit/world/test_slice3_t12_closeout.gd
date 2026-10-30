extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const CycleEndServiceScript = preload("res://scripts/world/cycle_end_service.gd")
const JobServiceScript = preload("res://scripts/world/job_service.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const DiceMinigameScript = preload("res://scripts/minigames/casino/dice_minigame.gd")
const TarotMinigameScript = preload("res://scripts/minigames/casino/tarot_minigame.gd")
const FateMinigameScript = preload("res://scripts/minigames/casino/fate_minigame.gd")

const AUTO_SAVE_PATH := "user://slice3_t12_cycle_probe.json"
const BLACK_MARKET_POOL := "res://data/shops/donen_blackmarket.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_slice3_t12_closeout.gd --")
	test_day_1_to_day_14_cycle_proxy_runs_mainline_hooks()
	test_r16_v35_economy_samples_stay_in_target_ranges()
	test_r24_relation_feedback_has_bounded_buffs_and_debuffs()
	test_casino_1000_sample_has_negative_expected_money_flow()
	test_t12_closeout_docs_and_no_commit_boundary_are_recorded()
	return {"passed": _passed, "failed": _failed}


func test_day_1_to_day_14_cycle_proxy_runs_mainline_hooks() -> void:
	var gs = _state()
	gs.day = 1
	gs.cycle = 1
	gs.ap = 12
	gs.ap_max = 12
	gs.time_of_day = "morning"
	var triggered_days: Array[int] = []
	var forced_towers: Dictionary = {}
	while int(gs.day) < 14:
		if int(gs.day) == 11:
			gs.church_awareness = 25
		var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH, 0.0)
		assert_true(bool(result.get("ok", false)), "sleep step succeeds in Day 1 -> Day 14 proxy")
		var hook: Dictionary = result.get("day_hook", {}) if result.get("day_hook", {}) is Dictionary else {}
		if bool(hook.get("triggered", false)):
			var hook_day := int(hook.get("day", 0))
			triggered_days.append(hook_day)
			forced_towers[hook_day] = hook.get("forced_tower", {})
	assert_eq(int(gs.day), 14, "cycle proxy reaches Day 14")
	assert_true(triggered_days.has(7), "cycle proxy triggers Day 7 hook")
	assert_true(triggered_days.has(12), "cycle proxy triggers Day 12 hook")
	assert_true(triggered_days.has(14), "cycle proxy triggers Day 14 hook")
	var day7: Dictionary = forced_towers.get(7, {}) if forced_towers.get(7, {}) is Dictionary else {}
	var day12: Dictionary = forced_towers.get(12, {}) if forced_towers.get(12, {}) is Dictionary else {}
	var day14: Dictionary = forced_towers.get(14, {}) if forced_towers.get(14, {}) is Dictionary else {}
	assert_eq(str(day7.get("tower_size", "")), "medium", "Day 7 proxy carries medium tower")
	assert_eq(str(day12.get("tower_template", "")), "church_investigation", "Day 12 proxy carries church investigation tower")
	assert_eq(str(day14.get("tower_size", "")), "large", "Day 14 proxy carries large final tower")
	var close: Dictionary = CycleEndServiceScript.complete_cycle(gs)
	assert_true(bool(close.get("ok", false)), "cycle closeout service completes after Day 14 proxy")
	assert_eq(int(gs.cycle), 2, "cycle closeout increments to cycle 2")
	assert_eq(int(gs.day), 1, "cycle closeout resets to Day 1")


func test_r16_v35_economy_samples_stay_in_target_ranges() -> void:
	var factory := _job_lingstones("factory_shift", "perfect")
	var dock := _job_lingstones("dock_shift", "cargo_success")
	var errand := _job_lingstones("errand_runner", "complete")
	assert_between(factory, 80, 120, "factory job pays within R16 v3.5 80-120 range")
	assert_between(dock, 30, 50, "dock job pays within R16 v3.5 30-50 range")
	assert_eq(errand, 30, "errand job pays the R16 v3.5 30 lingstones")
	var sampled_week_flow := (factory * 7) + (dock * 7) + (errand * 7)
	assert_between(sampled_week_flow, 500, 3000, "sampled weekly job flow fits R16 v3.5 500-3000 target")

	var fate_state = _state()
	fate_state.day = 5
	fate_state.ap = 12
	fate_state.lingstones = 200
	var fate: Dictionary = FateMinigameScript.new().play(fate_state, {
		"bet": 200,
		"choice_id": "truth",
		"truth_id": "truth",
		"advance_node_id": "node_t12_probe",
	})
	assert_true(bool(fate.get("ok", false)), "fate cards correct result settles for dao-page flow sample")
	assert_eq(int(fate_state.lingstones), 0, "fate cards consumes the fixed 200 lingstone bet")
	assert_eq(int(fate_state.dao_pages), 1, "fate cards win adds one dao page")

	var market := _json(BLACK_MARKET_POOL)
	assert_true(_pool_has_sku(market, "dao_page_x1"), "black-market pool contains 500 lingstone -> dao page SKU")


func test_r24_relation_feedback_has_bounded_buffs_and_debuffs() -> void:
	var library = NpcLibraryScript.new()
	var loaded: Dictionary = library.load_all()
	assert_true(bool(loaded.get("ok", false)), "NPC library loads for relation feedback balance audit")
	for npc_id in library.all_ids():
		var npc: Dictionary = library.get_definition(str(npc_id))
		var free_card_buffs := 0
		var rule_buffs := 0
		for buff in _array(npc.get("buff_unlocks_on_trust", [])):
			if not buff is Dictionary:
				continue
			match str((buff as Dictionary).get("type", "")):
				"free_temp_card":
					free_card_buffs += 1
				"rule_unlock":
					rule_buffs += 1
		assert_true(free_card_buffs <= 1, "%s grants at most one free temp card buff" % str(npc_id))
		assert_true(rule_buffs <= 1, "%s grants at most one rule unlock buff" % str(npc_id))
		for debuff in _array(npc.get("debuff_triggers_on_suspicion", [])):
			if not debuff is Dictionary:
				continue
			var payload: Dictionary = (debuff as Dictionary).get("payload", {}) if (debuff as Dictionary).get("payload", {}) is Dictionary else {}
			if str((debuff as Dictionary).get("type", "")) == "tower_extra_elite":
				assert_true(float(payload.get("chance", 0.0)) <= 0.30, "%s tower_extra_elite chance is <= 30%%" % str(npc_id))
			if str((debuff as Dictionary).get("type", "")) == "report_to_church":
				assert_true(int(payload.get("church_awareness", 0)) <= 10, "%s report_to_church awareness delta is <= 10" % str(npc_id))


func test_casino_1000_sample_has_negative_expected_money_flow() -> void:
	var dice = DiceMinigameScript.new()
	var dice_big_net := 0
	var dice_triple_net := 0
	for i in range(1000):
		var dice_values := _dice_for_index(i % 216)
		dice_big_net += dice._net_for_choice("big", dice_values, 30)
		dice_triple_net += dice._net_for_choice("triple", dice_values, 30)
	assert_true(dice_big_net < 0, "1000-sample dice big betting has negative money flow")
	assert_true(dice_triple_net < 0, "1000-sample dice triple betting has negative money flow")

	var tarot = TarotMinigameScript.new()
	var tarot_net := 0
	for i in range(1000):
		var grade := tarot.grade_for_roll(float(i) / 1000.0)
		tarot_net += int(floor(100.0 * _tarot_multiplier(tarot, grade))) - 100
	assert_true(tarot_net < 0, "1000-sample tarot betting has negative money flow")

	var fate_state = _state()
	fate_state.day = 5
	fate_state.ap = 12
	fate_state.lingstones = 600
	var fate = FateMinigameScript.new()
	var first: Dictionary = fate.play(fate_state, {"bet": 200, "choice_id": "a", "truth_id": "a"})
	var second: Dictionary = fate.play(fate_state, {"bet": 200, "choice_id": "b", "truth_id": "a"})
	var third: Dictionary = fate.play(fate_state, {"bet": 200, "choice_id": "a", "truth_id": "a"})
	assert_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "fate cards allows two cycle plays")
	assert_true(not bool(third.get("ok", true)), "fate cards blocks third cycle play")
	assert_eq(str(third.get("reason", "")), "cycle_limit", "fate cards third play reports cycle_limit")


func test_t12_closeout_docs_and_no_commit_boundary_are_recorded() -> void:
	var plan := _read_doc("res://../docs/SLICE_3_PLAN.md")
	var progress := _read_doc("res://../docs/SLICE_3_PROGRESS.md")
	var manual := _read_doc("res://../docs/SLICE_3_MANUAL_QA.md")
	var big := _read_doc("res://../docs/SLICE_BIG_PROGRESS.md")
	var project_status := _read_doc("res://../docs/PROJECT_STATUS.md")
	var agent_progress := _read_doc("res://../output/agent-progress.md")
	var webqa := _read_doc("res://../output/webqa/artifacts/webqa-summary.md")
	assert_true(plan.contains("| T12 | 集成手测 + 平衡调优 + 测试基线 + commit | 4 d | ✅ |"), "Slice 3 plan marks T12 complete")
	assert_true(progress.contains("## T12 Evidence"), "Slice 3 progress contains T12 evidence section")
	assert_true(progress.contains("slice3_t12_final_verify_stdout.log"), "Slice 3 progress records T12 final verify log")
	assert_true(manual.contains("## Human Path After T12"), "Manual QA contains T12 human path")
	assert_true(manual.contains("Day 1 -> Day 14"), "Manual QA records Day 1 -> Day 14 closeout path")
	assert_true(manual.contains("1000"), "Manual QA records the 1000-sample minigame balance check")
	assert_true(big.contains("batch-epsilon T12 RED/GREEN baseline") or big.contains("batch epsilon T12 RED/GREEN baseline"), "Big progress records T12 baseline")
	assert_true(project_status.contains("Slice 3 T1-T12 are code/test/doc/final-verify complete"), "Project status marks Slice 3 T1-T12 complete")
	assert_true(agent_progress.contains("Slice 3 T1-T12 are code/test/doc/final-verify complete"), "Agent progress marks Slice 3 T1-T12 complete")
	assert_true(agent_progress.contains("No commit was created") or agent_progress.contains("no commit was created"), "Agent progress records no-commit boundary")
	assert_true(webqa.contains("status: blocked"), "WebQA summary records blocked status")
	assert_true(webqa.contains("export_templates"), "WebQA summary records the missing Godot export-template blocker")
	assert_true(webqa.contains("web_nothreads_debug.zip") or webqa.contains("web_nothreads_release.zip"), "WebQA summary points to the missing Web export templates")


func _job_lingstones(job_id: String, grade: String) -> int:
	var gs = _state()
	gs.ap = 12
	gs.lingstones = 0
	gs.time_of_day = "morning"
	if job_id == "dock_shift":
		gs.time_of_day = "noon"
	var result: Dictionary = JobServiceScript.new().start_job(gs, job_id, {"grade": grade})
	assert_true(bool(result.get("ok", false)), "%s %s settles for economy sample" % [job_id, grade])
	return int(gs.lingstones)


func _pool_has_sku(pool: Dictionary, sku_id: String) -> bool:
	for raw_item in _array(pool.get("items", pool.get("offers", []))):
		if raw_item is Dictionary and str((raw_item as Dictionary).get("id", "")) == sku_id:
			return true
	return false


func _dice_for_index(index: int) -> Array:
	var value := index % 216
	var d1 := int(floor(float(value) / 36.0)) + 1
	var d2 := int(floor(float(value % 36) / 6.0)) + 1
	var d3 := int(value % 6) + 1
	return [d1, d2, d3]


func _tarot_multiplier(tarot, grade: String) -> float:
	for mode in tarot.outcome_modes():
		if mode is Dictionary and str((mode as Dictionary).get("id", "")) == grade:
			return float((mode as Dictionary).get("payout_multiplier", 0.0))
	return 0.0


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		assert_true(false, "%s exists" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed.duplicate(true)
	assert_true(false, "%s parses as Dictionary" % path)
	return {}


func _read_doc(relative_path: String) -> String:
	var abs_path := ProjectSettings.globalize_path(relative_path)
	if not FileAccess.file_exists(abs_path):
		assert_true(false, "%s exists" % relative_path)
		return ""
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		assert_true(false, "%s opens" % relative_path)
		return ""
	return file.get_as_text()


func _array(value: Variant) -> Array:
	return value if value is Array else []


func assert_between(actual: int, minimum: int, maximum: int, message: String) -> void:
	var ok := actual >= minimum and actual <= maximum
	if ok:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected %d..%d, got %d" % [message, minimum, maximum, actual])


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
