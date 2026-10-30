class_name ChemicalReaction
extends RefCounted

var id: String = ""
var required_symbols: Array[String] = []
var display_name: String = ""
var description: String = ""
var pollution_delta: int = 0


func _init(p_id: String = "", p_required: Array = [], p_display_name: String = "", p_description: String = "", p_pollution: int = 0) -> void:
	id = p_id
	required_symbols.assign(p_required)
	display_name = p_display_name
	description = p_description
	pollution_delta = p_pollution


func matches(symbol_ids: Array) -> bool:
	if symbol_ids.size() != required_symbols.size():
		return false
	var ours_sorted: Array = []
	ours_sorted.assign(required_symbols)
	ours_sorted.sort()
	var theirs_sorted: Array = symbol_ids.duplicate()
	theirs_sorted.sort()
	return ours_sorted == theirs_sorted


static func from_dict(data: Dictionary) -> ChemicalReaction:
	var rx := ChemicalReaction.new()
	rx.id = data.get("id", "")
	rx.required_symbols.assign(data.get("required_symbols", []))
	rx.display_name = data.get("display_name", "")
	rx.description = data.get("description", "")
	rx.pollution_delta = int(data.get("pollution_delta", 0))
	return rx


func to_dict() -> Dictionary:
	return {
		"id": id,
		"required_symbols": Array(required_symbols),
		"display_name": display_name,
		"description": description,
		"pollution_delta": pollution_delta,
	}
