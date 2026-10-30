class_name CardInventoryPanel
extends Panel

# 卡库管理面板 (R10 §3)
# 从 hub 书桌 -> 塔罗书桌 打开
# T3.1 列表 + T3.2 排序 + T3.3 筛选 + T3.5 详情子页

const CARD_ENTRY_HEIGHT := 48

enum SortMode { INDEX = 0, PATHWAY = 1, SEQUENCE = 2 }
enum FilterBrand { ALL = 0, MOUNTED = 1, UNMOUNTED = 2 }

var _sort_mode: SortMode = SortMode.INDEX
var _filter_pathway: String = ""
var _filter_brand: FilterBrand = FilterBrand.ALL
var _displayed_cards: Array = []

var _title_label: Label
var _sort_button: OptionButton
var _pathway_button: OptionButton
var _brand_filter_button: OptionButton
var _card_list: VBoxContainer
var _scroll: ScrollContainer
var _detail_panel: Control
var _detail_labels: Dictionary = {}
var _destroy_button: Button


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()
	hide()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.12, 0.95)
	add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_top = 0.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# 顶栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	vbox.add_child(top)

	_title_label = Label.new()
	_title_label.text = "当前卡库: 0 张 (无容量限制)"
	_title_label.add_theme_font_size_override("font_size", 18)
	top.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "关闭 [Esc]"
	close_btn.pressed.connect(hide)
	top.add_child(close_btn)

	# 排序/筛选栏
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	vbox.add_child(controls)

	var sort_label := Label.new()
	sort_label.text = "排序:"
	controls.add_child(sort_label)

	_sort_button = OptionButton.new()
	_sort_button.add_item("获得顺序")
	_sort_button.add_item("途径")
	_sort_button.add_item("序列 (升序)")
	_sort_button.item_selected.connect(_on_sort_changed)
	controls.add_child(_sort_button)

	var pw_label := Label.new()
	pw_label.text = "途径:"
	controls.add_child(pw_label)

	_pathway_button = OptionButton.new()
	_pathway_button.add_item("全部")
	_pathway_button.add_item("愚者 (fool)")
	_pathway_button.add_item("女祭司 (priestess)")
	_pathway_button.add_item("皇帝 (emperor)")
	_pathway_button.add_item("战车 (chariot)")
	_pathway_button.set_item_disabled(2, true)
	_pathway_button.set_item_disabled(3, true)
	_pathway_button.set_item_disabled(4, true)
	_pathway_button.item_selected.connect(_on_pathway_filter_changed)
	controls.add_child(_pathway_button)

	var bf_label := Label.new()
	bf_label.text = "烙印:"
	controls.add_child(bf_label)

	_brand_filter_button = OptionButton.new()
	_brand_filter_button.add_item("全部")
	_brand_filter_button.add_item("已挂载")
	_brand_filter_button.add_item("未挂载")
	_brand_filter_button.item_selected.connect(_on_brand_filter_changed)
	controls.add_child(_brand_filter_button)

	# 卡片列表
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_card_list = VBoxContainer.new()
	_card_list.add_theme_constant_override("separation", 2)
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_card_list)

	# 详情子页 (初始隐藏)
	_detail_panel = _build_detail_panel()
	add_child(_detail_panel)
	_detail_panel.hide()


func _build_detail_panel() -> Control:
	var panel := Panel.new()
	panel.anchor_left = 0.55
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.1, 0.15, 0.97)
	panel.add_theme_stylebox_override("panel", bg)

	var sv := ScrollContainer.new()
	sv.anchor_left = 0.0
	sv.anchor_right = 1.0
	sv.anchor_top = 0.0
	sv.anchor_bottom = 1.0
	panel.add_child(sv)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(content)

	var close_btn := Button.new()
	close_btn.text = "关闭详情"
	close_btn.pressed.connect(panel.hide)
	content.add_child(close_btn)

	# 字段标签 (按需填充)
	var fields := [
		"name", "pathway", "sequence", "rarity", "quality", "energy_cost",
		"description", "effect_summary", "element", "damage", "heal", "target", "range", "status_effects",
		"acting_rules", "rule_violation_penalty", "brands_info",
		"cultivation", "upgrade_info", "effective_damage",
	]
	for f in fields:
		var lb := Label.new()
		lb.text = f + ": "
		lb.add_theme_font_size_override("font_size", 13)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(lb)
		_detail_labels[f] = lb

	_destroy_button = Button.new()
	_destroy_button.text = "销毁此卡 (返还 50% 材料，道典保留)"
	_destroy_button.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	content.add_child(_destroy_button)

	return panel


