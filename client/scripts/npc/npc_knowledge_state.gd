class_name NpcKnowledgeState
extends RefCounted

# NPC 知识状态 (R11 §6.4)
# 三层身份揭示 + 信任/怀疑 + R20 active_perception 占位。

var layer_revealed: int = 0
var public_data: Dictionary = {}
var hidden_data: Dictionary = {}
var truth_data: Dictionary = {}

var trust: int = 0
var suspicion: int = 0

# R20 接线 (切片 1 占位，默认值)
var active_perception: String = "harvey"
var perception_expires_at: int = 0
var residual_identities: Array = []
var social_effects_active: Array = []

var first_met_day: int = -1
var dialog_count: int = 0
var dialogue_state: Dictionary = {}
var unlocked_dialogue_branches: Array[String] = []
var last_seen_day: int = -1
var pending_gifts: Array = []
var daily_mood: String = ""
var favor_debt: int = 0
var interaction_fatigue: int = 0
var today_opportunities: Array = []


func to_dict() -> Dictionary:
	return {
		"layer_revealed": layer_revealed,
		"public_data": public_data.duplicate(true),
		"hidden_data": hidden_data.duplicate(true),
		"truth_data": truth_data.duplicate(true),
		"trust": trust,
		"suspicion": suspicion,
		"active_perception": active_perception,
		"perception_expires_at": perception_expires_at,
		"residual_identities": residual_identities.duplicate(),
		"social_effects_active": social_effects_active.duplicate(),
		"first_met_day": first_met_day,
		"dialog_count": dialog_count,
		"dialogue_state": dialogue_state.duplicate(true),
		"unlocked_dialogue_branches": unlocked_dialogue_branches.duplicate(),
		"last_seen_day": last_seen_day,
		"pending_gifts": pending_gifts.duplicate(true),
		"daily_mood": daily_mood,
		"favor_debt": favor_debt,
		"interaction_fatigue": interaction_fatigue,
		"today_opportunities": today_opportunities.duplicate(true),
	}


static func from_dict(d: Dictionary) -> NpcKnowledgeState:
	var state := NpcKnowledgeState.new()
	state.layer_revealed = int(d.get("layer_revealed", 0))
	state.public_data = _dict(d.get("public_data", {}))
	state.hidden_data = _dict(d.get("hidden_data", {}))
	state.truth_data = _dict(d.get("truth_data", {}))
	state.trust = int(d.get("trust", 0))
	state.suspicion = int(d.get("suspicion", 0))
	state.active_perception = d.get("active_perception", "harvey")
	state.perception_expires_at = int(d.get("perception_expires_at", 0))
	state.residual_identities = _array(d.get("residual_identities", []))
	state.social_effects_active = _array(d.get("social_effects_active", []))
	state.first_met_day = int(d.get("first_met_day", -1))
	state.dialog_count = int(d.get("dialog_count", 0))
	state.dialogue_state = _dict(d.get("dialogue_state", {}))
	state.unlocked_dialogue_branches = _string_array(d.get("unlocked_dialogue_branches", []))
	state.last_seen_day = int(d.get("last_seen_day", -1))
	state.pending_gifts = _array(d.get("pending_gifts", []))
	state.daily_mood = str(d.get("daily_mood", ""))
	state.favor_debt = int(d.get("favor_debt", 0))
	state.interaction_fatigue = int(d.get("interaction_fatigue", 0))
	state.today_opportunities = _array(d.get("today_opportunities", []))
	return state


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate()
	return []


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
