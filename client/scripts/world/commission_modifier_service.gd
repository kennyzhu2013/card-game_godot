class_name CommissionModifierService
extends RefCounted

const DATA_PATH := "res://data/field_loop/commission_modifiers.json"

var _defs: Dictionary = {}


func load_all() -> Dictionary:
	if not _defs.is_empty():
		return _defs.duplicate(true)
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		return {}
	var raw_modifiers: Variant = (parsed as Dictionary).get("modifiers", [])
	if not raw_modifiers is Array:
		return {}
	for raw in raw_modifiers:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = (raw as Dictionary).duplicate(true)
		var id := str(entry.get("id", ""))
		if id != "":
			_defs[id] = entry
	return _defs.duplicate(true)


func decorate_available(game_state, commission, seed: int) -> Dictionary:
	var data: Dictionary = commission.to_dict() if commission != null and commission.has_method("to_dict") else {}
	if data.is_empty():
		return {}
	if str(data.get("main_story_hook", "")) != "":
		return data
	var allowed := _string_array(data.get("allowed_modifiers", []))
	if allowed.is_empty():
		return data
	var max_count := mini(2, allowed.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) + abs(str(data.get("id", "")).hash())
	var count := 1 if max_count <= 1 else int(rng.randi_range(1, max_count))
	var pool: Array = allowed.duplicate()
	var selected: Array = []
	while selected.size() < count and not pool.is_empty():
		var index := int(rng.randi_range(0, pool.size() - 1))
		selected.append(str(pool[index]))
		pool.remove_at(index)
	var result := apply_to_dict(game_state, data, selected)
	_record_history(game_state, str(result.get("id", "")), _string_array(result.get("modifiers", [])))
	return result


func apply_for_ids(game_state, commission_id: String, modifier_ids: Array) -> Dictionary:
	if game_state == null or commission_id == "":
		return {}
	var available: Array = game_state.available_commissions if game_state.available_commissions is Array else []
	for i in range(available.size()):
		var item = available[i]
		if not item is Dictionary:
			continue
		if str((item as Dictionary).get("id", "")) != commission_id:
			continue
		var next := apply_to_dict(game_state, (item as Dictionary).duplicate(true), modifier_ids)
		available[i] = next
		game_state.available_commissions = available
		_record_history(game_state, commission_id, _string_array(next.get("modifiers", [])))
		return next
	return {}


func apply_to_dict(game_state, data: Dictionary, modifier_ids: Array) -> Dictionary:
	var defs := load_all()
	var raw_ids := _string_array(modifier_ids)
	if raw_ids.size() > 2:
		raw_ids = raw_ids.slice(0, 2)
	var valid_ids: Array = []
	var labels: Array[String] = []
	var effects := {
		"reward_multiplier": 1.0,
		"time_limit_delta": 0,
		"issuer_trust_delta_on_expire": -5,
	}
	for id in raw_ids:
		var def: Dictionary = defs.get(id, {}) if defs.get(id, {}) is Dictionary else {}
		if def.is_empty():
			continue
		valid_ids.append(id)
		labels.append(str(def.get("display_name", id)))
		var effect: Dictionary = def.get("effects", {}) if def.get("effects", {}) is Dictionary else {}
		var risk: Dictionary = def.get("risk", {}) if def.get("risk", {}) is Dictionary else {}
		effects["reward_multiplier"] = float(effects.get("reward_multiplier", 1.0)) * float(effect.get("reward_multiplier", 1.0))
		effects["time_limit_delta"] = int(effects.get("time_limit_delta", 0)) + int(effect.get("time_limit_delta", 0))
		for key in effect.keys():
			var key_name := str(key)
			if ["reward_multiplier", "time_limit_delta"].has(key_name):
				continue
			effects[key_name] = effect[key]
		for key in risk.keys():
			effects[str(key)] = risk[key]
	data["modifiers"] = valid_ids
	data["modifier_effects"] = effects
	data["modifier_display_text"] = " / ".join(labels)
	if not valid_ids.is_empty():
		data["time_limit_days"] = maxi(1, int(data.get("time_limit_days", 1)) + int(effects.get("time_limit_delta", 0)))
	return data


func reward_multiplier(commission) -> float:
	var effects := _modifier_effects_from(commission)
	return float(effects.get("reward_multiplier", 1.0))


func expire_trust_delta(commission) -> int:
	var effects := _modifier_effects_from(commission)
	return int(effects.get("issuer_trust_delta_on_expire", -5))


func _modifier_effects_from(commission) -> Dictionary:
	if commission == null:
		return {}
	if commission is Dictionary:
		return (commission as Dictionary).get("modifier_effects", {}) if (commission as Dictionary).get("modifier_effects", {}) is Dictionary else {}
	var raw = commission.get("modifier_effects")
	return raw.duplicate(true) if raw is Dictionary else {}


func _record_history(game_state, commission_id: String, ids: Array) -> void:
	if game_state == null or commission_id == "":
		return
	var history: Dictionary = game_state.commission_modifier_history if game_state.commission_modifier_history is Dictionary else {}
	history[commission_id] = ids.duplicate()
	game_state.commission_modifier_history = history


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
