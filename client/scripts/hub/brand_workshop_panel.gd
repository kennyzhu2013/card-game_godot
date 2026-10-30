class_name BrandWorkshopPanel
extends Control

const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")
const ArtManifestScript = preload("res://scripts/art_manifest.gd")

var _game_state = null
var _ai_gm_service = null
var _card_select: OptionButton
var _brand_select: OptionButton
var _brand_texture_rect: TextureRect
var _detail_label: Label
var _mount_button: Button
var _unmount_button: Button


func _ready() -> void:
	if _card_select == null:
		_build_ui()
	hide()


func open(game_state = null) -> void:
	_game_state = game_state if game_state != null else GameState
	_refresh_options()
	show()


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func request_brand_naming_ai_gm(card, brand_a, brand_b = null, options: Dictionary = {}) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "brand_naming"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"brand_id_a": _brand_id(brand_a),
		"brand_id_b": _brand_id(brand_b),
		"card_template_id": _card_template_id(card),
		"fusion_outcome": str(options.get("fusion_outcome", "")),
	}
	ctx.fallback_template_pool = "BRAND_NAMING_TEMPLATES"
	return _call_ai_gm(ctx)


static func can_mount_brand(card, brand, game_state = null) -> Dictionary:
	if card == null:
		return {"ok": false, "reason": "missing_card"}
	if brand == null:
		return {"ok": false, "reason": "missing_brand"}
	if game_state != null and int(game_state.sequence) > 7:
		return {"ok": false, "reason": "sequence_locked"}
	if int(card.sequence) > int(brand.sequence_min):
		return {"ok": false, "reason": "card_sequence_too_low"}
	if str(brand.pathway_affinity) != "any" and str(card.pathway) != str(brand.pathway_affinity):
		return {"ok": false, "reason": "pathway_mismatch"}
	if str(brand.id) in card.brands:
		return {"ok": false, "reason": "duplicate_brand"}
	if card.brands.size() >= int(card.brand_slots):
		return {"ok": false, "reason": "slots_full"}
	return {"ok": true, "reason": "ok"}


static func mount_brand(card, brand, game_state = null) -> Dictionary:
	var check: Dictionary = can_mount_brand(card, brand, game_state)
	if not bool(check.get("ok", false)):
		return check
	if game_state != null:
		var inventory_index: int = _find_inventory_brand_index(game_state, str(brand.id))
		if inventory_index < 0:
			return {"ok": false, "reason": "brand_not_owned"}
		game_state.brands_inventory.remove_at(inventory_index)
	card.brands.append(str(brand.id))
	if game_state != null:
		_discover_brand(game_state, str(brand.id))
	return {"ok": true, "reason": "ok", "brand_id": str(brand.id)}


static func unmount_brand(card, brand_id: String, game_state = null) -> Dictionary:
	if card == null:
		return {"ok": false, "reason": "missing_card"}
	if not brand_id in card.brands:
		return {"ok": false, "reason": "brand_not_mounted"}
	card.brands.erase(brand_id)
	return {"ok": true, "reason": "ok", "brand_id": brand_id, "destroyed": true}


static func mountable_brands_for_card(card, brands: Array, game_state = null) -> Array:
	var result: Array = []
	for brand in brands:
		var check: Dictionary = can_mount_brand(card, brand, game_state)
		if bool(check.get("ok", false)):
			result.append(brand)
	return result


static func _find_inventory_brand_index(game_state, brand_id: String) -> int:
	for i in range(game_state.brands_inventory.size()):
		var brand = game_state.brands_inventory[i]
		if brand != null and str(brand.id) == brand_id:
			return i
	return -1


static func _discover_brand(game_state, brand_id: String) -> void:
	var discovered: Array = game_state.daodian.get("discovered_brands", [])
	if not brand_id in discovered:
		discovered.append(brand_id)
	game_state.daodian["discovered_brands"] = discovered


