class_name CommissionLibrary
extends RefCounted

const CommissionScript = preload("res://scripts/world/commission.gd")

const INDEX_PATH := "res://data/commissions/_index.json"

var _templates: Dictionary = {}
var _loaded: bool = false


func load_all() -> Dictionary:
	_templates.clear()
	_loaded = false
	if not FileAccess.file_exists(INDEX_PATH):
		return {"ok": false, "reason": "missing_index", "templates": {}, "count": 0}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not parsed is Dictionary:
		return {"ok": false, "reason": "invalid_index", "templates": {}, "count": 0}
	var entries: Variant = (parsed as Dictionary).get("templates", [])
	if not entries is Array:
		return {"ok": false, "reason": "invalid_templates", "templates": {}, "count": 0}
	for entry in entries:
		var path = _entry_path(entry)
		if path == "" or not FileAccess.file_exists(path):
			return {"ok": false, "reason": "missing_template", "path": path, "count": _templates.size()}
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not raw is Dictionary:
			return {"ok": false, "reason": "invalid_template_json", "path": path, "count": _templates.size()}
		var commission = CommissionScript.from_dict(raw)
		var validation = _validate(commission)
		if not bool(validation.get("ok", false)):
			validation["path"] = path
			validation["count"] = _templates.size()
			return validation
		if _templates.has(commission.id):
			return {"ok": false, "reason": "duplicate_id", "id": commission.id, "count": _templates.size()}
		_templates[commission.id] = commission
	_loaded = true
	return {"ok": true, "templates": _templates.duplicate(), "count": _templates.size()}


func all_templates() -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in _sorted_ids():
		result.append(_templates[id].copy())
	return result


func get_template(id: String):
	_ensure_loaded()
	if _templates.has(id):
		return _templates[id].copy()
	return CommissionScript.new()


func template_ids() -> Array[String]:
	_ensure_loaded()
	return _sorted_ids()


func due_templates(day: int, sequence: int) -> Array:
	_ensure_loaded()
	var result: Array = []
	for id in _sorted_ids():
		var commission = _templates[id]
		if int(day) < commission.min_day or int(day) > commission.max_day:
			continue
		if int(sequence) < commission.min_sequence:
			continue
		result.append(commission.copy())
	return result


func main_story_templates_for_day(day: int, sequence: int) -> Array:
	var result: Array = []
	for commission in due_templates(day, sequence):
		if commission != null and str(commission.main_story_hook) != "":
			result.append(commission)
	return result


func _ensure_loaded() -> void:
	if not _loaded:
		load_all()


func _entry_path(entry: Variant) -> String:
	if entry is String:
		return str(entry)
	if entry is Dictionary:
		return str((entry as Dictionary).get("path", ""))
	return ""


func _validate(commission) -> Dictionary:
	if commission == null or commission.id == "":
		return {"ok": false, "reason": "missing_id"}
	if not ["battle", "gather", "investigate", "perform"].has(commission.commission_type):
		return {"ok": false, "reason": "invalid_type", "id": commission.id}
	if commission.issuer_npc == "":
		return {"ok": false, "reason": "missing_issuer", "id": commission.id}
	if commission.district == "":
		return {"ok": false, "reason": "missing_district", "id": commission.id}
	if commission.dispatch_target.is_empty():
		return {"ok": false, "reason": "missing_dispatch_target", "id": commission.id}
	if commission.rewards.is_empty():
		return {"ok": false, "reason": "missing_rewards", "id": commission.id}
	return {"ok": true}


func _sorted_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _templates.keys():
		ids.append(str(id))
	ids.sort()
	return ids
