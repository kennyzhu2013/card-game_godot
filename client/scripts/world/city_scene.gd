class_name CityScene
extends Control

signal hotspot_selected(hotspot)
signal return_to_hub_requested
signal force_sleep_requested

const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")
const TimeAdvanceServiceScript = preload("res://scripts/world/time_advance_service.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const R20EffectEngineScript = preload("res://scripts/world/r20_effect_engine.gd")
const ChantButtonFactoryScript = preload("res://scripts/world/chant_button_factory.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")
const FieldOpportunityServiceScript = preload("res://scripts/world/field_opportunity_service.gd")
const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")
const ArtManifestScript = preload("res://scripts/art_manifest.gd")

const DEFAULT_LOCATION_DIR := "res://data/locations"
const LEGACY_DISTRICT_DATA := "res://data/districts/district_data.json"
const HOTSPOT_BUTTON_SCENE := "res://scenes/world/hotspot_button.tscn"

var _game_state = null
var _district_data: Dictionary = {}
var _hotspot_button_scene: PackedScene = null
var _npc_library = null
var _r20_chant_panel: HBoxContainer
var _intel_info_dialog: AcceptDialog
var _r20_feedback_dialog: AcceptDialog
var _ai_gm_service = null
var _active_daily_opportunity_id := ""
var _active_daily_opportunity_district_id := ""

@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _background: TextureRect = $Background
@onready var _time_overlay: ColorRect = $TimeOverlay
@onready var _fog_overlay: ColorRect = $FogOverlay
@onready var _interaction_surface: Control = $UILayer/RootMargin
@onready var _hotspot_layer: Control = $UILayer/RootMargin/Root/Scroll/HotspotLayer
@onready var _topbar: Control = $UILayer/RootMargin/Root/TopBar
@onready var _district_label: Label = $UILayer/RootMargin/Root/TopBar/DistrictNameLabel
@onready var _day_label: Label = $UILayer/RootMargin/Root/TopBar/DayLabel
@onready var _time_label: Label = $UILayer/RootMargin/Root/TopBar/TimeLabel
@onready var _ap_label: Label = $UILayer/RootMargin/Root/TopBar/ApLabel
@onready var _lingstones_label: Label = $UILayer/RootMargin/Root/TopBar/LingstonesLabel
var _intel_info_button: Button
var _church_awareness_label: Label
var _r20_atmosphere_label: Label
@onready var _return_button: Button = $UILayer/RootMargin/Root/Footer/ReturnButton
@onready var _time_advance_button: Button = $UILayer/RootMargin/Root/Footer/TimeAdvanceButton
@onready var _encounter_trigger: Node = $EncounterTrigger
@onready var _encounter_runner: Control = $UILayer/EncounterRunner


func _ready() -> void:
	_hotspot_button_scene = load(HOTSPOT_BUTTON_SCENE)
	if _return_button != null and not _return_button.pressed.is_connected(_on_return_pressed):
		_return_button.pressed.connect(_on_return_pressed)
	if _time_advance_button != null and not _time_advance_button.pressed.is_connected(_on_time_advance_pressed):
		_time_advance_button.pressed.connect(_on_time_advance_pressed)
	_setup_church_awareness_label()
	_setup_r20_atmosphere_label()
	_setup_intel_info_button()
	_setup_r20_chant_panel()
	_connect_encounter_runner()
	_connect_encounter_trigger()
	_apply_time_overlay()
	_sync_ui_layer_visibility()
	_raise_encounter_runner()


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_ui_layer_visibility()


func _sync_ui_layer_visibility() -> void:
	if _ui_layer == null:
		_ui_layer = get_node_or_null("UILayer") as CanvasLayer
	if _ui_layer == null:
		return
	_ui_layer.visible = visible
	_ui_layer.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED


func _raise_encounter_runner() -> void:
	if _ui_layer == null:
		_ui_layer = get_node_or_null("UILayer") as CanvasLayer
	if _encounter_runner == null:
		_encounter_runner = get_node_or_null("UILayer/EncounterRunner") as Control
	if _ui_layer == null or _encounter_runner == null:
		return
	if _encounter_runner.get_parent() == _ui_layer:
		_ui_layer.move_child(_encounter_runner, _ui_layer.get_child_count() - 1)
	_encounter_runner.mouse_filter = Control.MOUSE_FILTER_STOP
	_encounter_runner.z_index = 1000
	_connect_encounter_runner()


func _connect_encounter_runner() -> void:
	if _encounter_runner == null:
		_encounter_runner = get_node_or_null("UILayer/EncounterRunner") as Control
	if _encounter_runner == null or not _encounter_runner.has_signal("encounter_resolved"):
		return
	if not _encounter_runner.encounter_resolved.is_connected(_on_encounter_resolved):
		_encounter_runner.encounter_resolved.connect(_on_encounter_resolved)


func _connect_encounter_trigger() -> void:
	if _encounter_trigger == null:
		_encounter_trigger = get_node_or_null("EncounterTrigger")
	if _encounter_trigger == null or not _encounter_trigger.has_signal("encounter_triggered"):
		return
	if not _encounter_trigger.encounter_triggered.is_connected(_on_encounter_triggered):
		_encounter_trigger.encounter_triggered.connect(_on_encounter_triggered)


func open_district(district_id: String, game_state = null) -> Dictionary:
	var data := load_district_data(district_id)
	if data.is_empty():
		return {"ok": false, "reason": "missing_district"}
	open_from_data(data, game_state)
	return {"ok": true, "district_id": district_id}


func open_from_data(district_data: Dictionary, game_state = null) -> void:
	_game_state = game_state if game_state != null else GameState
	_district_data = district_data.duplicate(true)
	_clear_active_daily_opportunity()
	set_interaction_surface_visible(true)
	_apply_district_background()
	_apply_district_bgm()
	_update_topbar()
	_apply_time_overlay()
	_render_hotspots()
	_configure_encounter_trigger()
	show()
	_sync_ui_layer_visibility()
	_raise_encounter_runner()


static func load_district_data(district_id: String, base_dir: String = DEFAULT_LOCATION_DIR) -> Dictionary:
	var path := "%s/%s.json" % [base_dir, district_id]
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed.duplicate(true)
	return _legacy_district_to_location(district_id)


func _render_hotspots() -> void:
	_clear_r20_chant_buttons()
	_clear_side_chain_buttons()
	for child in _hotspot_layer.get_children():
		_hotspot_layer.remove_child(child)
		child.queue_free()
	_ensure_daily_field_opportunities()
	_add_daily_district_opportunity_button()
	_add_available_side_chain_buttons()
	var hotspots: Variant = _district_data.get("hotspots", [])
	if not hotspots is Array:
		return
	for hotspot in _hotspots_with_dynamic_npc_presence(hotspots):
		if not hotspot is Dictionary:
			continue
		var effective_hotspot := _apply_npc_city_presence(hotspot)
		if not bool(effective_hotspot.get("_city_presence_applied", false)):
			effective_hotspot = _apply_hotspot_time_modifier(effective_hotspot)
		effective_hotspot.erase("_city_presence_applied")
		effective_hotspot = _apply_mainline_forced_tower(effective_hotspot)
		effective_hotspot = _apply_commission_marker(effective_hotspot)
		if effective_hotspot.has("visible") and not bool(effective_hotspot.get("visible", true)):
			continue
		var visible_when: Variant = effective_hotspot.get("visible_when", "always")
		if not HotspotResolverScript.evaluate_visible_when(visible_when, _game_state):
			if _should_show_locked_hotspot(effective_hotspot):
				_add_hotspot_button(effective_hotspot, true, _locked_hotspot_hint(effective_hotspot, visible_when))
			continue
		_add_hotspot_button(effective_hotspot)


func _add_daily_district_opportunity_button() -> void:
	var opportunity_service = FieldOpportunityServiceScript.new()
	var district_id := str(_district_data.get("district_id", ""))
	var entries: Array[Dictionary] = []
	for opportunity in _visible_daily_district_opportunities():
		if not opportunity is Dictionary:
			continue
		var entry: Dictionary = opportunity
		var opportunity_id := str(entry.get("id", ""))
		if opportunity_id == "":
			continue
		if opportunity_service.encounter_for_district_opportunity(_game_state, district_id, opportunity_id) == null:
			continue
		entries.append(entry.duplicate(true))
	if entries.is_empty() or _hotspot_layer == null:
		return
	var panel := PanelContainer.new()
	panel.name = "DailyOpportunityPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hotspot_layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.name = "DailyOpportunityList"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(body)
	var title := Label.new()
	title.name = "DailyOpportunityTitle"
	title.text = "\u4eca\u65e5\u673a\u4f1a\uff1a%d \u5904\u53ef\u67e5" % entries.size()
	title.add_theme_font_size_override("font_size", 14)
	body.add_child(title)
	for entry in entries:
		var opportunity_id := str(entry.get("id", ""))
		var display_name := opportunity_service.player_title_for_opportunity(entry)
		var hotspot := {
			"id": "daily_district_opportunity_%s" % opportunity_id,
			"label": "\u4eca\u65e5\u673a\u4f1a\uff1a%s" % display_name,
			"icon": "!",
			"type": "district_opportunity",
			"ap_cost": _daily_opportunity_ap_cost(entry),
			"payload": {"opportunity_id": opportunity_id},
			"visible_when": "always",
		}
		var button := Button.new()
		button.name = "DistrictOpportunityButton_%s" % opportunity_id
		button.text = _hotspot_text(hotspot)
		button.tooltip_text = opportunity_service.player_tooltip_for_opportunity(entry)
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_hotspot_pressed.bind(hotspot.duplicate(true)))
		body.add_child(button)


