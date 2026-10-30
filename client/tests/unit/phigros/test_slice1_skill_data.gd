extends RefCounted

const SKILLS_DIR := "res://data/skills/"
const EXPECTED_TOTAL := 66
const EXPECTED_POOL_COUNTS := {
	"fool_pathway": 22,
	"common": 6,
	"tower_pickup": 8,
	"enemy_spell": 30,
}
const FOOL_S9_S7_IDS := [
	"fool_s9_spirit_vision",
	"fool_s9_star_chart_divination",
	"fool_s9_pendulum_query",
	"fool_s9_ritual_chant",
	"fool_s9_arcane_lore",
	"fool_s9_premonition",
	"fool_s8_acrobat_strike",
	"fool_s8_paper_blade_volley",
	"fool_s8_microexpression_read",
	"fool_s8_predator_instinct",
	"fool_s8_strongman_burst",
	"fool_s7_wound_displacement",
	"fool_s7_flame_jump",
	"fool_s7_air_bullet",
	"fool_s7_paper_doll_substitute",
	"fool_s7_flame_command",
	"fool_s7_illusion_weave",
	"fool_s7_water_breath",
	"fool_s7_bone_softening",
	"fool_s7_paper_arsenal",
	"fool_s7_swift_cast",
	"fool_s7_minor_trick",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_slice1_skill_data.gd --")
	test_slice1_skill_file_count_is_66()
	test_slice1_pool_counts_match_r15()
	test_fool_sequence_9_to_7_canonical_ids_exist()
	test_all_slice1_skill_json_has_required_schema()
	return {"passed": _passed, "failed": _failed}


func test_slice1_skill_file_count_is_66() -> void:
	var files: Array[String] = _skill_files()
	assert_eq(files.size(), EXPECTED_TOTAL, "R15 §4首批 skill json count = 66")


func test_slice1_pool_counts_match_r15() -> void:
	var counts: Dictionary = {}
	for data in _all_skill_data():
		var pool: String = str(data.get("card_pool", ""))
		counts[pool] = int(counts.get(pool, 0)) + 1
	for pool in EXPECTED_POOL_COUNTS:
		assert_eq(int(counts.get(pool, 0)), int(EXPECTED_POOL_COUNTS[pool]), "R15 pool %s count" % pool)


func test_fool_sequence_9_to_7_canonical_ids_exist() -> void:
	var by_id: Dictionary = {}
	for data in _all_skill_data():
		by_id[str(data.get("id", ""))] = data
	for id in FOOL_S9_S7_IDS:
		assert_true(by_id.has(id), "design/cards/fool-pathway.md canonical id exists: %s" % id)
		if by_id.has(id):
			var data: Dictionary = by_id[id]
			assert_eq(str(data.get("pathway", "")), "fool", "%s pathway=fool" % id)
			assert_true(int(data.get("sequence", 0)) >= 7 and int(data.get("sequence", 0)) <= 9, "%s sequence 7-9" % id)


func test_all_slice1_skill_json_has_required_schema() -> void:
	for data in _all_skill_data():
		var id: String = str(data.get("id", ""))
		for key in ["id", "display_name", "pathway", "sequence", "tier", "element", "combat_effect", "description"]:
			assert_true(data.has(key), "%s has %s" % [id, key])
			if data.has(key) and key != "combat_effect":
				assert_true(str(data.get(key, "")) != "", "%s non-empty %s" % [id, key])
		var combat: Dictionary = data.get("combat_effect", {})
		for key in ["damage", "heal", "target", "range", "status_effects"]:
			assert_true(combat.has(key), "%s combat_effect.%s" % [id, key])
		if combat.has("status_effects"):
			assert_true(combat.get("status_effects", []) is Array, "%s status_effects is Array" % id)


func _skill_files() -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(SKILLS_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _all_skill_data() -> Array:
	var result: Array = []
	for fname in _skill_files():
		var text: String = FileAccess.get_file_as_string(SKILLS_DIR + fname)
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			result.append(parsed)
		else:
			assert_true(false, "%s parses as Dictionary" % fname)
	return result


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
