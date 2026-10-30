extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const COMMISSION_PATH := "res://scripts/world/commission.gd"
const LIBRARY_PATH := "res://scripts/world/commission_library.gd"
const SERVICE_PATH := "res://scripts/world/commission_service.gd"
const MATCHER_PATH := "res://scripts/world/completion_matcher.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_commission_full.gd --")
	test_commission_roundtrip_preserves_runtime_state()
	test_library_loads_20_templates_and_5_main_hooks()
	test_npc_commission_template_ids_resolve()
	test_daily_refresh_slots_preserve_accepted_and_force_hooks()
	test_accept_reject_complete_claim_and_expire()
	test_church_awareness_reward_claim_records_threshold_event()
	test_completion_matcher_covers_all_four_types()
	test_dispatch_outputs_for_four_commission_types()
	return {"passed": _passed, "failed": _failed}


func test_commission_roundtrip_preserves_runtime_state() -> void:
	var script = _script(COMMISSION_PATH, "Commission script exists")
	if script == null:
		return
	var commission = script.from_dict({
		"id": "commission_test_roundtrip",
		"commission_type": "gather",
		"difficulty": "small",
		"display_name": "Roundtrip",
		"description": "Roundtrip description",
		"issuer_npc": "old_li",
		"district": "shadow_alley",
		"min_day": 1,
		"max_day": 14,
		"min_sequence": 9,
		"dispatch_target": {"kind": "job", "job_id": "errand_runner", "district": "shadow_alley", "item_id": "parcel", "count": 2},
		"time_limit_days": 2,
		"rewards": [{"type": "lingstones", "amount": 50}],
		"main_story_hook": "node_2_black_market_intro",
		"contract_rule_hook": "shadow_silence",
		"deposit": {"lingstones": 0},
		"escrow": {"enabled": false},
		"status": "accepted",
		"accepted_day": 3,
		"progress": {"gathered_count": 1},
	})
	var encoded: Dictionary = commission.to_dict()
	assert_eq(str(encoded.get("id", "")), "commission_test_roundtrip", "roundtrip keeps id")
	assert_eq(str(encoded.get("commission_type", "")), "gather", "roundtrip keeps commission_type")
	assert_eq(str(encoded.get("issuer_npc", "")), "old_li", "roundtrip keeps issuer_npc")
	assert_eq(str(encoded.get("main_story_hook", "")), "node_2_black_market_intro", "roundtrip keeps main_story_hook")
	assert_eq(str(encoded.get("contract_rule_hook", "")), "shadow_silence", "roundtrip keeps contract_rule_hook")
	assert_eq(str(encoded.get("status", "")), "accepted", "roundtrip keeps runtime status")
	assert_eq(int(encoded.get("accepted_day", 0)), 3, "roundtrip keeps accepted_day")
	assert_eq(int(encoded.get("progress", {}).get("gathered_count", 0)), 1, "roundtrip keeps progress")
	assert_true(encoded.has("deposit") and encoded.has("escrow"), "roundtrip keeps deposit/escrow placeholder fields")


func test_library_loads_20_templates_and_5_main_hooks() -> void:
	var library = _library()
	if library == null:
		return
	var result: Dictionary = library.load_all()
	assert_true(bool(result.get("ok", false)), "CommissionLibrary.load_all succeeds")
	var templates: Array = library.all_templates()
	assert_eq(templates.size(), 20, "CommissionLibrary loads exactly 20 MVP templates")
	var ids := {}
	var type_counts := {"battle": 0, "gather": 0, "investigate": 0, "perform": 0}
	var hooks := {}
	for item in templates:
		var data: Dictionary = item.to_dict() if item != null and item.has_method("to_dict") else {}
		var id := str(data.get("id", ""))
		assert_true(id != "", "template has structured id")
		assert_true(not ids.has(id), "template id is unique: %s" % id)
		ids[id] = true
		var ctype := str(data.get("commission_type", ""))
		if type_counts.has(ctype):
			type_counts[ctype] = int(type_counts[ctype]) + 1
		var hook := str(data.get("main_story_hook", ""))
		if hook != "":
			hooks[hook] = data
	assert_eq(hooks.size(), 5, "main story hook commission pool size == 5")
	for required_type in type_counts.keys():
		assert_true(int(type_counts[required_type]) >= 3, "library includes at least three %s commissions" % required_type)
	var expected_hooks := {
		"node_2_black_market_intro": {"min_day": 3, "max_day": 3},
		"node_3_halfmoon_contact": {"min_day": 6, "max_day": 7},
		"node_4_promotion_prepare": {"min_day": 8, "max_day": 9},
		"node_5_church_sermon": {"min_day": 12, "max_day": 12},
		"node_6_final_prepare": {"min_day": 13, "max_day": 14},
	}
	for hook_id in expected_hooks.keys():
		assert_true(hooks.has(hook_id), "required main story hook exists: %s" % hook_id)
		if hooks.has(hook_id):
			var data: Dictionary = hooks[hook_id]
			assert_eq(int(data.get("min_day", 0)), int(expected_hooks[hook_id].get("min_day", 0)), "%s min_day" % hook_id)
			assert_eq(int(data.get("max_day", 0)), int(expected_hooks[hook_id].get("max_day", 0)), "%s max_day" % hook_id)


