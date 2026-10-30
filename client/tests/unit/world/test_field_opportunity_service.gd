extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_field_opportunity_service.gd --")
	test_game_state_persists_slice35_field_loop_state()
	test_npc_state_persists_daily_opportunity_fields()
	test_npc_daily_opportunities_are_deterministic_and_gated()
	test_npc_daily_opportunities_respect_last_seen_fatigue()
	test_first_pass_npc_definitions_list_field_opportunities()
	test_npc_interaction_service_exposes_daily_opportunities()
	test_commission_npc_opportunity_accepts_board_commission()
	test_player_summaries_name_opportunity_targets()
	test_district_daily_deck_has_exact_first_slice_entries()
	test_premonition_reveals_one_hidden_district_opportunity()
	test_district_opportunity_resolves_registered_encounter()
	return {"passed": _passed, "failed": _failed}


func test_game_state_persists_slice35_field_loop_state() -> void:
	var gs = GameStateScript.new()
	gs._ready()
	var encoded := gs.to_dict()
	encoded["daily_field_opportunities"] = {
		"day": 3,
		"seed": 35003,
		"npc": {"old_li": [{"id": "old_li_private_tip"}]},
		"districts": {"shadow_alley": [{"id": "shadow_needle_lamp", "revealed": true}]},
	}
	encoded["field_hook_log"] = [{"day": 3, "hook_type": "premonition", "target_id": "shadow_needle_lamp"}]
	encoded["commission_modifier_history"] = {"commission_moonlight_grass_001": ["urgent"]}
	var restored = GameStateScript.new()
	restored.from_dict(encoded)
	var roundtrip := restored.to_dict()
	var opportunities: Dictionary = roundtrip.get("daily_field_opportunities", {}) if roundtrip.get("daily_field_opportunities", {}) is Dictionary else {}
	var field_hook_log: Array = roundtrip.get("field_hook_log", []) if roundtrip.get("field_hook_log", []) is Array else []
	var modifier_history: Dictionary = roundtrip.get("commission_modifier_history", {}) if roundtrip.get("commission_modifier_history", {}) is Dictionary else {}
	assert_true(roundtrip.has("daily_field_opportunities"), "daily_field_opportunities key is serialized")
	assert_eq(int(opportunities.get("day", 0)), 3, "daily_field_opportunities day roundtrips")
	assert_eq(str(opportunities.get("npc", {}).get("old_li", [])[0].get("id", "")) if opportunities.has("npc") else "", "old_li_private_tip", "NPC opportunities roundtrip")
	assert_true(roundtrip.has("field_hook_log"), "field_hook_log key is serialized")
	assert_eq(str(field_hook_log[0].get("hook_type", "")) if not field_hook_log.is_empty() else "", "premonition", "field_hook_log roundtrips")
	assert_true(roundtrip.has("commission_modifier_history"), "commission_modifier_history key is serialized")
	assert_true(modifier_history.get("commission_moonlight_grass_001", []).has("urgent"), "commission modifier history roundtrips")


func test_npc_state_persists_daily_opportunity_fields() -> void:
	var restored = NpcKnowledgeStateScript.from_dict({
		"daily_mood": "guarded",
		"favor_debt": 1,
		"interaction_fatigue": 2,
		"today_opportunities": [{"id": "vera_free_watch", "source_type": "free_rumor"}],
	})
	var encoded := restored.to_dict()
	var today: Array = encoded.get("today_opportunities", []) if encoded.get("today_opportunities", []) is Array else []
	assert_true(encoded.has("daily_mood"), "daily_mood key is serialized")
	assert_eq(str(encoded.get("daily_mood", "")), "guarded", "daily_mood roundtrips")
	assert_eq(int(encoded.get("favor_debt", 0)), 1, "favor_debt roundtrips")
	assert_eq(int(encoded.get("interaction_fatigue", 0)), 2, "interaction_fatigue roundtrips")
	assert_true(encoded.has("today_opportunities"), "today_opportunities key is serialized")
	assert_eq(str(today[0].get("id", "")) if not today.is_empty() else "", "vera_free_watch", "today_opportunities roundtrip")


func test_npc_daily_opportunities_are_deterministic_and_gated() -> void:
	var service = _field_service()
	if service == null:
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 3
	gs.time_of_day = "night"
	gs.current_district = "shadow_alley"
	var low: Dictionary = service.refresh_daily(gs, 35003)
	assert_true(bool(low.get("ok", false)), "daily opportunity refresh succeeds")
	var xiao_low: Array = service.available_npc_opportunities("xiao_ran", gs)
	assert_true(not _ids(xiao_low).has("xiao_ran_well_confession"), "trust gate hides Xiao Ran well confession")
	var state = NpcKnowledgeStateScript.new()
	state.trust = 25
	gs.npc_relations["xiao_ran"] = state
	var high: Dictionary = service.refresh_daily(gs, 35003)
	assert_true(bool(high.get("ok", false)), "daily opportunity refresh succeeds after trust")
	var xiao_high: Array = service.available_npc_opportunities("xiao_ran", gs)
	assert_true(_ids(xiao_high).has("xiao_ran_well_confession"), "trust gate reveals Xiao Ran well confession")
	var again: Dictionary = service.refresh_daily(gs, 35003)
	assert_eq(str(again.get("daily_key", "")), str(high.get("daily_key", "")), "same day and seed keep deterministic daily key")


