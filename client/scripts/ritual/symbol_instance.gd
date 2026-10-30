class_name SymbolInstance
extends RefCounted

# 基础（来自模板）
var template_id: String = ""
var display_name: String = ""
var pathway: String = ""

# 培育层
var cultivation_level: int = 0
var use_count: int = 0
var battles_witnessed: int = 0

# 个性层
var aspects: Array[String] = []
var aspect_strengths: Dictionary = {}
var mutation_type: String = ""
var mutation_aspect: String = ""

# 历史层
var forged_into: Array[String] = []
var npc_used_on: Array[String] = []
var first_acquired_day: int = 0
var notable_moments: Array = []

# 命名
var player_name: String = ""
var is_variant: bool = false


static func from_template(template: RitualSymbol, day: int = 0):
	var inst = _new_instance()
	inst.template_id = template.id
	inst.display_name = template.display_name
	inst.pathway = template.pathway
	inst.aspects = template.aspects.duplicate()
	for aspect in inst.aspects:
		inst.aspect_strengths[aspect] = 1.0
	inst.first_acquired_day = day
	return inst


func record_use(in_battle: bool = false) -> void:
	use_count += 1
	if in_battle:
		battles_witnessed += 1
	if use_count > 0 and use_count % 5 == 0:
		cultivation_level = min(cultivation_level + 1, 10)


func to_dict() -> Dictionary:
	return {
		"template_id": template_id,
		"display_name": display_name,
		"pathway": pathway,
		"cultivation_level": cultivation_level,
		"use_count": use_count,
		"battles_witnessed": battles_witnessed,
		"aspects": Array(aspects),
		"aspect_strengths": aspect_strengths.duplicate(true),
		"mutation_type": mutation_type,
		"mutation_aspect": mutation_aspect,
		"forged_into": Array(forged_into),
		"npc_used_on": Array(npc_used_on),
		"first_acquired_day": first_acquired_day,
		"notable_moments": notable_moments.duplicate(true),
		"player_name": player_name,
		"is_variant": is_variant,
	}


static func from_dict(d: Dictionary):
	var inst = _new_instance()
	inst.template_id = d.get("template_id", "")
	inst.display_name = d.get("display_name", "")
	inst.pathway = d.get("pathway", "")
	inst.cultivation_level = d.get("cultivation_level", 0)
	inst.use_count = d.get("use_count", 0)
	inst.battles_witnessed = d.get("battles_witnessed", 0)
	inst.aspects.assign(d.get("aspects", []))
	var strengths: Dictionary = d.get("aspect_strengths", {})
	inst.aspect_strengths = strengths.duplicate(true)
	inst.mutation_type = d.get("mutation_type", "")
	inst.mutation_aspect = d.get("mutation_aspect", "")
	inst.forged_into.assign(d.get("forged_into", []))
	inst.npc_used_on.assign(d.get("npc_used_on", []))
	inst.first_acquired_day = d.get("first_acquired_day", 0)
	var moments: Array = d.get("notable_moments", [])
	inst.notable_moments = moments.duplicate(true)
	inst.player_name = d.get("player_name", "")
	inst.is_variant = d.get("is_variant", false)
	return inst


static func _new_instance():
	return load("res://scripts/ritual/symbol_instance.gd").new()
