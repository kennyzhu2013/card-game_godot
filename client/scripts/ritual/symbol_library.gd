extends Node

const SymbolScript = preload("res://scripts/ritual/symbol.gd")

var _by_id: Dictionary = {}
var _order: Array = []


func load_from_file(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SymbolLibrary] cannot open %s" % path)
		return 0
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SymbolLibrary] invalid JSON in %s" % path)
		return 0
	var symbols_array: Array = parsed.get("symbols", [])
	var loaded := 0
	for sym_data in symbols_array:
		if typeof(sym_data) != TYPE_DICTIONARY:
			continue
		var sym = SymbolScript.from_dict(sym_data)
		_by_id[sym.id] = sym
		_order.append(sym.id)
		loaded += 1
	return loaded


func count() -> int:
	return _order.size()


func get_by_id(id: String):
	return _by_id.get(id, null)


func list_for_pathway(pathway: String) -> Array:
	var result: Array = []
	for id in _order:
		var sym = _by_id[id]
		if sym.pathway == pathway:
			result.append(sym)
	return result


func clear() -> void:
	_by_id.clear()
	_order.clear()
