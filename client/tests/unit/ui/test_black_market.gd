extends RefCounted

const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")
const ShopInventoryScript = preload("res://scripts/shop/shop_inventory.gd")
const BlackMarketScript = preload("res://scripts/ui/black_market.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const POOL_PATH := "res://data/shops/donen_blackmarket.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_black_market.gd --")
	test_pool_has_24_skus_with_min_day_3()
	test_market_closed_before_day_3_or_outside_night()
	test_market_open_at_night_day_3()
	test_six_slots_at_default_state()
	test_pollution_60_halves_slot_count()
	test_halfmoon_trust_70_grants_extra_slot()
	test_combined_threshold_formula_matches_spec()
	test_buy_card_deducts_lingstones_and_adds_inventory_card()
	test_buy_brand_deducts_dao_pages_and_adds_brand()
	test_buy_material_deducts_lingstones_and_adds_materials()
	test_potion_purify_reduces_pollution()
	test_rule_purchase_adds_to_learned_rules()
	test_locked_offer_cannot_be_purchased()
	test_church_awareness_25_raises_prices_20_percent()
	test_manual_refresh_costs_50_and_caps_at_3_per_day()
	return {"passed": _passed, "failed": _failed}


func test_pool_has_24_skus_with_min_day_3() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	assert_eq(int(pool.get("min_day_to_open", 0)), 3, "pool min_day_to_open = 3")
	assert_eq(int(pool.get("slot_count", 0)), 6, "pool default slot_count = 6")
	assert_eq(int(pool.get("manual_refresh_cost", 0)), 50, "manual refresh cost = 50")
	assert_eq(int(pool.get("manual_refresh_daily_limit", 0)), 3, "manual refresh daily limit = 3")
	var items: Array = pool.get("items", [])
	assert_true(items.size() >= 24, "pool has 24+ SKUs (per R16 §4.5.1)")


func test_market_closed_before_day_3_or_outside_night() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var gs = _state()
	gs.day = 1
	gs.time_of_day = "night"
	var d1 := BlackMarketScript.is_open(gs, pool)
	assert_true(not bool(d1.get("ok", true)), "Day 1 black market is closed")
	assert_eq(str(d1.get("reason", "")), "min_day_locked", "Day 1 reason is min_day_locked")
	gs.day = 5
	gs.time_of_day = "morning"
	var morning := BlackMarketScript.is_open(gs, pool)
	assert_true(not bool(morning.get("ok", true)), "morning black market is closed")
	assert_eq(str(morning.get("reason", "")), "not_night", "morning reason is not_night")


func test_market_open_at_night_day_3() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var gs = _state()
	gs.day = 3
	gs.time_of_day = "night"
	assert_true(bool(BlackMarketScript.is_open(gs, pool).get("ok", false)), "Day 3 night opens black market")


func test_six_slots_at_default_state() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var gs = _state()
	gs.day = 5
	gs.time_of_day = "night"
	assert_eq(BlackMarketScript.slot_count(gs, pool), 6, "default slot count is 6")


func test_pollution_60_halves_slot_count() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var gs = _state()
	gs.pollution = 60
	var n := BlackMarketScript.slot_count(gs, pool)
	assert_eq(n, 3, "pollution 60 halves 6 slots to max(3, 6/2) = 3")


func test_halfmoon_trust_70_grants_extra_slot() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var gs = _state()
	gs.halfmoon_trust = 70
	assert_eq(BlackMarketScript.slot_count(gs, pool), 7, "halfmoon_trust 70+ grants extra slot")


func test_combined_threshold_formula_matches_spec() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var combined = _state()
	combined.church_awareness = 25
	combined.pollution = 60
	combined.halfmoon_trust = 70
	assert_eq(BlackMarketScript.price_multiplier(combined), 1.20, "awareness 25 applies 1.20 price multiplier")
	assert_eq(BlackMarketScript.slot_count(combined, pool), 4, "combined slots = max(3, 6/2) + 1 = 4")
	var pure_pollution = _state()
	pure_pollution.pollution = 60
	assert_eq(BlackMarketScript.slot_count(pure_pollution, pool), 3, "pure pollution 60 slots = 3")
	var pure_trust = _state()
	pure_trust.halfmoon_trust = 70
	assert_eq(BlackMarketScript.slot_count(pure_trust, pool), 7, "pure halfmoon_trust 70 slots = 7")


func test_buy_card_deducts_lingstones_and_adds_inventory_card() -> void:
	var gs = _state()
	gs.lingstones = 500
	gs.day = 5
	var offer = _offer({
		"id": "card_shadow_arrow_test",
		"item_type": "card",
		"display_name": "影箭·临时 ★★",
		"template_id": "shadow_arrow",
		"skill_path": "res://data/skills/shadow_arrow.json",
		"price_currency": "lingstones",
		"price_amount": 80,
		"stock": 1,
	})
	var result: Dictionary = ShopServiceScript.buy(offer, gs)
	assert_true(bool(result.get("ok", false)), "card purchase succeeds with enough lingstones")
	assert_eq(int(gs.lingstones), 420, "card purchase deducts lingstones")
	assert_eq(gs.cards_inventory.size(), 1, "card purchase adds one inventory card")
	assert_eq(str(gs.cards_inventory[0].template_id), "shadow_arrow", "card purchase keeps template id")
	assert_eq(int(offer.stock), 0, "card purchase decrements stock")


func test_buy_brand_deducts_dao_pages_and_adds_brand() -> void:
	var gs = _state()
	gs.dao_pages = 50
	var offer = _offer({
		"id": "brand_low_test",
		"item_type": "brand",
		"display_name": "锐利之纹",
		"brand_id": "damage_plus_low",
		"price_currency": "dao_pages",
		"price_amount": 50,
		"stock": 1,
	})
	var result: Dictionary = ShopServiceScript.buy(offer, gs)
	assert_true(bool(result.get("ok", false)), "brand purchase succeeds with enough dao pages")
	assert_eq(int(gs.dao_pages), 0, "brand purchase deducts dao pages")
	assert_eq(gs.brands_inventory.size(), 1, "brand purchase adds one brand")


func test_buy_material_deducts_lingstones_and_adds_materials() -> void:
	var gs = _state()
	gs.lingstones = 75
	var offer = _offer({
		"id": "mat_fool_pages_test",
		"item_type": "material",
		"display_name": "愚者残页 ×3",
		"material_id": "愚者残页",
		"amount": 3,
		"price_currency": "lingstones",
		"price_amount": 50,
		"stock": 1,
	})
	var result: Dictionary = ShopServiceScript.buy(offer, gs)
	assert_true(bool(result.get("ok", false)), "material purchase succeeds with enough lingstones")
	assert_eq(int(gs.lingstones), 25, "material purchase deducts lingstones")
	assert_eq(int(gs.forge_materials.get("愚者残页", 0)), 3, "material purchase adds pack amount")


func test_potion_purify_reduces_pollution() -> void:
	var gs = _state()
	gs.lingstones = 200
	gs.pollution = 30
	var offer = _offer({
		"id": "potion_purify_5_test",
		"item_type": "potion",
		"display_name": "净化药剂",
		"pollution_delta": -5,
		"price_currency": "lingstones",
		"price_amount": 150,
		"stock": 1,
	})
	var result: Dictionary = ShopServiceScript.buy(offer, gs)
	assert_true(bool(result.get("ok", false)), "potion purchase succeeds")
	assert_eq(int(gs.pollution), 25, "potion reduces pollution by 5")


func test_rule_purchase_adds_to_learned_rules() -> void:
	var gs = _state()
	gs.dao_pages = 5
	var offer = _offer({
		"id": "rule_test",
		"item_type": "rule",
		"display_name": "守则:测试",
		"rule_id": "rule_test_unique",
		"price_currency": "dao_pages",
		"price_amount": 1,
		"stock": 1,
	})
	var result: Dictionary = ShopServiceScript.buy(offer, gs)
	assert_true(bool(result.get("ok", false)), "rule purchase succeeds")
	assert_true("rule_test_unique" in gs.learned_rules, "rule added to learned_rules")


func test_locked_offer_cannot_be_purchased() -> void:
	var gs = _state()
	gs.dao_pages = 5
	var offer = _offer({
		"id": "variant_locked",
		"item_type": "card",
		"display_name": "深影",
		"template_id": "shadow_arrow",
		"skill_path": "res://data/skills/shadow_arrow.json",
		"price_currency": "dao_pages",
		"price_amount": 2,
		"stock": 1,
		"locked_reason": "R14 正式版开放",
	})
	var result: Dictionary = ShopServiceScript.buy(offer, gs)
	assert_true(not bool(result.get("ok", true)), "locked offer rejects purchase")
	assert_eq(str(result.get("reason", "")), "locked", "locked reason returned")


func test_church_awareness_25_raises_prices_20_percent() -> void:
	var gs = _state()
	gs.church_awareness = 25
	assert_eq(BlackMarketScript.price_multiplier(gs), 1.20, "church awareness 25+ raises prices to 1.2x")


func test_manual_refresh_costs_50_and_caps_at_3_per_day() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var gs = _state()
	gs.day = 5
	gs.time_of_day = "night"
	gs.lingstones = 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var inventory = ShopInventoryScript.from_pool("donen_blackmarket", pool, gs.day, 6, rng)
	gs.shop_inventories[inventory.shop_id] = inventory
	for i in range(3):
		var ok: Dictionary = BlackMarketScript.manual_refresh(gs, pool, inventory)
		assert_true(bool(ok.get("ok", false)), "manual refresh #%d succeeds" % (i + 1))
	assert_eq(int(gs.lingstones), 50, "manual refresh deducts 3 × 50 lingstones")
	var fourth: Dictionary = BlackMarketScript.manual_refresh(gs, pool, inventory)
	assert_true(not bool(fourth.get("ok", true)), "fourth manual refresh in same day rejected")
	assert_eq(str(fourth.get("reason", "")), "refresh_limit", "fourth refresh reason refresh_limit")


func _offer(data: Dictionary):
	var ShopOfferScript = load("res://scripts/shop/shop_offer.gd")
	return ShopOfferScript.from_dict(data)


func _state():
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
