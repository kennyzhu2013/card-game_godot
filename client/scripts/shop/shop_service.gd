class_name ShopService
extends RefCounted

# R16：买卖通用路由（黑市 + 塔内商人共用）
# 把 ShopOffer + GameState + 价格倍率 转成"扣钱→发货→减库存"。

const CardScript = preload("res://scripts/combat/card.gd")
const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")


static func can_buy(offer, game_state, price_multiplier: float = 1.0) -> Dictionary:
	if offer == null:
		return {"ok": false, "reason": "missing_offer"}
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if int(offer.stock) <= 0:
		return {"ok": false, "reason": "sold_out"}
	if offer.locked_reason != "":
		return {"ok": false, "reason": "locked", "detail": offer.locked_reason}
	if offer.min_day > int(game_state.day):
		return {"ok": false, "reason": "min_day_locked"}
	var cond_check: Dictionary = _check_conditions(offer.conditions, game_state)
	if not bool(cond_check.get("ok", true)):
		return cond_check
	var price: int = offer.priced_amount(price_multiplier)
	if _currency_amount(game_state, offer.price_currency) < price:
		return {"ok": false, "reason": "insufficient_currency", "price": price}
	var secondary_price: int = 0
	if offer.secondary_price_currency != "" and int(offer.secondary_price_amount) > 0:
		secondary_price = offer.priced_secondary_amount(price_multiplier)
		if _currency_amount(game_state, offer.secondary_price_currency) < secondary_price:
			return {"ok": false, "reason": "insufficient_currency", "price": secondary_price}
	return {"ok": true, "reason": "ok", "price": price, "secondary_price": secondary_price}


static func apply_discount(game_state, shop_id: String, pct: int) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if shop_id == "":
		return {"ok": false, "reason": "missing_shop_id"}
	var clamped_pct := clampi(pct, 0, 100)
	if clamped_pct <= 0:
		return {"ok": false, "reason": "invalid_pct"}
	var discounts: Dictionary = _shop_discounts(game_state)
	var current := int(discounts.get(shop_id, 0))
	discounts[shop_id] = maxi(current, clamped_pct)
	_write_shop_discounts(game_state, discounts)
	return {"ok": true, "shop_id": shop_id, "pct": int(discounts[shop_id])}


static func price_multiplier_for(game_state, shop_id: String, base_multiplier: float = 1.0) -> float:
	if game_state == null or shop_id == "":
		return base_multiplier
	var pct := int(_shop_discounts(game_state).get(shop_id, 0))
	if pct <= 0:
		return base_multiplier
	return base_multiplier * maxf(0.0, 1.0 - (float(pct) / 100.0))


static func consume_discount(game_state, shop_id: String) -> int:
	if game_state == null or shop_id == "":
		return 0
	var discounts: Dictionary = _shop_discounts(game_state)
	var pct := int(discounts.get(shop_id, 0))
	if pct > 0:
		discounts.erase(shop_id)
		_write_shop_discounts(game_state, discounts)
	return pct


static func buy(offer, game_state, price_multiplier: float = 1.0, shop_id: String = "") -> Dictionary:
	var check: Dictionary = can_buy(offer, game_state, price_multiplier)
	if not bool(check.get("ok", false)):
		return check
	var price: int = int(check.get("price", offer.priced_amount(price_multiplier)))
	var item_type: String = str(offer.item_type)
	var granted = null
	match item_type:
		"card":
			granted = _create_card_from_offer(offer)
			if granted == null:
				return {"ok": false, "reason": "missing_card_template"}
			_deduct_offer_price(game_state, offer, price, int(check.get("secondary_price", 0)))
			game_state.add_card(granted)
			_record_card_discovered(game_state, granted.template_id)
		"brand":
			if offer.brand_id == "":
				return {"ok": false, "reason": "missing_brand"}
			granted = BrandCatalogScript.create_brand(offer.brand_id)
			if granted == null:
				return {"ok": false, "reason": "missing_brand"}
			_deduct_offer_price(game_state, offer, price, int(check.get("secondary_price", 0)))
			game_state.brands_inventory.append(granted)
			_record_brand_discovered(game_state, offer.brand_id)
		"material":
			if offer.material_id == "" or offer.amount <= 0:
				return {"ok": false, "reason": "missing_material"}
			_deduct_offer_price(game_state, offer, price, int(check.get("secondary_price", 0)))
			game_state.forge_materials[offer.material_id] = int(game_state.forge_materials.get(offer.material_id, 0)) + offer.amount
			granted = {"material_id": offer.material_id, "amount": offer.amount}
		"potion":
			_deduct_offer_price(game_state, offer, price, int(check.get("secondary_price", 0)))
			if offer.pollution_delta != 0:
				game_state.pollution = clampi(int(game_state.pollution) + offer.pollution_delta, 0, 100)
			if offer.ap_max_delta != 0:
				game_state.ap_max = max(1, int(game_state.ap_max) + offer.ap_max_delta)
			granted = {"potion_id": offer.id, "pollution_delta": offer.pollution_delta, "ap_max_delta": offer.ap_max_delta}
		"page":
			_deduct_offer_price(game_state, offer, price, int(check.get("secondary_price", 0)))
			game_state.dao_pages = int(game_state.dao_pages) + max(1, offer.amount)
			granted = {"dao_pages_added": max(1, offer.amount)}
		"rule":
			if offer.rule_id == "":
				return {"ok": false, "reason": "missing_rule"}
			_deduct_offer_price(game_state, offer, price, int(check.get("secondary_price", 0)))
			if not offer.rule_id in game_state.learned_rules:
				game_state.learned_rules.append(offer.rule_id)
			granted = {"rule_id": offer.rule_id}
		_:
			return {"ok": false, "reason": "unsupported_item_type", "item_type": item_type}
	offer.stock = max(0, int(offer.stock) - 1)
	if shop_id != "":
		consume_discount(game_state, shop_id)
	return {"ok": true, "reason": "ok", "item_type": item_type, "granted": granted, "price": price}


