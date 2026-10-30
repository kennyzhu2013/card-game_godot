extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")

const NPC_LIBRARY_PATH := "res://scripts/world/npc_library.gd"
const NPC_SERVICE_PATH := "res://scripts/world/npc_interaction_service.gd"
const IDENTITY_PICKER_PATH := "res://scripts/world/identity_picker_dialog.gd"
const JOB_SERVICE_PATH := "res://scripts/world/job_service.gd"
const DRILL_RUNNER_PATH := "res://scripts/world/drill_runner.gd"

var _passed := 0
var _failed := 0


class FakeDialogicAdapter:
	var started_timelines: Array[String] = []
	var variables: Dictionary = {}

	func start(timeline_id: String) -> void:
		started_timelines.append(timeline_id)

	func set_variable(variable_name: String, value: Variant) -> void:
		variables[variable_name] = value


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "hub npc ai gm visible text"


func run() -> Dictionary:
	print("\n-- test_npc_interaction_service.gd --")
	test_npc_knowledge_state_r24_fields_roundtrip()
	test_npc_library_loads_18_static_definitions()
	test_open_dialogue_binds_dialogic_variables()
	test_commit_dialogue_outcome_updates_single_game_state_source()
	test_ask_intel_spends_lingstones_and_grants_active_rumor()
	test_ask_intel_blocks_when_trust_too_low()
	test_ask_intel_blocks_when_lingstones_short()
	test_npc_commission_templates_are_filtered_by_day_and_state()
	test_accept_npc_commission_adds_real_commission_to_board_state()
	test_npc_activity_refs_are_real_job_and_drill_ids()
	test_npc_activity_lookup_filters_real_options_and_costs()
	test_identity_picker_defaults_to_harvey_in_slice_2_5()
	test_residual_identity_option_selects_current_identity_for_npc()
	test_project_dialogic_variables_include_r24_binding_keys()
	await test_hub_city_npc_hotspot_opens_dialogue_path()
	await test_hub_city_npc_dialogue_shows_ai_gm_first_meet_text()
	await test_hub_npc_dialogue_main_window_uses_layered_menu_not_activity_wall()
	await test_hub_npc_hotspot_does_not_leave_city_chant_wall_visible()
	await test_hub_npc_dialogue_suppresses_city_surface_buttons()
	await test_hub_npc_talk_menu_exposes_timeline_branch_buttons()
	await test_hub_npc_dialogue_deep_chat_spends_ap_and_updates_relation()
	await test_hub_npc_dialogue_action_buttons_mount_in_dialog_action_row()
	await test_hub_npc_dialogue_deep_chat_blocks_when_ap_short()
	await test_hub_npc_dialogue_exposes_daily_opportunity_button()
	await test_hub_npc_dialogue_keeps_paid_intel_off_npc_surface()
	await test_hub_npc_dialogue_exposes_real_commission_button()
	await test_hub_npc_dialogue_keeps_job_and_drill_buttons_off_npc_surface()
	return {"passed": _passed, "failed": _failed}


func test_npc_knowledge_state_r24_fields_roundtrip() -> void:
	var state = NpcKnowledgeStateScript.new()
	assert_true(state.get("dialogue_state") is Dictionary, "NpcKnowledgeState has dialogue_state Dictionary")
	assert_true(state.get("unlocked_dialogue_branches") is Array, "NpcKnowledgeState has unlocked_dialogue_branches Array")
	assert_eq(int(state.get("last_seen_day")), -1, "NpcKnowledgeState last_seen_day defaults to -1")
	assert_true(state.get("pending_gifts") is Array, "NpcKnowledgeState has pending_gifts Array")

	state.dialogue_state = {"node_id": "old_li.first_meet"}
	var branches: Array[String] = ["old_li.ask_market"]
	state.unlocked_dialogue_branches = branches
	state.last_seen_day = 6
	state.pending_gifts = [{"item_id": "tea", "amount": 1}]
	var restored = NpcKnowledgeStateScript.from_dict(state.to_dict())
	assert_eq(restored.dialogue_state.get("node_id", ""), "old_li.first_meet", "dialogue_state roundtrips")
	assert_eq(restored.unlocked_dialogue_branches, ["old_li.ask_market"], "unlocked_dialogue_branches roundtrips")
	assert_eq(restored.last_seen_day, 6, "last_seen_day roundtrips")
	assert_eq(restored.pending_gifts.size(), 1, "pending_gifts roundtrips")


func test_npc_library_loads_18_static_definitions() -> void:
	var library = _new_instance(NPC_LIBRARY_PATH, "NpcLibrary")
	if library == null:
		return
	var load_result: Dictionary = library.load_all()
	assert_true(bool(load_result.get("ok", false)), "NpcLibrary.load_all succeeds")
	var ids: Array = library.all_ids()
	assert_eq(ids.size(), 18, "NpcLibrary loads exactly 18 NPC definitions")
	assert_true(ids.has("old_li"), "NpcLibrary includes old_li")
	assert_true(ids.has("xiao_ran"), "NpcLibrary includes xiao_ran")
	assert_true(ids.has("widow_isa"), "NpcLibrary includes slice 4 placeholder widow_isa")
	var old_li: Dictionary = library.get_definition("old_li")
	assert_eq(str(old_li.get("default_district", "")), "shadow_alley", "old_li default district is shadow_alley")
	assert_true(old_li.get("city_presence", []) is Array, "old_li has city_presence array")
	assert_eq(str(old_li.get("dialogue_tree", "")), "old_li_main", "old_li dialogue_tree is old_li_main")
	assert_true(old_li.get("buff_unlocks_on_trust", []) is Array, "old_li has buff_unlocks_on_trust")
	var placeholder: Dictionary = library.get_definition("red_hand_carl")
	assert_true(not bool(placeholder.get("placeholder", false)), "Slice 3 T4 NPC definitions are no longer placeholders")


