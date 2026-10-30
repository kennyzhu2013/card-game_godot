extends Control

signal tower_completed(tower)
signal tower_collapsed(tower)
signal tower_event_resolved(tower, event_result: Dictionary)
signal returned_to_hub(reason: String)
signal floor_started(floor)
signal floor_cleared(floor)

const BattleScenePath := "res://scenes/combat/battle_scene.tscn"
const TowerMerchantPath := "res://scenes/ui/tower_merchant.tscn"
const HubScenePath := "res://scenes/hub/hub.tscn"

const EnemyLibraryScript = preload("res://scripts/combat/enemy_library.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const SaveStoreScript = preload("res://scripts/state/save_store.gd")
const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")
const TimeAdvanceServiceScript = preload("res://scripts/world/time_advance_service.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const CardLibraryScript = preload("res://scripts/combat/card_library.gd")
const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")
const TowerGeneratorScript = preload("res://scripts/tower/tower_generator.gd")
const CycleEndServiceScript = preload("res://scripts/world/cycle_end_service.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")
const ContractPickerScript = preload("res://scripts/ui/contract_picker_dialog.gd")

var _tower = null
var _game_state = null
var _current_floor_index: int = 0
var _active_view_kind: String = "closed"
var _active_battle_scene: Node = null
var _active_merchant: Node = null
var _choice_payloads: Array = []
var _choice_contexts: Array = []
var _last_battle_payload: Dictionary = {}
var _last_return_reason: String = ""
var _last_floor_result: String = ""
var _return_time_advanced: bool = false
var _last_npc_feedback_result: Dictionary = {}
var _ai_gm_service = null

var _root_panel: PanelContainer
var _title_label: Label
var _status_label: Label
var _intel_preview_label: Label
var _narrative_label: Label
var _floor_list: VBoxContainer
var _message_label: Label
var _choice_panel: PanelContainer
var _choice_title: Label
var _choice_body: Label
var _choice_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(tower, game_state = null) -> Dictionary:
	_tower = tower
	_game_state = game_state if game_state != null else GameState
	_ensure_active_contract_for_tower()
	var ap_result: Dictionary = _try_spend_entry_ap()
	if not bool(ap_result.get("ok", false)):
		_last_return_reason = str(ap_result.get("reason", "ap_short"))
		_last_floor_result = ""
		_last_npc_feedback_result = {}
		if _message_label != null:
			_message_label.text = "AP 不足：进入此塔需要 %d AP。" % int(ap_result.get("cost", 0))
		hide()
		return ap_result
	_last_npc_feedback_result = _apply_npc_pre_tower_feedback()
	IntelServiceScript.new().apply(_game_state, "tower_intel", {"tower": _tower})
	_current_floor_index = _first_pending_floor()
	_last_return_reason = ""
	_last_floor_result = ""
	_last_battle_payload = {}
	_return_time_advanced = false
	_clear_active_overlay()
	_set_view("floor_select")
	_refresh()
	show()
	return {"ok": true, "reason": "ok", "cost": int(ap_result.get("cost", 0)), "remaining": int(_game_state.ap)}


func start_tower(tower, game_state = null) -> Dictionary:
	return open(tower, game_state)


func get_tower():
	return _tower


func get_current_floor_index() -> int:
	return _current_floor_index


func get_active_view_kind() -> String:
	return _active_view_kind


func get_active_battle_scene():
	return _active_battle_scene


func get_active_merchant():
	return _active_merchant


func get_last_battle_payload() -> Dictionary:
	return _last_battle_payload.duplicate(true)


func get_last_return_reason() -> String:
	return _last_return_reason


func get_last_floor_result() -> String:
	return _last_floor_result


func get_last_npc_feedback_result() -> Dictionary:
	return _last_npc_feedback_result.duplicate(true)


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func _try_spend_entry_ap() -> Dictionary:
	if _tower == null or _game_state == null:
		return {"ok": false, "reason": "missing_state", "cost": 0}
	return ApServiceScript.try_spend_tower(_game_state, str(_tower.size))


func get_event_choice_count() -> int:
	return _choice_payloads.size()


func enter_current_floor() -> void:
	enter_floor(_current_floor_index)


func enter_floor(floor_index: int) -> void:
	if _tower == null or floor_index < 0 or floor_index >= _tower.floors.size():
		return
	_current_floor_index = floor_index
	var floor = _tower.floors[floor_index]
	if str(floor.resolution) == "cleared":
		return
	floor_started.emit(floor)
	match str(floor.event_type):
		"battle", "elite", "boss":
			_start_battle_floor(floor)
		"merchant":
			_open_merchant_floor(floor)
		"event":
			_open_event_floor(floor)
		"shrine":
			_open_shrine_floor(floor)
		"unknown":
			_open_unknown_floor(floor)
		_:
			_clear_current_floor()


func handle_battle_result(result: Dictionary) -> void:
	if _tower == null:
		return
	var won: bool = str(result.get("outcome", "")) == "victory"
	var floor = _tower.floors[_current_floor_index] if _current_floor_index >= 0 and _current_floor_index < _tower.floors.size() else null
	var boss_text := ""
	if won and floor != null and str(floor.event_type) == "boss":
		boss_text = request_boss_victory_ai_gm(floor, result)
		if boss_text != "":
			floor.ai_gm_narrative = boss_text
	_clear_active_overlay()
	if _tower != null and bool(_tower.is_ritual_tower) and _is_ritual_contract_violation(result):
		_last_floor_result = "collapsed"
		PromotionRitualServiceScript.fail(_tower, _game_state)
		_return_to_hub("collapsed")
		return
	if won:
		_clear_current_floor()
		_show_runner_narration(boss_text)
		return
	if _tower != null and bool(_tower.is_ritual_tower):
		_last_floor_result = "collapsed"
		PromotionRitualServiceScript.fail(_tower, _game_state)
		_return_to_hub("collapsed")
		return
	_last_floor_result = _tower.on_floor_failed(_current_floor_index, _game_state)
	if _last_floor_result == "respawn":
		_message_label.text = "本层失败，失去 1 张临时卡并增加污染。可以重新挑战。"
		_set_view("floor_select")
		_refresh()
	else:
		_return_to_hub("collapsed")


func handle_merchant_closed() -> void:
	_clear_active_overlay()
	_clear_current_floor()


func choose_event_option(index: int) -> bool:
	if index < 0 or index >= _choice_payloads.size():
		return false
	var payload: Dictionary = _choice_payloads[index]
	var context: Dictionary = _dict(_choice_contexts[index]) if index < _choice_contexts.size() else {}
	_apply_outcome(payload)
	_emit_tower_event_resolved(context)
	_choice_payloads.clear()
	_choice_contexts.clear()
	_clear_current_floor()
	return true


func _apply_npc_pre_tower_feedback() -> Dictionary:
	var free_temp_cards: Array = []
	var rule_unlocks: Array = []
	var shop_discounts: Array = []
	var church_awareness_delta := 0
	var extra_elite_injected := false
	if _game_state == null or _tower == null:
		return {
			"free_temp_cards": free_temp_cards,
			"rule_unlocks": rule_unlocks,
			"shop_discounts": shop_discounts,
			"extra_elite_injected": extra_elite_injected,
			"church_awareness_delta": church_awareness_delta,
		}
	var library = NpcLibraryScript.new()
	library.load_all()
	var card_library = CardLibraryScript.new()
	var free_temp_card_used := false
	var rule_unlock_used := false
	for npc_id_value in library.all_ids():
		var npc_id := str(npc_id_value)
		if not _game_state.npc_relations.has(npc_id):
			continue
		var relation = _game_state.npc_relations[npc_id]
		var npc_def: Dictionary = library.get_definition(npc_id)
		var trust := _relation_int(relation, "trust", 0)
		var suspicion := _relation_int(relation, "suspicion", 0)
		for buff in _array(npc_def.get("buff_unlocks_on_trust", [])):
			if not buff is Dictionary or trust < int(buff.get("trust", 0)):
				continue
			var buff_type := str(buff.get("type", ""))
			var buff_payload: Dictionary = _dict(buff.get("payload", {}))
			match buff_type:
				"free_temp_card":
					if free_temp_card_used:
						continue
					var card_pool := str(buff_payload.get("card_pool", ""))
					var card = card_library.roll_from_pool(card_pool, _npc_feedback_seed())
					if card != null and _game_state.add_temp_card(card):
						free_temp_card_used = true
						free_temp_cards.append(str(card.template_id))
				"rule_unlock":
					if rule_unlock_used:
						continue
					var rule_id := str(buff_payload.get("rule_id", ""))
					if rule_id != "":
						if not _game_state.learned_rules.has(rule_id):
							_game_state.learned_rules.append(rule_id)
						rule_unlock_used = true
						rule_unlocks.append(rule_id)
				"shop_discount":
					var shop_id := str(buff_payload.get("shop_id", ""))
					var pct := int(buff_payload.get("pct", 0))
					var discount_result: Dictionary = ShopServiceScript.apply_discount(_game_state, shop_id, pct)
					if bool(discount_result.get("ok", false)):
						shop_discounts.append({"shop_id": shop_id, "pct": int(discount_result.get("pct", pct))})
		for debuff in _array(npc_def.get("debuff_triggers_on_suspicion", [])):
			if not debuff is Dictionary or suspicion < int(debuff.get("suspicion", 0)):
				continue
			var debuff_type := str(debuff.get("type", ""))
			var debuff_payload: Dictionary = _dict(debuff.get("payload", {}))
			match debuff_type:
				"tower_extra_elite":
					if extra_elite_injected:
						continue
					var chance := minf(maxf(float(debuff_payload.get("chance", 0.0)), 0.0), 0.30)
					if _npc_feedback_roll_under(npc_id, debuff_type, chance):
						var generator = TowerGeneratorScript.new()
						var elite_result: Dictionary = generator.inject_extra_elite_floor(_tower)
						extra_elite_injected = bool(elite_result.get("ok", false))
				"report_to_church":
					var delta := maxi(0, int(debuff_payload.get("church_awareness", 0)))
					if delta > 0:
						var before := int(_game_state.church_awareness)
						if _game_state.has_method("adjust_church_awareness"):
							_game_state.adjust_church_awareness(delta, "tower:%s:%s" % [str(_tower.tower_id), npc_id])
						else:
							_game_state.church_awareness = mini(100, before + delta)
						church_awareness_delta += int(_game_state.church_awareness) - before
	return {
		"free_temp_cards": free_temp_cards,
		"rule_unlocks": rule_unlocks,
		"shop_discounts": shop_discounts,
		"extra_elite_injected": extra_elite_injected,
		"church_awareness_delta": church_awareness_delta,
	}


func _relation_int(relation, field_name: String, default_value: int) -> int:
	if relation is Dictionary:
		return int(relation.get(field_name, default_value))
	if relation != null:
		var value = relation.get(field_name)
		if value != null:
			return int(value)
	return default_value


func _npc_feedback_seed() -> int:
	if _tower != null and _tower.theme_modifiers is Dictionary and _tower.theme_modifiers.has("npc_feedback_seed"):
		return int(_tower.theme_modifiers.get("npc_feedback_seed", 0))
	return 0


func _npc_feedback_roll_under(_npc_id: String, _trigger_type: String, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if _tower != null and _tower.theme_modifiers is Dictionary and _tower.theme_modifiers.has("npc_feedback_seed"):
		var value := absi(int(_tower.theme_modifiers.get("npc_feedback_seed", 0))) % 1000
		return (float(value) / 1000.0) < chance
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randf() < chance


func _build_ui() -> void:
	_root_panel = PanelContainer.new()
	_root_panel.name = "TowerRunnerPanel"
	_root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.05, 0.055, 0.97)
	_root_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_root_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_root_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_status_label = Label.new()
	header.add_child(_status_label)

	_narrative_label = Label.new()
	_narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_narrative_label)

	_intel_preview_label = Label.new()
	_intel_preview_label.name = "IntelPreviewLabel"
	_intel_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_intel_preview_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_floor_list = VBoxContainer.new()
	_floor_list.add_theme_constant_override("separation", 8)
	_floor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_floor_list)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var enter_button := Button.new()
	enter_button.text = "进入当前层"
	enter_button.pressed.connect(enter_current_floor)
	actions.add_child(enter_button)

	var flee_button := Button.new()
	flee_button.text = "撤出塔"
	flee_button.pressed.connect(_on_flee_pressed)
	actions.add_child(flee_button)

	_build_choice_panel()