func test_npc_commission_template_ids_resolve() -> void:
	var library = _library()
	if library == null:
		return
	library.load_all()
	var paths := _npc_json_paths()
	assert_true(paths.size() >= 18, "NPC data paths are available")
	for path in paths:
		var npc := _json_dict(path)
		var npc_id := str(npc.get("id", path))
		var templates: Variant = npc.get("commission_templates", [])
		if templates is Array:
			for raw_id in templates:
				var template_id := str(raw_id)
				if template_id == "":
					continue
				assert_true(not library.get_template(template_id).is_empty(), "%s commission_template resolves: %s" % [npc_id, template_id])
		if npc_id in ["old_li", "xiao_ran"]:
			assert_true(templates is Array and (templates as Array).size() >= 1, "%s has at least one R17 commission template" % npc_id)


func test_daily_refresh_slots_preserve_accepted_and_force_hooks() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _state()
	gs.day = 1
	var day1: Dictionary = service.refresh_daily(gs, 101)
	assert_true(bool(day1.get("ok", false)), "day 1 commission refresh succeeds")
	assert_eq(gs.available_commissions.size(), 3, "Day 1-3 commission board has 3 slots")
	var accepted_id := str(gs.available_commissions[0].get("id", ""))
	var accepted: Dictionary = service.accept(gs, accepted_id)
	assert_true(bool(accepted.get("ok", false)), "accept first day commission succeeds")
	gs.day = 4
	var day4: Dictionary = service.refresh_daily(gs, 102)
	assert_true(bool(day4.get("ok", false)), "day 4 commission refresh succeeds")
	assert_eq(gs.available_commissions.size(), 5, "Day 4+ commission board has 5 visible slots including accepted unfinished")
	assert_true(accepted_id in gs.accepted_commissions, "accepted unfinished commission remains accepted after refresh")
	assert_true(_available_has(gs, accepted_id), "accepted unfinished commission remains visible after refresh")
	var hook_expectations := {
		3: "node_2_black_market_intro",
		6: "node_3_halfmoon_contact",
		9: "node_4_promotion_prepare",
		12: "node_5_church_sermon",
		14: "node_6_final_prepare",
	}
	for day in hook_expectations.keys():
		gs.available_commissions.clear()
		gs.accepted_commissions.clear()
		gs.day = int(day)
		service.refresh_daily(gs, 200 + int(day))
		assert_true(_available_has_hook(gs, str(hook_expectations[day])), "day %d forces hook %s" % [int(day), str(hook_expectations[day])])
		var hook_id := _id_for_hook(gs, str(hook_expectations[day]))
		if hook_id != "":
			var rejected: Dictionary = service.reject(gs, hook_id)
			assert_true(not bool(rejected.get("ok", true)), "main story hook cannot be rejected: %s" % hook_id)
			assert_eq(str(rejected.get("reason", "")), "cannot_reject_main_story", "main story reject reason is structured")


