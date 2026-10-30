class_name EncounterChainState
extends RefCounted

var chain_id: String = ""
var current_step: int = 0
var steps_history: Array = []
var locked: bool = false


func from_dict(data: Dictionary):
	chain_id = str(data.get("chain_id", ""))
	current_step = int(data.get("current_step", 0))
	steps_history = _array(data.get("steps_history", []))
	locked = bool(data.get("locked", false))
	return self


func to_dict() -> Dictionary:
	return {
		"chain_id": chain_id,
		"current_step": current_step,
		"steps_history": steps_history.duplicate(true),
		"locked": locked,
	}


func record_step(step: int, encounter_id: String, choice_id: String, day: int) -> void:
	steps_history.append({
		"step": step,
		"encounter_id": encounter_id,
		"choice_id": choice_id,
		"day": day,
	})
	current_step = maxi(current_step, step + 1)


static func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []
