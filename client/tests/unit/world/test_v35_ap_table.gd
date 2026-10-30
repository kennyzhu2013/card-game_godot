extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const CommissionActionServiceScript = preload("res://scripts/world/commission_action_service.gd")
const DistrictSelectScript = preload("res://scripts/ui/district_select.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_v35_ap_table.gd --")
	test_ap_service_exposes_r10_v35_cost_table()
	test_slice2_live_action_costs_match_r10_v35()
	test_city_roaming_and_remote_district_travel_match_v35()
	test_npc_deep_dialogue_spends_one_ap_but_short_chat_is_free()
	await test_encounter_runner_spends_by_step_count()
	return {"passed": _passed, "failed": _failed}


func test_ap_service_exposes_r10_v35_cost_table() -> void:
	assert_eq(_ap_call("city_roam_cost"), 0, "R10 v3.5 city roaming costs 0 AP")
	assert_eq(ApServiceScript.district_travel_cost("shadow_alley"), 0, "ordinary district travel costs 0 AP")
	assert_eq(ApServiceScript.district_travel_cost("misty_port"), 0, "near district travel costs 0 AP")
	assert_eq(ApServiceScript.district_travel_cost("stone_tower"), 2, "stone_tower remote travel costs 2 AP")
	assert_eq(ApServiceScript.district_travel_cost("ascetic_mountain"), 2, "ascetic_mountain remote travel costs 2 AP")
	assert_eq(_ap_call("npc_dialogue_cost", [2, false]), 0, "NPC short chat under 3 rounds costs 0 AP")
	assert_eq(_ap_call("npc_dialogue_cost", [3, false]), 1, "NPC deep dialogue at 3 rounds costs 1 AP")
	assert_eq(_ap_call("npc_dialogue_cost", [1, true]), 1, "NPC relation threshold change costs 1 AP")
	assert_eq(_ap_call("listen_rumor_cost"), 1, "street rumor listening costs 1 AP")
	assert_eq(_ap_call("casino_round_cost"), 1, "casino single round costs 1 AP")
	assert_eq(_ap_call("auction_cost"), 1, "auction participation costs 1 AP")
	assert_eq(_ap_call("work_cost", ["factory"]), 3, "factory job costs 3 AP")
	assert_eq(_ap_call("work_cost", ["dock"]), 2, "dock job costs 2 AP")
	assert_eq(_ap_call("work_cost", ["mountain"]), 3, "mountain job costs 3 AP")
	assert_eq(_ap_call("work_cost", ["errand"]), 1, "errand job costs 1 AP")
	assert_eq(_ap_call("drill_cost", ["short"]), 1, "short acting drill costs 1 AP")
	assert_eq(_ap_call("drill_cost", ["noble_salon"]), 2, "noble salon drill costs 2 AP")
	assert_eq(_ap_call("passive_encounter_cost", [1]), 0, "one-step passive encounter costs 0 AP")
	assert_eq(_ap_call("passive_encounter_cost", [2]), 1, "two-step passive encounter costs 1 AP")
	assert_eq(_ap_call("passive_encounter_cost", [3]), 2, "three-step passive encounter costs 2 AP")
	assert_eq(_ap_call("passive_encounter_cost", [9]), 2, "passive encounter AP cost is capped at 2")


