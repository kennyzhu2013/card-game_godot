class_name BlackMarket
extends Panel

# R16 §4 唐恩黑市 UI
# 6 槽，仅夜晚开张，Day 3 起开放，每日自动刷新 + 手动刷新 50 灵石/日 3 次
# 价格波动：教会查觉 ≥25 → +20%，污染 ≥60 → 烙印槽减半。
# 走 ShopService 抽象，与塔内商人共用购买路由。

const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")
const ShopInventoryScript = preload("res://scripts/shop/shop_inventory.gd")

const DEFAULT_POOL_PATH := "res://data/shops/donen_blackmarket.json"
const SHOP_ID := "donen_blackmarket"

var _game_state = null
var _pool: Dictionary = {}
var _inventory = null
var _offer_list: ItemList
var _currency_status_label: Label
var _message_label: Label
var _hint_label: Label
var _buy_button: Button
var _refresh_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(game_state = null) -> void:
	_game_state = game_state if game_state != null else GameState
	_pool = load_pool(DEFAULT_POOL_PATH)
	_message_label.text = ""
	_inventory = _ensure_inventory(_game_state, _pool)
	_populate()
	show()


# === 数据 / 库存 ===
static func load_pool(path: String = DEFAULT_POOL_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func is_open(game_state, pool: Dictionary) -> Dictionary:
	# Day < min_day_to_open 或 非夜晚 → 关闭
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if int(game_state.day) < int(pool.get("min_day_to_open", 0)):
		return {"ok": false, "reason": "min_day_locked", "min_day": int(pool.get("min_day_to_open", 0))}
	if str(game_state.time_of_day) != "night":
		return {"ok": false, "reason": "not_night"}
	return {"ok": true}


static func price_multiplier(game_state) -> float:
	if game_state == null:
		return 1.0
	var multiplier := 1.0
	if int(game_state.church_awareness) >= 25:
		multiplier *= 1.20
	return ShopServiceScript.price_multiplier_for(game_state, SHOP_ID, multiplier)


static func slot_count(game_state, pool: Dictionary) -> int:
	# R16/R20: pollution 60+ or church_awareness 50+ halves visible stock slots, floor 3.
	var base := int(pool.get("slot_count", 6))
	if game_state != null and (int(game_state.pollution) >= 60 or int(game_state.church_awareness) >= 50):
		base = max(3, int(base / 2))
	# halfmoon_trust ≥ 70 → 多 1 隐藏槽
	if game_state != null and int(game_state.halfmoon_trust) >= 70:
		base += 1
	return base


static func _ensure_inventory(game_state, pool: Dictionary):
	if game_state == null:
		return null
	var inv = game_state.shop_inventories.get(SHOP_ID, null)
	var day := int(game_state.day)
	if inv == null or int(inv.last_refresh_day) != day:
		inv = _roll_fresh(game_state, pool)
		game_state.shop_inventories[SHOP_ID] = inv
	return inv


static func _roll_fresh(game_state, pool: Dictionary):
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var slots := slot_count(game_state, pool)
	var inv = ShopInventoryScript.from_pool(SHOP_ID, pool, int(game_state.day), slots, rng)
	return inv


static func can_manual_refresh(game_state, pool: Dictionary, inventory) -> Dictionary:
	if inventory == null:
		return {"ok": false, "reason": "missing_inventory"}
	var cost := int(pool.get("manual_refresh_cost", 50))
	var limit := int(pool.get("manual_refresh_daily_limit", 3))
	if int(inventory.refresh_count_today) >= limit:
		return {"ok": false, "reason": "refresh_limit"}
	if int(game_state.lingstones) < cost:
		return {"ok": false, "reason": "insufficient_currency", "price": cost}
	return {"ok": true, "price": cost}


static func manual_refresh(game_state, pool: Dictionary, inventory) -> Dictionary:
	var check := can_manual_refresh(game_state, pool, inventory)
	if not bool(check.get("ok", false)):
		return check
	game_state.lingstones -= int(check.get("price", 50))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	inventory.slots = ShopInventoryScript.roll_slots(pool, int(game_state.day), slot_count(game_state, pool), rng)
	inventory.refresh_count_today = int(inventory.refresh_count_today) + 1
	return {"ok": true}


# === UI ===
func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.06, 0.08, 0.96)
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
	title.text = "唐恩的黑市"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_currency_status_label = Label.new()
	header.add_child(_currency_status_label)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint_label)

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

	_refresh_button = Button.new()
	_refresh_button.text = "刷新 (50 灵石)"
	_refresh_button.pressed.connect(_on_refresh_pressed)
	buttons.add_child(_refresh_button)

	var exit_button := Button.new()
	exit_button.text = "离开"
	exit_button.pressed.connect(_on_exit_pressed)
	buttons.add_child(exit_button)


