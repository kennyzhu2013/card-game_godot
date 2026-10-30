class_name AIGMCostSampler
extends RefCounted

const DAILY_COST_CAP := 0.02

const SCENE_CATALOG := {
	"forge_resolve": {"scene": "forge_resolve", "fallback_template_pool": "FORGE_RESULT_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 50, "word_max": 100},
	"unknown_reaction": {"scene": "unknown_reaction", "fallback_template_pool": "UNKNOWN_REACTION_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 50, "word_max": 100},
	"tower_floor_transition": {"scene": "tower_floor_transition", "fallback_template_pool": "TOWER_TRANSITION_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 30, "word_max": 30},
	"combat_resolve_critical": {"scene": "combat_resolve_critical", "fallback_template_pool": "COMBAT_RESOLVE_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
	"boss_victory": {"scene": "boss_victory", "fallback_template_pool": "BOSS_VICTORY_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00003, "word_min": 100, "word_max": 150},
	"mainline_boss": {"scene": "mainline_boss", "fallback_template_pool": "MAINLINE_BOSS_TEMPLATES", "provider_tier": "sonnet", "estimated_cost": 0.001, "word_min": 200, "word_max": 500},
	"brand_naming": {"scene": "brand_naming", "fallback_template_pool": "BRAND_NAMING_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
	"contract_violation": {"scene": "contract_violation", "fallback_template_pool": "CONTRACT_VIOLATION_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 30, "word_max": 30},
	"cycle_summary": {"scene": "cycle_summary", "fallback_template_pool": "CYCLE_SUMMARY_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00004, "word_min": 200, "word_max": 200},
	"day7_event": {"scene": "day7_event", "fallback_template_pool": "DAY7_TEMPLATES", "provider_tier": "sonnet", "estimated_cost": 0.001, "word_min": 200, "word_max": 500},
	"pollution_stage_transition": {"scene": "pollution_stage_transition", "fallback_template_pool": "POLLUTION_STAGE_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
	"dream_pollution_stage": {"scene": "dream_pollution_stage", "fallback_template_pool": "DREAM_STAGE_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50, "template_min": 5},
	"lost_control_narration": {"scene": "lost_control_narration", "fallback_template_pool": "LOST_CONTROL_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
	"card_upgrade": {"scene": "card_upgrade", "fallback_template_pool": "CARD_UPGRADE_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
	"sequence_promotion": {"scene": "sequence_promotion", "fallback_template_pool": "SEQUENCE_PROMOTION_TEMPLATES", "provider_tier": "sonnet", "estimated_cost": 0.001, "word_min": 200, "word_max": 200},
	"social_resolve": {"scene": "social_resolve", "fallback_template_pool": "SOCIAL_RESOLVE_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
	"church_threshold_10": {"scene": "church_threshold_10", "fallback_template_pool": "CHURCH_THRESHOLD_TEMPLATES_10", "provider_tier": "haiku", "estimated_cost": 0.00003, "word_min": 100, "word_max": 100},
	"church_threshold_25": {"scene": "church_threshold_25", "fallback_template_pool": "CHURCH_THRESHOLD_TEMPLATES_25", "provider_tier": "sonnet", "estimated_cost": 0.001, "word_min": 200, "word_max": 200},
	"church_threshold_50": {"scene": "church_threshold_50", "fallback_template_pool": "CHURCH_THRESHOLD_TEMPLATES_50", "provider_tier": "sonnet", "estimated_cost": 0.0015, "word_min": 300, "word_max": 300},
	"residual_identity_create": {"scene": "residual_identity_create", "fallback_template_pool": "RESIDUAL_IDENTITY_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 30, "word_max": 30},
	"residual_identity_expire": {"scene": "residual_identity_expire", "fallback_template_pool": "RESIDUAL_IDENTITY_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 20, "word_max": 20},
	"npc_first_meet": {"scene": "npc_first_meet", "fallback_template_pool": "NPC_FIRST_MEET_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
	"npc_relation_shift": {"scene": "npc_relation_shift", "fallback_template_pool": "NPC_RELATION_SHIFT_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 30, "word_max": 30},
	"npc_layer_reveal": {"scene": "npc_layer_reveal", "fallback_template_pool": "NPC_LAYER_REVEAL_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 50, "word_max": 50},
	"npc_perception_swap": {"scene": "npc_perception_swap", "fallback_template_pool": "NPC_PERCEPTION_SWAP_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 20, "word_max": 20},
	"acting_drill_collapse": {"scene": "acting_drill_collapse", "fallback_template_pool": "ACTING_DRILL_COLLAPSE_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 30, "word_max": 30},
	"rumor_generated": {"scene": "rumor_generated", "fallback_template_pool": "RUMOR_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00001, "word_min": 30, "word_max": 30},
	"encounter_resolve": {"scene": "encounter_resolve", "fallback_template_pool": "ENCOUNTER_RESOLVE_TEMPLATES", "provider_tier": "haiku", "estimated_cost": 0.00002, "word_min": 30, "word_max": 50},
}

const TYPICAL_ONE_CYCLE_PROFILE := {
	"forge_resolve": 2,
	"unknown_reaction": 1,
	"tower_floor_transition": 12,
	"combat_resolve_critical": 12,
	"boss_victory": 3,
	"mainline_boss": 1,
	"brand_naming": 2,
	"contract_violation": 3,
	"cycle_summary": 1,
	"day7_event": 1,
	"pollution_stage_transition": 4,
	"dream_pollution_stage": 4,
	"lost_control_narration": 2,
	"card_upgrade": 10,
	"sequence_promotion": 1,
	"social_resolve": 16,
	"church_threshold_10": 1,
	"church_threshold_25": 1,
	"church_threshold_50": 1,
	"residual_identity_create": 4,
	"residual_identity_expire": 4,
	"npc_first_meet": 12,
	"npc_relation_shift": 8,
	"npc_layer_reveal": 4,
	"npc_perception_swap": 4,
	"acting_drill_collapse": 5,
	"rumor_generated": 7,
	"encounter_resolve": 8,
}


func catalog() -> Dictionary:
	return SCENE_CATALOG.duplicate(true)


func scene_info(scene: String) -> Dictionary:
	return (SCENE_CATALOG.get(scene, {}) as Dictionary).duplicate(true)


func default_typical_one_cycle_profile() -> Dictionary:
	return TYPICAL_ONE_CYCLE_PROFILE.duplicate(true)


func estimate_profile(profile: Dictionary = {}) -> Dictionary:
	var selected := profile.duplicate(true)
	if selected.is_empty():
		selected = default_typical_one_cycle_profile()

	var rows: Array = []
	var unknown_scenes: Array[String] = []
	var total_calls := 0
	var total_cost := 0.0

	for scene in selected.keys():
		var scene_id := str(scene)
		var calls := int(selected.get(scene, 0))
		var info := scene_info(scene_id)
		if info.is_empty():
			unknown_scenes.append(scene_id)
			continue
		var unit_cost := float(info.get("estimated_cost", 0.0))
		var safe_calls: int = calls if calls > 0 else 0
		var row_cost: float = unit_cost * float(safe_calls)
		total_calls += safe_calls
		total_cost += row_cost
		rows.append({
			"scene": scene_id,
			"calls": safe_calls,
			"unit_cost": unit_cost,
			"total_cost": row_cost,
			"provider_tier": str(info.get("provider_tier", "")),
			"fallback_template_pool": str(info.get("fallback_template_pool", "")),
		})

	return {
		"ok": unknown_scenes.is_empty(),
		"rows": rows,
		"unknown_scenes": unknown_scenes,
		"total_calls": total_calls,
		"total_cost": total_cost,
		"daily_cap": DAILY_COST_CAP,
		"within_daily_cap": total_cost <= DAILY_COST_CAP,
	}
