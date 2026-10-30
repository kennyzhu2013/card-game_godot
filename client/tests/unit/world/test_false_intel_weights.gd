extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const LOCATION_DIR := "res://data/locations"
const LOCATION_IDS := [
	"shadow_alley",
	"steelworks",
	"misty_port",
	"sacred_seven",
	"stone_tower",
	"ascetic_mountain",
]
const RUMOR_POOL_PATHS := [
	"res://data/rumors/shadow_alley_pool.json",
	"res://data/rumors/steelworks_pool.json",
	"res://data/rumors/misty_port_pool.json",
	"res://data/rumors/sacred_seven_pool.json",
	"res://data/rumors/stone_tower_pool.json",
	"res://data/rumors/ascetic_mountain_pool.json",
	"res://data/rumors/tavern_pool.json",
	"res://data/rumors/teahouse_pool.json",
]

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "rumor narration"


func run() -> Dictionary:
	print("\n-- test_false_intel_weights.gd --")
	test_streettalker_draws_truth_bands_by_church_awareness()
	test_streettalker_hides_at_church_awareness_75()
	test_false_lead_cost_payloads_are_present_and_apply()
	test_draw_rate_limits_rumor_generated_once_per_day()
	return {"passed": _passed, "failed": _failed}


func test_streettalker_draws_truth_bands_by_church_awareness() -> void:
	var service = _new_service(["draw_streettalker_rumor"])
	if service == null:
		return
	var low_counts := _sample_truth_bands(service, 10, 80)
	assert_eq(int(low_counts.get("true", 0)), 80, "awareness <25 draws only true intel")
	assert_eq(int(low_counts.get("partial", 0)), 0, "awareness <25 draws no partial intel")
	assert_eq(int(low_counts.get("false", 0)), 0, "awareness <25 draws no false intel")

	var mid_counts := _sample_truth_bands(service, 30, 200)
	assert_between(int(mid_counts.get("true", 0)), 75, 125, "awareness 25-49 roughly follows 50 percent true weight")
	assert_between(int(mid_counts.get("partial", 0)), 35, 85, "awareness 25-49 roughly follows 30 percent partial weight")
	assert_between(int(mid_counts.get("false", 0)), 20, 60, "awareness 25-49 roughly follows 20 percent false weight")

	var high_counts := _sample_truth_bands(service, 60, 200)
	assert_between(int(high_counts.get("true", 0)), 35, 85, "awareness 50-74 roughly follows 30 percent true weight")
	assert_between(int(high_counts.get("partial", 0)), 35, 85, "awareness 50-74 roughly follows 30 percent partial weight")
	assert_between(int(high_counts.get("false", 0)), 50, 110, "awareness 50-74 roughly follows 40 percent false weight")


func test_streettalker_hides_at_church_awareness_75() -> void:
	var service = _new_service(["draw_streettalker_rumor"])
	if service == null:
		return
	var gs = _fresh_state()
	gs.church_awareness = 75
	var result: Dictionary = service.call("draw_streettalker_rumor", gs, "shadow_alley_rumors", 3, 17)
	assert_true(not bool(result.get("ok", true)), "awareness >=75 draw is blocked")
	assert_eq(str(result.get("reason", "")), "streettalker_hidden", "awareness >=75 returns hidden reason")
	assert_eq(_result_intels(result).size(), 0, "awareness >=75 grants no intel")
	assert_eq(_active_rumors(gs).size(), 0, "awareness >=75 does not mutate active rumors")

	for district_id in LOCATION_IDS:
		var rumor := _rumor_hotspot(_location(district_id))
		assert_true(not rumor.is_empty(), "%s has a rumor hotspot" % district_id)
		if rumor.is_empty():
			continue
		var visible_when := str(rumor.get("visible_when", ""))
		assert_true(visible_when.find("church_awareness < 75") >= 0, "%s reuses church_awareness <75 hide gate" % district_id)
		assert_true(not HotspotResolverScript.evaluate_visible_when(visible_when, gs), "%s rumor hotspot hides at awareness 75" % district_id)
	gs.queue_free()


