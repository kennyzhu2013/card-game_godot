extends RefCounted

const DistrictSelectScript = preload("res://scripts/ui/district_select.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const CITY_SCENE_PATH := "res://scenes/world/city_scene.tscn"

var _passed := 0
var _failed := 0
var _requested_district_id := ""


func run() -> Dictionary:
	print("\n-- test_district_entry_selector.gd --")
	test_selector_entries_are_loaded_from_r23_location_jsons()
	test_unlock_status_uses_location_unlock_condition_text()
	test_enter_district_returns_city_scene_request_without_event_dispatch()
	test_remote_ascetic_mountain_spends_two_ap_only_on_success()
	test_accepted_commission_marker_moves_district_to_top()
	await test_selector_scene_renders_six_rows_without_event_result_panel()
	await test_selector_player_facing_copy_is_chinese()
	await test_city_scene_chrome_is_chinese()
	await test_city_scene_marks_active_job_commission_hotspot()
	await test_city_scene_marks_active_tower_commission_hotspot()
	await test_city_scene_marks_main_story_hotspot()
	await test_city_scene_marks_visible_daily_district_opportunity()
	await test_city_scene_consumes_daily_district_opportunity_after_encounter_resolution()
	await test_city_scene_many_daily_opportunities_render_in_hotspot_list_not_topbar()
	await test_hub_front_door_opens_selector_then_city_scene()
	return {"passed": _passed, "failed": _failed}


func test_selector_entries_are_loaded_from_r23_location_jsons() -> void:
	var gs = _state()
	var entries := _selector_entries(gs)
	if entries.is_empty():
		return
	var ids := _entry_ids(entries)
	assert_eq(ids, ["shadow_alley", "steelworks", "misty_port", "sacred_seven", "stone_tower", "ascetic_mountain"], "selector uses the six R23 location district ids in fixed entry order")
	for entry in entries:
		assert_true(entry.has("district_id"), "entry has structured district_id")
		assert_true(entry.has("ap_to_enter"), "entry has structured ap_to_enter")
		assert_true(not entry.has("events"), "selector entry does not carry legacy events[]")


func test_unlock_status_uses_location_unlock_condition_text() -> void:
	var gs = _state()
	gs.sequence = 9
	gs.daodian["completed_main_story_nodes"] = []
	var entries := _selector_entries(gs)
	if entries.is_empty():
		return
	var stone := _entry(entries, "stone_tower")
	var ascetic := _entry(entries, "ascetic_mountain")
	assert_true(bool(stone.get("locked", false)), "stone_tower is locked at sequence 9")
	assert_true(str(stone.get("unlock_text", "")).contains("序列 8"), "stone_tower lock text names sequence 8")
	assert_true(bool(ascetic.get("locked", false)), "ascetic_mountain is locked before node_4")
	assert_true(str(ascetic.get("unlock_text", "")).contains("主线第四节点"), "ascetic_mountain lock text names mainline node 4 in Chinese")

	gs.sequence = 8
	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	entries = _selector_entries(gs)
	stone = _entry(entries, "stone_tower")
	ascetic = _entry(entries, "ascetic_mountain")
	assert_true(not bool(stone.get("locked", true)), "stone_tower unlocks at sequence 8")
	assert_true(not bool(ascetic.get("locked", true)), "ascetic_mountain unlocks after node_4")


func test_enter_district_returns_city_scene_request_without_event_dispatch() -> void:
	var gs = _state()
	gs.ap = 0
	var result := _enter_district("shadow_alley", gs)
	if result.is_empty():
		return
	assert_true(bool(result.get("ok", false)), "shadow_alley entry succeeds with 0 AP")
	assert_eq(str(result.get("scene_path", "")), CITY_SCENE_PATH, "entry result targets city_scene.tscn")
	assert_eq(str(result.get("district_id", "")), "shadow_alley", "entry result carries district_id")
	assert_eq(str(gs.current_district), "shadow_alley", "entry writes current_district")
	assert_eq(int(gs.ap), 0, "ordinary district entry does not spend AP")
	assert_true(not result.has("event_kind"), "entry result does not dispatch a legacy event")
	assert_true(not result.has("tower"), "entry result does not dispatch a tower")


func test_remote_ascetic_mountain_spends_two_ap_only_on_success() -> void:
	var gs = _state()
	gs.ap = 1
	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	var short := _enter_district("ascetic_mountain", gs)
	if short.is_empty():
		return
	assert_true(not bool(short.get("ok", true)), "ascetic_mountain rejects AP short")
	assert_eq(str(short.get("reason", "")), "ap_short", "ascetic AP short reason")
	assert_eq(int(gs.ap), 1, "failed remote entry does not spend AP")

	gs.ap = 5
	var ok := _enter_district("ascetic_mountain", gs)
	assert_true(bool(ok.get("ok", false)), "ascetic_mountain entry succeeds after node_4 with enough AP")
	assert_eq(int(ok.get("ap_cost", -1)), 2, "ascetic_mountain reports 2 AP remote travel cost")
	assert_eq(int(gs.ap), 3, "ascetic_mountain spends exactly 2 AP")
	assert_eq(str(gs.current_district), "ascetic_mountain", "ascetic_mountain writes current_district")


func test_accepted_commission_marker_moves_district_to_top() -> void:
	var gs = _state()
	gs.available_commissions = [
		{
			"id": "steel_missing_case",
			"title": "铸钢区·失踪案",
			"dispatch_target": {"district_id": "steelworks"},
		},
	]
	gs.accepted_commissions.clear()
	gs.accepted_commissions.append("steel_missing_case")
	var entries := _selector_entries(gs)
	if entries.is_empty():
		return
	assert_eq(str(entries[0].get("district_id", "")), "steelworks", "accepted commission district is sorted to top")
	assert_true(bool(entries[0].get("has_commission_marker", false)), "accepted commission district is highlighted")
	assert_eq(str(entries[0].get("commission_id", "")), "steel_missing_case", "entry carries commission id")
	assert_true(str(entries[0].get("commission_title", "")).contains("失踪案"), "entry carries commission title")


func test_selector_scene_renders_six_rows_without_event_result_panel() -> void:
	var selector = await _instantiate_selector()
	if selector == null:
		return
	selector.open(_state())
	await Engine.get_main_loop().process_frame
	var rows := _find_named_buttons(selector, "DistrictRow_")
	assert_eq(rows.size(), 6, "selector scene renders exactly six district rows")
	assert_true(selector.find_child("DistrictResultPanel", true, false) == null, "selector scene has no legacy event result panel")
	var locked = selector.find_child("DistrictRow_stone_tower", true, false)
	assert_true(locked is Button and locked.disabled, "locked district row is disabled")
	if locked is Button:
		assert_true(locked.text.contains("锁定") and locked.text.contains("序列 8"), "locked row exposes Chinese unlock status")
	selector.queue_free()


func test_selector_player_facing_copy_is_chinese() -> void:
	var selector = await _instantiate_selector()
	if selector == null:
		return
	var gs = _state()
	gs.sequence = 9
	gs.daodian["completed_main_story_nodes"] = []
	selector.open(gs)
	await Engine.get_main_loop().process_frame
	var title = selector.find_child("DistrictSelectTitle", true, false)
	assert_true(title is Label and str(title.text) == "洞府前门 · 你今天去哪？", "district selector title is Chinese")
	var cancel = selector.find_child("CancelButton", true, false)
	assert_true(cancel is Button and str(cancel.text) == "取消", "district selector cancel button is Chinese")
	for row in _find_named_buttons(selector, "DistrictRow_"):
		assert_true(_is_clean_player_text(str(row.text)), "%s row is Chinese player-facing copy" % str(row.name))
		assert_true(str(row.text).find("🔒") < 0, "%s row avoids unsupported lock glyph" % str(row.name))
	selector.queue_free()


func test_city_scene_chrome_is_chinese() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 1
	gs.time_of_day = "morning"
	gs.ap = 12
	gs.ap_max = 12
	gs.lingstones = 10
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	var day_label = city.find_child("DayLabel", true, false)
	assert_true(day_label is Label and str(day_label.text) == "第 1 天", "CityScene day label is Chinese")
	var time_label = city.find_child("TimeLabel", true, false)
	assert_true(time_label is Label and str(time_label.text) == "白天", "CityScene time label is Chinese")
	var lingstones_label = city.find_child("LingstonesLabel", true, false)
	assert_true(lingstones_label is Label and str(lingstones_label.text) == "灵石 10", "CityScene lingstones label is Chinese")
	var intel = city.find_child("IntelInfoButton", true, false)
	assert_true(intel is Button and str(intel.text) == "情报 [0]" and str(intel.tooltip_text) == "暂无情报", "CityScene intel button is Chinese")
	var return_button = city.find_child("ReturnButton", true, false)
	assert_true(return_button is Button and str(return_button.text) == "返回洞府", "CityScene return button is Chinese")
	var time_button = city.find_child("TimeAdvanceButton", true, false)
	assert_true(time_button is Button and str(time_button.text) == "推进时段", "CityScene time advance button is Chinese")
	city.queue_free()


func test_city_scene_marks_active_job_commission_hotspot() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 4
	gs.time_of_day = "morning"
	gs.sequence = 8
	gs.ap = 12
	gs.available_commissions = [{
		"id": "city_marker_job",
		"display_name": "factory shift commission",
		"dispatch_target": {"kind": "job", "job_id": "factory_shift", "district": "steelworks"},
	}]
	gs.accepted_commissions.append("city_marker_job")
	gs.set_meta("commission_active_dispatch", {
		"commission_id": "city_marker_job",
		"commission_type": "gather",
		"dispatch_kind": "job",
		"dispatch_target": {"kind": "job", "job_id": "factory_shift", "district": "steelworks"},
		"district": "steelworks",
	})
	city.open_district("steelworks", gs)
	await Engine.get_main_loop().process_frame
	var layer = city.find_child("HotspotLayer", true, false)
	var button = city.find_child("Hotspot_job_factory_shift", true, false)
	assert_true(button is Button, "active job commission target hotspot is rendered")
	if button is Button:
		assert_true(str(button.text).find("\u59d4\u6258") >= 0, "active job commission hotspot text carries a commission marker")
		assert_true(str(button.tooltip_text).find("\u59d4\u6258\u76ee\u6807") >= 0 and str(button.tooltip_text).find("city_marker_job") < 0, "active job commission tooltip explains the target without raw ids")
		var status = button.find_child("StatusDot", true, false)
		assert_true(status is Label and str(status.text) == "!", "active job commission hotspot uses attention status dot")
	if layer != null and layer.get_child_count() > 0:
		assert_eq(str(layer.get_child(0).name), "Hotspot_job_factory_shift", "active job commission hotspot is moved to the top of the city list")
	city.queue_free()


func test_city_scene_marks_active_tower_commission_hotspot() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 4
	gs.time_of_day = "morning"
	gs.sequence = 8
	gs.ap = 12
	gs.available_commissions = [{
		"id": "city_marker_tower",
		"display_name": "steelworks tower commission",
		"dispatch_target": {"district": "steelworks", "tower_size": "medium", "boss": "slag_golem"},
	}]
	gs.accepted_commissions.append("city_marker_tower")
	gs.set_meta("commission_active_dispatch", {
		"commission_id": "city_marker_tower",
		"commission_type": "battle",
		"dispatch_kind": "tower",
		"dispatch_target": {"district": "steelworks", "tower_size": "medium", "boss": "slag_golem"},
		"district": "steelworks",
	})
	city.open_district("steelworks", gs)
	await Engine.get_main_loop().process_frame
	var layer = city.find_child("HotspotLayer", true, false)
	var button = city.find_child("Hotspot_tower_entry_steelworks", true, false)
	assert_true(button is Button, "active tower commission target hotspot is rendered")
	if button is Button:
		assert_true(str(button.text).find("\u59d4\u6258") >= 0, "active tower commission hotspot text carries a commission marker")
		assert_true(str(button.tooltip_text).find("\u56de\u544a\u793a\u724c") >= 0 and str(button.tooltip_text).find("city_marker_tower") < 0, "active tower commission tooltip gives return-to-board guidance without raw ids")
	if layer != null and layer.get_child_count() > 0:
		assert_eq(str(layer.get_child(0).name), "Hotspot_tower_entry_steelworks", "active tower commission hotspot is moved to the top of the city list")
	city.queue_free()


func test_city_scene_marks_main_story_hotspot() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 3
	gs.time_of_day = "night"
	gs.sequence = 9
	gs.ap = 12
	city.open_from_data({
		"$schema": "city_hotspot_v1",
		"district_id": "audit_main_story",
		"display_name": "audit",
		"ap_to_enter": 0,
		"hotspots": [{
			"id": "main_story_node2_probe",
			"label": "黑市初遇",
			"type": "main_story",
			"ap_cost": 1,
			"payload": {"node_id": "node_2_black_market", "title": "黑市初遇"},
			"visible_when": "always",
		}],
	}, gs)
	await Engine.get_main_loop().process_frame
	var button = city.find_child("Hotspot_main_story_node2_probe", true, false)
	assert_true(button is Button and button.visible and not button.disabled, "CityScene exposes visible main_story hotspot")
	if button is Button:
		assert_true(str(button.text).contains("\u4e3b\u7ebf"), "main_story hotspot text carries a visible mainline marker")
		var status = button.find_child("StatusDot", true, false)
		assert_true(status is Label and str(status.text) == "!", "main_story hotspot uses attention status dot")
	city.queue_free()


func test_city_scene_marks_visible_daily_district_opportunity() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 5
	gs.time_of_day = "night"
	gs.current_district = "misty_port"
	gs.ap = 12
	var carl = NpcKnowledgeStateScript.new()
	carl.trust = 20
	gs.npc_relations["carl_smuggler"] = carl
	city.open_district("misty_port", gs)
	await Engine.get_main_loop().process_frame
	var marker_text := _collect_button_text(city)
	assert_true(
		marker_text.contains("\u4eca\u65e5\u673a\u4f1a") or marker_text.contains("\u4eca\u65e5\u5f02\u52a8"),
		"CityScene surfaces daily district opportunity marker"
	)
	var daily_buttons := _find_named_buttons(city, "DistrictOpportunityButton_")
	var marker_button = daily_buttons[0] if not daily_buttons.is_empty() else null
	assert_true(marker_button is Button, "CityScene daily opportunity marker is a clickable hotspot")
	if marker_button is Button:
		marker_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var runner = city.find_child("EncounterRunner", true, false)
	assert_true(runner != null and runner.visible, "clicking daily district opportunity marker opens EncounterRunner")
	city.queue_free()


func test_city_scene_consumes_daily_district_opportunity_after_encounter_resolution() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 5
	gs.time_of_day = "night"
	gs.current_district = "misty_port"
	gs.ap = 12
	gs.daily_field_opportunities = {
		"day": 5,
		"seed": 50009,
		"districts": {
			"misty_port": [
				{"id": "misty_moonlight_grass", "encounter_id": "enc_misty_port_moonlight_grass", "hidden": false, "cost": {"ap": 0}},
			],
		},
	}
	city.open_district("misty_port", gs)
	await Engine.get_main_loop().process_frame
	var before_button = city.find_child("DistrictOpportunityButton_misty_moonlight_grass", true, false)
	assert_true(before_button is Button, "daily opportunity button is rendered before resolution")
	if before_button is Button:
		before_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var runner = city.find_child("EncounterRunner", true, false)
	assert_true(runner != null and runner.visible, "daily opportunity starts encounter before resolution")
	if runner != null and runner.has_method("resolve_choice"):
		var resolve_result: Dictionary = runner.call("resolve_choice", "gather")
		assert_true(bool(resolve_result.get("ok", false)), "daily opportunity encounter choice resolves")
		await Engine.get_main_loop().process_frame
	var after_button = city.find_child("DistrictOpportunityButton_misty_moonlight_grass", true, false)
	assert_true(after_button == null, "resolved daily opportunity button is removed from CityScene")
	var stored: Dictionary = gs.daily_field_opportunities if gs.daily_field_opportunities is Dictionary else {}
	var resolved: Array = stored.get("resolved_event_ids", []) if stored.get("resolved_event_ids", []) is Array else []
	assert_true(resolved.has("misty_moonlight_grass"), "resolved daily opportunity id is persisted for the day")
	city.queue_free()


func test_city_scene_many_daily_opportunities_render_in_hotspot_list_not_topbar() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 8
	gs.time_of_day = "night"
	gs.current_district = "misty_port"
	gs.ap = 12
	gs.daily_field_opportunities = {
		"day": 8,
		"seed": 80009,
		"districts": {
			"misty_port": [
				{"id": "daily_many_breeze", "encounter_id": "enc_misty_port_seabreeze", "hidden": false, "cost": {"ap": 0}},
				{"id": "daily_many_grass", "encounter_id": "enc_misty_port_moonlight_grass", "hidden": false, "cost": {"ap": 1}},
				{"id": "daily_many_manifest", "encounter_id": "enc_misty_port_carl_manifest", "hidden": false, "cost": {"ap": 1}},
				{"id": "daily_many_check", "encounter_id": "enc_misty_port_smuggler_check", "hidden": false, "cost": {"ap": 1}},
			],
		},
	}
	city.open_district("misty_port", gs)
	await Engine.get_main_loop().process_frame
	var daily_buttons := _find_named_buttons(city, "DistrictOpportunityButton_")
	assert_eq(daily_buttons.size(), 4, "CityScene renders every visible daily opportunity instead of only the first one")
	var topbar = city.find_child("TopBar", true, false)
	var list = city.find_child("DailyOpportunityList", true, false)
	assert_true(list is Control, "CityScene groups many daily opportunities under DailyOpportunityList in the scrollable hotspot area")
	if topbar is Control:
		for button in daily_buttons:
			assert_true(not _is_descendant_of(button, topbar), "daily opportunity button %s is not mounted in TopBar" % str(button.name))
		assert_true((topbar as Control).get_global_rect().size.y <= 72.0, "TopBar stays compact when many daily opportunities exist")
	if list is Control:
		for button in daily_buttons:
			assert_true(_is_descendant_of(button, list), "daily opportunity button %s is mounted in DailyOpportunityList" % str(button.name))
	city.queue_free()


func test_hub_front_door_opens_selector_then_city_scene() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_state().to_dict())
	var hub = await _instantiate_hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var door = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	if door is Button:
		door.pressed.emit()
		await Engine.get_main_loop().process_frame
	var selector = hub.get_node_or_null("DistrictSelect")
	assert_true(selector != null and selector.visible, "front door opens district selector directly")
	if selector != null:
		var shadow = selector.find_child("DistrictRow_shadow_alley", true, false)
		if shadow is Button:
			shadow.pressed.emit()
			await Engine.get_main_loop().process_frame
		else:
			assert_true(false, "shadow_alley row exists for Hub path")
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "selecting a district opens CityScene")
	if city != null:
		var title = city.find_child("DistrictNameLabel", true, false)
		assert_true(title is Label and str(title.text).contains("影巷"), "CityScene opens with selected district data")
	assert_eq(str(GameState.current_district), "shadow_alley", "Hub path records selected district")
	hub.queue_free()
	GameState.from_dict(previous)


