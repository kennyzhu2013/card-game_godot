extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const BlackMarketScript = preload("res://scripts/ui/black_market.gd")
const CitySceneScript = preload("res://scripts/world/city_scene.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")

const POOL_PATH := "res://data/shops/donen_blackmarket.json"
const STREETTALKER_HOTSPOTS := {
	"shadow_alley": "rumor_streettalker",
	"steelworks": "rumor_factory_tabloid",
	"misty_port": "rumor_misty_port_tavern",
	"sacred_seven": "rumor_sacred_notice",
	"stone_tower": "rumor_stone_street",
	"ascetic_mountain": "rumor_ascetic_teahouse",
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_church_awareness_thresholds.gd --")
	test_game_state_church_awareness_clamps_and_records_threshold_events()
	test_black_market_awareness_50_halves_slots()
	test_shadow_alley_streettalker_hidden_at_awareness_75()
	test_all_district_streettalker_series_hide_at_awareness_75()
	return {"passed": _passed, "failed": _failed}


func test_game_state_church_awareness_clamps_and_records_threshold_events() -> void:
	var gs = _state()
	assert_true(gs.has_method("adjust_church_awareness"), "GameState exposes adjust_church_awareness(delta, source)")
	assert_true(_has_property(gs, "church_awareness_events"), "GameState stores church_awareness_events")
	if not gs.has_method("adjust_church_awareness") or not _has_property(gs, "church_awareness_events"):
		return
	gs.adjust_church_awareness(10, "r20_probe")
	assert_eq(int(gs.church_awareness), 10, "church_awareness reaches 10")
	assert_true(_has_threshold(gs, 10), "threshold 10 event is recorded")
	gs.adjust_church_awareness(15, "r20_probe")
	assert_eq(int(gs.church_awareness), 25, "church_awareness reaches 25")
	assert_true(_has_threshold(gs, 25), "threshold 25 event is recorded")
	gs.adjust_church_awareness(25, "r20_probe")
	assert_eq(int(gs.church_awareness), 50, "church_awareness reaches 50")
	assert_true(_has_threshold(gs, 50), "threshold 50 event is recorded")
	gs.adjust_church_awareness(999, "r20_probe")
	assert_eq(int(gs.church_awareness), 100, "church_awareness clamps to 100")


func test_black_market_awareness_50_halves_slots() -> void:
	var pool: Dictionary = BlackMarketScript.load_pool(POOL_PATH)
	var gs = _state()
	gs.church_awareness = 50
	assert_eq(BlackMarketScript.slot_count(gs, pool), 3, "church_awareness 50 halves black-market slots to max(3, 6/2)")
	gs.halfmoon_trust = 70
	assert_eq(BlackMarketScript.slot_count(gs, pool), 4, "awareness half slots still allows Halfmoon hidden slot")


func test_shadow_alley_streettalker_hidden_at_awareness_75() -> void:
	var data: Dictionary = CitySceneScript.load_district_data("shadow_alley")
	var hotspot: Dictionary = _find_hotspot(data, "rumor_streettalker")
	assert_true(not hotspot.is_empty(), "shadow_alley has streettalker rumor hotspot")
	if hotspot.is_empty():
		return
	var visible_when: Variant = hotspot.get("visible_when", "always")
	var gs = _state()
	gs.time_of_day = "evening"
	gs.church_awareness = 74
	assert_true(HotspotResolverScript.evaluate_visible_when(visible_when, gs), "streettalker is visible below church_awareness 75")
	gs.church_awareness = 75
	assert_true(not HotspotResolverScript.evaluate_visible_when(visible_when, gs), "streettalker hides at church_awareness 75")


func test_all_district_streettalker_series_hide_at_awareness_75() -> void:
	for district_id in STREETTALKER_HOTSPOTS.keys():
		var data: Dictionary = CitySceneScript.load_district_data(str(district_id))
		var hotspot_id := str(STREETTALKER_HOTSPOTS[district_id])
		var hotspot: Dictionary = _find_hotspot(data, hotspot_id)
		assert_true(not hotspot.is_empty(), "%s has streettalker-series rumor hotspot %s" % [district_id, hotspot_id])
		if hotspot.is_empty():
			continue
		var visible_when: Variant = hotspot.get("visible_when", "always")
		var gs = _state()
		gs.day = 7
		gs.time_of_day = "morning"
		gs.sequence = 8
		gs.daodian["completed_main_story_nodes"] = ["node_4"]
		gs.church_awareness = 74
		assert_true(HotspotResolverScript.evaluate_visible_when(visible_when, gs), "%s streettalker-series hotspot visible at church_awareness 74" % district_id)
		gs.church_awareness = 75
		assert_true(not HotspotResolverScript.evaluate_visible_when(visible_when, gs), "%s streettalker-series hotspot hidden at church_awareness 75" % district_id)


func _find_hotspot(data: Dictionary, hotspot_id: String) -> Dictionary:
	var hotspots: Array = data.get("hotspots", []) if data.get("hotspots", []) is Array else []
	for hotspot in hotspots:
		if hotspot is Dictionary and str((hotspot as Dictionary).get("id", "")) == hotspot_id:
			return (hotspot as Dictionary).duplicate(true)
	return {}


func _has_threshold(gs, threshold: int) -> bool:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return true
	return false


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false
	for entry in obj.get_property_list():
		if str(entry.get("name", "")) == property_name:
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
