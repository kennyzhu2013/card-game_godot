extends RefCounted

const ExecuteDirector = preload("res://scripts/battle/phigros/stage/execute_director.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_execute_director.gd --")
	test_punish_segment_low_perfect_max_damage()
	test_punish_segment_mid_perfect()
	test_punish_segment_high_perfect_min_damage()
	test_challenge_segment_top_tier()
	test_challenge_segment_mid_tier()
	test_challenge_segment_low_tier_backfires()
	test_challenge_boundary_inclusive()
	return {"passed": _passed, "failed": _failed}


func test_punish_segment_low_perfect_max_damage() -> void:
	var ed = ExecuteDirector.new()
	var ratio: float = ed.punish_segment_damage_ratio(0, 12)
	assert_true(is_equal_approx(ratio, 0.25), "0% perfect -> 25% damage")


func test_punish_segment_mid_perfect() -> void:
	var ed = ExecuteDirector.new()
	var ratio: float = ed.punish_segment_damage_ratio(4, 12)
	assert_true(is_equal_approx(ratio, 0.15), "33% perfect -> 15% damage")


func test_punish_segment_high_perfect_min_damage() -> void:
	var ed = ExecuteDirector.new()
	var ratio: float = ed.punish_segment_damage_ratio(8, 12)
	assert_true(is_equal_approx(ratio, 0.05), "67% perfect -> 5% damage")


func test_challenge_segment_top_tier() -> void:
	var ed = ExecuteDirector.new()
	var dmg: Dictionary = ed.challenge_segment_damage(12, 12)
	assert_true(is_equal_approx(dmg.get("enemy_ratio", 0.0), 0.50), "100% perfect -> 50% enemy")
	assert_true(is_equal_approx(dmg.get("player_backfire_ratio", 0.0), 0.0), "no backfire")


func test_challenge_segment_mid_tier() -> void:
	var ed = ExecuteDirector.new()
	var dmg: Dictionary = ed.challenge_segment_damage(5, 12)
	assert_true(is_equal_approx(dmg.get("enemy_ratio", 0.0), 0.20), "42% perfect -> 20% enemy")


func test_challenge_segment_low_tier_backfires() -> void:
	var ed = ExecuteDirector.new()
	var dmg: Dictionary = ed.challenge_segment_damage(1, 12)
	assert_true(is_equal_approx(dmg.get("enemy_ratio", 0.0), 0.05), "8% perfect -> 5% enemy")
	assert_true(is_equal_approx(dmg.get("player_backfire_ratio", 0.0), 0.10), "low tier 10% backfire")


func test_challenge_boundary_inclusive() -> void:
	var ed = ExecuteDirector.new()
	var dmg: Dictionary = ed.challenge_segment_damage(8, 10)
	assert_true(is_equal_approx(dmg.get("enemy_ratio", 0.0), 0.50), "80% inclusive -> top tier")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s" % msg)