func open() -> void:
	if not is_instance_valid(GameState):
		return
	_refresh()
	show()


func _refresh() -> void:
	if not is_instance_valid(GameState):
		return
	var gs = GameState
	var cards: Array = gs.cards_inventory.duplicate()

	# 筛选
	cards = _apply_filters(cards)
	# 排序
	cards = _apply_sort(cards)

	_displayed_cards = cards
	_title_label.text = "当前卡库: %d 张 (无容量限制)" % gs.cards_inventory.size()
	_rebuild_list()


func _apply_filters(cards: Array) -> Array:
	return filter_cards(cards, _filter_pathway, _filter_brand)


static func filter_cards(cards: Array, pathway_filter: String, brand_filter: FilterBrand) -> Array:
	var result: Array = []
	for c in cards:
		if pathway_filter != "" and c.pathway != pathway_filter:
			continue
		match brand_filter:
			FilterBrand.MOUNTED:
				if c.brands.size() == 0:
					continue
			FilterBrand.UNMOUNTED:
				if c.brands.size() > 0:
					continue
		result.append(c)
	return result


func _apply_sort(cards: Array) -> Array:
	var result := cards.duplicate()
	match _sort_mode:
		SortMode.PATHWAY:
			result.sort_custom(_cmp_pathway)
		SortMode.SEQUENCE:
			result.sort_custom(_cmp_sequence)
		# SortMode.INDEX: keep original order (= cards_inventory index)
	return result


static func _cmp_pathway(a, b) -> bool:
	if a.pathway == "fool" and b.pathway != "fool":
		return true
	if b.pathway == "fool" and a.pathway != "fool":
		return false
	return a.pathway < b.pathway


static func _cmp_sequence(a, b) -> bool:
	return a.sequence < b.sequence


func _rebuild_list() -> void:
	for child in _card_list.get_children():
		child.queue_free()

	for i in _displayed_cards.size():
		var c = _displayed_cards[i]
		var entry := _make_card_entry(i, c)
		_card_list.add_child(entry)


func _make_card_entry(index: int, card) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = CARD_ENTRY_HEIGHT

	var display_id: String = card.get_display_name() if card.has_method("get_display_name") else (card.template_id if card.template_id != "" else card.id)
	var quality_stars := ""
	for q in card.quality:
		quality_stars += "★"

	var label_text := "%2d. %s %s  [%s]  道行:%d  扮演:%d/10  烙印:%d/%d" % [
		index + 1,
		display_id,
		quality_stars,
		_pathway_label(str(card.pathway)),
		card.cultivation_level,
		card.acting_exp,
		card.brands.size(),
		card.brand_slots,
	]
	var summary := _card_effect_summary(card)
	if summary != "":
		label_text += "\n    %s" % summary.replace("\n", " / ")
		row.custom_minimum_size.y = CARD_ENTRY_HEIGHT + 26

	var lb := Label.new()
	lb.text = label_text
	lb.add_theme_font_size_override("font_size", 12)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(lb)

	var detail_btn := Button.new()
	detail_btn.text = "详情"
	detail_btn.pressed.connect(_show_detail.bind(card, _destroy_button))
	row.add_child(detail_btn)

	return row


static func _pathway_label(pathway: String) -> String:
	match pathway:
		"fool": return "愚者"
		"magician": return "魔术师"
		_: return pathway