func _selector_entries(gs) -> Array:
	if not _script_has_method(DistrictSelectScript, "selector_entries_for"):
		assert_true(false, "DistrictSelect.selector_entries_for exists")
		return []
	var probe = DistrictSelectScript.new()
	var entries = probe.call("selector_entries_for", gs)
	probe.queue_free()
	return entries if entries is Array else []


func _enter_district(district_id: String, gs) -> Dictionary:
	if not _script_has_method(DistrictSelectScript, "enter_district"):
		assert_true(false, "DistrictSelect.enter_district exists")
		return {}
	var probe = DistrictSelectScript.new()
	var result = probe.call("enter_district", district_id, gs)
	probe.queue_free()
	return result if result is Dictionary else {}


func _script_has_method(script: Script, method_name: String) -> bool:
	for method in script.get_script_method_list():
		if str(method.get("name", "")) == method_name:
			return true
	return false


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _entry_ids(entries: Array) -> Array:
	var ids: Array = []
	for entry in entries:
		if entry is Dictionary:
			ids.append(str(entry.get("district_id", "")))
	return ids


func _entry(entries: Array, district_id: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and str(entry.get("district_id", "")) == district_id:
			return entry
	return {}


func _instantiate_selector() -> Control:
	var scene = load("res://scenes/ui/district_select.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "district select scene loads")
		return null
	var instance = scene.instantiate()
	Engine.get_main_loop().root.add_child(instance)
	await Engine.get_main_loop().process_frame
	return instance


func _instantiate_hub() -> Control:
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var instance = scene.instantiate()
	Engine.get_main_loop().root.add_child(instance)
	await Engine.get_main_loop().process_frame
	return instance


func _city() -> Control:
	var scene = load(CITY_SCENE_PATH)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "city_scene loads")
		return null
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	return city


func _find_named_buttons(root: Node, prefix: String) -> Array:
	var result: Array = []
	_collect_named_buttons(root, prefix, result)
	return result


func _collect_button_text(root: Node) -> String:
	var pieces: Array[String] = []
	_collect_button_text_recursive(root, pieces)
	return "\n".join(pieces)


func _collect_button_text_recursive(node: Node, pieces: Array[String]) -> void:
	if node is Button:
		pieces.append(str((node as Button).text))
		pieces.append(str((node as Button).tooltip_text))
	for child in node.get_children():
		_collect_button_text_recursive(child, pieces)


func _collect_named_buttons(node: Node, prefix: String, result: Array) -> void:
	if node is Button and str(node.name).begins_with(prefix):
		result.append(node)
	for child in node.get_children():
		_collect_named_buttons(child, prefix, result)


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _on_city_scene_requested(district_id: String) -> void:
	_requested_district_id = district_id


func _is_clean_player_text(value: String) -> bool:
	if value.strip_edges() == "":
		return false
	for fragment in [
		"shadow_alley",
		"steelworks",
		"misty_port",
		"sacred_seven",
		"stone_tower",
		"ascetic_mountain",
		"node_",
		"District",
		"Return Hub",
		"Advance Time",
		"Lingstones",
		"Day ",
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
