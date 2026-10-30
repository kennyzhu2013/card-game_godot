extends RefCounted

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_damage_formula.gd --")
	test_element_multiplier_shadow_vs_faith()
	test_element_multiplier_faith_vs_radiance()
	test_damage_formula_perfect_qte()
	test_damage_floor_is_1()
	return {"passed": _passed, "failed": _failed}


func test_element_multiplier_shadow_vs_faith() -> void:
	var TableScript = _load_script("res://scripts/combat/element_table.gd", "ElementTable script loads")
	if TableScript == null:
		return
	var table = TableScript.new()
	table.load_table()
	assert_eq_float(table.multiplier("影", "信"), 2.0, "影 vs 信 multiplier is 2.0")


func test_element_multiplier_faith_vs_radiance() -> void:
	var TableScript = _load_script("res://scripts/combat/element_table.gd", "ElementTable script loads")
	if TableScript == null:
		return
	var table = TableScript.new()
	table.load_table()
	assert_eq_float(table.multiplier("信", "明"), 0.5, "信 vs 明 multiplier is 0.5")


func test_damage_formula_perfect_qte() -> void:
	var SkillScript = _load_script("res://scripts/combat/skill.gd", "Skill script loads")
	var ActorScript = _load_script("res://scripts/combat/combat_actor.gd", "CombatActor script loads")
	var EnemyScript = _load_script("res://scripts/combat/enemy.gd", "Enemy script loads")
	var TableScript = _load_script("res://scripts/combat/element_table.gd", "ElementTable script loads")
	var ExecutorScript = _load_script("res://scripts/combat/skill_executor.gd", "SkillExecutor script loads")
	if SkillScript == null or ActorScript == null or EnemyScript == null or TableScript == null or ExecutorScript == null:
		return
	var skill = SkillScript.from_json({
		"id": "shadow_arrow",
		"element": "影",
		"combat_effect": {"damage": 12},
	})
	var attacker = ActorScript.new()
	attacker.crit_rate = 0.0
	var defender = EnemyScript.new()
	defender.element = "信"
	defender.def = 2
	var table = TableScript.new()
	table.load_table()
	assert_eq(ExecutorScript.calculate_damage(skill, attacker, defender, 1.5, table), 34, "perfect qte damage formula")


func test_damage_floor_is_1() -> void:
	var SkillScript = _load_script("res://scripts/combat/skill.gd", "Skill script loads")
	var ActorScript = _load_script("res://scripts/combat/combat_actor.gd", "CombatActor script loads")
	var EnemyScript = _load_script("res://scripts/combat/enemy.gd", "Enemy script loads")
	var TableScript = _load_script("res://scripts/combat/element_table.gd", "ElementTable script loads")
	var ExecutorScript = _load_script("res://scripts/combat/skill_executor.gd", "SkillExecutor script loads")
	if SkillScript == null or ActorScript == null or EnemyScript == null or TableScript == null or ExecutorScript == null:
		return
	var skill = SkillScript.from_json({
		"id": "weak_hit",
		"element": "普通",
		"combat_effect": {"damage": 1},
	})
	var attacker = ActorScript.new()
	attacker.crit_rate = 0.0
	var defender = EnemyScript.new()
	defender.element = "普通"
	defender.def = 99
	var table = TableScript.new()
	table.load_table()
	assert_eq(ExecutorScript.calculate_damage(skill, attacker, defender, 0.5, table), 1, "damage floor is 1")


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


func assert_eq_float(actual: Variant, expected: float, message: String) -> void:
	if is_equal_approx(float(actual), expected):
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
