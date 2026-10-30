extends RefCounted

const MANIFEST_PATH := "res://assets/art_specs/pixel_asset_manifest.json"
const TOWER_TEXTURE_DIR := "res://assets/textures/towers"
const DISTRICT_TEXTURE_DIR := "res://assets/textures/districts"
const ONBOARDING_TEXTURE_DIR := "res://assets/textures/onboarding"
const ONBOARDING_PLACEHOLDER_PATHS_FIELD := "onboarding_scene_placeholder_paths"
const ONBOARDING_PLACEHOLDER_STRATEGY_FIELD := "onboarding_scene_placeholder_strategy"

const TOWER_ASSET_ROWS := [
	"tower_shadow_alley_morning|tower_shadow_alley_morning.png|tower_shadow_alley|001-env-tower-shadow_alley-morning.png",
	"tower_shadow_alley_noon|tower_shadow_alley_noon.png|tower_shadow_alley|002-env-tower-shadow_alley-noon.png",
	"tower_shadow_alley_evening|tower_shadow_alley_evening.png|tower_shadow_alley|003-env-tower-shadow_alley-evening.png",
	"tower_shadow_alley_night|tower_shadow_alley_night.png|tower_shadow_alley|004-env-tower-shadow_alley-night.png",
	"tower_steelworks_morning|tower_steelworks_morning.png|tower_steelworks|005-env-tower-steelworks-morning.png",
	"tower_steelworks_noon|tower_steelworks_noon.png|tower_steelworks|006-env-tower-steelworks-noon.png",
	"tower_steelworks_evening|tower_steelworks_evening.png|tower_steelworks|007-env-tower-steelworks-evening.png",
	"tower_steelworks_night|tower_steelworks_night.png|tower_steelworks|008-env-tower-steelworks-night.png",
	"tower_misty_port_morning|tower_misty_port_morning.png|tower_misty_port|009-env-tower-misty_port-morning.png",
	"tower_misty_port_noon|tower_misty_port_noon.png|tower_misty_port|010-env-tower-misty_port-noon.png",
	"tower_misty_port_evening|tower_misty_port_evening.png|tower_misty_port|011-env-tower-misty_port-evening.png",
	"tower_misty_port_night|tower_misty_port_night.png|tower_misty_port|012-env-tower-misty_port-night.png",
]

const DISTRICT_ASSET_ROWS := [
	"district_shadow_alley|district_shadow_alley.png|shadow_alley|013-district-shadow_alley-base.png",
	"district_steelworks|district_steelworks.png|steelworks|014-district-steelworks-base.png",
	"district_misty_port|district_misty_port.png|misty_port|015-district-misty_port-base.png",
	"district_sacred_seven|district_sacred_seven.png|sacred_seven|016-district-sacred_seven-base.png",
	"district_stone_tower|district_stone_tower.png|stone_tower|017-district-stone_tower-base.png",
	"district_ascetic_mountain|district_ascetic_mountain.png|ascetic_mountain|018-district-ascetic_mountain-base.png",
	"district_shadow_alley_morning|district_shadow_alley_morning.png|shadow_alley|019-district-shadow_alley-morning.png",
	"district_shadow_alley_noon|district_shadow_alley_noon.png|shadow_alley|020-district-shadow_alley-noon.png",
	"district_shadow_alley_evening|district_shadow_alley_evening.png|shadow_alley|021-district-shadow_alley-evening.png",
	"district_shadow_alley_night|district_shadow_alley_night.png|shadow_alley|022-district-shadow_alley-night.png",
	"district_steelworks_morning|district_steelworks_morning.png|steelworks|023-district-steelworks-morning.png",
	"district_steelworks_noon|district_steelworks_noon.png|steelworks|024-district-steelworks-noon.png",
	"district_steelworks_evening|district_steelworks_evening.png|steelworks|025-district-steelworks-evening.png",
	"district_steelworks_night|district_steelworks_night.png|steelworks|026-district-steelworks-night.png",
	"district_misty_port_morning|district_misty_port_morning.png|misty_port|027-district-misty_port-morning.png",
	"district_misty_port_noon|district_misty_port_noon.png|misty_port|028-district-misty_port-noon.png",
	"district_misty_port_evening|district_misty_port_evening.png|misty_port|029-district-misty_port-evening.png",
	"district_misty_port_night|district_misty_port_night.png|misty_port|030-district-misty_port-night.png",
	"district_sacred_seven_morning|district_sacred_seven_morning.png|sacred_seven|031-district-sacred_seven-morning.png",
	"district_sacred_seven_noon|district_sacred_seven_noon.png|sacred_seven|032-district-sacred_seven-noon.png",
	"district_sacred_seven_evening|district_sacred_seven_evening.png|sacred_seven|033-district-sacred_seven-evening.png",
	"district_sacred_seven_night|district_sacred_seven_night.png|sacred_seven|034-district-sacred_seven-night.png",
	"district_stone_tower_morning|district_stone_tower_morning.png|stone_tower|035-district-stone_tower-morning.png",
	"district_stone_tower_noon|district_stone_tower_noon.png|stone_tower|036-district-stone_tower-noon.png",
	"district_stone_tower_evening|district_stone_tower_evening.png|stone_tower|037-district-stone_tower-evening.png",
	"district_stone_tower_night|district_stone_tower_night.png|stone_tower|038-district-stone_tower-night.png",
	"district_ascetic_mountain_morning|district_ascetic_mountain_morning.png|ascetic_mountain|039-district-ascetic_mountain-morning.png",
	"district_ascetic_mountain_noon|district_ascetic_mountain_noon.png|ascetic_mountain|040-district-ascetic_mountain-noon.png",
	"district_ascetic_mountain_evening|district_ascetic_mountain_evening.png|ascetic_mountain|041-district-ascetic_mountain-evening.png",
	"district_ascetic_mountain_night|district_ascetic_mountain_night.png|ascetic_mountain|042-district-ascetic_mountain-night.png",
]

