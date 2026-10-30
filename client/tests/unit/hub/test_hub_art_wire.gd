extends RefCounted

const HUB_SCENE_PATH := "res://scenes/hub/hub.tscn"
const HUB_BACKGROUND_PATH := "res://assets/textures/hub/hub_anchor.png"
const HOTSPOT_ALPHA := 0.42
const ANCHOR_TOLERANCE := 0.005
const EXPECTED_HOTSPOTS := {
	"DeskButton": {
		"zone_id": "desk",
		"rect": Rect2(0.04, 0.50, 0.30, 0.45),
		"tooltip": "书桌 · 塔罗牌堆 · 抽签 / 整理牌组",
	},
	"BookshelfButton": {
		"zone_id": "bookshelf",
		"rect": Rect2(0.00, 0.05, 0.20, 0.45),
		"tooltip": "书架 · 守则 / 道典查询",
	},
	"FrontDoorButton": {
		"zone_id": "front_door",
		"rect": Rect2(0.32, 0.10, 0.18, 0.65),
		"tooltip": "出门 · 进入城区漫游",
	},
	"NoticeBoardButton": {
		"zone_id": "notice_board",
		"rect": Rect2(0.50, 0.05, 0.20, 0.55),
		"tooltip": "告示板 · 委托 / 灰冠日报",
	},
	"BedButton": {
		"zone_id": "bed",
		"rect": Rect2(0.66, 0.40, 0.30, 0.45),
		"tooltip": "床铺 · 睡觉推进时段",
	},
	"CushionButton": {
		"zone_id": "cushion",
		"rect": Rect2(0.58, 0.55, 0.16, 0.20),
		"tooltip": "蒲团 · 修炼 / 入梦",
	},
	"ClockButton": {
		"zone_id": "clock",
		"rect": Rect2(0.71, 0.04, 0.10, 0.18),
		"tooltip_prefix": "时钟 · 当前 day",
	},
}