func _clear_side_chain_buttons() -> void:
	if _topbar == null:
		return
	for child in _topbar.find_children("SideChainButton_*", "Button", false, false):
		if child is Button:
			_topbar.remove_child(child)
			child.queue_free()


func _add_available_side_chain_buttons() -> void:
	if _game_state == null or _topbar == null:
		return
	var used_chains: Array[String] = []
	for encounter in _available_side_chain_encounters():
		var chain_id := str(encounter.get("chain_id"))
		if chain_id == "" or used_chains.has(chain_id):
			continue
		used_chains.append(chain_id)
		var title := _side_chain_display_name(chain_id, encounter)
		var button := Button.new()
		button.name = "SideChainButton_%s" % chain_id
		button.text = "\u652f\u7ebf\uff1a%s" % title
		button.tooltip_text = "\u906d\u9047\uff1a%s\n\u70b9\u51fb\u8fdb\u5165\u8fd9\u6761\u652f\u7ebf\u7684\u5f53\u524d\u6b65\u9aa4\u3002" % title
		button.custom_minimum_size.y = 48
		button.pressed.connect(_on_side_chain_pressed.bind(encounter))
		_topbar.add_child(button)


func _available_side_chain_encounters() -> Array:
	var result: Array = []
	var pool = EncounterPoolScript.new()
	var all: Array = pool.load_all()
	var ctx := {
		"district_id": str(_district_data.get("district_id", "")),
		"time_of_day": str(_game_state.time_of_day),
		"game_state": _game_state,
	}
	for encounter in pool.filter_candidates(all, ctx):
		if encounter == null:
			continue
		if str(encounter.get("chain_id")) == "":
			continue
		result.append(encounter)
	return result


func _on_side_chain_pressed(encounter) -> void:
	if encounter == null or _game_state == null:
		return
	_raise_encounter_runner()
	if _encounter_runner != null and _encounter_runner.has_method("start"):
		_encounter_runner.start(encounter, _game_state)


func _side_chain_display_name(chain_id: String, encounter) -> String:
	match chain_id:
		"widow_child_chain":
			return "\u5be1\u5987\u4e0e\u5b69\u5b50"
		"reflection_chain":
			return "\u5012\u5f71\u604b\u4eba"
		"red_hand_chain":
			return "\u7ea2\u624b\u4f1a\u63a5\u89e6"
		"pendulum_chain":
			return "\u949f\u6446\u771f\u540d"
	var title := str(encounter.get("display_name", "")).strip_edges() if encounter != null else ""
	if title != "" and _has_cjk(title):
		return title
	return "\u652f\u7ebf\u5f02\u52a8"


func _daily_opportunity_ap_cost(entry: Dictionary) -> int:
	var cost: Variant = entry.get("cost", {})
	if cost is Dictionary:
		return int((cost as Dictionary).get("ap", entry.get("ap_cost", 0)))
	return int(entry.get("ap_cost", 0))


func _daily_district_opportunity_entry() -> Dictionary:
	var district_id := str(_district_data.get("district_id", ""))
	for opportunity in _visible_daily_district_opportunities():
		if not opportunity is Dictionary:
			continue
		var entry: Dictionary = opportunity
		var opportunity_id := str(entry.get("id", ""))
		if opportunity_id == "":
			continue
		if FieldOpportunityServiceScript.new().encounter_for_district_opportunity(_game_state, district_id, opportunity_id) != null:
			return entry.duplicate(true)
	return {}


