class_name DistrictSelect
extends Panel

signal city_scene_requested(district_id: String)

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")
const IdentityPickerScript = preload("res://scripts/world/identity_picker_dialog.gd")

const DEFAULT_LOCATION_DIR := "res://data/locations"
const CITY_SCENE_PATH := "res://scenes/world/city_scene.tscn"
const DISTRICT_ORDER := [
	"shadow_alley",
	"steelworks",
	"misty_port",
	"sacred_seven",
	"stone_tower",
	"ascetic_mountain",
]
const DISTRICT_DESCRIPTIONS := {
	"shadow_alley": "近邻熟人区。老李 / 小染 / 黑市。",
	"steelworks": "工厂区。失踪案的源头。",
	"misty_port": "黑市与水手。鳗鱼·凡的赌窟。",
	"sacred_seven": "教会大本营。礼拜 / 高怀疑度。",
	"stone_tower": "贵族旧塔与调查事件更常见。",
	"ascetic_mountain": "远途城区，钟摆相关委托高频。",
}

var _game_state = null
var _entries: Array = []
var _district_list: VBoxContainer
var _ap_label: Label
var _time_label: Label
var _message_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(game_state = null) -> void:
	_game_state = game_state if game_state != null else GameState
	_message_label.text = ""
	_refresh()
	show()


static func load_selector_entries(base_dir: String = DEFAULT_LOCATION_DIR) -> Array:
	var result: Array = []
	for i in range(DISTRICT_ORDER.size()):
		var district_id := str(DISTRICT_ORDER[i])
		var data := _load_location_data(district_id, base_dir)
		if data.is_empty():
			continue
		result.append(_entry_from_location(data, district_id, i))
	return result


static func selector_entries_for(game_state, base_dir: String = DEFAULT_LOCATION_DIR) -> Array:
	var entries := load_selector_entries(base_dir)
	var commission_map := _accepted_commission_map(game_state)
	var forced_tower := _forced_tower_for_state(game_state)
	var decorated: Array = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		var check := can_enter_entry(entry, game_state)
		var district_id := str(entry.get("district_id", ""))
		var commission: Dictionary = commission_map.get(district_id, {})
		var forced := _forced_tower_targets_district(forced_tower, district_id)
		entry["disabled"] = not bool(check.get("ok", false))
		entry["reason"] = str(check.get("reason", ""))
		entry["locked"] = str(check.get("reason", "")) == "locked"
		entry["unlock_text"] = _unlock_text_for(entry)
		entry["mainline_forced_marker"] = forced
		entry["mainline_forced_label"] = str(forced_tower.get("label", "主线")) if forced else ""
		entry["has_commission_marker"] = not commission.is_empty()
		entry["commission_id"] = str(commission.get("commission_id", ""))
		entry["commission_title"] = str(commission.get("commission_title", ""))
		decorated.append(entry)
	return _sort_entries(decorated)


static func can_enter_district(district_id: String, game_state) -> Dictionary:
	var entry := _entry_for_district_id(district_id)
	if entry.is_empty():
		return {"ok": false, "reason": "missing_district"}
	return can_enter_entry(entry, game_state)