const ONBOARDING_INTEGRATED_ROWS := [
	"onboarding_wake_up|onboarding_wake_up.png|wake_up|001-onboarding-wake_up.png",
	"onboarding_mirror_reflection|onboarding_mirror_reflection.png|mirror_reflection|002-onboarding-mirror_reflection.png",
	"onboarding_find_press_id|onboarding_find_press_id.png|find_press_id|003-onboarding-find_press_id.png",
	"onboarding_newspaper_and_notes|onboarding_newspaper_and_notes.png|newspaper_and_notes|004-onboarding-newspaper_and_notes.png",
	"onboarding_knocking_old_li|onboarding_knocking_old_li.png|knocking_old_li|005-onboarding-knocking_old_li.png",
]

const ONBOARDING_PLACEHOLDER_ROWS := [
	"onboarding_first_acting_check|onboarding_newspaper_and_notes.png|first_acting_check|006-onboarding-first_acting_check.png",
	"onboarding_task_arrow_to_seven_holy|onboarding_find_press_id.png|task_arrow_to_seven_holy|007-onboarding-task_arrow_to_seven_holy.png",
	"onboarding_leaving_home|onboarding_find_press_id.png|leaving_home|008-onboarding-leaving_home.png",
	"onboarding_drunkard_encounter|onboarding_knocking_old_li.png|drunkard_encounter|009-onboarding-drunkard_encounter.png",
	"onboarding_tutorial_battle|onboarding_find_press_id.png|tutorial_battle|010-onboarding-tutorial_battle.png",
	"onboarding_first_card_drop|onboarding_newspaper_and_notes.png|first_card_drop|011-onboarding-first_card_drop.png",
	"onboarding_drunkard_foreshadow|onboarding_knocking_old_li.png|drunkard_foreshadow|012-onboarding-drunkard_foreshadow.png",
	"onboarding_bell_tower_arrival|onboarding_find_press_id.png|bell_tower_arrival|013-onboarding-bell_tower_arrival.png",
	"onboarding_brandon_encounter|onboarding_knocking_old_li.png|brandon_encounter|014-onboarding-brandon_encounter.png",
	"onboarding_second_acting_check|onboarding_newspaper_and_notes.png|second_acting_check|015-onboarding-second_acting_check.png",
	"onboarding_victor_rumor|onboarding_knocking_old_li.png|victor_rumor|016-onboarding-victor_rumor.png",
	"onboarding_return_home|onboarding_wake_up.png|return_home|017-onboarding-return_home.png",
	"onboarding_forge_tutorial_intro|onboarding_newspaper_and_notes.png|forge_tutorial_intro|018-onboarding-forge_tutorial_intro.png",
	"onboarding_forge_phigros_tutorial|onboarding_newspaper_and_notes.png|forge_phigros_tutorial|019-onboarding-forge_phigros_tutorial.png",
	"onboarding_first_forge_result|onboarding_newspaper_and_notes.png|first_forge_result|020-onboarding-first_forge_result.png",
	"onboarding_weird_chanting|onboarding_wake_up.png|weird_chanting|021-onboarding-weird_chanting.png",
	"onboarding_basement_discovery|onboarding_wake_up.png|basement_discovery|022-onboarding-basement_discovery.png",
	"onboarding_true_notebook|onboarding_newspaper_and_notes.png|true_notebook|023-onboarding-true_notebook.png",
	"onboarding_ai_gm_revelation|onboarding_wake_up.png|ai_gm_revelation|024-onboarding-ai_gm_revelation.png",
	"onboarding_dream_pendulum|onboarding_wake_up.png|dream_pendulum|025-onboarding-dream_pendulum.png",
]

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


