class_name DeckBuilder
extends Panel

const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")

# R01 §2.2：active_deck 允许多张同名卡（每张视为独立实例）。
# 占比限额按稀有度（传奇/史诗/稀有），不限制同名 template_id。
const CARD_ROW_HEIGHT := 42
const RARITY_QUOTA_RATIO := {
	"legendary": 0.10,
	"epic": 0.15,
	"rare": 0.30,
}

enum SortMode { PATHWAY = 0, QUALITY = 1, ENERGY = 2 }

var _game_state = null
var _selected_ids: Array[String] = []
var _sort_mode: SortMode = SortMode.PATHWAY

var _inventory_list: VBoxContainer
var _deck_list: VBoxContainer
var _count_label: Label
var _message_label: Label
var _sort_button: OptionButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(game_state = null) -> void:
	_game_state = game_state if game_state != null else GameState
	_selected_ids = initial_selected_ids(_game_state)
	_refresh()
	show()


static func initial_selected_ids(game_state) -> Array[String]:
	var result: Array[String] = []
	if game_state == null:
		return result
	for card_id in game_state.active_deck:
		var cid := str(card_id)
		if game_state.get_card(cid) != null and not cid in result:
			result.append(cid)
	return result


static func can_add_card(card, selected_ids: Array[String], game_state) -> Dictionary:
	if card == null:
		return {"ok": false, "reason": "missing_card"}
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if str(card.id) in selected_ids:
		return {"ok": false, "reason": "already_selected"}
	var unlock_check: Dictionary = TurnBattleScript.card_unlock_check_for_sequence(card, int(game_state.sequence))
	if not bool(unlock_check.get("ok", false)):
		return unlock_check
	var capacity := int(game_state.get_active_deck_capacity())
	if selected_ids.size() >= capacity:
		return {"ok": false, "reason": "capacity_full"}
	var rarity := str(card.rarity)
	if rarity in RARITY_QUOTA_RATIO:
		var quota := rarity_quota(capacity, rarity)
		var used := count_rarity_in_deck(game_state, selected_ids, rarity)
		if used >= quota:
			return {"ok": false, "reason": "rarity_quota", "rarity": rarity, "quota": quota}
	if rarity == "unique" and count_rarity_in_deck(game_state, selected_ids, "unique") >= 1:
		return {"ok": false, "reason": "unique_limit"}
	return {"ok": true, "reason": "ok"}


static func apply_selection(game_state, selected_ids: Array[String]) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var capacity := int(game_state.get_active_deck_capacity())
	if selected_ids.size() > capacity:
		return {"ok": false, "reason": "capacity_full"}
	var rarity_counts := {"legendary": 0, "epic": 0, "rare": 0, "unique": 0}
	for card_id in selected_ids:
		var card = game_state.get_card(card_id)
		if card == null:
			return {"ok": false, "reason": "missing_card", "card_id": card_id}
		var unlock_check: Dictionary = TurnBattleScript.card_unlock_check_for_sequence(card, int(game_state.sequence))
		if not bool(unlock_check.get("ok", false)):
			return unlock_check
		var rarity := str(card.rarity)
		if rarity in rarity_counts:
			rarity_counts[rarity] = int(rarity_counts[rarity]) + 1
	for rarity in RARITY_QUOTA_RATIO.keys():
		var quota := rarity_quota(capacity, rarity)
		if int(rarity_counts.get(rarity, 0)) > quota:
			return {"ok": false, "reason": "rarity_quota", "rarity": rarity, "quota": quota}
	if int(rarity_counts.get("unique", 0)) > 1:
		return {"ok": false, "reason": "unique_limit"}
	if not game_state.set_active_deck(selected_ids):
		return {"ok": false, "reason": "state_rejected"}
	return {"ok": true, "reason": "ok"}


static func rarity_quota(capacity: int, rarity: String) -> int:
	var ratio: float = float(RARITY_QUOTA_RATIO.get(rarity, 0.0))
	return int(ceil(float(capacity) * ratio))


static func count_rarity_in_deck(game_state, selected_ids: Array[String], rarity: String) -> int:
	var count := 0
	for card_id in selected_ids:
		var card = game_state.get_card(card_id)
		if card != null and str(card.rarity) == rarity:
			count += 1
	return count


static func sorted_cards(cards: Array, sort_mode: SortMode) -> Array:
	var result := cards.duplicate()
	match sort_mode:
		SortMode.QUALITY:
			result.sort_custom(_cmp_quality)
		SortMode.ENERGY:
			result.sort_custom(_cmp_energy)
		_:
			result.sort_custom(_cmp_pathway)
	return result


static func card_label(card) -> String:
	if card == null:
		return ""
	var name_text: String = card.get_display_name() if card.has_method("get_display_name") else str(card.template_id)
	return "%s | 序列%d | Q%d | %s | dmg %d | cost %d" % [
		name_text,
		int(card.sequence),
		int(card.quality),
		_pathway_label(str(card.pathway)),
		int(card.damage),
		int(card.energy_cost),
	]


static func _pathway_label(pathway: String) -> String:
	match pathway:
		"fool": return "愚者"
		"magician": return "魔术师"
		_: return pathway


