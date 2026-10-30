extends RefCounted

const SERVICE_PATH := "res://scripts/ai_gm/ai_gm_service.gd"
const TEMPLATE_POOLS_PATH := "res://scripts/ai_gm/template_pools.gd"
const TEMPLATE_FILL_PATH := "res://scripts/ai_gm/template_fill.gd"
const PROMPT_CONTEXT_PATH := "res://scripts/ai_gm/prompt_context.gd"
const TEMPLATE_DIR := "res://data/ai_gm/templates"

const EXPECTED_SCENES := [
	"forge_resolve",
	"unknown_reaction",
	"tower_floor_transition",
	"combat_resolve_critical",
	"boss_victory",
	"mainline_boss",
	"brand_naming",
	"contract_violation",
	"cycle_summary",
	"day7_event",
	"pollution_stage_transition",
	"card_upgrade",
	"sequence_promotion",
	"social_resolve",
	"church_threshold_10",
	"church_threshold_25",
	"church_threshold_50",
	"residual_identity_create",
	"residual_identity_expire",
	"npc_first_meet",
	"npc_relation_shift",
	"npc_layer_reveal",
	"npc_perception_swap",
	"acting_drill_collapse",
	"rumor_generated",
	"encounter_resolve",
]

const LIVE_POOL_IDS := {
	"FORGE_RESULT_TEMPLATES": "forge_resolve",
	"UNKNOWN_REACTION_TEMPLATES": "unknown_reaction",
	"TOWER_TRANSITION_TEMPLATES": "tower_floor_transition",
	"COMBAT_RESOLVE_TEMPLATES": "combat_resolve_critical",
	"BOSS_VICTORY_TEMPLATES": "boss_victory",
	"MAINLINE_BOSS_TEMPLATES": "mainline_boss",
	"BRAND_NAMING_TEMPLATES": "brand_naming",
	"CONTRACT_VIOLATION_TEMPLATES": "contract_violation",
	"CYCLE_SUMMARY_TEMPLATES": "cycle_summary",
	"DAY7_TEMPLATES": "day7_event",
	"POLLUTION_STAGE_TEMPLATES": "pollution_stage_transition",
	"CARD_UPGRADE_TEMPLATES": "card_upgrade",
	"SEQUENCE_PROMOTION_TEMPLATES": "sequence_promotion",
	"SOCIAL_RESOLVE_TEMPLATES": "social_resolve",
	"CHURCH_THRESHOLD_TEMPLATES_10": "church_threshold_10",
	"CHURCH_THRESHOLD_TEMPLATES_25": "church_threshold_25",
	"CHURCH_THRESHOLD_TEMPLATES_50": "church_threshold_50",
	"RESIDUAL_IDENTITY_TEMPLATES": "residual_identity_create",
	"NPC_FIRST_MEET_TEMPLATES": "npc_first_meet",
	"NPC_RELATION_SHIFT_TEMPLATES": "npc_relation_shift",
	"NPC_LAYER_REVEAL_TEMPLATES": "npc_layer_reveal",
	"NPC_PERCEPTION_SWAP_TEMPLATES": "npc_perception_swap",
	"ACTING_DRILL_COLLAPSE_TEMPLATES": "acting_drill_collapse",
	"RUMOR_TEMPLATES": "rumor_generated",
	"ENCOUNTER_RESOLVE_TEMPLATES": "encounter_resolve",
}

const REQUIRED_ASPECTS := ["影", "星", "视", "知", "名", "血"]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_template_fill.gd --")
	test_t4_scripts_exist_and_load()
	test_all_scene_template_files_have_minimum_size()
	test_live_pool_ids_resolve_to_template_files()
	test_aspect_phrases_have_required_ranges()
	test_template_render_fills_scene_and_player_placeholders()
	test_missing_placeholder_degrades_without_crashing()
	test_ai_gm_service_uses_template_fallback_when_offline()
	return {"passed": _passed, "failed": _failed}


func test_t4_scripts_exist_and_load() -> void:
	for path in [TEMPLATE_POOLS_PATH, TEMPLATE_FILL_PATH]:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		if ResourceLoader.exists(path):
			var script = load(path)
			assert_true(script != null and script.can_instantiate(), "%s loads" % path)


func test_all_scene_template_files_have_minimum_size() -> void:
	var pools_script = _load_required(TEMPLATE_POOLS_PATH)
	if pools_script == null:
		return
	var pools = pools_script.new()
	for scene in EXPECTED_SCENES:
		var path := "%s/%s.json" % [TEMPLATE_DIR, scene]
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		var templates: Array = pools.load_scene_pool(scene)
		assert_true(templates.size() >= 30, "%s has at least 30 templates" % scene)
		assert_true(_all_strings(templates), "%s templates are non-empty strings" % scene)


