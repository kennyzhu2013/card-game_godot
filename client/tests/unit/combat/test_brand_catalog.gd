extends RefCounted

const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_brand_catalog.gd --")
	test_mvp_30_file_exists_and_loads_30_unique_brands()
	test_mvp_30_category_counts_match_r05()
	test_required_brand_schema_fields()
	test_boss_pool_references_existing_brand_ids()
	test_resolve_boss_drop_grants_brand_and_discovers_id()
	return {"passed": _passed, "failed": _failed}


func test_mvp_30_file_exists_and_loads_30_unique_brands() -> void:
	assert_true(FileAccess.file_exists("res://data/brands/mvp_30.json"), "mvp_30 brand data file exists")
	var brands: Array = BrandCatalogScript.load_all_brands()
	assert_eq(brands.size(), 30, "MVP catalog loads exactly 30 brands")
	var ids := {}
	for brand in brands:
		ids[brand.id] = true
	assert_eq(ids.size(), 30, "MVP catalog brand ids are unique")


func test_mvp_30_category_counts_match_r05() -> void:
	var counts: Dictionary = BrandCatalogScript.category_counts()
	assert_eq(int(counts.get("fool", 0)), 4, "R05 fool-specific brand count = 4")
	assert_eq(int(counts.get("common", 0)), 18, "R05 common brand count = 18")
	assert_eq(int(counts.get("unique", 0)), 4, "R05 unique brand count = 4")
	assert_eq(int(counts.get("forge", 0)), 4, "R05 forge brand count = 4")


func test_required_brand_schema_fields() -> void:
	var shadow = BrandCatalogScript.create_brand("fool_shadow_seal")
	assert_true(shadow != null, "fool_shadow_seal creates Brand")
	assert_eq(shadow.id, "fool_shadow_seal", "schema id")
	assert_eq(shadow.pathway_affinity, "fool", "schema pathway affinity")
	assert_eq(shadow.sequence_min, 7, "schema sequence_min")
	assert_eq(shadow.effect_type, "stat", "schema effect type")
	assert_true(shadow.effect_payload.has("operation"), "schema effect payload")
	assert_true(shadow.description.length() > 0, "schema description")


func test_boss_pool_references_existing_brand_ids() -> void:
	var ids := {}
	for brand in BrandCatalogScript.load_all_brands():
		ids[brand.id] = true
	var pool: Array[String] = BrandCatalogScript.pool_ids("fool_low_tier_brands")
	assert_true(pool.size() >= 4, "fool_low_tier_brands pool has entries")
	for brand_id in pool:
		assert_true(ids.has(brand_id), "%s exists in MVP catalog" % brand_id)


func test_resolve_boss_drop_grants_brand_and_discovers_id() -> void:
	var gs = _new_state()
	var drops := {
		"brand_guaranteed": true,
		"brand_pool": "fool_low_tier_brands",
	}
	var brand = BrandCatalogScript.resolve_boss_brand_drop(drops, gs, 0.0)
	assert_true(brand != null, "boss guaranteed drop creates a brand")
	if brand == null:
		return
	assert_eq(gs.brands_inventory.size(), 1, "boss drop appends to brands_inventory")
	assert_eq(gs.brands_inventory[0].id, brand.id, "boss drop stores the rolled brand")
	assert_true(brand.id in gs.daodian["discovered_brands"], "boss drop discovers brand id")


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