static func can_enter_entry(entry: Dictionary, game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var unlock_condition: Variant = entry.get("unlock_condition", null)
	if unlock_condition != null:
		var condition := str(unlock_condition).strip_edges()
		if condition != "" and not HotspotResolverScript.evaluate_visible_when(condition, game_state):
			return {"ok": false, "reason": "locked", "unlock_text": _unlock_text_for(entry)}
	var district_id := str(entry.get("district_id", ""))
	var blocked_until := _district_blocked_until_day(game_state, district_id)
	if blocked_until >= int(game_state.day):
		return {"ok": false, "reason": "activity_blocked", "blocked_until_day": blocked_until}
	if district_id == "ascetic_mountain" and _ascetic_visited_today(game_state):
		return {"ok": false, "reason": "daily_remote_limit", "ap_cost": int(entry.get("ap_to_enter", 0))}
	var ap_cost := int(entry.get("ap_to_enter", 0))
	if int(game_state.ap) < ap_cost:
		return {"ok": false, "reason": "ap_short", "ap_cost": ap_cost}
	return {"ok": true, "reason": "ok", "ap_cost": ap_cost}


static func enter_district(district_id: String, game_state) -> Dictionary:
	var entry := _entry_for_district_id(district_id)
	if entry.is_empty():
		return {"ok": false, "reason": "missing_district"}
	var check := can_enter_entry(entry, game_state)
	if not bool(check.get("ok", false)):
		return check
	var ap_cost := int(entry.get("ap_to_enter", 0))
	var spend: Dictionary = ApServiceScript.try_spend(game_state, ap_cost, "district_entry")
	if not bool(spend.get("ok", false)):
		return spend
	game_state.current_district = district_id
	if district_id == "ascetic_mountain" and game_state.has_method("set_meta"):
		game_state.set_meta("ascetic_visited_today", true)
	return {
		"ok": true,
		"reason": "ok",
		"district_id": district_id,
		"scene_path": CITY_SCENE_PATH,
		"ap_cost": ap_cost,
	}


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.065, 0.075, 0.97)
	bg.border_color = Color(0.32, 0.36, 0.34, 1.0)
	bg.border_width_left = 1
	bg.border_width_top = 1
	bg.border_width_right = 1
	bg.border_width_bottom = 1
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
	title.name = "DistrictSelectTitle"
	title.text = "洞府前门 · 你今天去哪？"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_ap_label = Label.new()
	_ap_label.name = "ApLabel"
	header.add_child(_ap_label)

	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	header.add_child(_time_label)

	var divider := HSeparator.new()
	root.add_child(divider)

	_district_list = VBoxContainer.new()
	_district_list.name = "DistrictList"
	_district_list.add_theme_constant_override("separation", 8)
	_district_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_district_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_district_list)

	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)

	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = "取消"
	cancel.pressed.connect(_on_cancel_pressed)
	footer.add_child(cancel)


func _refresh() -> void:
	if _game_state == null:
		return
	_entries = selector_entries_for(_game_state)
	_ap_label.text = "AP: %d/%d" % [int(_game_state.ap), int(_game_state.ap_max)]
	_time_label.text = "第 %d 天 · %s" % [int(_game_state.day), _time_text(str(_game_state.time_of_day))]
	for child in _district_list.get_children():
		_district_list.remove_child(child)
		child.queue_free()
	for entry in _entries:
		if entry is Dictionary:
			_add_entry_button(entry)
			_add_entry_identity_buttons(entry)


func _add_entry_button(entry: Dictionary) -> void:
	var button := Button.new()
	var district_id := str(entry.get("district_id", ""))
	button.name = "DistrictRow_%s" % district_id
	button.text = _entry_button_text(entry)
	button.tooltip_text = _reason_text(str(entry.get("reason", "")), entry)
	button.disabled = bool(entry.get("disabled", false))
	button.custom_minimum_size.y = 58
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_district_pressed.bind(district_id))
	_district_list.add_child(button)