func _hotspots_with_dynamic_npc_presence(base_hotspots: Array) -> Array:
	var result := base_hotspots.duplicate(true)
	if _game_state == null:
		return result
	var district_id := str(_district_data.get("district_id", ""))
	var current_time := str(_game_state.time_of_day)
	if district_id == "" or current_time == "":
		return result
	var existing_npc_ids: Array[String] = []
	var used_hotspot_ids: Array[String] = []
	for hotspot in result:
		if not hotspot is Dictionary:
			continue
		var entry: Dictionary = hotspot
		var hotspot_id := str(entry.get("id", ""))
		if hotspot_id != "" and not used_hotspot_ids.has(hotspot_id):
			used_hotspot_ids.append(hotspot_id)
		if str(entry.get("type", "")) != "npc":
			continue
		var payload: Variant = entry.get("payload", {})
		if not payload is Dictionary:
			continue
		var npc_id := str((payload as Dictionary).get("npc_id", ""))
		if npc_id != "" and not existing_npc_ids.has(npc_id):
			existing_npc_ids.append(npc_id)
	for npc_id in _all_npc_ids():
		if npc_id == "" or existing_npc_ids.has(npc_id):
			continue
		var npc_def := _npc_definition(npc_id)
		if npc_def.is_empty() or bool(npc_def.get("placeholder", false)):
			continue
		var presence := _matching_presence(npc_def, district_id, current_time)
		if presence.is_empty():
			continue
		var dynamic_hotspot := _dynamic_npc_presence_hotspot(npc_id, npc_def, presence, used_hotspot_ids)
		if dynamic_hotspot.is_empty():
			continue
		result.append(dynamic_hotspot)
		existing_npc_ids.append(npc_id)
		used_hotspot_ids.append(str(dynamic_hotspot.get("id", "")))
	return result


func _all_npc_ids() -> Array[String]:
	if _npc_library == null:
		_npc_library = NpcLibraryScript.new()
	var ids: Array[String] = []
	for raw_id in _npc_library.all_ids():
		var npc_id := str(raw_id)
		if npc_id != "":
			ids.append(npc_id)
	return ids


func _matching_presence(npc_def: Dictionary, district_id: String, time_id: String) -> Dictionary:
	var raw_presence: Variant = npc_def.get("city_presence", [])
	if not raw_presence is Array:
		return {}
	for entry in raw_presence:
		if not entry is Dictionary:
			continue
		var presence: Dictionary = entry
		if str(presence.get("district", "")) != district_id:
			continue
		if str(presence.get("time_of_day", "")) != time_id:
			continue
		return presence.duplicate(true)
	return {}


func _dynamic_npc_presence_hotspot(npc_id: String, npc_def: Dictionary, presence: Dictionary, used_ids: Array[String]) -> Dictionary:
	var hotspot_id := "npc_%s" % npc_id
	if used_ids.has(hotspot_id):
		var index := 2
		while used_ids.has("%s_%d" % [hotspot_id, index]):
			index += 1
		hotspot_id = "%s_%d" % [hotspot_id, index]
	var hotspot := {
		"id": hotspot_id,
		"label": str(npc_def.get("display_name", npc_id)),
		"icon": str(presence.get("icon", "N")),
		"type": "npc",
		"ap_cost": int(presence.get("ap_cost", 0)),
		"payload": {"npc_id": npc_id},
		"visible_when": str(presence.get("visible_when", "always")),
		"position_norm": presence.get("position_norm", [0.5, 0.5]),
		"dynamic_presence": true,
		"_dynamic_npc_presence": true,
		"_city_presence_applied": true,
	}
	_apply_npc_presence_patch(hotspot, presence)
	return hotspot


func _add_hotspot_button(hotspot: Dictionary, locked: bool = false, locked_hint: String = "") -> void:
	var button: Button = null
	if _hotspot_button_scene != null and _hotspot_button_scene.can_instantiate():
		var instance = _hotspot_button_scene.instantiate()
		if instance is Button:
			button = instance
	if button == null:
		button = Button.new()
	button.name = "Hotspot_%s" % str(hotspot.get("id", "unknown"))
	button.text = _hotspot_text(hotspot)
	button.tooltip_text = _hotspot_tooltip(hotspot)
	button.disabled = locked or not bool(hotspot.get("interactable", true))
	if locked:
		var hint := locked_hint if locked_hint != "" else "暂未开放"
		button.text = "%s（%s）" % [button.text, hint]
		button.tooltip_text = "%s\n%s" % [button.tooltip_text, hint]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 48
	_fill_hotspot_button_labels(button, hotspot)
	button.pressed.connect(_on_hotspot_pressed.bind(hotspot.duplicate(true)))
	_hotspot_layer.add_child(button)
	if bool(hotspot.get("commission_marker", false)):
		_hotspot_layer.move_child(button, 0)


func _fill_hotspot_button_labels(button: Button, hotspot: Dictionary) -> void:
	var icon_label = button.find_child("IconLabel", true, false)
	if icon_label is Label:
		icon_label.text = _safe_icon(str(hotspot.get("icon", "")))
	var name_label = button.find_child("NameLabel", true, false)
	if name_label is Label:
		name_label.text = _hotspot_name_text(hotspot)
	var ap_label = button.find_child("ApLabel", true, false)
	if ap_label is Label:
		ap_label.text = "%d AP" % int(hotspot.get("ap_cost", 0))
	var status_dot = button.find_child("StatusDot", true, false)
	if status_dot is Label:
		if bool(hotspot.get("commission_marker", false)) or _hotspot_is_main_story(hotspot):
			status_dot.text = "!"
		else:
			status_dot.text = "*" if bool(hotspot.get("interactable", true)) else "-"


func _hotspot_text(hotspot: Dictionary) -> String:
	var icon := _safe_icon(str(hotspot.get("icon", "")))
	var label := _hotspot_name_text(hotspot)
	var ap_cost := int(hotspot.get("ap_cost", 0))
	if icon == "":
		return "%s | AP %d" % [label, ap_cost]
	return "%s %s | AP %d" % [icon, label, ap_cost]


func _hotspot_name_text(hotspot: Dictionary) -> String:
	var label := str(hotspot.get("label", hotspot.get("id", "")))
	if bool(hotspot.get("commission_marker", false)) and label.find("\u59d4\u6258") < 0:
		return "[\u59d4\u6258] %s" % label
	if _hotspot_is_main_story(hotspot) and label.find("\u4e3b\u7ebf") < 0:
		return "[\u4e3b\u7ebf] %s" % label
	if _hotspot_is_daily_opportunity_anchor(hotspot):
		return "%s\n\u4eca\u65e5\u673a\u4f1a" % label
	return label


func _hotspot_is_main_story(hotspot: Dictionary) -> bool:
	if bool(hotspot.get("mainline_forced", false)):
		return true
	if str(hotspot.get("type", "")) == "main_story":
		return true
	var payload := _dictionary_from(hotspot.get("payload", {}))
	return str(payload.get("mainline_hook_id", "")) != "" or str(payload.get("mainline_node_id", "")) != ""


