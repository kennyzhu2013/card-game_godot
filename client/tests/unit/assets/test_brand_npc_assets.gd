extends RefCounted

const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")

const MANIFEST_PATH := "res://assets/art_specs/pixel_asset_manifest.json"
const BRAND_TEXTURE_DIR := "res://assets/textures/brands"
const PORTRAIT_TEXTURE_DIR := "res://assets/textures/portraits"
const HUB_TEXTURE_DIR := "res://assets/textures/hub"
const P0_EXPRESSION_FALLBACK_PATH_FIELD := "p0_portrait_expression_path"
const P0_EXPRESSION_FALLBACK_PATH := "res://assets/textures/portraits/portrait_{linked_data_id}.png"

const BRAND_ASSET_ROWS := [
	"brand_fool_shadow_seal|brand_fool_shadow_seal.png|fool_shadow_seal|001-brand-fool_shadow_seal.png",
	"brand_fool_jester_mark|brand_fool_jester_mark.png|fool_jester_mark|002-brand-fool_jester_mark.png",
	"brand_fool_substitute_mark|brand_fool_substitute_mark.png|fool_substitute_mark|003-brand-fool_substitute_mark.png",
	"brand_fool_face_mask_mark|brand_fool_face_mask_mark.png|fool_face_mask_mark|004-brand-fool_face_mask_mark.png",
	"brand_damage_plus_low|brand_damage_plus_low.png|damage_plus_low|005-brand-damage_plus_low.png",
	"brand_damage_plus_mid|brand_damage_plus_mid.png|damage_plus_mid|006-brand-damage_plus_mid.png",
	"brand_cost_minus|brand_cost_minus.png|cost_minus|007-brand-cost_minus.png",
	"brand_heal_plus|brand_heal_plus.png|heal_plus|008-brand-heal_plus.png",
	"brand_pierce|brand_pierce.png|pierce|009-brand-pierce.png",
	"brand_multi_target|brand_multi_target.png|multi_target|010-brand-multi_target.png",
	"brand_fate_thread|brand_fate_thread.png|fate_thread|011-brand-fate_thread.png",
	"brand_silence_brand|brand_silence_brand.png|silence_brand|012-brand-silence_brand.png",
	"brand_crit_brand|brand_crit_brand.png|crit_brand|013-brand-crit_brand.png",
	"brand_draw_on_play|brand_draw_on_play.png|draw_on_play|014-brand-draw_on_play.png",
	"brand_vampire|brand_vampire.png|vampire|015-brand-vampire.png",
	"brand_chain_brand|brand_chain_brand.png|chain_brand|016-brand-chain_brand.png",
	"brand_barrier_brand|brand_barrier_brand.png|barrier_brand|017-brand-barrier_brand.png",
	"brand_delay_brand|brand_delay_brand.png|delay_brand|018-brand-delay_brand.png",
	"brand_mirror_image|brand_mirror_image.png|mirror_image|019-brand-mirror_image.png",
	"brand_phoenix|brand_phoenix.png|phoenix|020-brand-phoenix.png",
	"brand_bloom|brand_bloom.png|bloom|021-brand-bloom.png",
	"brand_echo|brand_echo.png|echo|022-brand-echo.png",
	"brand_truename_brand|brand_truename_brand.png|truename_brand|023-brand-truename_brand.png",
	"brand_voidcrown_brand|brand_voidcrown_brand.png|voidcrown_brand|024-brand-voidcrown_brand.png",
	"brand_forbidden_word|brand_forbidden_word.png|forbidden_word|025-brand-forbidden_word.png",
	"brand_pathwise|brand_pathwise.png|pathwise|026-brand-pathwise.png",
	"brand_forge_residue_low|brand_forge_residue_low.png|forge_residue_low|027-brand-forge_residue_low.png",
	"brand_forge_residue_mid|brand_forge_residue_mid.png|forge_residue_mid|028-brand-forge_residue_mid.png",
	"brand_forge_residue_high|brand_forge_residue_high.png|forge_residue_high|029-brand-forge_residue_high.png",
	"brand_forge_residue_unique|brand_forge_residue_unique.png|forge_residue_unique|030-brand-forge_residue_unique.png",
]

