extends RefCounted

const COST_SAMPLER_PATH := "res://scripts/ai_gm/ai_gm_cost_sampler.gd"
const TEMPLATE_DIR := "res://data/ai_gm/templates"
const PROVIDER_PATH := "res://scripts/ai_gm/ai_gm_provider.gd"
const TEMPLATE_POOLS_PATH := "res://scripts/ai_gm/template_pools.gd"

const EXPECTED_SCENES := [
	{"scene": "forge_resolve", "pool": "FORGE_RESULT_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 50, "word_max": 100},
	{"scene": "unknown_reaction", "pool": "UNKNOWN_REACTION_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 50, "word_max": 100},
	{"scene": "tower_floor_transition", "pool": "TOWER_TRANSITION_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 30, "word_max": 30},
	{"scene": "combat_resolve_critical", "pool": "COMBAT_RESOLVE_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
	{"scene": "boss_victory", "pool": "BOSS_VICTORY_TEMPLATES", "tier": "haiku", "cost": 0.00003, "word_min": 100, "word_max": 150},
	{"scene": "mainline_boss", "pool": "MAINLINE_BOSS_TEMPLATES", "tier": "sonnet", "cost": 0.00100, "word_min": 200, "word_max": 500},
	{"scene": "brand_naming", "pool": "BRAND_NAMING_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
	{"scene": "contract_violation", "pool": "CONTRACT_VIOLATION_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 30, "word_max": 30},
	{"scene": "cycle_summary", "pool": "CYCLE_SUMMARY_TEMPLATES", "tier": "haiku", "cost": 0.00004, "word_min": 200, "word_max": 200},
	{"scene": "day7_event", "pool": "DAY7_TEMPLATES", "tier": "sonnet", "cost": 0.00100, "word_min": 200, "word_max": 500},
	{"scene": "pollution_stage_transition", "pool": "POLLUTION_STAGE_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
	{"scene": "dream_pollution_stage", "pool": "DREAM_STAGE_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50, "template_min": 5},
	{"scene": "lost_control_narration", "pool": "LOST_CONTROL_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
	{"scene": "card_upgrade", "pool": "CARD_UPGRADE_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
	{"scene": "sequence_promotion", "pool": "SEQUENCE_PROMOTION_TEMPLATES", "tier": "sonnet", "cost": 0.00100, "word_min": 200, "word_max": 200},
	{"scene": "social_resolve", "pool": "SOCIAL_RESOLVE_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
	{"scene": "church_threshold_10", "pool": "CHURCH_THRESHOLD_TEMPLATES_10", "tier": "haiku", "cost": 0.00003, "word_min": 100, "word_max": 100},
	{"scene": "church_threshold_25", "pool": "CHURCH_THRESHOLD_TEMPLATES_25", "tier": "sonnet", "cost": 0.00100, "word_min": 200, "word_max": 200},
	{"scene": "church_threshold_50", "pool": "CHURCH_THRESHOLD_TEMPLATES_50", "tier": "sonnet", "cost": 0.00150, "word_min": 300, "word_max": 300},
	{"scene": "residual_identity_create", "pool": "RESIDUAL_IDENTITY_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 30, "word_max": 30},
	{"scene": "residual_identity_expire", "pool": "RESIDUAL_IDENTITY_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 20, "word_max": 20},
	{"scene": "npc_first_meet", "pool": "NPC_FIRST_MEET_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
	{"scene": "npc_relation_shift", "pool": "NPC_RELATION_SHIFT_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 30, "word_max": 30},
	{"scene": "npc_layer_reveal", "pool": "NPC_LAYER_REVEAL_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 50, "word_max": 50},
	{"scene": "npc_perception_swap", "pool": "NPC_PERCEPTION_SWAP_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 20, "word_max": 20},
	{"scene": "acting_drill_collapse", "pool": "ACTING_DRILL_COLLAPSE_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 30, "word_max": 30},
	{"scene": "rumor_generated", "pool": "RUMOR_TEMPLATES", "tier": "haiku", "cost": 0.00001, "word_min": 30, "word_max": 30},
	{"scene": "encounter_resolve", "pool": "ENCOUNTER_RESOLVE_TEMPLATES", "tier": "haiku", "cost": 0.00002, "word_min": 30, "word_max": 50},
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_ai_gm_cost_sampler.gd --")
	test_cost_sampler_script_exists_and_loads()
	test_r09_scene_cost_catalog_covers_slice4_prompt_scenes()
	test_template_files_cover_cost_catalog()
	test_typical_one_cycle_profile_stays_under_daily_cap()
	test_provider_metadata_matches_sampler_tiers()
	return {"passed": _passed, "failed": _failed}


func test_cost_sampler_script_exists_and_loads() -> void:
	assert_true(ResourceLoader.exists(COST_SAMPLER_PATH), "AIGMCostSampler script exists")
	var script = load(COST_SAMPLER_PATH)
	assert_true(script != null and script.can_instantiate(), "AIGMCostSampler script loads")


func test_r09_scene_cost_catalog_covers_slice4_prompt_scenes() -> void:
	var sampler = _sampler()
	if sampler == null:
		return
	assert_true(sampler.has_method("catalog"), "AIGMCostSampler exposes catalog()")
	assert_true(sampler.has_method("scene_info"), "AIGMCostSampler exposes scene_info(scene)")
	if not sampler.has_method("catalog") or not sampler.has_method("scene_info"):
		return
	var catalog: Dictionary = sampler.catalog()
	assert_eq(catalog.size(), EXPECTED_SCENES.size(), "cost catalog has one row per Slice 4 AI GM scene")
	for row in EXPECTED_SCENES:
		var scene := str(row.get("scene", ""))
		assert_true(catalog.has(scene), "cost catalog includes %s" % scene)
		var info: Dictionary = sampler.scene_info(scene)
		assert_eq(str(info.get("scene", "")), scene, "%s scene id is stable" % scene)
		assert_eq(str(info.get("fallback_template_pool", "")), str(row.get("pool", "")), "%s fallback pool matches plan" % scene)
		assert_eq(str(info.get("provider_tier", "")), str(row.get("tier", "")), "%s provider tier matches R09" % scene)
		assert_almost_eq(float(info.get("estimated_cost", -1.0)), float(row.get("cost", 0.0)), 0.000001, "%s estimated cost matches R09" % scene)
		assert_eq(int(info.get("word_min", -1)), int(row.get("word_min", 0)), "%s min word budget matches R09" % scene)
		assert_eq(int(info.get("word_max", -1)), int(row.get("word_max", 0)), "%s max word budget matches R09" % scene)


func test_template_files_cover_cost_catalog() -> void:
	var sampler = _sampler()
	var pools = _script_instance(TEMPLATE_POOLS_PATH)
	if sampler == null or pools == null:
		return
	var catalog: Dictionary = sampler.catalog()
	for scene in catalog.keys():
		var path := "%s/%s.json" % [TEMPLATE_DIR, str(scene)]
		assert_true(FileAccess.file_exists(path), "%s template file exists" % str(scene))
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_true(parsed is Dictionary, "%s template file parses as Dictionary" % str(scene))
		var templates: Array = []
		if parsed is Dictionary:
			var raw = (parsed as Dictionary).get("templates", [])
			templates = raw if raw is Array else []
		var info: Dictionary = sampler.scene_info(str(scene))
		var template_min := int(info.get("template_min", 30))
		assert_true(templates.size() >= template_min, "%s has at least %d fallback templates" % [str(scene), template_min])
		assert_true(not str(pools.pick_template(str(scene), "slice4_t14")).strip_edges().is_empty(), "%s can be selected by TemplatePools" % str(scene))


func test_typical_one_cycle_profile_stays_under_daily_cap() -> void:
	var sampler = _sampler()
	if sampler == null:
		return
	assert_true(sampler.has_method("default_typical_one_cycle_profile"), "AIGMCostSampler exposes default profile")
	assert_true(sampler.has_method("estimate_profile"), "AIGMCostSampler exposes estimate_profile(profile)")
	if not sampler.has_method("default_typical_one_cycle_profile") or not sampler.has_method("estimate_profile"):
		return
	var profile: Dictionary = sampler.default_typical_one_cycle_profile()
	var estimate: Dictionary = sampler.estimate_profile(profile)
	assert_true(bool(estimate.get("ok", false)), "typical one-cycle profile has no unknown scenes")
	assert_true(bool(estimate.get("within_daily_cap", false)), "typical one-cycle profile stays within $0.02")
	assert_between(float(estimate.get("total_cost", 0.0)), 0.0, 0.02, "typical one-cycle total cost is <= $0.02")
	assert_true(int(estimate.get("total_calls", 0)) >= 100, "typical one-cycle sample covers high-frequency calls")
	var rows: Array = estimate.get("rows", []) if estimate.get("rows", []) is Array else []
	assert_eq(rows.size(), profile.size(), "estimate returns one row per profile scene")
	for row in rows:
		var scene := str(row.get("scene", ""))
		assert_true(profile.has(scene), "%s estimate row traces to profile" % scene)
		assert_true(int(row.get("calls", 0)) > 0, "%s call count is positive" % scene)
		assert_true(float(row.get("unit_cost", 0.0)) > 0.0, "%s unit cost is positive" % scene)
		assert_almost_eq(float(row.get("total_cost", 0.0)), float(row.get("unit_cost", 0.0)) * int(row.get("calls", 0)), 0.000001, "%s total cost equals unit cost times calls" % scene)


func test_provider_metadata_matches_sampler_tiers() -> void:
	var sampler = _sampler()
	var provider_script = _load_script(PROVIDER_PATH)
	if sampler == null or provider_script == null:
		return
	var haiku = provider_script.provider("claude_haiku")
	var sonnet = provider_script.provider("claude_sonnet")
	assert_eq(str(haiku.tier), "haiku", "provider metadata exposes haiku tier")
	assert_eq(str(sonnet.tier), "sonnet", "provider metadata exposes sonnet tier")
	assert_true(float(haiku.estimated_cost) <= 0.00002, "haiku provider estimate remains low frequency-safe")
	assert_true(float(sonnet.estimated_cost) >= 0.001, "sonnet provider estimate remains high-impact")
	var catalog: Dictionary = sampler.catalog()
	for scene in catalog.keys():
		var tier := str(catalog[scene].get("provider_tier", ""))
		assert_true(tier == "haiku" or tier == "sonnet", "%s uses a supported provider tier" % str(scene))


func _sampler():
	return _script_instance(COST_SAMPLER_PATH)


func _script_instance(path: String):
	var script = _load_script(path)
	if script == null:
		return null
	return script.new()


func _load_script(path: String):
	if not ResourceLoader.exists(path):
		assert_true(false, "%s exists" % path)
		return null
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s loads" % path)
		return null
	return script


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_between(actual: float, low: float, high: float, message: String) -> void:
	if actual >= low and actual <= high:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected %.6f..%.6f, got %.6f" % [message, low, high, actual])


func assert_almost_eq(actual: float, expected: float, epsilon: float, message: String) -> void:
	if abs(actual - expected) <= epsilon:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected %.6f, got %.6f" % [message, expected, actual])


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