func _hotspot_tooltip(hotspot: Dictionary) -> String:
	var hints: Array[String] = []
	if bool(hotspot.get("commission_marker", false)):
		hints.append(str(hotspot.get("commission_hint", "\u59d4\u6258\u76ee\u6807\uff1a\u5b8c\u6210\u540e\u56de\u544a\u793a\u724c\u4ea4\u5dee\u3002")))
	elif _hotspot_is_main_story(hotspot):
		hints.append("\u4e3b\u7ebf\u76ee\u6807\uff1a\u70b9\u51fb\u8fdb\u5165\u4e3b\u7ebf\u5206\u652f\u3002")
	else:
		hints.append(str(hotspot.get("type", "")))
	var visible := _visible_daily_district_opportunities()
	if not visible.is_empty():
		hints.append("\u4eca\u65e5\u5f02\u52a8\uff1a%d \u5904\u53ef\u67e5\u673a\u4f1a" % visible.size())
	return "\n".join(hints)


func _hotspot_is_daily_opportunity_anchor(hotspot: Dictionary) -> bool:
	if _visible_daily_district_opportunities().is_empty():
		return false
	var hotspot_type := str(hotspot.get("type", ""))
	if not hotspot_type in ["tower", "rumor", "minigame_job", "npc"]:
		return false
	var anchor_id := _daily_opportunity_anchor_hotspot_id()
	return anchor_id == "" or str(hotspot.get("id", "")) == anchor_id


func _daily_opportunity_anchor_hotspot_id() -> String:
	var hotspots: Variant = _district_data.get("hotspots", [])
	if not hotspots is Array:
		return ""
	for hotspot in hotspots:
		if not hotspot is Dictionary:
			continue
		var entry: Dictionary = hotspot
		var hotspot_type := str(entry.get("type", ""))
		if hotspot_type in ["tower", "rumor", "minigame_job", "npc"]:
			return str(entry.get("id", ""))
	return ""


func _visible_daily_district_opportunities() -> Array:
	if _game_state == null:
		return []
	return FieldOpportunityServiceScript.new().visible_district_opportunities(str(_district_data.get("district_id", "")), _game_state)


func _ensure_daily_field_opportunities() -> void:
	if _game_state == null:
		return
	var stored: Variant = _game_state.get("daily_field_opportunities")
	if stored is Dictionary and not (stored as Dictionary).is_empty() and int((stored as Dictionary).get("day", -1)) == int(_game_state.day):
		return
	FieldOpportunityServiceScript.new().refresh_daily(_game_state, int(_game_state.day) * 10000 + int(_game_state.sequence))


func _should_show_locked_hotspot(hotspot: Dictionary) -> bool:
	if bool(hotspot.get("commission_marker", false)):
		return true
	match str(hotspot.get("id", "")):
		"shop_blackmarket", "casino_eel_fan", "auction_smuggler":
			return true
		_:
			return false


func _locked_hotspot_hint(hotspot: Dictionary, visible_when: Variant) -> String:
	match str(hotspot.get("id", "")):
		"shop_blackmarket":
			return "第3天后夜间开放"
		"casino_eel_fan":
			return "夜间开放"
		"auction_smuggler":
			return "周六夜间开放"
		_:
			return _visible_when_hint(visible_when)


func _visible_when_hint(visible_when: Variant) -> String:
	var text := str(visible_when).strip_edges()
	if text == "" or text == "always":
		return "暂未开放"
	var parts := text.split(" AND ", false)
	var hints: Array[String] = []
	for part in parts:
		var clause := str(part).strip_edges()
		if clause.find("time_of_day == 'night'") >= 0:
			hints.append("夜间")
		elif clause.find("time_of_day == 'morning'") >= 0:
			hints.append("早晨")
		elif clause.find("day % 7 == 6") >= 0:
			hints.append("周六")
		elif clause.find("day >= 3") >= 0:
			hints.append("第3天后")
		elif clause.find("church_awareness < 75") >= 0:
			hints.append("教会关注低于75")
		else:
			hints.append(clause)
	if hints.is_empty():
		return "暂未开放"
	return _join_hint_text(hints)


func _join_hint_text(values: Array[String]) -> String:
	var text := ""
	for value in values:
		if text != "":
			text += "、"
		text += value
	if text != "":
		text += "开放"
	return text


func _safe_icon(icon: String) -> String:
	if icon == "" or icon.length() > 1:
		return ""
	var code := icon.unicode_at(0)
	if code > 0x7F:
		return ""
	return icon


func _time_text_zh(time_id: String) -> String:
	match time_id:
		"morning":
			return "白天"
		"noon":
			return "正午"
		"day":
			return "白天"
		"evening":
			return "黄昏"
		"night":
			return "夜晚"
		_:
			return time_id


func _update_topbar() -> void:
	var district_name := str(_district_data.get("display_name", _district_data.get("district_id", "")))
	_district_label.text = district_name
	if _game_state == null:
		_day_label.text = "第 ? 天"
		_time_label.text = "?"
		_ap_label.text = "AP ?/?"
		_lingstones_label.text = "灵石 ?"
		return
	_day_label.text = "第 %d 天" % int(_game_state.day)
	_time_label.text = _time_text_zh(str(_game_state.time_of_day))
	_ap_label.text = "AP %d/%d" % [int(_game_state.ap), int(_game_state.ap_max)]
	_lingstones_label.text = "灵石 %d" % int(_game_state.lingstones)
	_refresh_church_awareness_label()
	_refresh_r20_atmosphere_label()
	_refresh_intel_info_button()


func _setup_church_awareness_label() -> void:
	if _topbar == null or _church_awareness_label != null:
		return
	_church_awareness_label = Label.new()
	_church_awareness_label.name = "ChurchAwarenessLabel"
	_church_awareness_label.custom_minimum_size = Vector2(96, 28)
	_church_awareness_label.clip_text = true
	_church_awareness_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_topbar.add_child(_church_awareness_label)


func _refresh_church_awareness_label() -> void:
	if _church_awareness_label == null:
		return
	if _game_state == null:
		_church_awareness_label.text = "\u6559\u4f1a\u8b66\u89c9 ?"
		return
	_church_awareness_label.text = "\u6559\u4f1a\u8b66\u89c9 %d%%" % int(_game_state.church_awareness)


func _setup_r20_atmosphere_label() -> void:
	if _topbar == null or _r20_atmosphere_label != null:
		return
	_r20_atmosphere_label = Label.new()
	_r20_atmosphere_label.name = "R20AtmosphereLabel"
	_r20_atmosphere_label.custom_minimum_size = Vector2(120, 28)
	_r20_atmosphere_label.clip_text = true
	_r20_atmosphere_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_r20_atmosphere_label.hide()
	_topbar.add_child(_r20_atmosphere_label)