const PORTRAIT_ASSET_ROWS := [
	"portrait_ah_du_streettalker|portrait_ah_du_streettalker.png|ah_du_streettalker|001-portrait-ah_du_streettalker-default.png",
	"portrait_brendan|portrait_brendan.png|brendan|002-portrait-brendan-default.png",
	"portrait_carl_smuggler|portrait_carl_smuggler.png|carl_smuggler|003-portrait-carl_smuggler-default.png",
	"portrait_drunkard|portrait_drunkard.png|drunkard|004-portrait-drunkard-default.png",
	"portrait_eel_fan|portrait_eel_fan.png|eel_fan|005-portrait-eel_fan-default.png",
	"portrait_hanna_gardener|portrait_hanna_gardener.png|hanna_gardener|006-portrait-hanna_gardener-default.png",
	"portrait_harvey_mors|portrait_harvey_mors.png|harvey_mors|007-portrait-harvey_mors-default.png",
	"portrait_marquis_eng|portrait_marquis_eng.png|marquis_eng|008-portrait-marquis_eng-default.png",
	"portrait_martha_rich|portrait_martha_rich.png|martha_rich|009-portrait-martha_rich-default.png",
	"portrait_old_li|portrait_old_li.png|old_li|010-portrait-old_li-default.png",
	"portrait_pendulum|portrait_pendulum.png|pendulum|011-portrait-pendulum-default.png",
	"portrait_peter_furnace|portrait_peter_furnace.png|peter_furnace|012-portrait-peter_furnace-default.png",
	"portrait_red_hand_carl|portrait_red_hand_carl.png|red_hand_carl|013-portrait-red_hand_carl-default.png",
	"portrait_reflection|portrait_reflection.png|reflection|014-portrait-reflection-default.png",
	"portrait_thomas_priest|portrait_thomas_priest.png|thomas_priest|015-portrait-thomas_priest-default.png",
	"portrait_vera_lighthouse|portrait_vera_lighthouse.png|vera_lighthouse|016-portrait-vera_lighthouse-default.png",
	"portrait_victor_kelsey|portrait_victor_kelsey.png|victor_kelsey|017-portrait-victor_kelsey-default.png",
	"portrait_widow_isa|portrait_widow_isa.png|widow_isa|018-portrait-widow_isa-default.png",
	"portrait_xiao_ran|portrait_xiao_ran.png|xiao_ran|019-portrait-xiao_ran-default.png",
	"portrait_xuming_recluse|portrait_xuming_recluse.png|xuming_recluse|020-portrait-xuming_recluse-default.png",
]

const HOTSPOT_ASSET_ROWS := [
	"hotspot_hub_desk_cluster|hotspot_hub_desk_cluster.png|hub_desk_cluster|001-hotspot-hub_desk_cluster.png",
	"hotspot_hub_desk_forge_table|hotspot_hub_desk_forge_table.png|hub_desk_forge_table|002-hotspot-hub_desk_forge_table.png",
	"hotspot_hub_desk_tarot_cards|hotspot_hub_desk_tarot_cards.png|hub_desk_tarot_cards|003-hotspot-hub_desk_tarot_cards.png",
	"hotspot_hub_desk_brand_workshop|hotspot_hub_desk_brand_workshop.png|hub_desk_brand_workshop|004-hotspot-hub_desk_brand_workshop.png",
	"hotspot_hub_desk_deck_builder|hotspot_hub_desk_deck_builder.png|hub_desk_deck_builder|005-hotspot-hub_desk_deck_builder.png",
]

const HUB_HOTSPOT_RUNTIME_LINKS := {
	"hub_desk_cluster": "DeskButton",
	"hub_desk_forge_table": "Zone.FORGE",
	"hub_desk_tarot_cards": "Zone.TAROT_DESK",
	"hub_desk_brand_workshop": "Zone.BRAND_WORKSHOP",
	"hub_desk_deck_builder": "Zone.DECK_BUILDER",
}

const P0_PORTRAIT_IDS := [
	"harvey_mors",
	"old_li",
	"drunkard",
	"brendan",
	"reflection",
	"xiao_ran",
]

const P0_EXPRESSION_SLOTS := [
	"default",
	"angry",
	"shocked",
	"mysterious",
]

var _passed := 0
var _failed := 0
var _npc_library = null


