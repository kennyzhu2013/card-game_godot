class_name Enemy
extends "res://scripts/combat/combat_actor.gd"

var id: String = ""
var tier: int = 1
var element: String = "普通"
var weakness: Array[String] = []
var resistance: Array[String] = []
var skills: Array = []
var ai_pattern: Array = []
var intent_text: String = ""
var transformed: bool = false


static func from_json(d: Dictionary):
	var enemy = _new_instance()
	enemy.id = d.get("id", "")
	enemy.display_name = d.get("display_name", "")
	enemy.actor_id = d.get("actor_id", "")
	enemy.tier = int(d.get("tier", 1))
	enemy.element = d.get("element", "普通")
	enemy.weakness = _string_array(d.get("weakness", []))
	enemy.resistance = _string_array(d.get("resistance", []))
	enemy.intent_text = str(d.get("intent_text", ""))
	var stats: Dictionary = d.get("stats", {})
	enemy.hp = int(stats.get("hp", 100))
	enemy.max_hp = int(stats.get("max_hp", enemy.hp))
	enemy.atk = int(stats.get("atk", 10))
	enemy.def = int(stats.get("def", 5))
	enemy.spd = int(stats.get("spd", 10))
	enemy.crit_rate = float(stats.get("crit_rate", 0.05))
	enemy.skills = d.get("skills", []).duplicate(true)
	enemy.ai_pattern = d.get("ai_pattern", []).duplicate(true)
	return enemy


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _new_instance():
	return load("res://scripts/combat/enemy.gd").new()
