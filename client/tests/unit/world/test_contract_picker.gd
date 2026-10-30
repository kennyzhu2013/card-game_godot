extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const SCRIPT_PATH := "res://scripts/ui/contract_picker_dialog.gd"
const SCENE_PATH := "res://scenes/ui/contract_picker_dialog.tscn"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_contract_picker.gd --")
	await test_scene_and_script_load()
	await test_picker_locks_exactly_three_learned_rules()
	await test_picker_rejects_non_three_rule_selection()
	test_default_contract_uses_first_three_learned_rules()
	test_cycle_reset_preserves_previous_active_contract()
	return {"passed": _passed, "failed": _failed}


func test_scene_and_script_load() -> void:
	var script = load(SCRIPT_PATH)
	assert_true(script != null and script.can_instantiate(), "contract picker script loads")
	var scene = load(SCENE_PATH) if ResourceLoader.exists(SCENE_PATH) else null
	assert_true(scene != null and scene.can_instantiate(), "contract picker scene loads")


func test_picker_locks_exactly_three_learned_rules() -> void:
	var picker = await _picker()
	if picker == null:
		return
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_a", "rule_b", "rule_c", "rule_d"])
	gs.active_contract.clear()
	picker.open(gs)
	assert_true(picker.visible, "contract picker is visible after open")
	assert_eq(picker.available_rules(), ["rule_a", "rule_b", "rule_c", "rule_d"], "picker lists learned rules in order")
	assert_true(picker.select_rule("rule_a", true), "picker selects first rule")
	assert_true(picker.select_rule("rule_c", true), "picker selects second rule")
	assert_true(picker.select_rule("rule_d", true), "picker selects third rule")
	assert_true(picker.lock_selection(), "picker locks exactly three rules")
	assert_eq(Array(gs.active_contract), ["rule_a", "rule_c", "rule_d"], "lock writes active_contract")
	assert_true(not picker.visible, "picker hides after lock")
	picker.queue_free()
	gs.queue_free()


func test_picker_rejects_non_three_rule_selection() -> void:
	var picker = await _picker()
	if picker == null:
		return
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_a", "rule_b", "rule_c", "rule_d"])
	gs.active_contract.clear()
	picker.open(gs)
	picker.select_rule("rule_a", true)
	picker.select_rule("rule_b", true)
	assert_true(not picker.lock_selection(), "picker rejects two selected rules")
	assert_eq(Array(gs.active_contract), [], "two-rule reject does not mutate active_contract")
	picker.select_rule("rule_c", true)
	picker.select_rule("rule_d", true)
	assert_true(not picker.lock_selection(), "picker rejects four selected rules")
	assert_eq(Array(gs.active_contract), [], "four-rule reject does not mutate active_contract")
	picker.queue_free()
	gs.queue_free()


func test_default_contract_uses_first_three_learned_rules() -> void:
	var script = load(SCRIPT_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "contract picker script loads for default lock")
		return
	var picker = script.new()
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_a", "rule_b", "rule_c", "rule_d"])
	gs.active_contract.clear()
	assert_true(picker.ensure_contract_for_tower(gs), "ensure_contract_for_tower locks a default contract")
	assert_eq(Array(gs.active_contract), ["rule_a", "rule_b", "rule_c"], "default contract uses first three learned rules")
	gs.queue_free()


func test_cycle_reset_preserves_previous_active_contract() -> void:
	var gs = _state()
	_replace_string_array(gs.active_contract, ["rule_a", "rule_b", "rule_c"])
	gs.reset()
	assert_eq(Array(gs.active_contract), ["rule_a", "rule_b", "rule_c"], "cycle reset preserves prior active contract")
	gs.queue_free()


func _picker():
	var scene = load(SCENE_PATH) if ResourceLoader.exists(SCENE_PATH) else null
	if scene == null or not scene.can_instantiate():
		assert_true(false, "contract picker scene loads for interaction")
		return null
	var picker = scene.instantiate()
	Engine.get_main_loop().root.add_child(picker)
	await Engine.get_main_loop().process_frame
	return picker


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _replace_string_array(target: Array[String], values: Array) -> void:
	target.clear()
	for value in values:
		target.append(str(value))


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