func _build_choice_panel() -> void:
	_choice_panel = PanelContainer.new()
	_choice_panel.name = "ChoicePanel"
	_choice_panel.set_anchors_preset(Control.PRESET_CENTER)
	_choice_panel.custom_minimum_size = Vector2(520, 320)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.075, 0.07, 0.98)
	_choice_panel.add_theme_stylebox_override("panel", style)
	add_child(_choice_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_choice_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_choice_title = Label.new()
	_choice_title.add_theme_font_size_override("font_size", 18)
	root.add_child(_choice_title)

	_choice_body = Label.new()
	_choice_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_choice_body)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 8)
	root.add_child(_choice_box)
	_choice_panel.hide()


func _refresh() -> void:
	if _tower == null:
		_title_label.text = "Tower"
		_status_label.text = ""
		return
	_title_label.text = str(_tower.tower_name) if str(_tower.tower_name) != "" else "Tower"
	_status_label.text = "Floor %d/%d" % [_current_floor_index + 1, _tower.floors.size()]
	for child in _floor_list.get_children():
		child.queue_free()
	for i in range(_tower.floors.size()):
		var floor = _tower.floors[i]
		var button := Button.new()
		button.custom_minimum_size.y = 46
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "第 %d 层 | %s | %s" % [i + 1, str(floor.event_type), str(floor.resolution)]
		button.disabled = i != _current_floor_index or str(floor.resolution) == "cleared" or _active_view_kind != "floor_select"
		button.pressed.connect(_on_floor_button_pressed.bind(i))
		_floor_list.add_child(button)
	if _current_floor_index >= 0 and _current_floor_index < _tower.floors.size():
		var current = _tower.floors[_current_floor_index]
		_narrative_label.text = str(current.ai_gm_narrative)
	else:
		_narrative_label.text = ""
	_refresh_intel_preview()


