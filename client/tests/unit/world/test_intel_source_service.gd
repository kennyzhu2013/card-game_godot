extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")

const INTEL_SOURCE_SERVICE_PATH := "res://scripts/world/intel_source_service.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_intel_source_service.gd --")
	test_free_rumor_grants_intel_without_lingstones()
	test_npc_deep_chat_spends_ap_and_increases_fatigue()
	test_paid_npc_intel_spends_lingstones()
	test_trust_gate_failure_applies_risk_without_spending_ap()
	test_npc_interaction_service_resolves_daily_opportunity()
	return {"passed": _passed, "failed": _failed}


func test_free_rumor_grants_intel_without_lingstones() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 3
	gs.time_of_day = "night"
	gs.lingstones = 17
	var state = _npc_state(30)
	gs.npc_relations["old_li"] = state
	var result: Dictionary = service.resolve(gs, "old_li", {
		"id": "old_li_short_warning",
		"source_type": "free_rumor",
		"cost": {},
		"gates": {"trust_min": 30},
		"grant": {"intel_id": "intel_shadow_alley_church_patrol_001"},
		"result_text": "老李给出一条巡逻短讯。",
	})
	assert_true(bool(result.get("ok", false)), "free rumor resolves successfully")
	assert_eq(int(gs.lingstones), 17, "free rumor does not spend lingstones")
	assert_true(_active_ids(gs).has("intel_shadow_alley_church_patrol_001"), "free rumor grants intel")
	gs.queue_free()


func test_npc_deep_chat_spends_ap_and_increases_fatigue() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 4
	gs.ap = 3
	var state = _npc_state(25)
	gs.npc_relations["xiao_ran"] = state
	var result: Dictionary = service.resolve(gs, "xiao_ran", {
		"id": "xiao_ran_well_confession",
		"source_type": "npc_deep_chat",
		"cost": {"ap": 1},
		"gates": {"trust_min": 20},
		"grant": {"intel_id": "intel_xiao_ran_well_node4_001"},
		"result_text": "小染说出井边证词。",
	})
	assert_true(bool(result.get("ok", false)), "deep chat resolves successfully")
	assert_eq(int(gs.ap), 2, "deep chat spends AP")
	assert_eq(int(state.last_seen_day), 4, "deep chat records same-day interaction")
	assert_eq(int(state.interaction_fatigue), 1, "deep chat increases interaction fatigue")
	assert_true(_active_ids(gs).has("intel_xiao_ran_well_node4_001"), "deep chat grants intel")
	gs.queue_free()


func test_paid_npc_intel_spends_lingstones() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.lingstones = 15
	var state = _npc_state(0)
	gs.npc_relations["carl_smuggler"] = state
	var result: Dictionary = service.resolve(gs, "carl_smuggler", {
		"id": "carl_manifest_whisper",
		"source_type": "paid_npc_intel",
		"cost": {"lingstones": 10},
		"gates": {"trust_min": 0},
		"grant": {"intel_id": "intel_carl_smuggler_auction_001"},
		"result_text": "卡尔收下小费，给出货单耳语。",
	})
	assert_true(bool(result.get("ok", false)), "paid NPC intel resolves successfully")
	assert_eq(int(gs.lingstones), 5, "paid NPC intel spends lingstones")
	assert_true(_active_ids(gs).has("intel_carl_smuggler_auction_001"), "paid NPC intel grants intel")
	gs.queue_free()


func test_trust_gate_failure_applies_risk_without_spending_ap() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 5
	gs.ap = 5
	var state = _npc_state(5)
	state.suspicion = 2
	gs.npc_relations["carl_smuggler"] = state
	var result: Dictionary = service.resolve(gs, "carl_smuggler", {
		"id": "carl_sealed_gate",
		"source_type": "npc_deep_chat",
		"cost": {"ap": 1},
		"gates": {"trust_min": 20},
		"risk": {"suspicion_delta_on_fail": 5},
		"grant": {"intel_id": "intel_carl_smuggler_port_gate_001"},
		"result_text": "卡尔确认封仓门后的调包。",
	})
	assert_true(not bool(result.get("ok", true)), "trust-gated intel fails below required trust")
	assert_eq(str(result.get("reason", "")), "trust_too_low", "trust gate failure reports reason")
	assert_eq(int(gs.ap), 5, "trust gate failure does not spend AP")
	assert_eq(int(state.suspicion), 7, "trust gate failure applies suspicion risk")
	assert_true(not _active_ids(gs).has("intel_carl_smuggler_port_gate_001"), "trust gate failure does not grant intel")
	gs.queue_free()


func test_npc_interaction_service_resolves_daily_opportunity() -> void:
	var service = NpcInteractionServiceScript.new()
	assert_true(service.has_method("resolve_daily_opportunity"), "NpcInteractionService exposes daily opportunity resolver")
	if not service.has_method("resolve_daily_opportunity"):
		return
	var gs = _fresh_state()
	gs.day = 3
	gs.time_of_day = "night"
	gs.ap = 2
	var state = _npc_state(25)
	gs.npc_relations["xiao_ran"] = state
	var result: Dictionary = service.resolve_daily_opportunity("xiao_ran", gs, "xiao_ran_well_confession")
	assert_true(bool(result.get("ok", false)), "daily opportunity resolves through NpcInteractionService")
	assert_eq(int(gs.ap), 1, "daily opportunity spends declared AP")
	assert_eq(int(state.interaction_fatigue), 1, "daily opportunity updates NPC fatigue")
	assert_true(_active_ids(gs).has("intel_xiao_ran_well_node4_001"), "daily opportunity grants declared intel")
	gs.queue_free()


func _service():
	var script = load(INTEL_SOURCE_SERVICE_PATH)
	assert_true(script != null, "IntelSourceService script exists")
	if script == null or not script.can_instantiate():
		return null
	var service = script.new()
	assert_true(service.has_method("resolve"), "IntelSourceService exposes resolve")
	if not service.has_method("resolve"):
		return null
	return service


func _fresh_state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _npc_state(trust: int):
	var state = NpcKnowledgeStateScript.new()
	state.trust = trust
	return state


func _active_ids(game_state) -> Array:
	var result: Array = []
	var active: Variant = game_state.get("active_rumors")
	if not active is Array:
		return result
	for intel in active:
		if intel is Dictionary:
			result.append(str((intel as Dictionary).get("id", "")))
	return result


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
