extends Node

const ChemicalReactionScript = preload("res://scripts/ritual/chemical_reaction.gd")

var _reactions: Array = []


func load_from_file(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ReactionTable] cannot open %s" % path)
		return 0
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[ReactionTable] invalid JSON in %s" % path)
		return 0
	var reactions_array: Array = parsed.get("reactions", [])
	var loaded := 0
	for rx_data in reactions_array:
		if typeof(rx_data) != TYPE_DICTIONARY:
			continue
		var rx = ChemicalReactionScript.from_dict(rx_data)
		_reactions.append(rx)
		loaded += 1
	return loaded


func count() -> int:
	return _reactions.size()


func find_by_symbols(symbol_ids: Array):
	for rx in _reactions:
		if rx.matches(symbol_ids):
			return rx
	return null


func all_reactions() -> Array:
	return _reactions.duplicate()


func clear() -> void:
	_reactions.clear()