func _on_floor_button_pressed(index: int) -> void:
	enter_floor(index)


func _refresh_intel_preview() -> void:
	if _intel_preview_label == null:
		return
	if _tower == null or _game_state == null:
		_intel_preview_label.text = ""
		_intel_preview_label.hide()
		return
	var texts: Array[String] = IntelServiceScript.new().matching_tower_intel_texts(_game_state, _tower, true)
	if texts.is_empty():
		_intel_preview_label.text = "情报：暂无"
	else:
		_intel_preview_label.text = "情报：\n%s" % "\n".join(texts)
	_intel_preview_label.visible = true


func _start_battle_floor(floor) -> void:
	_clear_active_overlay()
	if str(floor.event_type) == "boss" and _tower != null and str(_tower.theme_modifiers.get("mainline_node_id", "")) != "":
		var mainline_text := request_mainline_boss_ai_gm(floor, {"prior_choices": _mainline_prior_choices()})
		if mainline_text != "":
			floor.ai_gm_narrative = mainline_text
	var active_deck: Array = _active_deck_cards()
	if active_deck.is_empty():
		_last_battle_payload = {
			"floor_index": int(floor.floor_index),
			"event_type": str(floor.event_type),
			"blocked_reason": "empty_active_deck",
		}
		if _message_label != null:
			_message_label.text = "请先在塔罗书桌构筑卡组，再进入爬塔战斗。"
		_set_view("floor_select")
		return
	var scene = load(BattleScenePath)
	if scene == null or not scene.can_instantiate():
		_message_label.text = "BattleScene missing"
		return
	var enemy_ids: Array = _enemy_ids_for_floor(floor)
	var enemies: Array = _load_enemies(enemy_ids)
	var picked_cards: Array = _temp_picked_cards()
	var contract: Array[String] = _active_contract()
	var victory_drops: Dictionary = _victory_drops_for_floor(floor)
	_last_battle_payload = {
		"floor_index": int(floor.floor_index),
		"event_type": str(floor.event_type),
		"enemy_pack_id": str(floor.event_data.get("enemy_pack_id", "")),
		"enemy_ids": enemy_ids.duplicate(),
		"loaded_enemy_ids": _loaded_enemy_ids(enemies),
		"victory_drops": victory_drops.duplicate(true),
	}
	_active_battle_scene = scene.instantiate()
	_active_battle_scene.name = "BattleScene"
	add_child(_active_battle_scene)
	if _active_battle_scene.has_signal("battle_finished"):
		_active_battle_scene.battle_finished.connect(handle_battle_result)
	if _active_battle_scene.has_method("start_battle"):
		var battle_context := {
			"tower_district": str(_tower.district) if _tower != null else "",
			"time_of_day": str(_game_state.time_of_day) if _game_state != null else "",
		}
		_active_battle_scene.start_battle(active_deck, picked_cards, enemies, contract, null, _game_state, victory_drops, battle_context)
	_show_active_battle_narration(str(floor.ai_gm_narrative))
	_set_view("battle")