func _build_ui() -> void:
	name = "BrandWorkshopPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 360)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "烙印工坊"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_card_select = OptionButton.new()
	_card_select.name = "CardSelect"
	_card_select.item_selected.connect(_on_selection_changed)
	root.add_child(_card_select)

	_brand_select = OptionButton.new()
	_brand_select.name = "BrandSelect"
	_brand_select.item_selected.connect(_on_selection_changed)
	root.add_child(_brand_select)

	_brand_texture_rect = TextureRect.new()
	_brand_texture_rect.name = "BrandTexture"
	_brand_texture_rect.custom_minimum_size = Vector2(72, 72)
	_brand_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brand_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(_brand_texture_rect)

	_detail_label = Label.new()
	_detail_label.name = "DetailLabel"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(0, 120)
	root.add_child(_detail_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	_mount_button = Button.new()
	_mount_button.text = "挂载"
	_mount_button.pressed.connect(_on_mount_pressed)
	buttons.add_child(_mount_button)

	_unmount_button = Button.new()
	_unmount_button.text = "卸下(销毁)"
	_unmount_button.pressed.connect(_on_unmount_pressed)
	buttons.add_child(_unmount_button)

	var close_button := Button.new()
	close_button.text = "取消"
	close_button.pressed.connect(hide)
	buttons.add_child(close_button)


func _refresh_options() -> void:
	if _game_state == null or _card_select == null:
		return
	_card_select.clear()
	for card in _game_state.cards_inventory:
		_card_select.add_item(_card_label(card))
	_brand_select.clear()
	for brand in _game_state.brands_inventory:
		_brand_select.add_item(_brand_label(brand))
	_refresh_detail()


func _refresh_detail() -> void:
	if _detail_label == null:
		return
	var card = _selected_card()
	var brand = _selected_brand()
	_refresh_brand_texture(brand)
	if card == null:
		_detail_label.text = "请选择卡牌"
		return
	if brand == null:
		_detail_label.text = "%s 烙印槽 %d/%d" % [_card_display(card), card.brands.size(), card.brand_slots]
		return
	var check: Dictionary = can_mount_brand(card, brand, _game_state)
	_detail_label.text = "%s 烙印槽 %d/%d\n%s\n%s" % [
		_card_display(card),
		card.brands.size(),
		card.brand_slots,
		str(brand.display_name),
		_reason_text(str(check.get("reason", "ok"))),
	]


func _refresh_brand_texture(brand) -> void:
	if _brand_texture_rect == null:
		return
	var brand_id := _brand_id(brand)
	var texture := ArtManifestScript.texture_for("brand", brand_id)
	_brand_texture_rect.texture = texture
	_brand_texture_rect.visible = texture != null


func _reason_text(reason: String) -> String:
	match reason:
		"ok": return "可以挂载"
		"sequence_locked": return "序列 7 才解锁烙印挂载（当前序列 > 7）"
		"card_sequence_too_low": return "此烙印需要更高序列卡牌"
		"pathway_mismatch": return "途径不符（需要 %s 途径卡）" % "对应"
		"duplicate_brand": return "该卡已挂载这枚烙印"
		"slots_full": return "卡牌烙印槽已满"
		"brand_not_owned": return "库存中没有这枚烙印"
		"missing_card": return "卡牌不存在"
		"missing_brand": return "烙印不存在"
		_: return reason


func _card_display(card) -> String:
	if card == null:
		return ""
	if card.has_method("get_display_name"):
		return str(card.get_display_name())
	return str(card.template_id) if str(card.template_id) != "" else str(card.id)


func _selected_card():
	if _game_state == null:
		return null
	var index: int = _card_select.selected
	if index < 0 or index >= _game_state.cards_inventory.size():
		return null
	return _game_state.cards_inventory[index]


func _selected_brand():
	if _game_state == null:
		return null
	var index: int = _brand_select.selected
	if index < 0 or index >= _game_state.brands_inventory.size():
		return null
	return _game_state.brands_inventory[index]


func _on_selection_changed(_idx: int) -> void:
	_refresh_detail()


func _on_mount_pressed() -> void:
	var selected_card = _selected_card()
	var selected_brand = _selected_brand()
	var previous_brands: Array = selected_card.brands.duplicate() if selected_card != null else []
	var result: Dictionary = mount_brand(_selected_card(), _selected_brand(), _game_state)
	if bool(result.get("ok", false)):
		if selected_card != null and previous_brands.size() > 0:
			request_brand_naming_ai_gm(selected_card, _brand_ref(previous_brands[previous_brands.size() - 1]), selected_brand, {
				"fusion_outcome": str(result.get("brand_id", "")),
			})
		_refresh_options()
	else:
		_refresh_detail()


func _on_unmount_pressed() -> void:
	var card = _selected_card()
	if card == null or card.brands.is_empty():
		return
	var result: Dictionary = unmount_brand(card, str(card.brands[card.brands.size() - 1]), _game_state)
	if bool(result.get("ok", false)):
		_refresh_options()


func _card_label(card) -> String:
	if card == null:
		return ""
	var name_text: String = str(card.get_display_name()) if card.has_method("get_display_name") else str(card.template_id)
	if name_text == "":
		name_text = str(card.id)
	return "[%s] %s ★%d %d/%d" % [str(card.pathway), name_text, int(card.quality), card.brands.size(), card.brand_slots]


func _brand_label(brand) -> String:
	if brand == null:
		return ""
	var name_text: String = str(brand.display_name)
	return name_text if name_text != "" else str(brand.id)


func _call_ai_gm(ctx) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var service = _resolve_ai_gm_service()
	if service == null or not service.has_method("call_ai_gm"):
		return ""
	return str(service.call_ai_gm(ctx))


func _resolve_ai_gm_service():
	if _ai_gm_service != null:
		return _ai_gm_service
	_ai_gm_service = AIGMServiceScript.new()
	return _ai_gm_service


func _ai_gm_player_state() -> Dictionary:
	if _game_state == null:
		return {}
	return {
		"sequence": int(_game_state.sequence),
		"pollution": int(_game_state.pollution),
		"pollution_stage": int(_game_state.pollution_stage),
		"cycle": int(_game_state.cycle),
		"day": int(_game_state.day),
		"time_of_day": str(_game_state.time_of_day),
	}


func _brand_ref(brand_id: String) -> Dictionary:
	return {"id": brand_id}


func _brand_id(brand) -> String:
	if brand == null:
		return ""
	if brand is Dictionary:
		return str((brand as Dictionary).get("id", ""))
	if brand.has_method("get"):
		var value = brand.get("id")
		if value != null:
			return str(value)
	return ""


func _card_template_id(card) -> String:
	if card == null:
		return ""
	if card.has_method("get"):
		var template = card.get("template_id")
		if template != null and str(template) != "":
			return str(template)
		var id = card.get("id")
		return str(id) if id != null else ""
	return ""
