class_name CommissionBoard
extends Panel

const CommissionActionServiceScript = preload("res://scripts/world/commission_action_service.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")

const DEFAULT_COMMISSIONS := [
	{
		"id": "runner_job",
		"title": "跑腿活",
		"description": "影巷里有人托你跑一趟短差。",
		"includes_tower": false,
		"tower_size": "",
	},
	{
		"id": "tower_patrol",
		"title": "巡塔委托",
		"description": "有人想让你进塔确认一处异常。",
		"includes_tower": true,
		"tower_size": "small",
	},
]

const COMMISSION_COPY := {
	"commission_rumor_delivery_001": {"title": "暗号传话", "description": "阿杜让你把一条街头暗号送到该送的人手里。"},
	"commission_moonlight_grass_001": {"title": "月光草采集", "description": "去合适的夜路采一束能入药的月光草。"},
	"commission_factory_shift_001": {"title": "工厂打工", "description": "替铸钢区的工厂顶一班短工。"},
	"commission_steelworks_missing_001": {"title": "铸钢失踪案", "description": "去铸钢区查一桩不见人的委托。"},
	"commission_misty_port_smuggle_001": {"title": "雾港货单", "description": "替雾港的走私者核对一批货单和去向。"},
	"commission_misty_port_casino_intro_001": {"title": "赌窟探路", "description": "先去鳗鱼·凡的赌窟摸一遍门路。"},
	"commission_church_cover_001": {"title": "教堂掩护", "description": "在教会区替人打个掩护，别让人起疑。"},
	"commission_confession_practice_001": {"title": "告解演练", "description": "按告解室的规矩练一遍说辞。"},
	"commission_stone_tower_salon_001": {"title": "石塔沙龙", "description": "进贵族沙龙前先把礼数练熟。"},
	"commission_stone_garden_errand_001": {"title": "花园跑腿", "description": "替石塔区的园丁跑一趟小差。"},
	"commission_red_hand_probe_001": {"title": "红手会探查", "description": "暗中摸一摸红手会的活动痕迹。"},
	"commission_ascetic_trade_001": {"title": "苦修山换货", "description": "把山里的货和山下的货对一遍。"},
	"commission_reflection_halfmoon_001": {"title": "倒影半月线索", "description": "顺着倒影留下的半月线索往下查。"},
	"commission_halfmoon_message_001": {"title": "半月密信", "description": "把一封半月之约的密信送到指定地点。"},
	"commission_shadow_well_inquiry_001": {"title": "影井问询", "description": "去影巷旧井边问一问那桩旧事。"},
	"commission_old_li_letter_001": {"title": "老李的信", "description": "替老李把一封信送到该送的人手上。"},
	"commission_main_black_market_intro_001": {"title": "黑市引线", "description": "沿着影巷夜里的线索走进黑市。"},
	"commission_main_halfmoon_contact_001": {"title": "半月接触", "description": "与半月之约的关键人物碰一次面。"},
	"commission_main_promotion_prepare_001": {"title": "晋升准备", "description": "为晋升仪式准备必要的条件。"},
	"commission_main_final_prepare_001": {"title": "最终准备", "description": "把最后一段路铺平，准备进入终局。"},
}

var _game_state = null
var _service = CommissionServiceScript.new()
var _list: VBoxContainer
var _status_label: Label
var _ap_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	hide()


func open(game_state = null) -> void:
	_game_state = game_state if game_state != null else GameState
	_ensure_available_commissions()
	_status_label.text = "选择一项委托。"
	_refresh()
	show()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.075, 0.075, 0.085, 0.96)
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
	title.name = "CommissionTitleLabel"
	title.text = "告示牌"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_ap_label = Label.new()
	header.add_child(_ap_label)

	var hint := Label.new()
	hint.name = "CommissionHintLabel"
	hint.text = "每日会刷新委托。接下后去对应城区、塔、演练或邂逅路线执行，完成后回到这里交差领奖。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.name = "CommissionList"
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_status_label = Label.new()
	_status_label.name = "CommissionStatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)

	var leave := Button.new()
	leave.name = "CommissionCloseButton"
	leave.text = "关闭"
	leave.pressed.connect(_on_leave_pressed)
	buttons.add_child(leave)


