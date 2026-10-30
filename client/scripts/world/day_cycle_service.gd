class_name DayCycleService
extends RefCounted

const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

const MAINLINE_DIR := "res://data/mainline/"
const TIMES: Array[String] = ["morning", "noon", "evening", "night"]


static func apply_day_hooks(game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "triggered": false, "reason": "missing_state"}
	var day := _state_int(game_state, "day", 1)
	var data: Dictionary = _load_day_hook(day)
	if data.is_empty():
		_clear_meta(game_state, "mainline_forced_tower")
		return {"ok": true, "triggered": false, "day": day}
	var node_id := str(data.get("node_id", ""))
	_record_mainline_node(game_state, node_id)
	_apply_flags(game_state, _dict(data.get("flags", {})))
	var forced_tower := _forced_tower_for_hook(data, game_state)
	var ai_gm_text := ""
	if day == 7:
		ai_gm_text = request_day7_event_ai_gm(game_state, {
			"mainline_progress": _completed_mainline_nodes(game_state),
		})
	if game_state.has_method("set_meta"):
		if forced_tower.is_empty():
			_clear_meta(game_state, "mainline_forced_tower")
		else:
			game_state.set_meta("mainline_forced_tower", forced_tower)
		game_state.set_meta("mainline_popup_pending", true)
		game_state.set_meta("mainline_popup_text", str(data.get("popup_text", "")))
		game_state.set_meta("mainline_popup_title", str(data.get("title", "")))
		game_state.set_meta("mainline_day", day)
		if ai_gm_text != "":
			game_state.set_meta("mainline_ai_gm_text", ai_gm_text)
	return {
		"ok": true,
		"triggered": true,
		"day": day,
		"node_id": node_id,
		"title": str(data.get("title", "")),
		"popup_text": str(data.get("popup_text", "")),
		"forced_tower": forced_tower,
		"ai_gm_text": ai_gm_text,
	}


static func request_day7_event_ai_gm(game_state, options: Dictionary = {}, service = null) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "day7_event"
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"cycle": _state_int(game_state, "cycle", 1),
		"mainline_progress": _string_array(options.get("mainline_progress", _completed_mainline_nodes(game_state))),
		"halfmoon_trust": _state_int(game_state, "halfmoon_trust", 0),
	}
	ctx.fallback_template_pool = "DAY7_TEMPLATES"
	return _call_ai_gm(ctx, service)