func test_open_dialogue_binds_dialogic_variables() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 5
	gs.sequence = 8
	gs.pollution = 17
	gs.current_weather = "fog"
	gs.time_of_day = "night"
	var state = NpcKnowledgeStateScript.new()
	state.trust = 42
	state.suspicion = 7
	state.layer_revealed = 1
	state.active_perception = "stranger"
	state.dialog_count = 3
	gs.npc_relations["old_li"] = state
	var adapter := FakeDialogicAdapter.new()

	var result: Dictionary = service.open_dialogue("old_li", gs, adapter)
	assert_true(bool(result.get("ok", false)), "open_dialogue succeeds for old_li")
	assert_eq(str(result.get("timeline_id", "")), "npc/old_li_main", "open_dialogue starts npc timeline")
	assert_eq(adapter.started_timelines, ["npc/old_li_main"], "Dialogic adapter receives timeline start")
	assert_eq(adapter.variables.get("npc_trust", -1), 42, "Dialogic npc_trust bound")
	assert_eq(adapter.variables.get("npc_suspicion", -1), 7, "Dialogic npc_suspicion bound")
	assert_eq(adapter.variables.get("npc_layer", -1), 1, "Dialogic npc_layer bound")
	assert_eq(adapter.variables.get("npc_perception", ""), "stranger", "Dialogic npc_perception bound")
	assert_eq(adapter.variables.get("npc_dialog_count", -1), 3, "Dialogic npc_dialog_count bound")
	assert_eq(adapter.variables.get("player_sequence", -1), 8, "Dialogic player_sequence bound")
	assert_eq(adapter.variables.get("player_pollution", -1), 17, "Dialogic player_pollution bound")
	assert_eq(adapter.variables.get("current_day", -1), 5, "Dialogic current_day bound")
	assert_eq(adapter.variables.get("current_weather", ""), "fog", "Dialogic current_weather bound")
	assert_eq(adapter.variables.get("time_of_day", ""), "night", "Dialogic time_of_day bound")
	gs.queue_free()


func test_commit_dialogue_outcome_updates_single_game_state_source() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 4
	var state = NpcKnowledgeStateScript.new()
	state.trust = 29
	state.suspicion = 98
	gs.npc_relations["old_li"] = state

	var result: Dictionary = service.commit_dialogue_outcome("old_li", {
		"trust_delta": 5,
		"suspicion_delta": 5,
		"layer_revealed_to": 1,
		"unlocked_dialogue_branches": ["old_li.ask_rules"],
		"pending_gifts": [{"item_id": "tea", "amount": 1}]
	}, gs)
	assert_true(bool(result.get("ok", false)), "commit_dialogue_outcome returns ok")
	assert_eq(state.trust, 34, "commit updates trust on GameState relation")
	assert_eq(state.suspicion, 100, "commit clamps suspicion to 100")
	assert_eq(state.layer_revealed, 1, "commit raises layer_revealed")
	assert_eq(state.dialog_count, 1, "commit increments dialog_count")
	assert_eq(state.last_seen_day, 4, "commit writes last_seen_day from GameState.day")
	assert_true(state.unlocked_dialogue_branches.has("old_li.ask_rules"), "commit records unlocked dialogue branch")
	assert_eq(state.pending_gifts.size(), 1, "commit records pending gifts")
	assert_true(result.get("triggered_thresholds", []).has("acquainted"), "trust crossing 30 triggers acquainted threshold")

	var buff_result: Dictionary = service.commit_dialogue_outcome("old_li", {"trust_delta": 6}, gs)
	assert_true(buff_result.get("unlocked_buffs", []).size() > 0, "crossing old_li buff trust threshold unlocks pending buff")
	assert_true(state.dialogue_state.get("unlocked_buffs_on_trust", []).size() > 0, "unlocked buffs are stored on dialogue_state")
	gs.queue_free()


func test_ask_intel_spends_lingstones_and_grants_active_rumor() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("ask_intel"), "NpcInteractionService exposes paid ask_intel")
	if not service.has_method("ask_intel"):
		return
	var gs = _fresh_state()
	gs.day = 5
	gs.time_of_day = "night"
	gs.lingstones = 50
	var state = NpcKnowledgeStateScript.new()
	state.trust = 30
	gs.npc_relations["old_li"] = state

	var result: Dictionary = service.call("ask_intel", "old_li", gs, "intel_xiao_ran_gift_001")
	assert_true(bool(result.get("ok", false)), "ask_intel succeeds for trusted Old Li intel")
	assert_eq(int(result.get("lingstones_cost", -1)), 20, "ask_intel returns default NPC intel cost")
	assert_eq(int(gs.lingstones), 30, "ask_intel deducts lingstones")
	assert_eq(_active_ids(gs), ["intel_xiao_ran_gift_001"], "ask_intel grants the requested active rumor")
	assert_true(_heard_history(gs).has("5") and _heard_history(gs)["5"].has("intel_xiao_ran_gift_001"), "ask_intel records heard_rumor_history")
	assert_true(_has_cjk(str(result.get("display_text", ""))), "ask_intel returns player-facing intel text")
	gs.queue_free()