func _ensure_available_commissions() -> void:
	if _game_state == null:
		return
	if not _game_state.available_commissions.is_empty():
		return
	var result: Dictionary = _service.refresh_daily(_game_state)
	if bool(result.get("ok", false)):
		return
	for entry in DEFAULT_COMMISSIONS:
		_game_state.available_commissions.append(entry.duplicate(true))


func _refresh() -> void:
	if _game_state == null:
		return
	_ap_label.text = "AP %d/%d" % [int(_game_state.ap), int(_game_state.ap_max)]
	var visible_ids: Array[String] = []
	for commission in _visible_commissions():
		var commission_id := str(commission.get("id", ""))
		if commission_id == "":
			continue
		visible_ids.append(commission_id)
		var row = _list.get_node_or_null("CommissionRow_%s" % commission_id)
		if row == null:
			_add_commission_row(commission)
		else:
			_update_commission_row(commission_id)
	for child in _list.get_children():
		if str(child.name).begins_with("CommissionRow_"):
			var row_id := str(child.name).trim_prefix("CommissionRow_")
			if not row_id in visible_ids:
				child.queue_free()


func _visible_commissions() -> Array:
	var by_id: Dictionary = {}
	for commission in _game_state.available_commissions:
		if commission is Dictionary:
			by_id[str(commission.get("id", ""))] = commission.duplicate(true)
	for id in _game_state.accepted_commissions:
		if not by_id.has(str(id)):
			by_id[str(id)] = _fallback_commission(str(id))
	for id in _game_state.completed_commissions:
		if not by_id.has(str(id)):
			by_id[str(id)] = _fallback_commission(str(id))
	var result: Array = []
	for key in by_id.keys():
		if key != "":
			result.append(by_id[key])
	result.sort_custom(_sort_commission_dicts)
	return result


static func _sort_commission_dicts(a: Dictionary, b: Dictionary) -> bool:
	var a_main := str(a.get("main_story_hook", "")) != ""
	var b_main := str(b.get("main_story_hook", "")) != ""
	if a_main != b_main:
		return a_main
	var a_priority := int(a.get("refresh_priority", 1000))
	var b_priority := int(b.get("refresh_priority", 1000))
	if a_priority != b_priority:
		return a_priority < b_priority
	return str(a.get("id", "")) < str(b.get("id", ""))


func _add_commission_row(commission: Dictionary) -> void:
	var commission_id := str(commission.get("id", ""))
	if commission_id == "":
		return
	var row := PanelContainer.new()
	row.name = "CommissionRow_%s" % commission_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(row)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text_box)

	var title := Label.new()
	title.name = "CommissionTitle_%s" % commission_id
	title.text = _commission_display_name(commission)
	text_box.add_child(title)

	var modifier_badge := Label.new()
	modifier_badge.name = "CommissionModifierBadge_%s" % commission_id
	modifier_badge.text = _modifier_badge_text(commission)
	modifier_badge.visible = modifier_badge.text != ""
	modifier_badge.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36, 1.0))
	text_box.add_child(modifier_badge)

	var desc := Label.new()
	desc.name = "CommissionDescription_%s" % commission_id
	desc.text = _commission_description(commission)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(desc)

	var state := Label.new()
	state.name = "CommissionStateLabel_%s" % commission_id
	state.text = _state_text(commission_id)
	box.add_child(state)

	var action := Button.new()
	action.name = "CommissionActionButton_%s" % commission_id
	action.text = _action_text(commission_id)
	action.disabled = _action_disabled(commission_id)
	action.pressed.connect(_on_action_pressed.bind(commission_id))
	box.add_child(action)

	var reject := Button.new()
	reject.name = "CommissionRejectButton_%s" % commission_id
	reject.text = "拒绝"
	reject.disabled = _reject_disabled(commission_id)
	reject.pressed.connect(_on_reject_pressed.bind(commission_id))
	box.add_child(reject)


