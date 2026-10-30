extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const NPC_LIBRARY_PATH := "res://scripts/world/npc_library.gd"
const NPC_SERVICE_PATH := "res://scripts/world/npc_interaction_service.gd"
const XIAO_RAN_TIMELINE_PATH := "res://dialogic/npc/xiao_ran_main.dtl"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_xiao_ran_dialogue.gd --")
	test_xiao_ran_json_has_t6_contract()
	test_xiao_ran_dialogic_timeline_has_node4_anchor()
	test_xiao_ran_trust_crossing_30_unlocks_free_temp_card()
	await test_hub_shadow_alley_xiao_ran_dialogue_records_first_meet()
	return {"passed": _passed, "failed": _failed}


func test_xiao_ran_json_has_t6_contract() -> void:
	var npc := _npc_def("xiao_ran")
	assert_true(not npc.is_empty(), "xiao_ran definition loads")
	assert_eq(str(npc.get("dialogue_tree", "")), "xiao_ran_main", "xiao_ran dialogue_tree is xiao_ran_main")
	assert_true(npc.get("city_presence", []) is Array, "xiao_ran has city_presence")
	assert_true(_presence_times(npc).has("evening"), "xiao_ran appears in evening")
	assert_true(_presence_times(npc).has("night"), "xiao_ran appears at night")
	var anchors: Variant = npc.get("mainline_anchors", null)
	assert_true(anchors is Array, "xiao_ran has mainline_anchors array")
	if anchors is Array:
		assert_true(anchors.has("node_4"), "xiao_ran JSON includes node_4 mainline anchor")
	var buffs: Array = npc.get("buff_unlocks_on_trust", [])
	assert_true(_has_buff(buffs, 30, "free_temp_card"), "xiao_ran trust 30 unlocks free_temp_card")


func test_xiao_ran_dialogic_timeline_has_node4_anchor() -> void:
	assert_true(FileAccess.file_exists(XIAO_RAN_TIMELINE_PATH), "xiao_ran_main.dtl exists")
	var content := FileAccess.get_file_as_string(XIAO_RAN_TIMELINE_PATH) if FileAccess.file_exists(XIAO_RAN_TIMELINE_PATH) else ""
	var expected_branches := ["first_meet", "small_talk", "ask_well", "node_4_anchor", "leave"]
	for branch_id in expected_branches:
		assert_true(content.find("branch:%s" % branch_id) >= 0, "xiao_ran timeline has %s branch" % branch_id)
	assert_true(content.find("mainline.node_4") >= 0, "xiao_ran timeline references mainline node_4")
	assert_eq(_registered_timeline_path("npc/xiao_ran_main"), XIAO_RAN_TIMELINE_PATH, "project registers xiao_ran Dialogic timeline")


func test_xiao_ran_trust_crossing_30_unlocks_free_temp_card() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	var gs = _fresh_state()
	var state = NpcKnowledgeStateScript.new()
	state.trust = 29
	gs.npc_relations["xiao_ran"] = state
	var result: Dictionary = service.commit_dialogue_outcome("xiao_ran", {"trust_delta": 1}, gs)
	assert_true(bool(result.get("ok", false)), "xiao_ran commit succeeds")
	var unlocked: Array = result.get("unlocked_buffs", [])
	assert_eq(unlocked.size(), 1, "crossing trust 30 unlocks exactly one buff")
	if unlocked.size() > 0 and unlocked[0] is Dictionary:
		assert_eq(str(unlocked[0].get("type", "")), "free_temp_card", "xiao_ran unlocked buff is free_temp_card")
		assert_eq(str(unlocked[0].get("source_npc_id", "")), "xiao_ran", "xiao_ran buff records source npc")
	var again: Dictionary = service.commit_dialogue_outcome("xiao_ran", {"trust_delta": 5}, gs)
	assert_eq(again.get("unlocked_buffs", []).size(), 0, "xiao_ran free_temp_card unlock is not duplicated")
	gs.queue_free()


func test_hub_shadow_alley_xiao_ran_dialogue_records_first_meet() -> void:
	var previous: Dictionary = GameState.to_dict()
	var fresh = _fresh_state()
	GameState.from_dict(fresh.to_dict())
	GameState.day = 6
	GameState.time_of_day = "evening"
	GameState.ap = 12
	fresh.queue_free()
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var door = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	if door is Button:
		door.pressed.emit()
		await Engine.get_main_loop().process_frame
	var selector = hub.get_node_or_null("DistrictSelect")
	if selector != null:
		var shadow = selector.find_child("DistrictRow_shadow_alley", true, false)
		if shadow is Button:
			shadow.pressed.emit()
			await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	if city != null:
		var xiao_ran_button = city.find_child("Hotspot_npc_xiao_ran", true, false)
		assert_true(xiao_ran_button is Button, "Hub path exposes Xiao Ran hotspot")
		if xiao_ran_button is Button:
			xiao_ran_button.pressed.emit()
			await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "Xiao Ran hotspot opens visible NPC dialogue")
	if dialog != null:
		var text := str(dialog.dialog_text)
		assert_true(_has_cjk(text), "visible dialog is Chinese player-facing copy")
		assert_true(text.find("npc/xiao_ran_main") < 0, "visible dialog hides xiao_ran timeline id")
	assert_eq(_first_met_day(GameState, "xiao_ran"), 6, "Hub path records xiao_ran first-met day")
	hub.queue_free()
	GameState.from_dict(previous)


func _npc_def(npc_id: String) -> Dictionary:
	var library = _new_instance(NPC_LIBRARY_PATH, "NpcLibrary")
	if library == null:
		return {}
	library.load_all()
	return library.get_definition(npc_id)


func _presence_times(npc: Dictionary) -> Array:
	var times: Array = []
	for entry in npc.get("city_presence", []):
		if entry is Dictionary:
			times.append(str(entry.get("time_of_day", "")))
	times.sort()
	return times


func _has_buff(buffs: Array, trust: int, buff_type: String) -> bool:
	for buff in buffs:
		if buff is Dictionary and int(buff.get("trust", -1)) == trust and str(buff.get("type", "")) == buff_type:
			return true
	return false


func _registered_timeline_path(timeline_id: String) -> String:
	var timelines: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
	return str(timelines.get(timeline_id, ""))


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _first_met_day(game_state, npc_id: String) -> int:
	var days: Variant = game_state.daodian.get("npc_first_met_days", {})
	if days is Dictionary:
		return int(days.get(npc_id, -1))
	return -1


func _new_instance(path: String, label: String):
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s script loads and can instantiate" % label)
		return null
	var instance = script.new()
	assert_true(instance != null, "%s instance creates" % label)
	return instance


func _fresh_state():
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