func test_npc_daily_opportunities_respect_last_seen_fatigue() -> void:
	var service = _field_service()
	if service == null:
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 4
	gs.time_of_day = "night"
	var old_li = NpcKnowledgeStateScript.new()
	old_li.trust = 45
	old_li.last_seen_day = 4
	old_li.interaction_fatigue = 1
	gs.npc_relations["old_li"] = old_li
	service.refresh_daily(gs, 35004)
	var entries: Array = service.available_npc_opportunities("old_li", gs)
	assert_true(_ids(entries).has("old_li_short_warning"), "low-fatigue recurring warning remains available")
	assert_true(not _ids(entries).has("old_li_private_request"), "high-cost private request is hidden after same-day fatigue")


func test_first_pass_npc_definitions_list_field_opportunities() -> void:
	var expected := {
		"res://data/npc/shadow_alley/old_li.json": ["old_li_short_warning", "old_li_private_request"],
		"res://data/npc/shadow_alley/xiao_ran.json": ["xiao_ran_well_confession", "xiao_ran_shadow_watch"],
		"res://data/npc/misty_port/vera_lighthouse.json": ["vera_tide_note", "vera_moonlight_watch"],
		"res://data/npc/misty_port/carl_smuggler.json": ["carl_manifest_whisper", "carl_sealed_gate"],
	}
	for path in expected.keys():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(parsed is Dictionary, "%s parses as JSON" % path)
		if not parsed is Dictionary:
			continue
		assert_eq(_string_array((parsed as Dictionary).get("field_opportunities", [])), expected[path], "%s lists first-pass field opportunities" % path)


func test_npc_interaction_service_exposes_daily_opportunities() -> void:
	var service = NpcInteractionServiceScript.new()
	assert_true(service.has_method("available_daily_opportunities_for_npc"), "NpcInteractionService exposes daily opportunities")
	if not service.has_method("available_daily_opportunities_for_npc"):
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 3
	gs.time_of_day = "night"
	gs.current_district = "shadow_alley"
	var state = NpcKnowledgeStateScript.new()
	state.trust = 25
	gs.npc_relations["xiao_ran"] = state
	var entries: Array = service.available_daily_opportunities_for_npc("xiao_ran", gs)
	assert_true(_ids(entries).has("xiao_ran_well_confession"), "NpcInteractionService returns gated daily opportunity")


func test_commission_npc_opportunity_accepts_board_commission() -> void:
	var service = _field_service()
	if service == null:
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 1
	gs.sequence = 9
	gs.time_of_day = "night"
	gs.current_district = "shadow_alley"
	var old_li = NpcKnowledgeStateScript.new()
	old_li.trust = 45
	old_li.last_seen_day = 1
	old_li.interaction_fatigue = 0
	gs.npc_relations["old_li"] = old_li
	service.refresh_daily(gs, 35001)
	var entries: Array = service.available_npc_opportunities("old_li", gs)
	assert_true(_ids(entries).has("old_li_private_request"), "Old Li private request is available before same-day fatigue")
	var result: Dictionary = service.resolve_npc_opportunity(gs, "old_li", "old_li_private_request")
	assert_true(bool(result.get("ok", false)), "commission-type NPC opportunity resolves successfully")
	assert_eq(str(result.get("commission_id", "")), "commission_old_li_letter_001", "commission opportunity result carries accepted commission id")
	assert_true("commission_old_li_letter_001" in gs.accepted_commissions, "commission-type NPC opportunity records accepted commission id")
	assert_eq(_available_commission_status(gs, "commission_old_li_letter_001"), "accepted", "commission-type NPC opportunity upserts board-visible accepted status")
	assert_eq(int(old_li.favor_debt), 1, "commission-type NPC opportunity applies favor debt cost once")
	var display_text := str(result.get("display_text", ""))
	assert_true(display_text.contains("\u59d4\u6258") and display_text.find("commission_old_li_letter_001") < 0, "commission opportunity result stays player-facing")