func test_ask_intel_blocks_when_trust_too_low() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("ask_intel"), "NpcInteractionService exposes ask_intel for trust gate")
	if not service.has_method("ask_intel"):
		return
	var gs = _fresh_state()
	gs.lingstones = 50
	var state = NpcKnowledgeStateScript.new()
	state.trust = 0
	gs.npc_relations["old_li"] = state

	var result: Dictionary = service.call("ask_intel", "old_li", gs, "intel_xiao_ran_gift_001")
	assert_true(not bool(result.get("ok", true)), "ask_intel blocks requested intel below trust threshold")
	assert_eq(str(result.get("reason", "")), "trust_too_low", "ask_intel reports trust_too_low")
	assert_eq(int(gs.lingstones), 50, "trust-gated ask_intel does not deduct lingstones")
	assert_eq(_active_ids(gs), [], "trust-gated ask_intel grants no rumor")
	gs.queue_free()


func test_ask_intel_blocks_when_lingstones_short() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("ask_intel"), "NpcInteractionService exposes ask_intel for lingstone gate")
	if not service.has_method("ask_intel"):
		return
	var gs = _fresh_state()
	gs.lingstones = 19
	var state = NpcKnowledgeStateScript.new()
	state.trust = 30
	gs.npc_relations["old_li"] = state

	var result: Dictionary = service.call("ask_intel", "old_li", gs, "intel_xiao_ran_gift_001")
	assert_true(not bool(result.get("ok", true)), "ask_intel blocks when lingstones are short")
	assert_eq(str(result.get("reason", "")), "lingstones_short", "ask_intel reports lingstones_short")
	assert_eq(int(gs.lingstones), 19, "lingstone-short ask_intel does not mutate currency")
	assert_eq(_active_ids(gs), [], "lingstone-short ask_intel grants no rumor")
	gs.queue_free()


func test_npc_commission_templates_are_filtered_by_day_and_state() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("available_commissions_for_npc"), "NpcInteractionService exposes available NPC commission lookup")
	if not service.has_method("available_commissions_for_npc"):
		return
	var gs = _fresh_state()
	gs.day = 1
	gs.sequence = 9

	var day1: Array = service.call("available_commissions_for_npc", "old_li", gs)
	assert_eq(day1.size(), 1, "Old Li only exposes day-valid NPC commissions on day 1")
	if day1.size() > 0 and day1[0] is Dictionary:
		assert_eq(str(day1[0].get("id", "")), "commission_old_li_letter_001", "Old Li day 1 commission is the letter commission")
		assert_true(str(day1[0].get("display_name", day1[0].get("title", ""))).find("commission_") < 0, "NPC commission lookup returns player-facing title")

	gs.accepted_commissions.append("commission_old_li_letter_001")
	var after_accept: Array = service.call("available_commissions_for_npc", "old_li", gs)
	assert_eq(after_accept.size(), 0, "accepted NPC commissions are not offered again")
	gs.queue_free()


func test_accept_npc_commission_adds_real_commission_to_board_state() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("accept_npc_commission"), "NpcInteractionService exposes NPC commission accept path")
	if not service.has_method("accept_npc_commission"):
		return
	var gs = _fresh_state()
	gs.day = 1
	gs.sequence = 9

	var result: Dictionary = service.call("accept_npc_commission", "old_li", gs, "commission_old_li_letter_001")
	assert_true(bool(result.get("ok", false)), "accept_npc_commission accepts a real Old Li template")
	assert_true("commission_old_li_letter_001" in gs.accepted_commissions, "NPC commission accept records accepted id")
	assert_eq(_available_commission_status(gs, "commission_old_li_letter_001"), "accepted", "NPC commission accept upserts board-visible accepted commission")

	var wrong_npc: Dictionary = service.call("accept_npc_commission", "old_li", gs, "commission_factory_shift_001")
	assert_true(not bool(wrong_npc.get("ok", true)), "NPC commission accept rejects templates not owned by the NPC")
	assert_eq(str(wrong_npc.get("reason", "")), "not_from_npc", "wrong-NPC commission has structured reason")
	gs.queue_free()


func test_npc_activity_refs_are_real_job_and_drill_ids() -> void:
	var library = _new_instance(NPC_LIBRARY_PATH, "NpcLibrary")
	var job_service = _new_instance(JOB_SERVICE_PATH, "JobService")
	var drill_runner = _new_instance(DRILL_RUNNER_PATH, "DrillRunner")
	if library == null or job_service == null or drill_runner == null:
		return
	library.load_all()
	for npc_id in library.all_ids():
		var npc_def: Dictionary = library.get_definition(str(npc_id))
		for job_id in _string_array(npc_def.get("available_jobs", [])):
			assert_true(not job_service.load_job_definition(job_id).is_empty(), "%s available job %s resolves to a real R25 job" % [str(npc_id), job_id])
		for drill_id in _string_array(npc_def.get("available_drills", [])):
			assert_true(not drill_runner.load_drill_definition(drill_id).is_empty(), "%s available drill %s resolves to a real R25 drill" % [str(npc_id), drill_id])