func run() -> Dictionary:
	print("\n-- test_environment_onboarding_assets.gd --")
	test_t3_environment_and_onboarding_textures_exist_under_client_assets()
	test_t3_assets_registered_in_pixel_asset_manifest()
	test_t3_asset_linked_data_ids_or_reference_strategy_resolve()
	test_no_orphan_t3_textures()
	test_tower_and_district_naming_mappings_follow_spec()
	test_onboarding_6_25_placeholder_fallback_strategy_is_manifested()
	test_extra_environment_overlay_is_left_as_style_backup()
	return {"passed": _passed, "failed": _failed}


func test_t3_environment_and_onboarding_textures_exist_under_client_assets() -> void:
	var missing: Array[String] = []
	for spec in _integrated_specs():
		var path := "%s/%s" % [str(spec.get("texture_dir", "")), str(spec.get("filename", ""))]
		if not ResourceLoader.exists(path):
			missing.append(path)
	assert_eq(_tower_specs().size(), 12, "tower expectation list contains all 12 generated tower backgrounds")
	assert_eq(_district_specs().size(), 30, "district expectation list contains 6 base + 24 phase backgrounds")
	assert_eq(_onboarding_integrated_specs().size(), 5, "onboarding expectation list contains the 5 generated P0 scenes")
	assert_true(missing.is_empty(), "all T3 integrated tower/district/onboarding textures exist under client assets: %s" % ", ".join(missing))


func test_t3_assets_registered_in_pixel_asset_manifest() -> void:
	var assets := _manifest_assets()
	var invalid: Array[String] = []
	var missing: Array[String] = []
	for spec in _all_specs():
		var asset_id := str(spec.get("asset_id", ""))
		if not assets.has(asset_id):
			missing.append(asset_id)
			continue
		var entry: Dictionary = assets[asset_id]
		var expected_path := "%s/%s" % [str(spec.get("texture_dir", "")), str(spec.get("filename", ""))]
		if str(entry.get("kind", "")) != "texture":
			invalid.append("%s kind=%s" % [asset_id, str(entry.get("kind", ""))])
		if str(entry.get("category", "")) != str(spec.get("category", "")):
			invalid.append("%s category=%s" % [asset_id, str(entry.get("category", ""))])
		if str(entry.get("runtime_status", "")) != str(spec.get("runtime_status", "")):
			invalid.append("%s runtime_status=%s" % [asset_id, str(entry.get("runtime_status", ""))])
		if str(entry.get("path", "")) != expected_path:
			invalid.append("%s path=%s" % [asset_id, str(entry.get("path", ""))])
		if str(entry.get("source", "")) != str(spec.get("source", "")):
			invalid.append("%s source=%s" % [asset_id, str(entry.get("source", ""))])
		if str(entry.get("linked_data_id", "")) != str(spec.get("linked_data_id", "")):
			invalid.append("%s linked_data_id=%s" % [asset_id, str(entry.get("linked_data_id", ""))])
	assert_eq(_category_entries(assets, "tower").size(), 12, "pixel asset manifest has exactly 12 tower entries")
	assert_eq(_category_entries(assets, "district").size(), 30, "pixel asset manifest has exactly 30 district entries")
	assert_eq(_category_entries(assets, "onboarding").size(), 25, "pixel asset manifest has 5 integrated + 20 placeholder onboarding entries")
	assert_true(missing.is_empty(), "all T3 generated or placeholder assets are registered in manifest: %s" % ", ".join(missing))
	assert_true(invalid.is_empty(), "all T3 manifest entries use the expected texture schema: %s" % ", ".join(invalid))