func test_player_summaries_name_opportunity_targets() -> void:
	var service = _field_service()
	if service == null:
		return
	assert_true(service.has_method("player_title_for_opportunity"), "FieldOpportunityService exposes player opportunity titles")
	assert_true(service.has_method("player_tooltip_for_opportunity"), "FieldOpportunityService exposes player opportunity tooltips")
	if not service.has_method("player_title_for_opportunity") or not service.has_method("player_tooltip_for_opportunity"):
		return
	var npc_entry := {
		"id": "old_li_short_warning",
		"display_name": "Alley warning",
		"source_type": "free_rumor",
		"grant": {"intel_id": "intel_shadow_alley_church_patrol_001"},
		"result_text": "Old Li passes along a short warning from the alley end.",
	}
	var title := str(service.call("player_title_for_opportunity", npc_entry))
	var tooltip := str(service.call("player_tooltip_for_opportunity", npc_entry))
	assert_true(title.contains("\u6559\u4f1a") and title.find("Alley warning") < 0 and title.find("\u7ebf\u7d22") < 0, "NPC opportunity title names the granted intel target")
	assert_true(tooltip.contains("\u60c5\u62a5") and tooltip.contains("\u6559\u4f1a"), "NPC opportunity tooltip explains the reward target")
	var district_entry := {"id": "shadow_needle_lamp", "encounter_id": "enc_shadow_alley_needle_lamp", "category": "free_flavor"}
	var district_title := str(service.call("player_title_for_opportunity", district_entry))
	var district_tooltip := str(service.call("player_tooltip_for_opportunity", district_entry))
	assert_true(district_title.contains("\u9488\u706f") or district_title.contains("\u5f02\u52a8"), "district opportunity title names the encounter content")
	assert_true(district_tooltip.contains("\u906d\u9047") and district_tooltip.find("enc_shadow") < 0, "district opportunity tooltip hides raw encounter ids")


func test_district_daily_deck_has_exact_first_slice_entries() -> void:
	var service = _field_service()
	if service == null or not _require_method(service, "available_district_opportunities"):
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 5
	gs.time_of_day = "night"
	gs.current_district = "misty_port"
	var carl = NpcKnowledgeStateScript.new()
	carl.trust = 20
	carl.suspicion = 25
	gs.npc_relations["carl_smuggler"] = carl
	service.refresh_daily(gs, 35005)
	var shadow: Array = service.available_district_opportunities("shadow_alley", gs)
	var misty: Array = service.available_district_opportunities("misty_port", gs)
	assert_eq(shadow.size(), 4, "Shadow Alley has exactly four first-pass district opportunities")
	assert_eq(misty.size(), 4, "Misty Port has exactly four first-pass district opportunities")
	assert_true(_ids(misty).has("misty_carl_manifest"), "Misty Port deck includes Carl NPC lead")
	assert_true(_ids(misty).has("misty_smuggler_check"), "Misty Port deck includes risk event")


func test_premonition_reveals_one_hidden_district_opportunity() -> void:
	var service = _field_service()
	if service == null:
		return
	if not _require_method(service, "visible_district_opportunities") or not _require_method(service, "reveal_hidden_district_opportunity"):
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 5
	gs.time_of_day = "night"
	gs.current_district = "misty_port"
	var state = NpcKnowledgeStateScript.new()
	state.trust = 20
	state.suspicion = 25
	gs.npc_relations["carl_smuggler"] = state
	service.refresh_daily(gs, 35005)
	var before: Array = service.visible_district_opportunities("misty_port", gs)
	assert_true(not _ids(before).has("misty_carl_manifest"), "hidden Carl lead starts hidden")
	var reveal: Dictionary = service.reveal_hidden_district_opportunity(gs, "misty_port", "premonition")
	assert_true(bool(reveal.get("ok", false)), "premonition reveal succeeds")
	var after: Array = service.visible_district_opportunities("misty_port", gs)
	assert_true(_ids(after).has(str(reveal.get("opportunity_id", ""))), "revealed hidden event becomes visible")


func test_district_opportunity_resolves_registered_encounter() -> void:
	var service = _field_service()
	if service == null or not _require_method(service, "encounter_for_district_opportunity"):
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 5
	gs.time_of_day = "night"
	gs.current_district = "misty_port"
	service.refresh_daily(gs, 35005)
	var encounter = service.encounter_for_district_opportunity(gs, "misty_port", "misty_carl_manifest")
	assert_true(encounter != null, "district opportunity resolves registered encounter")
	if encounter != null:
		assert_eq(str(encounter.get("id")), "enc_misty_port_carl_manifest", "resolved encounter id matches opportunity")


func _field_service():
	var script = load("res://scripts/world/field_opportunity_service.gd")
	assert_true(script != null, "FieldOpportunityService script exists")
	if script == null:
		return null
	return script.new()


func _require_method(target, method_name: String) -> bool:
	var has: bool = target != null and target.has_method(method_name)
	assert_true(has, "FieldOpportunityService exposes %s" % method_name)
	return has


func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		if entry is Dictionary:
			result.append(str(entry.get("id", "")))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _available_commission_status(game_state, commission_id: String) -> String:
	var value: Variant = game_state.get("available_commissions")
	if value is Array:
		for item in value:
			if item is Dictionary and str((item as Dictionary).get("id", "")) == commission_id:
				return str((item as Dictionary).get("status", ""))
	return ""


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
