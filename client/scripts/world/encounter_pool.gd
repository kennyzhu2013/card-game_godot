class_name EncounterPool
extends RefCounted

const EncounterScript = preload("res://scripts/world/encounter.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")

const DEFAULT_BASE_DIR := "res://data/encounters"
const DEFAULT_INDEX_PATH := "res://data/encounters/_index.json"

var _loaded := false
var _pools: Dictionary = {}
var _all: Array = []


func load_all(base_dir: String = DEFAULT_BASE_DIR) -> Array:
	_pools.clear()
	_all.clear()
	var index_path := "%s/_index.json" % base_dir
	var parsed := _load_json(index_path)
	if parsed.is_empty():
		_loaded = true
		return []
	var pools = parsed.get("pools", {})
	if not pools is Dictionary:
		_loaded = true
		return []
	for pool_id in pools.keys():
		var entries: Array = []
		var files = pools[pool_id]
		if files is Array:
			for file_path in files:
				for encounter in _load_encounters(str(file_path)):
					entries.append(encounter)
					_all.append(encounter)
		_pools[str(pool_id)] = entries
	_loaded = true
	return _all.duplicate()


func pick(pool_id: String, ctx: Dictionary, roll: float = -1.0):
	if not _loaded:
		load_all()
	var candidates: Array = filter_candidates(_pools.get(pool_id, []), ctx)
	if candidates.is_empty():
		return null
	var total_weight := 0
	for encounter in candidates:
		total_weight += maxi(1, int(encounter.get("weight")))
	var value := roll
	if value < 0.0:
		value = randf()
	value = clampf(value, 0.0, 0.999999)
	var target := int(floor(value * float(total_weight)))
	var running := 0
	for encounter in candidates:
		running += maxi(1, int(encounter.get("weight")))
		if target < running:
			return encounter
	return candidates.back()


func encounter_by_id(encounter_id: String):
	if encounter_id == "":
		return null
	if not _loaded:
		load_all()
	for encounter in _all:
		if encounter != null and str(encounter.get("id")) == encounter_id:
			return encounter
	return null


func filter_candidates(candidates: Array, ctx: Dictionary) -> Array:
	var result: Array = []
	var game_state = ctx.get("game_state", null)
	var district_id := _ctx_string(ctx, "district_id", game_state, "current_district")
	var time_id := _ctx_string(ctx, "time_of_day", game_state, "time_of_day")
	for encounter in candidates:
		if encounter == null:
			continue
		if not _matches_array(encounter.get("districts"), district_id):
			continue
		if not _matches_array(encounter.get("time_of_day"), time_id):
			continue
		if ctx.has("trigger_source") and not _preconditions_include_trigger_source(encounter.get("preconditions")):
			continue
		if not _matches_preconditions(encounter.get("preconditions"), game_state, ctx):
			continue
		if not _matches_chain(encounter, game_state):
			continue
		result.append(encounter)
	return result


func _load_encounter(path: String):
	var encounters := _load_encounters(path)
	if encounters.is_empty():
		return null
	return encounters[0]


func _load_encounters(path: String) -> Array:
	var data := _load_json(path)
	if data.is_empty():
		return []
	var result: Array = []
	var pack_entries = data.get("encounters", null)
	if pack_entries is Array:
		for entry in pack_entries:
			if entry is Dictionary:
				result.append(EncounterScript.new().from_dict(entry))
		return result
	result.append(EncounterScript.new().from_dict(data))
	return result


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed.duplicate(true)
	return {}


static func _matches_array(value: Variant, candidate: String) -> bool:
	if not value is Array or value.is_empty():
		return true
	for item in value:
		if str(item) == candidate:
			return true
	return false


static func _matches_preconditions(value: Variant, game_state, ctx: Dictionary) -> bool:
	if not value is Array:
		return true
	for expression in value:
		if not HotspotResolverScript.evaluate_visible_when(str(expression), game_state, ctx):
			return false
	return true


static func _preconditions_include_trigger_source(value: Variant) -> bool:
	if not value is Array:
		return false
	for expression in value:
		if str(expression).find("trigger_source") >= 0:
			return true
	return false


static func _matches_chain(encounter, game_state) -> bool:
	var chain_id := str(encounter.get("chain_id"))
	if chain_id == "":
		return true
	if game_state == null:
		return int(encounter.get("chain_step")) == 0
	var chains = game_state.get("encounter_chains")
	if not chains is Dictionary:
		return int(encounter.get("chain_step")) == 0
	var state = chains.get(chain_id, null)
	if state == null:
		return int(encounter.get("chain_step")) == 0
	var locked = bool(state.get("locked")) if state is Object else bool(state.get("locked", false))
	if locked:
		return false
	var current_step = int(state.get("current_step")) if state is Object else int(state.get("current_step", 0))
	return int(encounter.get("chain_step")) == current_step


static func _ctx_string(ctx: Dictionary, key: String, game_state, state_field: String) -> String:
	if ctx.has(key):
		return str(ctx.get(key))
	if game_state != null:
		return str(game_state.get(state_field))
	return ""
