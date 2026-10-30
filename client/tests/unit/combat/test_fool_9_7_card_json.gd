extends RefCounted

const EffectEngineScript = preload("res://scripts/combat/effect_engine.gd")

const SKILLS_DIR := "res://data/skills/"
const CARD_TYPE_TAGS := ["attack", "skill", "status"]
const EXPECTED_CARDS := {
	"fool_s9_spirit_vision": {"sequence": 9, "tier": 1, "type_tag": "skill"},
	"fool_s9_star_chart_divination": {"sequence": 9, "tier": 1, "type_tag": "skill"},
	"fool_s9_pendulum_query": {"sequence": 9, "tier": 1, "type_tag": "skill"},
	"fool_s9_ritual_chant": {"sequence": 9, "tier": 1, "type_tag": "skill"},
	"fool_s9_arcane_lore": {"sequence": 9, "tier": 1, "type_tag": "skill"},
	"fool_s9_premonition": {"sequence": 9, "tier": 1, "type_tag": "status"},
	"fool_s8_acrobat_strike": {"sequence": 8, "tier": 2, "type_tag": "attack"},
	"fool_s8_paper_blade_volley": {"sequence": 8, "tier": 2, "type_tag": "attack"},
	"fool_s8_microexpression_read": {"sequence": 8, "tier": 2, "type_tag": "skill"},
	"fool_s8_predator_instinct": {"sequence": 8, "tier": 2, "type_tag": "status"},
	"fool_s8_strongman_burst": {"sequence": 8, "tier": 2, "type_tag": "attack"},
	"fool_s7_wound_displacement": {"sequence": 7, "tier": 3, "type_tag": "skill"},
	"fool_s7_flame_jump": {"sequence": 7, "tier": 3, "type_tag": "skill"},
	"fool_s7_air_bullet": {"sequence": 7, "tier": 3, "type_tag": "attack"},
	"fool_s7_paper_doll_substitute": {"sequence": 7, "tier": 3, "type_tag": "status"},
	"fool_s7_flame_command": {"sequence": 7, "tier": 3, "type_tag": "skill"},
	"fool_s7_illusion_weave": {"sequence": 7, "tier": 3, "type_tag": "skill"},
	"fool_s7_water_breath": {"sequence": 7, "tier": 3, "type_tag": "status"},
	"fool_s7_bone_softening": {"sequence": 7, "tier": 3, "type_tag": "skill"},
	"fool_s7_paper_arsenal": {"sequence": 7, "tier": 3, "type_tag": "attack"},
	"fool_s7_swift_cast": {"sequence": 7, "tier": 3, "type_tag": "skill"},
	"fool_s7_minor_trick": {"sequence": 7, "tier": 3, "type_tag": "skill"},
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_fool_9_7_card_json.gd --")
	test_all_22_cards_exist_with_design_sequence_and_type_tags()
	test_all_status_effect_ids_are_registered_r28_ids()
	test_supported_r28_payloads_match_design_translation()
	return {"passed": _passed, "failed": _failed}


func test_all_22_cards_exist_with_design_sequence_and_type_tags() -> void:
	for card_id in EXPECTED_CARDS.keys():
		var data := _load_card_data(card_id)
		if data.is_empty():
			continue
		var expected: Dictionary = EXPECTED_CARDS[card_id]
		assert_eq(str(data.get("pathway", "")), "fool", "%s pathway=fool" % card_id)
		assert_eq(str(data.get("card_pool", "")), "fool_pathway", "%s card_pool=fool_pathway" % card_id)
		assert_eq(int(data.get("sequence", -1)), int(expected.get("sequence", -1)), "%s design sequence" % card_id)
		assert_eq(int(data.get("tier", -1)), int(expected.get("tier", -1)), "%s tier follows sequence" % card_id)
		var tags: Array = _string_array(data.get("tags", []))
		var expected_type := str(expected.get("type_tag", ""))
		assert_true(expected_type in tags, "%s carries structured card type tag %s" % [card_id, expected_type])
		assert_eq(_card_type_tag_count(tags), 1, "%s carries exactly one card type tag" % card_id)


func test_all_status_effect_ids_are_registered_r28_ids() -> void:
	for card_id in EXPECTED_CARDS.keys():
		var data := _load_card_data(card_id)
		if data.is_empty():
			continue
		_assert_effects_registered(card_id, _effects(data))
		for effect in _effects(data):
			if not effect is Dictionary:
				continue
			if str(effect.get("id", "")) == "create_random_temp_card":
				for option in effect.get("options", []):
					assert_true(option is Dictionary, "%s create_random_temp_card option is Dictionary" % card_id)
					if option is Dictionary:
						_assert_effects_registered("%s option %s" % [card_id, str(option.get("id", ""))], _effects(option))


func test_supported_r28_payloads_match_design_translation() -> void:
	var ritual := _load_card_data("fool_s9_ritual_chant")
	var ritual_effects := _effects(ritual)
	assert_eq(_effect_ids(ritual_effects), ["charge"], "ritual chant charges instead of applying payload immediately")
	var charge := _effect_by_id(ritual_effects, "charge")
	assert_eq(int(charge.get("magnitude", charge.get("duration", 0))), 2, "ritual chant charge lasts 2 rounds")
	assert_eq(_effect_ids(charge.get("payload", [])), ["weak", "vulnerable", "confusion"], "ritual chant charge payload matches design")

	_assert_draw_filter_payload("fool_s9_star_chart_divination")
	_assert_draw_filter_payload("fool_s9_arcane_lore")
	_assert_block_break_payload("fool_s8_strongman_burst")

	var flame_jump := _load_card_data("fool_s7_flame_jump")
	assert_eq(int(_combat(flame_jump).get("damage", -1)), 0, "flame jump damage comes from teleport_to_flame direct effect")
	assert_true(_effect_by_id(_effects(flame_jump), "teleport_to_flame").has("id"), "flame jump uses teleport_to_flame")
	assert_true(_effect_by_id(_effects(flame_jump), "cost_zero_if_flame_stream").has("id"), "flame jump keeps flame stream discount")
	assert_true(not _effect_by_id(_effects(flame_jump), "consume_flame_marker").has("id"), "flame jump does not double-consume flame markers")

	var flame_command := _load_card_data("fool_s7_flame_command")
	assert_eq(int(_effect_by_id(_effects(flame_command), "create_or_move_flame_markers").get("magnitude", 0)), 2, "flame command creates two flame markers")
	assert_eq(int(_effect_by_id(_effects(flame_command), "adjacent_burn").get("magnitude", 0)), 3, "flame command adjacent burn magnitude")

	var paper_arsenal := _load_card_data("fool_s7_paper_arsenal")
	assert_eq(int(_effect_by_id(_effects(paper_arsenal), "bonus_if_attack").get("magnitude", 0)), 6, "paper arsenal attack discard grants +6 damage")
	assert_eq(int(_effect_by_id(_effects(paper_arsenal), "vulnerable_if_skill").get("duration", 0)), 2, "paper arsenal skill discard applies vulnerable 2")
	assert_eq(int(_effect_by_id(_effects(paper_arsenal), "weak_if_status").get("duration", 0)), 2, "paper arsenal status discard applies weak 2")

	var minor_trick := _load_card_data("fool_s7_minor_trick")
	var temp_effect := _effect_by_id(_effects(minor_trick), "create_random_temp_card")
	assert_eq(_dictionary_option_count(temp_effect.get("options", [])), 4, "minor trick has four structured temp-card options")


func _load_card_data(card_id: String) -> Dictionary:
	var path := "%s%s.json" % [SKILLS_DIR, card_id]
	if not FileAccess.file_exists(path):
		assert_true(false, "%s JSON exists" % card_id)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		assert_true(false, "%s parses as Dictionary" % card_id)
		return {}
	return parsed


func _combat(data: Dictionary) -> Dictionary:
	var combat = data.get("combat_effect", {})
	if combat is Dictionary:
		return combat
	return {}


func _effects(data: Dictionary) -> Array:
	var effects = _combat(data).get("status_effects", [])
	if effects is Array:
		return effects
	return []


func _effect_ids(effects: Array) -> Array:
	var result: Array = []
	for effect in effects:
		if effect is Dictionary:
			result.append(str(effect.get("id", "")))
	return result


func _effect_by_id(effects: Array, id: String) -> Dictionary:
	for effect in effects:
		if effect is Dictionary and str(effect.get("id", "")) == id:
			return effect
	return {}


func _assert_effects_registered(context: String, effects: Array) -> void:
	for effect in effects:
		if not effect is Dictionary:
			assert_true(false, "%s effect entry is Dictionary" % context)
			continue
		var effect_id := str(effect.get("id", ""))
		assert_true(EffectEngineScript.HANDLERS.has(effect_id), "%s effect_id is registered R28 id: %s" % [context, effect_id])
		if effect.has("payload"):
			var payload = effect.get("payload", [])
			assert_true(payload is Array, "%s %s payload is Array" % [context, effect_id])
			if payload is Array:
				_assert_effects_registered("%s %s payload" % [context, effect_id], payload)


func _assert_draw_filter_payload(card_id: String) -> void:
	var data := _load_card_data(card_id)
	var effect := _effect_by_id(_effects(data), "draw_filter")
	assert_true(effect.has("id"), "%s mounts draw_filter as a combat effect" % card_id)
	assert_eq(int(effect.get("peek", 0)), 3, "%s draw_filter peeks three top cards" % card_id)
	assert_eq(int(effect.get("choose", 0)), 1, "%s draw_filter chooses one card" % card_id)
	assert_eq(str(effect.get("rest_policy", "")), "return_top", "%s draw_filter returns unchosen cards to the top" % card_id)


func _assert_block_break_payload(card_id: String) -> void:
	var data := _load_card_data(card_id)
	var effect := _effect_by_id(_effects(data), "block_break")
	assert_true(effect.has("id"), "%s mounts block_break as a combat effect" % card_id)
	assert_eq(int(effect.get("magnitude", 0)), 3, "%s block_break shreds three defense" % card_id)


func _dictionary_option_count(options: Variant) -> int:
	var count := 0
	if options is Array:
		for option in options:
			if option is Dictionary:
				count += 1
	return count


func _card_type_tag_count(tags: Array) -> int:
	var count := 0
	for tag in tags:
		if str(tag) in CARD_TYPE_TAGS:
			count += 1
	return count


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			result.append(str(item))
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
