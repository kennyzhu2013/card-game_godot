extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const SERVICE_PATH := "res://scripts/minigames/minigame_service.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_minigame_service.gd --")
	test_loads_casino_and_auction_definitions()
	test_dice_daily_limit_blocks_sixth_round()
	test_outcome_rewards_dispatch_to_game_state()
	return {"passed": _passed, "failed": _failed}


func test_loads_casino_and_auction_definitions() -> void:
	var service = _service()
	if service == null:
		return
	assert_true(service.has_method("load_definition"), "MinigameService exposes load_definition")
	var dice: Dictionary = service.call("load_definition", "dice_cup")
	assert_eq(str(dice.get("id", "")), "dice_cup", "dice_cup definition loads by structured id")
	assert_eq(str(dice.get("type", "")), "casino", "dice_cup is a casino minigame")
	assert_eq(int(dice.get("daily_limit", 0)), 5, "dice_cup has R25 daily_limit 5")
	var auction: Dictionary = service.call("load_definition", "misty_port_weekly")
	assert_eq(str(auction.get("id", "")), "misty_port_weekly", "weekly auction definition loads by structured id")
	assert_eq(str(auction.get("type", "")), "auction", "misty_port_weekly is an auction minigame")
	assert_eq(int(auction.get("weekly_limit", 0)), 1, "auction has weekly_limit 1")


func test_dice_daily_limit_blocks_sixth_round() -> void:
	var service = _service()
	if service == null:
		return
	assert_true(service.has_method("start_game"), "MinigameService exposes start_game")
	var gs = _state()
	gs.lingstones = 1000
	gs.ap = 12
	for i in range(5):
		var result: Dictionary = service.call("start_game", gs, "dice_cup", {"bet": 3, "choice": "big", "dice": [4, 4, 3]})
		assert_true(bool(result.get("ok", false)), "dice round %d starts and settles" % [i + 1])
	var blocked: Dictionary = service.call("start_game", gs, "dice_cup", {"bet": 3, "choice": "big", "dice": [4, 4, 3]})
	assert_true(not bool(blocked.get("ok", true)), "sixth dice round is blocked")
	assert_eq(str(blocked.get("reason", "")), "daily_limit", "sixth dice round reports daily_limit")
	gs.queue_free()


func test_outcome_rewards_dispatch_to_game_state() -> void:
	var service = _service()
	if service == null:
		return
	assert_true(service.has_method("apply_rewards"), "MinigameService exposes apply_rewards")
	var gs = _state()
	gs.lingstones = 10
	gs.dao_pages = 0
	gs.church_awareness = 0
	var result: Dictionary = service.call("apply_rewards", gs, [
		{"type": "lingstones", "amount": 17},
		{"type": "material", "id": "mist_salt", "amount": 2},
		{"type": "dao_pages", "amount": 1},
		{"type": "church_awareness", "amount": 5},
		{"type": "suspicion_delta", "npc_id": "eel_fan", "amount": 3},
		{"type": "brand", "id": "auction_low_brand", "amount": 1},
	])
	assert_true(bool(result.get("ok", false)), "apply_rewards returns ok")
	assert_eq(int(gs.lingstones), 27, "lingstones reward applies")
	assert_eq(int(gs.forge_materials.get("mist_salt", 0)), 2, "material reward applies")
	assert_eq(int(gs.dao_pages), 1, "dao_pages reward applies")
	assert_eq(int(gs.church_awareness), 5, "church_awareness reward applies")
	var relation = gs.npc_relations.get("eel_fan", null)
	assert_true(relation != null, "suspicion_delta creates NPC relation state")
	if relation != null:
		assert_eq(int(relation.suspicion), 3, "suspicion_delta applies to structured npc_id")
	assert_eq(gs.brands_inventory.size(), 1, "brand reward creates one brand")
	if gs.brands_inventory.size() > 0:
		assert_eq(str(gs.brands_inventory[0].id), "auction_low_brand", "brand reward stores structured brand id")
	gs.queue_free()


func _service():
	var script = load(SERVICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "MinigameService script loads and can instantiate")
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
