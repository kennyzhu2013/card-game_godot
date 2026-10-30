class_name BattleResultOverlay
extends PanelContainer

signal reward_chosen(rewards: Array, index: int)

const BattleCardViewScript = preload("res://scripts/ui/battle/battle_card_view.gd")

var _root_box: VBoxContainer
var _title_label: Label
var _summary_label: Label
var _contract_label: Label
var _drop_label: Label
var _reward_box: VBoxContainer
var _reward_row: HBoxContainer
var _narrative_label: Label
var _rewards: Array = []


func _init() -> void:
	name = "BattleResultOverlay"
	_ensure_ui()
	visible = false


func _ready() -> void:
	_ensure_ui()
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(760, 420)


func reward_box() -> VBoxContainer:
	_ensure_ui()
	return _reward_box


func show_rewards(rewards: Array, summary_text: String = "", narrative_text: String = "") -> void:
	_ensure_ui()
	_rewards = rewards.duplicate()
	_clear_reward_choices()
	visible = true
	_title_label.text = "胜利"
	_summary_label.text = summary_text if summary_text.strip_edges() != "" else "选择 1 张临时卡"
	_summary_label.visible = true
	_contract_label.text = ""
	_contract_label.visible = false
	_drop_label.text = ""
	_drop_label.visible = false
	_set_narrative(narrative_text)
	_reward_box.visible = true
	for i in range(mini(3, _rewards.size())):
		_add_reward_choice(_rewards[i], i)
	var skip := Button.new()
	skip.name = "SkipRewardButton"
	skip.text = "跳过"
	skip.focus_mode = Control.FOCUS_ALL
	skip.custom_minimum_size = Vector2(96, 48)
	skip.pressed.connect(_emit_reward_choice.bind(-1))
	_reward_box.add_child(skip)


func show_result(result: Dictionary, summary_text: String = "") -> void:
	_ensure_ui()
	_clear_reward_choices()
	_reward_box.visible = false
	visible = true
	var outcome := str(result.get("outcome", ""))
	_title_label.text = "败北" if outcome == "defeat" else "胜利"
	_summary_label.text = summary_text if summary_text.strip_edges() != "" else _result_summary_text(result)
	_summary_label.visible = _summary_label.text.strip_edges() != ""
	_contract_label.text = _contract_text(result.get("contract", {}))
	_contract_label.visible = _contract_label.text.strip_edges() != ""
	_drop_label.text = _drop_text(result)
	_drop_label.visible = _drop_label.text.strip_edges() != ""
	_set_narrative(_narrative_text(result))


func narrative_text() -> String:
	_ensure_ui()
	return _narrative_label.text


func _ensure_ui() -> void:
	if _root_box != null:
		return
	custom_minimum_size = Vector2(760, 420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.075, 0.09, 0.96)
	style.border_color = Color(0.48, 0.54, 0.62)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "BattleResultMargin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	_root_box = VBoxContainer.new()
	_root_box.name = "BattleResultBody"
	_root_box.add_theme_constant_override("separation", 8)
	_root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_root_box)

	_title_label = Label.new()
	_title_label.name = "BattleResultTitle"
	_title_label.add_theme_font_size_override("font_size", 22)
	_root_box.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.name = "BattleResultSummaryLabel"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_summary_label)

	_contract_label = Label.new()
	_contract_label.name = "BattleResultContractLabel"
	_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_contract_label)

	_drop_label = Label.new()
	_drop_label.name = "BattleResultDropLabel"
	_drop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_drop_label)

	_reward_box = VBoxContainer.new()
	_reward_box.name = "RewardBox"
	_reward_box.add_theme_constant_override("separation", 8)
	_reward_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_reward_box)

	_reward_row = HBoxContainer.new()
	_reward_row.name = "RewardChoiceRow"
	_reward_row.add_theme_constant_override("separation", 8)
	_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reward_box.add_child(_reward_row)

	var narrative_panel := PanelContainer.new()
	narrative_panel.name = "BattleNarrativeRail"
	narrative_panel.custom_minimum_size = Vector2(0, 72)
	narrative_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(narrative_panel)
	var narrative_margin := MarginContainer.new()
	narrative_margin.add_theme_constant_override("margin_left", 8)
	narrative_margin.add_theme_constant_override("margin_top", 6)
	narrative_margin.add_theme_constant_override("margin_right", 8)
	narrative_margin.add_theme_constant_override("margin_bottom", 6)
	narrative_panel.add_child(narrative_margin)
	_narrative_label = Label.new()
	_narrative_label.name = "BattleNarrativeLabel"
	_narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrative_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	narrative_margin.add_child(_narrative_label)