func _update_commission_row(commission_id: String) -> void:
	var row = _list.get_node_or_null("CommissionRow_%s" % commission_id)
	if row == null:
		return
	var commission := _commission_by_id(commission_id)
	var title = row.find_child("CommissionTitle_%s" % commission_id, true, false)
	if title is Label:
		title.text = _commission_display_name(commission)
	var desc = row.find_child("CommissionDescription_%s" % commission_id, true, false)
	if desc is Label:
		desc.text = _commission_description(commission)
	var modifier_badge = row.find_child("CommissionModifierBadge_%s" % commission_id, true, false)
	if modifier_badge is Label:
		modifier_badge.text = _modifier_badge_text(commission)
		modifier_badge.visible = modifier_badge.text != ""
	var state = row.find_child("CommissionStateLabel_%s" % commission_id, true, false)
	if state is Label:
		state.text = _state_text(commission_id)
	var action = row.find_child("CommissionActionButton_%s" % commission_id, true, false)
	if action is Button:
		action.text = _action_text(commission_id)
		action.disabled = _action_disabled(commission_id)
	var reject = row.find_child("CommissionRejectButton_%s" % commission_id, true, false)
	if reject is Button:
		reject.disabled = _reject_disabled(commission_id)


func _on_action_pressed(commission_id: String) -> void:
	if _is_legacy_commission(commission_id):
		_on_legacy_action_pressed(commission_id)
		return
	if commission_id in _game_state.completed_commissions:
		_status_label.text = "这项委托已经交差。"
	elif _commission_status(commission_id) == "completed":
		_claim_commission(commission_id)
	elif commission_id in _game_state.accepted_commissions:
		_execute_commission(commission_id)
	else:
		_accept_commission(commission_id)
	_refresh()


func _on_legacy_action_pressed(commission_id: String) -> void:
	if commission_id in _game_state.completed_commissions:
		_status_label.text = "这项委托已经交差。"
	elif _pending_commission_id() == commission_id:
		_complete_commission(commission_id)
	elif commission_id in _game_state.accepted_commissions:
		_execute_commission(commission_id)
	else:
		_accept_commission(commission_id)
	_refresh()


func _on_reject_pressed(commission_id: String) -> void:
	if _is_legacy_commission(commission_id):
		_remove_visible_commission(commission_id)
		_status_label.text = "已拒绝：%s" % _commission_title(commission_id)
		_refresh()
		return
	var result: Dictionary = _service.reject(_game_state, commission_id)
	_status_label.text = "已拒绝：%s" % _commission_title(commission_id) if bool(result.get("ok", false)) else _reason_text(str(result.get("reason", "")))
	_refresh()


func _accept_commission(commission_id: String) -> Dictionary:
	if _game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if _is_legacy_commission(commission_id):
		if commission_id in _game_state.completed_commissions:
			_status_label.text = "这项委托已经交差。"
			return {"ok": false, "reason": "already_completed"}
		if not commission_id in _game_state.accepted_commissions:
			_game_state.accepted_commissions.append(commission_id)
		_status_label.text = "已接受：%s" % _commission_title(commission_id)
		_refresh()
		return {"ok": true, "reason": "ok", "commission_id": commission_id}
	var result: Dictionary = _service.accept(_game_state, commission_id)
	_status_label.text = "已接受：%s" % _commission_title(commission_id) if bool(result.get("ok", false)) else _reason_text(str(result.get("reason", "")))
	_refresh()
	return result


