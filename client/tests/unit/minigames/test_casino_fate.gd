extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const FATE_PATH := "res://scripts/minigames/casino/fate_minigame.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_casino_fate.gd --")
	test_fate_requires_day5_and_fixed_200_bet()
	test_correct_fate_choice_advances_mainline_with_risk()
	test_wrong_fate_choice_raises_awareness_and_suspicion()
	test_fate_cycle_limit_blocks_third_play()
	return {"passed": _passed, "failed": _failed}


func test_fate_requires_day5_and_fixed_200_bet() -> void:
	var fate = _fate()
	if fate == null:
		return
	assert_true(fate.has_method("play"), "FateMinigame exposes play")
	var gs = _state()
	gs.day = 4
	gs.lingstones = 500
	gs.ap = 12
	var early: Dictionary = fate.call("play", gs, {"choice_id": "truth_halfmoon", "truth_id": "truth_halfmoon", "bet": 200})
	assert_true(not bool(early.get("ok", true)), "fate cards block before Day 5")
	assert_eq(str(early.get("reason", "")), "day_locked", "early fate reports day_locked")
	gs.day = 5
	var wrong_bet: Dictionary = fate.call("play", gs, {"choice_id": "truth_halfmoon", "truth_id": "truth_halfmoon", "bet": 199})
	assert_true(not bool(wrong_bet.get("ok", true)), "fate cards reject non-fixed bet")
	assert_eq(str(wrong_bet.get("reason", "")), "fixed_bet_required", "wrong fate bet reports fixed_bet_required")
	gs.queue_free()


func test_correct_fate_choice_advances_mainline_with_risk() -> void:
	var fate = _fate()
	if fate == null:
		return
	var gs = _state()
	gs.day = 5
	gs.lingstones = 500
	gs.ap = 12
	gs.church_awareness = 0
	gs.dao_pages = 0
	var result: Dictionary = fate.call("play", gs, {"choice_id": "truth_halfmoon", "truth_id": "truth_halfmoon", "bet": 200})
	assert_true(bool(result.get("ok", false)), "correct fate choice settles")
	assert_eq(str(result.get("grade", "")), "correct", "correct fate choice is graded correct")
	assert_eq(int(gs.lingstones), 300, "fate consumes fixed 200 lingstones")
	assert_eq(int(gs.dao_pages), 1, "correct fate grants one dao page")
	assert_eq(int(gs.church_awareness), 5, "correct fate raises church awareness by 5")
	assert_true(bool(result.get("mainline_advanced", false)), "correct fate advances mainline")
	assert_true(_completed_nodes(gs).has(str(result.get("advanced_node_id", ""))), "advanced node is recorded structurally")
	assert_eq(int(gs.ap), 11, "fate round spends 1 AP")
	gs.queue_free()


func test_wrong_fate_choice_raises_awareness_and_suspicion() -> void:
	var fate = _fate()
	if fate == null:
		return
	var gs = _state()
	gs.day = 5
	gs.lingstones = 500
	gs.ap = 12
	var result: Dictionary = fate.call("play", gs, {"choice_id": "wrong_lantern", "truth_id": "truth_halfmoon", "bet": 200})
	assert_true(bool(result.get("ok", false)), "wrong fate choice still settles")
	assert_eq(str(result.get("grade", "")), "wrong", "wrong fate choice is graded wrong")
	assert_eq(int(gs.church_awareness), 5, "wrong fate raises church awareness by 5")
	var relation = gs.npc_relations.get("eel_fan", null)
	assert_true(relation != null, "wrong fate creates eel_fan relation state")
	if relation != null:
		assert_eq(int(relation.suspicion), 3, "wrong fate adds suspicion +3 to eel_fan")
	gs.queue_free()


func test_fate_cycle_limit_blocks_third_play() -> void:
	var fate = _fate()
	if fate == null:
		return
	var gs = _state()
	gs.day = 5
	gs.lingstones = 1000
	gs.ap = 12
	for i in range(2):
		var result: Dictionary = fate.call("play", gs, {"choice_id": "truth_halfmoon", "truth_id": "truth_halfmoon", "bet": 200})
		assert_true(bool(result.get("ok", false)), "fate play %d succeeds" % [i + 1])
	var third: Dictionary = fate.call("play", gs, {"choice_id": "truth_halfmoon", "truth_id": "truth_halfmoon", "bet": 200})
	assert_true(not bool(third.get("ok", true)), "third fate play is blocked")
	assert_eq(str(third.get("reason", "")), "cycle_limit", "third fate play reports cycle_limit")
	gs.queue_free()


func _completed_nodes(gs) -> Array:
	var nodes = gs.daodian.get("completed_main_story_nodes", [])
	return nodes if nodes is Array else []


func _fate():
	var script = load(FATE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "FateMinigame script loads and can instantiate")
		return null
	return script.new()


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


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