func _open_merchant_floor(floor) -> void:
	_clear_active_overlay()
	var scene = load(TowerMerchantPath)
	if scene == null or not scene.can_instantiate():
		_message_label.text = "TowerMerchant missing"
		return
	_active_merchant = scene.instantiate()
	_active_merchant.name = "TowerMerchant"
	add_child(_active_merchant)
	if _active_merchant.has_signal("merchant_closed"):
		_active_merchant.merchant_closed.connect(handle_merchant_closed)
	if _active_merchant.has_method("open"):
		_active_merchant.open(_game_state, _floor_id(floor))
	_set_view("merchant")


func _open_event_floor(floor) -> void:
	var choices: Array = []
	var raw_choices: Variant = floor.event_data.get("choices", [])
	if raw_choices is Array:
		for choice in raw_choices:
			if choice is Dictionary:
				choices.append(choice.duplicate(true))
	if choices.is_empty():
		choices.append({"id": "continue", "text": "继续", "outcome": {}})
	_open_choice_view("event", str(floor.event_data.get("title", "事件")), str(floor.event_data.get("narrative_template", "")), choices, {
		"event_id": str(floor.event_data.get("event_id", "")),
		"floor_index": int(floor.floor_index),
	})


func _open_shrine_floor(floor) -> void:
	var payload: Dictionary = _dict(floor.event_data.get("service_payload", {}))
	var title: String = str(floor.event_data.get("title", "神龛"))
	if title == "":
		title = "神龛"
	_open_choice_view("shrine", title, str(floor.event_data.get("description", "")), [
		{"id": "accept", "text": "接受", "outcome": payload},
	])


