extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const RESOLVER_PATH := "res://scripts/world/hotspot_resolver.gd"
const CITY_SCENE_PATH := "res://scenes/world/city_scene.tscn"
const HOTSPOT_BUTTON_SCENE_PATH := "res://scenes/world/hotspot_button.tscn"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_hotspot_resolver.gd --")
	test_visible_when_basic_predicates()
	test_visible_when_mainline_and_npc_fields()
	test_visible_when_rejects_unsupported_syntax()
	await test_city_scene_and_hotspot_button_structure()
	await test_city_scene_renders_visible_hotspots_and_topbar()
	return {"passed": _passed, "failed": _failed}


func test_visible_when_basic_predicates() -> void:
	var resolver = _resolver()
	if resolver == null:
		return
	var gs = _state()
	gs.day = 3
	gs.cycle = 1
	gs.time_of_day = "night"
	gs.sequence = 8
	gs.pollution = 55
	gs.church_awareness = 25
	gs.halfmoon_trust = 42
	assert_true(resolver.evaluate_visible_when("always", gs), "always is visible")
	assert_true(resolver.evaluate_visible_when("time_of_day == 'night' AND day >= 3", gs), "time and day AND predicate passes")
	assert_true(resolver.evaluate_visible_when("time_of_day = 'night'", gs), "single equals normalizes to equality")
	assert_true(resolver.evaluate_visible_when("time_of_day != 'morning'", gs), "not-equals predicate passes")
	assert_true(resolver.evaluate_visible_when("sequence <= 8", gs), "sequence less-or-equal predicate passes")
	assert_true(resolver.evaluate_visible_when("pollution >= 50", gs), "pollution threshold predicate passes")
	assert_true(resolver.evaluate_visible_when("church_awareness >= 25", gs), "church awareness threshold predicate passes")
	assert_true(resolver.evaluate_visible_when("halfmoon_trust >= 40", gs), "halfmoon trust threshold predicate passes")
	assert_true(not resolver.evaluate_visible_when("day >= 4", gs), "failed predicate hides hotspot")


func test_visible_when_mainline_and_npc_fields() -> void:
	var resolver = _resolver()
	if resolver == null:
		return
	var gs = _state()
	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	var old_li = NpcKnowledgeStateScript.new()
	old_li.trust = 35
	old_li.suspicion = 15
	gs.npc_relations["old_li"] = old_li
	gs.npc_relations["xiao_ran"] = {"trust": 12, "suspicion": 3}
	assert_true(resolver.evaluate_visible_when("mainline.node_4.completed == true", gs), "completed mainline node predicate passes")
	assert_true(not resolver.evaluate_visible_when("mainline.node_5.completed == true", gs), "missing mainline node predicate fails")
	assert_true(resolver.evaluate_visible_when("npc.old_li.trust >= 30 AND npc.old_li.suspicion <= 20", gs), "NpcKnowledgeState trust and suspicion predicates pass")
	assert_true(resolver.evaluate_visible_when("npc.xiao_ran.trust >= 10 AND npc.xiao_ran.suspicion <= 5", gs), "dictionary npc relation predicates pass")


func test_visible_when_rejects_unsupported_syntax() -> void:
	var resolver = _resolver()
	if resolver == null:
		return
	var gs = _state()
	gs.time_of_day = "night"
	gs.day = 3
	assert_true(not resolver.evaluate_visible_when("time_of_day == 'night' OR day >= 3", gs), "OR is unsupported and fails closed")
	assert_true(not resolver.evaluate_visible_when("time_of_day == 'night' AND (day >= 3)", gs), "nested expression fails closed")
	assert_true(not resolver.evaluate_visible_when("unknown_field == true", gs), "unknown field fails closed")


