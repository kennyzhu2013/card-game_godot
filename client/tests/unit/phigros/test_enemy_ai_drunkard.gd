extends RefCounted

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_enemy_ai_drunkard.gd --")
	test_drunkard_loads_from_json()
	test_drunkard_turn_0_uses_swing()
	test_drunkard_turn_1_defends()
	test_hp_threshold_condition_uses_strict_below()
	return {"passed": _passed, "failed": _failed}


func test_drunkard_loads_from_json() -> void:
	var LibraryScript = _load_script("res://scripts/combat/enemy_library.gd", "EnemyLibrary script loads")
	if LibraryScript == null:
		return
	var library = LibraryScript.new()
	library.load_enemy("drunkard")
	var drunkard = library.get_enemy("drunkard")
	assert_true(drunkard != null, "drunkard exists")
	if drunkard != null:
		assert_eq(drunkard.id, "drunkard", "drunkard id")
		assert_eq(drunkard.display_name, "醉汉", "drunkard display_name")
		assert_eq(drunkard.hp, 30, "drunkard hp")
		assert_eq(drunkard.atk, 10, "drunkard atk")
		assert_eq(drunkard.def, 2, "drunkard def")
		assert_eq(drunkard.spd, 8, "drunkard spd")


func test_drunkard_turn_0_uses_swing() -> void:
	var LibraryScript = _load_script("res://scripts/combat/enemy_library.gd", "EnemyLibrary script loads")
	var AiScript = _load_script("res://scripts/combat/enemy_ai.gd", "EnemyAi script loads")
	if LibraryScript == null or AiScript == null:
		return
	var drunkard = _load_drunkard(LibraryScript)
	var action: Dictionary = AiScript.decide_action(drunkard, 0)
	assert_eq(action.get("action"), "use_skill", "turn 0 action is use_skill")
	assert_eq(action.get("skill"), "drunken_swing", "turn 0 skill is drunken_swing")


func test_drunkard_turn_1_defends() -> void:
	var LibraryScript = _load_script("res://scripts/combat/enemy_library.gd", "EnemyLibrary script loads")
	var AiScript = _load_script("res://scripts/combat/enemy_ai.gd", "EnemyAi script loads")
	if LibraryScript == null or AiScript == null:
		return
	var drunkard = _load_drunkard(LibraryScript)
	var action: Dictionary = AiScript.decide_action(drunkard, 1)
	assert_eq(action.get("action"), "defend", "turn 1 action is defend")
	assert_eq(action.get("params").get("damage_reduction"), 0.5, "turn 1 defend reduction")


func test_hp_threshold_condition_uses_strict_below() -> void:
	var EnemyScript = _load_script("res://scripts/combat/enemy.gd", "Enemy script loads")
	var AiScript = _load_script("res://scripts/combat/enemy_ai.gd", "EnemyAi script loads")
	if EnemyScript == null or AiScript == null:
		return
	var enemy = EnemyScript.new()
	enemy.max_hp = 100
	enemy.hp = 30
	assert_true(not AiScript._eval_condition("hp_below_30_percent", enemy, 0), "30 percent is not below 30 percent")
	enemy.hp = 29
	assert_true(AiScript._eval_condition("hp_below_30_percent", enemy, 0), "29 percent is below 30 percent")


func _load_drunkard(LibraryScript):
	var library = LibraryScript.new()
	library.load_enemy("drunkard")
	return library.get_enemy("drunkard")


func _load_script(path: String, message: String):
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, message)
		return null
	assert_true(true, message)
	return script


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
		return
	_failed += 1
	print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
