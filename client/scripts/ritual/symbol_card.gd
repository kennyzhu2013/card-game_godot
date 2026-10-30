extends Panel
class_name SymbolCard

@onready var _name_label: Label = $VBoxContainer/NameLabel
@onready var _aspects_label: Label = $VBoxContainer/AspectsLabel

var bound_symbol = null   # RitualSymbol


func bind_symbol(symbol) -> void:
	bound_symbol = symbol
	if _name_label == null:
		await ready
	_name_label.text = symbol.display_name
	_aspects_label.text = " / ".join(symbol.aspects)


func get_displayed_name() -> String:
	if _name_label == null:
		await ready
	return _name_label.text


func get_displayed_aspects() -> String:
	if _aspects_label == null:
		await ready
	return _aspects_label.text


func _get_drag_data(_at_position: Vector2) -> Variant:
	if bound_symbol == null:
		return null
	var preview = duplicate()
	set_drag_preview(preview)
	return {"symbol_id": bound_symbol.id}