func test_npc_activity_lookup_filters_real_options_and_costs() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("available_jobs_for_npc"), "NpcInteractionService exposes NPC job lookup")
	assert_true(service.has_method("available_drills_for_npc"), "NpcInteractionService exposes NPC drill lookup")
	if not service.has_method("available_jobs_for_npc") or not service.has_method("available_drills_for_npc"):
		return
	var gs = _fresh_state()
	gs.ap = 12
	gs.current_district = "steelworks"
	var jobs: Array = service.call("available_jobs_for_npc", "peter_furnace", gs)
	assert_eq(jobs.size(), 1, "Peter exposes one live job action")
	if jobs.size() > 0 and jobs[0] is Dictionary:
		assert_eq(str((jobs[0] as Dictionary).get("id", "")), "factory_shift", "Peter job action is factory_shift")
		assert_eq(int((jobs[0] as Dictionary).get("ap_cost", -1)), 3, "Peter job action reports real AP cost")
		assert_true(_has_cjk(str((jobs[0] as Dictionary).get("display_name", ""))), "NPC job action has player-facing name")
	var vera_jobs: Array = service.call("available_jobs_for_npc", "vera_lighthouse", gs)
	assert_eq(vera_jobs.size(), 1, "Vera exposes one live job action")
	if vera_jobs.size() > 0 and vera_jobs[0] is Dictionary:
		assert_eq(str((vera_jobs[0] as Dictionary).get("id", "")), "fishing_shift", "Vera job action is fishing_shift")
		assert_eq(int((vera_jobs[0] as Dictionary).get("ap_cost", -1)), 2, "Vera fishing job action reports real AP cost")
	var drills: Array = service.call("available_drills_for_npc", "old_li", gs)
	assert_eq(drills.size(), 1, "Old Li exposes one live drill action")
	if drills.size() > 0 and drills[0] is Dictionary:
		assert_eq(str((drills[0] as Dictionary).get("id", "")), "underground_signal", "Old Li drill action is underground_signal")
		assert_eq(int((drills[0] as Dictionary).get("ap_cost", -1)), 1, "Old Li drill action reports real AP cost")
		assert_true(_has_cjk(str((drills[0] as Dictionary).get("display_name", ""))), "NPC drill action has player-facing name")
	var thomas_drills: Array = service.call("available_drills_for_npc", "thomas_priest", gs)
	assert_eq(thomas_drills.size(), 1, "Thomas exposes one live drill action")
	if thomas_drills.size() > 0 and thomas_drills[0] is Dictionary:
		assert_eq(str((thomas_drills[0] as Dictionary).get("id", "")), "confession_room", "Thomas drill action is confession_room")
		assert_eq(int((thomas_drills[0] as Dictionary).get("ap_cost", -1)), 1, "Thomas confession drill action reports real AP cost")
	gs.queue_free()


func test_identity_picker_defaults_to_harvey_in_slice_2_5() -> void:
	var picker = _new_instance(IDENTITY_PICKER_PATH, "IdentityPickerDialog")
	if picker == null:
		return
	assert_eq(picker.choose_identity_for_npc("old_li", [], null), "harvey", "Slice 2.5 identity picker uses harvey when no residual identity exists")
	assert_eq(picker.choose_identity_for_npc("old_li", ["borrowed_a"], null), "harvey", "Slice 2.5 identity picker ignores residual identities until Slice 3")


func test_residual_identity_option_selects_current_identity_for_npc() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("residual_identity_options_for_npc"), "NpcInteractionService exposes residual identity options")
	assert_true(service.has_method("select_residual_identity_for_npc"), "NpcInteractionService exposes residual identity selection")
	if not service.has_method("residual_identity_options_for_npc") or not service.has_method("select_residual_identity_for_npc"):
		return
	var gs = _fresh_state()
	gs.day = 2
	gs.residual_identities.append({
		"id": "borrowed_face_old_li",
		"name": "张三",
		"source_npc_id": "old_li",
		"expires_at_day": 7,
		"allowed_locations": ["old_li"],
		"uses_remaining": 3,
	})
	var options: Array = service.call("residual_identity_options_for_npc", "old_li", gs)
	var saw_option := false
	for option in options:
		if option is Dictionary and str(option.get("identity_id", "")) == "borrowed_face_old_li":
			saw_option = true
			assert_true(str(option.get("label", "")).contains("以 张三 身份接近"), "residual identity option uses player-facing approach label")
	assert_true(saw_option, "residual identity approach option appears for NPC")
	var result: Dictionary = service.call("select_residual_identity_for_npc", "old_li", gs, "borrowed_face_old_li")
	assert_true(bool(result.get("ok", false)), "selecting residual identity succeeds")
	assert_eq(str(gs.current_residual_identity), "borrowed_face_old_li", "GameState.current_residual_identity records selected NPC identity")
	var state = gs.npc_relations.get("old_li", null)
	assert_true(state != null and str(state.dialogue_state.get("active_identity", "")) == "borrowed_face_old_li", "NPC dialogue state branches on selected identity")
	gs.queue_free()


