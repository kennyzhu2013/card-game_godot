class_name DebugPanel
extends Panel

# 测试调试面板：一键给资源、刷卡、刷烙印、切序列/时段/天、推进AP等
# 仅用于开发期间验收 Slice 1 各模块。F12 切换显示。

const CardScript = preload("res://scripts/combat/card.gd")
const CardLibraryScript = preload("res://scripts/combat/card_library.gd")
const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const ForgeResultCalculatorScript = preload("res://scripts/ritual/forge_result_calculator.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")

const SKILLS_DIR := "res://data/skills/"
const TIMES := ["morning", "noon", "evening", "night"]
const SEQUENCES := [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]

var _game_state = null
var _hub = null
var _message_label: Label
var _status_label: Label
var _quality_button: OptionButton
var _sequence_button: OptionButton
var _time_button: OptionButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func attach(hub) -> void:
	_hub = hub


func toggle() -> void:
	if visible:
		hide()
	else:
		open()


func open(game_state = null) -> void:
	_game_state = game_state if game_state != null else GameState
	_refresh_status()
	show()


func close_panel() -> void:
	hide()


# === 货币 / 资源 ===
func grant_lingstones(amount: int) -> void:
	if _game_state == null:
		return
	_game_state.lingstones += amount
	_set_message("灵石 +%d" % amount)


func grant_dao_pages(amount: int) -> void:
	if _game_state == null:
		return
	_game_state.dao_pages += amount
	_set_message("残页 +%d" % amount)


func grant_forge_material(material_id: String, amount: int) -> void:
	if _game_state == null:
		return
	_game_state.forge_materials[material_id] = int(_game_state.forge_materials.get(material_id, 0)) + amount
	_set_message("%s +%d" % [material_id, amount])


func grant_full_materials() -> void:
	if _game_state == null:
		return
	for mat in ["愚者残页", "影尘", "铁屑", "灵镜片", "血油"]:
		_game_state.forge_materials[mat] = int(_game_state.forge_materials.get(mat, 0)) + 20
	_set_message("锻造材料各 +20")


# === 卡牌（绕过锻造，直接发卡） ===
func grant_all_cards_once(quality: int = 3) -> int:
	if _game_state == null:
		return 0
	var added := 0
	for skill_id in available_skill_ids():
		var card = build_card_from_skill(skill_id, quality)
		if card == null:
			continue
		_game_state.add_card(card)
		_record_discovered(card)
		added += 1
	_set_message("一键发卡 ×%d (品质 %d)" % [added, quality])
	return added


func grant_card_by_template(template_id: String, quality: int = 3):
	if _game_state == null:
		return null
	var card = build_card_from_skill(template_id, quality)
	if card == null:
		_set_message("找不到模板：%s" % template_id)
		return null
	_game_state.add_card(card)
	_record_discovered(card)
	_set_message("发卡 %s (品质 %d)" % [template_id, quality])
	return card


static func available_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	var library = CardLibraryScript.new()
	library.load_all()
	for card in library.all_cards():
		if card == null:
			continue
		var template_id := str(card.template_id)
		if template_id == "":
			template_id = str(card.id)
		if template_id != "" and not ids.has(template_id):
			ids.append(template_id)
	ids.sort()
	return ids


