extends RefCounted

const HUB_SCENE := "res://scenes/hub/hub.tscn"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_casino_hub_path.gd --")
	await test_misty_port_casino_hotspot_opens_playable_menu()
	await test_fate_cards_crossing_church_threshold_surfaces_mainline_dialog()
	await test_misty_port_auction_hotspot_opens_auction_panel()
	return {"passed": _passed, "failed": _failed}


func test_misty_port_casino_hotspot_opens_playable_menu() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_city_state()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "misty_port", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Hub debug path opens misty_port CityScene")
	var button = city.find_child("Hotspot_casino_eel_fan", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes casino_eel_fan hotspot")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("CasinoMenuDialog")
	assert_true(dialog != null and dialog.visible, "casino hotspot opens CasinoMenuDialog")
	if dialog != null:
		var text := str(dialog.dialog_text)
		assert_true(_is_clean_player_text(text), "casino menu uses Chinese player-facing text")
		assert_true(text.find("骰盅") >= 0, "casino menu includes dice game by Chinese name")
		assert_true(text.find("塔罗占卜") >= 0, "casino menu includes tarot game by Chinese name")
		assert_true(text.find("命运牌局") >= 0, "casino menu includes fate game by Chinese name")
		var play_button = dialog.find_child("CasinoButton_dice_cup", true, false)
		assert_true(play_button is Button, "casino menu exposes a dice play button")
		if play_button is Button:
			assert_eq(str(play_button.text), "骰盅", "casino dice button uses Chinese label")
			var before_ap := int(GameState.ap)
			var before_lingstones := int(GameState.lingstones)
			play_button.pressed.emit()
			await Engine.get_main_loop().process_frame
			assert_eq(int(GameState.ap), before_ap - 1, "clicking dice button spends one AP")
			assert_true(int(GameState.lingstones) != before_lingstones, "clicking dice button settles lingstones")
			assert_true(str(dialog.dialog_text).find("本局结果") >= 0 and str(dialog.dialog_text).find("大胜") >= 0, "dice button writes Chinese settlement result")
	var placeholder = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(placeholder == null or not placeholder.visible, "casino hotspot no longer uses generic placeholder")
	hub.queue_free()
	GameState.from_dict(previous)


func test_fate_cards_crossing_church_threshold_surfaces_mainline_dialog() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_city_state()
	GameState.church_awareness = 24
	GameState.church_awareness_events.clear()
	GameState.minigame_history = {}
	GameState.set_ai_gm_service(FakeThresholdAIGMService.new())
	var hub = await _hub()
	if hub == null:
		GameState.set_ai_gm_service(null)
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "misty_port", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var casino_button = city.find_child("Hotspot_casino_eel_fan", true, false) if city != null else null
	assert_true(casino_button is Button, "CityScene exposes casino_eel_fan hotspot for church threshold path")
	if casino_button is Button:
		casino_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("CasinoMenuDialog")
	assert_true(dialog != null and dialog.visible, "casino hotspot opens CasinoMenuDialog before fate_cards")
	var fate_button = dialog.find_child("CasinoButton_fate_cards", true, false) if dialog != null else null
	assert_true(fate_button is Button, "casino menu exposes fate_cards play button")
	if fate_button is Button:
		fate_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var threshold_dialog = hub.get_node_or_null("MainlineDialog")
	assert_true(threshold_dialog != null and threshold_dialog.visible, "fate_cards threshold crossing opens a visible mainline-style dialog")
	if threshold_dialog != null:
		var text := str(threshold_dialog.dialog_text)
		assert_true(text.contains("教会阈值旁白"), "church threshold dialog surfaces AI GM text")
		assert_true(text.contains("教会"), "church threshold dialog is readable player-facing Chinese")
	assert_true(dialog == null or not dialog.visible, "fate_cards threshold closes casino menu before showing mainline dialog")
	assert_true(_has_threshold(GameState, 25), "fate_cards crossing records the church awareness threshold")
	hub.queue_free()
	GameState.set_ai_gm_service(null)
	GameState.from_dict(previous)


func test_misty_port_auction_hotspot_opens_auction_panel() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_city_state()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "misty_port", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var button = city.find_child("Hotspot_auction_smuggler", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes auction_smuggler hotspot on Saturday night")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("AuctionDialog")
	assert_true(dialog != null and dialog.visible, "auction hotspot opens AuctionDialog")
	if dialog != null:
		assert_true(_is_clean_player_text(str(dialog.dialog_text)) and str(dialog.dialog_text).find("拍卖") >= 0, "auction dialog uses Chinese player-facing text")
		var start_button = dialog.find_child("AuctionButton_start", true, false)
		assert_true(start_button is Button, "auction dialog exposes a start button")
		if start_button is Button:
			var before_ap := int(GameState.ap)
			start_button.pressed.emit()
			await Engine.get_main_loop().process_frame
			assert_eq(int(GameState.ap), before_ap - 1, "clicking auction button spends one AP")
			assert_true(str(dialog.dialog_text).find("拍卖结果") >= 0, "auction button writes Chinese settlement result")
	hub.queue_free()
	GameState.from_dict(previous)


func _setup_global_city_state() -> void:
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.sequence = 9
	GameState.ap = 12
	GameState.lingstones = 1000
	GameState.current_district = "misty_port"


func _hub() -> Control:
	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _has_threshold(gs, threshold: int) -> bool:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return true
	return false


class FakeThresholdAIGMService:
	extends RefCounted

	func call_ai_gm(_ctx) -> String:
		return "教会阈值旁白"


func _is_clean_player_text(value: String) -> bool:
	if value.strip_edges() == "":
		return false
	for fragment in [
		"dice_cup",
		"tarot_divination",
		"fate_cards",
		"casino_eel_fan",
		"npc_id=",
		"open",
		"locked:",
		"misty_port_weekly",
		"auction_id=",
		"status=",
		"results=",
		"grade=",
	]:
		if value.find(fragment) >= 0:
			return false
	return _has_cjk(value)


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


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