func run() -> Dictionary:
	print("\n-- test_brand_npc_assets.gd --")
	test_all_t2_textures_exist_under_client_assets()
	test_t2_assets_registered_in_pixel_asset_manifest()
	test_t2_asset_linked_data_ids_resolve()
	test_no_orphan_brand_portrait_or_hotspot_textures()
	test_brand_and_portrait_naming_mappings_follow_spec()
	test_p0_expression_slots_fallback_to_default_portrait_path()
	return {"passed": _passed, "failed": _failed}


func test_all_t2_textures_exist_under_client_assets() -> void:
	var missing: Array[String] = []
	for spec in _all_specs():
		var path := "%s/%s" % [str(spec.get("texture_dir", "")), str(spec.get("filename", ""))]
		if not ResourceLoader.exists(path):
			missing.append(path)
	assert_eq(_brand_specs().size(), 30, "brand expectation list contains all 30 generated brands")
	assert_eq(_portrait_specs().size(), 20, "portrait expectation list contains all 20 generated default portraits")
	assert_eq(_hotspot_specs().size(), 5, "hotspot expectation list contains the 5 T2 hub desk hotspots")
	assert_true(missing.is_empty(), "all T2 brand/portrait/hotspot textures exist under client assets: %s" % ", ".join(missing))


func test_t2_assets_registered_in_pixel_asset_manifest() -> void:
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
		if str(entry.get("runtime_status", "")) != "integrated":
			invalid.append("%s runtime_status=%s" % [asset_id, str(entry.get("runtime_status", ""))])
		if str(entry.get("path", "")) != expected_path:
			invalid.append("%s path=%s" % [asset_id, str(entry.get("path", ""))])
		if str(entry.get("source", "")) != str(spec.get("source", "")):
			invalid.append("%s source=%s" % [asset_id, str(entry.get("source", ""))])
		if str(entry.get("linked_data_id", "")) != str(spec.get("linked_data_id", "")):
			invalid.append("%s linked_data_id=%s" % [asset_id, str(entry.get("linked_data_id", ""))])
	assert_eq(_category_entries(assets, "brand").size(), 30, "pixel asset manifest has exactly 30 brand entries")
	assert_eq(_category_entries(assets, "portrait").size(), 20, "pixel asset manifest has exactly 20 portrait entries")
	assert_true(_category_entries(assets, "hotspot").size() >= 5, "pixel asset manifest keeps at least the 5 T2 hotspot entries")
	assert_true(missing.is_empty(), "all T2 generated assets are registered in manifest: %s" % ", ".join(missing))
	assert_true(invalid.is_empty(), "all T2 manifest entries use integrated texture schema: %s" % ", ".join(invalid))


func test_t2_asset_linked_data_ids_resolve() -> void:
	var assets := _manifest_assets()
	var missing: Array[String] = []
	for spec in _all_specs():
		var asset_id := str(spec.get("asset_id", ""))
		var entry: Dictionary = assets.get(asset_id, {})
		var category := str(entry.get("category", spec.get("category", "")))
		var linked_data_id := str(entry.get("linked_data_id", spec.get("linked_data_id", "")))
		if not _linked_data_exists(category, linked_data_id):
			missing.append("%s -> %s" % [asset_id, linked_data_id])
	assert_true(missing.is_empty(), "all T2 manifest linked_data_id values resolve through client data or hub runtime links: %s" % ", ".join(missing))


func test_no_orphan_brand_portrait_or_hotspot_textures() -> void:
	var assets := _manifest_assets()
	var orphans: Array[String] = []
	orphans.append_array(_orphan_textures(BRAND_TEXTURE_DIR, _category_entries(assets, "brand"), ""))
	orphans.append_array(_orphan_textures(PORTRAIT_TEXTURE_DIR, _category_entries(assets, "portrait"), ""))
	orphans.append_array(_orphan_textures(HUB_TEXTURE_DIR, _category_entries(assets, "hotspot"), "hotspot_"))
	assert_true(orphans.is_empty(), "no T2 brand/portrait/hotspot PNG exists without a matching manifest entry: %s" % ", ".join(orphans))