func _add_entry_identity_buttons(entry: Dictionary) -> void:
	if _game_state == null:
		return
	var district_id := str(entry.get("district_id", ""))
	if district_id == "":
		return
	var picker = IdentityPickerScript.new()
	var options: Array[String] = picker.options_for_location(district_id, _game_state)
	for identity_id in options:
		if identity_id == "" or identity_id == "harvey":
			continue
		var button := Button.new()
		button.name = "DistrictIdentityButton_%s_%s" % [district_id, identity_id]
		var display_name := _identity_display_name(identity_id)
		var selected := _selected_identity_matches(district_id, identity_id)
		button.text = "\u5df2\u9009\uff1a\u4ee5 %s \u8eab\u4efd\u51fa\u95e8" % display_name if selected else "\u4ee5 %s \u8eab\u4efd\u51fa\u95e8" % display_name
		button.tooltip_text = "\u8fdb\u5165 %s \u524d\u4f7f\u7528\u6b8b\u7559\u8eab\u4efd\uff1b\u8fdb\u57ce\u65f6\u4f1a\u6d88\u8017 1 \u6b21\u4f7f\u7528" % str(entry.get("display_name", district_id))
		button.disabled = bool(entry.get("disabled", false))
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_identity_pressed.bind(district_id, identity_id))
		_district_list.add_child(button)


func _entry_button_text(entry: Dictionary) -> String:
	var marker := "★ " if bool(entry.get("has_commission_marker", false)) else ""
	if bool(entry.get("mainline_forced_marker", false)):
		marker = "【主线】"
	var display_name := str(entry.get("display_name", entry.get("district_id", "")))
	var description := str(entry.get("description", ""))
	var ap_cost := int(entry.get("ap_to_enter", 0))
	var access_text := "城区漫游 0 AP" if ap_cost == 0 else "远途 %d AP" % ap_cost
	var status_text := "[进入] %s" % access_text
	if bool(entry.get("locked", false)):
		status_text = "锁定（%s）" % str(entry.get("unlock_text", "尚未解锁"))
	elif str(entry.get("reason", "")) == "ap_short":
		status_text = "AP 不足（%s）" % access_text
	elif str(entry.get("reason", "")) == "daily_remote_limit":
		status_text = "今日已往返"
	if bool(entry.get("mainline_forced_marker", false)):
		description = "%s · %s" % [str(entry.get("mainline_forced_label", "主线")), description]
	var commission_title := str(entry.get("commission_title", ""))
	if commission_title != "":
		description = "%s · %s" % [commission_title, description]
	return "%s%s    %s\n%s" % [marker, display_name, status_text, description]


func _on_district_pressed(district_id: String) -> void:
	_clear_mismatched_selected_identity(district_id)
	var result := enter_district(district_id, _game_state)
	if not bool(result.get("ok", false)):
		_message_label.text = _reason_text(str(result.get("reason", "")), _entry_for_district_id(district_id))
		_refresh()
		return
	if _game_state != null and _game_state.has_method("has_meta") and _game_state.has_meta("selected_identity_location_id"):
		_game_state.remove_meta("selected_identity_location_id")
	_message_label.text = ""
	hide()
	city_scene_requested.emit(district_id)


func _on_identity_pressed(district_id: String, identity_id: String) -> void:
	if _game_state == null or not _game_state.has_method("set_meta"):
		return
	var picker = IdentityPickerScript.new()
	if not picker.options_for_location(district_id, _game_state).has(identity_id):
		_message_label.text = "\u8be5\u8eab\u4efd\u5df2\u4e0d\u80fd\u7528\u4e8e\u8fd9\u4e2a\u57ce\u533a"
		_refresh()
		return
	_game_state.set_meta("selected_identity_id", identity_id)
	_game_state.set_meta("selected_identity_location_id", district_id)
	_message_label.text = "\u5df2\u9009\u62e9\uff1a\u4ee5 %s \u8eab\u4efd\u524d\u5f80 %s" % [_identity_display_name(identity_id), _district_display_name(district_id)]
	_refresh()


func _clear_mismatched_selected_identity(district_id: String) -> void:
	if _game_state == null or not _game_state.has_method("has_meta"):
		return
	var selected_location := str(_game_state.get_meta("selected_identity_location_id", ""))
	if selected_location == "" or selected_location == district_id:
		return
	for key in ["selected_identity_id", "selected_identity_location_id"]:
		if _game_state.has_meta(key):
			_game_state.remove_meta(key)


