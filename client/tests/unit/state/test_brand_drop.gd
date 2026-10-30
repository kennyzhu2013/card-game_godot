extends RefCounted

const ForgeResultCalculatorScript = preload("res://scripts/ritual/forge_result_calculator.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")
const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_brand_drop.gd --")
	test_brand_json_files_exist()
	test_four_star_drop_chance_is_five_percent()
	test_five_star_drop_chance_is_ten_percent()
	test_four_star_pool_only_low()
	test_five_star_full_pool_weights()
	test_high_weight_requires_98_percent_perfect()
	test_mid_weight_requires_all_two_star_dao_answers()
	test_unique_weight_blocked_after_same_cycle_claim()
	test_resolve_drop_appends_brand_and_discovers_id()
	return {"passed": _passed, "failed": _failed}


func test_brand_json_files_exist() -> void:
	for brand_id in ["forge_residue_low", "forge_residue_mid", "forge_residue_high", "forge_residue_unique"]:
		var brand = BrandCatalogScript.create_brand(brand_id)
		assert_true(brand != null, "%s exists in MVP brand catalog" % brand_id)


func test_four_star_drop_chance_is_five_percent() -> void:
	assert_eq(ForgeResultCalculatorScript.brand_drop_chance(4), 0.05, "4-star brand drop chance = 0.05")
	assert_true(ForgeResultCalculatorScript.should_drop_brand(4, 0.049), "4-star roll below 0.05 drops")
	assert_true(not ForgeResultCalculatorScript.should_drop_brand(4, 0.05), "4-star roll at 0.05 does not drop")


func test_five_star_drop_chance_is_ten_percent() -> void:
	assert_eq(ForgeResultCalculatorScript.brand_drop_chance(5), 0.10, "5-star brand drop chance = 0.10")
	assert_true(ForgeResultCalculatorScript.should_drop_brand(5, 0.099), "5-star roll below 0.10 drops")
	assert_true(not ForgeResultCalculatorScript.should_drop_brand(5, 0.10), "5-star roll at 0.10 does not drop")


func test_four_star_pool_only_low() -> void:
	var weights: Dictionary = ForgeResultCalculatorScript.eligible_forge_brand_weights(4, 0.97, ["★★"], _new_state())
	assert_eq(int(weights.get("forge_residue_low", -1)), 100, "4-star pool low weight = 100")
	assert_eq(int(weights.get("forge_residue_mid", -1)), 0, "4-star pool mid weight = 0")
	assert_eq(int(weights.get("forge_residue_high", -1)), 0, "4-star pool high weight = 0")
	assert_eq(int(weights.get("forge_residue_unique", -1)), 0, "4-star pool unique weight = 0")


func test_five_star_full_pool_weights() -> void:
	var weights: Dictionary = ForgeResultCalculatorScript.eligible_forge_brand_weights(5, 0.99, ["★★", "★★"], _new_state())
	assert_eq(int(weights.get("forge_residue_low", -1)), 60, "5-star full pool low weight = 60")
	assert_eq(int(weights.get("forge_residue_mid", -1)), 25, "5-star full pool mid weight = 25")
	assert_eq(int(weights.get("forge_residue_high", -1)), 12, "5-star full pool high weight = 12")
	assert_eq(int(weights.get("forge_residue_unique", -1)), 3, "5-star full pool unique weight = 3")


func test_high_weight_requires_98_percent_perfect() -> void:
	var weights: Dictionary = ForgeResultCalculatorScript.eligible_forge_brand_weights(5, 0.979, ["★★", "★★"], _new_state())
	assert_eq(int(weights.get("forge_residue_high", -1)), 0, "perfect_rate below 98 disables high weight")


func test_mid_weight_requires_all_two_star_dao_answers() -> void:
	var weights: Dictionary = ForgeResultCalculatorScript.eligible_forge_brand_weights(5, 0.99, ["★★", "★"], _new_state())
	assert_eq(int(weights.get("forge_residue_mid", -1)), 0, "non-all-two-star dao choices disable mid weight")


func test_unique_weight_blocked_after_same_cycle_claim() -> void:
	var gs = _new_state()
	gs.brands_inventory.append(BrandScript.from_dict({"id": "forge_residue_unique"}))
	var weights: Dictionary = ForgeResultCalculatorScript.eligible_forge_brand_weights(5, 0.99, ["★★", "★★"], gs)
	assert_eq(int(weights.get("forge_residue_unique", -1)), 0, "owned unique brand disables unique weight")


func test_resolve_drop_appends_brand_and_discovers_id() -> void:
	var gs = _new_state()
	var brand = ForgeResultCalculatorScript.resolve_forge_brand_drop(4, 0.95, [], gs, 0.01, 0.0)
	assert_true(brand != null, "4-star successful roll creates a brand")
	if brand == null:
		return
	assert_eq(brand.id, "forge_residue_low", "4-star drop grants low brand")
	assert_eq(gs.brands_inventory.size(), 1, "brand appended to inventory")
	assert_true("forge_residue_low" in gs.daodian["discovered_brands"], "brand id added to daodian discoveries")


func _new_state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


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
