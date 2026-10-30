class_name DialogicPortraitResolver
extends RefCounted

const PORTRAIT_DIR := "res://assets/textures/portraits"
const PORTRAIT_PREFIX := "portrait_"
const EXPRESSION_SUFFIXES := [
	"default",
	"angry",
	"shocked",
	"mysterious",
]


func resolve_path(requested_asset_id: String) -> String:
	var asset_id := _asset_id_from_request(requested_asset_id)
	if not asset_id.begins_with(PORTRAIT_PREFIX):
		return ""
	var direct_path := "%s/%s.png" % [PORTRAIT_DIR, asset_id]
	if ResourceLoader.exists(direct_path):
		return direct_path
	var linked_data_id := linked_data_id_from_asset_id(asset_id)
	if linked_data_id == "":
		return ""
	return fallback_path_for(linked_data_id)


func fallback_path_for(linked_data_id: String) -> String:
	if linked_data_id == "":
		return ""
	return "%s/%s%s.png" % [PORTRAIT_DIR, PORTRAIT_PREFIX, linked_data_id]


func linked_data_id_from_asset_id(asset_id: String) -> String:
	if not asset_id.begins_with(PORTRAIT_PREFIX):
		return ""
	var linked_data_id := asset_id.substr(PORTRAIT_PREFIX.length())
	for suffix in EXPRESSION_SUFFIXES:
		var marker := "_%s" % suffix
		if linked_data_id.ends_with(marker):
			return linked_data_id.substr(0, linked_data_id.length() - marker.length())
	return linked_data_id


func _asset_id_from_request(requested_asset_id: String) -> String:
	var value := requested_asset_id.strip_edges()
	if value.ends_with(".png"):
		value = value.get_file().get_basename()
	return value
