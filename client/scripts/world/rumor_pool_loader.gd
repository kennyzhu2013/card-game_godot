class_name RumorPoolLoader
extends RefCounted

const POOL_PATHS := {
	"shadow_alley_rumors": "res://data/rumors/shadow_alley_pool.json",
	"steelworks_tabloid": "res://data/rumors/steelworks_pool.json",
	"misty_port_rumors": "res://data/rumors/misty_port_pool.json",
	"sacred_seven_rumors": "res://data/rumors/sacred_seven_pool.json",
	"stone_tower_streets": "res://data/rumors/stone_tower_pool.json",
	"ascetic_mountain_rumors": "res://data/rumors/ascetic_mountain_pool.json",
	"tavern_pool": "res://data/rumors/tavern_pool.json",
	"teahouse_pool": "res://data/rumors/teahouse_pool.json",
}


func load_all() -> Dictionary:
	var pools: Dictionary = {}
	var entry_count := 0
	for pool_id_value in POOL_PATHS.keys():
		var pool_id := str(pool_id_value)
		var pool := load_pool(pool_id)
		if pool.is_empty():
			return {"ok": false, "reason": "missing_pool", "pool_id": pool_id, "entry_count": entry_count}
		var entries: Array = _entries(pool)
		entry_count += entries.size()
		pools[pool_id] = pool
	return {"ok": true, "pools": pools, "entry_count": entry_count}


func load_pool(pool_id: String) -> Dictionary:
	var path := str(POOL_PATHS.get(pool_id, ""))
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func pick(pool_id: String, game_state, count: int, seed: int) -> Array:
	var pool := load_pool(pool_id)
	if pool.is_empty() or count <= 0:
		return []
	var candidates: Array = []
	for entry in _entries(pool):
		if not entry is Dictionary:
			continue
		var entry_dict: Dictionary = entry
		if not _passes_filters(_dict(entry_dict.get("filters", {})), game_state):
			continue
		var intel := _intel_from_entry(entry_dict)
		if not intel.is_empty():
			candidates.append(intel)
	if candidates.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)
	var available: Array = candidates.duplicate(true)
	var result: Array = []
	var target_count := mini(maxi(1, count), available.size())
	while result.size() < target_count and not available.is_empty():
		var index := int(rng.randi_range(0, available.size() - 1))
		result.append((available[index] as Dictionary).duplicate(true))
		available.remove_at(index)
	return result


func intel_by_id(intel_id: String) -> Dictionary:
	if intel_id == "":
		return {}
	for pool_id_value in POOL_PATHS.keys():
		var pool := load_pool(str(pool_id_value))
		if pool.is_empty():
			continue
		for entry in _entries(pool):
			if not entry is Dictionary:
				continue
			var entry_dict: Dictionary = entry
			if str(entry_dict.get("id", "")) == intel_id:
				return _intel_from_entry(entry_dict)
	return {}


func _entries(pool: Dictionary) -> Array:
	var value: Variant = pool.get("entries", [])
	return value.duplicate(true) if value is Array else []


func _intel_from_entry(entry: Dictionary) -> Dictionary:
	var intel := entry.duplicate(true)
	intel.erase("weight")
	intel.erase("filters")
	if str(intel.get("id", "")) == "":
		return {}
	if not intel.get("apply_target", {}) is Dictionary:
		return {}
	if not intel.has("expires_after"):
		intel["expires_after"] = "today"
	if not intel.has("truth_value"):
		intel["truth_value"] = 100
	if not intel.has("has_applied"):
		intel["has_applied"] = false
	return intel


func _passes_filters(filters: Dictionary, game_state) -> bool:
	if filters.is_empty() or game_state == null:
		return true
	if filters.has("day_min") and int(_state_value(game_state, "day", 1)) < int(filters.get("day_min", 1)):
		return false
	if filters.has("day_max") and int(_state_value(game_state, "day", 1)) > int(filters.get("day_max", 999)):
		return false
	if filters.has("sequence_min") and int(_state_value(game_state, "sequence", 9)) < int(filters.get("sequence_min", 9)):
		return false
	if filters.has("sequence_max") and int(_state_value(game_state, "sequence", 9)) > int(filters.get("sequence_max", 9)):
		return false
	if filters.has("pollution_min") and int(_state_value(game_state, "pollution", 0)) < int(filters.get("pollution_min", 0)):
		return false
	if filters.has("pollution_max") and int(_state_value(game_state, "pollution", 0)) > int(filters.get("pollution_max", 100)):
		return false
	if filters.has("time_of_day"):
		var allowed: Variant = filters.get("time_of_day")
		var current := str(_state_value(game_state, "time_of_day", "morning"))
		if allowed is Array:
			var matched := false
			for item in allowed:
				if str(item) == current:
					matched = true
					break
			if not matched:
				return false
		elif str(allowed) != current:
			return false
	return true


func _state_value(game_state, field_name: String, default_value: Variant) -> Variant:
	var value = game_state.get(field_name)
	return default_value if value == null else value


func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