const HUB_HOTSPOT_TEXTURES := {
	"DeskButton": "res://assets/textures/hub/hotspot_hub_desk_cluster.png",
	"BookshelfButton": "res://assets/textures/hotspots/hotspot_hub_bookshelf.png",
	"FrontDoorButton": "res://assets/textures/hotspots/hotspot_hub_front_door.png",
	"NoticeBoardButton": "res://assets/textures/hotspots/hotspot_hub_notice_board.png",
	"BedButton": "res://assets/textures/hotspots/hotspot_hub_bed.png",
	"CushionButton": "res://assets/textures/hotspots/hotspot_hub_cushion.png",
	"ClockButton": "res://assets/textures/hotspots/hotspot_hub_clock.png",
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_hub_art_wire.gd --")
	await test_hub_anchor_background_is_mounted()
	await test_hub_hotspot_layer_contains_7_transparent_texture_buttons()
	await test_hub_hotspot_signals_and_tooltips_are_wired()
	await test_legacy_zone_grid_is_hidden_and_has_no_icons()
	await test_hotspot_highlights_start_transparent_with_expected_alpha()
	await test_hub_overlays_stay_above_anchor_background()
	await test_npc_portrait_dialog_coexists_with_anchor_background()
	return {"passed": _passed, "failed": _failed}


func test_hub_anchor_background_is_mounted() -> void:
	var hub := await _instantiate_hub()
	if hub == null:
		return
	var background := hub.get_node_or_null("HubBackground")
	assert_true(background is TextureRect, "HubBackground is a TextureRect")
	if background is TextureRect:
		assert_true((background as TextureRect).texture != null, "HubBackground has a texture")
		assert_true(str((background as TextureRect).texture.resource_path).find("hub_anchor.png") >= 0, "HubBackground uses hub_anchor.png")
		assert_true((background as TextureRect).modulate.a >= 0.95, "HubBackground stays near-opaque so the room art is not fogged")
		assert_eq(int((background as TextureRect).mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "HubBackground ignores mouse input")
	hub.queue_free()
	await Engine.get_main_loop().process_frame


func test_hub_hotspot_layer_contains_7_transparent_texture_buttons() -> void:
	var hub := await _instantiate_hub()
	if hub == null:
		return
	var layer := hub.get_node_or_null("HubHotspotLayer")
	assert_true(layer is Control, "HubHotspotLayer exists")
	if layer is Control:
		assert_eq((layer as Control).anchor_left, 0.0, "HubHotspotLayer anchor_left")
		assert_eq((layer as Control).anchor_top, 0.0, "HubHotspotLayer anchor_top")
		assert_eq((layer as Control).anchor_right, 1.0, "HubHotspotLayer anchor_right")
		assert_eq((layer as Control).anchor_bottom, 1.0, "HubHotspotLayer anchor_bottom")
		for button_name in EXPECTED_HOTSPOTS.keys():
			var button := layer.get_node_or_null(str(button_name))
			assert_true(button is TextureButton, "%s hotspot is TextureButton" % str(button_name))
			if button is TextureButton:
				var tex_button := button as TextureButton
				assert_true(tex_button.texture_normal == null, "%s texture_normal is transparent" % str(button_name))
				assert_true(tex_button.texture_hover == null, "%s texture_hover is transparent" % str(button_name))
				assert_true(tex_button.texture_pressed == null, "%s texture_pressed is transparent" % str(button_name))
				_assert_hotspot_anchors(tex_button, EXPECTED_HOTSPOTS[button_name]["rect"], str(button_name))
	hub.queue_free()
	await Engine.get_main_loop().process_frame


func test_hub_hotspot_signals_and_tooltips_are_wired() -> void:
	var hub := await _instantiate_hub()
	if hub == null:
		return
	var layer := hub.get_node_or_null("HubHotspotLayer")
	assert_true(layer is Control, "HubHotspotLayer exists for signal checks")
	if layer is Control:
		for button_name in EXPECTED_HOTSPOTS.keys():
			var button := layer.get_node_or_null(str(button_name))
			assert_true(button is TextureButton, "%s exists for signal checks" % str(button_name))
			if button is TextureButton:
				var tex_button := button as TextureButton
				assert_true(_has_signal_method(tex_button.mouse_entered, "_on_hotspot_mouse_entered"), "%s mouse_entered connects to hub hover handler" % str(button_name))
				assert_true(_has_signal_method(tex_button.mouse_exited, "_on_hotspot_mouse_exited"), "%s mouse_exited connects to hub hover handler" % str(button_name))
				assert_true(_has_signal_method(tex_button.pressed, "_on_hotspot_pressed_by_zone"), "%s pressed connects to zone router" % str(button_name))
				var expected: Dictionary = EXPECTED_HOTSPOTS[button_name]
				if expected.has("tooltip"):
					assert_eq(tex_button.tooltip_text, str(expected["tooltip"]), "%s tooltip text" % str(button_name))
				else:
					assert_true(tex_button.tooltip_text.begins_with(str(expected["tooltip_prefix"])), "%s dynamic clock tooltip" % str(button_name))
	hub.queue_free()
	await Engine.get_main_loop().process_frame


func test_legacy_zone_grid_is_hidden_and_has_no_icons() -> void:
	var hub := await _instantiate_hub()
	if hub == null:
		return
	var grid := hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid")
	assert_true(grid is GridContainer, "legacy ZoneGrid still exists as fallback")
	if grid is GridContainer:
		assert_true(not (grid as GridContainer).visible, "legacy ZoneGrid is hidden behind image-hotspot scene")
		for button_name in EXPECTED_HOTSPOTS.keys():
			var child := grid.get_node_or_null(str(button_name))
			assert_true(child is Button, "%s legacy fallback button still exists" % str(button_name))
			if child is Button:
				assert_true((child as Button).icon == null, "%s legacy button has no icon" % str(button_name))
	hub.queue_free()
	await Engine.get_main_loop().process_frame


func test_hotspot_highlights_start_transparent_with_expected_alpha() -> void:
	var hub := await _instantiate_hub()
	if hub == null:
		return
	var layer := hub.get_node_or_null("HubHotspotLayer")
	assert_true(layer is Control, "HubHotspotLayer exists for highlight checks")
	if layer is Control:
		for button_name in EXPECTED_HOTSPOTS.keys():
			var highlight_name := "%sHighlight" % str(button_name)
			var highlight := layer.get_node_or_null(highlight_name)
			assert_true(highlight is TextureRect, "%s is TextureRect scene-aligned art highlight" % highlight_name)
			if highlight is TextureRect:
				var rect := highlight as TextureRect
				var expected_path := str(HUB_HOTSPOT_TEXTURES.get(str(button_name), ""))
				assert_true(rect.texture is Texture2D, "%s loads hotspot texture" % highlight_name)
				assert_eq(str(rect.texture.resource_path) if rect.texture != null else "", expected_path, "%s texture path" % highlight_name)
				assert_eq(rect.modulate.a, 0.0, "%s starts transparent" % highlight_name)
				assert_true(absf(float(rect.get_meta("hover_alpha", -1.0)) - HOTSPOT_ALPHA) <= 0.001, "%s hover alpha metadata is 0.42" % highlight_name)
				assert_eq(int(rect.mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "%s ignores mouse input" % highlight_name)
	hub.queue_free()
	await Engine.get_main_loop().process_frame


func test_hub_overlays_stay_above_anchor_background() -> void:
	var hub := await _instantiate_hub()
	if hub == null:
		return
	var background := hub.get_node_or_null("HubBackground")
	hub.call("_setup_lost_control_visual")
	var overlay := hub.get_node_or_null("LostControlOverlay")
	assert_true(background is TextureRect, "HubBackground exists for lost-control layering")
	assert_true(overlay is ColorRect, "LostControlOverlay exists with hub anchor mounted")
	if background != null and overlay != null:
		assert_true(overlay.get_index() > background.get_index(), "LostControlOverlay remains above HubBackground")
	hub.queue_free()
	await Engine.get_main_loop().process_frame


func test_npc_portrait_dialog_coexists_with_anchor_background() -> void:
	var hub := await _instantiate_hub()
	if hub == null:
		return
	hub.call("_setup_npc_dialog")
	hub.call("_set_npc_portrait", "old_li", {"portrait_path": "res://assets/textures/portraits/portrait_old_li.png"})
	var background := hub.get_node_or_null("HubBackground")
	var dialog := hub.get_node_or_null("NpcDialogueDialog")
	var portrait = dialog.get_node_or_null("NpcPortraitTexture") if dialog != null else null
	assert_true(background is TextureRect, "HubBackground exists for NPC portrait overlap check")
	assert_true(dialog is AcceptDialog, "Hub NPC dialog exists above hub anchor background")
	assert_true(portrait is TextureRect, "Hub NPC dialog has portrait TextureRect")
	if portrait is TextureRect:
		assert_true((portrait as TextureRect).visible, "Hub NPC portrait remains visible with hub anchor background")
		assert_true((portrait as TextureRect).texture != null, "Hub NPC portrait resolves texture with hub anchor background")
	hub.queue_free()
	await Engine.get_main_loop().process_frame


func _assert_hotspot_anchors(button: TextureButton, expected_rect: Rect2, button_name: String) -> void:
	assert_true(absf(button.anchor_left - expected_rect.position.x) <= ANCHOR_TOLERANCE, "%s anchor_left ratio" % button_name)
	assert_true(absf(button.anchor_top - expected_rect.position.y) <= ANCHOR_TOLERANCE, "%s anchor_top ratio" % button_name)
	assert_true(absf(button.anchor_right - (expected_rect.position.x + expected_rect.size.x)) <= ANCHOR_TOLERANCE, "%s anchor_right ratio" % button_name)
	assert_true(absf(button.anchor_bottom - (expected_rect.position.y + expected_rect.size.y)) <= ANCHOR_TOLERANCE, "%s anchor_bottom ratio" % button_name)


func _has_signal_method(signal_value: Signal, method_name: String) -> bool:
	for connection in signal_value.get_connections():
		if not connection is Dictionary or not connection.has("callable"):
			continue
		var callable: Callable = connection["callable"]
		if str(callable.get_method()) == method_name:
			return true
	return false


func _instantiate_hub() -> Control:
	var scene = load(HUB_SCENE_PATH)
	assert_true(scene != null and scene.can_instantiate(), "hub scene loads for art wire test")
	if scene == null or not scene.can_instantiate():
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub as Control


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
