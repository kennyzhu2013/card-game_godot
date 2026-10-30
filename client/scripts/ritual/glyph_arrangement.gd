class_name GlyphArrangement
extends RefCounted

enum {
	SHAPE_LINE,   # 3 slots in a row, adjacency: (0,1), (1,2)
	SHAPE_L,      # 4 slots in L-shape, adjacency: (0,1), (1,2), (2,3)
	SHAPE_HEX     # 6 slots in hexagon, adjacency: (0,1)(1,2)(2,3)(3,4)(4,5)(5,0)
}

const _ADJACENCY := {
	SHAPE_LINE: [[0, 1], [1, 2]],
	SHAPE_L:    [[0, 1], [1, 2], [2, 3]],
	SHAPE_HEX:  [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]
}

var capacity: int = 0
var shape: int = SHAPE_LINE
var _slots: Array = []


func _init(p_capacity: int = 3, p_shape: int = SHAPE_LINE) -> void:
	capacity = p_capacity
	shape = p_shape
	_slots.resize(capacity)
	for i in range(capacity):
		_slots[i] = ""


func place(slot_index: int, symbol_id: String) -> void:
	if slot_index < 0 or slot_index >= capacity:
		push_error("[GlyphArrangement] slot %d out of range (capacity %d)" % [slot_index, capacity])
		return
	_slots[slot_index] = symbol_id


func clear_slot(slot_index: int) -> void:
	place(slot_index, "")


func get_at(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= capacity:
		return ""
	return _slots[slot_index]


func placed_count() -> int:
	var n := 0
	for s in _slots:
		if s != "":
			n += 1
	return n


func adjacent_symbol_pairs() -> Array:
	# Returns [[symbol_a, symbol_b], ...] for adjacent slots both filled.
	var pairs: Array = []
	var adjacency: Array = _ADJACENCY.get(shape, [])
	for pair in adjacency:
		var a: String = _slots[pair[0]]
		var b: String = _slots[pair[1]]
		if a != "" and b != "":
			pairs.append([a, b])
	return pairs


func to_dict() -> Dictionary:
	return {
		"capacity": capacity,
		"shape": shape,
		"slots": _slots.duplicate()
	}
