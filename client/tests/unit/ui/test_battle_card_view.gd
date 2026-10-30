extends RefCounted

const BattleCardViewScript = preload("res://scripts/ui/battle/battle_card_view.gd")
const CardScript = preload("res://scripts/combat/card.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_battle_card_view.gd --")
	await test_battle_card_view_renders_core_card_fields()
	await test_battle_card_view_body_text_is_clean_summary_not_raw_tokens()
	await test_battle_card_view_uses_full_card_art_background_with_text_overlay()
	await test_battle_card_view_prefers_portrait_card_size_from_art_texture()
	await test_battle_card_view_drag_preview_is_attached_and_compact_without_gui_drag_latch()
	await test_battle_card_view_hides_source_card_while_dragging_and_restores_on_cancel()
	return {"passed": _passed, "failed": _failed}


func test_battle_card_view_renders_core_card_fields() -> void:
	var view = BattleCardViewScript.new()
	Engine.get_main_loop().root.add_child(view)
	var card = _card()
	var summary := card.effect_summary_text()
	view.bind_card(card, 2, summary, "needs more energy", "", false, null)
	await Engine.get_main_loop().process_frame
	for node_name in ["CostBadge", "NameLabel", "TypeLabel", "EffectLabel", "DisabledReasonLabel"]:
		var node = view.find_child(node_name, true, false)
		assert_true(node is Control, "%s exists on BattleCardView" % node_name)
		if node is Control:
			assert_true((node as Control).visible, "%s is visible on BattleCardView" % node_name)
	var cost_label = view.find_child("CostBadge", true, false)
	var name_label = view.find_child("NameLabel", true, false)
	var effect_label = view.find_child("EffectLabel", true, false)
	var disabled_label = view.find_child("DisabledReasonLabel", true, false)
	assert_true(cost_label is Label and (cost_label as Label).text.contains("2"), "BattleCardView renders effective cost")
	assert_true(name_label is Label and (name_label as Label).text.contains(card.get_display_name()), "BattleCardView renders display name")
	var effect_text := (effect_label as Label).text if effect_label is Label else ""
	assert_true(effect_text.contains("Readable hand card probe") or view.tooltip_text.contains("Readable hand card probe"), "BattleCardView renders readable effect summary")
	var brand_text := card.brand_effects_text()
	assert_true(brand_text != "" and view.tooltip_text.contains(brand_text), "BattleCardView tooltip includes mounted-brand text")
	assert_true(disabled_label is Label and (disabled_label as Label).text.contains("needs more energy"), "BattleCardView renders disabled reason text")
	assert_true(view.custom_minimum_size.x >= 48 and view.custom_minimum_size.y >= 48, "BattleCardView keeps a 48px+ interactive target")
	view.queue_free()


