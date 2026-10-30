extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const RitualSymbolScript = preload("res://scripts/ritual/symbol.gd")
const SymbolInstanceScript = preload("res://scripts/ritual/symbol_instance.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_game_state.gd --")
	test_initial_slots_are_null()
	test_equip_skill_at_slot()
	test_equip_skill_out_of_range()
	test_get_equipped_slot_out_of_range()
	test_equipped_count_reflects_filled_slots()
	test_register_and_get_symbol_instance()
	test_record_symbol_use_increments_use_count()
	test_record_symbol_use_unknown_template_is_noop()
	test_reset_clears_all_state()
	return {"passed": _passed, "failed": _failed}


func _fresh_state() -> Node:
	var state = GameStateScript.new()
	state._ready()
	return state


func test_initial_slots_are_null() -> void:
	var state := _fresh_state()
	for i in GameStateScript.MAX_SLOTS:
		assert_true(state.get_equipped_slot(i) == null, "slot %d starts null" % i)
	state.queue_free()


func test_equip_skill_at_slot() -> void:
	var state := _fresh_state()
	var dummy := {"id": "shadow_arrow", "damage": 12}
	state.equip_skill(0, dummy)
	assert_true(state.get_equipped_slot(0) == dummy, "slot 0 holds equipped skill")
	assert_true(state.get_equipped_slot(1) == null, "slot 1 still null")
	state.queue_free()


func test_equip_skill_out_of_range() -> void:
	var state := _fresh_state()
	state.equip_skill(-1, {"id": "x"})
	state.equip_skill(99, {"id": "y"})
	assert_eq(state.equipped_count(), 0, "out-of-range equips are ignored")
	state.queue_free()


func test_get_equipped_slot_out_of_range() -> void:
	var state := _fresh_state()
	assert_true(state.get_equipped_slot(-1) == null, "slot -1 returns null")
	assert_true(state.get_equipped_slot(99) == null, "slot 99 returns null")
	state.queue_free()


func test_equipped_count_reflects_filled_slots() -> void:
	var state := _fresh_state()
	assert_eq(state.equipped_count(), 0, "empty state count == 0")
	state.equip_skill(0, {"id": "a"})
	state.equip_skill(2, {"id": "b"})
	assert_eq(state.equipped_count(), 2, "two slots filled count == 2")
	state.queue_free()


func test_register_and_get_symbol_instance() -> void:
	var state := _fresh_state()
	var template = RitualSymbolScript.new("shadow", "影", ["影", "恐", "失"], "fool")
	var inst = SymbolInstanceScript.from_template(template, 1)
	state.register_symbol_instance(inst)
	assert_true(state.get_symbol_instance("shadow") == inst, "registered instance retrievable by template_id")
	assert_true(state.get_symbol_instance("unknown") == null, "unknown template_id returns null")
	state.queue_free()


func test_record_symbol_use_increments_use_count() -> void:
	var state := _fresh_state()
	var template = RitualSymbolScript.new("shadow", "影", ["影"], "fool")
	var inst = SymbolInstanceScript.from_template(template, 0)
	state.register_symbol_instance(inst)
	state.record_symbol_use("shadow", false)
	assert_eq(inst.use_count, 1, "non-battle use increments use_count")
	assert_eq(inst.battles_witnessed, 0, "non-battle does not touch battles_witnessed")
	state.record_symbol_use("shadow", true)
	assert_eq(inst.use_count, 2, "battle use increments use_count")
	assert_eq(inst.battles_witnessed, 1, "battle use increments battles_witnessed")
	state.queue_free()


func test_record_symbol_use_unknown_template_is_noop() -> void:
	var state := _fresh_state()
	state.record_symbol_use("nonexistent", true)
	assert_true(state.get_symbol_instance("nonexistent") == null, "unknown record is no-op")
	state.queue_free()


func test_reset_clears_all_state() -> void:
	var state := _fresh_state()
	state.equip_skill(0, {"id": "a"})
	var template = RitualSymbolScript.new("shadow", "影", ["影"], "fool")
	state.register_symbol_instance(SymbolInstanceScript.from_template(template, 0))
	state.reset()
	assert_eq(state.equipped_count(), 0, "reset clears equipped_skills")
	assert_true(state.get_symbol_instance("shadow") == null, "reset clears symbol_instances")
	state.queue_free()


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
