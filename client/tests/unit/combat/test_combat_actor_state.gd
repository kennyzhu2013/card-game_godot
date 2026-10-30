extends RefCounted

const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_combat_actor_state.gd --")
	test_status_add_has_remove()
	test_status_tick_decrements_duration_and_removes_zero()
	test_marker_push_consume_and_cap()
	test_turn_battle_field_state_helpers()
	return {"passed": _passed, "failed": _failed}


func test_status_add_has_remove() -> void:
	var actor = CombatActorScript.new()
	if not _assert_actor_status_api(actor):
		return
	actor.add_status("weak", {"duration": 2, "magnitude": 1})
	assert_true(actor.has_status("weak"), "actor has added weak status")
	assert_eq(int(actor.statuses["weak"].get("duration", 0)), 2, "weak duration stored")
	assert_eq(int(actor.statuses["weak"].get("magnitude", 0)), 1, "weak magnitude stored")
	actor.remove_status("weak")
	assert_true(not actor.has_status("weak"), "removed weak status is absent")


func test_status_tick_decrements_duration_and_removes_zero() -> void:
	var actor = CombatActorScript.new()
	if not _assert_actor_status_api(actor):
		return
	actor.add_status("weak", {"duration": 2, "magnitude": 1})
	actor.add_status("vulnerable", {"duration": 1, "magnitude": 2})
	actor.add_status("next_card_cost_delta", {"magnitude": -1})
	actor.tick_statuses()
	assert_true(actor.has_status("weak"), "duration 2 status survives first tick")
	assert_eq(int(actor.statuses["weak"].get("duration", 0)), 1, "duration decrements by 1")
	assert_true(not actor.has_status("vulnerable"), "duration 1 status is removed on tick")
	assert_true(actor.has_status("next_card_cost_delta"), "status without duration is not tick-removed")


func test_marker_push_consume_and_cap() -> void:
	var actor = CombatActorScript.new()
	if not _assert_actor_marker_api(actor):
		return
	actor.add_marker("paper_doll", 1)
	assert_eq(actor.get_marker_count("paper_doll"), 1, "paper_doll marker starts at 1")
	actor.add_marker("paper_doll", 5, 3)
	assert_eq(actor.get_marker_count("paper_doll"), 3, "paper_doll marker respects max_stacks cap")
	assert_true(actor.consume_marker("paper_doll", 2), "consume_marker succeeds with enough markers")
	assert_eq(actor.get_marker_count("paper_doll"), 1, "consume_marker subtracts count")
	assert_true(not actor.consume_marker("paper_doll", 2), "consume_marker rejects insufficient count")
	assert_eq(actor.get_marker_count("paper_doll"), 1, "failed consume keeps count unchanged")


func test_turn_battle_field_state_helpers() -> void:
	var battle = TurnBattleScript.new()
	assert_true(_has_property(battle, "field_state"), "TurnBattle exposes field_state")
	assert_true(battle.has_method("get_field_marker_count"), "TurnBattle.get_field_marker_count exists")
	assert_true(battle.has_method("add_field_marker"), "TurnBattle.add_field_marker exists")
	assert_true(battle.has_method("consume_field_marker"), "TurnBattle.consume_field_marker exists")
	assert_true(battle.has_method("clear_field_state"), "TurnBattle.clear_field_state exists")
	if not _has_property(battle, "field_state"):
		return
	if not (
		battle.has_method("get_field_marker_count")
		and battle.has_method("add_field_marker")
		and battle.has_method("consume_field_marker")
		and battle.has_method("clear_field_state")
	):
		return
	assert_eq(battle.get_field_marker_count("flame_markers"), 0, "flame_markers starts at 0")
	battle.add_field_marker("flame_markers", 2)
	assert_eq(battle.get_field_marker_count("flame_markers"), 2, "field marker add increments")
	battle.add_field_marker("flame_markers", 5, 4)
	assert_eq(battle.get_field_marker_count("flame_markers"), 4, "field marker respects cap")
	assert_true(battle.consume_field_marker("flame_markers", 3), "field marker consume succeeds")
	assert_eq(battle.get_field_marker_count("flame_markers"), 1, "field marker consume subtracts")
	assert_true(not battle.consume_field_marker("flame_markers", 2), "field marker consume rejects insufficient count")
	battle.clear_field_state()
	assert_eq(battle.get_field_marker_count("flame_markers"), 0, "clear_field_state resets flame_markers")


func _assert_actor_status_api(actor) -> bool:
	assert_true(_has_property(actor, "statuses"), "CombatActor.statuses exists")
	assert_true(actor.has_method("add_status"), "CombatActor.add_status exists")
	assert_true(actor.has_method("has_status"), "CombatActor.has_status exists")
	assert_true(actor.has_method("remove_status"), "CombatActor.remove_status exists")
	assert_true(actor.has_method("tick_statuses"), "CombatActor.tick_statuses exists")
	return (
		_has_property(actor, "statuses")
		and actor.has_method("add_status")
		and actor.has_method("has_status")
		and actor.has_method("remove_status")
		and actor.has_method("tick_statuses")
	)


func _assert_actor_marker_api(actor) -> bool:
	assert_true(_has_property(actor, "markers"), "CombatActor.markers exists")
	assert_true(actor.has_method("add_marker"), "CombatActor.add_marker exists")
	assert_true(actor.has_method("consume_marker"), "CombatActor.consume_marker exists")
	assert_true(actor.has_method("get_marker_count"), "CombatActor.get_marker_count exists")
	return (
		_has_property(actor, "markers")
		and actor.has_method("add_marker")
		and actor.has_method("consume_marker")
		and actor.has_method("get_marker_count")
	)


func _has_property(object, property_name: String) -> bool:
	for property in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


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