func test_battle_card_view_body_text_is_clean_summary_not_raw_tokens() -> void:
	var view = BattleCardViewScript.new()
	Engine.get_main_loop().root.add_child(view)
	var card = CardScript.from_json({
		"id": "battle_card_view_raw_token_probe",
		"template_id": "battle_card_view_raw_token_probe",
		"display_name": "Battle Card Body Clean Probe",
		"description": "Clean card body summary.",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 1,
		"combat_effect": {
			"damage": 9,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 2}],
		},
		"social_effect": {"type": "identity_mask", "suspicion_delta": -2},
		"tags": ["attack"],
	})
	view.bind_card(card, 1, "[effect: raw_token payload: {id: paper_doll_marker}]", "", "", false, null)
	await Engine.get_main_loop().process_frame
	var effect_label = view.find_child("EffectLabel", true, false)
	var body_text := ""
	if effect_label is Label:
		body_text = (effect_label as Label).text + "\n" + (effect_label as Label).tooltip_text
	assert_true(body_text.contains("Clean card body summary"), "BattleCardView body uses the card clean summary")
	for raw in ["[", "]", "effect:", "payload:", "raw_token"]:
		assert_true(not body_text.contains(raw), "BattleCardView body hides raw token %s" % raw)
	view.queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_card_view_uses_full_card_art_background_with_text_overlay() -> void:
	var view = BattleCardViewScript.new()
	view.custom_minimum_size = Vector2(198, 132)
	view.size = Vector2(198, 132)
	Engine.get_main_loop().root.add_child(view)
	var card = _card()
	view.bind_card(card, 2, card.effect_summary_text(), "", "", false, _dummy_texture())
	await Engine.get_main_loop().process_frame
	var art = view.find_child("CardArt", true, false)
	var overlay = view.find_child("CardTextOverlay", true, false)
	var body = view.find_child("CardBody", true, false)
	var name_label = view.find_child("NameLabel", true, false)
	var effect_label = view.find_child("EffectLabel", true, false)
	assert_true(art is TextureRect and (art as TextureRect).texture != null and (art as TextureRect).visible, "BattleCardView renders the bound card texture")
	if art is TextureRect:
		assert_true((art as TextureRect).get_parent() == view, "CardArt is mounted as the full-card background instead of inside the text body flow")
		assert_true((art as TextureRect).custom_minimum_size.y >= view.custom_minimum_size.y * 0.70 or (art as TextureRect).size.y >= view.custom_minimum_size.y * 0.70, "CardArt covers most of the card height instead of a small inline strip")
		assert_eq((art as TextureRect).expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "CardArt ignores child-flow size and fills its rect")
		assert_eq((art as TextureRect).stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "CardArt crops proportionally to cover the full card")
	assert_true(overlay is Control, "BattleCardView exposes CardTextOverlay above the art")
	if overlay is Control:
		assert_true(body is Control and (body as Control).get_parent() == overlay, "CardBody lives inside the text overlay layer")
		assert_true(name_label is Control and _is_descendant_of(name_label, overlay), "NameLabel is drawn in the overlay layer")
		assert_true(effect_label is Control and _is_descendant_of(effect_label, overlay), "EffectLabel is drawn in the overlay layer")
		if effect_label is Control:
			assert_true((effect_label as Control).get_global_rect().size.y >= 24.0, "EffectLabel keeps visible height inside the bottom text ribbon")
		if art is Control:
			assert_true((overlay as Control).z_index > (art as Control).z_index, "CardTextOverlay draws above CardArt")
	view.queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_card_view_prefers_portrait_card_size_from_art_texture() -> void:
	var view = BattleCardViewScript.new()
	assert_true(view.has_method("preferred_card_size_for_art"), "BattleCardView exposes an art-driven preferred size helper")
	if view.has_method("preferred_card_size_for_art"):
		var preferred = view.call("preferred_card_size_for_art", _dummy_texture(1024, 1536), 140.0)
		assert_true(typeof(preferred) == TYPE_VECTOR2, "BattleCardView preferred size helper returns a Vector2")
		if typeof(preferred) == TYPE_VECTOR2:
			var size: Vector2 = preferred
			assert_true(size.x >= 139.0 and size.x <= 141.0, "BattleCardView preserves the requested card width")
			assert_true(size.y >= 209.0 and size.y <= 211.0, "BattleCardView derives height from the 1024x1536 card art ratio")
			assert_true(size.y > size.x * 1.45, "BattleCardView preferred size is portrait, not a short landscape button")
	view.free()