func test_project_dialogic_variables_include_r24_binding_keys() -> void:
	var variables: Dictionary = ProjectSettings.get_setting("dialogic/variables", {})
	var expected := [
		"npc_trust",
		"npc_suspicion",
		"npc_layer",
		"npc_perception",
		"npc_dialog_count",
		"player_sequence",
		"player_pollution",
		"current_day",
		"current_weather",
		"time_of_day",
	]
	for key in expected:
		assert_true(variables.has(key), "project Dialogic variables include %s" % key)
	assert_true(FileAccess.file_exists("res://dialogic/npc/_t5_variable_probe.dtl"), "Dialogic variable probe dtl exists")


func test_hub_city_npc_hotspot_opens_dialogue_path() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.ap = 12
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame

	var door = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	if door is Button:
		door.pressed.emit()
		await Engine.get_main_loop().process_frame
	var selector = hub.get_node_or_null("DistrictSelect")
	if selector != null:
		var shadow = selector.find_child("DistrictRow_shadow_alley", true, false)
		if shadow is Button:
			shadow.pressed.emit()
			await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Hub path reaches CityScene before NPC dialogue")
	if city != null:
		var old_li_button = city.find_child("Hotspot_npc_old_li", true, false)
		assert_true(old_li_button is Button, "Old Li hotspot button exists in CityScene")
		if old_li_button is Button:
			old_li_button.pressed.emit()
			await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "clicking an NPC hotspot opens a visible dialogue entry")
	if dialog != null:
		assert_true(_is_clean_player_text(str(dialog.dialog_text)), "visible NPC dialogue entry is Chinese player-facing copy")
		assert_true(str(dialog.dialog_text).find("Dialogic timeline") < 0 and str(dialog.dialog_text).find("npc_id:") < 0, "visible NPC dialogue entry hides internal ids")
	assert_true(GameState.npc_relations.has("old_li"), "Hub NPC dialogue path initializes old_li relation state")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_city_npc_dialogue_shows_ai_gm_first_meet_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC AI GM visibility path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	assert_true(hub.has_method("set_ai_gm_service"), "Hub exposes set_ai_gm_service for player-facing AI GM paths")
	var fake := FakeAIGMService.new()
	if hub.has_method("set_ai_gm_service"):
		hub.call("set_ai_gm_service", fake)
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for AI GM visibility path")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("hub npc ai gm visible text"), "Hub NPC dialogue shows AI GM first-meet text")
	assert_eq(fake.calls.size(), 1, "Hub NPC first-meet path calls injected AI GM once")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_main_window_uses_layered_menu_not_activity_wall() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	GameState.lingstones = 50
	GameState.church_awareness = 26
	var old_li_state = NpcKnowledgeStateScript.new()
	old_li_state.trust = 45
	old_li_state.suspicion = 12
	old_li_state.active_perception = "dead_brother"
	old_li_state.perception_expires_at = 9
	GameState.npc_relations["old_li"] = old_li_state
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC layered menu path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var church_label = hub.find_child("ChurchAwarenessLabel", true, false)
	assert_true(church_label is Label, "Hub status bar exposes persistent church awareness")
	if church_label is Label:
		assert_true(str(church_label.text).contains("\u6559\u4f1a") and str(church_label.text).contains("26"), "Hub church awareness status shows current value")
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for layered menu path")
	if dialog != null:
		assert_true(dialog.find_child("NpcTalkMenuButton_old_li", true, false) is Button, "NPC root window exposes a talk menu entry")
		assert_true(dialog.find_child("NpcEventMenuButton_old_li", true, false) is Button, "NPC root window exposes an event menu entry")
		assert_true(not (dialog.find_child("NpcServiceMenuButton_old_li", true, false) is Button), "NPC root window does not expose a service/system menu entry")
		var root_text := str(dialog.dialog_text)
		assert_true(root_text.contains("\u4fe1\u4efb") and root_text.contains("\u6000\u7591"), "NPC root window shows current social state")
		assert_true(root_text.contains("\u4f2a\u88c5") and root_text.contains("\u4ea1\u5144"), "NPC root window shows current disguise perception")
		for prefix in [
			"NpcServiceMenuButton_",
			"NpcOpportunityButton_",
			"NpcIntelButton_",
			"NpcCommissionButton_",
			"NpcJobButton_",
			"NpcDrillButton_",
			"R20ChantButton_",
		]:
			assert_eq(_visible_button_count(dialog, prefix), 0, "NPC root window does not flatten %s buttons" % prefix)
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_hotspot_does_not_leave_city_chant_wall_visible() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 5
	GameState.time_of_day = "morning"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	GameState.hub_mana = 10
	var chant_card = CardScript.from_json({
		"id": "shadow_jester",
		"template_id": "shadow_jester",
		"display_name": "影代之谜",
		"energy_cost": 2,
		"combat_effect": {"damage": 12, "target": "single"},
		"social_effect": {"type": "identity_mask", "duration_days": 3, "npc_perception": "dead_brother", "suspicion_delta": -20},
		"world_effect": {"type": "create_residual_identity", "identity_id": "borrowed_face_old_li", "duration_days": 3, "allowed_locations": ["old_li"]},
	})
	GameState.add_card(chant_card)
	GameState.active_deck = ["shadow_jester"]
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC city chant-wall path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("open_city_for_debug", "shadow_alley", "morning")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var old_li_button = city.find_child("Hotspot_npc_old_li", true, false) if city != null else null
	assert_true(old_li_button is Button, "Hub path reaches Old Li hotspot for chant-wall check")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens over the city scene")
	_assert_no_visible_buttons_in_tree(hub, "R20ChantButton_", "NPC hotspot leaves no city R20 chant wall visible")
	_assert_no_visible_buttons_in_tree(hub, "NpcServiceMenuButton_", "NPC hotspot leaves no service menu wall visible")
	_assert_no_visible_buttons_in_tree(hub, "NpcIntelButton_", "NPC hotspot leaves no paid-intel wall visible")
	_assert_no_visible_buttons_in_tree(hub, "NpcJobButton_", "NPC hotspot leaves no job wall visible")
	_assert_no_visible_buttons_in_tree(hub, "NpcDrillButton_", "NPC hotspot leaves no drill wall visible")
	assert_eq(int(GameState.hub_mana), 10, "NPC hotspot does not spend R20 hub mana while opening dialogue")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_suppresses_city_surface_buttons() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 5
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC city-surface suppression path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null, "Hub path reaches CityScene for NPC city-surface suppression")
	var before_names := _visible_button_names_in_tree(city)
	assert_true(before_names.size() > 2, "CityScene has visible surface buttons before NPC dialogue opens")
	var old_li_button = city.find_child("Hotspot_npc_old_li", true, false) if city != null else null
	assert_true(old_li_button is Button, "CityScene exposes Old Li hotspot for NPC city-surface suppression")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens over city surface")
	assert_eq(_visible_button_names_in_tree(city).size(), 0, "NPC dialogue suppresses the map/topbar/footer button wall behind it")
	if dialog != null:
		dialog.hide()
		await Engine.get_main_loop().process_frame
	assert_true(_visible_button_names_in_tree(city).size() > 2, "closing NPC dialogue restores the city interaction surface")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_talk_menu_exposes_timeline_branch_buttons() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 6
	GameState.time_of_day = "evening"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC timeline branch menu")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "xiao_ran", "payload": {"npc_id": "xiao_ran"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	var talk_button = dialog.find_child("NpcTalkMenuButton_xiao_ran", true, false) if dialog != null else null
	assert_true(talk_button is Button, "NPC root has talk menu button before branch selection")
	if talk_button is Button:
		talk_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var first_meet_button = dialog.find_child("NpcDialogueBranchButton_first_meet", true, false) if dialog != null else null
	assert_true(first_meet_button is Button, "talk menu exposes first_meet timeline branch")
	assert_eq(_visible_button_count(dialog, "NpcJobButton_") if dialog != null else -1, 0, "talk menu does not show minigame job buttons")
	if first_meet_button is Button:
		first_meet_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var state = GameState.npc_relations.get("xiao_ran", null)
	assert_true(state != null and int(state.dialog_count) == 1, "pressing a timeline branch commits NPC dialogue progress")
	if dialog != null:
		assert_true(_is_clean_player_text(str(dialog.dialog_text)), "timeline branch result is player-facing dialogue text")
		assert_true(str(dialog.dialog_text).find("branch:first_meet") < 0, "timeline branch result hides branch markup")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_deep_chat_spends_ap_and_updates_relation() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 2
	var state = NpcKnowledgeStateScript.new()
	state.trust = 35
	GameState.npc_relations["old_li"] = state
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC deep chat path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for deep chat path")
	_press_dialog_button(dialog, "NpcTalkMenuButton_old_li")
	await Engine.get_main_loop().process_frame
	var deep_button = dialog.find_child("NpcDeepChatButton_old_li", true, false) if dialog != null else null
	assert_true(deep_button is Button, "NPC dialogue exposes a deep-chat AP button")
	if deep_button is Button:
		assert_true(not deep_button.disabled, "deep-chat button is enabled when AP is enough")
		assert_true(str(deep_button.text).contains("AP"), "deep-chat button shows AP cost")
		deep_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(int(GameState.ap), 1, "pressing deep-chat button spends exactly 1 AP")
	assert_eq(int(state.trust), 36, "pressing deep-chat button increases NPC trust")
	assert_eq(int(state.dialog_count), 1, "pressing deep-chat button commits dialogue progress")
	assert_eq(int(state.last_seen_day), 6, "deep-chat path writes last_seen_day")
	if dialog != null:
		var text := str(dialog.dialog_text)
		assert_true(text.contains("深入") and text.contains("AP"), "deep-chat result gives visible AP feedback")
		assert_true(text.find("npc_id") < 0 and text.find("old_li") < 0, "deep-chat result hides internal ids")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_action_buttons_mount_in_dialog_action_row() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC action-row mount path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for action-row mount path")
	_press_dialog_button(dialog, "NpcTalkMenuButton_old_li")
	await Engine.get_main_loop().process_frame
	var deep_button = dialog.find_child("NpcDeepChatButton_old_li", true, false) if dialog != null else null
	assert_true(deep_button is Button, "NPC dialogue exposes deep-chat action button")
	if dialog != null and deep_button is Button:
		assert_true(deep_button.get_parent() != dialog, "NPC action button is mounted through AcceptDialog.add_button instead of as an unlaid-out root child")
		assert_true(deep_button.get_parent() is Container, "NPC action button parent is a layout container")
		assert_true(deep_button.is_visible_in_tree(), "NPC action button is visible in the open dialog tree")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_deep_chat_blocks_when_ap_short() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 0
	var state = NpcKnowledgeStateScript.new()
	state.trust = 35
	state.dialog_count = 0
	GameState.npc_relations["old_li"] = state
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for AP-short deep chat path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	_press_dialog_button(dialog, "NpcTalkMenuButton_old_li")
	await Engine.get_main_loop().process_frame
	var deep_button = dialog.find_child("NpcDeepChatButton_old_li", true, false) if dialog != null else null
	assert_true(deep_button is Button, "NPC dialogue still exposes deep-chat button when AP is short")
	if deep_button is Button:
		assert_true(deep_button.disabled, "deep-chat button is disabled when AP is short")
		assert_true(str(deep_button.tooltip_text).contains("AP"), "deep-chat disabled tooltip names AP shortage")
	assert_true(hub.has_method("_on_npc_deep_chat_pressed"), "Hub exposes deep-chat callback")
	if hub.has_method("_on_npc_deep_chat_pressed"):
		hub.call("_on_npc_deep_chat_pressed", "old_li")
		await Engine.get_main_loop().process_frame
	assert_eq(int(GameState.ap), 0, "AP-short deep-chat path does not mutate AP")
	assert_eq(int(state.trust), 35, "AP-short deep-chat path does not mutate trust")
	assert_eq(int(state.dialog_count), 0, "AP-short deep-chat path does not commit dialogue progress")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("AP"), "AP-short deep-chat result gives visible AP feedback")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_exposes_daily_opportunity_button() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 3
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	GameState.lingstones = 50
	var old_li_state = NpcKnowledgeStateScript.new()
	old_li_state.trust = 45
	GameState.npc_relations["old_li"] = old_li_state
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC daily opportunity path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var old_li_button = city.find_child("Hotspot_npc_old_li", true, false) if city != null else null
	assert_true(old_li_button is Button, "Hub path reaches Old Li hotspot for daily opportunity")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	_press_dialog_button(dialog, "NpcEventMenuButton_old_li")
	await Engine.get_main_loop().process_frame
	var opportunity_button = dialog.find_child("NpcOpportunityButton_old_li_short_warning", true, false) if dialog != null else null
	assert_true(opportunity_button is Button, "NPC dialogue exposes daily opportunity button")
	if opportunity_button is Button:
		assert_true(not opportunity_button.disabled, "free daily opportunity button is enabled")
		assert_true(str(opportunity_button.text).contains("\u4eca\u65e5\u673a\u4f1a"), "daily opportunity button is player-facing")
		assert_true(str(opportunity_button.text).find("\u7ebf\u7d22") < 0, "daily opportunity button names the concrete target instead of generic clue")
		assert_true(str(opportunity_button.tooltip_text).contains("\u60c5\u62a5") and str(opportunity_button.tooltip_text).contains("\u6559\u4f1a"), "daily opportunity tooltip maps to the granted intel target")
		opportunity_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_true(_active_ids(GameState).has("intel_shadow_alley_church_patrol_001"), "pressing daily opportunity grants intel")
	if dialog != null:
		var result_text := str(dialog.dialog_text)
		assert_true(result_text.contains("\u6559\u4f1a") and result_text.find("Old Li") < 0, "daily opportunity result explains the actual intel in player-facing text")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_keeps_paid_intel_off_npc_surface() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 5
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	GameState.lingstones = 50
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for paid intel path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for paid-intel surface check")
	if dialog != null:
		assert_true(not (dialog.find_child("NpcServiceMenuButton_old_li", true, false) is Button), "NPC root does not expose a service menu for paid intel")
		_assert_no_npc_service_buttons(dialog, "NPC root")
	_press_dialog_button(dialog, "NpcTalkMenuButton_old_li")
	await Engine.get_main_loop().process_frame
	_assert_no_npc_service_buttons(dialog, "talk menu")
	_press_dialog_button(dialog, "NpcBackButton_old_li")
	await Engine.get_main_loop().process_frame
	_press_dialog_button(dialog, "NpcEventMenuButton_old_li")
	await Engine.get_main_loop().process_frame
	_assert_no_npc_service_buttons(dialog, "event/task menu")
	assert_eq(int(GameState.lingstones), 50, "paid intel is not spent from ordinary NPC dialogue surface")
	assert_true(not _active_ids(GameState).has("intel_xiao_ran_gift_001"), "paid intel is not granted by an ordinary NPC button wall")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_exposes_real_commission_button() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 1
	GameState.sequence = 9
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.ap = 12
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC commission path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	_press_dialog_button(dialog, "NpcEventMenuButton_old_li")
	await Engine.get_main_loop().process_frame
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for commission path")
	var commission_button = dialog.find_child("NpcCommissionButton_commission_old_li_letter_001", true, false) if dialog != null else null
	assert_true(commission_button is Button, "NPC dialogue exposes a real commission button")
	if commission_button is Button:
		assert_true(not commission_button.disabled, "NPC commission button is enabled before accepting")
		assert_true(str(commission_button.text).contains("委托"), "NPC commission button names the commission action")
		commission_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_true("commission_old_li_letter_001" in GameState.accepted_commissions, "pressing NPC commission button accepts the real commission")
	assert_eq(_available_commission_status(GameState, "commission_old_li_letter_001"), "accepted", "Hub NPC commission path writes board-visible accepted status")
	if dialog != null:
		var text := str(dialog.dialog_text)
		assert_true(text.contains("委托") and text.find("commission_old_li_letter_001") < 0, "NPC commission result stays player-facing")
	var placeholder = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(placeholder == null or not placeholder.visible, "NPC commission path does not use generic placeholder")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_npc_dialogue_keeps_job_and_drill_buttons_off_npc_surface() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_fresh_state().to_dict())
	GameState.day = 1
	GameState.sequence = 9
	GameState.time_of_day = "morning"
	GameState.current_district = "steelworks"
	GameState.ap = 12
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for NPC activity surface check")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "peter_furnace", "payload": {"npc_id": "peter_furnace"}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for job/drill surface check")
	if dialog != null:
		assert_true(not (dialog.find_child("NpcServiceMenuButton_peter_furnace", true, false) is Button), "Peter NPC root does not expose service menu")
		_assert_no_npc_service_buttons(dialog, "Peter NPC root")
	_press_dialog_button(dialog, "NpcEventMenuButton_peter_furnace")
	await Engine.get_main_loop().process_frame
	_assert_no_npc_service_buttons(dialog, "Peter event/task menu")
	assert_eq(int(GameState.ap), 12, "NPC job buttons do not spend AP from ordinary NPC dialogue")

	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "old_li", "payload": {"npc_id": "old_li"}})
	await Engine.get_main_loop().process_frame
	dialog = hub.get_node_or_null("NpcDialogueDialog")
	_assert_no_npc_service_buttons(dialog, "Old Li NPC root")
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "vera_lighthouse", "payload": {"npc_id": "vera_lighthouse"}})
	await Engine.get_main_loop().process_frame
	dialog = hub.get_node_or_null("NpcDialogueDialog")
	_assert_no_npc_service_buttons(dialog, "Vera NPC root")
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": "thomas_priest", "payload": {"npc_id": "thomas_priest"}})
	await Engine.get_main_loop().process_frame
	dialog = hub.get_node_or_null("NpcDialogueDialog")
	_assert_no_npc_service_buttons(dialog, "Thomas NPC root")
	hub.queue_free()
	GameState.from_dict(previous)