func _refresh_r20_atmosphere_label() -> void:
	if _r20_atmosphere_label == null:
		return
	var modifier := _active_r20_atmosphere_modifier()
	_r20_atmosphere_label.visible = not modifier.is_empty()
	if modifier.is_empty():
		_r20_atmosphere_label.text = ""
		_r20_atmosphere_label.tooltip_text = ""
		return
	var display_text := str(modifier.get("display_text", "")).strip_edges()
	if display_text == "":
		display_text = "\u6c1b\u56f4\uff1a%s" % _r20_atmosphere_label_text(str(modifier.get("atmosphere", "")))
	_r20_atmosphere_label.text = display_text
	_r20_atmosphere_label.tooltip_text = display_text


func _active_r20_atmosphere_modifier() -> Dictionary:
	if _game_state == null:
		return {}
	var modifiers: Variant = _game_state.get("activity_modifiers")
	if not modifiers is Dictionary:
		return {}
	var modifier: Variant = (modifiers as Dictionary).get("r20_modify_node_atmosphere", {})
	if not modifier is Dictionary:
		return {}
	var data: Dictionary = (modifier as Dictionary).duplicate(true)
	var district_id := str(_district_data.get("district_id", "")).strip_edges()
	var modifier_district := str(data.get("district", "")).strip_edges()
	if modifier_district != "" and district_id != "" and modifier_district != district_id:
		return {}
	var expires_at := int(data.get("expires_at_day", 0))
	if expires_at > 0 and int(_game_state.day) > expires_at:
		return {}
	return data


func _r20_atmosphere_label_text(atmosphere_id: String) -> String:
	match atmosphere_id:
		"ritual_echo":
			return "\u4eea\u5f0f\u56de\u54cd"
		"fog", "mist":
			return "\u8584\u96fe"
		"church_pressure":
			return "\u6559\u4f1a\u538b\u529b"
		"market_noise":
			return "\u5e02\u96c6\u55a7\u54d7"
		_:
			if atmosphere_id.strip_edges() == "":
				return "\u5f02\u6837\u7684\u6c14\u606f"
			return atmosphere_id


func _setup_intel_info_button() -> void:
	if _topbar == null or _intel_info_button != null:
		return
	_intel_info_button = Button.new()
	_intel_info_button.name = "IntelInfoButton"
	_intel_info_button.text = "情报 [0]"
	_intel_info_button.custom_minimum_size = Vector2(82, 28)
	_intel_info_button.pressed.connect(_on_intel_info_pressed)
	_topbar.add_child(_intel_info_button)


func _setup_r20_chant_panel() -> void:
	if _topbar == null or _r20_chant_panel != null:
		return
	_r20_chant_panel = HBoxContainer.new()
	_r20_chant_panel.name = "R20ChantPanel"
	_r20_chant_panel.add_theme_constant_override("separation", 4)
	_r20_chant_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topbar.add_child(_r20_chant_panel)


func _clear_r20_chant_buttons() -> void:
	if _r20_chant_panel == null:
		return
	ChantButtonFactoryScript.clear_chant_buttons(_r20_chant_panel)


func clear_npc_context_buttons() -> void:
	_clear_r20_chant_buttons()


func set_interaction_surface_visible(value: bool) -> void:
	if _interaction_surface == null:
		_interaction_surface = get_node_or_null("UILayer/RootMargin") as Control
	if _interaction_surface == null:
		return
	_interaction_surface.visible = value
	_interaction_surface.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if not value:
		_clear_r20_chant_buttons()


func _refresh_r20_chant_buttons_for_hotspot(hotspot: Dictionary) -> void:
	_setup_r20_chant_panel()
	_clear_r20_chant_buttons()
	if str(hotspot.get("type", "")) != "npc" or _game_state == null:
		return
	var payload: Variant = hotspot.get("payload", {})
	if not payload is Dictionary:
		return
	var npc_id := str((payload as Dictionary).get("npc_id", ""))
	if npc_id == "":
		return
	ChantButtonFactoryScript.add_chant_buttons(_r20_chant_panel, _game_state, npc_id, Callable(self, "_on_r20_chant_pressed"))


func _on_r20_chant_pressed(card_id: String, npc_id: String) -> void:
	var card = _game_state.get_card(card_id) if is_instance_valid(_game_state) and _game_state.has_method("get_card") else null
	if card == null:
		return
	var result: Dictionary = _r20_effect_engine().dispatch_card(card, npc_id, {
		"game_state": _game_state,
		"source": "city_scene",
	})
	if bool(result.get("success", false)):
		_update_topbar()
		_refresh_r20_chant_buttons_for_hotspot({
			"type": "npc",
			"payload": {"npc_id": npc_id},
		})
		_show_r20_feedback(card, npc_id, result)


func _r20_effect_engine():
	var engine = R20EffectEngineScript.new()
	if _ai_gm_service != null and engine.has_method("set_ai_gm_service"):
		engine.set_ai_gm_service(_ai_gm_service)
	return engine


func _show_r20_feedback(card, npc_id: String, result: Dictionary) -> void:
	_setup_r20_feedback_dialog()
	if _r20_feedback_dialog == null:
		return
	var lines: Array[String] = []
	var card_name := str(card.get("display_name")) if card != null and card.has_method("get") else str(result.get("card_id", "R20"))
	if card_name == "":
		card_name = str(result.get("card_id", "R20"))
	lines.append("%s -> %s" % [card_name, npc_id])
	var engine = R20EffectEngineScript.new()
	if engine.has_method("player_feedback_lines"):
		for line in engine.call("player_feedback_lines", result):
			var text := str(line).strip_edges()
			if text != "":
				lines.append(text)
	else:
		var ai_text := str(result.get("ai_gm_text", "")).strip_edges()
		if ai_text != "":
			lines.append(ai_text)
	_r20_feedback_dialog.title = "R20"
	_r20_feedback_dialog.dialog_text = "\n".join(lines)
	if is_inside_tree():
		_r20_feedback_dialog.popup_centered()
	else:
		_r20_feedback_dialog.show()


func _setup_r20_feedback_dialog() -> void:
	if _r20_feedback_dialog != null:
		return
	_r20_feedback_dialog = AcceptDialog.new()
	_r20_feedback_dialog.name = "CityR20FeedbackDialog"
	_r20_feedback_dialog.title = "R20"
	_ui_layer.add_child(_r20_feedback_dialog)