func test_brand_and_portrait_naming_mappings_follow_spec() -> void:
	var brand_invalid: Array[String] = []
	for spec in _brand_specs():
		var expected_filename := "%s.png" % str(spec.get("asset_id", ""))
		if str(spec.get("filename", "")) != expected_filename:
			brand_invalid.append("%s -> %s" % [str(spec.get("source_filename", "")), str(spec.get("filename", ""))])
	var portrait_invalid: Array[String] = []
	for spec in _portrait_specs():
		var expected_filename := "%s.png" % str(spec.get("asset_id", ""))
		if str(spec.get("filename", "")) != expected_filename:
			portrait_invalid.append("%s -> %s" % [str(spec.get("source_filename", "")), str(spec.get("filename", ""))])
	assert_true(brand_invalid.is_empty(), "30 brand filenames map to brand_<id>.png: %s" % ", ".join(brand_invalid))
	assert_true(portrait_invalid.is_empty(), "20 portrait filenames map to portrait_<id>.png with default suffix removed: %s" % ", ".join(portrait_invalid))


func test_p0_expression_slots_fallback_to_default_portrait_path() -> void:
	var fallback_map: Dictionary = _manifest_root().get("placeholder_fallbacks", {})
	assert_eq(str(fallback_map.get(P0_EXPRESSION_FALLBACK_PATH_FIELD, "")), P0_EXPRESSION_FALLBACK_PATH, "manifest records P0 expression placeholder fallback path field")
	var resolver_script = load("res://scripts/ui/dialogic_portrait_resolver.gd")
	assert_true(resolver_script != null and resolver_script.can_instantiate(), "Dialogic portrait resolver script exists")
	if resolver_script == null or not resolver_script.can_instantiate():
		return
	var resolver = resolver_script.new()
	var invalid: Array[String] = []
	for npc_id in P0_PORTRAIT_IDS:
		var expected_path := "res://assets/textures/portraits/portrait_%s.png" % npc_id
		for expression in P0_EXPRESSION_SLOTS:
			var request_id := "portrait_%s_%s" % [npc_id, expression]
			var path := str(resolver.call("resolve_path", request_id))
			if path != expected_path:
				invalid.append("%s -> %s" % [request_id, path])
	assert_eq(P0_PORTRAIT_IDS.size() * P0_EXPRESSION_SLOTS.size(), 24, "P0 expression fallback matrix covers 24 slots")
	assert_true(invalid.is_empty(), "all P0 expression slots fall back to default portrait path: %s" % ", ".join(invalid))


func _brand_specs() -> Array:
	return _specs_from_rows(BRAND_ASSET_ROWS, "brand", BRAND_TEXTURE_DIR, "output/imagegen/greycrown_brands_full_30")


func _portrait_specs() -> Array:
	return _specs_from_rows(PORTRAIT_ASSET_ROWS, "portrait", PORTRAIT_TEXTURE_DIR, "output/imagegen/greycrown_portraits_runtime_default")


func _hotspot_specs() -> Array:
	return _specs_from_rows(HOTSPOT_ASSET_ROWS, "hotspot", HUB_TEXTURE_DIR, "output/imagegen/greycrown_hotspots_full/scene_aligned_full")


func _all_specs() -> Array:
	var specs := []
	specs.append_array(_brand_specs())
	specs.append_array(_portrait_specs())
	specs.append_array(_hotspot_specs())
	return specs


func _specs_from_rows(rows: Array, category: String, texture_dir: String, source_dir: String) -> Array:
	var specs: Array = []
	for row in rows:
		var parts := str(row).split("|", false)
		var source_filename := str(parts[3])
		specs.append({
			"asset_id": str(parts[0]),
			"filename": str(parts[1]),
			"linked_data_id": str(parts[2]),
			"source_filename": source_filename,
			"source": "%s/%s" % [source_dir, source_filename],
			"category": category,
			"texture_dir": texture_dir,
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
		if file_name.ends_with(".png") and (filename_prefix == "" or file_name.begins_with(filename_prefix)):
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


func _linked_data_exists(category: String, linked_data_id: String) -> bool:
	match category:
		"brand":
			return not BrandCatalogScript.get_brand_dict(linked_data_id).is_empty()
		"portrait":
			return _portrait_data_exists(linked_data_id)
		"hotspot":
			return _hub_hotspot_link_exists(linked_data_id)
	return false


func _portrait_data_exists(linked_data_id: String) -> bool:
	if _npc_library == null:
		_npc_library = NpcLibraryScript.new()
	if _npc_library.has_definition(linked_data_id):
		return true
	return _enemy_data_exists(linked_data_id)


func _enemy_data_exists(enemy_id: String) -> bool:
	var path := "res://data/combat/enemies/%s.json" % enemy_id
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
