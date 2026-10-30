class_name HotspotResolver
extends RefCounted

const SUPPORTED_COMPARATORS := [">=", "<=", "==", "!=", ">", "<"]


static func evaluate_visible_when(expression: Variant, game_state, extra_context: Dictionary = {}) -> bool:
	if expression is bool:
		return bool(expression)
	var text := str(expression).strip_edges()
	if text == "":
		return false
	if text == "always":
		return true
	if text.to_lower() == "false":
		return false
	if _has_unsupported_syntax(text):
		return false
	var clauses := text.split(" AND ", false)
	if clauses.is_empty():
		return false
	for raw_clause in clauses:
		if not _evaluate_clause(str(raw_clause).strip_edges(), game_state, extra_context):
			return false
	return true


static func _has_unsupported_syntax(text: String) -> bool:
	var upper := " %s " % text.to_upper()
	return upper.find(" OR ") >= 0 or text.find("(") >= 0 or text.find(")") >= 0


static func _evaluate_clause(clause: String, game_state, extra_context: Dictionary) -> bool:
	var parsed := _parse_clause(clause)
	if not bool(parsed.get("ok", false)):
		return false
	var left := _resolve_value(str(parsed.get("left", "")), game_state, extra_context)
	if not bool(left.get("ok", false)):
		return false
	var right: Variant = _parse_literal(str(parsed.get("right", "")))
	return _compare(left.get("value", null), str(parsed.get("op", "")), right)


static func _parse_clause(clause: String) -> Dictionary:
	for op in SUPPORTED_COMPARATORS:
		var pos := clause.find(op)
		if pos >= 0:
			return {
				"ok": true,
				"left": clause.substr(0, pos).strip_edges(),
				"op": op,
				"right": clause.substr(pos + op.length()).strip_edges(),
			}
	if clause.find("=") >= 0:
		var pos := clause.find("=")
		return {
			"ok": true,
			"left": clause.substr(0, pos).strip_edges(),
			"op": "==",
			"right": clause.substr(pos + 1).strip_edges(),
		}
	return {"ok": false}


static func _resolve_value(path: String, game_state, extra_context: Dictionary) -> Dictionary:
	if extra_context.has(path):
		return {"ok": true, "value": extra_context[path]}
	var modulo: Dictionary = _resolve_modulo_value(path, game_state, extra_context)
	if bool(modulo.get("ok", false)):
		return modulo
	match path:
		"time_of_day", "day", "cycle", "sequence", "pollution", "church_awareness", "halfmoon_trust", "ap", "lingstones":
			if game_state == null:
				return {"ok": false}
			return {"ok": true, "value": game_state.get(path)}
	if path.begins_with("mainline.") and path.ends_with(".completed"):
		return _resolve_mainline_completed(path, game_state)
	if path.begins_with("npc."):
		return _resolve_npc_relation(path, game_state)
	return {"ok": false}


static func _resolve_modulo_value(path: String, game_state, extra_context: Dictionary) -> Dictionary:
	if path.find("%") < 0:
		return {"ok": false}
	var parts := path.split("%", false)
	if parts.size() != 2:
		return {"ok": false}
	var base_path := str(parts[0]).strip_edges()
	var modulus_text := str(parts[1]).strip_edges()
	if not modulus_text.is_valid_int():
		return {"ok": false}
	var base: Dictionary = _resolve_value(base_path, game_state, extra_context)
	if not bool(base.get("ok", false)):
		return {"ok": false}
	var base_value: Variant = base.get("value", null)
	if not _is_number(base_value):
		return {"ok": false}
	var modulus := int(modulus_text)
	if modulus == 0:
		return {"ok": false}
	return {"ok": true, "value": int(base_value) % modulus}


static func _resolve_mainline_completed(path: String, game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false}
	var parts := path.split(".", false)
	if parts.size() != 3:
		return {"ok": false}
	var nodes: Array = []
	var daodian: Variant = game_state.get("daodian")
	if daodian is Dictionary:
		var raw_nodes: Variant = daodian.get("completed_main_story_nodes", [])
		if raw_nodes is Array:
			nodes = raw_nodes
	var wanted := str(parts[1])
	for node in nodes:
		var value := str(node)
		if value == wanted or value.begins_with("%s_" % wanted):
			return {"ok": true, "value": true}
	return {"ok": true, "value": false}


static func _resolve_npc_relation(path: String, game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false}
	var parts := path.split(".", false)
	if parts.size() != 3:
		return {"ok": false}
	var field := str(parts[2])
	if not field in ["trust", "suspicion"]:
		return {"ok": false}
	var relations: Variant = game_state.get("npc_relations")
	if not relations is Dictionary:
		return {"ok": false}
	var state: Variant = relations.get(str(parts[1]), null)
	if state == null:
		return {"ok": false}
	if state is Dictionary:
		if state.has(field):
			return {"ok": true, "value": state[field]}
		return {"ok": false}
	if state is Object:
		var value: Variant = state.get(field)
		if value != null:
			return {"ok": true, "value": value}
	return {"ok": false}


static func _parse_literal(raw_value: String) -> Variant:
	var value := raw_value.strip_edges()
	if (value.begins_with("'") and value.ends_with("'")) or (value.begins_with("\"") and value.ends_with("\"")):
		return value.substr(1, value.length() - 2)
	match value.to_lower():
		"true":
			return true
		"false":
			return false
	if value.is_valid_int():
		return int(value)
	if value.is_valid_float():
		return float(value)
	return value


static func _compare(left: Variant, op: String, right: Variant) -> bool:
	if _is_number(left) and _is_number(right):
		var a := float(left)
		var b := float(right)
		match op:
			"==":
				return is_equal_approx(a, b)
			"!=":
				return not is_equal_approx(a, b)
			">=":
				return a >= b
			"<=":
				return a <= b
			">":
				return a > b
			"<":
				return a < b
		return false
	match op:
		"==":
			return left == right
		"!=":
			return left != right
		_:
			return false


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
