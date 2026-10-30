class_name EncounterTrigger
extends Node

signal encounter_triggered(encounter)

const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")

@export var base_check_interval_sec: float = 30.0

var elapsed_in_district: float = 0.0
var encounter_pool_id: String = "city_roaming"

var _game_state = null
var _district_data: Dictionary = {}
var _pool = null
var _runner = null


func _ready() -> void:
	_pool = EncounterPoolScript.new()
	set_process(true)


func configure(game_state, district_data: Dictionary, runner = null) -> void:
	_game_state = game_state
	_district_data = district_data.duplicate(true)
	_runner = runner
	encounter_pool_id = str(_district_data.get("encounter_pool_id", "city_roaming"))
	elapsed_in_district = 0.0


func _process(delta: float) -> void:
	process_roaming_delta(delta)


func process_roaming_delta(delta: float, roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	elapsed_in_district += delta
	if elapsed_in_district < base_check_interval_sec:
		return {"ok": true, "triggered": false, "reason": "waiting", "elapsed": elapsed_in_district}
	elapsed_in_district = 0.0
	return try_trigger(roll, pool_roll)


func try_trigger(roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	if _game_state == null:
		return {"ok": false, "triggered": false, "reason": "missing_state"}
	return _try_trigger_with_context("", calc_trigger_chance(), roll, pool_roll)


func try_time_segment_spawn(roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	if _game_state == null:
		return {"ok": false, "triggered": false, "reason": "missing_state"}
	return _try_trigger_with_context("time_segment", 0.05, roll, pool_roll)


func try_action_trigger(action_id: String, roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	return on_action_complete(_normalize_action_source(action_id), "", roll, pool_roll)


func on_action_complete(source: String, district_id: String, roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	if _game_state == null:
		return {"ok": false, "triggered": false, "reason": "missing_state"}
	var trigger_source := _normalize_action_source(source)
	if trigger_source == "":
		return {"ok": false, "triggered": false, "reason": "missing_action_source"}
	return _try_trigger_with_context(trigger_source, 0.05, roll, pool_roll, district_id)


func _try_trigger_with_context(trigger_source: String, chance: float, roll: float, pool_roll: float, district_override: String = "") -> Dictionary:
	var district_id := str(district_override).strip_edges()
	if district_id == "":
		district_id = str(_district_data.get("district_id", _game_state.get("current_district")))
	if _daily_global() >= 8:
		return {"ok": true, "triggered": false, "reason": "daily_global_cap"}
	if _daily_district(district_id) >= 4:
		return {"ok": true, "triggered": false, "reason": "daily_district_cap"}
	var value := roll
	if value < 0.0:
		value = randf()
	value = clampf(value, 0.0, 0.999999)
	if value >= chance:
		return {"ok": true, "triggered": false, "reason": "roll_miss", "chance": chance, "roll": value}
	if _pool == null:
		_pool = EncounterPoolScript.new()
	var encounter = _pool.pick(encounter_pool_id, _filter_ctx(district_id, trigger_source), pool_roll)
	if encounter == null:
		return {"ok": true, "triggered": false, "reason": "empty_pool", "chance": chance, "roll": value}
	_record_daily_count(district_id)
	_start_runner(encounter)
	encounter_triggered.emit(encounter)
	return {
		"ok": true,
		"triggered": true,
		"reason": "triggered",
		"encounter_id": str(encounter.get("id")),
		"chance": chance,
		"roll": value,
		"trigger_source": trigger_source,
	}


func _normalize_action_source(source: String) -> String:
	match str(source):
		"errand_complete":
			return "errand"
		"errand", "casino_leave":
			return str(source)
		_:
			return str(source)


func calc_trigger_chance() -> float:
	if _game_state == null:
		return 0.0
	var chance := 0.25
	var pollution_stage := int(_game_state.get("pollution_stage"))
	if pollution_stage >= 2:
		chance += 0.10
	if int(_game_state.day) in [1, 3, 7, 10, 12, 14]:
		chance += 0.05
	var district_id := str(_district_data.get("district_id", _game_state.get("current_district")))
	if _daily_district(district_id) >= 2:
		chance -= 0.05
	return clampf(chance, 0.0, 1.0)


func _filter_ctx(district_id: String, trigger_source: String = "") -> Dictionary:
	var ctx := {
		"district_id": district_id,
		"time_of_day": str(_game_state.time_of_day),
		"game_state": _game_state,
	}
	if trigger_source != "":
		ctx["trigger_source"] = trigger_source
	return ctx


func _start_runner(encounter) -> void:
	var runner = _runner
	if runner == null:
		runner = get_parent().find_child("EncounterRunner", true, false) if get_parent() != null else null
	if runner != null and runner.has_method("start"):
		runner.start(encounter, _game_state)


func _record_daily_count(district_id: String) -> void:
	var counts := _ensure_daily_counts()
	counts["global"] = int(counts.get("global", 0)) + 1
	var districts = counts.get("districts", {})
	if not districts is Dictionary:
		districts = {}
		counts["districts"] = districts
	districts[district_id] = int(districts.get(district_id, 0)) + 1
	_game_state.set("last_encounter_today", counts)


func _daily_global() -> int:
	var counts := _ensure_daily_counts()
	return int(counts.get("global", 0))


func _daily_district(district_id: String) -> int:
	var counts := _ensure_daily_counts()
	var districts = counts.get("districts", {})
	if districts is Dictionary:
		return int(districts.get(district_id, 0))
	return 0


func _ensure_daily_counts() -> Dictionary:
	var counts = _game_state.get("last_encounter_today") if _game_state != null else {}
	if not counts is Dictionary:
		counts = {}
	if not counts.has("global"):
		counts["global"] = 0
	if not counts.get("districts", {}) is Dictionary:
		counts["districts"] = {}
	_game_state.set("last_encounter_today", counts)
	return counts
