class_name Skill
extends RefCounted

var id: String = ""
var display_name: String = ""
var pathway: String = "fool"
var element: String = "普通"
var target: String = "single"
var range: int = 1
var damage: int = 0
var heal: int = 0
var mp_cost: int = 0
var cooldown: int = 1
var status_effects: Array = []
var pollution_per_use: int = 0
var hp_cost: int = 0
var description: String = ""
var tier: int = 1
var required_symbols: Array[String] = []
var source_symbol_ids: Array[String] = []
var social_effect: Dictionary = {}
var world_effect: Dictionary = {}


static func from_json(d: Dictionary):
	var skill = _new_instance()
	skill.id = d.get("id", "")
	skill.display_name = d.get("display_name", "")
	skill.pathway = d.get("pathway", "fool")
	skill.element = d.get("element", "普通")
	skill.mp_cost = int(d.get("mp_cost", 0))
	skill.cooldown = int(d.get("cooldown", 1))
	skill.pollution_per_use = int(d.get("pollution_per_use", 0))
	skill.description = d.get("description", "")
	skill.tier = int(d.get("tier", 1))
	skill.required_symbols = _string_array(d.get("required_symbols", []))
	skill.source_symbol_ids = _string_array(d.get("source_symbol_ids", []))
	var combat: Dictionary = d.get("combat_effect", {})
	skill.damage = int(combat.get("damage", 0))
	skill.heal = int(combat.get("heal", 0))
	skill.target = combat.get("target", "single")
	skill.range = int(combat.get("range", 1))
	skill.status_effects = combat.get("status_effects", []).duplicate(true)
	skill.social_effect = _effect_dict(d.get("social_effect", {}))
	skill.world_effect = _effect_dict(d.get("world_effect", {}))
	return skill


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"pathway": pathway,
		"element": element,
		"tier": tier,
		"mp_cost": mp_cost,
		"cooldown": cooldown,
		"pollution_per_use": pollution_per_use,
		"description": description,
		"required_symbols": Array(required_symbols),
		"source_symbol_ids": Array(source_symbol_ids),
		"combat_effect": {
			"damage": damage,
			"heal": heal,
			"target": target,
			"range": range,
			"status_effects": status_effects.duplicate(true),
		},
		"social_effect": social_effect.duplicate(true),
		"world_effect": world_effect.duplicate(true),
	}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _effect_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _new_instance():
	return load("res://scripts/combat/skill.gd").new()
