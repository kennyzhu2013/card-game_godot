extends RefCounted

const MANIFEST_PATH := "res://assets/art_specs/pixel_asset_manifest.json"
const HUB_TEXTURE_DIR := "res://assets/textures/hub"
const HOTSPOT_TEXTURE_DIR := "res://assets/textures/hotspots"
const HOTSPOT_SOURCE_DIR := "output/imagegen/greycrown_hotspots_full/scene_aligned_full"
const LOCATION_DIR := "res://data/locations"
const HUB_SCRIPT_PATH := "res://scripts/hub/hub.gd"

const HOTSPOT_ASSET_ROWS := [
	"hotspot_hub_desk_cluster|hotspot_hub_desk_cluster.png|hub_desk_cluster|001-hotspot-hub_desk_cluster.png|hub",
	"hotspot_hub_desk_forge_table|hotspot_hub_desk_forge_table.png|hub_desk_forge_table|002-hotspot-hub_desk_forge_table.png|hub",
	"hotspot_hub_desk_tarot_cards|hotspot_hub_desk_tarot_cards.png|hub_desk_tarot_cards|003-hotspot-hub_desk_tarot_cards.png|hub",
	"hotspot_hub_desk_brand_workshop|hotspot_hub_desk_brand_workshop.png|hub_desk_brand_workshop|004-hotspot-hub_desk_brand_workshop.png|hub",
	"hotspot_hub_desk_deck_builder|hotspot_hub_desk_deck_builder.png|hub_desk_deck_builder|005-hotspot-hub_desk_deck_builder.png|hub",
	"hotspot_hub_notice_board|hotspot_hub_notice_board.png|hub_notice_board|006-hotspot-hub_notice_board.png|hotspots",
	"hotspot_hub_cushion|hotspot_hub_cushion.png|hub_cushion|007-hotspot-hub_cushion.png|hotspots",
	"hotspot_hub_bookshelf|hotspot_hub_bookshelf.png|hub_bookshelf|008-hotspot-hub_bookshelf.png|hotspots",
	"hotspot_hub_bed|hotspot_hub_bed.png|hub_bed|009-hotspot-hub_bed.png|hotspots",
	"hotspot_hub_front_door|hotspot_hub_front_door.png|hub_front_door|010-hotspot-hub_front_door.png|hotspots",
	"hotspot_hub_clock|hotspot_hub_clock.png|hub_clock|011-hotspot-hub_clock.png|hotspots",
	"hotspot_hub_front_door_city_map|hotspot_hub_front_door_city_map.png|hub_front_door_city_map|012-hotspot-hub_front_door_city_map.png|hotspots",
	"hotspot_hub_front_door_black_market|hotspot_hub_front_door_black_market.png|hub_front_door_black_market|013-hotspot-hub_front_door_black_market.png|hotspots",
	"hotspot_hub_intel_files|hotspot_hub_intel_files.png|hub_intel_files|014-hotspot-hub_intel_files.png|hotspots",
	"hotspot_hub_gray_crown_daily|hotspot_hub_gray_crown_daily.png|hub_gray_crown_daily|015-hotspot-hub_gray_crown_daily.png|hotspots",
	"hotspot_hub_promotion_ritual|hotspot_hub_promotion_ritual.png|hub_promotion_ritual|016-hotspot-hub_promotion_ritual.png|hotspots",
	"hotspot_ascetic_mountain_npc_pendulum|hotspot_ascetic_mountain_npc_pendulum.png|ascetic_mountain_npc_pendulum|017-hotspot-ascetic_mountain_npc_pendulum.png|hotspots",
	"hotspot_ascetic_mountain_npc_xuming_recluse|hotspot_ascetic_mountain_npc_xuming_recluse.png|ascetic_mountain_npc_xuming_recluse|018-hotspot-ascetic_mountain_npc_xuming_recluse.png|hotspots",
	"hotspot_ascetic_mountain_job_mountain_solitary_walk|hotspot_ascetic_mountain_job_mountain_solitary_walk.png|ascetic_mountain_job_mountain_solitary_walk|019-hotspot-ascetic_mountain_job_mountain_solitary_walk.png|hotspots",
	"hotspot_ascetic_mountain_tower_entry_ascetic_mountain|hotspot_ascetic_mountain_tower_entry_ascetic_mountain.png|ascetic_mountain_tower_entry_ascetic_mountain|020-hotspot-ascetic_mountain_tower_entry_ascetic_mountain.png|hotspots",
	"hotspot_ascetic_mountain_rumor_ascetic_teahouse|hotspot_ascetic_mountain_rumor_ascetic_teahouse.png|ascetic_mountain_rumor_ascetic_teahouse|021-hotspot-ascetic_mountain_rumor_ascetic_teahouse.png|hotspots",
	"hotspot_misty_port_tower_entry_misty_port|hotspot_misty_port_tower_entry_misty_port.png|misty_port_tower_entry_misty_port|022-hotspot-misty_port_tower_entry_misty_port.png|hotspots",
	"hotspot_misty_port_npc_carl_smuggler|hotspot_misty_port_npc_carl_smuggler.png|misty_port_npc_carl_smuggler|023-hotspot-misty_port_npc_carl_smuggler.png|hotspots",
	"hotspot_misty_port_npc_eel_fan|hotspot_misty_port_npc_eel_fan.png|misty_port_npc_eel_fan|024-hotspot-misty_port_npc_eel_fan.png|hotspots",
	"hotspot_misty_port_npc_vera_lighthouse|hotspot_misty_port_npc_vera_lighthouse.png|misty_port_npc_vera_lighthouse|025-hotspot-misty_port_npc_vera_lighthouse.png|hotspots",
	"hotspot_misty_port_casino_eel_fan|hotspot_misty_port_casino_eel_fan.png|misty_port_casino_eel_fan|026-hotspot-misty_port_casino_eel_fan.png|hotspots",
	"hotspot_misty_port_auction_smuggler|hotspot_misty_port_auction_smuggler.png|misty_port_auction_smuggler|027-hotspot-misty_port_auction_smuggler.png|hotspots",
	"hotspot_misty_port_job_dock_shift|hotspot_misty_port_job_dock_shift.png|misty_port_job_dock_shift|028-hotspot-misty_port_job_dock_shift.png|hotspots",
	"hotspot_misty_port_rumor_misty_port_tavern|hotspot_misty_port_rumor_misty_port_tavern.png|misty_port_rumor_misty_port_tavern|029-hotspot-misty_port_rumor_misty_port_tavern.png|hotspots",
	"hotspot_sacred_seven_tower_entry_sacred_seven|hotspot_sacred_seven_tower_entry_sacred_seven.png|sacred_seven_tower_entry_sacred_seven|030-hotspot-sacred_seven_tower_entry_sacred_seven.png|hotspots",
	"hotspot_sacred_seven_npc_brendan|hotspot_sacred_seven_npc_brendan.png|sacred_seven_npc_brendan|031-hotspot-sacred_seven_npc_brendan.png|hotspots",
	"hotspot_sacred_seven_npc_thomas_priest|hotspot_sacred_seven_npc_thomas_priest.png|sacred_seven_npc_thomas_priest|032-hotspot-sacred_seven_npc_thomas_priest.png|hotspots",
	"hotspot_sacred_seven_drill_confess_innocent|hotspot_sacred_seven_drill_confess_innocent.png|sacred_seven_drill_confess_innocent|033-hotspot-sacred_seven_drill_confess_innocent.png|hotspots",
	"hotspot_sacred_seven_job_worship_observation|hotspot_sacred_seven_job_worship_observation.png|sacred_seven_job_worship_observation|034-hotspot-sacred_seven_job_worship_observation.png|hotspots",
	"hotspot_sacred_seven_rumor_sacred_notice|hotspot_sacred_seven_rumor_sacred_notice.png|sacred_seven_rumor_sacred_notice|035-hotspot-sacred_seven_rumor_sacred_notice.png|hotspots",
	"hotspot_shadow_alley_tower_entry_shadow_alley|hotspot_shadow_alley_tower_entry_shadow_alley.png|shadow_alley_tower_entry_shadow_alley|036-hotspot-shadow_alley_tower_entry_shadow_alley.png|hotspots",
	"hotspot_shadow_alley_npc_old_li|hotspot_shadow_alley_npc_old_li.png|shadow_alley_npc_old_li|037-hotspot-shadow_alley_npc_old_li.png|hotspots",
	"hotspot_shadow_alley_npc_xiao_ran|hotspot_shadow_alley_npc_xiao_ran.png|shadow_alley_npc_xiao_ran|038-hotspot-shadow_alley_npc_xiao_ran.png|hotspots",
	"hotspot_shadow_alley_shop_blackmarket|hotspot_shadow_alley_shop_blackmarket.png|shadow_alley_shop_blackmarket|039-hotspot-shadow_alley_shop_blackmarket.png|hotspots",
	"hotspot_shadow_alley_rumor_streettalker|hotspot_shadow_alley_rumor_streettalker.png|shadow_alley_rumor_streettalker|040-hotspot-shadow_alley_rumor_streettalker.png|hotspots",
	"hotspot_shadow_alley_job_errand_board|hotspot_shadow_alley_job_errand_board.png|shadow_alley_job_errand_board|041-hotspot-shadow_alley_job_errand_board.png|hotspots",
	"hotspot_steelworks_tower_entry_steelworks|hotspot_steelworks_tower_entry_steelworks.png|steelworks_tower_entry_steelworks|042-hotspot-steelworks_tower_entry_steelworks.png|hotspots",
	"hotspot_steelworks_npc_martha|hotspot_steelworks_npc_martha.png|steelworks_npc_martha|043-hotspot-steelworks_npc_martha.png|hotspots",
	"hotspot_steelworks_npc_peter_furnace|hotspot_steelworks_npc_peter_furnace.png|steelworks_npc_peter_furnace|044-hotspot-steelworks_npc_peter_furnace.png|hotspots",
	"hotspot_steelworks_job_factory_shift|hotspot_steelworks_job_factory_shift.png|steelworks_job_factory_shift|045-hotspot-steelworks_job_factory_shift.png|hotspots",
	"hotspot_steelworks_rumor_factory_tabloid|hotspot_steelworks_rumor_factory_tabloid.png|steelworks_rumor_factory_tabloid|046-hotspot-steelworks_rumor_factory_tabloid.png|hotspots",
	"hotspot_stone_tower_tower_entry_stone_tower|hotspot_stone_tower_tower_entry_stone_tower.png|stone_tower_tower_entry_stone_tower|047-hotspot-stone_tower_tower_entry_stone_tower.png|hotspots",
	"hotspot_stone_tower_npc_marquis_eng|hotspot_stone_tower_npc_marquis_eng.png|stone_tower_npc_marquis_eng|048-hotspot-stone_tower_npc_marquis_eng.png|hotspots",
	"hotspot_stone_tower_npc_hanna_gardener|hotspot_stone_tower_npc_hanna_gardener.png|stone_tower_npc_hanna_gardener|049-hotspot-stone_tower_npc_hanna_gardener.png|hotspots",
	"hotspot_stone_tower_drill_noble_salon|hotspot_stone_tower_drill_noble_salon.png|stone_tower_drill_noble_salon|050-hotspot-stone_tower_drill_noble_salon.png|hotspots",
	"hotspot_stone_tower_rumor_stone_street|hotspot_stone_tower_rumor_stone_street.png|stone_tower_rumor_stone_street|051-hotspot-stone_tower_rumor_stone_street.png|hotspots",
]

