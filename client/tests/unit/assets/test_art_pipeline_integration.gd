extends RefCounted

const ArtManifestScript = preload("res://scripts/art_manifest.gd")
const CardLibraryScript = preload("res://scripts/combat/card_library.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const BattleSceneScript = preload("res://scripts/ui/battle_scene.gd")
const BrandWorkshopScript = preload("res://scripts/hub/brand_workshop_panel.gd")
const HubScript = preload("res://scripts/hub/hub.gd")

const CITY_SCENE_PATH := "res://scenes/world/city_scene.tscn"
const EVENT_DIR := "res://data/events"
const ENEMY_DIR := "res://data/combat/enemies"
const DISTRICT_DATA_PATH := "res://data/districts/district_data.json"
const TOWER_BOSS_TABLE_PATH := "res://data/towers/boss_table.json"
const FOOL_SYMBOLS_PATH := "res://data/ritual/fool_symbols.json"
const HUB_HOTSPOT_RUNTIME_LINKS := {
	"hub_desk_cluster": "DeskButton",
	"hub_desk_forge_table": "Zone.FORGE",
	"hub_desk_tarot_cards": "Zone.TAROT_DESK",
	"hub_desk_brand_workshop": "Zone.BRAND_WORKSHOP",
	"hub_desk_deck_builder": "Zone.DECK_BUILDER",
	"hub_notice_board": "NoticeBoardButton",
	"hub_cushion": "CushionButton",
	"hub_bookshelf": "BookshelfButton",
	"hub_bed": "BedButton",
	"hub_front_door": "FrontDoorButton",
	"hub_clock": "ClockButton",
	"hub_front_door_city_map": "_open_district_selector",
	"hub_front_door_black_market": "_black_market_panel",
	"hub_intel_files": "IntelInfoButton",
	"hub_gray_crown_daily": "GrayCrownDaily",
	"hub_promotion_ritual": "PromotionButton",
}
const DISTRICT_DATA_ALIASES := {
	"steelworks": "steel_district",
	"misty_port": "mist_harbor",
	"sacred_seven": "seven_saints",
}
const ONBOARDING_REFERENCE_IDS := [
	"wake_up",
	"mirror_reflection",
	"find_press_id",
	"newspaper_and_notes",
	"knocking_old_li",
	"first_acting_check",
	"task_arrow_to_seven_holy",
	"leaving_home",
	"drunkard_encounter",
	"tutorial_battle",
	"first_card_drop",
	"drunkard_foreshadow",
	"bell_tower_arrival",
	"brandon_encounter",
	"second_acting_check",
	"victor_rumor",
	"return_home",
	"forge_tutorial_intro",
	"forge_phigros_tutorial",
	"first_forge_result",
	"weird_chanting",
	"basement_discovery",
	"true_notebook",
	"ai_gm_revelation",
	"dream_pendulum",
]

var _passed := 0
var _failed := 0
var _card_library = null
var _npc_library = null


func run() -> Dictionary:
	print("\n-- test_art_pipeline_integration.gd --")
	test_manifest_integrated_textures_load_and_link_data()
	test_battle_card_resolves_manifest_texture()
	test_brand_workshop_resolves_brand_texture()
	test_hub_harvey_dialogue_resolves_portrait_texture()
	await test_city_scene_shadow_alley_event_uses_background_texture()
	return {"passed": _passed, "failed": _failed}


func test_manifest_integrated_textures_load_and_link_data() -> void:
	var entries: Array = ArtManifestScript.integrated_texture_entries()
	assert_true(entries.size() >= 18, "manifest has integrated texture entries")
	for entry in entries:
		var asset_id := str(entry.get("asset_id", ""))
		var path := str(entry.get("path", ""))
		var linked_data_id := str(entry.get("linked_data_id", ""))
		var category := str(entry.get("category", ""))
		assert_true(path.begins_with("res://assets/textures/"), "%s texture path uses client textures" % asset_id)
		var resource := ResourceLoader.load(path)
		assert_true(resource is Texture2D, "%s loads as Texture2D" % asset_id)
		assert_true(_linked_data_exists(category, linked_data_id), "%s linked data id exists: %s" % [asset_id, linked_data_id])


func test_battle_card_resolves_manifest_texture() -> void:
	var scene = BattleSceneScript.new()
	var card = CardScript.from_json({
		"id": "fool_s9_spirit_vision",
		"template_id": "fool_s9_spirit_vision",
		"display_name": "Spirit Vision",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {"damage": 0, "heal": 0, "target": "self", "range": 0, "status_effects": []},
	})
	var texture = scene.call("_card_texture_for", card)
	assert_true(texture is Texture2D, "BattleScene resolves Fool S9 card texture")
	scene.queue_free()


func test_brand_workshop_resolves_brand_texture() -> void:
	var panel = BrandWorkshopScript.new()
	panel.call("_build_ui")
	var brand = BrandCatalogScript.create_brand("fate_thread")
	panel.call("_refresh_brand_texture", brand)
	var texture_rect = panel.find_child("BrandTexture", true, false)
	assert_true(texture_rect is TextureRect, "BrandWorkshop has BrandTexture TextureRect")
	assert_true(texture_rect != null and texture_rect.texture is Texture2D, "BrandWorkshop resolves brand icon texture")
	panel.queue_free()


func test_hub_harvey_dialogue_resolves_portrait_texture() -> void:
	var hub = HubScript.new()
	hub.call("_setup_npc_dialog")
	var npc := _npc_def("harvey_mors")
	hub.call("_set_npc_portrait", "harvey_mors", npc)
	var texture_rect = hub.find_child("NpcPortraitTexture", true, false)
	assert_true(texture_rect is TextureRect, "Hub NPC dialog has portrait TextureRect")
	assert_true(texture_rect != null and texture_rect.texture is Texture2D, "Hub resolves Harvey portrait texture")
	hub.queue_free()


func test_city_scene_shadow_alley_event_uses_background_texture() -> void:
	var packed = load(CITY_SCENE_PATH)
	assert_true(packed != null and packed.can_instantiate(), "CityScene scene loads")
	if packed == null or not packed.can_instantiate():
		return
	var city = packed.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	var gs = GameStateScript.new()
	gs._ready()
	city.open_from_data({"district_id": "shadow_alley", "display_name": "Shadow Alley", "hotspots": []}, gs)
	city.call("_on_encounter_triggered", {"districts": ["shadow_alley"]})
	var background = city.get_node_or_null("Background")
	assert_true(background is TextureRect, "CityScene Background is TextureRect")
	assert_true(background != null and background.texture is Texture2D, "CityScene applies shadow alley event background texture")
	city.queue_free()


func _linked_data_exists(category: String, linked_data_id: String) -> bool:
	match category:
		"card":
			return _card(linked_data_id) != null
		"brand":
			return not BrandCatalogScript.get_brand_dict(linked_data_id).is_empty()
		"portrait":
			return not _npc_def(linked_data_id).is_empty() or _enemy_exists(linked_data_id)
		"event":
			return _event_exists(linked_data_id)
		"hub":
			return linked_data_id == "hub_anchor" or _symbol_exists(linked_data_id)
		"hotspot":
			return _hotspot_reference_exists(linked_data_id)
		"tower":
			return _tower_reference_exists(linked_data_id)
		"district":
			return _district_reference_exists(linked_data_id)
		"onboarding":
			return ONBOARDING_REFERENCE_IDS.has(linked_data_id)
	return false


func _card(card_id: String):
	if _card_library == null:
		_card_library = CardLibraryScript.new()
		_card_library.load_all()
	return _card_library.get_card(card_id)


func _npc_def(npc_id: String) -> Dictionary:
	if _npc_library == null:
		_npc_library = NpcLibraryScript.new()
	return _npc_library.get_definition(npc_id)


func _event_exists(event_id: String) -> bool:
	var dir := DirAccess.open(EVENT_DIR)
	if dir == null:
		return false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [EVENT_DIR, fname]))
			if parsed is Dictionary and str((parsed as Dictionary).get("id", "")) == event_id:
				dir.list_dir_end()
				return true
		fname = dir.get_next()
	dir.list_dir_end()
	return false


