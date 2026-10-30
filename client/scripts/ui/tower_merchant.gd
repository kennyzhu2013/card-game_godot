class_name TowerMerchant
extends Panel

signal merchant_closed

# R16 §5 / R03 §3 塔内商人面板
# 3 槽，当层一次性，不可刷新；价格比黑市低 15%
# 数据 res://data/shops/tower_merchant.json，复用 ShopService 路由

const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")
const ShopInventoryScript = preload("res://scripts/shop/shop_inventory.gd")

const POOL_PATH := "res://data/shops/tower_merchant.json"
const SHOP_ID_PREFIX := "tower_merchant"
const TOWER_PRICE_MULTIPLIER := 0.85

var _game_state = null
var _floor_id: String = ""
var _inventory = null
var _offer_list: ItemList
var _currency_status_label: Label
var _message_label: Label
var _buy_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(game_state, floor_id: String) -> void:
	_game_state = game_state if game_state != null else GameState
	_floor_id = floor_id
	_message_label.text = ""
	_inventory = _ensure_inventory()
	_populate()
	show()


# === 数据加载 ===
static func load_pool(path: String = POOL_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _shop_id() -> String:
	# 每层独立 inventory_id，离开后不刷新（R16 §5：当层一次性）
	return "%s::%s" % [SHOP_ID_PREFIX, _floor_id]


func _ensure_inventory():
	if _game_state == null:
		return null
	var shop_id: String = _shop_id()
	var existing = _game_state.shop_inventories.get(shop_id, null)
	if existing != null:
		return existing
	var pool: Dictionary = load_pool()
	var slots: int = int(pool.get("slot_count", 3))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var inv = ShopInventoryScript.from_pool(shop_id, pool, int(_game_state.day), slots, rng)
	_game_state.shop_inventories[shop_id] = inv
	return inv


# === UI ===
func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.06, 0.96)
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title := Label.new()
	title.text = "快闪商人"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_currency_status_label = Label.new()
	header.add_child(_currency_status_label)

	var hint := Label.new()
	hint.text = "本层一次性，价格比黑市低 15%。离开后不再出现。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	_offer_list = ItemList.new()
	_offer_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_list.item_selected.connect(_on_offer_selected)
	root.add_child(_offer_list)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	_buy_button = Button.new()
	_buy_button.text = "购买"
	_buy_button.disabled = true
	_buy_button.pressed.connect(_on_buy_pressed)
	buttons.add_child(_buy_button)

	var leave := Button.new()
	leave.text = "离开"
	leave.pressed.connect(_on_leave_pressed)
	buttons.add_child(leave)


func _populate() -> void:
	_refresh_currency()
	_offer_list.clear()
	if _inventory == null:
		return
	var multiplier := ShopServiceScript.price_multiplier_for(_game_state, _shop_id(), TOWER_PRICE_MULTIPLIER)
	for offer in _inventory.slots:
		var price: int = offer.priced_amount(multiplier)
		var label: String = "%s | %s %d | x%d" % [str(offer.display_name), _currency_display(offer.price_currency), price, int(offer.stock)]
		var index: int = _offer_list.add_item(label)
		var check: Dictionary = ShopServiceScript.can_buy(offer, _game_state, multiplier)
		_offer_list.set_item_metadata(index, offer)
		if not bool(check.get("ok", false)):
			_offer_list.set_item_disabled(index, true)
			_offer_list.set_item_custom_fg_color(index, Color(0.55, 0.55, 0.58))
			_offer_list.set_item_tooltip(index, _reason_text(str(check.get("reason", ""))))
	_refresh_buy_button()


func _refresh_currency() -> void:
	if _game_state == null:
		_currency_status_label.text = ""
		return
	_currency_status_label.text = "灵石 %d" % int(_game_state.lingstones)


func _on_offer_selected(_index: int) -> void:
	_refresh_buy_button()


func _on_buy_pressed() -> void:
	var selected := _offer_list.get_selected_items()
	if selected.is_empty():
		return
	var offer = _inventory.slots[selected[0]]
	var result: Dictionary = ShopServiceScript.buy(offer, _game_state, ShopServiceScript.price_multiplier_for(_game_state, _shop_id(), TOWER_PRICE_MULTIPLIER), _shop_id())
	if bool(result.get("ok", false)):
		_message_label.text = "成交：%s" % str(offer.display_name)
	else:
		_message_label.text = _reason_text(str(result.get("reason", "")))
	_populate()


func _refresh_buy_button() -> void:
	if _buy_button == null or _offer_list == null:
		return
	var selected := _offer_list.get_selected_items()
	if selected.is_empty():
		_buy_button.disabled = true
		return
	var offer = _inventory.slots[selected[0]]
	var check: Dictionary = ShopServiceScript.can_buy(offer, _game_state, ShopServiceScript.price_multiplier_for(_game_state, _shop_id(), TOWER_PRICE_MULTIPLIER))
	_buy_button.disabled = not bool(check.get("ok", false))


func _on_leave_pressed() -> void:
	hide()
	merchant_closed.emit()


static func _currency_display(currency: String) -> String:
	match currency:
		"lingstones": return "灵石"
		"dao_pages": return "残页"
		_: return currency


func _reason_text(reason: String) -> String:
	match reason:
		"insufficient_currency": return "货币不足"
		"sold_out": return "商品已售罄"
		"missing_card_template": return "卡牌模板缺失"
		"missing_brand": return "烙印数据缺失"
		"locked": return "未开放"
		"sequence_too_low": return "序列不足"
		_: return ""


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_leave_pressed()
		accept_event()
