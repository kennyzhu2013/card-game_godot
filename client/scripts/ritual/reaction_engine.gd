class_name ReactionEngine
extends RefCounted

# _table is a ReactionTable autoload (Node-based, no class_name due to autoload
# collision; type-annotated as Node for documentation value).
var _table: Node


func _init(p_table: Node) -> void:
	_table = p_table


func compute(arrangement: GlyphArrangement) -> Array:
	# Returns array of ChemicalReaction triggered by the arrangement's adjacent
	# pairs (deduplicated by reaction id).
	var result: Array = []
	var seen_ids: Dictionary = {}
	for pair in arrangement.adjacent_symbol_pairs():
		var rx = _table.find_by_symbols(pair)
		if rx != null and not seen_ids.has(rx.id):
			seen_ids[rx.id] = true
			result.append(rx)
	return result


func total_pollution(arrangement: GlyphArrangement) -> int:
	var total := 0
	for rx in compute(arrangement):
		total += rx.pollution_delta
	return total