func _new_instance(path: String, label: String):
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s script loads and can instantiate" % label)
		return null
	var instance = script.new()
	assert_true(instance != null, "%s instance creates" % label)
	return instance


func _fresh_state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _active_ids(game_state) -> Array:
	var result: Array = []
	var value: Variant = game_state.get("active_rumors")
	if value is Array:
		for intel in value:
			if intel is Dictionary:
				result.append(str((intel as Dictionary).get("id", "")))
	return result


func _heard_history(game_state) -> Dictionary:
	var value: Variant = game_state.get("heard_rumor_history")
	return value if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		var text := str(item)
		if text != "":
			result.append(text)
	return result


func _available_commission_status(game_state, commission_id: String) -> String:
	var value: Variant = game_state.get("available_commissions")
	if value is Array:
		for item in value:
			if item is Dictionary and str((item as Dictionary).get("id", "")) == commission_id:
				return str((item as Dictionary).get("status", ""))
	return ""


func _press_dialog_button(dialog, button_name: String) -> void:
	if dialog == null:
		return
	var button = dialog.find_child(button_name, true, false)
	if button is Button:
		button.pressed.emit()


func _visible_button_count(dialog, prefix: String) -> int:
	if dialog == null:
		return 0
	var count := 0
	for child in dialog.find_children("%s*" % prefix, "Button", true, false):
		if child is Button and child.visible:
			count += 1
	return count


