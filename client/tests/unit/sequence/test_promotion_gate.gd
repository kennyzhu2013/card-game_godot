extends RefCounted

const GateScript = preload("res://scripts/sequence/sequence_promotion_gate.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_promotion_gate.gd --")
	test_promotion_gate_json_files_have_full_schema()
	test_from_json_9_to_8()
	test_to_dict_roundtrip()
	test_can_promote_all_conditions_met()
	test_can_promote_wrong_sequence()
	test_can_promote_insufficient_exp()
	test_can_promote_insufficient_reactions()
	test_can_promote_too_much_pollution()
	test_can_promote_no_active_contract()
	return {"passed": _passed, "failed": _failed}


func test_from_json_9_to_8() -> void:
	var d := {
		"from_sequence": 9, "to_sequence": 8,
		"sequence_exp_required": 100, "reactions_required": 8,
		"pollution_max": 50, "story_node_id": "node_4",
		"ritual_tower_id": "ritual_tower_introspection_3f",
		"contract_rules_required": 3,
	}
	var gate = GateScript.from_json(d)
	assert_eq(gate.from_sequence, 9, "9→8 from_sequence")
	assert_eq(gate.to_sequence, 8, "9→8 to_sequence")
	assert_eq(gate.sequence_exp_required, 100, "9→8 exp required")
	assert_eq(gate.reactions_required, 8, "9→8 reactions required")
	assert_eq(gate.pollution_max, 50, "9→8 pollution max")
	assert_eq(gate.story_node_id, "node_4", "9→8 story node")
	assert_eq(gate.contract_rules_required, 3, "9→8 contract rules")


func test_to_dict_roundtrip() -> void:
	var d := {
		"from_sequence": 8, "to_sequence": 7,
		"sequence_exp_required": 250, "reactions_required": 18,
		"pollution_max": 60, "story_node_id": "node_4b",
		"ritual_tower_id": "ritual_tower_paper_blade_4f",
		"contract_rules_required": 3,
	}
	var gate = GateScript.from_json(d)
	var d2 = gate.to_dict()
	var gate2 = GateScript.from_json(d2)
	assert_eq(gate2.from_sequence, 8, "rt from_sequence")
	assert_eq(gate2.sequence_exp_required, 250, "rt exp required")
	assert_eq(gate2.reactions_required, 18, "rt reactions")
	assert_eq(gate2.pollution_max, 60, "rt pollution max")


func test_promotion_gate_json_files_have_full_schema() -> void:
	for path in [
		"res://data/sequence/promotion_gates/fool_9_to_8.json",
		"res://data/sequence/promotion_gates/fool_8_to_7.json",
	]:
		var gate := _load_json(path)
		assert_true(gate is Dictionary and not gate.is_empty(), "%s loads as Dictionary" % path)
		assert_true(gate.has("sequence_exp_required"), "%s has sequence_exp_required" % path)
		assert_true(gate.has("reactions_required"), "%s has reactions_required" % path)
		assert_true(gate.has("pollution_max"), "%s has pollution_max" % path)
		assert_true(gate.has("story_node_id"), "%s has story_node_id" % path)
		assert_true(gate.has("ritual_tower_id"), "%s has ritual_tower_id" % path)
		assert_true(gate.has("contract_rules_required"), "%s has contract_rules_required" % path)
		assert_true(_is_number(gate.get("sequence_exp_required", null)), "%s sequence_exp_required numeric type" % path)
		assert_true(_is_number(gate.get("reactions_required", null)), "%s reactions_required numeric type" % path)
		assert_true(_is_number(gate.get("pollution_max", null)), "%s pollution_max numeric type" % path)
		assert_eq(typeof(gate.get("story_node_id", null)), TYPE_STRING, "%s story_node_id type" % path)
		assert_eq(typeof(gate.get("ritual_tower_id", null)), TYPE_STRING, "%s ritual_tower_id type" % path)
		assert_true(_is_number(gate.get("contract_rules_required", null)), "%s contract_rules_required numeric type" % path)


func test_can_promote_all_conditions_met() -> void:
	var gs = _new_gs()
	gs["sequence"] = 9
	gs["sequence_exp"] = 150
	gs["known_reactions"] = _make_reactions(8)
	gs["pollution"] = 20
	gs["active_contract"] = ["rule_a", "rule_b", "rule_c"]

	var gate = GateScript.from_json({"from_sequence": 9, "to_sequence": 8})
	assert_true(gate.can_promote(gs), "all conditions met → can promote")


func test_can_promote_wrong_sequence() -> void:
	var gs = _new_gs()
	gs["sequence"] = 8
	var gate = GateScript.from_json({"from_sequence": 9, "to_sequence": 8})
	assert_true(not gate.can_promote(gs), "wrong sequence → blocked")


func test_can_promote_insufficient_exp() -> void:
	var gs = _new_gs()
	gs["sequence"] = 9
	gs["sequence_exp"] = 50
	gs["known_reactions"] = _make_reactions(8)
	gs["active_contract"] = ["a", "b", "c"]
	var gate = GateScript.from_json({"from_sequence": 9, "to_sequence": 8})
	assert_true(not gate.can_promote(gs), "insufficient exp → blocked")


func test_can_promote_insufficient_reactions() -> void:
	var gs = _new_gs()
	gs["sequence"] = 9
	gs["sequence_exp"] = 150
	gs["active_contract"] = ["a", "b", "c"]
	var gate = GateScript.from_json({"from_sequence": 9, "to_sequence": 8, "reactions_required": 8})
	assert_true(not gate.can_promote(gs), "insufficient reactions → blocked")


func test_can_promote_too_much_pollution() -> void:
	var gs = _new_gs()
	gs["sequence"] = 9
	gs["sequence_exp"] = 150
	gs["known_reactions"] = _make_reactions(8)
	gs["pollution"] = 80
	gs["active_contract"] = ["a", "b", "c"]
	var gate = GateScript.from_json({"from_sequence": 9, "to_sequence": 8, "pollution_max": 50})
	assert_true(not gate.can_promote(gs), "pollution too high → blocked")


func test_can_promote_no_active_contract() -> void:
	var gs = _new_gs()
	gs["sequence"] = 9
	gs["sequence_exp"] = 150
	gs["known_reactions"] = _make_reactions(8)
	gs["pollution"] = 20
	gs["active_contract"] = ["a"]
	var gate = GateScript.from_json({"from_sequence": 9, "to_sequence": 8, "contract_rules_required": 3})
	assert_true(not gate.can_promote(gs), "contract rules insufficient → blocked")


func _make_reactions(count: int) -> Array:
	var arr := []
	for i in count:
		arr.append("rx_%d" % i)
	return arr


func _new_gs() -> Dictionary:
	return {
		"sequence": 9,
		"sequence_exp": 0,
		"known_reactions": [],
		"pollution": 0,
		"active_contract": [],
	}


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _is_number(value: Variant) -> bool:
	var t := typeof(value)
	return t == TYPE_INT or t == TYPE_FLOAT


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