func test_accept_reject_complete_claim_and_expire() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _state()
	gs.day = 1
	gs.lingstones = 0
	service.refresh_daily(gs, 7)
	var reject_id := "commission_moonlight_grass_001"
	if not _available_has(gs, reject_id):
		reject_id = str(gs.available_commissions[0].get("id", ""))
	var reject_result: Dictionary = service.reject(gs, reject_id)
	assert_true(bool(reject_result.get("ok", false)), "non-main commission can be rejected")
	assert_true(not _available_has(gs, reject_id), "rejected commission leaves available list")
	var id := "commission_rumor_delivery_001"
	var accept_result: Dictionary = service.accept(gs, id)
	assert_true(bool(accept_result.get("ok", false)), "accept can add a known template by id")
	assert_true(id in gs.accepted_commissions, "accepted id recorded")
	var state = NpcKnowledgeStateScript.new()
	state.trust = 60
	gs.npc_relations["ah_du_streettalker"] = state
	var event_result: Dictionary = service.record_completion_event(gs, {
		"event": "perform_action",
		"district": "shadow_alley",
		"action_id": "deliver_rumor",
		"witness_count": 0,
	})
	assert_true(str(id) in _string_array(event_result.get("completed_ids", [])), "perform event marks commission completed")
	var before_pages := int(gs.dao_pages)
	var claim: Dictionary = service.claim(gs, id)
	assert_true(bool(claim.get("ok", false)), "claim completed commission succeeds")
	assert_true(id in gs.completed_commissions, "claim records completed commission id")
	assert_true(not id in gs.accepted_commissions, "claim removes accepted commission id")
	assert_eq(int(gs.lingstones), 72, "trust >=60 applies +20% to lingstone reward 60 -> 72")
	assert_true(int(gs.dao_pages) > before_pages, "claim applies dao page reward")
	var expire_id := "commission_factory_shift_001"
	gs.day = 1
	var exp_accept: Dictionary = service.accept(gs, expire_id)
	assert_true(bool(exp_accept.get("ok", false)), "expire setup accept succeeds")
	var issuer_state = NpcKnowledgeStateScript.new()
	issuer_state.trust = 10
	gs.npc_relations["peter_furnace"] = issuer_state
	gs.day = 5
	var expired: Dictionary = service.expire_overdue(gs)
	assert_true(str(expire_id) in _string_array(expired.get("expired_ids", [])), "overdue commission expires")
	assert_eq(int(gs.npc_relations["peter_furnace"].trust), 5, "expired commission applies issuer trust -5")


func test_church_awareness_reward_claim_records_threshold_event() -> void:
	var service = _service()
	var commission_script = _script(COMMISSION_PATH, "Commission script exists for church threshold reward")
	if service == null or commission_script == null:
		return
	var gs = _state()
	gs.day = 7
	gs.church_awareness = 24
	gs.set_ai_gm_service(FakeThresholdAIGMService.new())
	var commission = commission_script.from_dict({
		"id": "commission_church_threshold_probe",
		"commission_type": "perform",
		"display_name": "Church Threshold Probe",
		"issuer_npc": "thomas_priest",
		"district": "sacred_seven",
		"dispatch_target": {"kind": "drill", "drill_id": "street_debate"},
		"time_limit_days": 2,
		"rewards": [{"type": "church_awareness", "amount": 1}],
		"status": "completed",
	})
	service.call("_upsert_available", gs, commission)
	var claim: Dictionary = service.claim(gs, "commission_church_threshold_probe")
	assert_true(bool(claim.get("ok", false)), "claiming church-awareness commission reward succeeds")
	assert_eq(int(gs.church_awareness), 25, "commission reward crosses church awareness 25")
	assert_true(_has_threshold(gs, 25), "commission reward crossing 25 records church threshold event")
	assert_true(_threshold_ai_text(gs, 25) != "", "commission reward threshold event stores AI GM text")


