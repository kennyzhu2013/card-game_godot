class_name ShopInventory
extends RefCounted

# R16 §7.2 商店库存抽象（黑市 / 塔内商人共用）
# slots/refresh_count_today/last_refresh_day 为权威字段。

const ShopOfferScript = preload("res://scripts/shop/shop_offer.gd")

var shop_id: String = ""
var slots: Array = []                 # Array[ShopOffer]
var refresh_count_today: int = 0
var last_refresh_day: int = 0


static func from_pool(shop_id_in: String, pool: Dictionary, day: int, slot_count: int, rng: RandomNumberGenerator):
	var inv = load("res://scripts/shop/shop_inventory.gd").new()
	inv.shop_id = shop_id_in
	inv.slots = roll_slots(pool, day, slot_count, rng)
	inv.last_refresh_day = day
	inv.refresh_count_today = 0
	return inv


static func roll_slots(pool: Dictionary, day: int, slot_count: int, rng: RandomNumberGenerator) -> Array:
	var entries: Array = []
	var raw: Variant = pool.get("items", [])
	if raw is Array:
		for entry in raw:
			if entry is Dictionary and int(entry.get("min_day", 0)) <= day:
				entries.append(entry.duplicate(true))
	var result: Array = []
	for i in range(slot_count):
		if entries.is_empty():
			break
		var index := _weighted_index(entries, rng)
		if index < 0:
			break
		result.append(ShopOfferScript.from_dict(entries[index]))
		entries.remove_at(index)
	return result


static func _weighted_index(entries: Array, rng: RandomNumberGenerator) -> int:
	if entries.is_empty():
		return -1
	var total := 0
	for entry in entries:
		total += max(0, int(entry.get("weight", 1)))
	if total <= 0:
		return rng.randi_range(0, entries.size() - 1)
	var roll := rng.randi_range(1, total)
	var running := 0
	for i in range(entries.size()):
		running += max(0, int(entries[i].get("weight", 1)))
		if roll <= running:
			return i
	return entries.size() - 1


func to_dict() -> Dictionary:
	var slot_data: Array = []
	for offer in slots:
		if offer != null and offer.has_method("to_dict"):
			slot_data.append(offer.to_dict())
	return {
		"shop_id": shop_id,
		"slots": slot_data,
		"refresh_count_today": refresh_count_today,
		"last_refresh_day": last_refresh_day,
	}


static func from_dict(data: Dictionary):
	var inv = load("res://scripts/shop/shop_inventory.gd").new()
	inv.shop_id = str(data.get("shop_id", ""))
	inv.refresh_count_today = int(data.get("refresh_count_today", 0))
	inv.last_refresh_day = int(data.get("last_refresh_day", 0))
	var raw_slots: Variant = data.get("slots", [])
	if raw_slots is Array:
		for entry in raw_slots:
			if entry is Dictionary:
				inv.slots.append(ShopOfferScript.from_dict(entry))
	return inv
