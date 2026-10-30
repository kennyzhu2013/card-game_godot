extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CitySceneScript = preload("res://scripts/world/city_scene.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")

const LOCATION_DIR := "res://data/locations"
const EXPECTED := {
	"shadow_alley": {
		"count": 6,
		"render_count": 8,
		"visible_at": {"day": 3, "time_of_day": "night", "sequence": 9, "nodes": []},
		"hotspots": [
			{"id": "tower_entry_shadow_alley", "type": "tower", "payload": {"tower_template": "shadow_alley_small"}},
			{"id": "npc_old_li", "type": "npc", "payload": {"npc_id": "old_li"}},
			{"id": "npc_xiao_ran", "type": "npc", "payload": {"npc_id": "xiao_ran"}},
			{"id": "shop_blackmarket", "type": "shop", "payload": {"shop_id": "donen_blackmarket"}},
			{"id": "rumor_streettalker", "type": "rumor", "payload": {"rumor_pool": "shadow_alley_rumors"}},
			{"id": "job_errand_board", "type": "minigame_job", "payload": {"job_id": "errand_runner"}},
		],
	},
	"steelworks": {
		"count": 5,
		"visible_at": {"day": 4, "time_of_day": "morning", "sequence": 9, "nodes": []},
		"hotspots": [
			{"id": "tower_entry_steelworks", "type": "tower", "payload": {"tower_template": "steel_small"}},
			{"id": "npc_martha", "type": "npc", "payload": {"npc_id": "martha_rich"}},
			{"id": "npc_peter_furnace", "type": "npc", "payload": {"npc_id": "peter_furnace"}},
			{"id": "job_factory_shift", "type": "minigame_job", "payload": {"job_id": "factory_shift"}},
			{"id": "rumor_factory_tabloid", "type": "rumor", "payload": {"rumor_pool": "steelworks_tabloid"}},
		],
	},
	"misty_port": {
		"count": 8,
		"render_count": 9,
		"visible_at": {"day": 6, "time_of_day": "night", "sequence": 9, "nodes": []},
		"hotspots": [
			{"id": "tower_entry_misty_port", "type": "tower", "payload": {"tower_template": "mist_small"}},
			{"id": "npc_carl_smuggler", "type": "npc", "payload": {"npc_id": "carl_smuggler"}},
			{"id": "npc_eel_fan", "type": "npc", "payload": {"npc_id": "eel_fan"}},
			{"id": "npc_vera_lighthouse", "type": "npc", "payload": {"npc_id": "vera_lighthouse"}},
			{"id": "casino_eel_fan", "type": "minigame_casino", "payload": {"npc_id": "eel_fan", "game_ids": ["dice_cup", "tarot_divination", "fate_cards"]}},
			{"id": "auction_smuggler", "type": "minigame_auction", "payload": {"auction_id": "misty_port_weekly"}},
			{"id": "job_dock_shift", "type": "minigame_job", "payload": {"job_id": "dock_shift"}},
			{"id": "rumor_misty_port_tavern", "type": "rumor", "payload": {"rumor_pool": "misty_port_rumors"}},
		],
	},
	"sacred_seven": {
		"count": 6,
		"render_count": 7,
		"visible_at": {"day": 7, "time_of_day": "morning", "sequence": 9, "nodes": []},
		"hotspots": [
			{"id": "tower_entry_sacred_seven", "type": "tower", "payload": {"tower_template": "saints_small"}},
			{"id": "npc_brendan", "type": "npc", "payload": {"npc_id": "brendan"}},
			{"id": "npc_thomas_priest", "type": "npc", "payload": {"npc_id": "thomas_priest"}},
			{"id": "drill_confess_innocent", "type": "minigame_drill", "payload": {"drill_id": "confess_innocent"}},
			{"id": "job_worship_observation", "type": "minigame_job", "payload": {"job_id": "worship_observation"}},
			{"id": "rumor_sacred_notice", "type": "rumor", "payload": {"rumor_pool": "sacred_seven_rumors"}},
		],
	},
	"stone_tower": {
		"count": 5,
		"visible_at": {"day": 8, "time_of_day": "noon", "sequence": 8, "nodes": []},
		"hotspots": [
			{"id": "tower_entry_stone_tower", "type": "tower", "payload": {"tower_template": "stone_medium"}},
			{"id": "npc_marquis_eng", "type": "npc", "payload": {"npc_id": "marquis_eng"}},
			{"id": "npc_hanna_gardener", "type": "npc", "payload": {"npc_id": "hanna_gardener"}},
			{"id": "drill_noble_salon", "type": "minigame_drill", "payload": {"drill_id": "noble_salon"}},
			{"id": "rumor_stone_street", "type": "rumor", "payload": {"rumor_pool": "stone_tower_streets"}},
		],
	},
	"ascetic_mountain": {
		"count": 5,
		"visible_at": {"day": 12, "time_of_day": "evening", "sequence": 8, "nodes": ["node_4"]},
		"hotspots": [
			{"id": "tower_entry_ascetic_mountain", "type": "tower", "payload": {"tower_template": "ascetic_medium"}},
			{"id": "npc_pendulum", "type": "npc", "payload": {"npc_id": "pendulum"}},
			{"id": "npc_xuming_recluse", "type": "npc", "payload": {"npc_id": "xuming_recluse"}},
			{"id": "job_mountain_solitary_walk", "type": "minigame_job", "payload": {"job_id": "mountain_solitary_walk"}},
			{"id": "rumor_ascetic_teahouse", "type": "rumor", "payload": {"rumor_pool": "ascetic_mountain_rumors"}},
		],
	},
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_district_hotspots_full.gd --")
	test_slice3_hotspot_data_replaces_hidden_placeholders()
	test_visible_when_supports_slice3_day_and_relation_gates()
	await test_city_scene_renders_full_hotspot_sets()
	await test_city_scene_adds_dynamic_npc_presence_hotspots()
	await test_city_scene_surfaces_church_awareness_and_available_side_chain()
	await test_hub_dispatches_shop_rumor_and_minigame_hotspots()
	await test_debug_panel_jumps_to_any_district_and_time()
	return {"passed": _passed, "failed": _failed}


func test_slice3_hotspot_data_replaces_hidden_placeholders() -> void:
	var total := 0
	for district_id in EXPECTED.keys():
		var data := _json(district_id)
		var expected: Dictionary = EXPECTED[district_id]
		var hotspots: Array = data.get("hotspots", [])
		total += hotspots.size()
		assert_eq(hotspots.size(), int(expected.get("count", 0)), "%s hotspot count matches Slice 3 T1 table" % district_id)
		for expected_hotspot in expected.get("hotspots", []):
			var hotspot := _hotspot_by_id(hotspots, str(expected_hotspot.get("id", "")))
			assert_true(not hotspot.is_empty(), "%s includes hotspot %s" % [district_id, str(expected_hotspot.get("id", ""))])
			if hotspot.is_empty():
				continue
			assert_eq(str(hotspot.get("type", "")), str(expected_hotspot.get("type", "")), "%s %s type is structured" % [district_id, str(hotspot.get("id", ""))])
			assert_true(bool(hotspot.get("visible", true)), "%s %s is not hard-disabled" % [district_id, str(hotspot.get("id", ""))])
			assert_true(str(hotspot.get("visible_when", "always")) != "false", "%s %s has real visible_when" % [district_id, str(hotspot.get("id", ""))])
			assert_true(str(hotspot.get("label", "")).find("占位") < 0, "%s %s label is not placeholder text" % [district_id, str(hotspot.get("id", ""))])
			_assert_payload_contains(hotspot.get("payload", {}), expected_hotspot.get("payload", {}), "%s %s" % [district_id, str(hotspot.get("id", ""))])
	assert_eq(total, 35, "Slice 4 runtime audit table totals 35 dynamic hotspots")


func test_visible_when_supports_slice3_day_and_relation_gates() -> void:
	var gs = _state()
	gs.day = 6
	gs.time_of_day = "night"
	gs.npc_relations["old_li"] = {"trust": 45, "suspicion": 5}
	assert_true(HotspotResolverScript.evaluate_visible_when("day % 7 == 6 AND time_of_day == 'night'", gs), "weekly auction modulo day gate passes")
	gs.day = 5
	assert_true(not HotspotResolverScript.evaluate_visible_when("day % 7 == 6 AND time_of_day == 'night'", gs), "weekly auction modulo day gate fails on other days")
	assert_true(HotspotResolverScript.evaluate_visible_when("npc.old_li.trust >= 40 AND pollution <= 30", gs), "relation and pollution gate passes")
	gs.pollution = 80
	assert_true(not HotspotResolverScript.evaluate_visible_when("npc.old_li.trust >= 40 AND pollution <= 30", gs), "pollution part can hide hotspot")


func test_city_scene_renders_full_hotspot_sets() -> void:
	for district_id in EXPECTED.keys():
		var city = await _city()
		if city == null:
			return
		var gs = _state_for_visible_at(EXPECTED[district_id].get("visible_at", {}))
		city.open_district(district_id, gs)
		await Engine.get_main_loop().process_frame
		var layer = city.find_child("HotspotLayer", true, false)
		assert_eq(_button_count(layer), int(EXPECTED[district_id].get("render_count", EXPECTED[district_id].get("count", 0))), "%s renders all static and NPC-presence hotspots in its active window" % district_id)
		city.queue_free()


func test_city_scene_adds_dynamic_npc_presence_hotspots() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 6
	gs.time_of_day = "night"
	gs.sequence = 9
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	var pendulum_button = city.find_child("Hotspot_npc_pendulum", true, false)
	var widow_button = city.find_child("Hotspot_npc_widow_isa", true, false)
	assert_true(pendulum_button is Button, "shadow_alley night adds Pendulum from NPC city_presence")
	assert_true(widow_button is Button, "shadow_alley night adds Widow Isa from NPC city_presence")
	if pendulum_button is Button:
		assert_true(str((pendulum_button as Button).text).find("钟摆") >= 0 or str((pendulum_button as Button).tooltip_text).find("pendulum") >= 0, "dynamic Pendulum hotspot has player-facing identity")
	city.queue_free()

	var previous: Dictionary = GameState.to_dict()
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.sequence = 9
	GameState.current_district = "shadow_alley"
	GameState.accepted_commissions.clear()
	GameState.completed_commissions.clear()
	GameState.available_commissions.clear()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var hub_city = hub.get_node_or_null("CityScene")
	var hub_pendulum = hub_city.find_child("Hotspot_npc_pendulum", true, false) if hub_city != null else null
	assert_true(hub_pendulum is Button, "Hub city path exposes dynamic Pendulum hotspot")
	if hub_pendulum is Button:
		hub_pendulum.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "dynamic Pendulum hotspot opens NPC dialogue")
	assert_true(_press_dialog_button(dialog, "NpcEventMenuButton_pendulum"), "dynamic Pendulum dialogue exposes event menu")
	await Engine.get_main_loop().process_frame
	var commission_button = dialog.find_child("NpcCommissionButton_commission_halfmoon_message_001", true, false) if dialog != null else null
	assert_true(commission_button is Button, "dynamic Pendulum dialogue exposes halfmoon message commission")
	hub.queue_free()
	GameState.from_dict(previous)


