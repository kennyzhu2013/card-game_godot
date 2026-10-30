class_name AuctionService
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")
const CardScript = preload("res://scripts/combat/card.gd")

const AUCTION_ID := "misty_port_weekly"
const EARLY_POOL := "res://data/minigames/auctions/auction_pool_early.json"
const MID_POOL := "res://data/minigames/auctions/auction_pool_mid.json"


func can_start(game_state, auction_id: String = AUCTION_ID) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if auction_id != AUCTION_ID:
		return {"ok": false, "reason": "missing_definition", "id": auction_id}
	if int(game_state.day) % 7 != 6 or str(game_state.time_of_day) != "night":
		return {"ok": false, "reason": "schedule_locked"}
	if _weekly_count(game_state, auction_id) >= 1:
		return {"ok": false, "reason": "weekly_limit", "limit": 1}
	if int(game_state.ap) < ApServiceScript.auction_cost():
		return {"ok": false, "reason": "ap_short", "cost": ApServiceScript.auction_cost(), "remaining": int(game_state.ap)}
	return {"ok": true}


func start_auction(game_state, auction_id: String = AUCTION_ID, options: Dictionary = {}) -> Dictionary:
	var check := can_start(game_state, auction_id)
	if not bool(check.get("ok", false)):
		return check
	game_state.spend_ap(ApServiceScript.auction_cost())
	var lots := generate_lots(game_state, auction_id, int(options.get("lot_count", -1)))
	var player_bids: Array = options.get("player_bids", []) if options.get("player_bids", []) is Array else []
	var ai_rolls_by_lot: Array = options.get("ai_rolls", []) if options.get("ai_rolls", []) is Array else []
	var results: Array = []
	for i in lots.size():
		var lot: Dictionary = lots[i]
		var bid := int(player_bids[i]) if i < player_bids.size() else 0
		var rolls: Array = ai_rolls_by_lot[i] if i < ai_rolls_by_lot.size() and ai_rolls_by_lot[i] is Array else [0.5, 0.75]
		results.append(settle_lot(game_state, lot, {"player_bid": bid, "ai_rolls": rolls, "spend_ap": false}))
	_record_weekly_use(game_state, auction_id)
	return {"ok": true, "id": auction_id, "lots": lots, "results": results}


func generate_lots(game_state, auction_id: String = AUCTION_ID, lot_count: int = -1) -> Array:
	var definition := _load_pool(game_state, auction_id)
	var lots: Array = definition.get("lots", []) if definition.get("lots", []) is Array else []
	var count := lots.size()
	if lot_count > 0:
		count = mini(count, lot_count)
	var result: Array = []
	for i in range(count):
		if lots[i] is Dictionary:
			result.append((lots[i] as Dictionary).duplicate(true))
	return result


func settle_lot(game_state, lot: Dictionary, options: Dictionary) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var spend_ap := bool(options.get("spend_ap", true))
	if spend_ap:
		if int(game_state.ap) < ApServiceScript.auction_cost():
			return {"ok": false, "reason": "ap_short", "cost": ApServiceScript.auction_cost(), "remaining": int(game_state.ap)}
	var player_bid := int(options.get("player_bid", 0))
	var ai_rolls: Array = options.get("ai_rolls", []) if options.get("ai_rolls", []) is Array else []
	var ai_bids: Array[int] = []
	for roll in ai_rolls:
		ai_bids.append(ai_bid_for(lot, float(roll)))
	var highest_ai := 0
	for bid in ai_bids:
		highest_ai = maxi(highest_ai, int(bid))
	var won := player_bid > highest_ai and player_bid >= int(lot.get("start_price", 0))
	var currency := str(lot.get("currency", "lingstones"))
	if won and not _can_pay(game_state, currency, player_bid):
		return {"ok": false, "reason": "currency_short", "currency": currency, "bid": player_bid}
	if spend_ap:
		game_state.spend_ap(ApServiceScript.auction_cost())
	if won:
		_pay(game_state, currency, player_bid)
		_grant_item(game_state, lot.get("item", {}))
	return {
		"ok": true,
		"lot_id": str(lot.get("id", "")),
		"won": won,
		"player_bid": player_bid,
		"ai_bids": ai_bids,
		"highest_ai_bid": highest_ai,
	}