static func build_card_from_skill(skill_id: String, quality: int):
	var library_card = _runtime_template_card(skill_id)
	if library_card != null:
		return _build_debug_card_from_template(library_card, skill_id, quality)
	var path := "%s%s.json" % [SKILLS_DIR, skill_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	var clamped_quality: int = clampi(quality, 1, 5)
	var multiplier: float = ForgeResultCalculatorScript.QUALITY_MULTIPLIER.get(clamped_quality, 1.0)
	var data: Dictionary = parsed.duplicate(true)
	data["quality"] = clamped_quality
	data["template_id"] = skill_id
	data["id"] = "%s_debug_%d_%d" % [skill_id, Time.get_ticks_usec(), randi() % 100000]
	data["brand_slots"] = clamped_quality + 1
	data["rarity"] = _rarity_for_quality(clamped_quality)
	if not data.has("display_name") or str(data.get("display_name", "")) == "":
		data["display_name"] = skill_id
	if data.has("combat_effect") and data["combat_effect"] is Dictionary:
		var combat: Dictionary = data["combat_effect"]
		combat["damage"] = int(round(float(combat.get("damage", 0)) * multiplier))
		combat["heal"] = int(round(float(combat.get("heal", 0)) * multiplier))
	else:
		data["damage"] = int(round(float(data.get("damage", 0)) * multiplier))
		data["heal"] = int(round(float(data.get("heal", 0)) * multiplier))
	return CardScript.from_skill_json(data)


static func _runtime_template_card(template_id: String):
	var library = CardLibraryScript.new()
	library.load_all()
	var card = library.get_card(template_id)
	if card != null:
		return card
	for candidate in library.all_cards():
		if candidate != null and str(candidate.template_id) == template_id:
			return candidate
	return null


static func _build_debug_card_from_template(template_card, template_id: String, quality: int):
	var clamped_quality: int = clampi(quality, 1, 5)
	var multiplier: float = ForgeResultCalculatorScript.QUALITY_MULTIPLIER.get(clamped_quality, 1.0)
	var data: Dictionary = template_card.to_dict()
	var resolved_template_id := str(template_card.template_id)
	if resolved_template_id == "":
		resolved_template_id = template_id
	data["quality"] = clamped_quality
	data["template_id"] = resolved_template_id
	data["id"] = "%s_debug_%d_%d" % [resolved_template_id, Time.get_ticks_usec(), randi() % 100000]
	data["brand_slots"] = clamped_quality + 1
	data["rarity"] = _rarity_for_quality(clamped_quality)
	if not data.has("display_name") or str(data.get("display_name", "")) == "":
		data["display_name"] = resolved_template_id
	var combat: Dictionary = data.get("combat_effect", {})
	combat["damage"] = int(round(float(combat.get("damage", 0)) * multiplier))
	combat["heal"] = int(round(float(combat.get("heal", 0)) * multiplier))
	data["combat_effect"] = combat
	return CardScript.from_json(data)


static func _rarity_for_quality(quality: int) -> String:
	match quality:
		5: return "legendary"
		4: return "epic"
		3: return "rare"
		_: return "common"


# === 烙印 ===
func grant_all_brands_once() -> int:
	if _game_state == null:
		return 0
	var data: Dictionary = BrandCatalogScript.load_data()
	var entries: Array = data.get("brands", [])
	var added := 0
	for entry in entries:
		if not entry is Dictionary:
			continue
		var brand_id := str(entry.get("id", ""))
		if brand_id == "":
			continue
		if BrandCatalogScript.grant_brand_to_state(brand_id, _game_state) != null:
			added += 1
	_set_message("一键发烙印 ×%d" % added)
	return added


# === 序列 / 污染 / 时间 / AP ===
func set_sequence(value: int) -> void:
	if _game_state == null:
		return
	_game_state.sequence = clampi(value, 0, 9)
	_set_message("序列设为 %d" % _game_state.sequence)


func set_time_of_day(time_id: String) -> void:
	if _game_state == null or not time_id in TIMES:
		return
	_game_state.time_of_day = time_id
	_set_message("时段设为 %s" % time_id)


func jump_to_city_time(district_id: String, time_id: String) -> Dictionary:
	if _game_state == null:
		_game_state = GameState
	if time_id in TIMES:
		_game_state.time_of_day = time_id
	if _hub != null and _hub.has_method("open_city_for_debug"):
		var result: Dictionary = _hub.open_city_for_debug(district_id, str(_game_state.time_of_day))
		_set_message("jump %s @ %s" % [district_id, str(_game_state.time_of_day)])
		return result
	_set_message("missing hub debug city jump")
	return {"ok": false, "reason": "missing_hub", "district_id": district_id}


func advance_day(amount: int = 1) -> void:
	if _game_state == null:
		return
	SleepServiceScript.sleep_to_next_day(_game_state, amount)
	_set_message("入梦推进 %d 天 → Day %d" % [amount, _game_state.day])


func refill_ap() -> void:
	if _game_state == null:
		return
	_game_state.ap = int(_game_state.ap_max)
	_set_message("AP 满到 %d" % _game_state.ap)


func add_pollution(amount: int) -> void:
	if _game_state == null:
		return
	_game_state.pollution = clampi(int(_game_state.pollution) + amount, 0, 100)
	_set_message("污染 %d" % _game_state.pollution)


func fill_pollution_to_lost_control() -> Dictionary:
	if _game_state == null:
		_game_state = GameState
	var result: Dictionary = {}
	if _game_state.has_method("set_pollution"):
		result = _game_state.set_pollution(100, ["debug_fill_pollution"])
	else:
		_game_state.pollution = 100
		_game_state.pollution_stage = 5
	if not bool(_game_state.is_lost_control) and _game_state.has_method("enter_lost_control"):
		result["lost_control"] = _game_state.enter_lost_control(["debug_fill_pollution"])
	_set_message("一键拉满污染 -> 失控")
	result["ok"] = bool(_game_state.is_lost_control) and int(_game_state.pollution) >= 100
	result["pollution"] = int(_game_state.pollution)
	result["pollution_stage"] = int(_game_state.pollution_stage)
	return result


func clear_pollution() -> void:
	if _game_state == null:
		return
	_game_state.pollution = 0
	_game_state.pollution_stage = 0
	_set_message("污染清零")


func launch_practice_battle() -> void:
	# 直接进战斗场景：用 active_deck（如果空则用 cards_inventory 前 8 张），打一个醉汉
	if _game_state == null:
		return
	var EnemyLibrary = load("res://scripts/combat/enemy_library.gd")
	var lib = EnemyLibrary.new()
	var drunkard = lib.load_enemy("drunkard")
	var deck: Array = []
	for cid in _game_state.active_deck:
		var c = _game_state.get_card(cid)
		if c != null:
			deck.append(c)
	if deck.is_empty():
		for c in _game_state.cards_inventory.slice(0, 8):
			deck.append(c)
	if deck.is_empty():
		_set_message("先用调试面板发卡，再开练习战斗")
		return
	var scene = load("res://scenes/combat/battle_scene.tscn")
	if scene == null or not scene.can_instantiate():
		_set_message("战斗场景未配置")
		return
	if get_tree() == null:
		return
	get_tree().change_scene_to_packed(scene)
	# 场景切换后下一帧再 start_battle
	await get_tree().process_frame
	var battle: Node = get_tree().current_scene
	if battle != null and battle.has_method("start_battle"):
		battle.start_battle(deck, [], [drunkard], [] as Array[String], null, _game_state)


# === UI 构造 ===
func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.08, 0.94)
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
	title.text = "🧪 调试面板（仅开发期间）"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "关闭 (F12)"
	close.pressed.connect(close_panel)
	header.add_child(close)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	root.add_child(_make_section("货币 / 资源", [
		_make_button("+500 灵石", grant_lingstones.bind(500)),
		_make_button("+5 残页", grant_dao_pages.bind(5)),
		_make_button("锻造材料 +20", grant_full_materials),
	]))

	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 8)
	var card_label := Label.new()
	card_label.text = "卡牌品质"
	card_row.add_child(card_label)
	_quality_button = OptionButton.new()
	for q in [1, 2, 3, 4, 5]:
		_quality_button.add_item("品质 %d" % q, q)
	_quality_button.select(2)
	card_row.add_child(_quality_button)
	card_row.add_child(_make_button("一键发全卡 ×1", _on_grant_all_cards))
	card_row.add_child(_make_button("一键发烙印", grant_all_brands_once))
	root.add_child(_titled_section("卡牌 / 烙印", [card_row]))

	var seq_row := HBoxContainer.new()
	seq_row.add_theme_constant_override("separation", 8)
	seq_row.add_child(_make_label("序列"))
	_sequence_button = OptionButton.new()
	for s in SEQUENCES:
		_sequence_button.add_item("序列 %d" % s, s)
	_sequence_button.item_selected.connect(_on_sequence_selected)
	seq_row.add_child(_sequence_button)
	seq_row.add_child(_make_label("时段"))
	_time_button = OptionButton.new()
	for t in TIMES:
		_time_button.add_item(t)
	_time_button.item_selected.connect(_on_time_selected)
	seq_row.add_child(_time_button)
	root.add_child(_titled_section("序列 / 时段", [seq_row]))

	root.add_child(_make_section("时间 / AP", [
		_make_button("满 AP", refill_ap),
		_make_button("推进 1 天", advance_day.bind(1)),
		_make_button("推进 7 天", advance_day.bind(7)),
	]))

	root.add_child(_make_section("污染", [
		_make_button("污染 +10", add_pollution.bind(10)),
		_make_button("污染 +50", add_pollution.bind(50)),
		_make_button("污染清零", clear_pollution),
	]))

	root.add_child(_make_section("战斗", [
		_make_button("练习战斗（醉汉）", launch_practice_battle),
	]))

	root.add_child(_make_section("Lost Control", [
		_make_button("一键拉满污染", fill_pollution_to_lost_control),
	]))

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)


