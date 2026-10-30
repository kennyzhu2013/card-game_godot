extends Panel

signal symbol_dropped(slot_index: int, symbol_id: String)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("symbol_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var slot_index: int = get_meta("slot_index", -1)
	var symbol_id: String = data.get("symbol_id", "")
	if slot_index >= 0 and symbol_id != "":
		symbol_dropped.emit(slot_index, symbol_id)