func _show_detail(card, destroy_btn: Button) -> void:
	_detail_panel.show()
	var card_name: String = card.get_display_name() if card.has_method("get_display_name") else (card.template_id if card.template_id != "" else card.id)
	_detail_labels["name"].text = "名称: %s" % card_name
	_detail_labels["pathway"].text = "途径: %s" % _pathway_label(str(card.pathway))
	_detail_labels["sequence"].text = "序列: %d" % card.sequence
	var rarity_text: String = card.rarity_label() if card.has_method("rarity_label") else str(card.rarity)
	_detail_labels["rarity"].text = "稀有度: %s" % rarity_text
	_detail_labels["quality"].text = "品质: %d ★" % card.quality
	_detail_labels["energy_cost"].text = "能耗: %d" % card.energy_cost
	_detail_labels["description"].text = "描述: %s" % str(card.description)
	_detail_labels["effect_summary"].text = "效果解读:\n%s" % _card_effect_summary(card)
	_detail_labels["element"].text = "元素: %s" % card.element
	_detail_labels["damage"].text = "伤害: %d" % card.damage
	_detail_labels["heal"].text = "治疗: %d" % card.heal
	var target_text: String = card.target_label() if card.has_method("target_label") else str(card.target)
	_detail_labels["target"].text = "目标: %s（范围 %d）" % [target_text, card.range]
	var status_text: String = card.status_effects_text() if card.has_method("status_effects_text") else ""
	_detail_labels["status_effects"].text = "状态: %s" % (status_text if status_text != "" else "无")
	var rules_text: String = card.acting_rules_text() if card.has_method("acting_rules_text") else ""
	_detail_labels["acting_rules"].text = "守则: %s" % (rules_text if rules_text != "" else "无")
	var penalty_text: String = card.rule_violation_penalty_text() if card.has_method("rule_violation_penalty_text") else ""
	_detail_labels["rule_violation_penalty"].text = "惩戒: %s" % (penalty_text if penalty_text != "" else "无")
	var brands_text: String = card.brands_text() if card.has_method("brands_text") else "已挂载 %d/%d" % [card.brands.size(), card.brand_slots]
	_detail_labels["brands_info"].text = "烙印: %s" % brands_text
	_detail_labels["cultivation"].text = "道行: Lv.%d (出牌 %d/10)" % [card.cultivation_level, card.play_count % 10]

	var upgrade_text := "升级: Lv.%d/5 (扮演经验 %d/10)" % [card.upgrade_level, card.acting_exp]
	if card.upgrade_level >= 5:
		upgrade_text += " [已封顶]"
	_detail_labels["upgrade_info"].text = upgrade_text

	_detail_labels["effective_damage"].text = "实际伤害: %d (含升级加成)" % card.get_effective_damage()

	# 断开旧连接，接新卡
	if destroy_btn.pressed.is_connected(_on_destroy_pressed):
		destroy_btn.pressed.disconnect(_on_destroy_pressed)
	destroy_btn.pressed.connect(_on_destroy_pressed.bind(card.id))


static func _card_effect_summary(card) -> String:
	if card != null and card.has_method("effect_summary_text"):
		return str(card.call("effect_summary_text")).strip_edges()
	return ""


func _on_destroy_pressed(card_id: String) -> void:
	if not is_instance_valid(GameState):
		return
	_confirm_destroy(card_id)


func _confirm_destroy(card_id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "确认销毁"
	dialog.dialog_text = "销毁此卡将返还 50% 材料 (道典保留)。\n确定销毁？"
	dialog.confirmed.connect(_do_destroy.bind(card_id, dialog))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _do_destroy(card_id: String, dialog: ConfirmationDialog) -> void:
	dialog.queue_free()
	if not is_instance_valid(GameState):
		return
	GameState.destroy_card(card_id)
	_detail_panel.hide()
	_refresh()


func _on_sort_changed(idx: int) -> void:
	_sort_mode = idx as SortMode
	_refresh()


func _on_pathway_filter_changed(idx: int) -> void:
	match idx:
		0: _filter_pathway = ""
		1: _filter_pathway = "fool"
		_: _filter_pathway = ""  # disabled items fallback
	_refresh()


func _on_brand_filter_changed(idx: int) -> void:
	_filter_brand = idx as FilterBrand
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		hide()
		accept_event()