const HUB_RUNTIME_TOKENS := {
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

const DISTRICT_PREFIXES := [
	"ascetic_mountain",
	"shadow_alley",
	"sacred_seven",
	"stone_tower",
	"steelworks",
	"misty_port",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_scene_aligned_hotspot_assets.gd --")
	test_all_51_scene_aligned_hotspot_textures_exist_under_client_assets()
	test_all_51_scene_aligned_hotspots_registered_in_manifest()
	test_all_scene_aligned_hotspot_links_resolve_to_hub_or_location_data()
	test_no_orphan_scene_aligned_hotspot_textures()
	return {"passed": _passed, "failed": _failed}


func test_all_51_scene_aligned_hotspot_textures_exist_under_client_assets() -> void:
	var missing: Array[String] = []
	for spec in _hotspot_specs():
		var path := _expected_path(spec)
		if not ResourceLoader.exists(path):
			missing.append(path)
	assert_eq(_hotspot_specs().size(), 51, "scene-aligned hotspot expectation list contains all 51 generated PNGs")
	assert_true(missing.is_empty(), "all 51 scene-aligned hotspot textures exist under client assets: %s" % ", ".join(missing))


func test_all_51_scene_aligned_hotspots_registered_in_manifest() -> void:
	var assets := _manifest_assets()
	var missing: Array[String] = []
	var invalid: Array[String] = []
	for spec in _hotspot_specs():
		var asset_id := str(spec.get("asset_id", ""))
		if not assets.has(asset_id):
			missing.append(asset_id)
			continue
		var entry: Dictionary = assets[asset_id]
		if str(entry.get("kind", "")) != "texture":
			invalid.append("%s kind=%s" % [asset_id, str(entry.get("kind", ""))])
		if str(entry.get("category", "")) != "hotspot":
			invalid.append("%s category=%s" % [asset_id, str(entry.get("category", ""))])
		if str(entry.get("runtime_status", "")) != "integrated":
			invalid.append("%s runtime_status=%s" % [asset_id, str(entry.get("runtime_status", ""))])
		if str(entry.get("path", "")) != _expected_path(spec):
			invalid.append("%s path=%s" % [asset_id, str(entry.get("path", ""))])
		if str(entry.get("source", "")) != str(spec.get("source", "")):
			invalid.append("%s source=%s" % [asset_id, str(entry.get("source", ""))])
		if str(entry.get("linked_data_id", "")) != str(spec.get("linked_data_id", "")):
			invalid.append("%s linked_data_id=%s" % [asset_id, str(entry.get("linked_data_id", ""))])
	assert_eq(_category_entries(assets, "hotspot").size(), 51, "pixel asset manifest has exactly 51 hotspot entries")
	assert_true(missing.is_empty(), "all 51 scene-aligned hotspots are registered in manifest: %s" % ", ".join(missing))
	assert_true(invalid.is_empty(), "all 51 scene-aligned hotspot manifest entries use integrated texture schema: %s" % ", ".join(invalid))


func test_all_scene_aligned_hotspot_links_resolve_to_hub_or_location_data() -> void:
	var missing: Array[String] = []
	for spec in _hotspot_specs():
		var linked_data_id := str(spec.get("linked_data_id", ""))
		if linked_data_id.begins_with("hub_"):
			if not _hub_runtime_token_exists(linked_data_id):
				missing.append(linked_data_id)
		elif not _location_hotspot_exists(linked_data_id):
			missing.append(linked_data_id)
	assert_true(missing.is_empty(), "all scene-aligned hotspot linked_data_id values resolve to hub runtime tokens or location hotspot ids: %s" % ", ".join(missing))


func test_no_orphan_scene_aligned_hotspot_textures() -> void:
	var manifest_paths := {}
	for entry in _category_entries(_manifest_assets(), "hotspot"):
		manifest_paths[str((entry as Dictionary).get("path", ""))] = true
	var orphans: Array[String] = []
	orphans.append_array(_orphan_hotspot_textures(HUB_TEXTURE_DIR, manifest_paths))
	orphans.append_array(_orphan_hotspot_textures(HOTSPOT_TEXTURE_DIR, manifest_paths))
	assert_true(orphans.is_empty(), "no hotspot_*.png under hub/hotspots lacks a matching manifest path: %s" % ", ".join(orphans))


func _hotspot_specs() -> Array:
	var specs: Array = []
	for row in HOTSPOT_ASSET_ROWS:
		var parts := str(row).split("|", false)
		specs.append({
			"asset_id": str(parts[0]),
			"filename": str(parts[1]),
			"linked_data_id": str(parts[2]),
			"source_filename": str(parts[3]),
			"source": "%s/%s" % [HOTSPOT_SOURCE_DIR, str(parts[3])],
			"texture_dir": HUB_TEXTURE_DIR if str(parts[4]) == "hub" else HOTSPOT_TEXTURE_DIR,
		})
	return specs


func _expected_path(spec: Dictionary) -> String:
	return "%s/%s" % [str(spec.get("texture_dir", "")), str(spec.get("filename", ""))]


func _manifest_root() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _manifest_assets() -> Dictionary:
	return _manifest_root().get("assets", {})


func _category_entries(assets: Dictionary, category: String) -> Array:
	var result: Array = []
	for asset_id in assets.keys():
		var entry: Variant = assets[asset_id]
		if not entry is Dictionary:
			continue
		if str((entry as Dictionary).get("category", "")) == category:
			var item := (entry as Dictionary).duplicate(true)
			item["asset_id"] = str(asset_id)
			result.append(item)
	return result


func _hub_runtime_token_exists(linked_data_id: String) -> bool:
	if not HUB_RUNTIME_TOKENS.has(linked_data_id):
		return false
	var source := FileAccess.get_file_as_string(HUB_SCRIPT_PATH)
	return source.find(str(HUB_RUNTIME_TOKENS[linked_data_id])) >= 0


func _location_hotspot_exists(linked_data_id: String) -> bool:
	for district_id in DISTRICT_PREFIXES:
		var prefix := "%s_" % district_id
		if not linked_data_id.begins_with(prefix):
			continue
		var local_id := linked_data_id.trim_prefix(prefix)
		return _location_has_hotspot_id(district_id, local_id)
	return false


func _location_has_hotspot_id(district_id: String, local_id: String) -> bool:
	var path := "%s/%s.json" % [LOCATION_DIR, district_id]
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


func _orphan_hotspot_textures(texture_dir: String, manifest_paths: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(texture_dir)
	if dir == null:
		return result
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if filename.ends_with(".png") and filename.begins_with("hotspot_"):
			var path := "%s/%s" % [texture_dir, filename]
			if not manifest_paths.has(path):
				result.append(path)
		filename = dir.get_next()
	dir.list_dir_end()
	return result


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