static func _template_id(card) -> String:
	var tid := str(card.template_id)
	return tid if tid != "" else str(card.id)


static func _cmp_pathway(a, b) -> bool:
	if str(a.pathway) == "fool" and str(b.pathway) != "fool":
		return true
	if str(b.pathway) == "fool" and str(a.pathway) != "fool":
		return false
	if str(a.pathway) == str(b.pathway):
		return str(a.id) < str(b.id)
	return str(a.pathway) < str(b.pathway)


static func _cmp_quality(a, b) -> bool:
	if int(a.quality) == int(b.quality):
		return str(a.id) < str(b.id)
	return int(a.quality) > int(b.quality)


static func _cmp_energy(a, b) -> bool:
	if int(a.energy_cost) == int(b.energy_cost):
		return str(a.id) < str(b.id)
	return int(a.energy_cost) < int(b.energy_cost)


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.11, 0.96)
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

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var title := Label.new()
	title.text = "构筑卡组"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	_count_label = Label.new()
	_count_label.text = "0/0"
	_count_label.add_theme_font_size_override("font_size", 18)
	top.add_child(_count_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_inventory_side())
	body.add_child(_build_deck_side())

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)

	var confirm := Button.new()
	confirm.text = "确认"
	confirm.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel)


func _build_inventory_side() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(420, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var label := Label.new()
	label.text = "卡库"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	_sort_button = OptionButton.new()
	_sort_button.add_item("按途径")
	_sort_button.add_item("按品质")
	_sort_button.add_item("按能耗")
	_sort_button.item_selected.connect(_on_sort_selected)
	header.add_child(_sort_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inventory_list)
	return panel


func _build_deck_side() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(360, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var label := Label.new()
	label.text = "当前卡组"
	box.add_child(label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_deck_list = VBoxContainer.new()
	_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_deck_list)
	return panel


func _refresh() -> void:
	if _game_state == null:
		return
	_count_label.text = "%d/%d" % [_selected_ids.size(), int(_game_state.get_active_deck_capacity())]
	_rebuild_inventory_list()
	_rebuild_deck_list()


func _rebuild_inventory_list() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()
	var cards := sorted_cards(_game_state.cards_inventory, _sort_mode)
	for card in cards:
		if str(card.id) in _selected_ids:
			continue
		_inventory_list.add_child(_make_card_button(card, true))


func _rebuild_deck_list() -> void:
	for child in _deck_list.get_children():
		child.queue_free()
	for card_id in _selected_ids:
		var card = _game_state.get_card(card_id)
		if card != null:
			_deck_list.add_child(_make_card_button(card, false))


func _make_card_button(card, add_mode: bool) -> Button:
	var button := Button.new()
	button.text = card_label(card)
	button.custom_minimum_size.y = CARD_ROW_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if add_mode:
		var add_check: Dictionary = can_add_card(card, _selected_ids, _game_state)
		if not bool(add_check.get("ok", false)):
			var add_reason := str(add_check.get("reason", ""))
			if add_reason in ["sequence_locked", "mechanic_locked"]:
				button.disabled = true
				button.text += " | " + _reason_text(add_reason)
			button.tooltip_text = _reason_text(add_reason)
		button.pressed.connect(_on_inventory_card_pressed.bind(str(card.id)))
	else:
		if _game_state != null:
			var deck_check: Dictionary = TurnBattleScript.card_unlock_check_for_sequence(card, int(_game_state.sequence))
			if not bool(deck_check.get("ok", false)):
				var deck_reason := str(deck_check.get("reason", ""))
				button.text += " | " + _reason_text(deck_reason)
				button.tooltip_text = _reason_text(deck_reason)
		button.pressed.connect(_on_deck_card_pressed.bind(str(card.id)))
	return button


func _on_inventory_card_pressed(card_id: String) -> void:
	var card = _game_state.get_card(card_id)
	var result: Dictionary = can_add_card(card, _selected_ids, _game_state)
	if bool(result.get("ok", false)):
		_selected_ids.append(card_id)
		_message_label.text = ""
	else:
		_message_label.text = _reason_text(str(result.get("reason", "")))
	_refresh()


func _on_deck_card_pressed(card_id: String) -> void:
	_selected_ids.erase(card_id)
	_message_label.text = ""
	_refresh()


func _on_sort_selected(index: int) -> void:
	_sort_mode = index as SortMode
	_refresh()


func _on_confirm_pressed() -> void:
	var result: Dictionary = apply_selection(_game_state, _selected_ids)
	if bool(result.get("ok", false)):
		hide()
	else:
		_message_label.text = _reason_text(str(result.get("reason", "")))


func _on_cancel_pressed() -> void:
	_selected_ids = []
	hide()


func _reason_text(reason: String) -> String:
	match reason:
		"sequence_locked":
			return "序列未解锁"
		"mechanic_locked":
			return "机制未解锁"
		"capacity_full":
			return "卡组容量已满"
		"rarity_quota":
			return "该稀有度占比已达上限"
		"unique_limit":
			return "每塔卡组限带 1 张唯一卡"
		"already_selected":
			return "这张卡已经在卡组中"
		"missing_card":
			return "卡牌不存在"
		_:
			return "无法加入卡组"


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		accept_event()