static func _create_card_from_offer(offer):
	var data: Dictionary = {}
	if offer.card_data is Dictionary and not offer.card_data.is_empty():
		data = offer.card_data.duplicate(true)
	else:
		var path: String = offer.skill_path
		if path == "":
			path = "res://data/skills/%s.json" % offer.template_id
		if not FileAccess.file_exists(path):
			return null
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			return null
		data = parsed
	if not data.has("display_name") or str(data.get("display_name", "")) == "":
		data["display_name"] = offer.display_name
	var card = CardScript.from_skill_json(data)
	if offer.template_id != "":
		card.template_id = offer.template_id
	if card.display_name == "":
		card.display_name = offer.display_name
	card.id = _unique_card_id(card.template_id)
	return card


static func _unique_card_id(template_id: String) -> String:
	var base := template_id if template_id != "" else "card"
	return "%s_shop_%d_%d" % [base, Time.get_ticks_usec(), randi() % 1000000]


static func _currency_amount(game_state, currency: String) -> int:
	match currency:
		"lingstones": return int(game_state.lingstones)
		"dao_pages": return int(game_state.dao_pages)
		_: return 0


static func _shop_discounts(game_state) -> Dictionary:
	var value = game_state.get("shop_discounts")
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _write_shop_discounts(game_state, discounts: Dictionary) -> void:
	game_state.set("shop_discounts", discounts.duplicate(true))


static func _deduct_currency(game_state, currency: String, amount: int) -> void:
	match currency:
		"lingstones": game_state.lingstones -= amount
		"dao_pages": game_state.dao_pages -= amount


static func _deduct_offer_price(game_state, offer, primary_amount: int, secondary_amount: int = 0) -> void:
	_deduct_currency(game_state, offer.price_currency, primary_amount)
	if offer.secondary_price_currency != "" and secondary_amount > 0:
		_deduct_currency(game_state, offer.secondary_price_currency, secondary_amount)


static func _check_conditions(conditions: Dictionary, game_state) -> Dictionary:
	if conditions.is_empty():
		return {"ok": true}
	if conditions.has("sequence_min") and int(game_state.sequence) > int(conditions["sequence_min"]):
		return {"ok": false, "reason": "sequence_too_low"}
	if conditions.has("halfmoon_trust_min") and int(game_state.halfmoon_trust) < int(conditions["halfmoon_trust_min"]):
		return {"ok": false, "reason": "halfmoon_trust_too_low"}
	if conditions.has("church_awareness_max") and int(game_state.church_awareness) > int(conditions["church_awareness_max"]):
		return {"ok": false, "reason": "church_awareness_too_high"}
	return {"ok": true}


static func _record_card_discovered(game_state, template_id: String) -> void:
	var discovered: Array = game_state.daodian.get("discovered_cards", [])
	if not template_id in discovered:
		discovered.append(template_id)
	game_state.daodian["discovered_cards"] = discovered


static func _record_brand_discovered(game_state, brand_id: String) -> void:
	var discovered: Array = game_state.daodian.get("discovered_brands", [])
	if not brand_id in discovered:
		discovered.append(brand_id)
	game_state.daodian["discovered_brands"] = discovered
