extends RefCounted

const ForgeResultCalculatorScript = preload("res://scripts/ritual/forge_result_calculator.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_reforge_brand.gd --")
	test_default_reforge_destroys_old_card_brands()
	test_keep_reforge_moves_brands_and_costs_150_percent()
	test_keep_and_slot_reforge_updates_brand_slots_and_costs_200_percent()
	test_unique_brand_grants_one_free_keep_and_slot_reforge()
	return {"passed": _passed, "failed": _failed}


func test_default_reforge_destroys_old_card_brands() -> void:
	var gs = _new_state_with_materials(10)
	var old_card = _card("old_default", 3, ["forge_residue_low"], 0)
	var new_card = _card("new_default", 3, [], 0)
	var result: Dictionary = ForgeResultCalculatorScript.reforge_card(old_card, new_card, "default", gs, false)
	assert_true(result.get("ok", false), "default reforge succeeds")
	assert_eq(old_card.brands, [], "default reforge clears old card brands")
	assert_eq(new_card.brands, [], "default reforge leaves new card brands empty")
	assert_eq(int(gs.forge_materials.get("愚者残页", 0)), 8, "default reforge consumes standard cost 2")


func test_keep_reforge_moves_brands_and_costs_150_percent() -> void:
	var gs = _new_state_with_materials(10)
	var old_card = _card("old_keep", 4, ["forge_residue_low", "forge_residue_mid"], 0)
	var new_card = _card("new_keep", 4, [], 0)
	var result: Dictionary = ForgeResultCalculatorScript.reforge_card(old_card, new_card, "keep_brands", gs, false)
	assert_true(result.get("ok", false), "keep-brands reforge succeeds for 4-star card")
	assert_eq(old_card.brands, [], "keep-brands reforge clears old card brands after moving")
	assert_eq(new_card.brands, ["forge_residue_low", "forge_residue_mid"], "keep-brands reforge moves brands to new card")
	assert_eq(int(gs.forge_materials.get("愚者残页", 0)), 7, "keep-brands reforge consumes standard * 1.5 = 3")


func test_keep_and_slot_reforge_updates_brand_slots_and_costs_200_percent() -> void:
	var gs = _new_state_with_materials(10)
	var old_card = _card("old_slot", 5, ["forge_residue_high"], 0)
	var new_card = _card("new_slot", 5, [], 2)
	var result: Dictionary = ForgeResultCalculatorScript.reforge_card(old_card, new_card, "keep_brands_new_slot", gs, true)
	assert_true(result.get("ok", false), "keep+slot reforge succeeds for 5-star perfect forge")
	assert_eq(new_card.brands, ["forge_residue_high"], "keep+slot reforge moves brands to new card")
	assert_eq(new_card.brand_slots, 8, "keep+slot sets brand_slots = quality + 1 + upgrade_level")
	assert_eq(int(gs.forge_materials.get("愚者残页", 0)), 6, "keep+slot reforge consumes standard * 2.0 = 4")


func test_unique_brand_grants_one_free_keep_and_slot_reforge() -> void:
	var gs = _new_state_with_materials(10)
	var old_card = _card("old_unique", 5, ["forge_residue_unique"], 0)
	var new_card = _card("new_unique", 5, [], 1)
	var result: Dictionary = ForgeResultCalculatorScript.reforge_card(old_card, new_card, "keep_brands_new_slot", gs, true)
	assert_true(result.get("ok", false), "unique brand keep+slot reforge succeeds")
	assert_eq(new_card.brands, ["forge_residue_unique"], "unique brand moves to new card")
	assert_eq(new_card.brand_slots, 7, "unique free reforge still opens new slot formula")
	assert_eq(int(gs.forge_materials.get("愚者残页", 0)), 10, "unique brand first keep+slot reforge consumes 0 materials")
	assert_true(gs.forge_unique_reforge_used, "unique free reforge sets weekly usage flag")


func _new_state_with_materials(amount: int):
	var gs = GameStateScript.new()
	gs._ready()
	gs.forge_materials["愚者残页"] = amount
	return gs


func _card(id: String, quality: int, brands: Array[String], upgrade_level: int):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"quality": quality,
		"brands": brands,
		"upgrade_level": upgrade_level,
	})


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