func _execute_commission(commission_id: String) -> Dictionary:
	if _is_legacy_commission(commission_id):
		var commission: Dictionary = _commission_by_id(commission_id)
		var legacy_result: Dictionary = CommissionActionServiceScript.execute_placeholder(
			_game_state,
			commission_id,
			bool(commission.get("includes_tower", false)),
			str(commission.get("tower_size", ""))
		)
		_status_label.text = "已派发：%s" % _commission_title(commission_id) if bool(legacy_result.get("ok", false)) else _reason_text(str(legacy_result.get("reason", "")))
		_refresh()
		return legacy_result
	var result: Dictionary = _service.execute(_game_state, commission_id, {"auto_resolve": false})
	if bool(result.get("ok", false)):
		_status_label.text = "已派发：%s（%s）" % [_commission_title(commission_id), _dispatch_kind_text(str(result.get("dispatch_kind", "")))]
	else:
		_status_label.text = _reason_text(str(result.get("reason", "")))
	_refresh()
	return result


func _complete_commission(commission_id: String) -> Dictionary:
	var result: Dictionary = CommissionActionServiceScript.complete_placeholder(_game_state, commission_id)
	if bool(result.get("ok", false)):
		_status_label.text = "已完成：获得 %d 序列经验" % int(result.get("sequence_exp_delta", 0))
	else:
		_status_label.text = _reason_text(str(result.get("reason", "")))
	_refresh()
	return result


func _claim_commission(commission_id: String) -> Dictionary:
	var result: Dictionary = _service.claim(_game_state, commission_id)
	_status_label.text = "已交差：%s" % _commission_title(commission_id) if bool(result.get("ok", false)) else _reason_text(str(result.get("reason", "")))
	_refresh()
	return result


func _pending_commission_id() -> String:
	if _game_state == null or not _game_state.has_method("get_meta"):
		return ""
	return str(_game_state.get_meta("commission_pending_completion", ""))


func _state_text(commission_id: String) -> String:
	if commission_id in _game_state.completed_commissions:
		return "已完成"
	if _is_legacy_commission(commission_id):
		if _pending_commission_id() == commission_id:
			return "待交差"
		if commission_id in _game_state.accepted_commissions:
			return "已接"
		return "可接"
	match _commission_status(commission_id):
		"accepted", "in_progress":
			return "已接"
		"completed":
			return "待交差"
		"expired":
			return "逾期"
		"claimed":
			return "已完成"
		_:
			return "可接"


func _action_text(commission_id: String) -> String:
	if commission_id in _game_state.completed_commissions:
		return "已完成"
	if _is_legacy_commission(commission_id):
		if _pending_commission_id() == commission_id:
			return "完成"
		if commission_id in _game_state.accepted_commissions:
			return "执行"
		return "接受"
	match _commission_status(commission_id):
		"completed":
			return "交差"
		"accepted", "in_progress":
			return "执行"
		"expired", "claimed":
			return "已完成"
		_:
			return "接受"


func _action_disabled(commission_id: String) -> bool:
	if commission_id in _game_state.completed_commissions:
		return true
	var status := _commission_status(commission_id)
	return status == "expired" or status == "claimed"


func _reject_disabled(commission_id: String) -> bool:
	if _is_legacy_commission(commission_id):
		return commission_id in _game_state.accepted_commissions or commission_id in _game_state.completed_commissions
	var commission := _commission_by_id(commission_id)
	return str(commission.get("main_story_hook", "")) != "" or commission_id in _game_state.accepted_commissions or commission_id in _game_state.completed_commissions


func _commission_by_id(commission_id: String) -> Dictionary:
	for commission in _game_state.available_commissions:
		if commission is Dictionary and str(commission.get("id", "")) == commission_id:
			return commission.duplicate(true)
	return _fallback_commission(commission_id)


func _commission_status(commission_id: String) -> String:
	return str(_commission_by_id(commission_id).get("status", "available"))


func _commission_title(commission_id: String) -> String:
	return _commission_display_name(_commission_by_id(commission_id))


