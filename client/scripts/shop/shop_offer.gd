class_name ShopOffer
extends RefCounted

# R16 §7.1 ShopItem schema（黑市/塔内商人共用）
# 一条 ShopOffer = 一个商品槽。商品库存 stock 默认 1。

var id: String = ""
var item_type: String = ""           # "card" / "brand" / "potion" / "material" / "page" / "rule"
var category: String = ""            # R16 §4.5.1 SKU bucket, e.g. "temporary_card" / "variant"
var display_name: String = ""

# 价格
var price_currency: String = "lingstones"  # "lingstones" / "dao_pages"
var price_amount: int = 0
var secondary_price_currency: String = ""
var secondary_price_amount: int = 0

# 商品 payload
var template_id: String = ""        # 卡牌模板 / 烙印 id 等
var skill_path: String = ""         # 卡牌走 skills/*.json 路径
var brand_id: String = ""
var material_id: String = ""
var amount: int = 1
var rule_id: String = ""            # 守则商品（R16 §4.5.1）
var pollution_delta: int = 0        # 净化药剂用
var ap_max_delta: int = 0           # 凝神药剂用
var card_data: Dictionary = {}      # 直接给定 card json（覆盖 skill_path）

# 限制
var rarity: String = "common"
var available_in: Array[String] = []
var min_day: int = 0
var conditions: Dictionary = {}     # {"sequence_min": 3, "halfmoon_trust_min": 70, "owner_dao_pages_min": 1}
var stock: int = 1
var weight: int = 1
var locked_reason: String = ""      # 仅显示用，例如 "R14 正式版开放"


static func from_dict(data: Dictionary):
	var offer = load("res://scripts/shop/shop_offer.gd").new()
	offer.id = str(data.get("id", ""))
	offer.item_type = str(data.get("item_type", ""))
	offer.category = str(data.get("category", ""))
	offer.display_name = str(data.get("display_name", offer.id))
	offer.price_currency = _normalize_currency(str(data.get("price_currency", "lingstones")))
	offer.price_amount = int(data.get("price_amount", 0))
	offer.secondary_price_currency = _normalize_currency(str(data.get("secondary_price_currency", "")))
	offer.secondary_price_amount = int(data.get("secondary_price_amount", 0))
	offer.template_id = str(data.get("template_id", ""))
	offer.skill_path = str(data.get("skill_path", ""))
	offer.brand_id = str(data.get("brand_id", data.get("payload_id", "")))
	offer.material_id = str(data.get("material_id", ""))
	offer.amount = int(data.get("amount", 1))
	offer.rule_id = str(data.get("rule_id", ""))
	offer.pollution_delta = int(data.get("pollution_delta", 0))
	offer.ap_max_delta = int(data.get("ap_max_delta", 0))
	if data.get("card_data", null) is Dictionary:
		offer.card_data = data.get("card_data").duplicate(true)
	offer.rarity = str(data.get("rarity", "common"))
	var raw_avail: Variant = data.get("available_in", [])
	if raw_avail is Array:
		for entry in raw_avail:
			offer.available_in.append(str(entry))
	offer.min_day = int(data.get("min_day", 0))
	if data.get("conditions", null) is Dictionary:
		offer.conditions = data.get("conditions").duplicate(true)
	offer.stock = int(data.get("stock", 1))
	offer.weight = int(data.get("weight", 1))
	offer.locked_reason = str(data.get("locked_reason", ""))
	return offer


func to_dict() -> Dictionary:
	return {
		"id": id,
		"item_type": item_type,
		"category": category,
		"display_name": display_name,
		"price_currency": price_currency,
		"price_amount": price_amount,
		"secondary_price_currency": secondary_price_currency,
		"secondary_price_amount": secondary_price_amount,
		"template_id": template_id,
		"skill_path": skill_path,
		"brand_id": brand_id,
		"material_id": material_id,
		"amount": amount,
		"rule_id": rule_id,
		"pollution_delta": pollution_delta,
		"ap_max_delta": ap_max_delta,
		"card_data": card_data.duplicate(true),
		"rarity": rarity,
		"available_in": Array(available_in),
		"min_day": min_day,
		"conditions": conditions.duplicate(true),
		"stock": stock,
		"weight": weight,
		"locked_reason": locked_reason,
	}


func clone():
	return load("res://scripts/shop/shop_offer.gd").from_dict(to_dict())


func priced_amount(price_multiplier: float = 1.0) -> int:
	return int(ceil(float(price_amount) * price_multiplier))


func priced_secondary_amount(price_multiplier: float = 1.0) -> int:
	return int(ceil(float(secondary_price_amount) * price_multiplier))


static func _normalize_currency(currency: String) -> String:
	match currency:
		"lingstone", "lingstones", "spirit_stones":
			return "lingstones"
		"dao_page", "dao_pages", "scraps":
			return "dao_pages"
		_:
			return currency
