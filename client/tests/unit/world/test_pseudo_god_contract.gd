extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const HubScript = preload("res://scripts/hub/hub.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")
const DayCycleServiceScript = preload("res://scripts/world/day_cycle_service.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")

const PSEUDO_GOD_CONTRACT_SERVICE_PATH := "res://scripts/world/pseudo_god_contract_service.gd"
const AUTO_SAVE_PATH := "user://slice3_t5_sleep_auto.json"

var _passed := 0
var _failed := 0


class FakeDialogicAdapter:
	var started_timelines: Array[String] = []
	var variables: Dictionary = {}

	func start(timeline_id: String) -> void:
		started_timelines.append(timeline_id)

	func set_variable(variable_name: String, value: Variant) -> void:
		variables[variable_name] = value


func run() -> Dictionary:
	print("\n-- test_pseudo_god_contract.gd --")
	test_sequence8_unlocks_pseudo_contract_with_five_rules()
	test_strict_observance_adds_halfmoon_trust_and_three_sequence7_cards()
	test_violation_marks_breach_and_forces_day12_event_tower()
	test_pollution_80_sleep_forces_pendulum_warning_visitor()
	test_halfmoon_three_dialogue_entries_bind_story_variables()
	await test_hub_pseudo_god_contract_button_shows_five_rules()
	return {"passed": _passed, "failed": _failed}


func test_sequence8_unlocks_pseudo_contract_with_five_rules() -> void:
	var service = _service()
	if service == null:
		return
	var locked = _state()
	locked.sequence = 9
	var locked_result: Dictionary = service.call("ensure_unlocked_for_state", locked)
	assert_true(not bool(locked_result.get("unlocked", true)), "sequence 9 does not unlock pseudo-god contract")

	var gs = _state()
	gs.sequence = 8
	_replace_string_array(gs.learned_rules, ["mask", "observer", "question", "truth", "god_name"])
	var result: Dictionary = service.call("ensure_unlocked_for_state", gs)
	var contract: Dictionary = _contract(gs)
	assert_true(bool(result.get("ok", false)), "sequence 8 unlock call succeeds")
	assert_true(bool(result.get("unlocked", false)), "sequence 8 unlocks pseudo-god contract")
	assert_eq(str(contract.get("contract_id", "")), "pseudo_god_contract", "pseudo-god contract is stored with structured id")
	assert_eq(_array(contract.get("rule_ids", [])).size(), 5, "pseudo-god contract stores exactly 5 rule ids")
	assert_true(Array(gs.active_contract).size() >= 5, "active_contract receives the 5 pseudo-god rules")
	locked.queue_free()
	gs.queue_free()


func test_strict_observance_adds_halfmoon_trust_and_three_sequence7_cards() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _state()
	gs.sequence = 8
	gs.halfmoon_trust = 30
	_replace_string_array(gs.learned_rules, ["mask", "observer", "question", "truth", "god_name"])
	var unlocked: Dictionary = service.call("ensure_unlocked_for_state", gs)
	var outcomes := {}
	for rule_id in _array(unlocked.get("rule_ids", [])):
		outcomes[str(rule_id)] = "satisfied"
	var result: Dictionary = service.call("settle_rule_outcomes", gs, outcomes)
	assert_eq(str(result.get("outcome", "")), "strict", "all 5 pseudo-god rules produce strict outcome")
	assert_eq(int(result.get("previous_halfmoon_trust", -1)), 30, "strict result records previous halfmoon_trust")
	assert_eq(int(gs.halfmoon_trust), 80, "strict pseudo-god observance adds 50 trust points")
	assert_true(_array(result.get("crossed_thresholds", [])).has("friend"), "strict trust reward crosses friend threshold")
	assert_true(_array(result.get("crossed_thresholds", [])).has("trusted"), "strict trust reward crosses trusted threshold")
	var unlocked_card_ids: Array = _array(result.get("unlocked_card_ids", []))
	assert_eq(unlocked_card_ids.size(), 3, "strict pseudo-god observance unlocks exactly 3 cards")
	assert_eq(_sequence7_card_count(gs, unlocked_card_ids), 3, "all pseudo-god reward cards are Fool sequence 7 cards")
	gs.queue_free()


func test_violation_marks_breach_and_forces_day12_event_tower() -> void:
	var service = _service()
	if service == null:
		return
	var gs = _state()
	gs.sequence = 8
	gs.day = 11
	gs.halfmoon_trust = 80
	_replace_string_array(gs.learned_rules, ["mask", "observer", "question", "truth", "god_name"])
	var unlocked: Dictionary = service.call("ensure_unlocked_for_state", gs)
	var outcomes := {}
	for rule_id in _array(unlocked.get("rule_ids", [])):
		outcomes[str(rule_id)] = "satisfied"
	var rules: Array = _array(unlocked.get("rule_ids", []))
	if not rules.is_empty():
		outcomes[str(rules[0])] = "violated"
	var breach: Dictionary = service.call("settle_rule_outcomes", gs, outcomes)
	var contract: Dictionary = _contract(gs)
	assert_eq(str(breach.get("outcome", "")), "violated", "one violated pseudo-god rule records a violation outcome")
	assert_eq(int(gs.halfmoon_trust), 60, "pseudo-god violation subtracts 20 trust points")
	assert_true(bool(contract.get("violated", false)), "pseudo-god contract stores an explicit violated flag")

	gs.day = 12
	gs.church_awareness = 0
	var day_hook: Dictionary = DayCycleServiceScript.apply_day_hooks(gs)
	var forced: Dictionary = _forced_tower(gs)
	assert_true(bool(day_hook.get("triggered", false)), "Day 12 hook still triggers")
	assert_true(not forced.is_empty(), "pseudo-god violation forces the Day 12 exposure event tower")
	assert_eq(str(forced.get("node_id", "")), "node_5_church_investigation", "Day 12 exposure tower uses node_5 id")
	assert_eq(str(forced.get("tower_template", "")), "church_investigation", "Day 12 exposure tower uses church investigation template")
	gs.queue_free()