func test_t3_asset_linked_data_ids_or_reference_strategy_resolve() -> void:
	var assets := _manifest_assets()
	var missing: Array[String] = []
	for spec in _all_specs():
		var asset_id := str(spec.get("asset_id", ""))
		var entry: Dictionary = assets.get(asset_id, {})
		var category := str(entry.get("category", spec.get("category", "")))
		var linked_data_id := str(entry.get("linked_data_id", spec.get("linked_data_id", "")))
		if not _linked_reference_exists(category, linked_data_id):
			missing.append("%s -> %s" % [asset_id, linked_data_id])
	assert_true(missing.is_empty(), "all T3 linked_data_id values resolve through client data or manifest fallback strategy: %s" % ", ".join(missing))


func test_no_orphan_t3_textures() -> void:
	var assets := _manifest_assets()
	var orphans: Array[String] = []
	orphans.append_array(_orphan_textures(TOWER_TEXTURE_DIR, _category_entries(assets, "tower"), "tower_"))
	orphans.append_array(_orphan_textures(DISTRICT_TEXTURE_DIR, _category_entries(assets, "district"), "district_"))
	orphans.append_array(_orphan_textures(ONBOARDING_TEXTURE_DIR, _category_entries(assets, "onboarding"), "onboarding_"))
	assert_true(orphans.is_empty(), "no T3 tower/district/onboarding PNG exists without a matching manifest entry: %s" % ", ".join(orphans))


func test_tower_and_district_naming_mappings_follow_spec() -> void:
	var tower_invalid: Array[String] = []
	for spec in _tower_specs():
		if str(spec.get("filename", "")) != "%s.png" % str(spec.get("asset_id", "")):
			tower_invalid.append("%s -> %s" % [str(spec.get("source_filename", "")), str(spec.get("filename", ""))])
	var district_invalid: Array[String] = []
	for spec in _district_specs():
		if str(spec.get("filename", "")) != "%s.png" % str(spec.get("asset_id", "")):
			district_invalid.append("%s -> %s" % [str(spec.get("source_filename", "")), str(spec.get("filename", ""))])
	assert_true(tower_invalid.is_empty(), "12 tower filenames map to tower_<district>_<phase>.png: %s" % ", ".join(tower_invalid))
	assert_true(district_invalid.is_empty(), "30 district filenames map to district_<district>[_<phase>].png: %s" % ", ".join(district_invalid))


func test_onboarding_6_25_placeholder_fallback_strategy_is_manifested() -> void:
	var fallback_map: Dictionary = _manifest_root().get("placeholder_fallbacks", {})
	var paths: Variant = fallback_map.get(ONBOARDING_PLACEHOLDER_PATHS_FIELD, {})
	assert_true(str(fallback_map.get(ONBOARDING_PLACEHOLDER_STRATEGY_FIELD, "")).contains("scene_06-scene_25"), "manifest records onboarding 6-25 placeholder strategy text")
	assert_true(paths is Dictionary, "manifest records onboarding 6-25 placeholder fallback path dictionary")
	if not paths is Dictionary:
		return
	var invalid: Array[String] = []
	for spec in _onboarding_placeholder_specs():
		var asset_id := str(spec.get("asset_id", ""))
		var expected_path := "%s/%s" % [ONBOARDING_TEXTURE_DIR, str(spec.get("filename", ""))]
		if str((paths as Dictionary).get(asset_id, "")) != expected_path:
			invalid.append("%s -> %s" % [asset_id, str((paths as Dictionary).get(asset_id, ""))])
		if not ResourceLoader.exists(expected_path):
			invalid.append("%s fallback texture missing: %s" % [asset_id, expected_path])
	assert_eq((paths as Dictionary).size(), 20, "manifest placeholder fallback dictionary covers onboarding 6-25")
	assert_true(invalid.is_empty(), "all onboarding 6-25 placeholders point at existing first-five fallback scene textures: %s" % ", ".join(invalid))


func test_extra_environment_overlay_is_left_as_style_backup() -> void:
	var assets := _manifest_assets()
	var overlay_paths := [
		"res://assets/textures/towers/weather_fog_overlay.png",
		"res://assets/textures/districts/weather_fog_overlay.png",
		"res://assets/textures/onboarding/weather_fog_overlay.png",
	]
	var copied: Array[String] = []
	for path in overlay_paths:
		if ResourceLoader.exists(path):
			copied.append(path)
	assert_true(not assets.has("weather_fog_overlay"), "extra 043 weather fog overlay is not integrated into manifest for T3")
	assert_true(copied.is_empty(), "extra 043 weather fog overlay is not copied into T3 runtime texture dirs: %s" % ", ".join(copied))


