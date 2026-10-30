class_name SaveStore
extends RefCounted

const SAVE_VERSION := 1
const AUTO_PATH := "user://saves/auto.json"
const SAVE_DIR := "user://saves"
const GAME_VERSION := "0.1.0-mvp"
const MANUAL_SLOTS := ["save_1", "save_2", "save_3"]


static func save_auto(game_state, path: String = AUTO_PATH) -> bool:
	return save_game_state(game_state, path)


static func auto_save(game_state = null, base_path: String = SAVE_DIR) -> bool:
	return save("auto", game_state, base_path)


static func save(slot: String, game_state = null, base_path: String = SAVE_DIR) -> bool:
	var state = game_state if game_state != null else GameState
	if state == null or not state.has_method("to_dict"):
		return false
	return save_game_state(state, slot_path(slot, base_path))


static func load(slot: String, base_path: String = SAVE_DIR) -> Dictionary:
	return load_path(slot_path(slot, base_path))


static func load_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func apply_payload(payload: Dictionary, game_state = null) -> bool:
	var state = game_state if game_state != null else GameState
	if state == null or not state.has_method("from_dict"):
		return false
	var data = payload.get("game_state", {})
	if not data is Dictionary:
		return false
	state.from_dict(data)
	return true


static func slot_path(slot: String, base_path: String = SAVE_DIR) -> String:
	var file_name := "auto.json" if slot == "auto" else "%s.json" % slot
	return "%s/%s" % [_trim_trailing_slash(base_path), file_name]


static func save_game_state(game_state, path: String) -> bool:
	if game_state == null or not game_state.has_method("to_dict"):
		return false
	if not _ensure_parent_dir(path):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(build_payload(game_state), "\t"))
	file.close()
	return true


static func build_payload(game_state) -> Dictionary:
	var saved_at := int(Time.get_unix_time_from_system())
	return {
		"$schema": "save_v1",
		"save_version": SAVE_VERSION,
		"timestamp": saved_at,
		"saved_at_unix": saved_at,
		"saved_at_display": Time.get_datetime_string_from_system(false, true),
		"summary": _summary(game_state),
		"game_state": game_state.to_dict(),
		"metadata": {
			"play_time_seconds": 0,
			"godot_version": Engine.get_version_info().get("string", ""),
			"game_version": GAME_VERSION,
		},
	}


static func _summary(game_state) -> Dictionary:
	return {
		"character_id": game_state.character_id,
		"pathway": game_state.pathway,
		"sequence": game_state.sequence,
		"cycle": game_state.cycle,
		"day": game_state.day,
		"time_of_day": game_state.time_of_day,
		"location": game_state.current_district,
		"ap": game_state.ap,
		"ap_max": game_state.ap_max,
		"lingstones": game_state.lingstones,
		"pollution": game_state.pollution,
		"card_count": game_state.cards_inventory.size(),
	}


static func _ensure_parent_dir(path: String) -> bool:
	var base_dir := path.get_base_dir()
	if base_dir == "" or base_dir == ".":
		return true
	var absolute := ProjectSettings.globalize_path(base_dir)
	return DirAccess.make_dir_recursive_absolute(absolute) == OK


static func _trim_trailing_slash(path: String) -> String:
	var result := path
	while result.ends_with("/") or result.ends_with("\\"):
		result = result.substr(0, result.length() - 1)
	return result