func test_pollution_80_sleep_forces_pendulum_warning_visitor() -> void:
	var gs = _state()
	gs.day = 5
	gs.time_of_day = "night"
	gs.pollution = 80
	gs.ap = 12
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH, 0.0)
	var dream: Dictionary = result.get("dream", {}) if result.get("dream", {}) is Dictionary else {}
	var visitor: Dictionary = result.get("visitor", {}) if result.get("visitor", {}) is Dictionary else {}
	assert_eq(int(dream.get("pollution_stage", -1)), 3, "pollution 80 produces stage-3 dream")
	assert_eq(str(dream.get("tone", "")), "warning", "stage-3 dream is the pendulum warning tone")
	assert_eq(str(visitor.get("id", "")), "pendulum_message", "pollution 80 forces the pendulum message visitor")
	assert_eq(str(visitor.get("source_npc_id", "")), "pendulum", "forced warning visitor is structurally tied to pendulum")
	gs.queue_free()


func test_halfmoon_three_dialogue_entries_bind_story_variables() -> void:
	var gs = _state()
	gs.sequence = 8
	gs.day = 12
	gs.pollution = 82
	gs.halfmoon_trust = 70
	var service := NpcInteractionServiceScript.new()
	for npc_id in ["harvey_mors", "reflection", "pendulum"]:
		var adapter := FakeDialogicAdapter.new()
		var result: Dictionary = service.open_dialogue(str(npc_id), gs, adapter)
		assert_true(bool(result.get("ok", false)), "%s halfmoon dialogue opens" % str(npc_id))
		assert_eq(adapter.started_timelines.size(), 1, "%s starts one Dialogic timeline" % str(npc_id))
		assert_eq(result.get("variables", {}).get("halfmoon_trust", -1), 70, "%s binds halfmoon_trust variable" % str(npc_id))
		assert_eq(result.get("variables", {}).get("pseudo_god_unlocked", null), true, "%s binds pseudo_god_unlocked variable" % str(npc_id))
	gs.queue_free()


func test_hub_pseudo_god_contract_button_shows_five_rules() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_state().to_dict())
	GameState.sequence = 8
	GameState.pseudo_god_contract = {
		"contract_id": "pseudo_god_contract",
		"unlocked": true,
		"rule_ids": ["mask", "observer", "question", "truth", "god_name"],
		"satisfied_rule_ids": ["mask", "observer"],
		"violated_rule_ids": ["truth"],
	}
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "Hub scene loads for pseudo-god contract button")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var button = hub.get_node_or_null("MarginContainer/VBoxContainer/StatusBar/PseudoGodContractButton")
	assert_true(button is Button, "Hub exposes pseudo-god contract status button")
	if button is Button:
		assert_true(button.visible, "pseudo-god contract button is visible after signing")
		assert_true(str(button.text).contains("2/5"), "pseudo-god contract button shows observed rule count")
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("PseudoGodContractDialog")
	assert_true(dialog is AcceptDialog and dialog.visible, "pseudo-god contract button opens status dialog")
	var text := str(dialog.dialog_text) if dialog is AcceptDialog else ""
	for rule_id in ["mask", "observer", "question", "truth", "god_name"]:
		assert_true(text.contains(rule_id), "pseudo-god contract dialog includes rule %s" % rule_id)
	assert_true(text.contains("已遵守") and text.contains("已违反") and text.contains("未触发"), "pseudo-god contract dialog shows all status labels")
	hub.queue_free()
	GameState.from_dict(previous)


func _service():
	var script = load(PSEUDO_GOD_CONTRACT_SERVICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "PseudoGodContractService script loads and can instantiate")
		return null
	var instance = script.new()
	assert_true(instance != null, "PseudoGodContractService instance creates")
	return instance


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	_clear_t5_meta(gs)
	return gs


func _contract(gs) -> Dictionary:
	var value: Variant = gs.get("pseudo_god_contract")
	if value is Dictionary:
		return value
	return {}


func _forced_tower(gs) -> Dictionary:
	if gs != null and gs.has_method("get_meta"):
		var value: Variant = gs.get_meta("mainline_forced_tower", {})
		if value is Dictionary:
			return value.duplicate(true)
	return {}


func _sequence7_card_count(gs, card_ids: Array) -> int:
	var count := 0
	for card_id in card_ids:
		var card = gs.get_card(str(card_id))
		if card != null and str(card.pathway) == "fool" and int(card.sequence) == 7:
			count += 1
	return count


func _replace_string_array(target: Array[String], values: Array) -> void:
	target.clear()
	for value in values:
		target.append(str(value))


func _array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _clear_t5_meta(gs) -> void:
	if gs == null:
		return
	for key in ["mainline_forced_tower", "mainline_popup_pending", "mainline_popup_text", "mainline_popup_title", "mainline_day"]:
		if gs.has_method("remove_meta") and gs.has_meta(key):
			gs.remove_meta(key)


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
