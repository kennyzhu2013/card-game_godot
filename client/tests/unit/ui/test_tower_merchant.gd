extends RefCounted

const TowerMerchantScript = preload("res://scripts/ui/tower_merchant.gd")
const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_tower_merchant.gd --")
	test_pool_loads_with_12_skus()
	test_per_floor_inventory_persists()
	test_purchase_uses_15_percent_discount()
	test_purchase_decrements_stock()
	return {"passed": _passed, "failed": _failed}


func test_pool_loads_with_12_skus() -> void:
	var pool: Dictionary = TowerMerchantScript.load_pool()
	var items: Array = pool.get("items", [])
	assert_true(items.size() >= 12, "tower_merchant has 12+ SKUs (got %d)" % items.size())


func test_per_floor_inventory_persists() -> void:
	var gs = _state()
	var panel = TowerMerchantScript.new()
	panel._game_state = gs
	panel._floor_id = "shadow_alley::3"
	var first = panel._ensure_inventory()
	assert_true(first != null, "first ensure_inventory returns inventory")
	var same = panel._ensure_inventory()
	assert_eq(first, same, "second ensure on same floor returns same inventory (no reroll)")


func test_purchase_uses_15_percent_discount() -> void:
	var gs = _state()
	gs.lingstones = 200
	var ShopOfferScript = load("res://scripts/shop/shop_offer.gd")
	var offer = ShopOfferScript.from_dict({
		"id": "card_shadow_arrow_t2",
		"item_type": "card",
		"display_name": "影箭·临时 ★★",
		"template_id": "shadow_arrow",
		"skill_path": "res://data/skills/shadow_arrow.json",
		"price_currency": "lingstones",
		"price_amount": 60,
		"stock": 1,
	})
	# 60 × 0.85 = 51
	var result: Dictionary = ShopServiceScript.buy(offer, gs, TowerMerchantScript.TOWER_PRICE_MULTIPLIER)
	assert_true(bool(result.get("ok", false)), "tower merchant purchase succeeds")
	assert_eq(int(result.get("price", 0)), 51, "price = ceil(60 * 0.85) = 51")
	assert_eq(int(gs.lingstones), 149, "lingstones deducted by discount price")


func test_purchase_decrements_stock() -> void:
	var gs = _state()
	gs.lingstones = 100
	var ShopOfferScript = load("res://scripts/shop/shop_offer.gd")
	var offer = ShopOfferScript.from_dict({
		"id": "potion_red_small",
		"item_type": "potion",
		"display_name": "小红药",
		"price_currency": "lingstones",
		"price_amount": 30,
		"stock": 1,
	})
	ShopServiceScript.buy(offer, gs, TowerMerchantScript.TOWER_PRICE_MULTIPLIER)
	assert_eq(int(offer.stock), 0, "stock decremented to 0 after buy")
	var second: Dictionary = ShopServiceScript.buy(offer, gs, TowerMerchantScript.TOWER_PRICE_MULTIPLIER)
	assert_true(not bool(second.get("ok", true)), "second buy on sold-out offer rejected")
	assert_eq(str(second.get("reason", "")), "sold_out", "sold_out reason")


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
