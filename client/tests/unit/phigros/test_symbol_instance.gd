extends RefCounted

const RitualSymbolScript = preload("res://scripts/ritual/symbol.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_symbol_instance.gd --")
	test_from_template_copies_template_fields()
	test_cultivation_level_increments_every_5_uses()
	test_cultivation_level_caps_at_10()
	test_record_use_battle_flag_increments_battles_witnessed()
	test_serialize_roundtrip()
	return {"passed": _passed, "failed": _failed}


func test_from_template_copies_template_fields() -> void:
	var SymbolInstanceScript = _load_symbol_instance_script()
	if SymbolInstanceScript == null:
		return
	var template = RitualSymbolScript.new("shadow", "影", ["影", "恐", "失"], "fool")
	var inst = SymbolInstanceScript.from_template(template, 3)
	assert_eq(inst.template_id, "shadow", "from_template copies template_id")
	assert_eq(inst.display_name, "影", "from_template copies display_name")
	assert_eq(inst.pathway, "fool", "from_template copies pathway")
	assert_eq(inst.first_acquired_day, 3, "from_template records first_acquired_day")
	assert_array_eq(inst.aspects, ["影", "恐", "失"], "from_template copies aspects")
	assert_eq(float(inst.aspect_strengths.get("影", 0.0)), 1.0, "from_template sets 影 strength")
	assert_eq(float(inst.aspect_strengths.get("恐", 0.0)), 1.0, "from_template sets 恐 strength")
	assert_eq(float(inst.aspect_strengths.get("失", 0.0)), 1.0, "from_template sets 失 strength")
	template.aspects.append("骗")
	assert_eq(inst.aspects.size(), 3, "from_template aspects are independent copy")


func test_cultivation_level_increments_every_5_uses() -> void:
	var SymbolInstanceScript = _load_symbol_instance_script()
	if SymbolInstanceScript == null:
		return
	var inst = SymbolInstanceScript.new()
	for i in 5:
		inst.record_use()
	assert_eq(inst.use_count, 5, "record_use counts 5 uses")
	assert_eq(inst.cultivation_level, 1, "cultivation_level increments after 5 uses")
	for i in 4:
		inst.record_use()
	assert_eq(inst.cultivation_level, 1, "cultivation_level waits until next fifth use")
	inst.record_use()
	assert_eq(inst.use_count, 10, "record_use counts 10 uses")
	assert_eq(inst.cultivation_level, 2, "cultivation_level increments after 10 uses")


func test_cultivation_level_caps_at_10() -> void:
	var SymbolInstanceScript = _load_symbol_instance_script()
	if SymbolInstanceScript == null:
		return
	var inst = SymbolInstanceScript.new()
	for i in 60:
		inst.record_use()
	assert_eq(inst.use_count, 60, "record_use counts all uses beyond cap")
	assert_eq(inst.cultivation_level, 10, "cultivation_level caps at 10")


func test_record_use_battle_flag_increments_battles_witnessed() -> void:
	var SymbolInstanceScript = _load_symbol_instance_script()
	if SymbolInstanceScript == null:
		return
	var inst = SymbolInstanceScript.new()
	inst.record_use(true)
	inst.record_use(false)
	inst.record_use(true)
	assert_eq(inst.use_count, 3, "record_use always increments use_count")
	assert_eq(inst.battles_witnessed, 2, "record_use(true) increments battles_witnessed only for battle use")


func test_serialize_roundtrip() -> void:
	var SymbolInstanceScript = _load_symbol_instance_script()
	if SymbolInstanceScript == null:
		return
	var template = RitualSymbolScript.new("shadow", "影", ["影", "恐", "失"], "fool")
	var inst = SymbolInstanceScript.from_template(template, 7)
	inst.cultivation_level = 4
	inst.use_count = 21
	inst.battles_witnessed = 6
	inst.aspect_strengths["恐"] = 2.0
	inst.mutation_type = "异变"
	inst.mutation_aspect = "恐"
	inst.forged_into.assign(["shadow_arrow", "inquiry_mirror"])
	inst.npc_used_on.assign(["npc_hawi", "npc_guard"])
	inst.notable_moments = [{"day": 8, "summary": "初战见血"}]
	inst.player_name = "暗潮"
	inst.is_variant = true
	var data: Dictionary = inst.to_dict()
	var expected_fields := [
		"template_id",
		"display_name",
		"pathway",
		"cultivation_level",
		"use_count",
		"battles_witnessed",
		"aspects",
		"aspect_strengths",
		"mutation_type",
		"mutation_aspect",
		"forged_into",
		"npc_used_on",
		"first_acquired_day",
		"notable_moments",
		"player_name",
		"is_variant",
	]
	for field in expected_fields:
		assert_true(data.has(field), "to_dict includes %s" % field)
	assert_true(not data.has("instance_uuid"), "to_dict excludes non-spec instance_uuid")
	var rebuilt = SymbolInstanceScript.from_dict(data)
	assert_eq(rebuilt.template_id, inst.template_id, "roundtrip template_id")
	assert_eq(rebuilt.display_name, inst.display_name, "roundtrip display_name")
	assert_eq(rebuilt.pathway, inst.pathway, "roundtrip pathway")
	assert_eq(rebuilt.cultivation_level, inst.cultivation_level, "roundtrip cultivation_level")
	assert_eq(rebuilt.use_count, inst.use_count, "roundtrip use_count")
	assert_eq(rebuilt.battles_witnessed, inst.battles_witnessed, "roundtrip battles_witnessed")
	assert_array_eq(rebuilt.aspects, inst.aspects, "roundtrip aspects")
	assert_eq(float(rebuilt.aspect_strengths.get("恐", 0.0)), 2.0, "roundtrip aspect_strengths")
	assert_eq(rebuilt.mutation_type, inst.mutation_type, "roundtrip mutation_type")
	assert_eq(rebuilt.mutation_aspect, inst.mutation_aspect, "roundtrip mutation_aspect")
	assert_array_eq(rebuilt.forged_into, inst.forged_into, "roundtrip forged_into")
	assert_array_eq(rebuilt.npc_used_on, inst.npc_used_on, "roundtrip npc_used_on")
	assert_eq(rebuilt.first_acquired_day, inst.first_acquired_day, "roundtrip first_acquired_day")
	assert_eq(String(rebuilt.notable_moments[0].get("summary", "")), "初战见血", "roundtrip notable_moments")
	assert_eq(rebuilt.player_name, inst.player_name, "roundtrip player_name")
	assert_eq(rebuilt.is_variant, inst.is_variant, "roundtrip is_variant")


func _load_symbol_instance_script():
	var script = load("res://scripts/ritual/symbol_instance.gd")
	if script == null or not script.can_instantiate():
		assert_true(false, "SymbolInstance script loads")
		return null
	assert_true(true, "SymbolInstance script loads")
	return script


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


func assert_array_eq(actual: Array, expected: Array, message: String) -> void:
	if actual.size() != expected.size():
		_failed += 1
		print("  FAIL: %s - expected size '%d', got '%d'" % [message, expected.size(), actual.size()])
		return
	for i in expected.size():
		if actual[i] != expected[i]:
			_failed += 1
			print("  FAIL: %s - index %d expected '%s', got '%s'" % [message, i, str(expected[i]), str(actual[i])])
			return
	_passed += 1
	print("  PASS: %s" % message)
