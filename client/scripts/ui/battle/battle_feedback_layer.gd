class_name BattleFeedbackLayer
extends PanelContainer

const MAX_VISIBLE_EVENTS := 6

var _selected_card_label: Label
var _recent_action_label: Label
var _events_box: VBoxContainer
var _event_texts: Array[String] = []


func _init() -> void:
	name = "BattleFeedbackLayer"
	_ensure_ui()


func _ready() -> void:
	_ensure_ui()
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(0, 24)


func max_visible_events() -> int:
	return MAX_VISIBLE_EVENTS


func bind_state(selected_text: String, recent_action_text: String, battle_log_entries: Array = [], effect_results: Array = []) -> void:
	_ensure_ui()
	var clean_selected := selected_text.strip_edges()
	_selected_card_label.text = "Selected: %s" % (clean_selected if clean_selected != "" else "none")
	var clean_recent := recent_action_text.strip_edges()
	_recent_action_label.text = "Recent: %s" % (clean_recent if clean_recent != "" else "none")

	_event_texts.clear()
	for raw_result in _last_values(effect_results, MAX_VISIBLE_EVENTS):
		if raw_result is Dictionary:
			var event: Dictionary = raw_result
			_append_event_text(_text_for_effect_result(event))
	for raw_log in _last_values(battle_log_entries, 2):
		var log_text := str(raw_log).strip_edges()
		if log_text != "":
			_append_event_text("Log: %s" % log_text)
	_redraw_event_labels()


func push_event(event: Dictionary) -> void:
	_ensure_ui()
	_append_event_text(_text_for_event(event))
	_redraw_event_labels()


func event_label_count() -> int:
	_ensure_ui()
	return _events_box.get_child_count()


func _ensure_ui() -> void:
	if _events_box != null:
		return
	custom_minimum_size = Vector2(0, 24)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_FILL

	var margin := MarginContainer.new()
	margin.name = "BattleFeedbackMargin"
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	var body := HBoxContainer.new()
	body.name = "BattleFeedbackBody"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_FILL
	margin.add_child(body)

	var state_column := VBoxContainer.new()
	state_column.name = "BattleFeedbackStateColumn"
	state_column.add_theme_constant_override("separation", 0)
	state_column.custom_minimum_size = Vector2(160, 0)
	state_column.size_flags_vertical = Control.SIZE_FILL
	body.add_child(state_column)

	var selected_rail := PanelContainer.new()
	selected_rail.name = "SelectedCardRail"
	selected_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_column.add_child(selected_rail)
	var selected_margin := MarginContainer.new()
	selected_margin.add_theme_constant_override("margin_left", 6)
	selected_margin.add_theme_constant_override("margin_top", 3)
	selected_margin.add_theme_constant_override("margin_right", 6)
	selected_margin.add_theme_constant_override("margin_bottom", 3)
	selected_rail.add_child(selected_margin)
	_selected_card_label = Label.new()
	_selected_card_label.name = "SelectedCardLabel"
	_selected_card_label.clip_text = true
	_selected_card_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selected_margin.add_child(_selected_card_label)

	_recent_action_label = Label.new()
	_recent_action_label.name = "RecentActionLabel"
	_recent_action_label.clip_text = true
	_recent_action_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_recent_action_label.max_lines_visible = 1
	state_column.add_child(_recent_action_label)

	_events_box = VBoxContainer.new()
	_events_box.name = "FeedbackEventList"
	_events_box.add_theme_constant_override("separation", 0)
	_events_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events_box.size_flags_vertical = Control.SIZE_FILL
	body.add_child(_events_box)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12)
	style.border_color = Color(0.34, 0.40, 0.48)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)


func _append_event_text(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	_event_texts.append(clean)
	while _event_texts.size() > MAX_VISIBLE_EVENTS:
		_event_texts.pop_front()


func _redraw_event_labels() -> void:
	for child in _events_box.get_children():
		_events_box.remove_child(child)
		child.queue_free()
	if _event_texts.is_empty():
		return
	var label := Label.new()
	label.name = "FeedbackEventLabel0"
	label.text = " | ".join(_event_texts)
	label.max_lines_visible = 1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_events_box.add_child(label)


func _text_for_event(event: Dictionary) -> String:
	var event_type := str(event.get("type", event.get("reason", "")))
	match event_type:
		"card_played":
			return "Card: %s" % str(event.get("card_name", event.get("card", "")))
		"damage":
			return "%s took %d damage" % [str(event.get("target", "target")), int(event.get("amount", event.get("damage", 0)))]
		"defense_change", "block", "defense_shredded", "defense_broken":
			if event.has("before") or event.has("after"):
				return "%s DEF %d -> %d" % [str(event.get("target", "target")), int(event.get("before", 0)), int(event.get("after", 0))]
			return "Defense changed %s" % str(event.get("magnitude", event.get("amount", "")))
		"status_applied", "conditional_status_applied":
			var status_text := str(event.get("status", event.get("applied_status", ""))).strip_edges()
			return "Status applied%s" % (": %s" % status_text if status_text != "" else "")
		"target_selection_registered":
			return "Target selection %d-%d" % [int(event.get("min", 0)), int(event.get("max", 0))]
		"intent_revealed_by_card":
			return "Intent shown %d" % int(event.get("target_count", 0))
		"brand_triggered", "brand_next_turn_replay_scheduled", "brand_next_turn_replay_resolved", "brand_delayed_card_effect_scheduled", "brand_delayed_card_effect_resolved":
			return "Brand effect resolved"
		"summary":
			return str(event.get("text", ""))
		_:
			var text := str(event.get("text", event.get("message", ""))).strip_edges()
			if text != "":
				return text
			return "Effect resolved"


func _text_for_effect_result(result: Dictionary) -> String:
	var reason := str(result.get("reason", ""))
	match reason:
		"defense_shredded", "defense_broken":
			return "Defense changed %s" % str(result.get("magnitude", ""))
		"status_applied", "conditional_status_applied":
			return "Status applied"
		"damage_reduction_triggered":
			return "Damage reduced %d" % int(result.get("prevented_damage", 0))
		"counter_spell_triggered", "dodge_counter_triggered":
			return "Counter %d" % int(result.get("damage", 0))
		"target_selection_registered":
			return "Target selection %d-%d" % [int(result.get("min", 0)), int(result.get("max", 0))]
		"intent_revealed_by_card":
			return "Intent shown %d" % int(result.get("target_count", 0))
		"marker_added":
			return "Marker +%d" % int(result.get("added", result.get("count", 1)))
		"field_marker_added":
			return "Field marker +%d" % int(result.get("added", result.get("count", 1)))
		"charged":
			return "Charged"
		"charge_payload_resolved":
			return "Charge resolved"
		"brand_triggered", "brand_next_turn_replay_scheduled", "brand_next_turn_replay_resolved", "brand_delayed_card_effect_scheduled", "brand_delayed_card_effect_resolved":
			return "Brand effect resolved"
		_:
			return "Effect resolved"


func _last_values(values: Array, limit: int) -> Array:
	var result: Array = []
	var start := maxi(0, values.size() - limit)
	for i in range(start, values.size()):
		result.append(values[i])
	return result
