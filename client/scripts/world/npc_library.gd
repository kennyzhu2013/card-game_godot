class_name NpcLibrary
extends RefCounted

const DEFAULT_INDEX_PATH := "res://data/npc/_index.json"
const SPECIAL_NPC_DIR := "res://data/npc/special/"

var _definitions: Dictionary = {}
var _loaded := false


func load_all(index_path: String = DEFAULT_INDEX_PATH) -> Dictionary:
	_definitions.clear()
	_loaded = false
	if not FileAccess.file_exists(index_path):
		return {"ok": false, "reason": "missing_index", "path": index_path}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not parsed is Dictionary:
		return {"ok": false, "reason": "invalid_index_json", "path": index_path}
	var entries: Variant = parsed.get("npcs", [])
	if not entries is Array:
		return {"ok": false, "reason": "invalid_index_entries", "path": index_path}
	for entry in entries:
		if not entry is Dictionary:
			continue
		var npc_id := str(entry.get("id", ""))
		var path := str(entry.get("path", ""))
		if npc_id == "" or path == "" or not FileAccess.file_exists(path):
			continue
		var npc_def := _load_definition(path)
		if npc_def.is_empty():
			continue
		var def_id := str(npc_def.get("id", npc_id))
		if def_id == "":
			continue
		_definitions[def_id] = npc_def
	_loaded = true
	return {"ok": true, "count": _definitions.size()}


func all_ids() -> Array:
	_ensure_loaded()
	var ids := _definitions.keys()
	ids.sort()
	return ids


func get_definition(npc_id: String) -> Dictionary:
	_ensure_loaded()
	if not _definitions.has(npc_id):
		return _special_definition(npc_id)
	return _definitions[npc_id].duplicate(true)


func has_definition(npc_id: String) -> bool:
	_ensure_loaded()
	return _definitions.has(npc_id) or not _special_definition(npc_id).is_empty()


func _ensure_loaded() -> void:
	if not _loaded:
		load_all()


func _load_definition(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed.duplicate(true)
	return {}


func _special_definition(npc_id: String) -> Dictionary:
	if npc_id == "":
		return {}
	var path := "%s%s.json" % [SPECIAL_NPC_DIR, npc_id]
	if not FileAccess.file_exists(path):
		return {}
	var npc_def := _load_definition(path)
	if str(npc_def.get("id", "")) != npc_id:
		return {}
	return npc_def
