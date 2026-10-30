extends RefCounted

const SkillScript = preload("res://scripts/combat/skill.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_skill_library.gd --")
	test_load_all_5_skills()
	test_shadow_arrow_damage_12()
	test_water_touch_is_heal_not_damage()
	test_shadow_jester_has_social_effect()
	test_skill_to_dict_roundtrip()
	return {"passed": _passed, "failed": _failed}


func test_load_all_5_skills() -> void:
	var LibraryScript = _load_script("res://scripts/combat/skill_library.gd", "SkillLibrary script loads")
	if LibraryScript == null:
		return
	var library = LibraryScript.new()
	library._load_all()
	assert_eq(library.all_skills().size(), 66, "loads all 66 Slice 1 skill json files")


func test_shadow_arrow_damage_12() -> void:
	var LibraryScript = _load_script("res://scripts/combat/skill_library.gd", "SkillLibrary script loads")
	if LibraryScript == null:
		return
	var library = LibraryScript.new()
	library._load_all()
	var skill = library.get_skill("shadow_arrow")
	assert_true(skill != null, "shadow_arrow exists")
	if skill != null:
		assert_eq(skill.damage, 12, "shadow_arrow damage is 12")
		assert_eq(skill.element, "影", "shadow_arrow element is 影")


func test_water_touch_is_heal_not_damage() -> void:
	var LibraryScript = _load_script("res://scripts/combat/skill_library.gd", "SkillLibrary script loads")
	if LibraryScript == null:
		return
	var library = LibraryScript.new()
	library._load_all()
	var skill = library.get_skill("water_touch")
	assert_true(skill != null, "water_touch exists")
	if skill != null:
		assert_eq(skill.damage, 0, "water_touch damage is 0")
		assert_eq(skill.heal, 12, "water_touch heal is 12")
		assert_eq(skill.target, "self", "water_touch target is self")


func test_shadow_jester_has_social_effect() -> void:
	var LibraryScript = _load_script("res://scripts/combat/skill_library.gd", "SkillLibrary script loads")
	if LibraryScript == null:
		return
	var library = LibraryScript.new()
	library._load_all()
	var skill = library.get_skill("shadow_jester")
	assert_true(skill != null, "shadow_jester exists")
	if skill != null:
		assert_true(skill.social_effect.has("type"), "shadow_jester social_effect has type")
		assert_eq(skill.social_effect.get("type"), "identity_mask", "shadow_jester social_effect type")


func test_skill_to_dict_roundtrip() -> void:
	var LibraryScript = _load_script("res://scripts/combat/skill_library.gd", "SkillLibrary script loads")
	if LibraryScript == null:
		return
	var library = LibraryScript.new()
	library._load_all()
	var skill = library.get_skill("shadow_arrow")
	assert_true(skill != null, "shadow_arrow exists for to_dict roundtrip")
	if skill == null:
		return
	if not skill.has_method("to_dict"):
		assert_true(false, "Skill exposes to_dict")
		return
	var data: Dictionary = skill.to_dict()
	var copy = SkillScript.from_json(data)
	assert_eq(copy.id, skill.id, "roundtrip id")
	assert_eq(copy.display_name, skill.display_name, "roundtrip display_name")
	assert_eq(copy.damage, skill.damage, "roundtrip damage")
	assert_eq(copy.heal, skill.heal, "roundtrip heal")
	assert_eq(copy.target, skill.target, "roundtrip target")
	assert_eq(copy.range, skill.range, "roundtrip range")
	assert_eq(Array(copy.required_symbols), Array(skill.required_symbols), "roundtrip required_symbols")
	assert_eq(copy.social_effect, skill.social_effect, "roundtrip social_effect")
	assert_eq(copy.world_effect, skill.world_effect, "roundtrip world_effect")


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
