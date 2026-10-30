extends RefCounted

const GlyphArrangementScript = preload("res://scripts/ritual/glyph_arrangement.gd")
const SkillLibraryScript = preload("res://scripts/combat/skill_library.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_forge_result_calculator.gd --")
	test_perfect_rate_95_yields_quality_5()
	test_perfect_rate_50_yields_quality_2()
	test_perfect_rate_0_yields_quality_1()
	test_quality_5_multiplies_shadow_arrow_damage_to_18()
	test_quality_1_multiplies_shadow_arrow_damage_to_6()
	test_unknown_reaction_generates_card()
	test_water_touch_quality_5_heals_18()
	test_forge_builds_card_next_to_legacy_skill()
	test_forged_card_ids_are_unique()
	test_fog_fool_forge_material_output_is_twenty_percent_higher()
	return {"passed": _passed, "failed": _failed}


func test_perfect_rate_95_yields_quality_5() -> void:
	var calculator = _load_calculator()
	if calculator == null:
		return
	var quality: Dictionary = calculator.evaluate_quality(0.95)
	assert_eq(quality.get("id", 0), 5, "0.95 perfect rate yields quality 5")
	assert_eq(quality.get("stars", 0), 5, "quality 5 has 5 stars")


func test_perfect_rate_50_yields_quality_2() -> void:
	var calculator = _load_calculator()
	if calculator == null:
		return
	var quality: Dictionary = calculator.evaluate_quality(0.50)
	assert_eq(quality.get("id", 0), 2, "0.50 perfect rate yields quality 2")
	assert_eq(quality.get("stars", 0), 2, "quality 2 has 2 stars")


func test_perfect_rate_0_yields_quality_1() -> void:
	var calculator = _load_calculator()
	if calculator == null:
		return
	var quality: Dictionary = calculator.evaluate_quality(0.0)
	assert_eq(quality.get("id", 0), 1, "0 perfect rate yields quality 1")
	assert_eq(quality.get("stars", 0), 1, "quality 1 has 1 star")


func test_quality_5_multiplies_shadow_arrow_damage_to_18() -> void:
	var result := _forge("shadow_arrow", 0.95)
	var forged = result.get("forged_skill", null)
	assert_true(forged != null, "shadow_arrow quality 5 creates forged skill")
	if forged == null:
		return
	assert_eq(forged.damage, 18, "quality 5 shadow_arrow damage")
	assert_eq(forged.tier, 5, "quality 5 sets forged tier")
	assert_eq(result.get("multiplier", 0.0), 1.5, "quality 5 multiplier")


func test_quality_1_multiplies_shadow_arrow_damage_to_6() -> void:
	var result := _forge("shadow_arrow", 0.0)
	var forged = result.get("forged_skill", null)
	assert_true(forged != null, "shadow_arrow quality 1 creates forged skill")
	if forged == null:
		return
	assert_eq(forged.damage, 6, "quality 1 shadow_arrow damage")
	assert_eq(forged.tier, 1, "quality 1 sets forged tier")
	assert_eq(result.get("multiplier", 0.0), 0.5, "quality 1 multiplier")


func test_unknown_reaction_generates_card() -> void:
	var calculator = _load_calculator()
	if calculator == null:
		return
	var arrangement = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	var result: Dictionary = calculator.forge("unknown_reaction", 0.95, arrangement, _new_library())
	assert_eq(result.get("multiplier", -1), 1.5, "unknown reaction uses quality 5 multiplier")
	assert_true(result.get("base_skill", "missing") == null, "unknown reaction base_skill null")
	assert_true(result.get("forged_skill", "missing") == null, "unknown reaction forged_skill null")
	assert_true(result.get("forged_card", null) != null, "unknown reaction generates generic card")
	assert_true(result.get("source_arrangement", null) == arrangement, "unknown reaction keeps arrangement")


func test_water_touch_quality_5_heals_18() -> void:
	var result := _forge("water_touch", 0.95)
	var forged = result.get("forged_skill", null)
	assert_true(forged != null, "water_touch quality 5 creates forged skill")
	if forged == null:
		return
	assert_eq(forged.heal, 18, "quality 5 water_touch heal")
	assert_eq(forged.damage, 0, "quality 5 water_touch damage remains 0")
	assert_eq(forged.tier, 5, "quality 5 water_touch tier")


func test_forge_builds_card_next_to_legacy_skill() -> void:
	var result := _forge("shadow_arrow", 0.95)
	var forged = result.get("forged_skill", null)
	var card = result.get("forged_card", null)
	assert_true(forged != null, "legacy forged_skill still exists")
	assert_true(card != null, "forge also creates forged_card")
	if card == null:
		return
	assert_eq(card.template_id, "shadow_arrow", "card template_id from reaction skill")
	assert_true(card.id.begins_with("shadow_arrow_"), "card id has template prefix")
	assert_eq(card.quality, 5, "card quality from Phigros rating")
	assert_eq(card.damage, 18, "card damage uses quality multiplier")
	assert_eq(card.brand_slots, 6, "quality 5 card brand_slots = quality + 1")


func test_forged_card_ids_are_unique() -> void:
	var first = _forge("shadow_arrow", 0.95).get("forged_card", null)
	var second = _forge("shadow_arrow", 0.95).get("forged_card", null)
	assert_true(first != null, "first forged card exists")
	assert_true(second != null, "second forged card exists")
	if first == null or second == null:
		return
	assert_true(first.id != second.id, "two forged cards from same template get unique ids")


func test_fog_fool_forge_material_output_is_twenty_percent_higher() -> void:
	var sunny_state = _state("sunny")
	var fog_state = _state("fog")
	var sunny: Dictionary = _forge_with_state("shadow_arrow", 0.95, sunny_state)
	var fog: Dictionary = _forge_with_state("shadow_arrow", 0.95, fog_state)
	var material_id := "愚者残页"
	var sunny_outputs: Dictionary = sunny.get("material_outputs", {})
	var fog_outputs: Dictionary = fog.get("material_outputs", {})
	assert_eq(int(sunny_outputs.get(material_id, 0)), 5, "sunny perfect forge outputs 5 material units")
	assert_eq(int(fog_outputs.get(material_id, 0)), 6, "fog fool perfect forge outputs 6 material units")
	assert_eq(int(fog.get("forge_weather_bonus_percent", 0)), 20, "fog fool forge result reports 20 percent bonus")


func _forge(reaction_id: String, perfect_rate: float) -> Dictionary:
	var calculator = _load_calculator()
	if calculator == null:
		return {}
	var arrangement = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	return calculator.forge(reaction_id, perfect_rate, arrangement, _new_library())


func _forge_with_state(reaction_id: String, perfect_rate: float, game_state) -> Dictionary:
	var calculator = _load_calculator()
	if calculator == null:
		return {}
	var arrangement = GlyphArrangementScript.new(6, GlyphArrangementScript.SHAPE_HEX)
	return calculator.forge(reaction_id, perfect_rate, arrangement, _new_library(), game_state)


func _state(weather_id: String):
	var gs = GameStateScript.new()
	gs._ready()
	gs.current_weather = weather_id
	gs.pathway = "fool"
	return gs


func _new_library():
	var library = SkillLibraryScript.new()
	library._load_all()
	return library


func _load_calculator():
	var script = load("res://scripts/ritual/forge_result_calculator.gd")
	if script == null or not script.can_instantiate():
		assert_true(false, "ForgeResultCalculator script loads")
		return null
	assert_true(true, "ForgeResultCalculator script loads")
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
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
