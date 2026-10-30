extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const AUCTION_PATH := "res://scripts/minigames/auction/auction_service.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_auction_service.gd --")
	test_auction_schedule_and_weekly_limit()
	test_ai_bid_range_uses_70_to_130_percent_valuation()
	test_player_win_settles_payment_and_grant()
	return {"passed": _passed, "failed": _failed}


func test_auction_schedule_and_weekly_limit() -> void:
	var auction = _auction()
	if auction == null:
		return
	assert_true(auction.has_method("can_start"), "AuctionService exposes can_start")
	var gs = _state()
	gs.day = 5
	gs.time_of_day = "night"
	var locked: Dictionary = auction.call("can_start", gs, "misty_port_weekly")
	assert_true(not bool(locked.get("ok", true)), "auction blocks outside Saturday night")
	assert_eq(str(locked.get("reason", "")), "schedule_locked", "wrong schedule reports schedule_locked")
	gs.day = 6
	var open: Dictionary = auction.call("can_start", gs, "misty_port_weekly")
	assert_true(bool(open.get("ok", false)), "auction opens on Saturday night")
	assert_true(auction.has_method("start_auction"), "AuctionService exposes start_auction")
	gs.lingstones = 1000
	gs.ap = 12
	var first: Dictionary = auction.call("start_auction", gs, "misty_port_weekly", {"lot_count": 1, "player_bids": [300], "ai_rolls": [[0.0, 0.0]]})
	assert_true(bool(first.get("ok", false)), "first weekly auction settles")
	var second: Dictionary = auction.call("start_auction", gs, "misty_port_weekly", {"lot_count": 1, "player_bids": [300], "ai_rolls": [[0.0, 0.0]]})
	assert_true(not bool(second.get("ok", true)), "second weekly auction is blocked")
	assert_eq(str(second.get("reason", "")), "weekly_limit", "second weekly auction reports weekly_limit")
	gs.queue_free()


func test_ai_bid_range_uses_70_to_130_percent_valuation() -> void:
	var auction = _auction()
	if auction == null:
		return
	assert_true(auction.has_method("ai_bid_for"), "AuctionService exposes ai_bid_for")
	var lot := {"id": "lot_test", "appraised_value": 200}
	assert_eq(int(auction.call("ai_bid_for", lot, 0.0)), 140, "AI minimum bid is 70% of valuation")
	assert_eq(int(auction.call("ai_bid_for", lot, 1.0)), 260, "AI maximum bid is 130% of valuation")


func test_player_win_settles_payment_and_grant() -> void:
	var auction = _auction()
	if auction == null:
		return
	assert_true(auction.has_method("settle_lot"), "AuctionService exposes settle_lot")
	var gs = _state()
	gs.day = 6
	gs.time_of_day = "night"
	gs.lingstones = 1000
	gs.ap = 12
	var lot := {
		"id": "low_brand_lot",
		"currency": "lingstones",
		"start_price": 200,
		"appraised_value": 240,
		"item": {"type": "brand", "id": "auction_low_brand", "amount": 1},
	}
	var result: Dictionary = auction.call("settle_lot", gs, lot, {"player_bid": 300, "ai_rolls": [0.0, 0.1]})
	assert_true(bool(result.get("ok", false)), "auction lot settles")
	assert_true(bool(result.get("won", false)), "player wins when bid beats AI")
	assert_eq(int(gs.lingstones), 700, "winning auction subtracts player bid")
	assert_eq(gs.brands_inventory.size(), 1, "winning auction grants item")
	if gs.brands_inventory.size() > 0:
		assert_eq(str(gs.brands_inventory[0].id), "auction_low_brand", "auction grant uses structured brand id")
	assert_eq(int(gs.ap), 11, "auction participation spends 1 AP")
	gs.queue_free()


func _auction():
	var script = load(AUCTION_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "AuctionService script loads and can instantiate")
		return null
	return script.new()


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