func _assert_no_npc_service_buttons(dialog, context: String) -> void:
	for prefix in [
		"NpcServiceMenuButton_",
		"NpcIntelButton_",
		"NpcJobButton_",
		"NpcDrillButton_",
		"R20ChantButton_",
	]:
		assert_eq(_visible_button_count(dialog, prefix), 0, "%s does not expose %s buttons" % [context, prefix])


func _assert_no_visible_buttons_in_tree(root: Node, prefix: String, message: String) -> void:
	var count := 0
	if root != null:
		for child in root.find_children("%s*" % prefix, "Button", true, false):
			if child is Button and child.visible and child.is_visible_in_tree():
				count += 1
	assert_eq(count, 0, message)


func _visible_button_names_in_tree(root: Node) -> Array[String]:
	var names: Array[String] = []
	if root == null:
		return names
	for child in root.find_children("*", "Button", true, false):
		if child is Button and child.visible and child.is_visible_in_tree():
			names.append(str(child.name))
	return names


func _is_clean_player_text(value: String) -> bool:
	if value.strip_edges() == "":
		return false
	for fragment in [
		"Dialogic timeline",
		"npc_id:",
		"npc/",
		"timeline_id",
	]:
		if value.find(fragment) >= 0:
			return false
	return _has_cjk(value)


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


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
