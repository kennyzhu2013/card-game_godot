class_name ArtManifest
extends RefCounted

const DEFAULT_PATH := "res://assets/art_specs/pixel_asset_manifest.json"


static func load_assets(manifest_path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(manifest_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		return {}
	var assets: Variant = (parsed as Dictionary).get("assets", {})
	if assets is Dictionary:
		return (assets as Dictionary).duplicate(true)
	return {}


static func integrated_texture_entries(manifest_path: String = DEFAULT_PATH) -> Array:
	var result: Array = []
	var assets := load_assets(manifest_path)
	for asset_id in assets.keys():
		var entry: Variant = assets[asset_id]
		if not entry is Dictionary:
			continue
		if str((entry as Dictionary).get("kind", "")) != "texture":
			continue
		if str((entry as Dictionary).get("runtime_status", "")) != "integrated":
			continue
		var item := (entry as Dictionary).duplicate(true)
		item["asset_id"] = str(asset_id)
		result.append(item)
	return result


static func texture_path_for(category: String, linked_data_id: String, manifest_path: String = DEFAULT_PATH) -> String:
	var wanted_category := str(category)
	var wanted_id := str(linked_data_id)
	if wanted_category == "" or wanted_id == "":
		return ""
	for entry in integrated_texture_entries(manifest_path):
		if str(entry.get("category", "")) != wanted_category:
			continue
		if str(entry.get("linked_data_id", "")) != wanted_id:
			continue
		return str(entry.get("path", ""))
	return ""


static func district_texture_path(district_id: String, phase: String = "") -> String:
	var clean_id := str(district_id).strip_edges()
	if clean_id == "":
		return ""
	var base := "res://assets/textures/districts/district_%s" % clean_id
	var clean_phase := str(phase).strip_edges()
	if clean_phase != "":
		var phase_path := "%s_%s.png" % [base, clean_phase]
		if ResourceLoader.exists(phase_path):
			return phase_path
	var base_path := "%s.png" % base
	if ResourceLoader.exists(base_path):
		return base_path
	return ""


static func tower_texture_path(district_id: String, phase: String = "") -> String:
	var clean_id := str(district_id).strip_edges()
	if clean_id == "":
		return ""
	var clean_phase := str(phase).strip_edges()
	var resolved_phase := clean_phase if clean_phase != "" else "morning"
	var path := "res://assets/textures/towers/tower_%s_%s.png" % [clean_id, resolved_phase]
	if ResourceLoader.exists(path):
		return path
	return ""


static func texture_for(category: String, linked_data_id: String, manifest_path: String = DEFAULT_PATH) -> Texture2D:
	var path := texture_path_for(category, linked_data_id, manifest_path)
	if path == "":
		return null
	var resource := ResourceLoader.load(path)
	return resource as Texture2D