func _open_unknown_floor(floor) -> void:
	var choices: Array = []
	var table: Variant = floor.event_data.get("outcome_table", [])
	if table is Array:
		var index := 0
		for entry in table:
			if entry is Dictionary:
				choices.append({
					"id": str(entry.get("type", "unknown_%d" % index)),
					"text": _unknown_choice_text(str(entry.get("type", ""))),
					"outcome": _dict(entry.get("payload", {})),
				})
				index += 1
	if choices.is_empty():
		choices.append({"id": "skip", "text": "继续", "outcome": {}})
	_open_choice_view("unknown", "未知节点", "阴影后的结果尚未显形。", choices)


func _open_choice_view(kind: String, title: String, body: String, choices: Array, context: Dictionary = {}) -> void:
	_clear_active_overlay()
	_choice_payloads.clear()
	_choice_contexts.clear()
	for child in _choice_box.get_children():
		child.queue_free()
	_choice_title.text = title
	_choice_body.text = body
	for i in range(choices.size()):
		var choice: Dictionary = _dict(choices[i])
		_choice_payloads.append(_dict(choice.get("outcome", {})))
		var choice_context := context.duplicate(true)
		choice_context["kind"] = kind
		choice_context["choice_id"] = str(choice.get("id", ""))
		_choice_contexts.append(choice_context)
		var button := Button.new()
		button.text = str(choice.get("text", choice.get("id", "继续")))
		button.custom_minimum_size.y = 42
		button.pressed.connect(choose_event_option.bind(i))
		_choice_box.add_child(button)
	_choice_panel.show()
	_set_view(kind)