func _make_section(title_text: String, buttons: Array) -> Control:
	return _titled_section(title_text, [_buttons_row(buttons)])


func _titled_section(title_text: String, content: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 14)
	box.add_child(label)
	for child in content:
		box.add_child(child)
	return box


func _buttons_row(buttons: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for btn in buttons:
		row.add_child(btn)
	return row


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	return btn


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


# === 状态刷新 ===
func _refresh_status() -> void:
	if _game_state == null:
		_status_label.text = ""
		return
	_status_label.text = "Day %d · %s · 序列 %d · AP %d/%d · 灵石 %d · 残页 %d · 污染 %d · 卡库 %d · 烙印 %d" % [
		int(_game_state.day),
		str(_game_state.time_of_day),
		int(_game_state.sequence),
		int(_game_state.ap),
		int(_game_state.ap_max),
		int(_game_state.lingstones),
		int(_game_state.dao_pages),
		int(_game_state.pollution),
		_game_state.cards_inventory.size(),
		_game_state.brands_inventory.size(),
	]
	if _sequence_button != null:
		var seq_idx := SEQUENCES.find(int(_game_state.sequence))
		_sequence_button.select(maxi(seq_idx, 0))
	if _time_button != null:
		var t_idx := TIMES.find(str(_game_state.time_of_day))
		_time_button.select(maxi(t_idx, 0))


func _set_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text
	_refresh_status()
	if _hub != null and _hub.has_method("_refresh_status"):
		_hub._refresh_status()


func _record_discovered(card) -> void:
	if card == null or _game_state == null:
		return
	var discovered: Array = _game_state.daodian.get("discovered_cards", [])
	if not card.template_id in discovered:
		discovered.append(card.template_id)
	_game_state.daodian["discovered_cards"] = discovered


func _on_grant_all_cards() -> void:
	var quality := int(_quality_button.get_item_id(_quality_button.selected)) if _quality_button != null else 3
	grant_all_cards_once(quality)


func _on_sequence_selected(index: int) -> void:
	if _sequence_button == null:
		return
	set_sequence(int(_sequence_button.get_item_id(index)))


func _on_time_selected(index: int) -> void:
	if index >= 0 and index < TIMES.size():
		set_time_of_day(TIMES[index])


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		accept_event()