static func advance_time_segment(game_state, auto_save_path: String = "user://day_cycle_auto.json", weather_roll: float = -1.0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var current := str(game_state.time_of_day)
	var index := TIMES.find(current)
	if index < 0:
		game_state.time_of_day = "morning"
		return {"ok": true, "forced_sleep": false, "time_of_day": "morning"}
	if index < TIMES.size() - 1:
		game_state.time_of_day = TIMES[index + 1]
		return {"ok": true, "forced_sleep": false, "time_of_day": str(game_state.time_of_day)}
	if game_state.has_method("set_meta"):
		game_state.set_meta("force_sleep_pending", true)
	return {
		"ok": true,
		"forced_sleep": false,
		"forced_sleep_required": true,
		"time_of_day": str(game_state.time_of_day),
	}


static func _load_day_hook(day: int) -> Dictionary:
	var path := "%smainline_day%d.json" % [MAINLINE_DIR, day]
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _record_mainline_node(game_state, node_id: String) -> void:
	if node_id == "":
		return
	var daodian: Dictionary = game_state.daodian
	var completed: Array = []
	var existing: Variant = daodian.get("completed_main_story_nodes", [])
	if existing is Array:
		for node in existing:
			completed.append(str(node))
	for node in _mainline_node_aliases(node_id):
		if not node in completed:
			completed.append(node)
	daodian["completed_main_story_nodes"] = completed


static func _mainline_node_aliases(node_id: String) -> Array[String]:
	var result: Array[String] = [node_id]
	var parts := node_id.split("_", false)
	if parts.size() >= 2 and str(parts[0]) == "node":
		var generic_id := "%s_%s" % [str(parts[0]), str(parts[1])]
		if not generic_id in result:
			result.append(generic_id)
	return result


static func _apply_flags(game_state, flags: Dictionary) -> void:
	if game_state == null or not game_state.has_method("set_meta"):
		return
	for key in flags.keys():
		game_state.set_meta(str(key), flags[key])


static func _forced_tower_for_hook(data: Dictionary, game_state) -> Dictionary:
	var raw: Variant = data.get("forced_tower", {})
	if not raw is Dictionary:
		return {}
	var forced: Dictionary = raw.duplicate(true)
	if not _requirements_met(_dict(forced.get("requires", {})), game_state):
		return {}
	forced.erase("requires")
	if not forced.has("node_id"):
		forced["node_id"] = str(data.get("node_id", ""))
	if not forced.has("day"):
		forced["day"] = int(data.get("day", _state_int(game_state, "day", 1)))
	if not forced.has("district_ids"):
		var district_id := str(forced.get("district_id", ""))
		forced["district_ids"] = [district_id] if district_id != "" else []
	if not forced.has("required"):
		forced["required"] = true
	return forced


static func _requirements_met(requirements: Dictionary, game_state) -> bool:
	if requirements.is_empty():
		return true
	if game_state == null:
		return false
	if requirements.has("any"):
		var options: Variant = requirements.get("any", [])
		if not options is Array:
			return false
		for option in options:
			if option is Dictionary and _requirements_met(option, game_state):
				return true
		return false
	if requirements.has("church_awareness_min"):
		if int(game_state.church_awareness) < int(requirements.get("church_awareness_min", 0)):
			return false
	if requirements.has("pseudo_god_contract_violated"):
		var expected := bool(requirements.get("pseudo_god_contract_violated", false))
		var contract: Variant = game_state.get("pseudo_god_contract")
		var actual := false
		if contract is Dictionary:
			actual = bool((contract as Dictionary).get("violated", false))
		if actual != expected:
			return false
	if requirements.has("sequence_max"):
		if int(game_state.sequence) > int(requirements.get("sequence_max", 99)):
			return false
	if requirements.has("completed_mainline_node"):
		var node_id := str(requirements.get("completed_mainline_node", ""))
		if node_id != "" and not _mainline_completed(game_state, node_id):
			return false
	return true


static func _mainline_completed(game_state, node_id: String) -> bool:
	var daodian: Variant = game_state.get("daodian")
	if not daodian is Dictionary:
		return false
	var raw_nodes: Variant = (daodian as Dictionary).get("completed_main_story_nodes", [])
	if not raw_nodes is Array:
		return false
	for node in raw_nodes:
		var value := str(node)
		if value == node_id or value.begins_with("%s_" % node_id):
			return true
	return false


static func _clear_meta(game_state, key: String) -> void:
	if game_state == null:
		return
	if game_state.has_method("remove_meta") and game_state.has_meta(key):
		game_state.remove_meta(key)


static func _state_int(game_state, key: String, default_value: int) -> int:
	if game_state == null:
		return default_value
	var value = game_state.get(key)
	if value == null:
		return default_value
	return int(value)


static func _state_string(game_state, key: String, default_value: String) -> String:
	if game_state == null:
		return default_value
	var value = game_state.get(key)
	if value == null:
		return default_value
	return str(value)


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _call_ai_gm(ctx, service = null) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var resolved_service = service
	if resolved_service == null:
		resolved_service = AIGMServiceScript.new()
	if resolved_service == null or not resolved_service.has_method("call_ai_gm"):
		return ""
	return str(resolved_service.call_ai_gm(ctx))


static func _ai_gm_player_state(game_state) -> Dictionary:
	return {
		"sequence": _state_int(game_state, "sequence", 9),
		"pollution": _state_int(game_state, "pollution", 0),
		"pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"cycle": _state_int(game_state, "cycle", 1),
		"day": _state_int(game_state, "day", 1),
		"time_of_day": _state_string(game_state, "time_of_day", "morning"),
	}


static func _completed_mainline_nodes(game_state) -> Array[String]:
	if game_state == null:
		return []
	var daodian: Variant = game_state.get("daodian")
	if not daodian is Dictionary:
		return []
	return _string_array((daodian as Dictionary).get("completed_main_story_nodes", []))


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
