class_name RitualSymbol
extends RefCounted

var id: String = ""
var display_name: String = ""
var aspects: Array[String] = []
var pathway: String = ""


func _init(p_id: String = "", p_display_name: String = "", p_aspects: Array = [], p_pathway: String = "") -> void:
	id = p_id
	display_name = p_display_name
	aspects.assign(p_aspects)
	pathway = p_pathway


func has_aspect(aspect: String) -> bool:
	return aspect in aspects


static func from_dict(data: Dictionary) -> RitualSymbol:
	var sym := RitualSymbol.new()
	sym.id = data.get("id", "")
	sym.display_name = data.get("display_name", "")
	sym.aspects.assign(data.get("aspects", []))
	sym.pathway = data.get("pathway", "")
	return sym


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"aspects": Array(aspects),
		"pathway": pathway,
	}
