extends RefCounted

const CardLibraryScript = preload("res://scripts/combat/card_library.gd")

const MANIFEST_PATH := "res://assets/art_specs/pixel_asset_manifest.json"
const CARD_TEXTURE_DIR := "res://assets/textures/cards"

const CARD_ASSET_ROWS := [
	"card_chariot_s7_thunder_boarding|card_chariot_s7_thunder_boarding.png|chariot_s7_thunder_boarding|001-card-chariot-s7-chariot_s7_thunder_boarding.png",
	"card_chariot_s8_reef_breaker|card_chariot_s8_reef_breaker.png|chariot_s8_reef_breaker|002-card-chariot-s8-chariot_s8_reef_breaker.png",
	"card_chariot_s8_storm_pulse|card_chariot_s8_storm_pulse.png|chariot_s8_storm_pulse|003-card-chariot-s8-chariot_s8_storm_pulse.png",
	"card_chariot_s9_sailor_shout|card_chariot_s9_sailor_shout.png|chariot_s9_sailor_shout|004-card-chariot-s9-chariot_s9_sailor_shout.png",
	"card_chariot_s9_tide_cut|card_chariot_s9_tide_cut.png|chariot_s9_tide_cut|005-card-chariot-s9-chariot_s9_tide_cut.png",
	"card_arrow_water|card_arrow_water.png|arrow_water|006-card-common-s9-arrow_water.png",
	"card_flame_arrow|card_flame_arrow.png|flame_arrow|007-card-common-s9-flame_arrow.png",
	"card_flame_water|card_flame_water.png|flame_water|008-card-common-s9-flame_water.png",
	"card_fortune_arrow|card_fortune_arrow.png|fortune_arrow|009-card-common-s9-fortune_arrow.png",
	"card_inquiry_arrow|card_inquiry_arrow.png|inquiry_arrow|010-card-common-s9-inquiry_arrow.png",
	"card_jester_arrow|card_jester_arrow.png|jester_arrow|011-card-common-s9-jester_arrow.png",
	"card_mirror_arrow|card_mirror_arrow.png|mirror_arrow|012-card-common-s9-mirror_arrow.png",
	"card_name_arrow|card_name_arrow.png|name_arrow|013-card-common-s9-name_arrow.png",
	"card_fool_s9_shadow_arrow|card_fool_s9_shadow_arrow.png|shadow_arrow|014-card-common-s9-shadow_arrow.png",
	"card_shadow_flame|card_shadow_flame.png|shadow_flame|015-card-common-s9-shadow_flame.png",
	"card_thread_arrow|card_thread_arrow.png|thread_arrow|016-card-common-s9-thread_arrow.png",
	"card_water_touch|card_water_touch.png|water_touch|017-card-common-s9-water_touch.png",
	"card_death_s7_reaper_hook|card_death_s7_reaper_hook.png|death_s7_reaper_hook|018-card-death-s7-death_s7_reaper_hook.png",
	"card_death_s8_mourning_touch|card_death_s8_mourning_touch.png|death_s8_mourning_touch|019-card-death-s8-death_s8_mourning_touch.png",
	"card_death_s8_wither_breath|card_death_s8_wither_breath.png|death_s8_wither_breath|020-card-death-s8-death_s8_wither_breath.png",
	"card_death_s9_bone_splinter|card_death_s9_bone_splinter.png|death_s9_bone_splinter|021-card-death-s9-death_s9_bone_splinter.png",
	"card_death_s9_grave_chill|card_death_s9_grave_chill.png|death_s9_grave_chill|022-card-death-s9-death_s9_grave_chill.png",
	"card_emperor_s7_verdict_crush|card_emperor_s7_verdict_crush.png|emperor_s7_verdict_crush|023-card-emperor-s7-emperor_s7_verdict_crush.png",
	"card_emperor_s8_debt_mark|card_emperor_s8_debt_mark.png|emperor_s8_debt_mark|024-card-emperor-s8-emperor_s8_debt_mark.png",
	"card_emperor_s8_tax_blood|card_emperor_s8_tax_blood.png|emperor_s8_tax_blood|025-card-emperor-s8-emperor_s8_tax_blood.png",
	"card_emperor_s9_contract_bind|card_emperor_s9_contract_bind.png|emperor_s9_contract_bind|026-card-emperor-s9-emperor_s9_contract_bind.png",
	"card_emperor_s9_legal_notice|card_emperor_s9_legal_notice.png|emperor_s9_legal_notice|027-card-emperor-s9-emperor_s9_legal_notice.png",
	"card_fool_s7_air_bullet|card_fool_s7_air_bullet.png|fool_s7_air_bullet|028-card-fool-s7-fool_s7_air_bullet.png",
	"card_fool_s7_bone_softening|card_fool_s7_bone_softening.png|fool_s7_bone_softening|029-card-fool-s7-fool_s7_bone_softening.png",
	"card_fool_s7_flame_command|card_fool_s7_flame_command.png|fool_s7_flame_command|030-card-fool-s7-fool_s7_flame_command.png",
	"card_fool_s7_flame_jump|card_fool_s7_flame_jump.png|fool_s7_flame_jump|031-card-fool-s7-fool_s7_flame_jump.png",
	"card_fool_s7_illusion_weave|card_fool_s7_illusion_weave.png|fool_s7_illusion_weave|032-card-fool-s7-fool_s7_illusion_weave.png",
	"card_fool_s7_minor_trick|card_fool_s7_minor_trick.png|fool_s7_minor_trick|033-card-fool-s7-fool_s7_minor_trick.png",
	"card_fool_s7_paper_arsenal|card_fool_s7_paper_arsenal.png|fool_s7_paper_arsenal|034-card-fool-s7-fool_s7_paper_arsenal.png",
	"card_fool_s7_paper_doll_substitute|card_fool_s7_paper_doll_substitute.png|fool_s7_paper_doll_substitute|035-card-fool-s7-fool_s7_paper_doll_substitute.png",
	"card_fool_s7_swift_cast|card_fool_s7_swift_cast.png|fool_s7_swift_cast|036-card-fool-s7-fool_s7_swift_cast.png",
	"card_fool_s7_water_breath|card_fool_s7_water_breath.png|fool_s7_water_breath|037-card-fool-s7-fool_s7_water_breath.png",
	"card_fool_s7_wound_displacement|card_fool_s7_wound_displacement.png|fool_s7_wound_displacement|038-card-fool-s7-fool_s7_wound_displacement.png",
	"card_fool_s8_acrobat_strike|card_fool_s8_acrobat_strike.png|fool_s8_acrobat_strike|039-card-fool-s8-fool_s8_acrobat_strike.png",
	"card_fool_s8_microexpression_read|card_fool_s8_microexpression_read.png|fool_s8_microexpression_read|040-card-fool-s8-fool_s8_microexpression_read.png",
	"card_fool_s8_paper_blade_volley|card_fool_s8_paper_blade_volley.png|fool_s8_paper_blade_volley|041-card-fool-s8-fool_s8_paper_blade_volley.png",
	"card_fool_s8_predator_instinct|card_fool_s8_predator_instinct.png|fool_s8_predator_instinct|042-card-fool-s8-fool_s8_predator_instinct.png",
	"card_fool_s8_strongman_burst|card_fool_s8_strongman_burst.png|fool_s8_strongman_burst|043-card-fool-s8-fool_s8_strongman_burst.png",
	"card_fortune_thread|card_fortune_thread.png|fortune_thread|044-card-fool-s8-fortune_thread.png",
	"card_inquiry_fortune|card_inquiry_fortune.png|inquiry_fortune|045-card-fool-s8-inquiry_fortune.png",
	"card_inquiry_mirror|card_inquiry_mirror.png|inquiry_mirror|046-card-fool-s8-inquiry_mirror.png",
	"card_inquiry_name|card_inquiry_name.png|inquiry_name|047-card-fool-s8-inquiry_name.png",
	"card_jester_face|card_jester_face.png|jester_face|048-card-fool-s8-jester_face.png",
	"card_jester_fortune|card_jester_fortune.png|jester_fortune|049-card-fool-s8-jester_fortune.png",
	"card_jester_name|card_jester_name.png|jester_name|050-card-fool-s8-jester_name.png",
	"card_mirror_face|card_mirror_face.png|mirror_face|051-card-fool-s8-mirror_face.png",
	"card_mirror_shadow|card_mirror_shadow.png|mirror_shadow|052-card-fool-s8-mirror_shadow.png",
	"card_shadow_jester|card_shadow_jester.png|shadow_jester|053-card-fool-s8-shadow_jester.png",
	"card_shadow_name|card_shadow_name.png|shadow_name|054-card-fool-s8-shadow_name.png",
	"card_shadow_thread|card_shadow_thread.png|shadow_thread|055-card-fool-s8-shadow_thread.png",
	"card_fool_s9_arcane_lore|card_fool_s9_arcane_lore.png|fool_s9_arcane_lore|056-card-fool-s9-fool_s9_arcane_lore.png",
	"card_fool_s9_pendulum_query|card_fool_s9_pendulum_query.png|fool_s9_pendulum_query|057-card-fool-s9-fool_s9_pendulum_query.png",
	"card_fool_s9_premonition|card_fool_s9_premonition.png|fool_s9_premonition|058-card-fool-s9-fool_s9_premonition.png",
	"card_fool_s9_ritual_chant|card_fool_s9_ritual_chant.png|fool_s9_ritual_chant|059-card-fool-s9-fool_s9_ritual_chant.png",
	"card_fool_s9_spirit_vision|card_fool_s9_spirit_vision.png|fool_s9_spirit_vision|060-card-fool-s9-fool_s9_spirit_vision.png",
	"card_fool_s9_star_chart_divination|card_fool_s9_star_chart_divination.png|fool_s9_star_chart_divination|061-card-fool-s9-fool_s9_star_chart_divination.png",
	"card_hermit_s7_spell_backlash|card_hermit_s7_spell_backlash.png|hermit_s7_spell_backlash|062-card-hermit-s7-hermit_s7_spell_backlash.png",
	"card_hermit_s8_archive_flame|card_hermit_s8_archive_flame.png|hermit_s8_archive_flame|063-card-hermit-s8-hermit_s8_archive_flame.png",
	"card_hermit_s8_rune_cage|card_hermit_s8_rune_cage.png|hermit_s8_rune_cage|064-card-hermit-s8-hermit_s8_rune_cage.png",
	"card_hermit_s9_glyph_spark|card_hermit_s9_glyph_spark.png|hermit_s9_glyph_spark|065-card-hermit-s9-hermit_s9_glyph_spark.png",
	"card_hermit_s9_hidden_eye|card_hermit_s9_hidden_eye.png|hermit_s9_hidden_eye|066-card-hermit-s9-hermit_s9_hidden_eye.png",
	"card_priestess_s7_space_fold|card_priestess_s7_space_fold.png|priestess_s7_space_fold|067-card-priestess-s7-priestess_s7_space_fold.png",
	"card_priestess_s8_door_step|card_priestess_s8_door_step.png|priestess_s8_door_step|068-card-priestess-s8-priestess_s8_door_step.png",
	"card_priestess_s9_key_turn|card_priestess_s9_key_turn.png|priestess_s9_key_turn|069-card-priestess-s9-priestess_s9_key_turn.png",
	"card_priestess_s9_mist_bolt|card_priestess_s9_mist_bolt.png|priestess_s9_mist_bolt|070-card-priestess-s9-priestess_s9_mist_bolt.png",
	"card_shadow_water|card_shadow_water.png|shadow_water|071-card-priestess-s9-shadow_water.png",
	"card_tower_s7_dream_eclipse|card_tower_s7_dream_eclipse.png|tower_s7_dream_eclipse|072-card-tower-s7-tower_s7_dream_eclipse.png",
	"card_tower_s8_moonless_field|card_tower_s8_moonless_field.png|tower_s8_moonless_field|073-card-tower-s8-tower_s8_moonless_field.png",
	"card_tower_s8_shadow_claw|card_tower_s8_shadow_claw.png|tower_s8_shadow_claw|074-card-tower-s8-tower_s8_shadow_claw.png",
	"card_tower_s9_night_pebble|card_tower_s9_night_pebble.png|tower_s9_night_pebble|075-card-tower-s9-tower_s9_night_pebble.png",
	"card_tower_s9_quiet_step|card_tower_s9_quiet_step.png|tower_s9_quiet_step|076-card-tower-s9-tower_s9_quiet_step.png",
]