func test_slice2_live_action_costs_match_r10_v35() -> void:
	assert_eq(ApServiceScript.forge_cost_for_capacity(3), 2, "LINE forge costs 2 AP")
	assert_eq(ApServiceScript.forge_cost_for_capacity(4), 3, "L forge costs 3 AP")
	assert_eq(ApServiceScript.forge_cost_for_capacity(6), 3, "HEX forge costs 3 AP")
	assert_eq(ApServiceScript.MEDITATION_COST, 3, "meditation costs 3 AP")
	assert_eq(ApServiceScript.SLEEP_COST, 3, "sleep costs 3 AP")
	assert_eq(ApServiceScript.tower_cost_for_size("small"), 2, "small tower costs 2 AP")
	assert_eq(ApServiceScript.tower_cost_for_size("medium"), 4, "medium tower costs 4 AP")
	assert_eq(ApServiceScript.tower_cost_for_size("large"), 6, "large tower costs 6 AP")
	assert_eq(ApServiceScript.commission_execution_cost(false, ""), 1, "non-tower commission execution costs 1 AP")
	assert_eq(ApServiceScript.commission_execution_cost(true, "small"), 3, "tower commission stacks 1 AP plus small tower AP")

	var gs = _fresh_state()
	gs.ap = 6
	gs.accepted_commissions.append("errand")
	var result: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "errand", false, "")
	assert_true(bool(result.get("ok", false)), "non-tower commission execution succeeds")
	assert_eq(int(result.get("ap_cost", -1)), 1, "commission result reports 1 AP")
	assert_eq(int(gs.ap), 5, "commission execution spends exactly 1 AP")
	gs.queue_free()


func test_city_roaming_and_remote_district_travel_match_v35() -> void:
	var gs = _fresh_state()
	gs.ap = 0
	var shadow: Dictionary = DistrictSelectScript.enter_district("shadow_alley", gs)
	assert_true(bool(shadow.get("ok", false)), "shadow_alley city roaming succeeds at 0 AP")
	assert_eq(int(shadow.get("ap_cost", -1)), 0, "shadow_alley reports 0 AP entry")
	assert_eq(int(gs.ap), 0, "shadow_alley entry does not spend AP")

	gs.sequence = 8
	gs.ap = 1
	var stone_short: Dictionary = DistrictSelectScript.enter_district("stone_tower", gs)
	assert_true(not bool(stone_short.get("ok", true)), "stone_tower remote entry rejects AP short")
	assert_eq(str(stone_short.get("reason", "")), "ap_short", "stone_tower AP short reason")
	assert_eq(int(gs.ap), 1, "failed stone_tower entry does not spend AP")

	gs.ap = 4
	var stone: Dictionary = DistrictSelectScript.enter_district("stone_tower", gs)
	assert_true(bool(stone.get("ok", false)), "stone_tower remote entry succeeds when unlocked and funded")
	assert_eq(int(stone.get("ap_cost", -1)), 2, "stone_tower reports 2 AP remote travel")
	assert_eq(int(gs.ap), 2, "stone_tower spends exactly 2 AP")

	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	gs.ap = 5
	var ascetic: Dictionary = DistrictSelectScript.enter_district("ascetic_mountain", gs)
	assert_true(bool(ascetic.get("ok", false)), "ascetic_mountain remote entry succeeds after node_4")
	assert_eq(int(ascetic.get("ap_cost", -1)), 2, "ascetic_mountain reports 2 AP remote travel")
	assert_eq(int(gs.ap), 3, "ascetic_mountain spends exactly 2 AP")
	gs.queue_free()