func test_battle_card_view_drag_preview_is_attached_and_compact_without_gui_drag_latch() -> void:
	var view = BattleCardViewScript.new()
	view.custom_minimum_size = Vector2(340, 240)
	view.size = Vector2(340, 240)
	Engine.get_main_loop().root.add_child(view)
	var card = CardScript.from_json({
		"id": "battle_card_view_drag_preview_probe",
		"template_id": "battle_card_view_drag_preview_probe",
		"display_name": "Battle Card Drag Preview Probe",
		"description": "A deliberately long clean summary that must stay inside a compact drag preview instead of expanding into one oversized row.",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 1,
		"combat_effect": {
			"damage": 8,
			"heal": 0,
			"target": "single",
			"range": 3,
			"status_effects": [{"id": "flame_wound", "duration": 2, "magnitude": 4}],
		},
		"tags": ["attack"],
	})
	view.bind_card(card)
	await Engine.get_main_loop().process_frame
	var payload = view.call("_get_drag_data", Vector2(8, 8))
	assert_true(payload is Dictionary, "BattleCardView drag preview payload is inspectable")
	if payload is Dictionary:
		assert_true(bool(payload.get("preview_attached", false)), "BattleCardView attaches a drag preview immediately when drag data is requested")
		assert_true(payload.get("preview_control", null) is Control, "BattleCardView exposes the compact preview control for verification")
		assert_true(bool(payload.get("drag_lift_animation", false)), "BattleCardView drag payload declares a lift animation for the dragged card")
		assert_true(bool(payload.get("drag_travel_animation", false)), "BattleCardView drag payload declares a travel animation for card play resolution")
		var preview_rect: Rect2 = payload.get("preview_rect", Rect2())
		assert_true(preview_rect.size.y > preview_rect.size.x * 1.35, "BattleCardView drag preview keeps the card-art portrait aspect")
		assert_true(preview_rect.size.x <= 180.0 and preview_rect.size.y <= 260.0, "BattleCardView drag preview stays hand-sized instead of inheriting an oversized card rect")
		var preview = payload.get("preview_control", null)
		if preview is Control:
			assert_eq((preview as Control).position, -preview_rect.size * 0.5, "BattleCardView drag preview is centered on the cursor so the card lifts with the drag")
			assert_true(bool((preview as Control).get_meta("drag_lift_animation", false)), "BattleCardView drag preview marks the lifted visual state")
			assert_true((preview as Control).scale.x > 1.0 and (preview as Control).scale.y > 1.0, "BattleCardView drag preview visibly pops above the hand while dragging")
			assert_true((preview as Control).z_index >= 200, "BattleCardView drag preview is z-raised above the battle UI")
			var effect_label = (preview as Control).find_child("EffectLabel", true, false)
			assert_true(effect_label is Label and (effect_label as Label).autowrap_mode != TextServer.AUTOWRAP_OFF, "BattleCardView drag preview keeps wrapped effect text")
			var effect_text := (effect_label as Label).text if effect_label is Label else ""
			assert_true(effect_text.contains("\n") and not effect_text.contains(" / "), "BattleCardView drag preview keeps compact multi-line text instead of one oversized row")
	view.queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_card_view_hides_source_card_while_dragging_and_restores_on_cancel() -> void:
	var view = BattleCardViewScript.new()
	view.custom_minimum_size = Vector2(140, 210)
	view.size = Vector2(140, 210)
	Engine.get_main_loop().root.add_child(view)
	var card = _card()
	view.bind_card(card, 1, card.effect_summary_text(), "", "", false, _dummy_texture(1024, 1536))
	await Engine.get_main_loop().process_frame
	var original_size: Vector2 = view.size
	var payload = view.call("_get_drag_data", Vector2(8, 8))
	assert_true(payload is Dictionary, "BattleCardView drag data exists for source-hide behavior")
	assert_true(bool(view.get_meta("drag_source_placeholder", false)), "BattleCardView marks the source card as a drag placeholder")
	assert_true(view.visible, "BattleCardView keeps the source slot in layout while dragging")
	assert_true(view.modulate.a <= 0.05, "BattleCardView source card disappears while the lifted preview is being dragged")
	assert_eq(view.size, original_size, "BattleCardView source placeholder keeps the original card footprint")
	if payload is Dictionary:
		assert_true(bool((payload as Dictionary).get("source_hidden_during_drag", false)), "BattleCardView drag payload records that the source is hidden during drag")
	view.notification(Control.NOTIFICATION_DRAG_END)
	await Engine.get_main_loop().process_frame
	assert_true(not bool(view.get_meta("drag_source_placeholder", false)), "BattleCardView clears the drag placeholder marker after drag end")
	assert_true(view.modulate.a >= 0.99, "BattleCardView restores the source card when the drag is cancelled")
	view.queue_free()
	await Engine.get_main_loop().process_frame


func _card() -> Card:
	return CardScript.from_json({
		"id": "battle_card_view_probe",
		"template_id": "battle_card_view_probe",
		"display_name": "Battle Card View Probe",
		"description": "Readable hand card probe effect summary.",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 2,
		"brand_slots": 2,
		"brands": ["damage_plus_low"],
		"combat_effect": {
			"damage": 7,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 2}],
		},
		"tags": ["attack"],
	})


func _dummy_texture(width: int = 96, height: int = 144) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.30, 0.22, 0.16, 1.0))
	return ImageTexture.create_from_image(image)


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
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
