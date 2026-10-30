extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const DICE_PATH := "res://scripts/minigames/casino/dice_minigame.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_casino_dice.gd --")
	test_expected_return_matches_r25_table()
	test_big_small_and_triple_settlement()
	test_bet_bounds_and_ap_gate()
	return {"passed": _passed, "failed": _failed}


func test_expected_return_matches_r25_table() -> void:
	var dice = _dice()
	if dice == null:
		return
	assert_true(dice.has_method("expected_return"), "DiceMinigame exposes expected_return")
	assert_approx(float(dice.call("expected_return", "big")), -0.0277777, 0.0005, "big EV is about -2.78%")
	assert_approx(float(dice.call("expected_return", "small")), -0.0277777, 0.0005, "small EV is about -2.78%")
	assert_approx(float(dice.call("expected_return", "triple")), -0.1666666, 0.0005, "triple EV is about -16.67%")


func test_big_small_and_triple_settlement() -> void:
	var dice = _dice()
	if dice == null:
		return
	assert_true(dice.has_method("play"), "DiceMinigame exposes play")
	var gs = _state()
	gs.lingstones = 100
	gs.ap = 12
	var big_win: Dictionary = dice.call("play", gs, {"bet": 10, "choice": "big", "dice": [4, 4, 3]})
	assert_true(bool(big_win.get("ok", false)), "big round settles")
	assert_eq(str(big_win.get("grade", "")), "big_win", "11 non-triple wins big")
	assert_eq(int(gs.lingstones), 110, "big win pays x2 after stake")
	assert_eq(int(gs.ap), 11, "dice round spends 1 AP")
	assert_eq(str(big_win.get("animation_state", "")), "shake_reveal", "dice settlement exposes shake/reveal animation state")
	gs.queue_free()

	var triple_big = _state()
	triple_big.lingstones = 100
	triple_big.ap = 12
	var house_win: Dictionary = dice.call("play", triple_big, {"bet": 10, "choice": "big", "dice": [4, 4, 4]})
	assert_true(bool(house_win.get("ok", false)), "triple is valid dice result")
	assert_eq(str(house_win.get("grade", "")), "loss", "house eats triples for big/small bets")
	assert_eq(int(triple_big.lingstones), 90, "lost big stake is removed")
	triple_big.queue_free()

	var triple_bet = _state()
	triple_bet.lingstones = 100
	triple_bet.ap = 12
	var triple_win: Dictionary = dice.call("play", triple_bet, {"bet": 10, "choice": "triple", "dice": [4, 4, 4]})
	assert_true(bool(triple_win.get("ok", false)), "triple bet settles")
	assert_eq(str(triple_win.get("grade", "")), "triple_win", "three equal dice win triple")
	assert_eq(int(triple_bet.lingstones), 390, "triple win pays x30 after stake")
	triple_bet.queue_free()


func test_bet_bounds_and_ap_gate() -> void:
	var dice = _dice()
	if dice == null:
		return
	var gs = _state()
	gs.lingstones = 100
	gs.ap = 0
	var blocked_ap: Dictionary = dice.call("play", gs, {"bet": 10, "choice": "small", "dice": [1, 2, 3]})
	assert_true(not bool(blocked_ap.get("ok", true)), "dice blocks when AP is short")
	assert_eq(str(blocked_ap.get("reason", "")), "ap_short", "short AP reports ap_short")
	gs.ap = 12
	var low_bet: Dictionary = dice.call("play", gs, {"bet": 2, "choice": "small", "dice": [1, 2, 3]})
	assert_true(not bool(low_bet.get("ok", true)), "dice blocks below early bet minimum")
	assert_eq(str(low_bet.get("reason", "")), "bet_out_of_range", "low bet reports bet_out_of_range")
	gs.queue_free()


func _dice():
	var script = load(DICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "DiceMinigame script loads and can instantiate")
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


func assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	if abs(actual - expected) <= tolerance:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected about '%s', got '%s'" % [message, str(expected), str(actual)])