func _tower_specs() -> Array:
	return _specs_from_rows(TOWER_ASSET_ROWS, "tower", TOWER_TEXTURE_DIR, "output/imagegen/greycrown_environments_full", "integrated")


func _district_specs() -> Array:
	return _specs_from_rows(DISTRICT_ASSET_ROWS, "district", DISTRICT_TEXTURE_DIR, "output/imagegen/greycrown_environments_full", "integrated")


func _onboarding_integrated_specs() -> Array:
	return _specs_from_rows(ONBOARDING_INTEGRATED_ROWS, "onboarding", ONBOARDING_TEXTURE_DIR, "output/imagegen/greycrown_onboarding_scenes_full_25", "integrated")


func _onboarding_placeholder_specs() -> Array:
	return _specs_from_rows(ONBOARDING_PLACEHOLDER_ROWS, "onboarding", ONBOARDING_TEXTURE_DIR, "placeholder_fallback:onboarding_scene_6_25", "placeholder")


func _integrated_specs() -> Array:
	var specs := []
	specs.append_array(_tower_specs())
	specs.append_array(_district_specs())
	specs.append_array(_onboarding_integrated_specs())
	return specs


func _all_specs() -> Array:
	var specs := _integrated_specs()
	specs.append_array(_onboarding_placeholder_specs())
	return specs


func _specs_from_rows(rows: Array, category: String, texture_dir: String, source_dir: String, runtime_status: String) -> Array:
	var specs: Array = []
	for row in rows:
		var parts := str(row).split("|", false)
		var source_filename := str(parts[3])
		var source := "%s/%s" % [source_dir, source_filename] if runtime_status == "integrated" else "%s/%s" % [source_dir, str(parts[1])]
		specs.append({
			"asset_id": str(parts[0]),
			"filename": str(parts[1]),
			"linked_data_id": str(parts[2]),
			"source_filename": source_filename,
			"source": source,
			"category": category,
			"texture_dir": texture_dir,
			"runtime_status": runtime_status,
		})
	return specs


func _manifest_root() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _manifest_assets() -> Dictionary:
	var root := _manifest_root()
	var assets: Variant = root.get("assets", {})
	if assets is Dictionary:
		return (assets as Dictionary).duplicate(true)
	return {}


func _category_entries(assets: Dictionary, category: String) -> Dictionary:
	var result := {}
	for asset_id in assets.keys():
		var entry: Variant = assets[asset_id]
		if entry is Dictionary and str((entry as Dictionary).get("category", "")) == category:
			result[str(asset_id)] = (entry as Dictionary)
	return result


func _orphan_textures(texture_dir: String, entries: Dictionary, filename_prefix: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(texture_dir)
	if dir == null:
		result.append("%s/<missing directory>" % texture_dir)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png") and file_name.begins_with(filename_prefix):
			var resource_path := "%s/%s" % [texture_dir, file_name]
			var has_manifest_entry := false
			for entry in entries.values():
				if str((entry as Dictionary).get("path", "")) == resource_path:
					has_manifest_entry = true
					break
			if not has_manifest_entry:
				result.append(resource_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


func _linked_reference_exists(category: String, linked_data_id: String) -> bool:
	match category:
		"tower":
			return _tower_reference_exists(linked_data_id)
		"district":
			return _district_reference_exists(linked_data_id)
		"onboarding":
			return _onboarding_reference_exists(linked_data_id)
	return false


func _tower_reference_exists(linked_data_id: String) -> bool:
	if not linked_data_id.begins_with("tower_"):
		return false
	var district_id := linked_data_id.trim_prefix("tower_")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/towers/boss_table.json"))
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
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/districts/district_data.json"))
	if not parsed is Dictionary:
		return result
	var districts: Variant = (parsed as Dictionary).get("districts", [])
	if not districts is Array:
		return result
	for district in districts:
		if district is Dictionary:
			result[str((district as Dictionary).get("id", ""))] = true
	return result


func _onboarding_reference_exists(linked_data_id: String) -> bool:
	return ONBOARDING_REFERENCE_IDS.has(linked_data_id)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual, expected, message: String) -> void:
	if actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])