func _add_reward_choice(card, index: int) -> void:
	var choice := VBoxContainer.new()
	choice.name = "RewardChoice%d" % index
	choice.add_theme_constant_override("separation", 6)
	choice.custom_minimum_size = Vector2(148, 186)
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reward_row.add_child(choice)

	var card_view = BattleCardViewScript.new()
	card_view.custom_minimum_size = Vector2(132, 136)
	card_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_view.bind_card(card, _card_cost(card), _card_summary(card), "", _card_tooltip(card), false, null)
	card_view.pressed.connect(_on_reward_card_pressed.bind(index))
	choice.add_child(card_view)

	var choose := Button.new()
	choose.name = "RewardChooseButton%d" % index
	choose.text = "选择"
	choose.focus_mode = Control.FOCUS_ALL
	choose.custom_minimum_size = Vector2(96, 48)
	choose.pressed.connect(_emit_reward_choice.bind(index))
	choice.add_child(choose)


func _clear_reward_choices() -> void:
	if _reward_row != null:
		for child in _reward_row.get_children():
			_reward_row.remove_child(child)
			child.queue_free()
	if _reward_box != null:
		for child in _reward_box.get_children():
			if child == _reward_row:
				continue
			_reward_box.remove_child(child)
			child.queue_free()


func _on_reward_card_pressed(_card, index: int) -> void:
	_emit_reward_choice(index)


func _emit_reward_choice(index: int) -> void:
	reward_chosen.emit(_rewards, index)


func _set_narrative(text: String) -> void:
	var clean := text.strip_edges()
	_narrative_label.text = clean
	_narrative_label.visible = clean != ""


func _narrative_text(result: Dictionary) -> String:
	var lines: Array[String] = []
	var ai_gm_text := str(result.get("ai_gm_text", "")).strip_edges()
	if ai_gm_text != "":
		lines.append(ai_gm_text)
	var contract: Dictionary = result.get("contract", {}) if result.get("contract", {}) is Dictionary else {}
	var violation_text := str(contract.get("violation_ai_gm_text", "")).strip_edges()
	if violation_text != "" and violation_text != ai_gm_text:
		lines.append(violation_text)
	return "\n".join(lines)


func _result_summary_text(result: Dictionary) -> String:
	var outcome := str(result.get("outcome", ""))
	if outcome == "defeat":
		return "战斗失败"
	if result.get("selected_card", null) != null:
		return "已选择奖励：%s" % _card_name(result.get("selected_card"))
	return "战斗胜利"


func _contract_text(raw_contract: Variant) -> String:
	if not raw_contract is Dictionary:
		return ""
	var contract: Dictionary = raw_contract
	if contract.is_empty():
		return ""
	var parts: Array[String] = []
	var outcome := str(contract.get("outcome", ""))
	if outcome != "":
		parts.append("契约：%s" % _contract_outcome_label(outcome))
	if contract.has("tier"):
		parts.append("阶层 %s" % str(contract.get("tier")))
	if contract.has("pollution_delta"):
		var delta := int(contract.get("pollution_delta", 0))
		parts.append("污染 %s%d" % ["+" if delta >= 0 else "", delta])
	if contract.has("acting_check_difficulty"):
		parts.append("判定 %d" % int(contract.get("acting_check_difficulty", 0)))
	return " / ".join(parts)


func _drop_text(result: Dictionary) -> String:
	var lines: Array[String] = []
	if result.get("selected_card", null) != null:
		lines.append("奖励：%s" % _card_name(result.get("selected_card")))
	if result.get("brand_drop", null) != null:
		lines.append("BOSS 烙印：%s" % _card_name(result.get("brand_drop")))
	if int(result.get("sequence_exp_delta", 0)) != 0:
		lines.append("序列经验 +%d" % int(result.get("sequence_exp_delta", 0)))
	if int(result.get("weather_pollution_delta", 0)) != 0:
		var delta := int(result.get("weather_pollution_delta", 0))
		lines.append("天气污染 %s%d" % ["+" if delta >= 0 else "", delta])
	return "\n".join(lines)


func _contract_outcome_label(outcome: String) -> String:
	match outcome:
		"full":
			return "完整"
		"partial":
			return "部分"
		"broken":
			return "破契"
		"failed":
			return "失败"
		"no_contract":
			return "无"
		_:
			return outcome


func _card_cost(card) -> int:
	if card is Dictionary:
		return int((card as Dictionary).get("energy_cost", 0))
	if card != null:
		return int(card.energy_cost)
	return 0


func _card_name(card) -> String:
	if card == null:
		return ""
	if card is Dictionary:
		return str((card as Dictionary).get("display_name", ""))
	if card.has_method("get_display_name"):
		return str(card.call("get_display_name"))
	var display_name := str(card.get("display_name"))
	if display_name != "":
		return display_name
	return str(card)


func _card_summary(card) -> String:
	if card != null and card.has_method("effect_summary_text"):
		return str(card.call("effect_summary_text")).strip_edges()
	return ""


func _card_tooltip(card) -> String:
	var lines: Array[String] = [_card_name(card)]
	var summary := _card_summary(card)
	if summary != "":
		lines.append(summary)
	return "\n".join(lines)
