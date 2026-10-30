class_name CombatActor
extends RefCounted

var display_name: String = ""
var actor_id: String = ""  # 用于映射 portrait / art assets
var hp: int = 100
var max_hp: int = 100
var atk: int = 10
var def: int = 5
var spd: int = 10
var crit_rate: float = 0.05
var atb: float = 0.0
var ready: bool = false
var statuses: Dictionary = {}
var markers: Dictionary = {}

const ATB_MAX := 100.0
const ATB_TICK_INTERVAL := 0.1


func atb_tick(delta: float) -> void:
	atb = min(atb + spd * delta, ATB_MAX)
	if atb >= ATB_MAX:
		ready = true


func consume_atb() -> void:
	atb = 0.0
	ready = false


func is_dead() -> bool:
	return hp <= 0


func add_status(id: String, payload: Dictionary = {}) -> void:
	if id == "":
		return
	statuses[id] = payload.duplicate(true)


func has_status(id: String) -> bool:
	return statuses.has(id)


func remove_status(id: String) -> void:
	statuses.erase(id)


func tick_statuses() -> void:
	var expired: Array[String] = []
	for id in statuses.keys():
		var payload: Dictionary = statuses.get(id, {})
		if not payload.has("duration"):
			continue
		var remaining := int(payload.get("duration", 0)) - 1
		if remaining <= 0:
			expired.append(str(id))
		else:
			payload["duration"] = remaining
			statuses[id] = payload
	for id in expired:
		statuses.erase(id)


func add_marker(id: String, amount: int = 1, max_stacks: int = -1) -> int:
	if id == "":
		return 0
	var next_count := get_marker_count(id) + maxi(0, amount)
	if max_stacks >= 0:
		next_count = mini(next_count, max_stacks)
	if next_count <= 0:
		markers.erase(id)
	else:
		markers[id] = next_count
	return next_count


func consume_marker(id: String, amount: int = 1) -> bool:
	var consume_amount := maxi(1, amount)
	var current := get_marker_count(id)
	if current < consume_amount:
		return false
	var next_count := current - consume_amount
	if next_count <= 0:
		markers.erase(id)
	else:
		markers[id] = next_count
	return true


func get_marker_count(id: String) -> int:
	return int(markers.get(id, 0))