func _emit_tower_event_resolved(context: Dictionary) -> void:
	if str(context.get("kind", "")) != "event":
		return
	var event_id := str(context.get("event_id", ""))
	var choice_id := str(context.get("choice_id", ""))
	if event_id == "" or choice_id == "":
		return
	tower_event_resolved.emit(_tower, {
		"event_id": event_id,
		"choice_id": choice_id,
		"floor_index": int(context.get("floor_index", _current_floor_index)),
	})


func _clear_current_floor() -> void:
	if _tower == null or _current_floor_index < 0 or _current_floor_index >= _tower.floors.size():
		return
	var floor = _tower.floors[_current_floor_index]
	floor.resolution = "cleared"
	floor_cleared.emit(floor)
	_current_floor_index = _first_pending_floor()
	if _current_floor_index == -1:
		_complete_tower()
	else:
		var next_floor = _tower.floors[_current_floor_index]
		var narrative := request_tower_floor_transition_ai_gm(floor, next_floor)
		if narrative != "":
			next_floor.ai_gm_narrative = narrative
		_set_view("floor_select")
		_refresh()


func _complete_tower() -> void:
	if _tower != null:
		_tower.resolution = "cleared"
	if _tower != null and bool(_tower.is_ritual_tower) and _game_state != null:
		PromotionRitualServiceScript.complete(_tower, _game_state)
	var cycle_end_result: Dictionary = {}
	if _should_complete_cycle_on_tower():
		cycle_end_result = CycleEndServiceScript.complete_cycle(_game_state)
		if _tower != null:
			_tower.theme_modifiers["cycle_end_result"] = cycle_end_result
		_return_time_advanced = true
	if _game_state != null and _game_state.has_method("clear_temp_cards"):
		_game_state.clear_temp_cards()
	SaveStoreScript.auto_save(_game_state)
	tower_completed.emit(_tower)
	_return_to_hub("completed")


func _should_complete_cycle_on_tower() -> bool:
	if _tower == null or _game_state == null:
		return false
	if bool(_tower.theme_modifiers.get("cycle_end_on_complete", false)):
		return true
	var node_id := str(_tower.theme_modifiers.get("mainline_node_id", ""))
	return node_id == "node_6_final_tower" and _game_state.has_method("get_meta") and bool(_game_state.get_meta("cycle_end_ready", false))


func _return_to_hub(reason: String) -> void:
	_last_return_reason = reason
	if _tower != null and bool(_tower.is_ritual_tower) and _game_state != null:
		PromotionRitualServiceScript.restore_active_contract(_game_state)
	_advance_time_on_return()
	if reason == "collapsed":
		SaveStoreScript.auto_save(_game_state)
		tower_collapsed.emit(_tower)
	_set_view("returned")
	hide()
	returned_to_hub.emit(reason)


func _on_flee_pressed() -> void:
	if _tower == null:
		return
	if _tower.is_ritual_tower:
		_message_label.text = "仪式塔不可撤出。"
		return
	SaveStoreScript.auto_save(_game_state)
	_return_to_hub("fled")


func _set_view(kind: String) -> void:
	_active_view_kind = kind
	if _root_panel != null:
		_root_panel.visible = kind in ["floor_select", "event", "shrine", "unknown"]
	if _choice_panel != null and not (kind in ["event", "shrine", "unknown"]):
		_choice_panel.hide()
	_refresh()