func test_live_pool_ids_resolve_to_template_files() -> void:
	var pools_script = _load_required(TEMPLATE_POOLS_PATH)
	if pools_script == null:
		return
	var pools = pools_script.new()
	for pool_id in LIVE_POOL_IDS.keys():
		var templates: Array = pools.get_templates(pool_id)
		assert_true(templates.size() >= 30, "%s resolves to at least 30 templates" % pool_id)


func test_aspect_phrases_have_required_ranges() -> void:
	var pools_script = _load_required(TEMPLATE_POOLS_PATH)
	if pools_script == null:
		return
	var pools = pools_script.new()
	var phrases: Dictionary = pools.load_aspect_phrases()
	for aspect in REQUIRED_ASPECTS:
		assert_true(phrases.has(aspect), "aspect phrases include %s" % aspect)
		var entries: Array = phrases.get(aspect, [])
		assert_true(entries.size() >= 3 and entries.size() <= 5, "%s has 3-5 phrases" % aspect)
		assert_true(_all_strings(entries), "%s phrases are non-empty strings" % aspect)


func test_template_render_fills_scene_and_player_placeholders() -> void:
	var fill_script = _load_required(TEMPLATE_FILL_PATH)
	var ctx = _context("forge_resolve", "FORGE_RESULT_TEMPLATES")
	if fill_script == null or ctx == null:
		return
	ctx.scene_payload = {
		"district": "shadow_alley",
		"quality": "III",
		"reaction_id": "ash_mirror",
	}
	ctx.player_state = {"day": 3, "sequence": 8}
	var text: String = fill_script.render("你在{district}的煤雾里看见{quality}级{reaction_id}，第{day}日仍留下钩子。", ctx)
	assert_true(text.find("{") == -1 and text.find("}") == -1, "render removes known placeholders")
	assert_true(text.contains("shadow_alley"), "render fills scene_payload key")
	assert_true(text.contains("III"), "render fills second scene_payload key")
	assert_true(text.contains("3"), "render fills player_state key")


func test_missing_placeholder_degrades_without_crashing() -> void:
	var fill_script = _load_required(TEMPLATE_FILL_PATH)
	var ctx = _context("tower_floor_transition", "TOWER_TRANSITION_TEMPLATES")
	if fill_script == null or ctx == null:
		return
	var text: String = fill_script.render("你听见{missing_key}在门后回声，仍继续向前。", ctx)
	assert_true(text.find("{missing_key}") == -1, "missing placeholder is not leaked raw")
	assert_true(text.contains("未明"), "missing placeholder degrades to readable fallback")


func test_ai_gm_service_uses_template_fallback_when_offline() -> void:
	var service_script = _load_required(SERVICE_PATH)
	var ctx = _context("forge_resolve", "FORGE_RESULT_TEMPLATES")
	if service_script == null or ctx == null:
		return
	ctx.scene_payload = {
		"glyph_arrangement": "影+星+名",
		"primary_source": "影",
		"reaction_id": "ash_mirror",
		"perfect_rate": "steady",
		"quality": "III",
		"dao_choices": "kept_silence",
		"brand_dropped": "none",
		"district": "shadow_alley",
		"aspect": "影",
	}
	ctx.player_state = {"sequence": 8, "pollution": 12, "pollution_stage": 0, "cycle": 1, "day": 3}
	var service = service_script.new()
	var text: String = service.call_ai_gm(ctx)
	assert_eq(str(service.last_result.get("source", "")), "fallback", "offline service records fallback source")
	assert_true(not text.begins_with("fallback:"), "offline service returns rendered template text")
	assert_true(text.find("{") == -1 and text.find("}") == -1, "offline service fallback does not leak placeholders")
	assert_true(text.length() >= 12 and text.length() <= 160, "offline fallback text length is in range")


func _context(scene: String, pool_id: String):
	var context_script = _load_required(PROMPT_CONTEXT_PATH)
	if context_script == null:
		return null
	var ctx = context_script.new()
	ctx.scene = scene
	ctx.fallback_template_pool = pool_id
	ctx.player_state = {"sequence": 9, "pollution": 10, "cycle": 1, "day": 1}
	ctx.scene_payload = {"district": "shadow_alley", "aspect": "影"}
	return ctx


func _all_strings(values: Array) -> bool:
	for value in values:
		if not (value is String):
			return false
		if str(value).strip_edges() == "":
			return false
	return true


func _load_required(path: String):
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


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
