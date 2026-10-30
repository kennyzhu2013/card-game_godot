extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")

const NPC_LIBRARY_PATH := "res://scripts/world/npc_library.gd"
const NPC_SERVICE_PATH := "res://scripts/world/npc_interaction_service.gd"
const OLD_LI_TIMELINE_PATH := "res://dialogic/npc/old_li_main.dtl"

var _passed := 0
var _failed := 0


class FakeDialogicAdapter:
	var started_timelines: Array[String] = []
	var variables: Dictionary = {}

	func start(timeline_id: String) -> void:
		started_timelines.append(timeline_id)

	func set_variable(variable_name: String, value: Variant) -> void:
		variables[variable_name] = value


func run() -> Dictionary:
	print("\n-- test_old_li_dialogue.gd --")
	test_old_li_json_has_t6_contract()
	test_old_li_dialogic_timeline_has_five_required_branches()
	test_opening_old_li_records_first_met_day_once()
	await test_hub_shadow_alley_old_li_dialogue_records_first_meet()
	return {"passed": _passed, "failed": _failed}


func test_old_li_json_has_t6_contract() -> void:
	var npc := _npc_def("old_li")
	assert_true(not npc.is_empty(), "old_li definition loads")
	assert_eq(str(npc.get("dialogue_tree", "")), "old_li_main", "old_li dialogue_tree is old_li_main")
	assert_eq(_presence_times(npc), ["evening", "morning", "night", "noon"], "old_li has city_presence for four time segments")
	var intels: Variant = npc.get("available_intels", null)
	assert_true(intels is Array, "old_li has available_intels array")
	if intels is Array:
		assert_true(intels.size() >= 2, "old_li has multiple intel entries")
		assert_true(_has_intel_id(intels, "intel_xiao_ran_gift_001"), "old_li includes R26 xiao_ran gift intel")
	var buffs: Array = npc.get("buff_unlocks_on_trust", [])
	assert_eq(buffs.size(), 3, "old_li has three trust buff tiers")
	assert_true(_has_buff(buffs, 40, "free_temp_card"), "old_li trust 40 unlocks free_temp_card")
	assert_true(_has_buff(buffs, 70, "rule_unlock"), "old_li trust 70 unlocks rule_unlock")
	assert_true(_has_buff(buffs, 90, "shop_discount"), "old_li trust 90 unlocks shop_discount")


func test_old_li_dialogic_timeline_has_five_required_branches() -> void:
	assert_true(FileAccess.file_exists(OLD_LI_TIMELINE_PATH), "old_li_main.dtl exists")
	var content := FileAccess.get_file_as_string(OLD_LI_TIMELINE_PATH) if FileAccess.file_exists(OLD_LI_TIMELINE_PATH) else ""
	var expected_branches := ["first_meet", "small_talk", "ask_intel", "commission_placeholder", "leave"]
	for branch_id in expected_branches:
		assert_true(content.find("branch:%s" % branch_id) >= 0, "old_li timeline has %s branch" % branch_id)
	assert_true(content.find("npc_first_meet") >= 0, "old_li timeline marks npc_first_meet hook")
	assert_eq(_registered_timeline_path("npc/old_li_main"), OLD_LI_TIMELINE_PATH, "project registers old_li Dialogic timeline")


func test_opening_old_li_records_first_met_day_once() -> void:
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 5
	var adapter := FakeDialogicAdapter.new()
	var result: Dictionary = service.open_dialogue("old_li", gs, adapter)
	assert_true(bool(result.get("ok", false)), "open_dialogue succeeds for old_li")
	assert_eq(_first_met_day(gs, "old_li"), 5, "old_li first-met day is recorded in daodian")
	gs.day = 7
	service.open_dialogue("old_li", gs, adapter)
	assert_eq(_first_met_day(gs, "old_li"), 5, "old_li first-met day is not overwritten")
	gs.queue_free()


func test_hub_shadow_alley_old_li_dialogue_records_first_meet() -> void:
	var previous: Dictionary = GameState.to_dict()
	var fresh = _fresh_state()
	GameState.from_dict(fresh.to_dict())
	GameState.day = 6
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
		var old_li_button = city.find_child("Hotspot_npc_old_li", true, false)
		assert_true(old_li_button is Button, "Hub path exposes Old Li hotspot")
		if old_li_button is Button:
			old_li_button.pressed.emit()
			await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "Old Li hotspot opens visible NPC dialogue")
	if dialog != null:
		var text := str(dialog.dialog_text)
		assert_true(_has_cjk(text), "visible dialog is Chinese player-facing copy")
		assert_true(text.find("npc/old_li_main") < 0, "visible dialog hides old_li timeline id")
	assert_eq(_first_met_day(GameState, "old_li"), 6, "Hub path records old_li first-met day")
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


func _has_intel_id(intels: Array, intel_id: String) -> bool:
	for intel in intels:
		if intel is Dictionary and str(intel.get("intel_id", intel.get("id", ""))) == intel_id:
			return true
	return false


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