func test_false_lead_cost_payloads_are_present_and_apply() -> void:
	for path in RUMOR_POOL_PATHS:
		var pool := _json(path)
		for entry in _entries(pool):
			if not entry is Dictionary:
				continue
			var intel: Dictionary = entry
			if str(intel.get("category", "")) != "false":
				continue
			var false_lead: Dictionary = _dict(intel.get("false_lead", {}))
			var cost: Dictionary = _dict(false_lead.get("cost", {}))
			assert_true(not cost.is_empty(), "%s false intel has false_lead.cost" % str(intel.get("id", "")))
			assert_true(cost.has("lingstone"), "%s false_lead.cost has lingstone" % str(intel.get("id", "")))
			assert_true(cost.has("ap"), "%s false_lead.cost has ap" % str(intel.get("id", "")))
			assert_true(cost.has("suspicion"), "%s false_lead.cost has suspicion" % str(intel.get("id", "")))

	var service = _new_service(["apply_false_lead_cost"])
	if service == null:
		return
	var gs = _fresh_state()
	gs.lingstones = 30
	gs.ap = 6
	var npc_state = NpcKnowledgeStateScript.new()
	npc_state.suspicion = 8
	gs.npc_relations["old_li"] = npc_state
	var intel := {
		"id": "intel_false_cost_unit",
		"category": "false",
		"source_type": "rumor_streettalker",
		"source_district": "shadow_alley",
		"apply_target": {"kind": "false_lead.cost", "payload": {}},
		"false_lead": {"cost": {"lingstone": 7, "ap": 2, "suspicion": 6}},
	}
	var result: Dictionary = service.call("apply_false_lead_cost", gs, intel, {"target_npc_id": "old_li"})
	assert_true(bool(result.get("ok", false)), "apply_false_lead_cost succeeds")
	assert_eq(int(gs.lingstones), 23, "false lead spends configured lingstones")
	assert_eq(int(gs.ap), 4, "false lead spends configured AP")
	assert_eq(int(npc_state.suspicion), 14, "false lead increases target suspicion")
	var side_effects: Dictionary = _dict(result.get("side_effects_applied", {}))
	assert_eq(side_effects, {"lingstone": -7, "ap": -2, "suspicion": 6}, "false lead reports applied costs")
	gs.queue_free()


func test_draw_rate_limits_rumor_generated_once_per_day() -> void:
	var service = _new_service(["draw_streettalker_rumor", "set_ai_gm_service"])
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 4
	gs.time_of_day = "evening"
	gs.church_awareness = 30
	var fake := FakeAIGMService.new()
	service.call("set_ai_gm_service", fake)
	var first: Dictionary = service.call("draw_streettalker_rumor", gs, "misty_port_rumors", 3, 410)
	var second: Dictionary = service.call("draw_streettalker_rumor", gs, "misty_port_rumors", 3, 411)
	assert_true(bool(first.get("ok", false)), "first streettalker draw succeeds")
	assert_true(bool(second.get("ok", false)), "second same-day streettalker draw still grants intel")
	assert_eq(fake.calls.size(), 1, "rumor_generated AI GM is limited to once per day")
	if fake.calls.size() > 0:
		var ctx = fake.calls[0]
		assert_eq(str(ctx.scene), "rumor_generated", "draw uses rumor_generated scene")
		assert_eq(str(ctx.fallback_template_pool), "RUMOR_TEMPLATES", "draw uses rumor fallback pool")
		assert_true(bool(ctx.validate().get("valid", false)), "draw builds a valid rumor PromptContext")


func _sample_truth_bands(service, awareness: int, samples: int) -> Dictionary:
	var counts := {"true": 0, "partial": 0, "false": 0, "none": 0}
	for i in range(samples):
		var gs = _fresh_state()
		gs.day = 4
		gs.time_of_day = "evening"
		gs.church_awareness = awareness
		var result: Dictionary = service.call("draw_streettalker_rumor", gs, "shadow_alley_rumors", 1, 1000 + i)
		var intels := _result_intels(result)
		if intels.is_empty():
			counts["none"] = int(counts["none"]) + 1
		else:
			var band := _truth_band(intels[0])
			counts[band] = int(counts.get(band, 0)) + 1
		gs.queue_free()
	return counts


func _truth_band(intel: Dictionary) -> String:
	var target: Dictionary = _dict(intel.get("apply_target", {}))
	if str(intel.get("category", "")) == "false" or str(target.get("kind", "")) == "false_lead.cost":
		return "false"
	var truth := int(intel.get("truth_value", 100))
	if truth >= 100:
		return "true"
	if truth <= 49:
		return "false"
	return "partial"


func _new_service(required_methods: Array):
	var service = IntelServiceScript.new()
	for method in required_methods:
		assert_true(service.has_method(str(method)), "IntelService exposes %s()" % str(method))
		if not service.has_method(str(method)):
			return null
	return service


func _fresh_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.ap = 12
	gs.lingstones = 50
	gs.set("active_rumors", [])
	gs.set("heard_rumor_history", {})
	return gs


func _json(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "%s exists" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s parses as dictionary" % path)
	return parsed if parsed is Dictionary else {}


func _entries(pool: Dictionary) -> Array:
	var value: Variant = pool.get("entries", [])
	return value if value is Array else []


func _location(district_id: String) -> Dictionary:
	return _json("%s/%s.json" % [LOCATION_DIR, district_id])


func _rumor_hotspot(location: Dictionary) -> Dictionary:
	var hotspots: Variant = location.get("hotspots", [])
	if not hotspots is Array:
		return {}
	for hotspot in hotspots:
		if hotspot is Dictionary and str(hotspot.get("type", "")) == "rumor":
			return hotspot
	return {}


func _result_intels(result: Dictionary) -> Array:
	var value: Variant = result.get("intels", result.get("granted_intels", []))
	return value if value is Array else []


func _active_rumors(game_state) -> Array:
	var value: Variant = game_state.get("active_rumors")
	return value if value is Array else []


func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_between(actual: int, low: int, high: int, message: String) -> void:
	if actual >= low and actual <= high:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected %d..%d, got %d" % [message, low, high, actual])


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
