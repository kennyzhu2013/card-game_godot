class_name PromptContext
extends RefCounted

# AI GM 调用上下文 (R09 §4.7)
# 切片 1 仅定义 schema 类，AI GM 实际调用在切片 4。

var scene: String = ""
var player_state: Dictionary = {}
var scene_payload: Dictionary = {}
var contract_state: Dictionary = {}
var npc_context: Dictionary = {}
var fallback_template_pool: String = ""


func to_dict() -> Dictionary:
	return {
		"scene": scene,
		"player_state": player_state.duplicate(true),
		"scene_payload": scene_payload.duplicate(true),
		"contract_state": contract_state.duplicate(true),
		"npc_context": npc_context.duplicate(true),
		"fallback_template_pool": fallback_template_pool,
	}


static func from_dict(d: Dictionary) -> PromptContext:
	var ctx := PromptContext.new()
	ctx.scene = d.get("scene", "")
	ctx.player_state = _dict(d.get("player_state", {}))
	ctx.scene_payload = _dict(d.get("scene_payload", {}))
	ctx.contract_state = _dict(d.get("contract_state", {}))
	ctx.npc_context = _dict(d.get("npc_context", {}))
	ctx.fallback_template_pool = str(d.get("fallback_template_pool", ""))
	return ctx


func validate() -> Dictionary:
	var missing: Array[String] = []
	if scene.strip_edges() == "":
		missing.append("scene")
	if fallback_template_pool.strip_edges() == "":
		missing.append("fallback_template_pool")
	return {
		"valid": missing.is_empty(),
		"missing": missing,
	}


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