func test_city_scene_surfaces_church_awareness_and_available_side_chain() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 4
	gs.time_of_day = "night"
	gs.sequence = 9
	gs.ap = 12
	gs.church_awareness = 31
	gs.current_district = "shadow_alley"
	gs.daodian["completed_main_story_nodes"] = ["node_2"]
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	var church_label = city.find_child("ChurchAwarenessLabel", true, false)
	assert_true(church_label is Label, "CityScene topbar exposes persistent church awareness")
	if church_label is Label:
		assert_true(str(church_label.text).contains("\u6559\u4f1a") and str(church_label.text).contains("31"), "CityScene church awareness status shows current value")
	var side_button = city.find_child("SideChainButton_widow_child_chain", true, false)
	assert_true(side_button is Button, "CityScene marks an available side-chain encounter in the current district")
	if side_button is Button:
		assert_true(str(side_button.text).contains("\u652f\u7ebf") and str(side_button.text).contains("\u5be1"), "side-chain marker names the branch instead of relying on random spawn")
		assert_true(str(side_button.tooltip_text).contains("\u906d\u9047") and str(side_button.tooltip_text).find("widow_child_chain") < 0, "side-chain tooltip maps to playable encounter content without raw ids")
		side_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var runner = city.find_child("EncounterRunner", true, false)
	assert_true(runner != null and bool(runner.visible), "pressing side-chain marker starts the EncounterRunner")
	city.queue_free()