func _refresh_intel_info_button() -> void:
	if _intel_info_button == null:
		return
	var active := _active_rumors(_game_state)
	_intel_info_button.text = "情报 [%d]" % active.size()
	var lines := _intel_display_lines(_game_state)
	_intel_info_button.tooltip_text = "\n".join(lines)


func _on_intel_info_pressed() -> void:
	_setup_intel_info_dialog()
	_intel_info_dialog.title = "情报"
	_intel_info_dialog.dialog_text = "\n".join(_intel_display_lines(_game_state))
	if is_inside_tree():
		_intel_info_dialog.popup_centered()
	else:
		_intel_info_dialog.show()


func _setup_intel_info_dialog() -> void:
	if _intel_info_dialog != null:
		return
	_intel_info_dialog = AcceptDialog.new()
	_intel_info_dialog.name = "IntelInfoDialog"
	_intel_info_dialog.title = "情报"
	_ui_layer.add_child(_intel_info_dialog)


func _intel_display_lines(game_state) -> Array[String]:
	var lines: Array[String] = []
	for item in _active_rumors(game_state):
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		var text := IntelServiceScript.player_display_text(intel)
		if text != "":
			lines.append(text)
	if lines.is_empty():
		lines.append("暂无情报")
	return lines


func _apply_time_overlay() -> void:
	if _time_overlay == null:
		return
	var time_id := ""
	if _game_state != null:
		time_id = str(_game_state.time_of_day)
	match time_id:
		"morning":
			_time_overlay.color = Color(1.0, 0.98, 0.94, 0.05)
		"evening":
			_time_overlay.color = Color(1.0, 0.60, 0.40, 0.10)
		"night":
			_time_overlay.color = Color(0.10, 0.16, 0.25, 0.30)
		_:
			_time_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	if _fog_overlay != null:
		var weather_id := ""
		if _game_state != null:
			weather_id = str(_game_state.current_weather)
		_fog_overlay.color = Color(0.53, 0.53, 0.53, 0.15) if weather_id == "fog" else Color(0.53, 0.53, 0.53, 0.0)


func _apply_district_background() -> void:
	var district_id := str(_district_data.get("district_id", "")).strip_edges()
	if district_id == "":
		_set_background_texture("")
		return
	var phase := ""
	if _game_state != null:
		var raw_phase := str(_game_state.time_of_day).strip_edges()
		if raw_phase in ["morning", "noon", "evening", "night"]:
			phase = raw_phase
	_set_background_texture(ArtManifestScript.district_texture_path(district_id, phase))


func _apply_district_bgm() -> void:
	var track_id := bgm_track_for_district(str(_district_data.get("district_id", "")))
	if track_id == "":
		return
	_crossfade_bgm(track_id)


static func bgm_track_for_district(district_id: String) -> String:
	var normalized := district_id.strip_edges().to_lower()
	if normalized == "":
		return ""
	if normalized == "shadow_alley" or normalized == "whisper_alley" or normalized.find("alley") >= 0 or normalized.find("whisper") >= 0:
		return "whisper_alley"
	if normalized == "misty_port" or normalized == "foghorn_harbor" or normalized.find("harbor") >= 0 or normalized.find("foghorn") >= 0 or normalized.find("port") >= 0:
		return "foghorn_harbor"
	if normalized == "sacred_seven" or normalized.find("cathedral") >= 0:
		return "hollow_cathedral"
	return ""


func _bgm_autoload() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Bgm")


func _crossfade_bgm(track_id: String, duration: float = 1.5) -> void:
	var bgm := _bgm_autoload()
	if bgm != null and bgm.has_method("crossfade_to"):
		bgm.call("crossfade_to", track_id, duration)


func _on_hotspot_pressed(hotspot: Dictionary) -> void:
	_refresh_r20_chant_buttons_for_hotspot(hotspot)
	if _try_open_daily_district_opportunity(hotspot):
		return
	hotspot_selected.emit(hotspot)


func _try_open_daily_district_opportunity(hotspot: Dictionary) -> bool:
	if _game_state == null or str(hotspot.get("type", "")) != "district_opportunity":
		return false
	var payload := _dictionary_from(hotspot.get("payload", {}))
	var opportunity_id := str(payload.get("opportunity_id", ""))
	if opportunity_id == "":
		return false
	var district_id := str(_district_data.get("district_id", ""))
	var encounter = FieldOpportunityServiceScript.new().encounter_for_district_opportunity(_game_state, district_id, opportunity_id)
	if encounter == null:
		return false
	_raise_encounter_runner()
	if _encounter_runner == null or not _encounter_runner.has_method("start"):
		return false
	var start_result: Dictionary = _encounter_runner.start(encounter, _game_state)
	if bool(start_result.get("ok", false)):
		_active_daily_opportunity_id = opportunity_id
		_active_daily_opportunity_district_id = district_id
	return true


func _on_return_pressed() -> void:
	return_to_hub_requested.emit()


func _on_time_advance_pressed() -> void:
	if _game_state == null:
		return
	var result: Dictionary = TimeAdvanceServiceScript.advance_for_action(_game_state, "debug_wait")
	_update_topbar()
	_apply_time_overlay()
	_render_hotspots()
	if bool(result.get("forced_sleep_required", false)):
		force_sleep_requested.emit()
		return
	trigger_time_segment_encounter()


