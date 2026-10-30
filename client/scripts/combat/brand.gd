class_name Brand
extends RefCounted

# Per R05 §2 — 卡牌修饰器，从 BOSS 战 / 黑市 / 事件获取

var id: String = ""
var display_name: String = ""
var pathway_affinity: String = "any"
var sequence_min: int = 9
var effect_type: String = "stat"
var effect_payload: Dictionary = {}
var description: String = ""


static func from_dict(d: Dictionary) -> Brand:
	var b := Brand.new()
	b.id = d.get("id", "")
	b.display_name = d.get("display_name", "")
	b.pathway_affinity = d.get("pathway_affinity", "any")
	b.sequence_min = int(d.get("sequence_min", 9))
	b.effect_type = d.get("effect_type", "stat")
	b.effect_payload = _dict(d.get("effect_payload", {}))
	b.description = d.get("description", "")
	return b


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"pathway_affinity": pathway_affinity,
		"sequence_min": sequence_min,
		"effect_type": effect_type,
		"effect_payload": effect_payload.duplicate(true),
		"description": description,
	}


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
