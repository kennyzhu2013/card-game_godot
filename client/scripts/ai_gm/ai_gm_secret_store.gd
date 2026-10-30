class_name AIGMSecretStore
extends RefCounted

const DEFAULT_PATH := "user://ai_gm_secret.json"

var path: String = DEFAULT_PATH


func save_api_key(api_key: String) -> bool:
	if not _ensure_parent_dir(path):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"api_key": api_key}))
	file.close()
	return true


func load_api_key() -> String:
	if not FileAccess.file_exists(path):
		return ""
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return ""
	return str((parsed as Dictionary).get("api_key", ""))


func clear_api_key() -> bool:
	return save_api_key("")


static func _ensure_parent_dir(target_path: String) -> bool:
	var base_dir := target_path.get_base_dir()
	if base_dir == "" or base_dir == ".":
		return true
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir)) == OK
