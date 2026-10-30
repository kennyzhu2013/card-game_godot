class_name TemplateFill
extends RefCounted

const ASPECT_PHRASES_PATH := "res://data/ai_gm/aspect_phrases.json"

const SCENE_LABELS := {
	"forge_resolve": "锻造余温",
	"unknown_reaction": "未知反应",
	"tower_floor_transition": "爬塔过场",
	"combat_resolve_critical": "关键回合",
	"boss_victory": "塔顶胜利",
	"mainline_boss": "主线夜战",
	"brand_naming": "烙印命名",
	"contract_violation": "扮演裂痕",
	"cycle_summary": "周目结算",
	"day7_event": "第七日钟声",
	"pollution_stage_transition": "污染跨段",
	"card_upgrade": "卡牌升阶",
	"sequence_promotion": "序列晋升",
	"social_resolve": "社交咏念",
	"church_threshold_10": "教会侦缉",
	"church_threshold_25": "主教调查",
	"church_threshold_50": "清剿前夜",
	"residual_identity_create": "残留身份",
	"residual_identity_expire": "身份失效",
	"npc_first_meet": "初见回声",
	"npc_relation_shift": "关系转折",
	"npc_layer_reveal": "身份揭露",
	"npc_perception_swap": "感知错位",
	"acting_drill_collapse": "演练崩塌",
	"rumor_generated": "街角传闻",
	"encounter_resolve": "邂逅余波",
}


static func render(template: String, ctx) -> String:
	var values := _context_values(ctx)
	var re := RegEx.new()
	var err := re.compile("\\{([A-Za-z0-9_\\.]+)\\}")
	if err != OK:
		return template

	var output := template
	var matches := re.search_all(template)
	for i in range(matches.size() - 1, -1, -1):
		var match: RegExMatch = matches[i]
		var key := match.get_string(1)
		var resolved = _resolve_key(values, key)
		var replacement := ""
		if resolved == null:
			replacement = "未明"
			push_warning("[TemplateFill] missing placeholder: %s" % key)
		else:
			replacement = _stringify_value(resolved)
		output = output.substr(0, match.get_start()) + replacement + output.substr(match.get_end())
	return output


static func _context_values(ctx) -> Dictionary:
	var values: Dictionary = {}
	var scene := ""
	if ctx != null:
		scene = str(ctx.scene)
		_merge(values, ctx.player_state)
		_merge(values, ctx.scene_payload)
		_merge(values, ctx.contract_state)
		_merge(values, ctx.npc_context)
	values["scene"] = scene
	values["scene_label"] = SCENE_LABELS.get(scene, scene)
	if str(values.get("aspect", "")).strip_edges() == "":
		values["aspect"] = "影"
	values["aspect_phrase"] = _aspect_phrase(str(values.get("aspect", "影")), scene)
	return values


static func _merge(target: Dictionary, source: Variant) -> void:
	if not source is Dictionary:
		return
	var data := source as Dictionary
	for key in data.keys():
		target[str(key)] = data[key]


static func _resolve_key(values: Dictionary, key: String):
	if values.has(key):
		return values[key]
	if key.find(".") == -1:
		return null
	var current: Variant = values
	for part in key.split("."):
		if current is Dictionary and (current as Dictionary).has(part):
			current = current[part]
		else:
			return null
	return current


static func _stringify_value(value: Variant) -> String:
	if value is Array:
		var parts: Array[String] = []
		for item in value:
			parts.append(str(item))
		return "、".join(parts)
	if value is Dictionary:
		return JSON.stringify(value)
	return str(value)


static func _aspect_phrase(aspect: String, seed_text: String) -> String:
	var phrases := _load_aspect_phrases()
	var entries: Array = phrases.get(aspect, [])
	if entries.is_empty():
		entries = phrases.get("影", [])
	if entries.is_empty():
		return "影子在煤烟里慢了半拍"
	var index := _positive_hash("%s:%s" % [aspect, seed_text]) % entries.size()
	return str(entries[index])


static func _load_aspect_phrases() -> Dictionary:
	if not FileAccess.file_exists(ASPECT_PHRASES_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ASPECT_PHRASES_PATH))
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


static func _positive_hash(value: String) -> int:
	var result := int(value.hash())
	if result < 0:
		result = -result
	return result