func test_hub_dispatches_shop_rumor_and_minigame_hotspots() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.lingstones = 1000
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_on_city_hotspot_selected", {"type": "shop", "label": "唐恩黑市", "payload": {"shop_id": "donen_blackmarket"}})
	await Engine.get_main_loop().process_frame
	var black_market = hub.get_node_or_null("BlackMarket")
	assert_true(black_market != null and black_market.visible, "shop hotspot opens the black market panel")
	if black_market != null:
		black_market.hide()
	await _assert_dialog_dispatch(hub, {"type": "rumor", "label": "街角说书人", "payload": {"rumor_pool": "shadow_alley_rumors"}}, "RumorDialog", "听到", "rumor hotspot opens real intel dialog")
	await _assert_dialog_dispatch(hub, {"type": "minigame_casino", "label": "鳗鱼·凡的赌窟", "payload": {"npc_id": "eel_fan", "game_ids": ["dice_cup", "tarot_divination", "fate_cards"]}}, "CasinoMenuDialog", "骰盅", "casino hotspot opens playable game menu")
	await _assert_dialog_dispatch(hub, {"type": "minigame_job", "label": "工厂打工", "payload": {"job_id": "factory_shift"}}, "JobDialog", "工厂打工", "job hotspot opens playable job dialog")
	await _assert_dialog_dispatch(hub, {"type": "minigame_drill", "label": "贵族沙龙演练", "payload": {"drill_id": "noble_salon"}}, "DrillDialog", "贵族沙龙演练", "drill hotspot opens playable drill dialog")
	await _assert_dialog_dispatch(hub, {"type": "minigame_auction", "label": "走私者拍卖", "payload": {"auction_id": "misty_port_weekly"}}, "AuctionDialog", "拍卖", "auction hotspot opens playable auction dialog")
	hub.queue_free()
	GameState.from_dict(previous)


