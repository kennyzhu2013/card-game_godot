extends RefCounted

const BrandWorkshopScript = preload("res://scripts/hub/brand_workshop_panel.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const HubScript = preload("res://scripts/hub/hub.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_brand_workshop.gd --")
	test_mount_requires_sequence_7_unlock()
	test_mount_requires_pathway_affinity()
	test_mount_rejects_duplicate_brand()
	test_mount_rejects_full_slots()
	test_mount_moves_brand_from_inventory_to_card()
	test_unmount_destroys_brand_without_inventory_return()
	test_mvp_30_catalog_category_buckets()
	test_lost_control_overlay_visible_when_state_active()
	test_ai_gm_text_uses_mainline_dialog()
	return {"passed": _passed, "failed": _failed}


func test_mount_requires_sequence_7_unlock() -> void:
	var result: Dictionary = BrandWorkshopScript.can_mount_brand(_card("c", "fool", 7), _brand("damage_plus_low"), _state(8))
	assert_true(not result.get("ok", false), "sequence 8 player cannot mount brands")
	assert_eq(result.get("reason", ""), "sequence_locked", "sequence lock reason")


func test_mount_requires_pathway_affinity() -> void:
	var result: Dictionary = BrandWorkshopScript.can_mount_brand(_card("c", "priestess", 7), _brand("fool_shadow_seal", "fool", 7), _state(7))
	assert_true(not result.get("ok", false), "fool brand cannot mount to priestess card")
	assert_eq(result.get("reason", ""), "pathway_mismatch", "pathway mismatch reason")


func test_mount_rejects_duplicate_brand() -> void:
	var card = _card("c", "fool", 7, 3, ["damage_plus_low"], 4)
	var result: Dictionary = BrandWorkshopScript.can_mount_brand(card, _brand("damage_plus_low"), _state(7))
	assert_true(not result.get("ok", false), "duplicate brand is rejected")
	assert_eq(result.get("reason", ""), "duplicate_brand", "duplicate reason")


func test_mount_rejects_full_slots() -> void:
	var card = _card("c", "fool", 7, 1, ["a", "b"], 2)
	var result: Dictionary = BrandWorkshopScript.can_mount_brand(card, _brand("damage_plus_low"), _state(7))
	assert_true(not result.get("ok", false), "full brand slots reject mount")
	assert_eq(result.get("reason", ""), "slots_full", "full slot reason")


func test_mount_moves_brand_from_inventory_to_card() -> void:
	var gs = _state(7)
	var card = _card("c", "fool", 7)
	var brand = _brand("damage_plus_low")
	gs.brands_inventory.append(brand)
	var result: Dictionary = BrandWorkshopScript.mount_brand(card, brand, gs)
	assert_true(result.get("ok", false), "mount_brand succeeds")
	assert_eq(card.brands, ["damage_plus_low"], "brand id added to card")
	assert_eq(gs.brands_inventory.size(), 0, "mounted brand removed from inventory")
	assert_true("damage_plus_low" in gs.daodian["discovered_brands"], "mounted brand is discovered")


func test_unmount_destroys_brand_without_inventory_return() -> void:
	var gs = _state(7)
	var card = _card("c", "fool", 7, 3, ["damage_plus_low"], 4)
	var result: Dictionary = BrandWorkshopScript.unmount_brand(card, "damage_plus_low", gs)
	assert_true(result.get("ok", false), "unmount_brand succeeds")
	assert_eq(card.brands, [], "brand id removed from card")
	assert_eq(gs.brands_inventory.size(), 0, "unmount destroys instead of returning to inventory")


func test_mvp_30_catalog_category_buckets() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/brands/mvp_30.json"))
	assert_true(parsed is Dictionary, "mvp_30.json parses as Dictionary")
	var brands: Array = []
	if parsed is Dictionary:
		brands = parsed.get("brands", [])
	var buckets := {"fool": 0, "common": 0, "unique": 0, "forge": 0}
	for brand in brands:
		if brand is Dictionary:
			var category := str(brand.get("category", ""))
			if buckets.has(category):
				buckets[category] = int(buckets[category]) + 1
	assert_eq(brands.size(), 30, "mvp_30 brand count = 30")
	assert_eq(int(buckets.get("fool", 0)), 4, "mvp_30 fool bucket = 4")
	assert_eq(int(buckets.get("common", 0)), 18, "mvp_30 common bucket = 18")
	assert_eq(int(buckets.get("unique", 0)), 4, "mvp_30 unique bucket = 4")
	assert_eq(int(buckets.get("forge", 0)), 4, "mvp_30 forge bucket = 4")


func test_lost_control_overlay_visible_when_state_active() -> void:
	var hub = HubScript.new()
	var gs = GameStateScript.new()
	gs._ready()
	gs.is_lost_control = true
	hub.call("_refresh_lost_control_visual", gs)
	var overlay = hub.get_node_or_null("LostControlOverlay")
	assert_true(overlay is ColorRect, "hub creates LostControlOverlay ColorRect")
	assert_true(overlay != null and overlay.visible, "LostControlOverlay is visible while lost control is active")
	gs.is_lost_control = false
	gs.pollution_stage = 0
	gs.pollution = 0
	hub.call("_refresh_lost_control_visual", gs)
	assert_true(overlay != null and not overlay.visible, "LostControlOverlay is hidden when lost control is inactive")
	hub.queue_free()


func test_ai_gm_text_uses_mainline_dialog() -> void:
	var hub = HubScript.new()
	hub.call("_setup_mainline_dialog")
	hub.call("_show_ai_gm_text", "AI GM", "测试 AI GM 文本")
	var dialog = hub.get_node_or_null("MainlineDialog")
	assert_true(dialog is AcceptDialog, "hub AI GM text uses MainlineDialog")
	assert_true(dialog != null and dialog.visible, "hub AI GM dialog becomes visible")
	assert_true(dialog != null and str(dialog.dialog_text).contains("测试 AI GM 文本"), "hub AI GM dialog shows returned text")
	hub.queue_free()


func _card(id: String, pathway: String, sequence: int, quality: int = 3, brands: Array[String] = [], slots: int = -1):
	var data := {
		"id": id,
		"template_id": id,
		"pathway": pathway,
		"sequence": sequence,
		"quality": quality,
		"brands": brands,
	}
	if slots >= 0:
		data["brand_slots"] = slots
	return CardScript.from_json(data)


func _brand(id: String, pathway: String = "any", sequence_min: int = 9):
	return BrandScript.from_dict({
		"id": id,
		"display_name": id,
		"pathway_affinity": pathway,
		"sequence_min": sequence_min,
		"effect_type": "stat",
		"effect_payload": {"stat_target": "damage", "operation": "add", "value": 1},
	})


func _state(sequence: int):
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = sequence
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
