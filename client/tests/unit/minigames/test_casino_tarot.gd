extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const TAROT_PATH := "res://scripts/minigames/casino/tarot_minigame.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_casino_tarot.gd --")
	test_major_arcana_deck_and_six_outcome_modes()
	test_roll_thresholds_map_to_r25_modes()
	test_tarot_settlement_dispatches_rewards()
	return {"passed": _passed, "failed": _failed}


func test_major_arcana_deck_and_six_outcome_modes() -> void:
	var tarot = _tarot()
	if tarot == null:
		return
	assert_true(tarot.has_method("major_arcana_deck"), "TarotMinigame exposes major_arcana_deck")
	assert_true(tarot.has_method("outcome_modes"), "TarotMinigame exposes outcome_modes")
	var deck: Array = tarot.call("major_arcana_deck")
	assert_eq(deck.size(), 22, "tarot deck has 22 major arcana")
	assert_true(_has_id(deck, "fool"), "tarot deck includes fool arcana")
	var modes: Array = tarot.call("outcome_modes")
	assert_eq(modes.size(), 6, "tarot has six R25 outcome modes")
	assert_approx(_chance_sum(modes), 100.0, 0.01, "tarot outcome chances sum to 100")


func test_roll_thresholds_map_to_r25_modes() -> void:
	var tarot = _tarot()
	if tarot == null:
		return
	assert_true(tarot.has_method("grade_for_roll"), "TarotMinigame exposes grade_for_roll")
	assert_eq(str(tarot.call("grade_for_roll", 0.10)), "no_relation", "0.10 roll maps to no_relation")
	assert_eq(str(tarot.call("grade_for_roll", 0.70)), "one_relation", "0.70 roll maps to one_relation")
	assert_eq(str(tarot.call("grade_for_roll", 0.90)), "mystic_three", "0.90 roll maps to mystic_three")
	assert_eq(str(tarot.call("grade_for_roll", 0.95)), "same_polarity_three", "0.95 roll maps to same_polarity_three")
	assert_eq(str(tarot.call("grade_for_roll", 0.99)), "fool_mystic", "0.99 roll maps to fool_mystic")
	assert_eq(str(tarot.call("grade_for_roll", 0.998)), "major_same_polarity", "0.998 roll maps to major_same_polarity")


func test_tarot_settlement_dispatches_rewards() -> void:
	var tarot = _tarot()
	if tarot == null:
		return
	assert_true(tarot.has_method("play"), "TarotMinigame exposes play")
	var gs = _state()
	gs.lingstones = 500
	gs.ap = 12
	var result: Dictionary = tarot.call("play", gs, {"bet": 100, "roll": 0.90, "reward_roll": 0.2})
	assert_true(bool(result.get("ok", false)), "tarot round settles")
	assert_eq(str(result.get("grade", "")), "mystic_three", "tarot roll hits mystic_three")
	assert_eq(int(gs.lingstones), 600, "mystic_three pays x2 after stake")
	assert_true(int(gs.forge_materials.get("tarot_residue", 0)) >= 1, "mystic_three grants one forging material")
	assert_eq(int(gs.ap), 11, "tarot round spends 1 AP")
	gs.queue_free()


func _tarot():
	var script = load(TAROT_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "TarotMinigame script loads and can instantiate")
		return null
	return script.new()


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _has_id(entries: Array, id: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return true
	return false


func _chance_sum(modes: Array) -> float:
	var total := 0.0
	for mode in modes:
		if mode is Dictionary:
			total += float(mode.get("chance_pct", 0.0))
	return total


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


func assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	if abs(actual - expected) <= tolerance:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected about '%s', got '%s'" % [message, str(expected), str(actual)])