func test_npc_deep_dialogue_spends_one_ap_but_short_chat_is_free() -> void:
	var service := NpcInteractionServiceScript.new()
	var gs = _fresh_state()
	gs.day = 5
	gs.ap = 3

	var short_result: Dictionary = service.commit_dialogue_outcome("old_li", {
		"dialogue_rounds": 2,
		"trust_delta": 0,
	}, gs)
	assert_true(bool(short_result.get("ok", false)), "short NPC chat commits")
	assert_eq(int(short_result.get("ap_cost", -1)), 0, "short NPC chat reports 0 AP")
	assert_eq(int(gs.ap), 3, "short NPC chat does not spend AP")

	var deep_result: Dictionary = service.commit_dialogue_outcome("old_li", {
		"dialogue_rounds": 3,
		"trust_delta": 0,
	}, gs)
	assert_true(bool(deep_result.get("ok", false)), "deep NPC dialogue commits with enough AP")
	assert_eq(int(deep_result.get("ap_cost", -1)), 1, "deep NPC dialogue reports 1 AP")
	assert_eq(int(gs.ap), 2, "deep NPC dialogue spends exactly 1 AP")

	var relation_state = gs.npc_relations["old_li"]
	relation_state.trust = 29
	var threshold_result: Dictionary = service.commit_dialogue_outcome("old_li", {
		"dialogue_rounds": 1,
		"trust_delta": 1,
	}, gs)
	assert_true(bool(threshold_result.get("ok", false)), "relation-threshold dialogue commits")
	assert_eq(int(threshold_result.get("ap_cost", -1)), 1, "threshold-changing dialogue reports deep-dialogue AP")
	assert_eq(int(gs.ap), 1, "threshold-changing dialogue spends exactly 1 AP")

	gs.ap = 0
	relation_state.trust = 59
	var blocked: Dictionary = service.commit_dialogue_outcome("old_li", {
		"dialogue_rounds": 3,
		"trust_delta": 10,
	}, gs)
	assert_true(not bool(blocked.get("ok", true)), "deep NPC dialogue is blocked when AP is short")
	assert_eq(str(blocked.get("reason", "")), "ap_short", "deep dialogue AP short reason")
	assert_eq(int(relation_state.trust), 59, "AP-short deep dialogue does not mutate relation trust")
	gs.queue_free()


func test_encounter_runner_spends_by_step_count() -> void:
	var runner := EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame

	var gs = _fresh_state()
	gs.ap = 3
	var one_step: Dictionary = _runner_start(runner, _encounter("enc_one_step", 1), gs)
	assert_true(bool(one_step.get("ok", false)), "one-step encounter starts")
	assert_eq(int(one_step.get("ap_cost", -1)), 0, "one-step encounter reports 0 AP")
	assert_eq(int(gs.ap), 3, "one-step encounter does not spend AP")
	runner.resolve_choice("leave")

	var three_step: Dictionary = _runner_start(runner, _encounter("enc_three_step", 3), gs)
	assert_true(bool(three_step.get("ok", false)), "three-step encounter starts")
	assert_eq(int(three_step.get("ap_cost", -1)), 2, "three-step encounter reports 2 AP")
	assert_eq(int(gs.ap), 1, "three-step encounter spends exactly 2 AP")
	runner.resolve_choice("leave")

	gs.ap = 1
	var blocked: Dictionary = _runner_start(runner, _encounter("enc_blocked", 3), gs)
	assert_true(not bool(blocked.get("ok", true)), "three-step encounter is blocked when AP is short")
	assert_eq(str(blocked.get("reason", "")), "ap_short", "encounter AP short reason")
	assert_true(not runner.visible, "AP-short encounter runner stays hidden")
	assert_eq(int(gs.ap), 1, "AP-short encounter does not spend AP")
	runner.queue_free()
	gs.queue_free()


func _encounter(encounter_id: String, step_count: int) -> Dictionary:
	return {
		"id": encounter_id,
		"display_name": encounter_id,
		"step_count": step_count,
		"scene_payload": {
			"text": "encounter body",
			"choices": [
				{"id": "leave", "label": "Leave", "outcome": {}},
			],
		},
	}


func _ap_call(method_name: String, args: Array = []) -> Variant:
	if not _script_has_method(ApServiceScript, method_name):
		assert_true(false, "ApService.%s exists" % method_name)
		return null
	var service = ApServiceScript.new()
	return service.callv(method_name, args)


func _runner_start(runner, encounter: Dictionary, gs) -> Dictionary:
	var value = runner.call("start", encounter, gs)
	if value is Dictionary:
		return value
	assert_true(false, "EncounterRunner.start returns a result Dictionary")
	return {}


func _script_has_method(script: Script, method_name: String) -> bool:
	for method in script.get_script_method_list():
		if str(method.get("name", "")) == method_name:
			return true
	return false


func _fresh_state():
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