func ai_bid_for(lot: Dictionary, roll: float) -> int:
	var valuation := int(lot.get("appraised_value", lot.get("start_price", 0)))
	var multiplier := 0.7 + 0.6 * clampf(roll, 0.0, 1.0)
	return int(round(float(valuation) * multiplier))


func _load_pool(game_state, auction_id: String) -> Dictionary:
	var path := EARLY_POOL
	if game_state != null and int(game_state.day) >= 8:
		path = MID_POOL
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var data: Dictionary = parsed.duplicate(true)
		data["id"] = auction_id
		return data
	return {}


func _weekly_count(game_state, auction_id: String) -> int:
	var history := _history(game_state)
	var bucket: Dictionary = history.get("weekly", {}) if history.get("weekly", {}) is Dictionary else {}
	return int(bucket.get(_weekly_key(game_state, auction_id), 0))


func _record_weekly_use(game_state, auction_id: String) -> void:
	var history := _history(game_state)
	var bucket: Dictionary = history.get("weekly", {}) if history.get("weekly", {}) is Dictionary else {}
	var key := _weekly_key(game_state, auction_id)
	bucket[key] = int(bucket.get(key, 0)) + 1
	history["weekly"] = bucket


func _history(game_state) -> Dictionary:
	if not game_state.minigame_history is Dictionary:
		game_state.minigame_history = {}
	if not game_state.minigame_history.has("weekly") or not game_state.minigame_history["weekly"] is Dictionary:
		game_state.minigame_history["weekly"] = {}
	return game_state.minigame_history


func _weekly_key(game_state, auction_id: String) -> String:
	var week_index := int(floor(float(maxi(1, int(game_state.day)) - 1) / 7.0))
	return "%d:%d:%s" % [int(game_state.cycle), week_index, auction_id]


func _can_pay(game_state, currency: String, amount: int) -> bool:
	match currency:
		"dao_pages":
			return int(game_state.dao_pages) >= amount
		_:
			return int(game_state.lingstones) >= amount


func _pay(game_state, currency: String, amount: int) -> void:
	match currency:
		"dao_pages":
			game_state.dao_pages = maxi(0, int(game_state.dao_pages) - amount)
		_:
			game_state.lingstones = maxi(0, int(game_state.lingstones) - amount)


func _grant_item(game_state, item: Variant) -> void:
	if not item is Dictionary:
		return
	var entry: Dictionary = item
	var amount := int(entry.get("amount", 1))
	match str(entry.get("type", "")):
		"brand":
			for _i in range(maxi(1, amount)):
				game_state.brands_inventory.append(BrandScript.from_dict({
					"id": str(entry.get("id", "")),
					"display_name": str(entry.get("display_name", entry.get("id", ""))),
					"pathway_affinity": "any",
					"sequence_min": 9,
					"effect_type": "auction_reward",
					"effect_payload": {},
					"description": "R25 auction reward",
				}))
		"material":
			var material_id := str(entry.get("id", ""))
			if material_id != "":
				game_state.forge_materials[material_id] = int(game_state.forge_materials.get(material_id, 0)) + maxi(1, amount)
		"dao_pages":
			game_state.dao_pages += maxi(1, amount)
		"temp_card":
			for _i in range(maxi(1, amount)):
				var card_id := str(entry.get("id", "auction_temp_card"))
				var card = CardScript.from_json({
					"id": card_id,
					"template_id": card_id,
					"display_name": str(entry.get("display_name", card_id)),
					"pathway": "fool",
					"sequence": 9,
					"rarity": str(entry.get("rarity", "rare")),
					"quality": 1,
					"energy_cost": 1,
					"combat_effect": {"damage": 4, "target": "single"},
				})
				if game_state.has_method("add_temp_card"):
					game_state.add_temp_card(card)
				else:
					game_state.temp_picked_cards.append(card)