func _enemy_exists(enemy_id: String) -> bool:
	var path := "%s/%s.json" % [ENEMY_DIR, enemy_id]
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed is Dictionary and str((parsed as Dictionary).get("id", "")) == enemy_id


func _hub_hotspot_link_exists(linked_data_id: String) -> bool:
	if not HUB_HOTSPOT_RUNTIME_LINKS.has(linked_data_id):
		return false
	var token := str(HUB_HOTSPOT_RUNTIME_LINKS[linked_data_id])
	var hub_source := FileAccess.get_file_as_string("res://scripts/hub/hub.gd")
	return hub_source.find(token) >= 0


func _hotspot_reference_exists(linked_data_id: String) -> bool:
	if linked_data_id.begins_with("hub_"):
		return _hub_hotspot_link_exists(linked_data_id)
	return _location_hotspot_reference_exists(linked_data_id)


func _location_hotspot_reference_exists(linked_data_id: String) -> bool:
	for district_id in ["ascetic_mountain", "shadow_alley", "sacred_seven", "stone_tower", "steelworks", "misty_port"]:
		var prefix := "%s_" % district_id
		if not linked_data_id.begins_with(prefix):
			continue
		var local_id := linked_data_id.trim_prefix(prefix)
		var path := "res://data/locations/%s.json" % district_id
		if not FileAccess.file_exists(path):
			return false
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			return false
		var hotspots: Variant = (parsed as Dictionary).get("hotspots", [])
		if not hotspots is Array:
			return false
		for hotspot in hotspots:
			if hotspot is Dictionary and str((hotspot as Dictionary).get("id", "")) == local_id:
				return true
		return false
	return false


func _tower_reference_exists(linked_data_id: String) -> bool:
	if not linked_data_id.begins_with("tower_"):
		return false
	var district_id := linked_data_id.trim_prefix("tower_")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOWER_BOSS_TABLE_PATH))
	if not parsed is Dictionary:
		return false
	var bosses: Variant = (parsed as Dictionary).get("bosses", {})
	return bosses is Dictionary and (bosses as Dictionary).has(district_id)


func _district_reference_exists(linked_data_id: String) -> bool:
	var ids := _district_data_ids()
	if ids.has(linked_data_id):
		return true
	var alias := str(DISTRICT_DATA_ALIASES.get(linked_data_id, ""))
	return alias != "" and ids.has(alias)


func _district_data_ids() -> Dictionary:
	var result := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DISTRICT_DATA_PATH))
	if not parsed is Dictionary:
		return result
	var districts: Variant = (parsed as Dictionary).get("districts", [])
	if not districts is Array:
		return result
	for district in districts:
		if district is Dictionary:
			result[str((district as Dictionary).get("id", ""))] = true
	return result


func _symbol_exists(symbol_id: String) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOOL_SYMBOLS_PATH))
	if not parsed is Dictionary:
		return false
	var symbols: Variant = (parsed as Dictionary).get("symbols", [])
	if not symbols is Array:
		return false
	for symbol in symbols:
		if symbol is Dictionary and str((symbol as Dictionary).get("id", "")) == symbol_id:
			return true
	return false


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