func _show_active_battle_narration(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "" or _active_battle_scene == null:
		return
	if _active_battle_scene.has_method("show_ai_gm_narration"):
		_active_battle_scene.call("show_ai_gm_narration", clean)


func _show_runner_narration(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "" or _message_label == null:
		return
	_message_label.text = clean


func _clear_active_overlay() -> void:
	if is_instance_valid(_active_battle_scene):
		_active_battle_scene.queue_free()
	_active_battle_scene = null
	if is_instance_valid(_active_merchant):
		_active_merchant.queue_free()
	_active_merchant = null
	if _choice_panel != null:
		_choice_panel.hide()


func _first_pending_floor() -> int:
	if _tower == null:
		return -1
	for i in range(_tower.floors.size()):
		if str(_tower.floors[i].resolution) != "cleared":
			return i
	return -1


func _enemy_ids_for_floor(floor) -> Array:
	var result: Array = []
	var data: Dictionary = _dict(floor.event_data)
	if str(floor.event_type) == "boss":
		var boss_id: String = str(data.get("boss_id", ""))
		if boss_id != "":
			result.append(boss_id)
		var boss_pack: Variant = data.get("boss_pack", [])
		if boss_pack is Array:
			for id in boss_pack:
				result.append(str(id))
	else:
		var ids: Variant = data.get("enemy_ids", [])
		if ids is Array:
			for id in ids:
				result.append(str(id))
	if result.is_empty():
		result.append("drunkard")
	return result


func _load_enemies(enemy_ids: Array) -> Array:
	var library = EnemyLibraryScript.new()
	var result: Array = []
	for id in enemy_ids:
		var enemy = library.load_enemy(str(id))
		if enemy == null:
			enemy = _fallback_enemy(str(id))
		result.append(enemy)
	return result


func _fallback_enemy(id: String):
	var hp := 80 if id.find("boss") != -1 or id.find("horror") != -1 or id.find("captain") != -1 else 30
	return EnemyScript.from_json({
		"id": id,
		"display_name": id,
		"tier": 2 if hp >= 80 else 1,
		"stats": {"hp": hp, "max_hp": hp, "atk": 8, "def": 2, "spd": 8},
		"skills": [{"id": "strike", "damage": 8, "target": "single"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "strike"}],
	})


func _loaded_enemy_ids(enemies: Array) -> Array:
	var result: Array = []
	for enemy in enemies:
		if enemy != null:
			result.append(str(enemy.id))
	return result


func _active_deck_cards() -> Array:
	if _game_state == null:
		return []
	var cards: Array = []
	if _game_state.has_method("active_deck_cards"):
		cards = _game_state.active_deck_cards()
	return cards


func _temp_picked_cards() -> Array:
	if _game_state == null:
		return []
	var temp_cards = _game_state.get("temp_picked_cards")
	if temp_cards is Array:
		return temp_cards.duplicate()
	return []


func _active_contract() -> Array[String]:
	var result: Array[String] = []
	if _game_state == null:
		return result
	_ensure_active_contract_for_tower()
	var source: Array = []
	if _tower != null and bool(_tower.is_ritual_tower):
		var learned = _game_state.get("learned_rules")
		source = learned.duplicate() if learned is Array else []
	else:
		var active = _game_state.get("active_contract")
		source = active.duplicate() if active is Array else []
	for rule in source:
		result.append(str(rule))
	return result


func _ensure_active_contract_for_tower() -> void:
	if _game_state == null:
		return
	if _tower != null and bool(_tower.is_ritual_tower):
		return
	ContractPickerScript.new().ensure_contract_for_tower(_game_state)


func _is_ritual_contract_violation(result: Dictionary) -> bool:
	var contract: Dictionary = _dict(result.get("contract", {}))
	var outcome := str(contract.get("outcome", ""))
	return outcome == "partial" or outcome == "failed" or outcome == "broken"


func _victory_drops_for_floor(floor) -> Dictionary:
	var data: Dictionary = _dict(floor.event_data)
	if data.has("victory_drops"):
		return _dict(data.get("victory_drops", {}))
	return _dict(data.get("drop_table", {}))


func _floor_id(floor) -> String:
	var tower_id: String = str(_tower.tower_id) if _tower != null else "tower"
	return "%s::floor_%d" % [tower_id, int(floor.floor_index)]


func request_tower_floor_transition_ai_gm(prev_floor, next_floor) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "tower_floor_transition"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"tower_id": str(_tower.tower_id) if _tower != null else "",
		"floor_index": int(next_floor.floor_index) if next_floor != null else _current_floor_index,
		"prev_event_type": str(prev_floor.event_type) if prev_floor != null else "",
		"next_event_type": str(next_floor.event_type) if next_floor != null else "",
	}
	ctx.fallback_template_pool = "TOWER_TRANSITION_TEMPLATES"
	return _call_ai_gm(ctx)


func request_boss_victory_ai_gm(floor, result: Dictionary = {}) -> String:
	var contract: Dictionary = _dict(result.get("contract", {}))
	var ctx = PromptContextScript.new()
	ctx.scene = "boss_victory"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"boss_id": _boss_id_for_floor(floor),
		"district": str(_tower.district) if _tower != null else "",
		"brand_dropped": result.has("brand_drop") and result.get("brand_drop", null) != null,
		"contract_ratio": float(contract.get("ratio", 0.0)),
	}
	ctx.contract_state = _contract_state_from_result(contract)
	ctx.fallback_template_pool = "BOSS_VICTORY_TEMPLATES"
	return _call_ai_gm(ctx)


