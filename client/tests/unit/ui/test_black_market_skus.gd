extends RefCounted

const BlackMarketScript = preload("res://scripts/ui/black_market.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const ShopInventoryScript = preload("res://scripts/shop/shop_inventory.gd")
const ShopOfferScript = preload("res://scripts/shop/shop_offer.gd")
const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")

const POOL_PATH := "res://data/shops/donen_blackmarket.json"
const LEGACY_POOL_PATH := "res://data/shop/black_market_pool.json"

const EXPECTED_CATEGORY_COUNTS := {
	"temporary_card": 6,
	"material": 4,
	"potion": 3,
	"brand": 5,
	"dao_page_rule": 4,
	"variant": 2,
}

const EXPECTED_SKUS := {
	"card_shadow_arrow_t2": {"category": "temporary_card", "price_currency": "lingstone", "price_amount": 80, "weight": 12},
	"card_flame_arrow_t2": {"category": "temporary_card", "price_currency": "lingstone", "price_amount": 80, "weight": 12},
	"card_water_touch_t2": {"category": "temporary_card", "price_currency": "lingstone", "price_amount": 90, "weight": 10},
	"card_double_shadow_t3": {"category": "temporary_card", "price_currency": "lingstone", "price_amount": 180, "weight": 6},
	"card_inquiry_mirror_t2": {"category": "temporary_card", "price_currency": "lingstone", "price_amount": 100, "weight": 8},
	"card_premonition_t2": {"category": "temporary_card", "price_currency": "lingstone", "price_amount": 70, "weight": 10},
	"mat_shadow_dust_x3": {"category": "material", "price_currency": "lingstone", "price_amount": 30, "weight": 15},
	"mat_iron_shard_x5": {"category": "material", "price_currency": "lingstone", "price_amount": 25, "weight": 15},
	"mat_glass_lens_x1": {"category": "material", "price_currency": "lingstone", "price_amount": 80, "weight": 8},
	"mat_blood_oil_x2": {"category": "material", "price_currency": "lingstone", "price_amount": 60, "weight": 10},
	"potion_purify_5": {"category": "potion", "price_currency": "lingstone", "price_amount": 150, "weight": 8},
	"potion_purify_15": {"category": "potion", "price_currency": "lingstone", "price_amount": 400, "weight": 4},
	"potion_focus": {"category": "potion", "price_currency": "lingstone", "price_amount": 200, "weight": 5},
	"brand_silence_low": {"category": "brand", "price_currency": "lingstone", "price_amount": 600, "weight": 4},
	"brand_fate_low": {"category": "brand", "price_currency": "lingstone", "price_amount": 700, "weight": 4},
	"brand_crit_low": {"category": "brand", "price_currency": "lingstone", "price_amount": 550, "weight": 5},
	"brand_truename": {"category": "brand", "price_currency": "dao_page", "price_amount": 1, "weight": 2},
	"brand_forbidden": {"category": "brand", "price_currency": "dao_page", "price_amount": 3, "weight": 1},
	"dao_page_x1": {"category": "dao_page_rule", "price_currency": "lingstone", "price_amount": 500, "weight": 5},
	"rule_use_debuff": {"category": "dao_page_rule", "price_currency": "dao_page", "price_amount": 1, "weight": 3},
	"rule_no_consec_attack": {"category": "dao_page_rule", "price_currency": "dao_page", "price_amount": 1, "weight": 3},
	"rule_first_question": {"category": "dao_page_rule", "price_currency": "dao_page", "price_amount": 1, "weight": 2},
	"variant_shadow_deep": {"category": "variant", "price_currency": "dao_page", "price_amount": 2, "secondary_price_currency": "lingstone", "secondary_price_amount": 300, "weight": 1},
	"variant_shadow_lost": {"category": "variant", "price_currency": "dao_page", "price_amount": 3, "secondary_price_currency": "lingstone", "secondary_price_amount": 500, "weight": 1},
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_black_market_skus.gd --")
	test_only_one_live_black_market_pool_path()
	test_r16_black_market_sku_ids_categories_prices_and_weights()
	test_variant_offers_are_locked_and_do_not_grant_or_deduct()
	await test_locked_variant_ui_is_disabled_with_exact_r14_tooltip()
	return {"passed": _passed, "failed": _failed}


func test_only_one_live_black_market_pool_path() -> void:
	assert_true(FileAccess.file_exists(POOL_PATH), "live black market pool is res://data/shops/donen_blackmarket.json")
	assert_true(not FileAccess.file_exists(LEGACY_POOL_PATH), "legacy res://data/shop/black_market_pool.json is absent")
	assert_eq(str(BlackMarketScript.DEFAULT_POOL_PATH), POOL_PATH, "BlackMarket reads the single live pool path")


func test_r16_black_market_sku_ids_categories_prices_and_weights() -> void:
	var pool: Dictionary = _pool()
	var items: Array = pool.get("items", [])
	assert_eq(items.size(), 24, "R16 §4.5.1 black market SKU count is exactly 24")
	var by_id: Dictionary = {}
	var counts: Dictionary = {}
	for entry in items:
		var data: Dictionary = entry
		var id: String = str(data.get("id", ""))
		var category: String = str(data.get("category", ""))
		by_id[id] = data
		counts[category] = int(counts.get(category, 0)) + 1
	for category in EXPECTED_CATEGORY_COUNTS:
		assert_eq(int(counts.get(category, 0)), int(EXPECTED_CATEGORY_COUNTS[category]), "category %s SKU count" % category)
	assert_eq(by_id.size(), 24, "24 SKU ids are unique")
	for id in EXPECTED_SKUS:
		assert_true(by_id.has(id), "R16 §4.5.1 SKU exists: %s" % id)
		if by_id.has(id):
			_assert_sku_matches(id, by_id[id], EXPECTED_SKUS[id])


func test_variant_offers_are_locked_and_do_not_grant_or_deduct() -> void:
	var gs = _state()
	gs.dao_pages = 10
	gs.lingstones = 1000
	for id in ["variant_shadow_deep", "variant_shadow_lost"]:
		var offer = ShopOfferScript.from_dict(_item_by_id(id))
		var before_lingstones: int = gs.lingstones
		var before_dao_pages: int = gs.dao_pages
		var result: Dictionary = ShopServiceScript.buy(offer, gs)
		assert_true(not bool(result.get("ok", true)), "%s purchase rejects while R14 locked" % id)
		assert_eq(str(result.get("reason", "")), "locked", "%s purchase reason is locked" % id)
		assert_eq(str(result.get("detail", "")), "R14 正式版开放", "%s lock detail is exact R16 tooltip text" % id)
		assert_eq(int(gs.lingstones), before_lingstones, "%s does not deduct lingstones" % id)
		assert_eq(int(gs.dao_pages), before_dao_pages, "%s does not deduct dao pages" % id)
		assert_eq(gs.cards_inventory.size(), 0, "%s does not grant card" % id)
		assert_eq(int(offer.stock), 1, "%s stock is unchanged after rejected buy" % id)


func test_locked_variant_ui_is_disabled_with_exact_r14_tooltip() -> void:
	var panel = BlackMarketScript.new()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	gs.day = 5
	gs.time_of_day = "night"
	gs.dao_pages = 10
	gs.lingstones = 1000
	var offer = ShopOfferScript.from_dict(_item_by_id("variant_shadow_deep"))
	var inv = ShopInventoryScript.new()
	inv.shop_id = "donen_blackmarket"
	inv.last_refresh_day = gs.day
	inv.slots.append(offer)
	panel._game_state = gs
	panel._pool = _pool()
	panel._inventory = inv
	panel._populate()
	assert_true(panel._offer_list.is_item_disabled(0), "locked variant row is disabled")
	assert_eq(panel._offer_list.get_item_tooltip(0), "R14 正式版开放", "locked variant row tooltip is exact")
	panel._offer_list.select(0)
	panel._on_offer_selected(0)
	assert_true(panel._buy_button.disabled, "locked variant disables purchase button")
	assert_eq(panel._buy_button.tooltip_text, "R14 正式版开放", "locked variant buy button tooltip is exact")
	panel.queue_free()


func _assert_sku_matches(id: String, data: Dictionary, expected: Dictionary) -> void:
	assert_eq(str(data.get("category", "")), str(expected.get("category", "")), "%s category" % id)
	assert_eq(str(data.get("price_currency", "")), str(expected.get("price_currency", "")), "%s price_currency" % id)
	assert_eq(int(data.get("price_amount", -1)), int(expected.get("price_amount", -1)), "%s price_amount" % id)
	assert_eq(int(data.get("weight", -1)), int(expected.get("weight", -1)), "%s weight" % id)
	if expected.has("secondary_price_currency"):
		assert_eq(str(data.get("secondary_price_currency", "")), str(expected.get("secondary_price_currency", "")), "%s secondary_price_currency" % id)
		assert_eq(int(data.get("secondary_price_amount", -1)), int(expected.get("secondary_price_amount", -1)), "%s secondary_price_amount" % id)
	if str(expected.get("category", "")) == "variant":
		assert_eq(str(data.get("locked_reason", "")), "R14 正式版开放", "%s locked reason" % id)


func _pool() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(POOL_PATH))
	if parsed is Dictionary:
		return parsed
	return {}


func _item_by_id(id: String) -> Dictionary:
	var items: Array = _pool().get("items", [])
	for entry in items:
		var data: Dictionary = entry
		if str(data.get("id", "")) == id:
			return data
	return {}


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