func test_completion_matcher_covers_all_four_types() -> void:
	var commission_script = _script(COMMISSION_PATH, "Commission script exists for matcher")
	var matcher_script = _script(MATCHER_PATH, "CompletionMatcher script exists")
	if commission_script == null or matcher_script == null:
		return
	var battle = commission_script.from_dict({
		"id": "battle_test",
		"commission_type": "battle",
		"district": "steelworks",
		"dispatch_target": {"district": "steelworks", "tower_size": "medium", "boss": "slag_golem"},
	})
	assert_true(matcher_script.matches(battle, {"event": "tower_complete", "district": "steelworks", "tower_size": "medium", "boss_defeated_id": "slag_golem", "victory": true}), "battle matcher requires district/tower_size/boss/victory")
	var gather = commission_script.from_dict({
		"id": "gather_test",
		"commission_type": "gather",
		"district": "misty_port",
		"dispatch_target": {"district": "misty_port", "time": "night", "item_id": "moonlight_grass", "count": 3},
		"progress": {},
	})
	assert_true(not matcher_script.matches(gather, {"event": "loot_resolved", "district": "misty_port", "time": "night", "item_id": "moonlight_grass", "count_added": 2}), "gather matcher accumulates without early completion")
	assert_eq(int(gather.progress.get("gathered_count", 0)), 2, "gather matcher stores partial count")
	assert_true(matcher_script.matches(gather, {"event": "loot_resolved", "district": "misty_port", "time": "night", "item_id": "moonlight_grass", "count_added": 1}), "gather matcher completes at target count")
	var investigate = commission_script.from_dict({
		"id": "investigate_test",
		"commission_type": "investigate",
		"district": "shadow_alley",
		"dispatch_target": {"district": "shadow_alley", "required_event_id": "well_bottom", "accepted_choices": ["listen"]},
	})
	assert_true(matcher_script.matches(investigate, {"event": "tower_event_resolved", "district": "shadow_alley", "event_id": "well_bottom", "choice_id": "listen"}), "investigate matcher accepts structured event/choice")
	var perform = commission_script.from_dict({
		"id": "perform_test",
		"commission_type": "perform",
		"district": "sacred_seven",
		"dispatch_target": {"district": "sacred_seven", "action_id": "recite_letter", "witness_check": true},
	})
	assert_true(not matcher_script.matches(perform, {"event": "perform_action", "district": "sacred_seven", "action_id": "recite_letter", "witness_count": 1}), "perform matcher rejects witnessed action")
	assert_true(matcher_script.matches(perform, {"event": "perform_action", "district": "sacred_seven", "action_id": "recite_letter", "witness_count": 0}), "perform matcher accepts clean action")


func test_dispatch_outputs_for_four_commission_types() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _state()
	for id in [
		"commission_steelworks_missing_001",
		"commission_moonlight_grass_001",
		"commission_shadow_well_inquiry_001",
		"commission_rumor_delivery_001",
	]:
		var accepted: Dictionary = service.accept(gs, id)
		assert_true(bool(accepted.get("ok", false)), "accept for dispatch succeeds: %s" % id)
	var battle: Dictionary = service.execute(gs, "commission_steelworks_missing_001")
	assert_eq(str(battle.get("dispatch_kind", "")), "tower", "battle dispatch targets tower")
	assert_eq(str(battle.get("dispatch_target", {}).get("tower_size", "")), "medium", "battle dispatch carries tower_size")
	var gather: Dictionary = service.execute(gs, "commission_moonlight_grass_001", {"count_added": 3})
	assert_eq(str(gather.get("dispatch_kind", "")), "encounter", "gather dispatch targets R27 encounter/loot path")
	var investigate: Dictionary = service.execute(gs, "commission_shadow_well_inquiry_001")
	assert_eq(str(investigate.get("dispatch_kind", "")), "tower_event", "investigate dispatch targets tower event")
	var perform: Dictionary = service.execute(gs, "commission_rumor_delivery_001", {"auto_resolve": false})
	assert_eq(str(perform.get("dispatch_kind", "")), "drill", "perform dispatch targets R25 drill/action path")
	assert_true(gs.has_meta("commission_active_dispatch"), "execute writes active dispatch meta for player path")


func _library():
	var script = _script(LIBRARY_PATH, "CommissionLibrary script exists")
	if script == null:
		return null
	return script.new()


func _service():
	var script = _script(SERVICE_PATH, "CommissionService script exists")
	if script == null:
		return null
	return script.new()


func _script(path: String, message: String):
	if not ResourceLoader.exists(path):
		assert_true(false, message)
		return null
	var script = load(path)
	if script == null:
		assert_true(false, "%s loads" % path)
		return null
	return script


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _available_has(game_state, id: String) -> bool:
	for item in game_state.available_commissions:
		if item is Dictionary and str(item.get("id", "")) == id:
			return true
	return false


func _available_has_hook(game_state, hook_id: String) -> bool:
	return _id_for_hook(game_state, hook_id) != ""


func _id_for_hook(game_state, hook_id: String) -> String:
	for item in game_state.available_commissions:
		if item is Dictionary and str(item.get("main_story_hook", "")) == hook_id:
			return str(item.get("id", ""))
	return ""


func _npc_json_paths() -> Array[String]:
	var result: Array[String] = []
	_collect_json_paths("res://data/npc", result)
	return result


func _collect_json_paths(dir_path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var path := "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			_collect_json_paths(path, result)
		elif name.ends_with(".json") and name != "_index.json":
			result.append(path)
	dir.list_dir_end()


func _json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


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
