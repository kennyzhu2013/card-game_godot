class_name Commission
extends RefCounted

var id: String = ""
var commission_type: String = ""
var difficulty: String = "small"
var display_name: String = ""
var description: String = ""
var issuer_npc: String = ""
var district: String = ""
var min_day: int = 1
var max_day: int = 14
var min_sequence: int = 9
var dispatch_target: Dictionary = {}
var time_limit_days: int = 3
var allowed_modifiers: Array = []
var modifiers: Array = []
var modifier_effects: Dictionary = {}
var modifier_display_text: String = ""
var rewards: Array = []
var main_story_hook: String = ""
var contract_rule_hook: String = ""
var deposit: Dictionary = {}
var escrow: Dictionary = {}
var refresh_priority: int = 1000

var status: String = "available"
var accepted_day: int = -1
var progress: Dictionary = {}


static func from_dict(data: Dictionary):
	var commission = new()
	commission.id = str(data.get("id", ""))
	commission.commission_type = str(data.get("commission_type", data.get("type", "")))
	commission.difficulty = str(data.get("difficulty", "small"))
	commission.display_name = str(data.get("display_name", data.get("title", commission.id)))
	commission.description = str(data.get("description", ""))
	commission.issuer_npc = str(data.get("issuer_npc", data.get("issuer", "")))
	commission.district = str(data.get("district", data.get("district_id", "")))
	commission.min_day = int(data.get("min_day", 1))
	commission.max_day = int(data.get("max_day", 14))
	commission.min_sequence = int(data.get("min_sequence", 9))
	commission.dispatch_target = _dict(data.get("dispatch_target", {}))
	commission.time_limit_days = int(data.get("time_limit_days", 3))
	commission.allowed_modifiers = _array(data.get("allowed_modifiers", []))
	commission.modifiers = _array(data.get("modifiers", []))
	commission.modifier_effects = _dict(data.get("modifier_effects", {}))
	commission.modifier_display_text = str(data.get("modifier_display_text", ""))
	commission.rewards = _array(data.get("rewards", []))
	commission.main_story_hook = str(data.get("main_story_hook", ""))
	commission.contract_rule_hook = str(data.get("contract_rule_hook", ""))
	commission.deposit = _dict(data.get("deposit", {}))
	commission.escrow = _dict(data.get("escrow", {}))
	commission.refresh_priority = int(data.get("refresh_priority", 1000))
	commission.status = str(data.get("status", "available"))
	commission.accepted_day = int(data.get("accepted_day", -1))
	commission.progress = _dict(data.get("progress", {}))
	return commission


func to_dict() -> Dictionary:
	return {
		"id": id,
		"commission_type": commission_type,
		"difficulty": difficulty,
		"display_name": display_name,
		"title": display_name,
		"description": description,
		"issuer_npc": issuer_npc,
		"district": district,
		"min_day": min_day,
		"max_day": max_day,
		"min_sequence": min_sequence,
		"dispatch_target": dispatch_target.duplicate(true),
		"time_limit_days": time_limit_days,
		"allowed_modifiers": allowed_modifiers.duplicate(true),
		"modifiers": modifiers.duplicate(true),
		"modifier_effects": modifier_effects.duplicate(true),
		"modifier_display_text": modifier_display_text,
		"rewards": rewards.duplicate(true),
		"main_story_hook": main_story_hook,
		"contract_rule_hook": contract_rule_hook,
		"deposit": deposit.duplicate(true),
		"escrow": escrow.duplicate(true),
		"refresh_priority": refresh_priority,
		"status": status,
		"accepted_day": accepted_day,
		"progress": progress.duplicate(true),
	}


func is_empty() -> bool:
	return id == ""


func copy():
	return from_dict(to_dict())


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []
