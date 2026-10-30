class_name AIGMCache
extends RefCounted

const CACHEABLE_SCENES := ["unknown_reaction", "brand_naming"]

var path: String = "user://ai_gm_cache.json"
var entries: Dictionary = {}


func is_cacheable(ctx) -> bool:
	if ctx == null:
		return false
	return CACHEABLE_SCENES.has(str(ctx.scene))


func get_text(ctx) -> String:
	if not is_cacheable(ctx):
		return ""
	if entries.is_empty():
		load_cache()
	return str(entries.get(cache_key(ctx), ""))


func set_text(ctx, text: String) -> bool:
	if not is_cacheable(ctx):
		return false
	entries[cache_key(ctx)] = text
	return save_cache()


func cache_key(ctx) -> String:
	if ctx == null:
		return ""
	match str(ctx.scene):
		"unknown_reaction":
			return "unknown_reaction:%s" % _hash_key(_stable_payload_key(ctx.scene_payload.get("glyph_arrangement", [])))
		"brand_naming":
			var payload: Dictionary = ctx.scene_payload
			return "brand_naming:%s" % _hash_key("%s:%s:%s" % [
				str(payload.get("brand_id_a", "")),
				str(payload.get("brand_id_b", "")),
				str(payload.get("card_template_id", "")),
			])
		_:
			return "%s:%s" % [str(ctx.scene), _stable_payload_key(ctx.scene_payload)]


func load_cache() -> bool:
	if not FileAccess.file_exists(path):
		entries = {}
		return true
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		entries = {}
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		entries = parsed.duplicate(true)
		return true
	entries = {}
	return false


func save_cache() -> bool:
	var base_dir := path.get_base_dir()
	if base_dir != "" and base_dir != ".":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(entries, "\t"))
	file.close()
	return true


func _stable_payload_key(value: Variant) -> String:
	if value is Array:
		var parts: Array[String] = []
		for item in value:
			parts.append(str(item))
		return "|".join(parts)
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts: Array[String] = []
		for key in keys:
			parts.append("%s=%s" % [str(key), _stable_payload_key(value[key])])
		return "&".join(parts)
	return str(value)


func _hash_key(value: String) -> String:
	var hash_value := int(value.hash())
	if hash_value < 0:
		hash_value = -hash_value
	return "%016x" % hash_value
