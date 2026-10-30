extends Node

const ELEMENT_TABLE_PATH := "res://data/combat/element_table.json"

var _matrix: Dictionary = {}


func _ready() -> void:
	load_table()


func load_table() -> void:
	var text := FileAccess.get_file_as_string(ELEMENT_TABLE_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_matrix = parsed.get("interaction_matrix", {})


func multiplier(attacker_element: String, defender_element: String) -> float:
	if not _matrix.has(attacker_element):
		return 1.0
	var row: Variant = _matrix[attacker_element]
	if row is Dictionary:
		return float(row.get(defender_element, 1.0))
	return 1.0
