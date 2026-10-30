extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0
var _last_ap_signal: Array[int] = []


func run() -> Dictionary:
	print("\n-- test_ap_service.gd --")
	test_v35_cost_tables_match_slice_2_plan()
	test_spend_ap_never_goes_negative_and_reports_shortage()
	test_game_state_ap_signal_emits_on_spend_and_refill()
	test_budget_prevents_big_tower_meditation_forge_and_sleep_without_deficit()
	return {"passed": _passed, "failed": _failed}


func test_v35_cost_tables_match_slice_2_plan() -> void:
	assert_eq(ApServiceScript.forge_cost_for_capacity(3), 2, "LINE forge costs 2 AP")
	assert_eq(ApServiceScript.forge_cost_for_capacity(4), 3, "L forge costs 3 AP")
	assert_eq(ApServiceScript.forge_cost_for_capacity(6), 3, "HEX forge costs 3 AP")
	assert_eq(ApServiceScript.tower_cost_for_size("small"), 2, "small tower costs 2 AP")
	assert_eq(ApServiceScript.tower_cost_for_size("medium"), 4, "medium tower costs 4 AP")
	assert_eq(ApServiceScript.tower_cost_for_size("large"), 6, "large tower costs 6 AP")
	assert_eq(ApServiceScript.district_travel_cost("shadow_alley"), 0, "shadow alley roam is free")
	assert_eq(ApServiceScript.district_travel_cost("steel_district"), 0, "steel district roam is free")
	assert_eq(ApServiceScript.district_travel_cost("mist_harbor"), 0, "mist harbor roam is free")
	assert_eq(ApServiceScript.district_travel_cost("seven_saints"), 0, "seven saints roam is free")
	assert_eq(ApServiceScript.district_travel_cost("stone_tower"), 2, "stone tower remote travel costs 2 AP")
	assert_eq(ApServiceScript.district_travel_cost("ascetic_mountain"), 2, "ascetic mountain remote travel costs 2 AP")
	assert_eq(ApServiceScript.commission_execution_cost(false, ""), 1, "commission without tower costs 1 AP")
	assert_eq(ApServiceScript.commission_execution_cost(true, "small"), 3, "commission with small tower stacks 1+2 AP")


func test_spend_ap_never_goes_negative_and_reports_shortage() -> void:
	var gs = _state()
	gs.ap = 2
	var short: Dictionary = ApServiceScript.try_spend(gs, 3, "unit")
	assert_true(not bool(short.get("ok", true)), "spend fails when AP is short")
	assert_eq(str(short.get("reason", "")), "ap_short", "short spend reports ap_short")
	assert_eq(int(gs.ap), 2, "failed spend does not mutate AP")
	var ok: Dictionary = ApServiceScript.try_spend(gs, 2, "unit")
	assert_true(bool(ok.get("ok", false)), "spend succeeds when AP is enough")
	assert_eq(int(gs.ap), 0, "successful spend deducts exact AP")


func test_game_state_ap_signal_emits_on_spend_and_refill() -> void:
	var gs = _state()
	_last_ap_signal.clear()
	gs.ap_changed.connect(_on_ap_changed)
	var result: Dictionary = ApServiceScript.try_spend(gs, 2, "signal_test")
	assert_true(bool(result.get("ok", false)), "spend through service succeeds")
	assert_eq(_last_ap_signal, [10, 12], "spend emits ap_changed with current/max")
	gs.refill_ap_to_max()
	assert_eq(_last_ap_signal, [12, 12], "refill emits ap_changed with current/max")


func test_budget_prevents_big_tower_meditation_forge_and_sleep_without_deficit() -> void:
	var gs = _state()
	gs.ap = 12
	assert_true(bool(ApServiceScript.try_spend_tower(gs, "large").get("ok", false)), "large tower spends 6 AP")
	assert_true(bool(ApServiceScript.try_spend_meditation(gs).get("ok", false)), "meditation spends 3 AP")
	assert_true(bool(ApServiceScript.try_spend_forge(gs, 4).get("ok", false)), "L forge spends 3 AP")
	assert_eq(int(gs.ap), 0, "large tower + meditation + L forge consumes all 12 AP")
	var sleep: Dictionary = ApServiceScript.spend_sleep_cost_or_deficit(gs)
	assert_eq(int(sleep.get("deficit", -1)), 3, "mandatory sleep records 3 AP deficit")
	assert_eq(int(gs.ap), 0, "sleep deficit keeps AP at zero instead of going negative")


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _on_ap_changed(current: int, maximum: int) -> void:
	_last_ap_signal = [current, maximum]


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
