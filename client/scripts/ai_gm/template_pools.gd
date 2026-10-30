class_name TemplatePools
extends RefCounted

const TEMPLATE_DIR := "res://data/ai_gm/templates"
const ASPECT_PHRASES_PATH := "res://data/ai_gm/aspect_phrases.json"

const POOL_TO_SCENE := {
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
	"DREAM_STAGE_TEMPLATES": "dream_pollution_stage",
	"LOST_CONTROL_TEMPLATES": "lost_control_narration",
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

var _pool_cache: Dictionary = {}
var _aspect_cache: Dictionary = {}


func scene_for_pool_id(pool_or_scene_id: String) -> String:
	return str(POOL_TO_SCENE.get(pool_or_scene_id, pool_or_scene_id))


func get_templates(pool_or_scene_id: String) -> Array:
	return load_scene_pool(scene_for_pool_id(pool_or_scene_id))


func load_scene_pool(scene: String) -> Array:
	if _pool_cache.has(scene):
		return (_pool_cache[scene] as Array).duplicate()

	var path := "%s/%s.json" % [TEMPLATE_DIR, scene]
	var templates: Array[String] = []
	if not FileAccess.file_exists(path):
		push_warning("[TemplatePools] missing pool file: %s" % path)
		_pool_cache[scene] = templates
		return templates.duplicate()

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var raw_templates = parsed.get("templates", [])
		if raw_templates is Array:
			for item in raw_templates:
				var text := str(item).strip_edges()
				if text != "":
					templates.append(text)

	if templates.is_empty():
		push_warning("[TemplatePools] pool has no templates: %s" % path)
	_pool_cache[scene] = templates
	return templates.duplicate()


func pick_template(pool_or_scene_id: String, seed_text: String = "") -> String:
	var templates := get_templates(pool_or_scene_id)
	if templates.is_empty():
		return ""
	var seed := seed_text
	if seed == "":
		seed = pool_or_scene_id
	var index := _positive_hash(seed) % templates.size()
	return str(templates[index])


func template_for_context(ctx) -> String:
	if ctx == null:
		return ""
	var pool_id := str(ctx.fallback_template_pool)
	if pool_id.strip_edges() == "":
		pool_id = str(ctx.scene)
	var scene_id := str(ctx.scene)
	if scene_id.strip_edges() != "" and not load_scene_pool(scene_id).is_empty():
		return pick_template(scene_id, _context_seed(ctx))
	return pick_template(pool_id, _context_seed(ctx))


func load_aspect_phrases() -> Dictionary:
	if not _aspect_cache.is_empty():
		return _aspect_cache.duplicate(true)
	if not FileAccess.file_exists(ASPECT_PHRASES_PATH):
		push_warning("[TemplatePools] missing aspect phrases: %s" % ASPECT_PHRASES_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ASPECT_PHRASES_PATH))
	if parsed is Dictionary:
		_aspect_cache = parsed.duplicate(true)
	return _aspect_cache.duplicate(true)


func _context_seed(ctx) -> String:
	if ctx == null:
		return ""
	var payload: Dictionary = {}
	if ctx.has_method("to_dict"):
		payload = ctx.to_dict()
	else:
		payload = {
			"scene": str(ctx.scene),
			"fallback_template_pool": str(ctx.fallback_template_pool),
		}
	return JSON.stringify(payload)


func _positive_hash(value: String) -> int:
	var result := int(value.hash())
	if result < 0:
		result = -result
	return result
