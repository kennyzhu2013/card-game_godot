extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const LOADER_PATH := "res://scripts/world/rumor_pool_loader.gd"
const EXPECTED_POOLS := {
	"shadow_alley_rumors": "res://data/rumors/shadow_alley_pool.json",
	"steelworks_tabloid": "res://data/rumors/steelworks_pool.json",
	"misty_port_rumors": "res://data/rumors/misty_port_pool.json",
	"sacred_seven_rumors": "res://data/rumors/sacred_seven_pool.json",
	"stone_tower_streets": "res://data/rumors/stone_tower_pool.json",
	"ascetic_mountain_rumors": "res://data/rumors/ascetic_mountain_pool.json",
	"tavern_pool": "res://data/rumors/tavern_pool.json",
	"teahouse_pool": "res://data/rumors/teahouse_pool.json",
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_rumor_pool_loader.gd --")
	test_required_rumor_pool_files_exist()
	test_loader_loads_50_plus_intel_entries()
	test_loader_filters_and_picks_pool_entries()
	return {"passed": _passed, "failed": _failed}


func test_required_rumor_pool_files_exist() -> void:
	for pool_id in EXPECTED_POOLS.keys():
		assert_true(FileAccess.file_exists(str(EXPECTED_POOLS[pool_id])), "%s file exists" % pool_id)
	assert_true(FileAccess.file_exists("res://data/rumors/templates.json"), "rumor fallback templates file exists")


func test_loader_loads_50_plus_intel_entries() -> void:
	var loader = _new_loader()
	if loader == null:
		return
	var result: Dictionary = loader.load_all()
	assert_true(bool(result.get("ok", false)), "RumorPoolLoader.load_all succeeds")
	assert_true(int(result.get("entry_count", 0)) >= 50, "R26 has at least 50 intel entries")
	for pool_id in EXPECTED_POOLS.keys():
		var pool: Dictionary = loader.load_pool(pool_id)
		assert_eq(str(pool.get("pool_id", "")), pool_id, "%s pool_id loads by structured id" % pool_id)
		assert_true(pool.get("entries", []) is Array and pool.get("entries", []).size() >= 3, "%s has at least three entries" % pool_id)


func test_loader_filters_and_picks_pool_entries() -> void:
	var loader = _new_loader()
	if loader == null:
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 4
	gs.time_of_day = "evening"
	gs.sequence = 9
	var picked: Array = loader.pick("shadow_alley_rumors", gs, 3, 17)
	assert_true(picked.size() >= 1 and picked.size() <= 3, "pick returns 1-3 filtered intels")
	for intel in picked:
		assert_true(intel is Dictionary, "picked intel is dictionary")
		if intel is Dictionary:
			assert_true(str(intel.get("id", "")).begins_with("intel_"), "picked intel uses structured intel id")
			assert_true(intel.get("apply_target", {}) is Dictionary, "picked intel carries apply_target")
	gs.queue_free()


func _new_loader():
	var script = load(LOADER_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "RumorPoolLoader script loads and can instantiate")
		return null
	var loader = script.new()
	assert_true(loader.has_method("load_all"), "RumorPoolLoader exposes load_all")
	assert_true(loader.has_method("load_pool"), "RumorPoolLoader exposes load_pool")
	assert_true(loader.has_method("pick"), "RumorPoolLoader exposes pick")
	if not loader.has_method("load_all") or not loader.has_method("load_pool") or not loader.has_method("pick"):
		return null
	return loader


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