const LINK_SAMPLE_ASSET_IDS := [
	"card_chariot_s7_thunder_boarding",
	"card_fool_s9_shadow_arrow",
	"card_fortune_thread",
	"card_fool_s9_spirit_vision",
	"card_tower_s9_quiet_step",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_card_assets_first_batch.gd --")
	test_all_76_card_textures_exist_under_client_assets()
	test_all_76_cards_registered_in_pixel_asset_manifest()
	test_card_asset_path_links_to_data_id()
	test_no_orphan_card_textures()
	return {"passed": _passed, "failed": _failed}


func test_all_76_card_textures_exist_under_client_assets() -> void:
	var specs := _card_specs()
	var missing: Array[String] = []
	for spec in specs:
		var path := "%s/%s" % [CARD_TEXTURE_DIR, str(spec.get("filename", ""))]
		if not ResourceLoader.exists(path):
			missing.append(path)
	assert_eq(specs.size(), 76, "card asset expectation list contains all 76 generated cards")
	assert_true(missing.is_empty(), "all 76 card textures exist under client assets: %s" % ", ".join(missing))


func test_all_76_cards_registered_in_pixel_asset_manifest() -> void:
	var assets := _manifest_assets()
	var card_entries := _card_entries(assets)
	var missing: Array[String] = []
	var invalid: Array[String] = []
	for spec in _card_specs():
		var asset_id := str(spec.get("asset_id", ""))
		if not card_entries.has(asset_id):
			missing.append(asset_id)
			continue
		var entry: Dictionary = card_entries[asset_id]
		var expected_path := "%s/%s" % [CARD_TEXTURE_DIR, str(spec.get("filename", ""))]
		var expected_source := "output/imagegen/greycrown_cards_full_76/%s" % str(spec.get("source", ""))
		if str(entry.get("kind", "")) != "texture":
			invalid.append("%s kind=%s" % [asset_id, str(entry.get("kind", ""))])
		if str(entry.get("category", "")) != "card":
			invalid.append("%s category=%s" % [asset_id, str(entry.get("category", ""))])
		if str(entry.get("runtime_status", "")) != "integrated":
			invalid.append("%s runtime_status=%s" % [asset_id, str(entry.get("runtime_status", ""))])
		if str(entry.get("path", "")) != expected_path:
			invalid.append("%s path=%s" % [asset_id, str(entry.get("path", ""))])
		if str(entry.get("source", "")) != expected_source:
			invalid.append("%s source=%s" % [asset_id, str(entry.get("source", ""))])
		if str(entry.get("linked_data_id", "")) != str(spec.get("linked_data_id", "")):
			invalid.append("%s linked_data_id=%s" % [asset_id, str(entry.get("linked_data_id", ""))])
	assert_eq(card_entries.size(), 76, "pixel asset manifest has exactly 76 card entries")
	assert_true(missing.is_empty(), "all 76 generated cards are registered in manifest: %s" % ", ".join(missing))
	assert_true(invalid.is_empty(), "all card manifest entries use integrated card schema: %s" % ", ".join(invalid))


func test_card_asset_path_links_to_data_id() -> void:
	var card_library = CardLibraryScript.new()
	card_library.load_all()
	var assets := _manifest_assets()
	var missing: Array[String] = []
	for asset_id in LINK_SAMPLE_ASSET_IDS:
		var entry: Dictionary = assets.get(asset_id, {})
		var linked_data_id := str(entry.get("linked_data_id", ""))
		var card = card_library.get_card(linked_data_id)
		if card == null:
			missing.append("%s -> %s" % [asset_id, linked_data_id])
	assert_true(missing.is_empty(), "sample card manifest linked_data_id values resolve through CardLibrary: %s" % ", ".join(missing))


func test_no_orphan_card_textures() -> void:
	var expected := _expected_filenames()
	var assets := _manifest_assets()
	var card_entries := _card_entries(assets)
	var orphaned: Array[String] = []
	var dir := DirAccess.open(CARD_TEXTURE_DIR)
	assert_true(dir != null, "card texture directory exists")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".png"):
			var resource_path := "%s/%s" % [CARD_TEXTURE_DIR, file_name]
			var has_manifest_entry := false
			for entry in card_entries.values():
				if str((entry as Dictionary).get("path", "")) == resource_path:
					has_manifest_entry = true
					break
			if not expected.has(file_name) or not has_manifest_entry:
				orphaned.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	assert_true(orphaned.is_empty(), "no card PNG exists without a matching manifest entry: %s" % ", ".join(orphaned))


func _card_specs() -> Array:
	var specs: Array = []
	for row in CARD_ASSET_ROWS:
		var parts := str(row).split("|", false)
		specs.append({
			"asset_id": str(parts[0]),
			"filename": str(parts[1]),
			"linked_data_id": str(parts[2]),
			"source": str(parts[3]),
		})
	return specs


func _expected_filenames() -> Dictionary:
	var result := {}
	for spec in _card_specs():
		result[str(spec.get("filename", ""))] = true
	return result


func _manifest_assets() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("assets", {}) is Dictionary:
		return ((parsed as Dictionary).get("assets", {}) as Dictionary).duplicate(true)
	return {}


func _card_entries(assets: Dictionary) -> Dictionary:
	var result := {}
	for asset_id in assets.keys():
		var entry: Variant = assets[asset_id]
		if entry is Dictionary and str((entry as Dictionary).get("category", "")) == "card":
			result[str(asset_id)] = (entry as Dictionary)
	return result


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