func test_debug_panel_jumps_to_any_district_and_time() -> void:
	var previous: Dictionary = GameState.to_dict()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var debug = hub.get_node_or_null("DebugPanel")
	assert_true(debug != null and debug.has_method("jump_to_city_time"), "debug panel exposes jump_to_city_time")
	if debug != null and debug.has_method("jump_to_city_time"):
		debug.call("jump_to_city_time", "misty_port", "night")
		await Engine.get_main_loop().process_frame
		var city = hub.get_node_or_null("CityScene")
		assert_true(city != null and city.visible, "debug jump opens CityScene")
		assert_eq(str(GameState.current_district), "misty_port", "debug jump writes current district")
		assert_eq(str(GameState.time_of_day), "night", "debug jump writes time segment")
	hub.queue_free()
	GameState.from_dict(previous)


func _assert_placeholder_dispatch(hub, hotspot: Dictionary, expected_fragment: String, message: String) -> void:
	hub.call("_on_city_hotspot_selected", hotspot)
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(dialog != null and dialog.visible, "%s opens placeholder dialog" % message)
	if dialog != null:
		assert_true(str(dialog.dialog_text).find(expected_fragment) >= 0, message)
		dialog.hide()


func _assert_dialog_dispatch(hub, hotspot: Dictionary, dialog_name: String, expected_fragment: String, message: String) -> void:
	hub.call("_on_city_hotspot_selected", hotspot)
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null(dialog_name)
	assert_true(dialog != null and dialog.visible, "%s opens %s" % [message, dialog_name])
	if dialog != null:
		assert_true(str(dialog.dialog_text).find(expected_fragment) >= 0, message)
		dialog.hide()


func _assert_payload_contains(actual_payload: Variant, expected_payload: Variant, message: String) -> void:
	assert_true(actual_payload is Dictionary, "%s payload is dictionary" % message)
	assert_true(expected_payload is Dictionary, "%s expected payload is dictionary" % message)
	if not actual_payload is Dictionary or not expected_payload is Dictionary:
		return
	for key in expected_payload.keys():
		assert_true(actual_payload.has(key), "%s payload has %s" % [message, str(key)])
		if not actual_payload.has(key):
			continue
		var expected_value = expected_payload[key]
		var actual_value = actual_payload[key]
		if expected_value is Array:
			assert_true(actual_value is Array, "%s %s payload is array" % [message, str(key)])
			if actual_value is Array:
				for item in expected_value:
					assert_true(item in actual_value, "%s %s payload includes %s" % [message, str(key), str(item)])
		else:
			assert_eq(actual_value, expected_value, "%s %s payload matches" % [message, str(key)])


func _json(district_id: String) -> Dictionary:
	var path := "%s/%s.json" % [LOCATION_DIR, district_id]
	if not FileAccess.file_exists(path):
		assert_true(false, "%s exists" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _hotspot_by_id(hotspots: Array, hotspot_id: String) -> Dictionary:
	for hotspot in hotspots:
		if hotspot is Dictionary and str(hotspot.get("id", "")) == hotspot_id:
			return hotspot
	return {}


func _state() -> Object:
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _state_for_visible_at(spec: Dictionary) -> Object:
	var gs = _state()
	gs.day = int(spec.get("day", 1))
	gs.time_of_day = str(spec.get("time_of_day", "morning"))
	gs.sequence = int(spec.get("sequence", 9))
	gs.pollution = int(spec.get("pollution", 0))
	gs.daodian["completed_main_story_nodes"] = spec.get("nodes", [])
	return gs


func _city() -> Control:
	var scene = load("res://scenes/world/city_scene.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "city_scene loads")
		return null
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	return city


func _hub() -> Control:
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _button_count(node) -> int:
	if node == null:
		return 0
	var count := 0
	for child in node.get_children():
		if child is Button:
			count += 1
	return count


func _press_dialog_button(dialog, button_name: String) -> bool:
	if dialog == null:
		return false
	var button = dialog.find_child(button_name, true, false)
	if button is Button:
		button.pressed.emit()
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