func _selected_identity_matches(district_id: String, identity_id: String) -> bool:
	if _game_state == null or not _game_state.has_method("has_meta"):
		return false
	return str(_game_state.get_meta("selected_identity_id", "")) == identity_id and str(_game_state.get_meta("selected_identity_location_id", "")) == district_id


func _identity_display_name(identity_id: String) -> String:
	if _game_state == null:
		return identity_id
	var identities: Variant = _game_state.get("residual_identities")
	if not identities is Array:
		return identity_id
	for raw_identity in identities:
		var raw_id := ""
		var raw_name := ""
		if raw_identity is Dictionary:
			var data: Dictionary = raw_identity
			raw_id = str(data.get("id", ""))
			raw_name = str(data.get("name", data.get("display_name", "")))
		elif raw_identity is Object and raw_identity.has_method("get"):
			raw_id = str(raw_identity.get("id"))
			raw_name = str(raw_identity.get("name"))
			if raw_name == "":
				raw_name = str(raw_identity.get("display_name"))
		if raw_id == identity_id:
			return raw_name if raw_name.strip_edges() != "" else identity_id
	return identity_id


func _district_display_name(district_id: String) -> String:
	var entry := _entry_for_district_id(district_id)
	return str(entry.get("display_name", district_id))


func _on_cancel_pressed() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		accept_event()


static func _entry_for_district_id(district_id: String) -> Dictionary:
	for entry in load_selector_entries():
		if entry is Dictionary and str(entry.get("district_id", "")) == district_id:
			return entry
	return {}


static func _entry_from_location(data: Dictionary, district_id: String, sort_order: int) -> Dictionary:
	return {
		"district_id": str(data.get("district_id", district_id)),
		"display_name": str(data.get("display_name", district_id)),
		"ap_to_enter": int(data.get("ap_to_enter", 0)),
		"unlock_condition": data.get("unlock_condition", null),
		"description": str(DISTRICT_DESCRIPTIONS.get(district_id, "")),
		"sort_order": sort_order,
	}