func request_mainline_boss_ai_gm(floor, options: Dictionary = {}) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "mainline_boss"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"node_id": str(_tower.theme_modifiers.get("mainline_node_id", "")) if _tower != null else "",
		"boss_id": _boss_id_for_floor(floor),
		"prior_choices": _array(options.get("prior_choices", _mainline_prior_choices())),
		"sequence": int(_game_state.sequence) if _game_state != null else 9,
	}
	ctx.fallback_template_pool = "MAINLINE_BOSS_TEMPLATES"
	return _call_ai_gm(ctx)


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


func _boss_id_for_floor(floor) -> String:
	if floor == null:
		return ""
	var data: Dictionary = _dict(floor.event_data)
	var boss_id := str(data.get("boss_id", ""))
	if boss_id != "":
		return boss_id
	var boss_pack: Array = _array(data.get("boss_pack", []))
	if not boss_pack.is_empty():
		return str(boss_pack[0])
	return ""


func _contract_state_from_result(contract: Dictionary) -> Dictionary:
	return {
		"active_contract": _array(contract.get("active_contract", [])),
		"last_resolve_ratio": float(contract.get("ratio", 0.0)),
		"satisfied_rules": _array(contract.get("satisfied_rules", [])),
		"violated_rules": _array(contract.get("violated_rules", [])),
	}


func _mainline_prior_choices() -> Array:
	if _game_state == null:
		return []
	var daodian: Variant = _game_state.daodian
	if daodian is Dictionary:
		return _array((daodian as Dictionary).get("completed_main_story_nodes", []))
	return []


func _apply_outcome(outcome: Dictionary) -> void:
	if _game_state == null:
		return
	if outcome.has("pollution"):
		_game_state.pollution += int(outcome.get("pollution", 0))
		_game_state.pollution_stage = _pollution_stage(int(_game_state.pollution))
	if outcome.has("lingstones"):
		_game_state.lingstones += int(outcome.get("lingstones", 0))
	if outcome.has("dao_pages"):
		_game_state.dao_pages += int(outcome.get("dao_pages", 0))
	if outcome.has("ap_loss"):
		var ap_loss := maxi(0, int(outcome.get("ap_loss", 0)))
		var spend_amount := mini(int(_game_state.ap), ap_loss)
		if spend_amount > 0:
			ApServiceScript.try_spend(_game_state, spend_amount, "tower_event_ap_loss")
	if outcome.has("material_id"):
		var material_id: String = str(outcome.get("material_id", ""))
		if material_id != "":
			var amount: int = int(outcome.get("material_amount", 1))
			_game_state.forge_materials[material_id] = int(_game_state.forge_materials.get(material_id, 0)) + amount
	if outcome.has("heal_amount") and _game_state.has_method("set_meta"):
		var heal_amount: int = int(outcome.get("heal_amount", 0))
		_game_state.set_meta("tower_pending_heal", int(_game_state.get_meta("tower_pending_heal", 0)) + heal_amount)
	if outcome.has("brand_enchant") and _game_state.has_method("set_meta"):
		_game_state.set_meta("tower_brand_enchant_pending", true)
	if outcome.has("forge_mini") and _game_state.has_method("set_meta"):
		_game_state.set_meta("tower_forge_mini_pending", true)


func _unknown_choice_text(kind: String) -> String:
	match kind:
		"trap":
			return "靠近"
		"loot":
			return "搜寻"
		"old_man":
			return "交谈"
		_:
			return "继续"


func _advance_time_on_return() -> void:
	if _return_time_advanced or _game_state == null:
		return
	_return_time_advanced = true
	TimeAdvanceServiceScript.advance_for_action(_game_state, "tower_return")


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


func _pollution_stage(value: int) -> int:
	if value >= 100:
		return 5
	if value >= 95:
		return 4
	if value >= 80:
		return 3
	if value >= 50:
		return 2
	if value >= 30:
		return 1
	return 0