func _commission_display_name(commission: Dictionary) -> String:
	var id := str(commission.get("id", ""))
	if COMMISSION_COPY.has(id):
		return str((COMMISSION_COPY[id] as Dictionary).get("title", id))
	var display_name := str(commission.get("display_name", ""))
	if display_name != "" and _has_cjk(display_name):
		return display_name
	var title := str(commission.get("title", id))
	if _has_cjk(title):
		return title
	return "委托"


func _commission_description(commission: Dictionary) -> String:
	var lines: Array[String] = [_base_commission_description(commission)]
	var modifier_text := str(commission.get("modifier_display_text", ""))
	if modifier_text != "":
		lines.append("\u8bcd\u6761\uff1a%s" % modifier_text)
	var effects: Dictionary = commission.get("modifier_effects", {}) if commission.get("modifier_effects", {}) is Dictionary else {}
	var reward_multiplier := float(effects.get("reward_multiplier", 1.0))
	if reward_multiplier > 1.0:
		lines.append("\u5956\u52b1\u500d\u7387\uff1a%.2f" % reward_multiplier)
	return "\n".join(lines)


func _modifier_badge_text(commission: Dictionary) -> String:
	return str(commission.get("modifier_display_text", "")).strip_edges()


func _base_commission_description(commission: Dictionary) -> String:
	var id := str(commission.get("id", ""))
	if COMMISSION_COPY.has(id):
		return str((COMMISSION_COPY[id] as Dictionary).get("description", ""))
	var description := str(commission.get("description", ""))
	if _has_cjk(description):
		return description
	match str(commission.get("commission_type", "")):
		"battle":
			return "进入指定城区处理一场战斗委托。"
		"investigate":
			return "去指定地点调查线索，完成后回来交差。"
		"perform":
			return "按委托人的要求完成一次行动。"
		"drill":
			return "完成一次演练，再回来交差。"
		_:
			return "完成这项委托后回到告示牌交差。"


func _dispatch_kind_text(kind: String) -> String:
	match kind:
		"battle":
			return "战斗"
		"gather":
			return "采集"
		"investigate":
			return "调查"
		"perform":
			return "行动"
		"drill":
			return "演练"
		"tower":
			return "进塔"
		_:
			return "委托路线"


func _reason_text(reason: String) -> String:
	match reason:
		"missing_state":
			return "状态缺失，暂时不能处理委托。"
		"already_completed":
			return "这项委托已经交差。"
		"already_accepted":
			return "这项委托已经接下。"
		"not_accepted":
			return "先接下委托，再执行。"
		"not_completed":
			return "委托还没有完成。"
		"expired":
			return "委托已经逾期。"
		"ap_short":
			return "AP 不足。"
		_:
			if reason.strip_edges() == "":
				return "委托暂时不能处理。"
			return "委托暂时不能处理：%s" % reason


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _fallback_commission(commission_id: String) -> Dictionary:
	for entry in DEFAULT_COMMISSIONS:
		if str(entry.get("id", "")) == commission_id:
			return entry.duplicate(true)
	var template = _service.get_library().get_template(commission_id)
	if template != null and template.has_method("to_dict") and not template.is_empty():
		return template.to_dict()
	return {
		"id": commission_id,
		"title": "委托",
		"description": "完成这项委托后回到告示牌交差。",
		"includes_tower": false,
		"tower_size": "",
	}


func _is_legacy_commission(commission_id: String) -> bool:
	var commission := _commission_by_id(commission_id)
	return not commission.has("commission_type") or str(commission.get("commission_type", "")) == ""


func _remove_visible_commission(commission_id: String) -> void:
	var next: Array = []
	for commission in _game_state.available_commissions:
		if commission is Dictionary and str(commission.get("id", "")) == commission_id:
			continue
		next.append(commission)
	_game_state.available_commissions = next


func _on_leave_pressed() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_leave_pressed()
		accept_event()