func trigger_time_segment_encounter(roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	if _encounter_trigger != null and _encounter_trigger.has_method("try_time_segment_spawn"):
		return _encounter_trigger.try_time_segment_spawn(roll, pool_roll)
	return {"ok": false, "triggered": false, "reason": "missing_trigger"}


func trigger_action_encounter(action_id: String, roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	return on_action_complete(action_id, str(_district_data.get("district_id", "")), roll, pool_roll)


func on_action_complete(source: String, district_id: String = "", roll: float = -1.0, pool_roll: float = -1.0) -> Dictionary:
	if _encounter_trigger != null and _encounter_trigger.has_method("on_action_complete"):
		var target_district := district_id if str(district_id).strip_edges() != "" else str(_district_data.get("district_id", ""))
		return _encounter_trigger.on_action_complete(source, target_district, roll, pool_roll)
	if _encounter_trigger != null and _encounter_trigger.has_method("try_action_trigger"):
		return _encounter_trigger.try_action_trigger(source, roll, pool_roll)
	return {"ok": false, "triggered": false, "reason": "missing_trigger"}


func _on_encounter_triggered(encounter) -> void:
	_apply_event_background_for_encounter(encounter)


func _apply_event_background_for_encounter(encounter) -> void:
	var district_id := _encounter_primary_district(encounter)
	if district_id == "":
		district_id = str(_district_data.get("district_id", ""))
	if district_id == "shadow_alley":
		_set_background_texture(ArtManifestScript.texture_path_for("event", "shadow_alley_well_face"))


func _encounter_primary_district(encounter) -> String:
	if encounter == null:
		return ""
	var districts: Variant = []
	if encounter is Dictionary:
		districts = (encounter as Dictionary).get("districts", [])
	else:
		districts = encounter.get("districts")
	if districts is Array and not (districts as Array).is_empty():
		return str((districts as Array)[0])
	return ""


func _set_background_texture(path: String) -> void:
	if _background == null:
		return
	var texture: Texture2D = null
	if path != "":
		texture = ResourceLoader.load(path) as Texture2D
	_background.texture = texture
	_background.visible = texture != null


func _apply_hotspot_time_modifier(hotspot: Dictionary) -> Dictionary:
	var result := hotspot.duplicate(true)
	var modifier: Variant = result.get("time_modifier", {})
	if not modifier is Dictionary or _game_state == null:
		return result
	var current_time := str(_game_state.time_of_day)
	if not modifier.has(current_time):
		return result
	var patch: Variant = modifier.get(current_time)
	if patch is String:
		result["label"] = "%s%s" % [str(result.get("label", "")), str(patch)]
	elif patch is Dictionary:
		if patch.has("label_suffix"):
			result["label"] = "%s%s" % [str(result.get("label", "")), str(patch.get("label_suffix", ""))]
		for key in patch.keys():
			if str(key) == "label_suffix":
				continue
			result[str(key)] = patch[key]
	return result


func _apply_npc_city_presence(hotspot: Dictionary) -> Dictionary:
	var result := hotspot.duplicate(true)
	if str(result.get("type", "")) != "npc" or _game_state == null:
		return result
	var payload: Variant = result.get("payload", {})
	if not payload is Dictionary:
		return result
	var npc_id := str((payload as Dictionary).get("npc_id", ""))
	if npc_id == "":
		return result
	var npc_def := _npc_definition(npc_id)
	if npc_def.is_empty() or bool(npc_def.get("placeholder", false)):
		return result
	var raw_presence: Variant = npc_def.get("city_presence", [])
	if not raw_presence is Array:
		return result
	var district_id := str(_district_data.get("district_id", ""))
	var current_time := str(_game_state.time_of_day)
	var has_presence_for_district := false
	for entry in raw_presence:
		if not entry is Dictionary:
			continue
		if str(entry.get("district", "")) != district_id:
			continue
		has_presence_for_district = true
		if str(entry.get("time_of_day", "")) != current_time:
			continue
		result["_city_presence_applied"] = true
		_apply_npc_presence_patch(result, entry)
		return result
	if has_presence_for_district:
		result["visible"] = false
		result["_city_presence_applied"] = true
	return result


func _apply_npc_presence_patch(hotspot: Dictionary, presence: Dictionary) -> void:
	if presence.has("label"):
		hotspot["label"] = str(presence.get("label", ""))
	elif presence.has("label_suffix"):
		hotspot["label"] = "%s%s" % [str(hotspot.get("label", "")), str(presence.get("label_suffix", ""))]
	for key in ["icon", "interactable", "visible", "ap_cost", "position_norm"]:
		if presence.has(key):
			hotspot[key] = presence[key]


func _apply_mainline_forced_tower(hotspot: Dictionary) -> Dictionary:
	var result := hotspot.duplicate(true)
	if str(result.get("type", "")) != "tower" or _game_state == null:
		return result
	var forced := _mainline_forced_tower()
	if forced.is_empty():
		return result
	var district_id := str(_district_data.get("district_id", ""))
	if not _forced_tower_targets_district(forced, district_id):
		return result
	if forced.has("label"):
		result["label"] = str(forced.get("label", result.get("label", "")))
	if forced.has("icon"):
		result["icon"] = str(forced.get("icon", result.get("icon", "")))
	else:
		result["icon"] = "!"
	result["mainline_forced"] = true
	result["visible_when"] = "always"
	var payload: Dictionary = {}
	var raw_payload: Variant = result.get("payload", {})
	if raw_payload is Dictionary:
		payload = raw_payload.duplicate(true)
	payload["mainline_hook_id"] = str(forced.get("id", ""))
	payload["mainline_node_id"] = str(forced.get("node_id", ""))
	payload["tower_size"] = str(forced.get("tower_size", payload.get("tower_size", "small")))
	payload["tower_template"] = str(forced.get("tower_template", payload.get("tower_template", "")))
	payload["tower_label"] = str(forced.get("label", result.get("label", "")))
	if forced.has("cycle_end_on_complete"):
		payload["cycle_end_on_complete"] = bool(forced.get("cycle_end_on_complete", false))
	result["payload"] = payload
	return result


func _apply_commission_marker(hotspot: Dictionary) -> Dictionary:
	var result := hotspot.duplicate(true)
	var dispatch := _active_city_commission_dispatch()
	if dispatch.is_empty():
		return result
	if not _hotspot_matches_commission_dispatch(result, dispatch):
		return result
	var title := _commission_title_for_dispatch(dispatch)
	result["commission_marker"] = true
	result["commission_title"] = title
	result["commission_hint"] = "\u59d4\u6258\u76ee\u6807\uff1a%s\u3002\u5b8c\u6210\u540e\u56de\u544a\u793a\u724c\u4ea4\u5dee\u3002" % title
	result["icon"] = "!"
	return result


func _active_city_commission_dispatch() -> Dictionary:
	if _game_state == null or not _game_state.has_method("get_meta"):
		return {}
	var value: Variant = _game_state.get_meta("commission_active_dispatch", {})
	if not value is Dictionary:
		return {}
	var dispatch: Dictionary = value.duplicate(true)
	var current_district := str(_district_data.get("district_id", ""))
	var target_district := _commission_dispatch_district(dispatch)
	if target_district != "" and current_district != "" and target_district != current_district:
		return {}
	return dispatch


func _active_encounter_commission_dispatch() -> Dictionary:
	var dispatch := _active_city_commission_dispatch()
	if dispatch.is_empty():
		return {}
	if str(dispatch.get("dispatch_kind", "")) != "encounter":
		return {}
	if str(dispatch.get("commission_type", "")) != "gather":
		return {}
	return dispatch


func _on_encounter_resolved(result: Dictionary) -> void:
	var completion := _record_encounter_commission_completion(result)
	var daily_resolution := _record_active_daily_opportunity_resolution(result)
	if completion.is_empty() and daily_resolution.is_empty():
		return
	_update_topbar()
	_render_hotspots()


func _record_active_daily_opportunity_resolution(result: Dictionary) -> Dictionary:
	if _game_state == null or _active_daily_opportunity_id == "" or _active_daily_opportunity_district_id == "":
		return {}
	var opportunity_id := _active_daily_opportunity_id
	var district_id := _active_daily_opportunity_district_id
	_clear_active_daily_opportunity()
	var resolution: Dictionary = FieldOpportunityServiceScript.new().resolve_district_opportunity(
		_game_state,
		district_id,
		opportunity_id,
		result
	)
	if not bool(resolution.get("ok", false)):
		return {}
	return resolution


func _clear_active_daily_opportunity() -> void:
	_active_daily_opportunity_id = ""
	_active_daily_opportunity_district_id = ""


func _record_encounter_commission_completion(result: Dictionary) -> Dictionary:
	var dispatch := _active_encounter_commission_dispatch()
	if dispatch.is_empty() or _game_state == null:
		return {}
	var target := _commission_dispatch_target(dispatch)
	var outcome := _dictionary_from(result.get("outcome", {}))
	var item_id := str(outcome.get("loot_item_id", outcome.get("item_id", "")))
	if item_id == "" or item_id != str(target.get("item_id", "")):
		return {}
	var count_added := maxi(1, int(outcome.get("loot_count", outcome.get("count_added", 1))))
	var event := {
		"event": "loot_resolved",
		"district": _commission_dispatch_district(dispatch),
		"time": str(_game_state.get("time_of_day")),
		"item_id": item_id,
		"count_added": count_added,
	}
	var completion_result: Dictionary = CommissionServiceScript.new().record_completion_event(_game_state, event)
	if completion_result.has("completed_ids") and Array(completion_result.get("completed_ids", [])).size() > 0:
		if _game_state.has_method("remove_meta") and _game_state.has_meta("commission_active_dispatch"):
			_game_state.remove_meta("commission_active_dispatch")
	return completion_result


func _hotspot_matches_commission_dispatch(hotspot: Dictionary, dispatch: Dictionary) -> bool:
	var hotspot_type := str(hotspot.get("type", ""))
	var payload := _dictionary_from(hotspot.get("payload", {}))
	var target := _commission_dispatch_target(dispatch)
	match str(dispatch.get("dispatch_kind", "")):
		"job":
			return hotspot_type == "minigame_job" and _payload_id_matches(payload, target, "job_id")
		"drill":
			return hotspot_type == "minigame_drill" and _payload_id_matches(payload, target, "drill_id")
		"tower", "tower_event":
			return hotspot_type == "tower"
		_:
			return false


func _payload_id_matches(payload: Dictionary, target: Dictionary, key: String) -> bool:
	var expected := str(target.get(key, ""))
	if expected == "":
		return false
	return str(payload.get(key, "")) == expected


func _commission_title_for_dispatch(dispatch: Dictionary) -> String:
	var commission_id := str(dispatch.get("commission_id", ""))
	if _game_state != null:
		var available: Variant = _game_state.get("available_commissions")
		if available is Array:
			for item in available:
				if not item is Dictionary:
					continue
				var data: Dictionary = item
				if str(data.get("id", "")) != commission_id:
					continue
				var title := str(data.get("display_name", data.get("title", "")))
				if title != "":
					return title
	return "\u5f53\u524d\u59d4\u6258"


func _commission_dispatch_district(dispatch: Dictionary) -> String:
	var target := _commission_dispatch_target(dispatch)
	for key in ["district", "district_id", "target_district"]:
		var target_value := str(target.get(key, ""))
		if target_value != "":
			return target_value
	for key in ["district", "district_id", "target_district"]:
		var dispatch_value := str(dispatch.get(key, ""))
		if dispatch_value != "":
			return dispatch_value
	return ""


func _commission_dispatch_target(dispatch: Dictionary) -> Dictionary:
	return _dictionary_from(dispatch.get("dispatch_target", {}))


func _dictionary_from(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _has_cjk(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x3400 and code <= 0x9fff:
			return true
	return false


func _mainline_forced_tower() -> Dictionary:
	if _game_state != null and _game_state.has_method("get_meta"):
		var value: Variant = _game_state.get_meta("mainline_forced_tower", {})
		if value is Dictionary:
			return value.duplicate(true)
	return {}


func _forced_tower_targets_district(forced_tower: Dictionary, district_id: String) -> bool:
	var district_ids: Variant = forced_tower.get("district_ids", [])
	if district_ids is Array:
		for id in district_ids:
			if str(id) == district_id:
				return true
	return false


func _npc_definition(npc_id: String) -> Dictionary:
	if _npc_library == null:
		_npc_library = NpcLibraryScript.new()
	return _npc_library.get_definition(npc_id)


func _configure_encounter_trigger() -> void:
	if _encounter_trigger != null and _encounter_trigger.has_method("configure"):
		_encounter_trigger.configure(_game_state, _district_data, _encounter_runner)
	_connect_encounter_trigger()


func _active_rumors(game_state) -> Array:
	if game_state == null:
		return []
	var value: Variant = game_state.get("active_rumors")
	return value if value is Array else []


static func _legacy_district_to_location(district_id: String) -> Dictionary:
	if not FileAccess.file_exists(LEGACY_DISTRICT_DATA):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_DISTRICT_DATA))
	if not parsed is Dictionary:
		return {}
	for district in parsed.get("districts", []):
		if not district is Dictionary or str(district.get("id", "")) != district_id:
			continue
		var result := {
			"$schema": "city_hotspot_v1",
			"district_id": district_id,
			"display_name": str(district.get("display_name", district_id)),
			"ap_to_enter": int(district.get("ap_cost", 0)),
			"hotspots": _legacy_events_to_hotspots(district.get("events", [])),
		}
		return result
	return {}


static func _legacy_events_to_hotspots(events: Variant) -> Array:
	var hotspots: Array = []
	if not events is Array:
		return hotspots
	var index := 0
	for event in events:
		if not event is Dictionary:
			continue
		var event_type := str(event.get("type", "event"))
		hotspots.append({
			"id": "%s_%d" % [event_type, index],
			"label": event_type,
			"icon": _icon_for_event(event_type),
			"type": _hotspot_type_for_event(event_type),
			"ap_cost": 0,
			"payload": event.duplicate(true),
			"visible_when": "always",
		})
		index += 1
	return hotspots


static func _hotspot_type_for_event(event_type: String) -> String:
	if event_type.begins_with("tower"):
		return "tower"
	match event_type:
		"shop_visit":
			return "shop"
		"npc_encounter":
			return "npc"
		"main_story":
			return "main_story"
		"loot":
			return "loot"
		_:
			return "event"


static func _icon_for_event(event_type: String) -> String:
	if event_type.begins_with("tower"):
		return "T"
	match event_type:
		"shop_visit":
			return "S"
		"npc_encounter":
			return "N"
		"main_story":
			return "M"
		"loot":
			return "L"
		_:
			return "?"