static func _load_location_data(district_id: String, base_dir: String = DEFAULT_LOCATION_DIR) -> Dictionary:
	var path := "%s/%s.json" % [base_dir, district_id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed.duplicate(true) if parsed is Dictionary else {}


static func _accepted_commission_map(game_state) -> Dictionary:
	var result: Dictionary = {}
	if game_state == null:
		return result
	var accepted_ids := _accepted_commission_ids(game_state)
	if accepted_ids.is_empty():
		return result
	var available: Array = _array_field(game_state, "available_commissions")
	for raw_commission in available:
		if not raw_commission is Dictionary:
			continue
		var commission_id := str(raw_commission.get("id", ""))
		if commission_id == "" or not commission_id in accepted_ids:
			continue
		var district_id := _commission_district_id(raw_commission)
		if district_id == "":
			continue
		result[district_id] = {
			"commission_id": commission_id,
			"commission_title": str(raw_commission.get("display_name", raw_commission.get("title", commission_id))),
		}
	return result


static func _accepted_commission_ids(game_state) -> Array:
	var result: Array = []
	for item in _array_field(game_state, "accepted_commissions"):
		if item is Dictionary:
			var dict_id := str(item.get("id", ""))
			if dict_id != "":
				result.append(dict_id)
		else:
			var id := str(item)
			if id != "":
				result.append(id)
	return result


static func _commission_district_id(commission: Dictionary) -> String:
	var dispatch: Variant = commission.get("dispatch_target", {})
	if dispatch is Dictionary:
		for key in ["district_id", "district", "target_district"]:
			var value := str(dispatch.get(key, ""))
			if value != "":
				return value
	for key in ["district_id", "district", "target_district"]:
		var direct := str(commission.get(key, ""))
		if direct != "":
			return direct
	return ""


static func _array_field(game_state, field_name: String) -> Array:
	if game_state == null:
		return []
	var raw: Variant = game_state.get(field_name)
	return raw.duplicate(true) if raw is Array else []


static func _forced_tower_for_state(game_state) -> Dictionary:
	if game_state != null and game_state.has_method("get_meta"):
		var value: Variant = game_state.get_meta("mainline_forced_tower", {})
		if value is Dictionary:
			return value.duplicate(true)
	return {}


static func _forced_tower_targets_district(forced_tower: Dictionary, district_id: String) -> bool:
	var district_ids: Variant = forced_tower.get("district_ids", [])
	if district_ids is Array:
		for id in district_ids:
			if str(id) == district_id:
				return true
	return false


static func _ascetic_visited_today(game_state) -> bool:
	if game_state == null or not game_state.has_method("get_meta"):
		return false
	return bool(game_state.get_meta("ascetic_visited_today", false))


static func _district_blocked_until_day(game_state, district_id: String) -> int:
	if game_state == null or district_id == "":
		return 0
	var modifiers: Variant = game_state.get("activity_modifiers")
	if not modifiers is Dictionary:
		return 0
	return int((modifiers as Dictionary).get("%s_blocked_until_day" % district_id, 0))


static func _sort_entries(entries: Array) -> Array:
	var sorted: Array = []
	for entry in entries:
		if not entry is Dictionary:
			continue
		var inserted := false
		for i in range(sorted.size()):
			if _entry_before(entry, sorted[i]):
				sorted.insert(i, entry)
				inserted = true
				break
		if not inserted:
			sorted.append(entry)
	return sorted


static func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	var a_forced := bool(a.get("mainline_forced_marker", false))
	var b_forced := bool(b.get("mainline_forced_marker", false))
	if a_forced != b_forced:
		return a_forced
	var a_marker := bool(a.get("has_commission_marker", false))
	var b_marker := bool(b.get("has_commission_marker", false))
	if a_marker != b_marker:
		return a_marker
	var a_ap := int(a.get("ap_to_enter", 0))
	var b_ap := int(b.get("ap_to_enter", 0))
	if a_ap != b_ap:
		return a_ap < b_ap
	return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))


static func _unlock_text_for(entry: Dictionary) -> String:
	var condition := str(entry.get("unlock_condition", "")).strip_edges()
	if condition == "" or condition == "<null>":
		return "起始可达"
	if condition.begins_with("sequence <= "):
		return "序列 %s 解锁" % condition.replace("sequence <= ", "").strip_edges()
	if condition.begins_with("mainline.") and condition.ends_with(".completed == true"):
		var parts := condition.split(".", false)
		if parts.size() >= 2:
			return "主线%s解锁" % _mainline_node_text(str(parts[1]))
	return "尚未解锁"


static func _mainline_node_text(node_id: String) -> String:
	match node_id:
		"node_1":
			return "第一节点"
		"node_2":
			return "第二节点"
		"node_3":
			return "第三节点"
		"node_4":
			return "第四节点"
		"node_5":
			return "第五节点"
		"node_6":
			return "第六节点"
		_:
			if node_id.begins_with("node_"):
				return node_id.replace("node_", "第") + "节点"
			return node_id


func _reason_text(reason: String, entry: Dictionary = {}) -> String:
	match reason:
		"locked":
			return str(entry.get("unlock_text", _unlock_text_for(entry)))
		"ap_short":
			return "AP 不足：需要 %d AP" % int(entry.get("ap_to_enter", 0))
		"daily_remote_limit":
			return "苦修山远途今日只能往返一次"
		"activity_blocked":
			return "该城区暂时拒绝进入"
		"missing_district":
			return "城区数据缺失"
		"missing_state":
			return "状态缺失"
		_:
			return ""


func _time_text(time_id: String) -> String:
	match time_id:
		"morning":
			return "白天"
		"noon":
			return "正午"
		"evening":
			return "黄昏"
		"night":
			return "夜晚"
		_:
			return time_id