func test_city_scene_and_hotspot_button_structure() -> void:
	var city_scene = load(CITY_SCENE_PATH)
	assert_true(city_scene != null and city_scene.can_instantiate(), "city_scene.tscn loads")
	if city_scene != null and city_scene.can_instantiate():
		var city = city_scene.instantiate()
		Engine.get_main_loop().root.add_child(city)
		await Engine.get_main_loop().process_frame
		for node_name in ["Background", "TimeOverlay", "HotspotLayer", "TopBar", "EncounterTrigger", "ReturnButton", "TimeAdvanceButton"]:
			assert_true(city.find_child(node_name, true, false) != null, "city_scene has %s node" % node_name)
		assert_true(city.has_method("open_from_data"), "city_scene exposes open_from_data")
		assert_true(city.has_signal("hotspot_selected"), "city_scene emits hotspot_selected")
		assert_true(city.has_signal("return_to_hub_requested"), "city_scene emits return_to_hub_requested")
		city.queue_free()

	var button_scene = load(HOTSPOT_BUTTON_SCENE_PATH)
	assert_true(button_scene != null and button_scene.can_instantiate(), "hotspot_button.tscn loads")
	if button_scene != null and button_scene.can_instantiate():
		var button = button_scene.instantiate()
		Engine.get_main_loop().root.add_child(button)
		await Engine.get_main_loop().process_frame
		for node_name in ["IconLabel", "NameLabel", "ApLabel", "StatusDot"]:
			assert_true(button.find_child(node_name, true, false) != null, "hotspot_button has %s node" % node_name)
		button.queue_free()


func test_city_scene_renders_visible_hotspots_and_topbar() -> void:
	var city_scene = load(CITY_SCENE_PATH)
	if city_scene == null or not city_scene.can_instantiate():
		assert_true(false, "city_scene.tscn loads for render test")
		return
	var city = city_scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	if not city.has_method("open_from_data"):
		assert_true(false, "city_scene supports open_from_data for render test")
		city.queue_free()
		return
	var gs = _state()
	gs.day = 3
	gs.time_of_day = "night"
	gs.ap = 7
	gs.ap_max = 12
	gs.lingstones = 240
	var district := {
		"district_id": "test_district",
		"display_name": "Test District",
		"hotspots": [
			{"id": "tower_entry", "label": "Tower Gate", "icon": "T", "type": "tower", "ap_cost": 2, "visible_when": "always"},
			{"id": "night_market", "label": "Night Market", "icon": "N", "type": "shop", "ap_cost": 0, "visible_when": "time_of_day == 'night' AND day >= 3"},
			{"id": "morning_only", "label": "Morning Only", "icon": "M", "type": "npc", "ap_cost": 0, "visible_when": "time_of_day == 'morning'"},
		],
	}
	city.call("open_from_data", district, gs)
	await Engine.get_main_loop().process_frame
	var hotspot_layer = city.find_child("HotspotLayer", true, false)
	assert_eq(_hotspot_button_count(hotspot_layer), 2, "city_scene renders only visible hotspots")
	var rendered_text := _collect_button_text(hotspot_layer)
	assert_true(rendered_text.find("Tower Gate") >= 0, "tower hotspot label rendered")
	assert_true(rendered_text.find("Night Market") >= 0, "night hotspot label rendered")
	assert_true(rendered_text.find("Morning Only") < 0, "hidden hotspot label not rendered")
	var topbar_text := _collect_label_text(city.find_child("TopBar", true, false))
	assert_true(topbar_text.find("第 3 天") >= 0, "topbar shows day")
	assert_true(topbar_text.find("夜晚") >= 0, "topbar shows time_of_day")
	assert_true(topbar_text.find("AP 7/12") >= 0, "topbar shows AP")
	assert_true(topbar_text.find("灵石 240") >= 0, "topbar shows lingstones")
	assert_true(topbar_text.find("Test District") >= 0, "topbar shows district name")
	var before_ap: int = int(gs.ap)
	var returns: Array = []
	city.return_to_hub_requested.connect(func() -> void:
		returns.append(true)
	)
	var return_button = city.find_child("ReturnButton", true, false)
	if return_button is Button:
		return_button.pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_eq(int(gs.ap), before_ap, "return button costs 0 AP")
	assert_eq(returns.size(), 1, "return button emits return signal")
	city.queue_free()


func _resolver():
	var script = load(RESOLVER_PATH)
	if script == null:
		assert_true(false, "HotspotResolver script loads")
		return null
	return script


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _hotspot_button_count(node) -> int:
	if node == null:
		return 0
	var count := 0
	for child in node.get_children():
		if child is Button:
			count += 1
	return count


func _collect_button_text(node) -> String:
	if node == null:
		return ""
	var text := ""
	for child in node.get_children():
		if child is Button:
			text += str(child.text) + "\n"
	return text


func _collect_label_text(node) -> String:
	if node == null:
		return ""
	var text := ""
	if node is Label:
		text += str(node.text) + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


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