func _populate() -> void:
	_refresh_currency()
	_offer_list.clear()
	var open_check: Dictionary = is_open(_game_state, _pool)
	if not bool(open_check.get("ok", false)):
		_hint_label.text = _open_hint(open_check)
		_buy_button.disabled = true
		_refresh_button.disabled = true
		return
	_hint_label.text = "今夜 6 槽。手动刷新剩余 %d 次。" % max(0, int(_pool.get("manual_refresh_daily_limit", 3)) - int(_inventory.refresh_count_today))
	var multiplier: float = price_multiplier(_game_state)
	for offer in _inventory.slots:
		var label: String = "%s | %s | x%d" % [str(offer.display_name), _offer_price_text(offer, multiplier), int(offer.stock)]
		var index: int = _offer_list.add_item(label)
		var check: Dictionary = ShopServiceScript.can_buy(offer, _game_state, multiplier)
		_offer_list.set_item_metadata(index, offer)
		if not bool(check.get("ok", false)):
			_offer_list.set_item_disabled(index, true)
			_offer_list.set_item_custom_fg_color(index, Color(0.55, 0.55, 0.58))
			_offer_list.set_item_tooltip(index, _reason_text_from_check(check))
	_refresh_buy_button(multiplier)
	var refresh_check: Dictionary = can_manual_refresh(_game_state, _pool, _inventory)
	_refresh_button.disabled = not bool(refresh_check.get("ok", false))
	_refresh_button.tooltip_text = _reason_text(str(refresh_check.get("reason", "")))


func _on_offer_selected(index: int) -> void:
	_refresh_buy_button(price_multiplier(_game_state), index)


func _on_buy_pressed() -> void:
	var selected := _offer_list.get_selected_items()
	if selected.is_empty():
		return
	var offer = _inventory.slots[selected[0]]
	var result: Dictionary = ShopServiceScript.buy(offer, _game_state, price_multiplier(_game_state), SHOP_ID)
	if bool(result.get("ok", false)):
		_message_label.text = "成交：%s" % str(offer.display_name)
	else:
		_message_label.text = _reason_text(str(result.get("reason", "")))
	_populate()


func _on_refresh_pressed() -> void:
	var result: Dictionary = manual_refresh(_game_state, _pool, _inventory)
	if bool(result.get("ok", false)):
		_message_label.text = "刷新成功"
	else:
		_message_label.text = _reason_text(str(result.get("reason", "")))
	_populate()


func _refresh_buy_button(multiplier: float, fallback_index: int = -1) -> void:
	if _buy_button == null or _offer_list == null:
		return
	var selected := _offer_list.get_selected_items()
	var selected_index := -1
	if not selected.is_empty():
		selected_index = int(selected[0])
	elif fallback_index >= 0 and _inventory != null and fallback_index < _inventory.slots.size():
		selected_index = fallback_index
	if selected_index < 0:
		_buy_button.disabled = true
		_buy_button.tooltip_text = ""
		return
	var offer = _inventory.slots[selected_index]
	var check: Dictionary = ShopServiceScript.can_buy(offer, _game_state, multiplier)
	_buy_button.disabled = not bool(check.get("ok", false))
	_buy_button.tooltip_text = "" if bool(check.get("ok", false)) else _reason_text_from_check(check)


func _refresh_currency() -> void:
	if _game_state == null:
		_currency_status_label.text = ""
		return
	_currency_status_label.text = "灵石 %d    残页 %d" % [int(_game_state.lingstones), int(_game_state.dao_pages)]


func _on_exit_pressed() -> void:
	hide()


func _open_hint(check: Dictionary) -> String:
	match str(check.get("reason", "")):
		"min_day_locked":
			return "黑市 Day %d 起开张（当前 Day %d）" % [int(check.get("min_day", 3)), int(_game_state.day)]
		"not_night":
			return "黑市仅夜晚开张（当前 %s）" % str(_game_state.time_of_day)
		_:
			return "黑市未开门"


static func _currency_display(currency: String) -> String:
	match currency:
		"lingstones": return "灵石"
		"dao_pages": return "残页"
		_: return currency


static func _offer_price_text(offer, multiplier: float) -> String:
	var primary: String = "%s %d" % [_currency_display(offer.price_currency), offer.priced_amount(multiplier)]
	if offer.secondary_price_currency != "" and int(offer.secondary_price_amount) > 0:
		return "%s + %s %d" % [primary, _currency_display(offer.secondary_price_currency), offer.priced_secondary_amount(multiplier)]
	return primary


func _reason_text_from_check(check: Dictionary) -> String:
	if str(check.get("reason", "")) == "locked" and str(check.get("detail", "")) != "":
		return str(check.get("detail", ""))
	return _reason_text(str(check.get("reason", "")))


func _reason_text(reason: String) -> String:
	match reason:
		"insufficient_currency": return "货币不足"
		"sold_out": return "商品已售罄"
		"missing_card_template": return "卡牌模板缺失"
		"missing_brand": return "烙印数据缺失"
		"locked": return "未开放（R14 等）"
		"sequence_too_low": return "序列不足，无法购买"
		"halfmoon_trust_too_low": return "半月信任不足"
		"refresh_limit": return "今日刷新次数已用完"
		"min_day_locked": return "黑市未到开放日"
		"not_night": return "黑市仅夜晚开张"
		"missing_inventory": return "黑市未开张"
		_: return ""


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_exit_pressed()
		accept_event()
