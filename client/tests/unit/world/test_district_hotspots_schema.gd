extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CitySceneScript = preload("res://scripts/world/city_scene.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")

const LOCATION_DIR := "res://data/locations"
const ALLOWED_TYPES := [
	"tower",
	"npc",
	"shop",
	"minigame_casino",
	"minigame_job",
	"minigame_drill",
	"minigame_auction",
	"rumor",
	"commission_marker",
	"main_story",
]
const DISTRICTS := [
	{"file": "shadow_alley", "district_id": "shadow_alley", "count": 6},
	{"file": "steelworks", "district_id": "steelworks", "count": 5},
	{"file": "misty_port", "district_id": "misty_port", "count": 8},
	{"file": "sacred_seven", "district_id": "sacred_seven", "count": 6},
	{"file": "stone_tower", "district_id": "stone_tower", "count": 5},
	{"file": "ascetic_mountain", "district_id": "ascetic_mountain", "count": 5},
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_district_hotspots_schema.gd --")
	test_six_location_files_have_hotspot_schema()
	test_t25_schema_still_exposes_primary_tower_and_npc_anchors()
	test_unlock_conditions_evaluate_through_hotspot_resolver()
	await test_city_scene_loads_location_json_by_district_id()
	return {"passed": _passed, "failed": _failed}


func test_six_location_files_have_hotspot_schema() -> void:
	for spec in DISTRICTS:
		var path := _path(str(spec["file"]))
		var data := _json(path)
		assert_true(not data.is_empty(), "%s exists and parses" % path)
		if data.is_empty():
			continue
		assert_eq(str(data.get("$schema", "")), "city_hotspot_v1", "%s uses city_hotspot_v1 schema" % path)
		assert_eq(str(data.get("district_id", "")), str(spec["district_id"]), "%s district_id matches file" % path)
		assert_true(str(data.get("display_name", "")) != "", "%s display_name is present" % path)
		assert_true(data.has("ap_to_enter"), "%s has ap_to_enter" % path)
		assert_true(data.has("hotspots") and data["hotspots"] is Array, "%s has hotspots array" % path)
		var hotspots: Array = data.get("hotspots", [])
		assert_eq(hotspots.size(), int(spec["count"]), "%s hotspot count matches current city+intel plan" % path)
		for hotspot in hotspots:
			_assert_hotspot_schema(hotspot, path)


func test_t25_schema_still_exposes_primary_tower_and_npc_anchors() -> void:
	var tower_count := 0
	var npc_count := 0
	for spec in DISTRICTS:
		var data := _json(_path(str(spec["file"])))
		if data.is_empty():
			continue
		for hotspot in data.get("hotspots", []):
			if not hotspot is Dictionary:
				continue
			if str(hotspot.get("type", "")) == "tower":
				tower_count += 1
			elif str(hotspot.get("type", "")) == "npc":
				npc_count += 1
	assert_true(tower_count >= 6, "Slice 2.5/3 combined city schema keeps tower anchors")
	assert_true(npc_count >= 6, "Slice 2.5/3 combined city schema keeps NPC anchors")


func test_unlock_conditions_evaluate_through_hotspot_resolver() -> void:
	var stone := _json(_path("stone_tower"))
	var ascetic := _json(_path("ascetic_mountain"))
	if stone.is_empty() or ascetic.is_empty():
		assert_true(false, "stone_tower and ascetic_mountain JSON exist for unlock checks")
		return
	assert_eq(str(stone.get("unlock_condition", "")), "sequence <= 8", "stone_tower district unlock uses sequence <= 8")
	assert_eq(str(ascetic.get("unlock_condition", "")), "mainline.node_4.completed == true", "ascetic_mountain unlock uses mainline node_4")
	var gs = _state()
	gs.sequence = 9
	assert_true(not HotspotResolverScript.evaluate_visible_when(str(stone.get("unlock_condition", "")), gs), "stone_tower locked at sequence 9")
	gs.sequence = 8
	assert_true(HotspotResolverScript.evaluate_visible_when(str(stone.get("unlock_condition", "")), gs), "stone_tower unlocked at sequence 8")
	assert_true(not HotspotResolverScript.evaluate_visible_when(str(ascetic.get("unlock_condition", "")), gs), "ascetic mountain locked before node_4")
	gs.daodian["completed_main_story_nodes"] = ["node_4"]
	assert_true(HotspotResolverScript.evaluate_visible_when(str(ascetic.get("unlock_condition", "")), gs), "ascetic mountain unlocks after node_4")


func test_city_scene_loads_location_json_by_district_id() -> void:
	var data: Dictionary = CitySceneScript.load_district_data("shadow_alley")
	assert_eq(str(data.get("district_id", "")), "shadow_alley", "CityScene loads shadow_alley from locations JSON")
	var scene = load("res://scenes/world/city_scene.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "city_scene loads for location render")
		return
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	gs.time_of_day = "night"
	gs.day = 3
	city.call("open_from_data", data, gs)
	await Engine.get_main_loop().process_frame
	var layer = city.find_child("HotspotLayer", true, false)
	assert_true(_visible_button_count(layer) >= 3, "CityScene renders enabled shadow_alley hotspots from JSON")
	city.queue_free()


func _assert_hotspot_schema(hotspot: Variant, path: String) -> void:
	assert_true(hotspot is Dictionary, "%s hotspot is a dictionary" % path)
	if not hotspot is Dictionary:
		return
	for key in ["id", "label", "icon", "type", "ap_cost", "payload"]:
		assert_true(hotspot.has(key), "%s hotspot %s has %s" % [path, str(hotspot.get("id", "")), key])
	assert_true(str(hotspot.get("id", "")) != "", "%s hotspot id is non-empty" % path)
	assert_true(str(hotspot.get("label", "")) != "", "%s hotspot label is non-empty" % path)
	assert_true(str(hotspot.get("type", "")) in ALLOWED_TYPES, "%s hotspot type is allowed" % path)
	assert_true(int(hotspot.get("ap_cost", -1)) >= 0, "%s hotspot ap_cost is non-negative" % path)
	assert_true(hotspot.get("payload", null) is Dictionary, "%s hotspot payload is dictionary" % path)
	assert_true(hotspot.has("visible_when") or hotspot.has("visible"), "%s hotspot has visible_when or visible flag" % path)


func _is_enabled_for_slice_25(hotspot: Dictionary) -> bool:
	if hotspot.has("visible") and not bool(hotspot.get("visible", true)):
		return false
	return str(hotspot.get("visible_when", "always")) != "false"


func _path(file_stem: String) -> String:
	return "%s/%s.json" % [LOCATION_DIR, file_stem]


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _visible_button_count(node) -> int:
	if node == null:
		return 0
	var count := 0
	for child in node.get_children():
		if child is Button:
			count += 1
	return count


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
