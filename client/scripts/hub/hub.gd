extends Control

# Per R10 §2 — 洞府主屏，8 热区 + 窗 + 底部状态栏
# 锻造台和塔罗书桌共用一个像素位，点击弹出二级菜单二选一

signal zone_clicked(zone_id: String)

enum Zone {
	FORGE = 0,
	TAROT_DESK = 1,
	BRAND_WORKSHOP = 2,
	DECK_BUILDER = 3,
	CUSHION = 4,
	BOOKSHELF = 5,
	NOTICE_BOARD = 6,
	BED = 7,
	FRONT_DOOR = 8,
	CLOCK = 9,
}

const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const MeditationServiceScript = preload("res://scripts/world/meditation_service.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")
const TowerGeneratorScript = preload("res://scripts/tower/tower_generator.gd")
const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")
const MinigameServiceScript = preload("res://scripts/minigames/minigame_service.gd")
const AuctionServiceScript = preload("res://scripts/minigames/auction/auction_service.gd")
const JobServiceScript = preload("res://scripts/world/job_service.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const FieldOpportunityServiceScript = preload("res://scripts/world/field_opportunity_service.gd")
const PseudoGodContractServiceScript = preload("res://scripts/world/pseudo_god_contract_service.gd")
const R20EffectEngineScript = preload("res://scripts/world/r20_effect_engine.gd")
const ChantButtonFactoryScript = preload("res://scripts/world/chant_button_factory.gd")
const IdentityPickerScript = preload("res://scripts/world/identity_picker_dialog.gd")
const ContractPickerScript = preload("res://scripts/ui/contract_picker_dialog.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const ArtManifestScript = preload("res://scripts/art_manifest.gd")

const ZONE_DESK := "desk"
const ZONE_TAROT := "tarot_desk"
const ZONE_BRAND_WORKSHOP := "brand_workshop"
const ZONE_CUSHION := "cushion"
const ZONE_BOOKSHELF := "bookshelf"
const ZONE_NOTICE_BOARD := "notice_board"
const ZONE_BED := "bed"
const ZONE_FRONT_DOOR := "front_door"
const ZONE_CLOCK := "clock"
const HUB_BACKGROUND_PATH := "res://assets/textures/hub/hub_anchor.png"
const SHOW_HOTSPOT_DEBUG_RECTS := false
const HOTSPOT_HOVER_MODULATE := Color(1.0, 0.93, 0.7, 0.42)
const HOTSPOT_HIDDEN_MODULATE := Color(1.0, 0.93, 0.7, 0.0)
const HOTSPOT_DEBUG_MODULATE := Color(1.0, 0.12, 0.08, 0.22)
const HUB_HOTSPOTS := {
	"DeskButton": {
		"zone_id": ZONE_DESK,
		"rect": Rect2(0.04, 0.50, 0.30, 0.45),
		"tooltip": "书桌 · 塔罗牌堆 · 抽签 / 整理牌组",
	},
	"BookshelfButton": {
		"zone_id": ZONE_BOOKSHELF,
		"rect": Rect2(0.00, 0.05, 0.20, 0.45),
		"tooltip": "书架 · 守则 / 道典查询",
	},
	"FrontDoorButton": {
		"zone_id": ZONE_FRONT_DOOR,
		"rect": Rect2(0.32, 0.10, 0.18, 0.65),
		"tooltip": "出门 · 进入城区漫游",
	},
	"NoticeBoardButton": {
		"zone_id": ZONE_NOTICE_BOARD,
		"rect": Rect2(0.50, 0.05, 0.20, 0.55),
		"tooltip": "告示板 · 委托 / 灰冠日报",
	},
	"BedButton": {
		"zone_id": ZONE_BED,
		"rect": Rect2(0.66, 0.40, 0.30, 0.45),
		"tooltip": "床铺 · 睡觉推进时段",
	},
	"CushionButton": {
		"zone_id": ZONE_CUSHION,
		"rect": Rect2(0.58, 0.55, 0.16, 0.20),
		"tooltip": "蒲团 · 修炼 / 入梦",
	},
	"ClockButton": {
		"zone_id": ZONE_CLOCK,
		"rect": Rect2(0.71, 0.04, 0.10, 0.18),
		"tooltip": "",
	},
}

const HUB_HOTSPOT_TEXTURE_LINKS := {
	"DeskButton": "hub_desk_cluster",
	"BookshelfButton": "hub_bookshelf",
	"FrontDoorButton": "hub_front_door",
	"NoticeBoardButton": "hub_notice_board",
	"BedButton": "hub_bed",
	"CushionButton": "hub_cushion",
	"ClockButton": "hub_clock",
}

const BUTTON_ZONE_MAP := {
	"DeskButton": ZONE_DESK,
	"NoticeBoardButton": ZONE_NOTICE_BOARD,
	"CushionButton": ZONE_CUSHION,
	"BookshelfButton": ZONE_BOOKSHELF,
	"BedButton": ZONE_BED,
	"FrontDoorButton": ZONE_FRONT_DOOR,
	"ClockButton": ZONE_CLOCK,
}

const PROMOTION_SERVICE_PATH := "res://scripts/sequence/promotion_ritual_service.gd"
const PROMOTION_GATE_DIR := "res://data/sequence/promotion_gates/"
const GRAY_CROWN_DAILY_SCENE := "res://scenes/ui/gray_crown_daily_dialog.tscn"
const NPC_DEEP_CHAT_ROUNDS := 3
const NPC_DEEP_CHAT_TRUST_DELTA := 1
const NPC_DIALOG_BUTTON_PREFIXES := [
	"NpcRootButton_",
	"NpcTalkMenuButton_",
	"NpcEventMenuButton_",
	"NpcServiceMenuButton_",
	"NpcBackButton_",
	"NpcDialogueBranchButton_",
	"NpcDeepChatButton_",
	"NpcIdentityButton_",
	"NpcOpportunityButton_",
	"NpcMainlineButton_",
	"NpcIntelButton_",
	"NpcCommissionButton_",
	"NpcJobButton_",
	"NpcDrillButton_",
	"R20ChantButton_",
]

var _zone_buttons: Dictionary = {}
var _hotspot_highlights: Dictionary = {}
var _hotspot_tweens: Dictionary = {}
var _desk_menu: PopupMenu
var _front_door_menu: PopupMenu
var _status_day: Label
var _status_ap: Label
var _status_pollution: Label
var _status_church_awareness: Label
var _status_lingstones: Label
var _intel_info_button: Button
var _r20_visitor_buttons: Dictionary = {}
var _r20_visitor_dialog: AcceptDialog
var _gray_crown_daily_button: Button
var _pseudo_god_contract_button: Button
var _intel_info_dialog: AcceptDialog
var _pseudo_god_contract_dialog: AcceptDialog
var _promotion_button: Button
var _promotion_progress_label: Label
var _window_label: Label
var _card_inventory_panel: Control
var _brand_workshop_panel: Control
var _deck_builder_panel: Control
var _black_market_panel: Control
var _commission_panel: Control
var _district_select_panel: Control
var _city_scene_panel: Control
var _tower_runner_panel: Control
var _contract_picker_dialog: Control
var _pending_tower_open: Dictionary = {}
var _meditation_panel: Control
var _settings_panel: Control
var _debug_panel: Control
var _sleep_confirm_dialog: ConfirmationDialog
var _placeholder_dialog: AcceptDialog
var _npc_dialog: AcceptDialog
var _npc_portrait_rect: TextureRect
var _casino_dialog: AcceptDialog
var _auction_dialog: AcceptDialog
var _job_dialog: AcceptDialog
var _drill_dialog: AcceptDialog
var _rumor_dialog: AcceptDialog
var _gray_crown_daily_dialog: Control
var _promotion_ready_dialog: AcceptDialog
var _mainline_dialog: AcceptDialog
var _sleep_force_active: bool = false
var _pollution_hud: Control
var _lost_control_background_tint: ColorRect
var _ai_gm_service = null
var _drill_runner_override = null
var _active_npc_id: String = ""
var _active_npc_dialogue_result: Dictionary = {}


func _ready() -> void:
	_fit_to_viewport()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)
	_setup_zones()
	_setup_hub_art()
	_setup_desk_menu()
	_setup_front_door_menu()
	_setup_status_bar()
	_connect_game_state_signals()
	_setup_card_inventory_panel()
	_setup_brand_workshop_panel()
	_setup_deck_builder_panel()
	_setup_black_market_panel()
	_setup_commission_panel()
	_setup_tower_runner_panel()
	_setup_district_select_panel()
	_setup_city_scene_panel()
	_setup_cushion_meditation_panel()
	_setup_settings_panel()
	_setup_sleep_confirm_dialog()
	_setup_placeholder_dialog()
	_setup_npc_dialog()
	_setup_casino_dialog()
	_setup_auction_dialog()
	_setup_job_dialog()
	_setup_drill_dialog()
	_setup_rumor_dialog()
	_setup_gray_crown_daily_dialog()
	_setup_promotion_ready_dialog()
	_setup_mainline_dialog()
	_setup_debug_panel()
	_setup_pollution_hud()
	_setup_lost_control_visual()
	_refresh_status()
	_crossfade_bgm("hub_sanctuary")


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service
	if _city_scene_panel != null and _city_scene_panel.has_method("set_ai_gm_service"):
		_city_scene_panel.call("set_ai_gm_service", service)


func set_drill_runner(runner) -> void:
	_drill_runner_override = runner


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_to_viewport()


func _fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _bgm_autoload() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Bgm")


func _crossfade_bgm(track_id: String, duration: float = 1.5) -> void:
	var bgm := _bgm_autoload()
	if bgm != null and bgm.has_method("crossfade_to"):
		bgm.call("crossfade_to", track_id, duration)


func _current_bgm_track() -> String:
	var bgm := _bgm_autoload()
	if bgm != null and bgm.has_method("current_track"):
		return str(bgm.call("current_track"))
	return ""


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _all_subpanels_hidden():
		if _settings_panel and _settings_panel.has_method("open"):
			_settings_panel.open()
			accept_event()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_toggle_fullscreen()
			accept_event()
		elif event.keycode == KEY_F12:
			_on_debug_pressed()
			accept_event()
		elif event.keycode == KEY_S and _all_subpanels_hidden():
			if _settings_panel and _settings_panel.has_method("open") and _settings_panel.has_method("open_save_picker"):
				_settings_panel.open()
				_settings_panel.open_save_picker()
				accept_event()


func _process(_delta: float) -> void:
	_refresh_status()
	_refresh_promotion_button()


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _setup_zones() -> void:
	var grid = $MarginContainer/VBoxContainer/ZoneGrid
	for i in grid.get_child_count():
		var btn = grid.get_child(i)
		if btn is Button:
			var zone_id = BUTTON_ZONE_MAP.get(btn.name, "")
			_zone_buttons[zone_id] = btn
			btn.pressed.connect(_on_zone_pressed.bind(zone_id))


func _setup_hub_art() -> void:
	_setup_hub_background()
	var has_background := ResourceLoader.exists(HUB_BACKGROUND_PATH)
	_set_legacy_zone_grid_visible(not has_background)
	if has_background:
		_build_hub_hotspot_layer()


func _setup_hub_background() -> void:
	var background := get_node_or_null("HubBackground")
	if not ResourceLoader.exists(HUB_BACKGROUND_PATH):
		if background != null:
			background.queue_free()
		return
	if not background is TextureRect:
		background = TextureRect.new()
		background.name = "HubBackground"
		add_child(background)
	var rect := background as TextureRect
	_configure_full_rect_control(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = ResourceLoader.load(HUB_BACKGROUND_PATH) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	move_child(rect, 0)


func _set_legacy_zone_grid_visible(is_visible: bool) -> void:
	var grid := get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid")
	if grid == null:
		return
	grid.visible = is_visible
	for child in grid.get_children():
		if not child is Button:
			continue
		var button := child as Button
		button.icon = null
		button.expand_icon = false
		if button.has_theme_constant_override("icon_max_width"):
			button.remove_theme_constant_override("icon_max_width")


func _build_hub_hotspot_layer() -> void:
	var layer := _ensure_hub_hotspot_layer()
	if layer == null:
		return
	_hotspot_highlights.clear()
	for raw_button_name in HUB_HOTSPOTS.keys():
		var button_name := str(raw_button_name)
		var spec: Dictionary = HUB_HOTSPOTS[raw_button_name]
		var highlight := _ensure_hotspot_highlight(layer, button_name, spec)
		var button := _ensure_hotspot_button(layer, button_name, spec)
		if highlight == null or button == null:
			continue
		if highlight.get_index() > button.get_index():
			layer.move_child(highlight, button.get_index())
		_hotspot_highlights[button_name] = highlight
		_zone_buttons[str(spec.get("zone_id", ""))] = button
	_refresh_hotspot_clock_tooltip()


func _ensure_hub_hotspot_layer() -> Control:
	var existing := get_node_or_null("HubHotspotLayer")
	var layer: Control = null
	if existing is Control:
		layer = existing as Control
	else:
		layer = Control.new()
		layer.name = "HubHotspotLayer"
		add_child(layer)
	_configure_full_rect_control(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 5
	move_child(layer, get_child_count() - 1)
	return layer


func _ensure_hotspot_highlight(layer: Control, button_name: String, spec: Dictionary) -> TextureRect:
	var highlight_name := "%sHighlight" % button_name
	var node := layer.get_node_or_null(highlight_name)
	var highlight: TextureRect = null
	if node is TextureRect:
		highlight = node as TextureRect
	else:
		if node != null:
			layer.remove_child(node)
			node.queue_free()
		highlight = TextureRect.new()
		highlight.name = highlight_name
		layer.add_child(highlight)
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.texture = _hub_hotspot_texture(button_name)
	highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	highlight.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	highlight.clip_contents = true
	highlight.modulate = HOTSPOT_DEBUG_MODULATE if SHOW_HOTSPOT_DEBUG_RECTS else HOTSPOT_HIDDEN_MODULATE
	highlight.z_index = 0
	highlight.set_meta("hover_alpha", HOTSPOT_HOVER_MODULATE.a)
	highlight.set_meta("linked_data_id", str(HUB_HOTSPOT_TEXTURE_LINKS.get(button_name, "")))
	_apply_hotspot_rect(highlight, spec.get("rect", Rect2()))
	return highlight


func _hub_hotspot_texture(button_name: String) -> Texture2D:
	var linked_data_id := str(HUB_HOTSPOT_TEXTURE_LINKS.get(button_name, ""))
	if linked_data_id == "":
		return null
	var path := ArtManifestScript.texture_path_for("hotspot", linked_data_id)
	if path == "":
		return null
	var resource := ResourceLoader.load(path)
	return resource as Texture2D


func _ensure_hotspot_button(layer: Control, button_name: String, spec: Dictionary) -> TextureButton:
	var node := layer.get_node_or_null(button_name)
	var button: TextureButton = null
	if node is TextureButton:
		button = node as TextureButton
	else:
		button = TextureButton.new()
		button.name = button_name
		layer.add_child(button)
	button.texture_normal = null
	button.texture_hover = null
	button.texture_pressed = null
	button.texture_disabled = null
	button.texture_focused = null
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.z_index = 1
	button.tooltip_text = _hotspot_tooltip(button_name, spec)
	button.set_meta("zone_id", str(spec.get("zone_id", "")))
	_apply_hotspot_rect(button, spec.get("rect", Rect2()))
	_connect_hotspot_button_signals(button, button_name, str(spec.get("zone_id", "")))
	return button


func _apply_hotspot_rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.position.x + rect.size.x
	control.anchor_bottom = rect.position.y + rect.size.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _connect_hotspot_button_signals(button: TextureButton, button_name: String, zone_id: String) -> void:
	var enter_callable := Callable(self, "_on_hotspot_mouse_entered").bind(button_name)
	if not button.mouse_entered.is_connected(enter_callable):
		button.mouse_entered.connect(enter_callable)
	var exit_callable := Callable(self, "_on_hotspot_mouse_exited").bind(button_name)
	if not button.mouse_exited.is_connected(exit_callable):
		button.mouse_exited.connect(exit_callable)
	var pressed_callable := Callable(self, "_on_hotspot_pressed_by_zone").bind(zone_id)
	if not button.pressed.is_connected(pressed_callable):
		button.pressed.connect(pressed_callable)


func _hotspot_tooltip(button_name: String, spec: Dictionary) -> String:
	if button_name == "ClockButton":
		return _clock_hotspot_tooltip()
	return str(spec.get("tooltip", ""))


func _clock_hotspot_tooltip() -> String:
	if is_instance_valid(GameState):
		return "时钟 · 当前 day %d %s" % [int(GameState.day), str(GameState.time_of_day)]
	return "时钟 · 当前 day 1 morning"


func _refresh_hotspot_clock_tooltip() -> void:
	var layer := get_node_or_null("HubHotspotLayer")
	if not layer is Control:
		return
	var clock := (layer as Control).get_node_or_null("ClockButton")
	if clock is TextureButton:
		(clock as TextureButton).tooltip_text = _clock_hotspot_tooltip()


func _on_hotspot_mouse_entered(button_name: String) -> void:
	_tween_hotspot_highlight(button_name, HOTSPOT_HOVER_MODULATE)


func _on_hotspot_mouse_exited(button_name: String) -> void:
	_tween_hotspot_highlight(button_name, HOTSPOT_HIDDEN_MODULATE)


func _on_hotspot_pressed_by_zone(zone_id: String) -> void:
	_on_zone_pressed(zone_id)


func _tween_hotspot_highlight(button_name: String, target: Color) -> void:
	var highlight = _hotspot_highlights.get(button_name, null)
	if not highlight is TextureRect:
		return
	var existing_tween = _hotspot_tweens.get(button_name, null)
	if existing_tween is Tween:
		(existing_tween as Tween).kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(highlight, "modulate", target, 0.15)
	_hotspot_tweens[button_name] = tween


func _set_hotspot_debug_rects_visible(enabled: bool) -> void:
	for button_name in _hotspot_highlights.keys():
		var highlight = _hotspot_highlights[button_name]
		if highlight is TextureRect:
			var target := HOTSPOT_DEBUG_MODULATE if enabled else HOTSPOT_HIDDEN_MODULATE
			(highlight as TextureRect).modulate = target


func _setup_desk_menu() -> void:
	_desk_menu = PopupMenu.new()
	_desk_menu.add_item("锻造台", Zone.FORGE)
	_desk_menu.add_item("塔罗书桌", Zone.TAROT_DESK)
	_desk_menu.add_item("烙印工坊", Zone.BRAND_WORKSHOP)
	_desk_menu.add_item("构筑卡组", Zone.DECK_BUILDER)
	_desk_menu.id_pressed.connect(_on_desk_menu_selected)
	add_child(_desk_menu)


func _setup_front_door_menu() -> void:
	_front_door_menu = PopupMenu.new()
	_front_door_menu.name = "FrontDoorMenu"
	_front_door_menu.add_item("出门", 0)
	_front_door_menu.add_item("黑市", 1)
	_front_door_menu.add_item("灰冠日报", 2)
	_front_door_menu.id_pressed.connect(_on_front_door_menu_selected)
	add_child(_front_door_menu)


func _setup_card_inventory_panel() -> void:
	_card_inventory_panel = load("res://scripts/hub/card_inventory_panel.gd").new()
	_card_inventory_panel.hide()
	add_child(_card_inventory_panel)


func _setup_brand_workshop_panel() -> void:
	_brand_workshop_panel = load("res://scripts/hub/brand_workshop_panel.gd").new()
	_brand_workshop_panel.hide()
	add_child(_brand_workshop_panel)


func _setup_deck_builder_panel() -> void:
	var scene = load("res://scenes/ui/deck_builder.tscn")
	if scene != null and scene.can_instantiate():
		_deck_builder_panel = scene.instantiate()
		_deck_builder_panel.hide()
		add_child(_deck_builder_panel)


func _setup_black_market_panel() -> void:
	var scene = load("res://scenes/ui/black_market.tscn")
	if scene != null and scene.can_instantiate():
		_black_market_panel = scene.instantiate()
		_black_market_panel.hide()
		add_child(_black_market_panel)


func _setup_commission_panel() -> void:
	var scene = load("res://scenes/ui/commission_board.tscn")
	if scene != null and scene.can_instantiate():
		_commission_panel = scene.instantiate()
		_commission_panel.name = "CommissionBoard"
		_commission_panel.hide()
		add_child(_commission_panel)


func _setup_district_select_panel() -> void:
	var scene = load("res://scenes/ui/district_select.tscn")
	if scene != null and scene.can_instantiate():
		_district_select_panel = scene.instantiate()
		_district_select_panel.hide()
		add_child(_district_select_panel)
		if _district_select_panel.has_signal("city_scene_requested"):
			_district_select_panel.city_scene_requested.connect(_on_city_scene_requested)


func _setup_city_scene_panel() -> void:
	var scene = load("res://scenes/world/city_scene.tscn")
	if scene != null and scene.can_instantiate():
		_city_scene_panel = scene.instantiate()
		_city_scene_panel.name = "CityScene"
		_city_scene_panel.hide()
		add_child(_city_scene_panel)
		if _ai_gm_service != null and _city_scene_panel.has_method("set_ai_gm_service"):
			_city_scene_panel.call("set_ai_gm_service", _ai_gm_service)
		if _city_scene_panel.has_signal("return_to_hub_requested"):
			_city_scene_panel.return_to_hub_requested.connect(_on_city_return_requested)
		if _city_scene_panel.has_signal("force_sleep_requested"):
			_city_scene_panel.force_sleep_requested.connect(_on_city_force_sleep_requested)
		if _city_scene_panel.has_signal("hotspot_selected"):
			_city_scene_panel.hotspot_selected.connect(_on_city_hotspot_selected)


func _setup_cushion_meditation_panel() -> void:
	var scene = load("res://scenes/hub/cushion_meditation.tscn")
	if scene != null and scene.can_instantiate():
		_meditation_panel = scene.instantiate()
		_meditation_panel.name = "CushionMeditation"
		_meditation_panel.hide()
		add_child(_meditation_panel)


func _setup_tower_runner_panel() -> void:
	var scene = load("res://scenes/tower/tower_runner.tscn")
	if scene != null and scene.can_instantiate():
		_tower_runner_panel = scene.instantiate()
		_tower_runner_panel.name = "TowerRunner"
		_tower_runner_panel.hide()
		add_child(_tower_runner_panel)
	if _tower_runner_panel.has_signal("tower_completed") and not _tower_runner_panel.tower_completed.is_connected(_on_tower_runner_completed):
		_tower_runner_panel.tower_completed.connect(_on_tower_runner_completed)
	if _tower_runner_panel.has_signal("tower_event_resolved") and not _tower_runner_panel.tower_event_resolved.is_connected(_on_tower_runner_event_resolved):
		_tower_runner_panel.tower_event_resolved.connect(_on_tower_runner_event_resolved)
	if _tower_runner_panel.has_signal("returned_to_hub") and not _tower_runner_panel.returned_to_hub.is_connected(_on_tower_runner_returned):
		_tower_runner_panel.returned_to_hub.connect(_on_tower_runner_returned)


func _setup_settings_panel() -> void:
	var scene = load("res://scenes/ui/settings_menu.tscn")
	if scene != null and scene.can_instantiate():
		_settings_panel = scene.instantiate()
		_settings_panel.hide()
		add_child(_settings_panel)


func _setup_sleep_confirm_dialog() -> void:
	if _sleep_confirm_dialog != null:
		return
	_sleep_confirm_dialog = ConfirmationDialog.new()
	_sleep_confirm_dialog.name = "SleepConfirmDialog"
	_sleep_confirm_dialog.title = "入梦"
	_sleep_confirm_dialog.dialog_text = "现在入梦？（推进到次日，AP 重置，自动存档）"
	_sleep_confirm_dialog.confirmed.connect(_confirm_sleep)
	_sleep_confirm_dialog.canceled.connect(_cancel_sleep)
	add_child(_sleep_confirm_dialog)


func _setup_placeholder_dialog() -> void:
	if _placeholder_dialog != null:
		return
	_placeholder_dialog = AcceptDialog.new()
	_placeholder_dialog.name = "HubPlaceholderDialog"
	_placeholder_dialog.title = "暂未开放"
	add_child(_placeholder_dialog)


func _setup_npc_dialog() -> void:
	if _npc_dialog != null:
		return
	_npc_dialog = AcceptDialog.new()
	_npc_dialog.name = "NpcDialogueDialog"
	_npc_dialog.title = "NPC"
	var visibility_callable := Callable(self, "_on_npc_dialog_visibility_changed")
	if _npc_dialog.has_signal("visibility_changed") and not _npc_dialog.is_connected("visibility_changed", visibility_callable):
		_npc_dialog.connect("visibility_changed", visibility_callable)
	add_child(_npc_dialog)
	_npc_portrait_rect = TextureRect.new()
	_npc_portrait_rect.name = "NpcPortraitTexture"
	_npc_portrait_rect.position = Vector2(12, 44)
	_npc_portrait_rect.custom_minimum_size = Vector2(128, 192)
	_npc_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc_portrait_rect.z_index = -1
	_npc_portrait_rect.visible = false
	_npc_dialog.add_child(_npc_portrait_rect)


func _setup_casino_dialog() -> void:
	if _casino_dialog != null:
		return
	_casino_dialog = AcceptDialog.new()
	_casino_dialog.name = "CasinoMenuDialog"
	_casino_dialog.title = "鳗鱼·凡的赌窟"
	add_child(_casino_dialog)


func _setup_auction_dialog() -> void:
	if _auction_dialog != null:
		return
	_auction_dialog = AcceptDialog.new()
	_auction_dialog.name = "AuctionDialog"
	_auction_dialog.title = "走私者拍卖会"
	add_child(_auction_dialog)


func _setup_job_dialog() -> void:
	if _job_dialog != null:
		return
	_job_dialog = AcceptDialog.new()
	_job_dialog.name = "JobDialog"
	_job_dialog.title = "打工入口"
	add_child(_job_dialog)


func _setup_drill_dialog() -> void:
	if _drill_dialog != null:
		return
	_drill_dialog = AcceptDialog.new()
	_drill_dialog.name = "DrillDialog"
	_drill_dialog.title = "演练入口"
	add_child(_drill_dialog)


func _setup_rumor_dialog() -> void:
	if _rumor_dialog != null:
		return
	_rumor_dialog = AcceptDialog.new()
	_rumor_dialog.name = "RumorDialog"
	_rumor_dialog.title = "街角消息"
	add_child(_rumor_dialog)


func _setup_gray_crown_daily_dialog() -> void:
	if _gray_crown_daily_dialog != null:
		return
	var scene = load(GRAY_CROWN_DAILY_SCENE)
	if scene != null and scene.can_instantiate():
		_gray_crown_daily_dialog = scene.instantiate()
		_gray_crown_daily_dialog.name = "GrayCrownDailyDialog"
		_gray_crown_daily_dialog.hide()
		add_child(_gray_crown_daily_dialog)


func _setup_promotion_ready_dialog() -> void:
	if _promotion_ready_dialog != null:
		return
	_promotion_ready_dialog = AcceptDialog.new()
	_promotion_ready_dialog.name = "PromotionReadyDialog"
	_promotion_ready_dialog.title = "可以晋升了"
	add_child(_promotion_ready_dialog)


func _setup_mainline_dialog() -> void:
	if _mainline_dialog != null:
		return
	_mainline_dialog = AcceptDialog.new()
	_mainline_dialog.name = "MainlineDialog"
	add_child(_mainline_dialog)


func _show_ai_gm_text(title: String, text: String) -> void:
	var clean := str(text).strip_edges()
	if clean == "":
		return
	_setup_mainline_dialog()
	_mainline_dialog.title = title if str(title).strip_edges() != "" else "AI GM"
	_mainline_dialog.dialog_text = clean
	if is_inside_tree():
		_mainline_dialog.popup_centered()
	else:
		_mainline_dialog.show()


func _setup_debug_panel() -> void:
	var scene = load("res://scenes/ui/debug_panel.tscn")
	if scene != null and scene.can_instantiate():
		_debug_panel = scene.instantiate()
		_debug_panel.hide()
		add_child(_debug_panel)
		if _debug_panel.has_method("attach"):
			_debug_panel.attach(self)


func _setup_pollution_hud() -> void:
	if _pollution_hud == null or not is_instance_valid(_pollution_hud):
		_pollution_hud = HudScript.new()
		_pollution_hud.name = "PollutionHud"
		_pollution_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pollution_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_pollution_hud)
	if _pollution_hud.has_method("bind_game_state"):
		_pollution_hud.call("bind_game_state", GameState)


func _setup_lost_control_visual() -> void:
	_lost_control_background_tint = _ensure_lost_control_overlay()
	_configure_full_rect_control(_lost_control_background_tint)


func _ensure_lost_control_overlay() -> ColorRect:
	var existing := get_node_or_null("LostControlOverlay")
	if existing is ColorRect:
		_ensure_legacy_lost_control_tint()
		return existing as ColorRect
	if _lost_control_background_tint != null and is_instance_valid(_lost_control_background_tint):
		if _lost_control_background_tint.name == "LostControlOverlay":
			_ensure_legacy_lost_control_tint()
			return _lost_control_background_tint
		_lost_control_background_tint = null
	var rect := ColorRect.new()
	rect.name = "LostControlOverlay"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.55, 0.05, 0.05, 0.0)
	rect.hide()
	add_child(rect)
	_move_above_hub_background(rect)
	_ensure_legacy_lost_control_tint()
	return rect


func _ensure_legacy_lost_control_tint() -> ColorRect:
	var legacy := get_node_or_null("LostControlBackgroundTint")
	if legacy is ColorRect:
		legacy.hide()
		legacy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legacy.self_modulate = Color(1, 1, 1, 0)
		_configure_full_rect_control(legacy)
		return legacy as ColorRect
	var rect := ColorRect.new()
	rect.name = "LostControlBackgroundTint"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.55, 0.05, 0.05, 0.0)
	rect.self_modulate = Color(1, 1, 1, 0)
	rect.hide()
	add_child(rect)
	_move_above_hub_background(rect)
	_configure_full_rect_control(rect)
	return rect


func _move_above_hub_background(control: Control) -> void:
	if control == null or control.get_parent() != self:
		return
	var background := get_node_or_null("HubBackground")
	if background != null and background.get_parent() == self:
		move_child(control, mini(background.get_index() + 1, get_child_count() - 1))
	else:
		move_child(control, 0)


func _configure_full_rect_control(control: Control) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _on_debug_pressed() -> void:
	Sfx.play("ui_click")
	if _debug_panel == null:
		return
	if _debug_panel.has_method("toggle"):
		_debug_panel.toggle()
	_refresh_status()


func _setup_status_bar() -> void:
	var bar = $MarginContainer/VBoxContainer/StatusBar
	if bar is HBoxContainer:
		bar.add_theme_constant_override("separation", 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_day = bar.get_node("DayLabel")
	_status_ap = bar.get_node("ApLabel")
	_status_pollution = bar.get_node("PollutionLabel")
	_status_lingstones = bar.get_node("LingstonesLabel")
	_status_church_awareness = Label.new()
	_status_church_awareness.name = "ChurchAwarenessLabel"
	_status_church_awareness.custom_minimum_size = Vector2(96, 28)
	bar.add_child(_status_church_awareness)
	bar.move_child(_status_church_awareness, _status_lingstones.get_index())
	for label in [_status_day, _status_ap, _status_pollution, _status_church_awareness, _status_lingstones]:
		if label is Label:
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_lingstones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intel_info_button = Button.new()
	_intel_info_button.name = "IntelInfoButton"
	_intel_info_button.text = "情报 [0]"
	_intel_info_button.custom_minimum_size = Vector2(82, 28)
	_intel_info_button.pressed.connect(_on_intel_info_pressed)
	bar.add_child(_intel_info_button)
	_pseudo_god_contract_button = Button.new()
	_pseudo_god_contract_button.name = "PseudoGodContractButton"
	_pseudo_god_contract_button.text = "契约·已守0/5"
	_pseudo_god_contract_button.custom_minimum_size = Vector2(108, 28)
	_pseudo_god_contract_button.pressed.connect(_on_pseudo_god_contract_pressed)
	_pseudo_god_contract_button.hide()
	bar.add_child(_pseudo_god_contract_button)
	_gray_crown_daily_button = Button.new()
	_gray_crown_daily_button.name = "GrayCrownDailyButton"
	_gray_crown_daily_button.text = "灰冠日报"
	_gray_crown_daily_button.custom_minimum_size = Vector2(96, 44)
	_gray_crown_daily_button.focus_mode = Control.FOCUS_ALL
	_gray_crown_daily_button.pressed.connect(_on_gray_crown_daily_pressed)
	bar.add_child(_gray_crown_daily_button)
	_promotion_button = Button.new()
	_promotion_button.name = "PromotionButton"
	_promotion_button.text = "晋升仪式"
	_promotion_button.custom_minimum_size = Vector2(96, 28)
	_promotion_button.pressed.connect(_on_promotion_pressed)
	_promotion_button.hide()
	bar.add_child(_promotion_button)
	_promotion_progress_label = Label.new()
	_promotion_progress_label.name = "PromotionProgressLabel"
	_promotion_progress_label.hide()
	bar.add_child(_promotion_progress_label)
	_window_label = $MarginContainer/VBoxContainer/WindowLabel
	var debug_btn = $MarginContainer/VBoxContainer/DebugBar.get_node_or_null("DebugButton") if has_node("MarginContainer/VBoxContainer/DebugBar") else null
	if debug_btn != null:
		debug_btn.pressed.connect(_on_debug_pressed)


func _connect_game_state_signals() -> void:
	if not is_instance_valid(GameState):
		return
	if GameState.has_signal("ap_changed") and not GameState.ap_changed.is_connected(_on_game_state_ap_changed):
		GameState.ap_changed.connect(_on_game_state_ap_changed)


func _refresh_status() -> void:
	if not is_instance_valid(GameState):
		return
	var gs = GameState
	_status_day.text = "第 %d 天 · %s" % [gs.day, _time_label_zh(str(gs.time_of_day))]
	_status_ap.text = "AP %d/%d" % [gs.ap, gs.ap_max]
	_status_pollution.text = "污染 %d%%" % gs.pollution
	if _status_church_awareness != null:
		_status_church_awareness.text = "\u6559\u4f1a\u8b66\u89c9 %d%%" % int(gs.church_awareness)
	var pages := int(gs.forge_materials.get("愚者残页", 0))
	_status_lingstones.text = "灵石 %d · 残页 %d · 卡库 %d · 烙印 %d · 愚者残页 %d" % [
		gs.lingstones, gs.dao_pages, gs.cards_inventory.size(), gs.brands_inventory.size(), pages,
	]
	_window_label.text = window_observation_text(gs)
	_refresh_lost_control_visual(gs)
	_refresh_intel_info_button()
	_refresh_pseudo_god_contract_button()
	_refresh_gray_crown_daily_button()
	_refresh_church_threshold_prompt()
	_refresh_activity_gates()
	_refresh_r20_visitor_buttons()
	_refresh_hotspot_clock_tooltip()


func _on_game_state_ap_changed(_current_ap: int, _max_ap: int) -> void:
	_refresh_status()


func _refresh_intel_info_button() -> void:
	if _intel_info_button == null or not is_instance_valid(GameState):
		return
	var lines := _intel_display_lines(GameState)
	var active := _active_rumors(GameState)
	_intel_info_button.text = "情报 [%d]" % active.size()
	_intel_info_button.tooltip_text = "\n".join(lines)


func _refresh_r20_visitor_buttons() -> void:
	if not is_instance_valid(GameState):
		return
	var bar = get_node_or_null("MarginContainer/VBoxContainer/StatusBar")
	if not bar is HBoxContainer:
		return
	var arrived := _arrived_r20_visitors()
	var desired: Array[String] = []
	for visitor in arrived:
		var npc_id := str(visitor.get("npc_id", "")).strip_edges()
		if npc_id == "":
			continue
		var button_name := "R20VisitorButton_%s" % _safe_node_suffix(npc_id)
		desired.append(button_name)
		var button = bar.get_node_or_null(button_name)
		if not button is Button:
			button = Button.new()
			button.name = button_name
			button.custom_minimum_size = Vector2(96, 28)
			button.focus_mode = Control.FOCUS_ALL
			bar.add_child(button)
		var visitor_button := button as Button
		var display_name := _r20_visitor_display_name(visitor)
		visitor_button.text = "\u8bbf\u5ba2\uff1a%s" % display_name
		visitor_button.tooltip_text = "\u8bbf\u5ba2\u5230\u8bbf\uff1a%s" % display_name
		visitor_button.visible = true
		for connection in visitor_button.pressed.get_connections():
			if connection is Dictionary and connection.has("callable"):
				visitor_button.pressed.disconnect(connection["callable"])
		visitor_button.pressed.connect(_on_r20_visitor_pressed.bind(visitor.duplicate(true)))
	for child in bar.get_children():
		if not child is Button:
			continue
		if not str(child.name).begins_with("R20VisitorButton_"):
			continue
		if not desired.has(str(child.name)):
			bar.remove_child(child)
			child.queue_free()


func _arrived_r20_visitors() -> Array:
	var result: Array = []
	if not is_instance_valid(GameState) or not GameState.has_method("get_meta"):
		return result
	var value: Variant = GameState.get_meta("r20_pending_visitors", [])
	if not value is Array:
		return result
	for item in value:
		if not item is Dictionary:
			continue
		var visitor: Dictionary = (item as Dictionary).duplicate(true)
		if int(visitor.get("arrives_at_day", 0)) <= int(GameState.day):
			result.append(visitor)
	return result


func _on_r20_visitor_pressed(visitor: Dictionary) -> void:
	_setup_r20_visitor_dialog()
	var display_name := _r20_visitor_display_name(visitor)
	var message := str(visitor.get("message", visitor.get("text", ""))).strip_edges()
	if message == "":
		message = "\u8bbf\u5ba2\u5df2\u5230\u8fbe\u6d1e\u5e9c\u3002"
	_r20_visitor_dialog.title = "\u8bbf\u5ba2"
	_r20_visitor_dialog.dialog_text = "%s\n%s" % [display_name, message]
	if is_inside_tree():
		_r20_visitor_dialog.popup_centered()
	else:
		_r20_visitor_dialog.show()


func _setup_r20_visitor_dialog() -> void:
	if _r20_visitor_dialog != null:
		return
	_r20_visitor_dialog = AcceptDialog.new()
	_r20_visitor_dialog.name = "R20VisitorDialog"
	_r20_visitor_dialog.title = "\u8bbf\u5ba2"
	add_child(_r20_visitor_dialog)


func _r20_visitor_display_name(visitor: Dictionary) -> String:
	var display_name := str(visitor.get("display_name", visitor.get("name", ""))).strip_edges()
	if display_name != "":
		return display_name
	var npc_id := str(visitor.get("npc_id", "")).strip_edges()
	if npc_id == "":
		return "\u8bbf\u5ba2"
	return npc_id


func _safe_node_suffix(value: String) -> String:
	var suffix := value.strip_edges()
	for ch in [" ", "/", "\\", ":", ".", "[", "]"]:
		suffix = suffix.replace(ch, "_")
	if suffix == "":
		suffix = "visitor"
	return suffix


func _on_intel_info_pressed() -> void:
	Sfx.play("ui_click")
	_setup_intel_info_dialog()
	_intel_info_dialog.title = "情报"
	_intel_info_dialog.dialog_text = _join_lines(_intel_display_lines(GameState))
	if is_inside_tree():
		_intel_info_dialog.popup_centered()
	else:
		_intel_info_dialog.show()


func _refresh_pseudo_god_contract_button() -> void:
	if _pseudo_god_contract_button == null or not is_instance_valid(GameState):
		return
	var contract := _pseudo_god_contract()
	var signed := bool(contract.get("unlocked", false))
	_pseudo_god_contract_button.visible = signed
	if not signed:
		return
	var total := _pseudo_god_rule_ids(contract).size()
	var satisfied := _pseudo_god_satisfied_count(contract)
	_pseudo_god_contract_button.text = "契约·已守%d/%d" % [satisfied, total]
	_pseudo_god_contract_button.tooltip_text = _join_lines(_pseudo_god_contract_lines(contract))


func _setup_pseudo_god_contract_dialog() -> void:
	if _pseudo_god_contract_dialog != null:
		return
	_pseudo_god_contract_dialog = AcceptDialog.new()
	_pseudo_god_contract_dialog.name = "PseudoGodContractDialog"
	_pseudo_god_contract_dialog.title = "伪神契约"
	add_child(_pseudo_god_contract_dialog)


func _on_pseudo_god_contract_pressed() -> void:
	Sfx.play("ui_click")
	_setup_pseudo_god_contract_dialog()
	var contract := _pseudo_god_contract()
	_pseudo_god_contract_dialog.dialog_text = _join_lines(_pseudo_god_contract_lines(contract))
	if is_inside_tree():
		_pseudo_god_contract_dialog.popup_centered()
	else:
		_pseudo_god_contract_dialog.show()


func _pseudo_god_contract() -> Dictionary:
	if not is_instance_valid(GameState):
		return {}
	var value: Variant = GameState.get("pseudo_god_contract")
	return value.duplicate(true) if value is Dictionary else {}


func _pseudo_god_contract_lines(contract: Dictionary) -> Array[String]:
	var lines: Array[String] = ["伪神契约"]
	var rule_ids := _pseudo_god_rule_ids(contract)
	if rule_ids.is_empty():
		lines.append("未签契约")
		return lines
	for rule_id in rule_ids:
		lines.append("%s：%s" % [rule_id, _pseudo_god_rule_status(rule_id, contract)])
	return lines


func _pseudo_god_rule_ids(contract: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw_rules: Variant = contract.get("rule_ids", [])
	if raw_rules is Array:
		for rule in raw_rules:
			var id := str(rule)
			if id != "" and not result.has(id):
				result.append(id)
			if result.size() >= 5:
				return result
	if is_instance_valid(GameState):
		for rule in GameState.active_contract:
			var id := str(rule)
			if id != "" and not result.has(id):
				result.append(id)
			if result.size() >= 5:
				return result
	return result


func _pseudo_god_satisfied_count(contract: Dictionary) -> int:
	var count := 0
	for rule_id in _pseudo_god_rule_ids(contract):
		if _pseudo_god_rule_status(rule_id, contract) == "已遵守":
			count += 1
	return count


func _pseudo_god_rule_status(rule_id: String, contract: Dictionary) -> String:
	if bool(contract.get("strictly_observed", false)):
		return "已遵守"
	var rule_states: Dictionary = contract.get("rule_states", {}) if contract.get("rule_states", {}) is Dictionary else {}
	if rule_states.has(rule_id):
		match str(rule_states.get(rule_id, "")):
			"satisfied", "observed", "kept", "已遵守":
				return "已遵守"
			"violated", "broken", "已违反":
				return "已违反"
	var satisfied: Array = contract.get("satisfied_rule_ids", []) if contract.get("satisfied_rule_ids", []) is Array else []
	for value in satisfied:
		if str(value) == rule_id:
			return "已遵守"
	var violated: Array = contract.get("violated_rule_ids", []) if contract.get("violated_rule_ids", []) is Array else []
	for value in violated:
		if str(value) == rule_id:
			return "已违反"
	return "未触发"


func _refresh_gray_crown_daily_button() -> void:
	if _gray_crown_daily_button == null or not is_instance_valid(GameState):
		return
	var week_index := IntelServiceScript.new().gray_crown_week_index(GameState)
	_gray_crown_daily_button.tooltip_text = "灰冠日报：第 %d 周周报" % [week_index + 1]


func _refresh_church_threshold_prompt() -> void:
	if not is_instance_valid(GameState) or not GameState.has_method("get_meta"):
		return
	var pending: Array[int] = []
	for threshold in [10, 25, 50]:
		if _church_threshold_pending(threshold):
			pending.append(threshold)
	if pending.is_empty():
		return
	_setup_mainline_dialog()
	var lines: Array[String] = []
	for threshold in pending:
		var event := _church_threshold_event(threshold)
		if event.is_empty():
			continue
		var label := _church_threshold_label(threshold)
		if label != "":
			lines.append(label)
		var ai_gm_text := str(event.get("ai_gm_text", "")).strip_edges()
		if ai_gm_text != "":
			lines.append(ai_gm_text)
		_clear_church_threshold_meta(threshold)
	if lines.is_empty():
		return
	_mainline_dialog.title = "教会查觉"
	_mainline_dialog.dialog_text = _join_lines(lines)
	_hide_threshold_blocking_dialogs()
	if is_inside_tree():
		_mainline_dialog.popup_centered()
	else:
		_mainline_dialog.show()


func _hide_threshold_blocking_dialogs() -> void:
	for dialog in [
		_placeholder_dialog,
		_casino_dialog,
		_auction_dialog,
		_job_dialog,
		_drill_dialog,
		_npc_dialog,
		_rumor_dialog,
		_intel_info_dialog,
	]:
		if dialog != null and dialog.visible:
			dialog.hide()


func _church_threshold_pending(threshold: int) -> bool:
	match threshold:
		10:
			return bool(GameState.get_meta("church_investigator_visit_pending", false))
		25:
			return bool(GameState.get_meta("church_threshold_25_mainline_pending", false))
		50:
			return bool(GameState.get_meta("church_boss_eve_pending", false))
		_:
			return false


func _church_threshold_event(threshold: int) -> Dictionary:
	for event in GameState.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return (event as Dictionary)
	return {}


func _church_threshold_label(threshold: int) -> String:
	match threshold:
		10:
			return "教会侦缉者来访"
		25:
			return "主教调查"
		50:
			return "清剿前夜"
		_:
			return "教会查觉"


func _clear_church_threshold_meta(threshold: int) -> void:
	if not is_instance_valid(GameState) or not GameState.has_method("remove_meta"):
		return
	match threshold:
		10:
			if GameState.has_meta("church_investigator_visit_pending"):
				GameState.remove_meta("church_investigator_visit_pending")
		25:
			if GameState.has_meta("church_threshold_25_mainline_pending"):
				GameState.remove_meta("church_threshold_25_mainline_pending")
			if GameState.has_meta("church_threshold_25_mainline_node_id"):
				GameState.remove_meta("church_threshold_25_mainline_node_id")
		50:
			if GameState.has_meta("church_boss_eve_pending"):
				GameState.remove_meta("church_boss_eve_pending")
			if GameState.has_meta("church_boss_event_id"):
				GameState.remove_meta("church_boss_event_id")


func _on_gray_crown_daily_pressed() -> void:
	Sfx.play("ui_click")
	_open_gray_crown_daily("manual")


func _open_gray_crown_daily(source: String = "manual") -> Dictionary:
	_setup_gray_crown_daily_dialog()
	if _gray_crown_daily_dialog == null or not _gray_crown_daily_dialog.has_method("open"):
		_show_placeholder("灰冠日报暂时无法打开。")
		return {"ok": false, "reason": "missing_dialog"}
	var service = IntelServiceScript.new()
	var result: Dictionary = service.claim_gray_crown_daily(GameState, _gray_crown_daily_seed(source), source)
	if not bool(result.get("ok", false)):
		_show_placeholder("灰冠日报暂时没有可读版面。")
		return result
	_gray_crown_daily_dialog.call("open", result)
	_refresh_status()
	return result


func try_auto_push_gray_crown_daily(seed: int = -1) -> Dictionary:
	_setup_gray_crown_daily_dialog()
	var service = IntelServiceScript.new()
	var actual_seed := _gray_crown_daily_seed("auto_push") if seed < 0 else seed
	var result: Dictionary = service.auto_push_gray_crown_daily_if_due(GameState, actual_seed)
	if bool(result.get("pushed", false)) and _gray_crown_daily_dialog != null and _gray_crown_daily_dialog.has_method("open"):
		_gray_crown_daily_dialog.call("open", result)
	_refresh_status()
	return result


func _gray_crown_daily_seed(source: String) -> int:
	if not is_instance_valid(GameState):
		return 0
	return absi(hash("%d:%d:%s:gray_crown_daily" % [int(GameState.cycle), int(GameState.day), source]))


func _setup_intel_info_dialog() -> void:
	if _intel_info_dialog != null:
		return
	_intel_info_dialog = AcceptDialog.new()
	_intel_info_dialog.name = "IntelInfoDialog"
	_intel_info_dialog.title = "情报"
	add_child(_intel_info_dialog)


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


func _refresh_activity_gates() -> void:
	if not is_instance_valid(GameState):
		return
	var check: Dictionary = MeditationServiceScript.can_start(GameState)
	var reason := str(check.get("reason", ""))
	var is_available := bool(check.get("ok", false))
	var legacy_cushion = get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/CushionButton")
	if legacy_cushion is Button:
		(legacy_cushion as Button).disabled = not is_available
		(legacy_cushion as Button).text = _meditation_button_text(reason)
		(legacy_cushion as Button).tooltip_text = _meditation_gate_text(reason)
	var hotspot_cushion = get_node_or_null("HubHotspotLayer/CushionButton")
	if hotspot_cushion is BaseButton:
		(hotspot_cushion as BaseButton).disabled = not is_available
		(hotspot_cushion as BaseButton).tooltip_text = str(HUB_HOTSPOTS["CushionButton"].get("tooltip", ""))


func _meditation_button_text(reason: String) -> String:
	match reason:
		"ap_short":
			return "蒲团（AP不足/需3）"
		"daily_limit":
			return "蒲团（今日已满）"
		_:
			return "蒲团"


func _meditation_gate_text(reason: String) -> String:
	match reason:
		"ap_short":
			return "AP 不足：修炼需要 3 AP"
		"daily_limit":
			return "今日修炼已达 3 次"
		_:
			return "蒲团修炼（消耗 3 AP）"


func _refresh_promotion_button() -> void:
	if _promotion_button == null or not is_instance_valid(GameState):
		return
	var service = load(PROMOTION_SERVICE_PATH)
	if service == null:
		_promotion_button.hide()
		_hide_promotion_progress()
		return
	var gate_id: String = service.next_gate_id(GameState)
	var gate: Dictionary = _load_promotion_gate_data(gate_id)
	_refresh_promotion_progress(gate_id, gate)
	var day10_highlight: bool = int(GameState.day) == 10 or bool(GameState.get_meta("promotion_day10_highlight", false))
	_promotion_button.text = "晋升仪式（Day10）" if day10_highlight else "晋升仪式"
	var visual_day10: bool = int(GameState.day) == 10
	if visual_day10:
		_promotion_button.modulate = Color(1.0, 0.85, 0.4)
		var highlight_style := StyleBoxFlat.new()
		highlight_style.bg_color = Color(0.22, 0.17, 0.05, 1.0)
		highlight_style.border_color = Color(1.0, 0.86, 0.45, 1.0)
		highlight_style.border_width_left = 2
		highlight_style.border_width_top = 2
		highlight_style.border_width_right = 2
		highlight_style.border_width_bottom = 2
		_promotion_button.add_theme_stylebox_override("normal", highlight_style)
	else:
		_promotion_button.modulate = Color.WHITE
		_promotion_button.remove_theme_stylebox_override("normal")
	var can_start: bool = gate_id != "" and bool(service.can_start_ritual(gate_id, GameState))
	_promotion_button.visible = can_start
	_maybe_show_promotion_ready_prompt(gate_id, can_start)


func _refresh_promotion_progress(gate_id: String, gate: Dictionary) -> void:
	if _promotion_progress_label == null:
		return
	if gate_id == "" or gate.is_empty():
		_hide_promotion_progress()
		return
	var from_sequence := int(gate.get("from_sequence", GameState.sequence))
	var to_sequence := int(gate.get("to_sequence", maxi(from_sequence - 1, 0)))
	var exp_required := int(gate.get("sequence_exp_required", 0))
	var reactions_required := int(gate.get("reactions_required", 0))
	var pollution_max := int(gate.get("pollution_max", 0))
	var exp_remaining := maxi(0, exp_required - int(GameState.sequence_exp))
	var reaction_remaining := maxi(0, reactions_required - GameState.known_reactions.size())
	_promotion_progress_label.text = "晋升 %d→%d：还差 %d 经验 / 还差 %d 反应 / 污染上限 %d（当前 %d）" % [
		from_sequence,
		to_sequence,
		exp_remaining,
		reaction_remaining,
		pollution_max,
		int(GameState.pollution),
	]
	var current_exp := int(GameState.sequence_exp)
	var current_reactions := GameState.known_reactions.size()
	_promotion_progress_label.text = "晋升 %d→%d：经验 %d/%d（还差 %d 经验） / 反应 %d/%d（还差 %d 反应） / 污染 ≤%d（当前 %d）" % [
		from_sequence,
		to_sequence,
		current_exp,
		exp_required,
		exp_remaining,
		current_reactions,
		reactions_required,
		reaction_remaining,
		pollution_max,
		int(GameState.pollution),
	]
	_promotion_progress_label.show()


func _maybe_show_promotion_ready_prompt(gate_id: String, can_start: bool) -> void:
	if gate_id == "" or not can_start:
		return
	if not bool(GameState.get_meta("promotion_prompt_pending", false)):
		return
	_setup_promotion_ready_dialog()
	_promotion_ready_dialog.title = "可以晋升了"
	_promotion_ready_dialog.dialog_text = "可以晋升了。点击状态栏里的晋升仪式按钮进入仪式塔。"
	GameState.set_meta("promotion_prompt_pending", false)
	GameState.set_meta("promotion_prompt_gate_id", "")
	if is_inside_tree():
		_promotion_ready_dialog.popup_centered()
	else:
		_promotion_ready_dialog.show()


func _hide_promotion_progress() -> void:
	if _promotion_progress_label != null:
		_promotion_progress_label.hide()


func _load_promotion_gate_data(gate_id: String) -> Dictionary:
	if gate_id == "":
		return {}
	var path := "%s%s.json" % [PROMOTION_GATE_DIR, gate_id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _time_label_zh(time_id: String) -> String:
	match time_id:
		"morning": return "白天"
		"noon": return "正午"
		"evening": return "黄昏"
		"night": return "夜晚"
		_: return time_id


func lost_control_visual_state(game_state) -> Dictionary:
	var motifs: Array = ["shadow_consumes_body", "split_doubles", "open_doors"]
	if game_state != null:
		var state: Dictionary = game_state.lost_control_state if game_state.lost_control_state is Dictionary else {}
		var raw_motifs: Variant = state.get("visual_motifs", [])
		if raw_motifs is Array and not raw_motifs.is_empty():
			motifs = raw_motifs.duplicate()
	return {
		"background_state": "lost_control",
		"visual_motifs": motifs,
		"hud_pressure": "red_top",
		"sprite_state": "shadow_consumes_body",
	}


func _refresh_lost_control_visual(game_state) -> void:
	_setup_lost_control_visual()
	if _lost_control_background_tint == null:
		return
	var lost_control_active := false
	if game_state != null:
		lost_control_active = bool(game_state.is_lost_control) or int(game_state.pollution_stage) >= 5 or int(game_state.pollution) >= 100
	if not lost_control_active:
		_lost_control_background_tint.hide()
		_lost_control_background_tint.color = Color(0.55, 0.05, 0.05, 0.0)
		_refresh_legacy_lost_control_tint(false)
		return
	var state := lost_control_visual_state(game_state)
	_lost_control_background_tint.show()
	_lost_control_background_tint.color = Color(0.55, 0.05, 0.05, 0.35)
	_refresh_legacy_lost_control_tint(true)
	_lost_control_background_tint.tooltip_text = "%s:%s" % [str(state.get("background_state", "lost_control")), ",".join(Array(state.get("visual_motifs", [])))]


func _refresh_legacy_lost_control_tint(active: bool) -> void:
	var legacy := _ensure_legacy_lost_control_tint()
	if legacy == null:
		return
	if active:
		legacy.show()
		legacy.color = Color(0.55, 0.05, 0.05, 0.35)
		legacy.self_modulate = Color(1, 1, 1, 0)
	else:
		legacy.hide()
		legacy.color = Color(0.55, 0.05, 0.05, 0.0)
		legacy.self_modulate = Color(1, 1, 1, 0)


func window_observation_text(game_state) -> String:
	var weather := _weather_label_for_state(game_state)
	var time_label := _time_label_zh(str(game_state.time_of_day)) if game_state != null else "morning"
	var text := "窗外：%s · %s" % [weather, time_label]
	if game_state != null and (int(game_state.pollution_stage) >= 5 or int(game_state.pollution) >= 100):
		text += " · 玻璃里站着另一个你"
	return text


func _weather_label_for_state(gs) -> String:
	if not is_instance_valid(gs):
		return "阴天"
	var weather_id := str(gs.current_weather)
	if weather_id != "":
		return _weather_display_name(weather_id)
	var stage = gs.pollution_stage
	if stage >= 4:
		return "暴雨"
	elif stage >= 2:
		return "阴天"
	return "晴"


func _weather_label() -> String:
	var gs = GameState
	if not is_instance_valid(gs):
		return "阴天"
	var weather_id := str(gs.current_weather)
	if weather_id != "":
		return _weather_display_name(weather_id)
	var stage = gs.pollution_stage
	if stage >= 4:
		return "暴雨"
	elif stage >= 2:
		return "阴天"
	else:
		return "晴"


func _weather_display_name(weather_id: String) -> String:
	match weather_id:
		"sunny": return "晴"
		"fog": return "雾"
		"rain": return "雨"
		"storm": return "暴风"
		"full_moon": return "月圆"
		_: return weather_id


func _try_force_sleep_before_action() -> bool:
	if not is_instance_valid(GameState):
		return false
	if not bool(GameState.get_meta("force_sleep_pending", false)):
		return false
	_show_forced_sleep_prompt()
	return true


func _show_forced_sleep_prompt() -> void:
	_setup_sleep_confirm_dialog()
	_sleep_force_active = true
	if GameState.has_method("set_meta"):
		GameState.set_meta("force_sleep_pending", true)
	_sleep_confirm_dialog.title = "必须入梦"
	_sleep_confirm_dialog.dialog_text = "夜深了，必须入梦。确认后将进入梦境并推进到次日清晨。"
	_set_sleep_cancel_available(false)
	if is_inside_tree():
		_sleep_confirm_dialog.popup_centered()
	else:
		_sleep_confirm_dialog.show()


func _set_sleep_cancel_available(available: bool) -> void:
	if _sleep_confirm_dialog == null:
		return
	var cancel_button := _sleep_confirm_dialog.get_cancel_button()
	if cancel_button == null:
		return
	cancel_button.disabled = not available
	cancel_button.visible = available


func _show_morning_summary(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	var lines: Array[String] = []
	var dream: Dictionary = result.get("dream", {})
	if not dream.is_empty():
		var dream_title := str(dream.get("title", ""))
		var dream_text := str(dream.get("text", ""))
		if dream_title != "":
			lines.append(dream_title)
		if dream_text != "":
			lines.append(dream_text)
	var visitor: Dictionary = result.get("visitor", {})
	if not visitor.is_empty():
		var visitor_name := str(visitor.get("display_name", ""))
		var visitor_text := str(visitor.get("text", ""))
		if visitor_name != "" or visitor_text != "":
			lines.append("%s：%s" % [visitor_name, visitor_text])
	var day_hook: Dictionary = result.get("day_hook", {})
	if bool(day_hook.get("triggered", false)):
		var hook_title := str(day_hook.get("title", ""))
		var hook_text := str(day_hook.get("popup_text", ""))
		if hook_title != "":
			lines.append(hook_title)
		if hook_text != "":
			lines.append(hook_text)
	if lines.is_empty():
		return
	_setup_placeholder_dialog()
	_placeholder_dialog.title = "晨起"
	_placeholder_dialog.dialog_text = _join_lines(lines)
	if is_inside_tree():
		_placeholder_dialog.popup_centered()
	else:
		_placeholder_dialog.show()


func _show_mainline_prompt(day_hook: Dictionary) -> void:
	if not bool(day_hook.get("triggered", false)):
		return
	_setup_mainline_dialog()
	var day := int(day_hook.get("day", GameState.day))
	var hook_title := str(day_hook.get("title", ""))
	var hook_text := str(day_hook.get("popup_text", ""))
	if hook_text == "" and GameState.has_method("get_meta"):
		hook_text = str(GameState.get_meta("mainline_popup_text", ""))
	if hook_title == "" and GameState.has_method("get_meta"):
		hook_title = str(GameState.get_meta("mainline_popup_title", ""))
	var ai_gm_text := ""
	if GameState.has_method("get_meta"):
		ai_gm_text = str(GameState.get_meta("mainline_ai_gm_text", ""))
	_mainline_dialog.title = "主线·Day%d" % day
	var lines: Array[String] = []
	if hook_title != "":
		lines.append(hook_title)
	if hook_text != "" and hook_text != hook_title:
		lines.append(hook_text)
	if ai_gm_text != "":
		lines.append(ai_gm_text)
	_mainline_dialog.dialog_text = _join_lines(lines)
	if _placeholder_dialog != null and _placeholder_dialog.visible:
		_placeholder_dialog.hide()
	if GameState.has_method("remove_meta"):
		for key in ["mainline_popup_pending", "mainline_popup_text", "mainline_popup_title", "mainline_day", "mainline_ai_gm_text"]:
			if GameState.has_meta(key):
				GameState.remove_meta(key)
	if is_inside_tree():
		_mainline_dialog.popup_centered()
	else:
		_mainline_dialog.show()


func _on_tower_runner_returned(reason: String) -> void:
	if reason != "completed":
		return
	if _show_tower_return_ai_gm_prompt():
		return


func _show_tower_return_ai_gm_prompt() -> bool:
	if not is_instance_valid(GameState) or not GameState.has_method("get_meta"):
		return false
	var title := ""
	var lines: Array[String] = []
	var sequence_text := str(GameState.get_meta("sequence_promotion_ai_gm_text", "")).strip_edges()
	if sequence_text != "":
		title = "序列晋升"
		lines.append(sequence_text)
		_clear_tower_return_ai_gm_meta(["sequence_promotion_ai_gm_text"])
	else:
		var cycle_summary := str(GameState.get_meta("cycle_end_summary", "")).strip_edges()
		var cycle_text := str(GameState.get_meta("cycle_end_ai_gm_text", "")).strip_edges()
		if cycle_summary == "" and cycle_text == "":
			return false
		title = "周期结算"
		if cycle_summary != "":
			lines.append(cycle_summary)
		if cycle_text != "":
			lines.append(cycle_text)
		_clear_tower_return_ai_gm_meta(["cycle_end_summary", "cycle_end_ai_gm_text"])
	_setup_mainline_dialog()
	_mainline_dialog.title = title
	_mainline_dialog.dialog_text = _join_lines(lines)
	if _placeholder_dialog != null and _placeholder_dialog.visible:
		_placeholder_dialog.hide()
	if is_inside_tree():
		_mainline_dialog.popup_centered()
	else:
		_mainline_dialog.show()
	return true


func _clear_tower_return_ai_gm_meta(keys: Array[String]) -> void:
	if not is_instance_valid(GameState) or not GameState.has_method("remove_meta"):
		return
	for key in keys:
		if GameState.has_meta(key):
			GameState.remove_meta(key)


func _join_lines(lines: Array[String]) -> String:
	var text := ""
	for line in lines:
		if text != "":
			text += "\n"
		text += line
	return text


func _npc_interaction_service():
	var service = NpcInteractionServiceScript.new()
	if _ai_gm_service != null and service.has_method("set_ai_gm_service"):
		service.set_ai_gm_service(_ai_gm_service)
	if _drill_runner_override != null and service.has_method("set_drill_runner"):
		service.set_drill_runner(_drill_runner_override)
	return service


func _r20_effect_engine():
	var engine = R20EffectEngineScript.new()
	if _ai_gm_service != null and engine.has_method("set_ai_gm_service"):
		engine.set_ai_gm_service(_ai_gm_service)
	return engine


func _intel_service():
	var service = IntelServiceScript.new()
	if _ai_gm_service != null and service.has_method("set_ai_gm_service"):
		service.set_ai_gm_service(_ai_gm_service)
	return service


func _drill_runner():
	if _drill_runner_override != null:
		return _drill_runner_override
	var runner = DrillRunnerScript.new()
	if _ai_gm_service != null and runner.has_method("set_ai_gm_service"):
		runner.set_ai_gm_service(_ai_gm_service)
	return runner


func _append_npc_ai_gm_text(text: String) -> void:
	var trimmed := str(text).strip_edges()
	if trimmed == "" or _npc_dialog == null:
		return
	if str(_npc_dialog.dialog_text).strip_edges() == "":
		_npc_dialog.dialog_text = trimmed
	else:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), trimmed]


func _append_npc_state_summary(npc_id: String) -> void:
	if _npc_dialog == null or not is_instance_valid(GameState):
		return
	var summary := _npc_state_summary_text(npc_id)
	if summary == "":
		return
	if str(_npc_dialog.dialog_text).strip_edges() == "":
		_npc_dialog.dialog_text = summary
	else:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), summary]


func _npc_state_summary_text(npc_id: String) -> String:
	var state = GameState.npc_relations.get(npc_id, null) if is_instance_valid(GameState) else null
	if state == null:
		return ""
	var trust := int(state.get("trust")) if state is Object else int((state as Dictionary).get("trust", 0))
	var suspicion := int(state.get("suspicion")) if state is Object else int((state as Dictionary).get("suspicion", 0))
	var lines: Array[String] = ["\u72b6\u6001\uff1a\u4fe1\u4efb %d\uff0c\u6000\u7591 %d" % [trust, suspicion]]
	var perception := str(state.get("active_perception")) if state is Object else str((state as Dictionary).get("active_perception", ""))
	if perception != "" and perception != "harvey":
		var expires := int(state.get("perception_expires_at")) if state is Object else int((state as Dictionary).get("perception_expires_at", 0))
		var suffix := "\uff0c\u5230\u7b2c %d \u5929" % expires if expires > 0 else ""
		lines.append("\u4f2a\u88c5\uff1a%s%s" % [_npc_perception_label(perception), suffix])
	return "\n".join(lines)


func _npc_perception_label(perception: String) -> String:
	match perception:
		"stranger":
			return "\u964c\u751f\u4eba"
		"dead_brother":
			return "\u4ea1\u5144\u7684\u5f71\u5b50"
		"shadow_double":
			return "\u66ff\u8eab\u5f71"
		"borrowed_name":
			return "\u501f\u6765\u7684\u540d\u5b57"
		"forgotten":
			return "\u88ab\u62b9\u6389\u7684\u4eba"
		_:
			return perception


func _npc_identity_display_name(identity_id: String) -> String:
	if not is_instance_valid(GameState):
		return identity_id
	var identities = GameState.residual_identities
	for raw_identity in identities:
		if raw_identity is Dictionary:
			var data: Dictionary = raw_identity
			if str(data.get("id", "")) == identity_id:
				var name := str(data.get("name", data.get("display_name", ""))).strip_edges()
				return name if name != "" else identity_id
		elif raw_identity is Object and raw_identity.has_method("get"):
			if str(raw_identity.get("id")) == identity_id:
				var name := str(raw_identity.get("name")).strip_edges()
				if name == "":
					name = str(raw_identity.get("display_name")).strip_edges()
				return name if name != "" else identity_id
	return identity_id


func _minigame_name(game_id: String, fallback: String = "") -> String:
	match game_id:
		"dice_cup":
			return "骰盅"
		"tarot_divination":
			return "塔罗占卜"
		"fate_cards":
			return "命运牌局"
		"misty_port_weekly":
			return "雾港周末拍卖会"
		"factory_shift":
			return "工厂打工"
		"dock_shift":
			return "码头打工"
		"fishing_shift":
			return "钓鱼短工"
		"errand_runner":
			return "跑腿送信"
		"worship_observation":
			return "礼拜旁观"
		"mountain_solitary_walk":
			return "山中独行"
		"street_debate":
			return "街头辩论"
		"underground_signal":
			return "地下暗号"
		"smuggle_role":
			return "走私扮演"
		"confess_innocent":
			return "告解演练"
		"mirror_step":
			return "镜中影步"
		"foreman_dialogue":
			return "工头对答"
		"tavern_brag":
			return "酒馆吹牛"
		"noble_salon":
			return "贵族沙龙演练"
		_:
			if _has_cjk(fallback):
				return fallback
			return "未知活动"


func _job_name(job_id: String, definition: Dictionary = {}) -> String:
	var fallback := str(definition.get("display_name", ""))
	match job_id:
		"factory_shift":
			return "工厂打工"
		"dock_shift":
			return "码头打工"
		"fishing_shift":
			return "钓鱼短工"
		"errand_runner":
			return "跑腿送信"
		"worship_observation":
			return "礼拜旁观"
		"mountain_solitary_walk":
			return "山中独行"
		_:
			if _has_cjk(fallback):
				return fallback
			return "打工"


func _drill_name(drill_id: String, definition: Dictionary = {}) -> String:
	var fallback := str(definition.get("display_name", ""))
	match drill_id:
		"street_debate":
			return "街头辩论"
		"underground_signal":
			return "地下暗号"
		"smuggle_role":
			return "走私扮演"
		"confess_innocent":
			return "告解演练"
		"confession_room":
			return "告解室演练"
		"mirror_step":
			return "镜中影步"
		"foreman_dialogue":
			return "工头对答"
		"tavern_brag":
			return "酒馆吹牛"
		"noble_salon":
			return "贵族沙龙演练"
		_:
			if _has_cjk(fallback):
				return fallback
			return "演练"


func _result_text_zh(result: Dictionary, key_name: String) -> String:
	if not result.get("ok", false):
		return "未成功：%s" % _reason_text_zh(str(result.get("reason", "")))
	var value := str(result.get(key_name, ""))
	match value:
		"big_win":
			return "大胜"
		"small_win":
			return "小胜"
		"triple_win":
			return "豹子通杀"
		"loss":
			return "失手"
		"perfect":
			return "完美"
		"partial":
			return "合格"
		"correct":
			return "答对"
		"wrong":
			return "答错"
		_:
			if _has_cjk(value):
				return value
			return value if value != "" else "完成"


func _action_encounter_text(result: Dictionary, prefix: String) -> String:
	if not bool(result.get("ok", false)):
		return "%s时没有触发新的邂逅。" % prefix
	var encounter_id := str(result.get("encounter_id", ""))
	if encounter_id == "":
		return "%s时没有触发新的邂逅。" % prefix
	return "%s时触发了一个新的邂逅。" % prefix


func _auction_result_text(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		return _reason_text_zh(str(result.get("reason", "")))
	return "结果已结算"


func _card_display_name(card) -> String:
	if card != null and card.has_method("get_display_name"):
		var display_name := str(card.get_display_name())
		if display_name != "":
			return display_name
	if card != null and card.has_method("get"):
		var fallback := str(card.get("display_name"))
		if fallback != "":
			return fallback
	return "一张牌"


func _r20_result_text(result: Dictionary) -> String:
	var engine = R20EffectEngineScript.new()
	if engine.has_method("player_feedback_text"):
		return engine.call("player_feedback_text", result)
	if bool(result.get("success", false)):
		return "咒念生效"
	return "没有生效：%s" % _reason_text_zh(str(result.get("reason", "")))


func _reason_text_zh(reason: String) -> String:
	match reason:
		"missing_state":
			return "状态缺失"
		"missing_city_scene":
			return "城区场景暂时不可用"
		"missing_definition":
			return "定义缺失"
		"ap_short":
			return "AP 不足"
		"lingstones_short":
			return "灵石不足"
		"trust_too_low":
			return "信任不足"
		"unknown_intel":
			return "没有这条情报"
		"no_available_intel":
			return "暂无可问情报"
		"already_known":
			return "已经知道这条情报"
		"not_from_npc":
			return "这不是对方能交给你的委托"
		"not_due":
			return "时机未到"
		"no_available_commission":
			return "暂无可接委托"
		"already_active_or_done":
			return "这项委托已经在处理或已完成"
		"unknown_commission":
			return "没有这项委托"
		"daily_limit":
			return "今日次数已满"
		"weekly_limit":
			return "本周次数已满"
		"cycle_limit":
			return "本周目次数已满"
		"schedule_locked":
			return "时段未开放"
		"pollution_blocked":
			return "污染太高，暂时不能开始"
		"missing_district":
			return "城区数据缺失"
		_:
			if reason.strip_edges() == "":
				return "暂时不能处理"
			return reason


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _on_zone_pressed(zone_id: String) -> void:
	Sfx.play("ui_click")
	if _try_force_sleep_before_action():
		return
	if zone_id == ZONE_DESK:
		_show_desk_menu()
	elif zone_id == ZONE_TAROT:
		if _card_inventory_panel:
			_card_inventory_panel.open()
	elif zone_id == ZONE_BRAND_WORKSHOP:
		if _brand_workshop_panel:
			_brand_workshop_panel.open()
	elif zone_id == ZONE_CUSHION:
		var result: Dictionary = {}
		if _meditation_panel != null and _meditation_panel.has_method("open"):
			result = _meditation_panel.open(GameState)
		else:
			result = MeditationServiceScript.start_placeholder_session(GameState)
		if bool(result.get("ok", false)):
			if _meditation_panel != null:
				_refresh_status()
				return
			_show_placeholder("蒲团修炼已开始；本次消耗 3 AP。")
		else:
			_show_placeholder(_meditation_gate_text(str(result.get("reason", ""))))
		_refresh_status()
	elif zone_id == ZONE_NOTICE_BOARD:
		if _commission_panel != null and _commission_panel.has_method("open"):
			_commission_panel.open(GameState)
		else:
			_show_placeholder("告示板委托暂不可用")
		return
		_show_placeholder("告示板委托（切片 3 开放）")
	elif zone_id == ZONE_BOOKSHELF:
		_show_placeholder("道典 UI（后续切片开放）")
	elif zone_id == ZONE_FRONT_DOOR:
		_open_district_selector()
	elif zone_id == ZONE_CLOCK:
		if _settings_panel and _settings_panel.has_method("open"):
			_settings_panel.open()
	elif zone_id == ZONE_BED:
		_on_bed_pressed()
	else:
		zone_clicked.emit(zone_id)


func _on_bed_pressed() -> void:
	if not is_instance_valid(GameState):
		return
	_setup_sleep_confirm_dialog()
	_sleep_force_active = false
	_set_sleep_cancel_available(true)
	_sleep_confirm_dialog.title = "入梦"
	_sleep_confirm_dialog.dialog_text = "现在入梦？（推进到次日，AP 重置，自动存档）"
	if is_inside_tree():
		_sleep_confirm_dialog.popup_centered()
	else:
		_sleep_confirm_dialog.show()


func _confirm_sleep() -> void:
	# R19 入梦：推进到次日 + 重置 AP/时段 + 自动存档 + 商店刷新计数
	if not is_instance_valid(GameState):
		return
	if _sleep_confirm_dialog != null:
		_sleep_confirm_dialog.hide()
	var previous_bgm := _current_bgm_track()
	_crossfade_bgm("pendulum_dream")
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(GameState, 1)
	if GameState.has_method("set_meta"):
		GameState.set_meta("force_sleep_pending", false)
	_sleep_force_active = false
	_refresh_status()
	_show_morning_summary(result)
	_show_mainline_prompt(result.get("day_hook", {}))
	var return_track := previous_bgm if previous_bgm != "" and previous_bgm != "pendulum_dream" else "hub_sanctuary"
	_crossfade_bgm(return_track)


func _cancel_sleep() -> void:
	if _sleep_force_active:
		return
	if _sleep_confirm_dialog != null:
		_sleep_confirm_dialog.hide()


func _show_placeholder(text: String) -> void:
	_setup_placeholder_dialog()
	_placeholder_dialog.dialog_text = text
	if is_inside_tree():
		_placeholder_dialog.popup_centered()
	else:
		_placeholder_dialog.show()


func _show_desk_menu() -> void:
	var desk_btn = _zone_buttons.get(ZONE_DESK, null)
	if desk_btn:
		var pos = desk_btn.global_position + Vector2(0, desk_btn.size.y)
		_desk_menu.position = pos
	_desk_menu.popup()


func _show_front_door_menu() -> void:
	var door_btn = _zone_buttons.get(ZONE_FRONT_DOOR, null)
	if door_btn:
		var pos = door_btn.global_position + Vector2(0, door_btn.size.y)
		_front_door_menu.position = pos
	_front_door_menu.popup()


func _on_desk_menu_selected(id: int) -> void:
	if _try_force_sleep_before_action():
		return
	match id:
		Zone.FORGE:
			_crossfade_bgm("hammer_forge")
			if get_tree():
				get_tree().change_scene_to_file("res://scenes/ritual/glyph_workshop.tscn")
		Zone.TAROT_DESK:
			_on_zone_pressed(ZONE_TAROT)
		Zone.BRAND_WORKSHOP:
			_on_zone_pressed(ZONE_BRAND_WORKSHOP)
		Zone.DECK_BUILDER:
			if _deck_builder_panel and _deck_builder_panel.has_method("open"):
				_deck_builder_panel.open()


func _on_front_door_menu_selected(id: int) -> void:
	if _try_force_sleep_before_action():
		return
	match id:
		0:
			_open_district_selector()
		1:
			if _black_market_panel and _black_market_panel.has_method("open"):
				_black_market_panel.open()
		2:
			_open_gray_crown_daily("front_door")


func _open_district_selector() -> void:
	if _district_select_panel and _district_select_panel.has_method("open"):
		_district_select_panel.open(GameState)


func _on_city_scene_requested(district_id: String) -> void:
	if _city_scene_panel == null or not _city_scene_panel.has_method("open_district"):
		_show_placeholder("城区场景暂不可用")
		return
	if _district_select_panel != null:
		_district_select_panel.hide()
	prepare_district_identity(district_id, GameState)
	var result: Dictionary = _city_scene_panel.open_district(district_id, GameState)
	if not bool(result.get("ok", false)):
		_show_placeholder("城区数据缺失：%s" % district_id)


func prepare_district_identity(district_id: String, game_state = null) -> Dictionary:
	var gs = game_state if game_state != null else GameState
	if gs == null:
		return {"ok": false, "reason": "missing_game_state"}
	var picker = IdentityPickerScript.new()
	var identity_id := picker.choose_identity_for_location(district_id, gs)
	var result: Dictionary = picker.use_identity_for_location(district_id, gs, identity_id)
	gs.set_meta("last_district_identity_result", result.duplicate(true))
	return result


func open_city_for_debug(district_id: String, time_id: String) -> Dictionary:
	if time_id != "":
		GameState.time_of_day = time_id
	GameState.current_district = district_id
	_on_city_scene_requested(district_id)
	return {"ok": _city_scene_panel != null and _city_scene_panel.visible, "district_id": district_id, "time_of_day": str(GameState.time_of_day)}


func _on_city_return_requested() -> void:
	if _city_scene_panel != null:
		_city_scene_panel.hide()
	_crossfade_bgm("hub_sanctuary")


func _on_city_force_sleep_requested() -> void:
	_show_forced_sleep_prompt()


func _on_city_hotspot_selected(hotspot: Dictionary) -> void:
	var hotspot_type := str(hotspot.get("type", ""))
	if hotspot_type == "tower":
		_open_tower_from_city_hotspot(hotspot)
		return
	if hotspot_type == "rumor":
		_open_rumor_from_city_hotspot(hotspot)
		return
	if hotspot_type == "newspaper":
		_open_gray_crown_daily("hotspot")
		return
	if hotspot_type == "shop":
		_open_shop_from_city_hotspot(hotspot)
		return
	if hotspot_type == "rumor":
		_show_city_hotspot_placeholder(hotspot, "情报热点", ["rumor_pool"])
		return
	if hotspot_type == "minigame_casino":
		_open_casino_from_city_hotspot(hotspot)
		return
	if hotspot_type == "minigame_job":
		_open_job_from_city_hotspot(hotspot)
		return
	if hotspot_type == "minigame_drill":
		_open_drill_from_city_hotspot(hotspot)
		return
	if hotspot_type == "minigame_auction":
		_open_auction_from_city_hotspot(hotspot)
		return
	if hotspot_type == "main_story":
		var mainline_payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
		var node_id := ""
		for key in ["node_id", "mainline_node_id", "story_node_id", "anchor_id"]:
			node_id = str(mainline_payload.get(key, hotspot.get(key, "")))
			if node_id != "":
				break
		if node_id == "":
			var anchors: Variant = mainline_payload.get("story_anchors", hotspot.get("story_anchors", []))
			if anchors is Array:
				for anchor in anchors:
					node_id = str(anchor)
					if node_id != "":
						break
		if node_id == "":
			_show_city_hotspot_placeholder(hotspot, "主线热点", ["node_id", "story_anchors"])
			return
		var daodian: Dictionary = GameState.daodian if GameState.daodian is Dictionary else {}
		var completed: Array = []
		var raw_completed: Variant = daodian.get("completed_main_story_nodes", [])
		if raw_completed is Array:
			for item in raw_completed:
				completed.append(str(item))
		for value in _mainline_node_aliases_for_hotspot(node_id):
			if value != "" and not value in completed:
				completed.append(value)
		daodian["completed_main_story_nodes"] = completed
		GameState.daodian = daodian
		var label := str(hotspot.get("label", "主线线索"))
		var title_text := str(mainline_payload.get("title", label))
		if title_text == "":
			title_text = "主线线索"
		var body_text := str(mainline_payload.get("popup_text", mainline_payload.get("description", "")))
		_setup_mainline_dialog()
		_mainline_dialog.title = "主线线索"
		var lines: Array[String] = [title_text]
		if body_text != "" and body_text != title_text:
			lines.append(body_text)
		lines.append("线索已记录。")
		_mainline_dialog.dialog_text = _join_lines(lines)
		if _placeholder_dialog != null and _placeholder_dialog.visible:
			_placeholder_dialog.hide()
		if is_inside_tree():
			_mainline_dialog.popup_centered()
		else:
			_mainline_dialog.show()
		_refresh_status()
		return
	if hotspot_type != "npc":
		_show_city_hotspot_placeholder(hotspot, "城区热点", [])
		return
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var npc_id := str(payload.get("npc_id", ""))
	if npc_id == "":
		return
	_clear_city_npc_context_buttons()
	var service = _npc_interaction_service()
	var result: Dictionary = service.open_dialogue(npc_id, GameState)
	if not bool(result.get("ok", false)):
		_show_placeholder("暂时无法交谈：%s" % _reason_text_zh(str(result.get("reason", ""))))
		return
	var npc: Dictionary = result.get("npc", {})
	var display_name := str(npc.get("display_name", npc_id))
	_setup_npc_dialog()
	_npc_dialog.title = display_name
	_set_npc_portrait(npc_id, npc)
	_npc_dialog.dialog_text = str(result.get("dialogue_preview", "你和%s开始交谈。" % display_name))
	_append_npc_ai_gm_text(str(result.get("ai_gm_text", "")))
	_append_npc_state_summary(npc_id)
	_active_npc_id = npc_id
	_active_npc_dialogue_result = result.duplicate(true)
	_show_npc_root_menu(npc_id)
	if is_inside_tree():
		_npc_dialog.popup_centered()
	else:
		_npc_dialog.show()


func _clear_city_npc_context_buttons() -> void:
	if _city_scene_panel != null and _city_scene_panel.has_method("clear_npc_context_buttons"):
		_city_scene_panel.call("clear_npc_context_buttons")


func _on_npc_dialog_visibility_changed() -> void:
	if _npc_dialog == null:
		return
	_set_city_interaction_surface_visible(not _npc_dialog.visible)


func _set_city_interaction_surface_visible(value: bool) -> void:
	if _city_scene_panel != null and _city_scene_panel.visible and _city_scene_panel.has_method("set_interaction_surface_visible"):
		_city_scene_panel.call("set_interaction_surface_visible", value)


func _set_npc_portrait(npc_id: String, npc: Dictionary) -> void:
	if _npc_portrait_rect == null:
		return
	var path := str(npc.get("portrait_path", ""))
	if path == "":
		path = ArtManifestScript.texture_path_for("portrait", npc_id)
	var texture: Texture2D = null
	if path != "":
		texture = ResourceLoader.load(path) as Texture2D
	_npc_portrait_rect.texture = texture
	_npc_portrait_rect.visible = texture != null


func _add_npc_dialog_button(button_name: String, button_text: String) -> Button:
	_setup_npc_dialog()
	var button := _npc_dialog.add_button(button_text, false, button_name)
	button.name = button_name
	return button


func _show_npc_root_menu(npc_id: String) -> void:
	_setup_npc_dialog()
	_active_npc_id = npc_id
	_clear_all_npc_dialog_buttons()
	var talk_button := _add_npc_dialog_button("NpcTalkMenuButton_%s" % npc_id, "\u4ea4\u6d41")
	talk_button.tooltip_text = "\u67e5\u770b\u5e76\u63a8\u8fdb\u8be5 NPC \u7684 timeline \u5bf9\u8bdd"
	talk_button.pressed.connect(_on_npc_talk_menu_pressed.bind(npc_id))
	var event_button := _add_npc_dialog_button("NpcEventMenuButton_%s" % npc_id, "\u4e8b\u4ef6/\u4efb\u52a1")
	event_button.tooltip_text = "\u968f\u673a\u4e8b\u4ef6\u3001\u4eca\u65e5\u673a\u4f1a\u3001\u4e3b\u7ebf\u4e0e\u59d4\u6258"
	event_button.pressed.connect(_on_npc_event_menu_pressed.bind(npc_id))
	_refresh_npc_identity_buttons(npc_id, _active_npc_dialogue_result)


func _show_npc_talk_menu(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_all_npc_dialog_buttons()
	_refresh_npc_dialogue_branch_buttons(npc_id)
	_refresh_npc_dialogue_buttons(npc_id)
	_add_npc_back_button(npc_id)


func _show_npc_event_menu(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_all_npc_dialog_buttons()
	_refresh_npc_mainline_buttons(npc_id)
	_refresh_npc_opportunity_buttons(npc_id)
	_refresh_npc_commission_buttons(npc_id)
	_add_npc_back_button(npc_id)


func _show_npc_service_menu(npc_id: String) -> void:
	_show_npc_event_menu(npc_id)


func _on_npc_talk_menu_pressed(npc_id: String) -> void:
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), "\u4f60\u628a\u6ce8\u610f\u529b\u653e\u56de\u5bf9\u65b9\u7684\u8bdd\u4e0a\u3002"]
	_show_npc_talk_menu(npc_id)


func _on_npc_event_menu_pressed(npc_id: String) -> void:
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), "\u4f60\u68b3\u7406\u8fd9\u540d NPC \u8eab\u4e0a\u80fd\u89e6\u53d1\u7684\u4e8b\u4ef6\u548c\u4efb\u52a1\u3002"]
	_show_npc_event_menu(npc_id)


func _on_npc_service_menu_pressed(npc_id: String) -> void:
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), "\u4f60\u8f6c\u5411\u53ef\u4ee5\u7acb\u523b\u7ed3\u7b97\u7684\u4e8b\u52a1\u3002"]
	_show_npc_service_menu(npc_id)


func _add_npc_back_button(npc_id: String) -> Button:
	var button := _add_npc_dialog_button("NpcBackButton_%s" % npc_id, "\u8fd4\u56de")
	button.tooltip_text = "\u8fd4\u56de NPC \u4e3b\u5bf9\u8bdd\u5165\u53e3"
	button.pressed.connect(_on_npc_back_pressed.bind(npc_id))
	return button


func _on_npc_back_pressed(npc_id: String) -> void:
	_show_npc_root_menu(npc_id)


func _clear_all_npc_dialog_buttons() -> void:
	if _npc_dialog == null:
		return
	for prefix in NPC_DIALOG_BUTTON_PREFIXES:
		_clear_owned_dialog_buttons(_npc_dialog, str(prefix))


func _refresh_npc_dialogue_branch_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcDialogueBranchButton_")
	var service = _npc_interaction_service()
	if not service.has_method("dialogue_branches_for_npc"):
		return
	for branch in service.call("dialogue_branches_for_npc", npc_id, GameState):
		if not branch is Dictionary:
			continue
		var entry: Dictionary = branch
		var branch_id := str(entry.get("id", ""))
		if branch_id == "" or branch_id == "leave":
			continue
		var label := str(entry.get("label", branch_id))
		var button := _add_npc_dialog_button("NpcDialogueBranchButton_%s" % branch_id, "\u5bf9\u8bdd\uff1a%s" % label)
		button.tooltip_text = str(entry.get("text", ""))
		button.pressed.connect(_on_npc_dialogue_branch_pressed.bind(npc_id, branch_id))


func _on_npc_dialogue_branch_pressed(npc_id: String, branch_id: String) -> void:
	var service = _npc_interaction_service()
	var result: Dictionary = {}
	if service.has_method("resolve_dialogue_branch"):
		result = service.call("resolve_dialogue_branch", npc_id, GameState, branch_id)
	if _npc_dialog != null:
		var line := str(result.get("text", ""))
		if line == "":
			line = "\u5bf9\u8bdd\uff1a%s" % _reason_text_zh(str(result.get("reason", "")))
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), line]
		var commit: Dictionary = result.get("commit", {}) if result.get("commit", {}) is Dictionary else {}
		var ai_gm_texts: Dictionary = commit.get("ai_gm_texts", {}) if commit.get("ai_gm_texts", {}) is Dictionary else {}
		for ai_text in ai_gm_texts.values():
			_append_npc_ai_gm_text(str(ai_text))
	var mainline_node_id := str(result.get("mainline_node_id", ""))
	if mainline_node_id != "":
		_record_mainline_node_from_hotspot(mainline_node_id)
	_show_npc_talk_menu(npc_id)
	_refresh_status()


func _refresh_npc_mainline_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcMainlineButton_")
	var npc: Dictionary = _active_npc_dialogue_result.get("npc", {}) if _active_npc_dialogue_result.get("npc", {}) is Dictionary else {}
	var anchors: Variant = npc.get("mainline_anchors", [])
	if not anchors is Array:
		return
	for anchor in anchors:
		var node_id := str(anchor)
		if node_id == "":
			continue
		var button := _add_npc_dialog_button("NpcMainlineButton_%s" % node_id, "\u4e3b\u7ebf\uff1a%s" % _mainline_node_label(node_id))
		button.tooltip_text = "\u8bb0\u5f55\u8be5 NPC \u6307\u5411\u7684\u4e3b\u7ebf\u8282\u70b9"
		button.pressed.connect(_on_npc_mainline_pressed.bind(npc_id, node_id))


func _on_npc_mainline_pressed(npc_id: String, node_id: String) -> void:
	_record_mainline_node_from_hotspot(node_id)
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), "\u4e3b\u7ebf\u7ebf\u7d22\u5df2\u8bb0\u5f55\uff1a%s" % _mainline_node_label(node_id)]
	_show_npc_event_menu(npc_id)
	_refresh_status()


func _mainline_node_label(node_id: String) -> String:
	match node_id:
		"node_4":
			return "\u7b2c\u56db\u8282\u70b9"
		_:
			return node_id


func _refresh_npc_dialogue_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcDeepChatButton_")
	var cost := ApServiceScript.npc_dialogue_cost(NPC_DEEP_CHAT_ROUNDS, false)
	var button := _add_npc_dialog_button("NpcDeepChatButton_%s" % npc_id, "深入交谈 %d AP" % cost)
	button.tooltip_text = "消耗 %d AP，推进关系与对话进度。" % cost
	if int(GameState.ap) < cost:
		button.disabled = true
		button.tooltip_text += "当前 AP 不足。"
	button.pressed.connect(_on_npc_deep_chat_pressed.bind(npc_id))


func _refresh_npc_identity_buttons(npc_id: String, dialogue_result: Dictionary = {}) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcIdentityButton_")
	var options: Array = dialogue_result.get("identity_options", []) if dialogue_result.get("identity_options", []) is Array else []
	if options.is_empty():
		var service = _npc_interaction_service()
		if service.has_method("residual_identity_options_for_npc"):
			options = service.call("residual_identity_options_for_npc", npc_id, GameState)
	for option in options:
		if not option is Dictionary:
			continue
		var entry: Dictionary = option
		var identity_id := str(entry.get("identity_id", entry.get("id", "")))
		if identity_id == "":
			continue
		var button := _add_npc_dialog_button("NpcIdentityButton_%s" % identity_id, str(entry.get("label", "以 %s 身份接近" % identity_id)))
		button.pressed.connect(_on_npc_identity_pressed.bind(npc_id, identity_id))


func _refresh_npc_opportunity_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcOpportunityButton_")
	var service = _npc_interaction_service()
	for opportunity in service.available_daily_opportunities_for_npc(npc_id, GameState):
		if not opportunity is Dictionary:
			continue
		var entry: Dictionary = opportunity
		var opportunity_id := str(entry.get("id", ""))
		if opportunity_id == "":
			continue
		var display_name := FieldOpportunityServiceScript.new().player_title_for_opportunity(entry)
		var button := _add_npc_dialog_button("NpcOpportunityButton_%s" % opportunity_id, "\u4eca\u65e5\u673a\u4f1a\uff1a%s" % display_name)
		button.tooltip_text = _field_opportunity_tooltip(entry)
		button.pressed.connect(_on_npc_opportunity_pressed.bind(npc_id, opportunity_id))


func _field_opportunity_tooltip(entry: Dictionary) -> String:
	var service = FieldOpportunityServiceScript.new()
	if service.has_method("player_tooltip_for_opportunity"):
		return service.call("player_tooltip_for_opportunity", entry)
	var cost: Dictionary = entry.get("cost", {}) if entry.get("cost", {}) is Dictionary else {}
	var pieces: Array[String] = []
	if int(cost.get("ap", 0)) > 0:
		pieces.append("%d AP" % int(cost.get("ap", 0)))
	if int(cost.get("lingstones", 0)) > 0:
		pieces.append("%d \u7075\u77f3" % int(cost.get("lingstones", 0)))
	if int(cost.get("hub_mana", 0)) > 0:
		pieces.append("%d \u6d1e\u5e9c\u6cd5\u529b" % int(cost.get("hub_mana", 0)))
	if not pieces.is_empty():
		return "\u82b1\u8d39\uff1a%s" % " / ".join(pieces)
	return "\u4e0d\u9700\u8981\u76f4\u63a5\u82b1\u8d39\uff0c\u4f46\u53ef\u80fd\u6539\u53d8\u5173\u7cfb\u4e0e\u98ce\u9669"


func _refresh_npc_intel_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcIntelButton_")
	var service = _npc_interaction_service()
	var intels: Array = service.available_intels_for_npc(npc_id, GameState)
	for intel in intels:
		if not intel is Dictionary:
			continue
		var entry: Dictionary = intel
		var intel_id := str(entry.get("intel_id", entry.get("id", "")))
		if intel_id == "":
			continue
		var cost := int(entry.get("lingstones_cost", 20))
		var button := _add_npc_dialog_button("NpcIntelButton_%s" % intel_id, "问情报 %d 灵石" % cost)
		button.tooltip_text = str(entry.get("summary", entry.get("display_text", "")))
		button.disabled = bool(entry.get("already_known", false)) or int(GameState.lingstones) < cost
		button.pressed.connect(_on_npc_intel_pressed.bind(npc_id, intel_id))


func _refresh_npc_commission_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcCommissionButton_")
	var service = _npc_interaction_service()
	var commissions: Array = service.available_commissions_for_npc(npc_id, GameState)
	for commission in commissions:
		if not commission is Dictionary:
			continue
		var entry: Dictionary = commission
		var commission_id := str(entry.get("id", ""))
		if commission_id == "":
			continue
		var commission_name := str(entry.get("display_name", entry.get("title", entry.get("name", ""))))
		if commission_name == "" or not _has_cjk(commission_name):
			commission_name = "一项委托"
		var commission_description := str(entry.get("description", ""))
		if commission_description == "" or not _has_cjk(commission_description):
			commission_description = "接受后可在告示板查看、执行和交差。"
		var button := _add_npc_dialog_button("NpcCommissionButton_%s" % commission_id, "接委托：%s" % commission_name)
		button.tooltip_text = commission_description
		button.pressed.connect(_on_npc_commission_pressed.bind(npc_id, commission_id))


func _refresh_npc_activity_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	_clear_owned_dialog_buttons(_npc_dialog, "NpcJobButton_")
	_clear_owned_dialog_buttons(_npc_dialog, "NpcDrillButton_")
	var service = _npc_interaction_service()
	for job in service.available_jobs_for_npc(npc_id, GameState):
		if not job is Dictionary:
			continue
		var entry: Dictionary = job
		var job_id := str(entry.get("id", ""))
		if job_id == "":
			continue
		var button := _add_npc_dialog_button("NpcJobButton_%s" % job_id, "打工：%s %d AP" % [str(entry.get("display_name", _job_name(job_id))), int(entry.get("ap_cost", 0))])
		button.tooltip_text = "通过这名 NPC 开始对应打工结算。"
		if not bool(entry.get("available", false)):
			button.disabled = true
			button.tooltip_text = "暂不可开始：%s" % _reason_text_zh(str(entry.get("reason", "")))
		button.pressed.connect(_on_npc_job_pressed.bind(npc_id, job_id))
	for drill in service.available_drills_for_npc(npc_id, GameState):
		if not drill is Dictionary:
			continue
		var entry: Dictionary = drill
		var drill_id := str(entry.get("id", ""))
		if drill_id == "":
			continue
		var button := _add_npc_dialog_button("NpcDrillButton_%s" % drill_id, "演练：%s %d AP" % [str(entry.get("display_name", _drill_name(drill_id))), int(entry.get("ap_cost", 1))])
		button.tooltip_text = "通过这名 NPC 开始对应演练结算。"
		if not bool(entry.get("available", false)):
			button.disabled = true
			button.tooltip_text = "暂不可开始：%s" % _reason_text_zh(str(entry.get("reason", "")))
		button.pressed.connect(_on_npc_drill_pressed.bind(npc_id, drill_id))


func _refresh_r20_chant_buttons(npc_id: String) -> void:
	_setup_npc_dialog()
	ChantButtonFactoryScript.clear_chant_buttons(_npc_dialog)
	ChantButtonFactoryScript.add_chant_buttons(_npc_dialog, GameState, npc_id, Callable(self, "_on_r20_chant_pressed"))


func _owned_r20_social_cards() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	if not is_instance_valid(GameState):
		return result
	for card_id in GameState.active_deck:
		var card = GameState.get_card(str(card_id))
		if card != null and not seen.has(str(card.get("id"))):
			seen[str(card.get("id"))] = true
			result.append(card)
	for card in GameState.cards_inventory:
		if card == null or not card.has_method("get"):
			continue
		var id := str(card.get("id"))
		if id != "" and not seen.has(id):
			seen[id] = true
			result.append(card)
	return result


func _on_r20_chant_pressed(card_id: String, npc_id: String) -> void:
	var card = GameState.get_card(card_id) if is_instance_valid(GameState) else null
	if card == null:
		return
	var result: Dictionary = _r20_effect_engine().dispatch_card(card, npc_id, {
		"game_state": GameState,
		"source": "npc_dialogue",
	})
	var line := "咒念：%s，%s" % [_card_display_name(card), _r20_result_text(result)]
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), line]
		_append_npc_ai_gm_text(str(result.get("ai_gm_text", "")))
	_show_npc_service_menu(npc_id)
	_refresh_status()


func _on_npc_opportunity_pressed(npc_id: String, opportunity_id: String) -> void:
	var result: Dictionary = _npc_interaction_service().resolve_daily_opportunity(npc_id, GameState, opportunity_id)
	var line := "\u4eca\u65e5\u673a\u4f1a\uff1a%s" % _reason_text_zh(str(result.get("reason", "")))
	if bool(result.get("ok", false)):
		var display_text := str(result.get("display_text", ""))
		if display_text == "" or not _has_cjk(display_text):
			display_text = "\u7ebf\u7d22\u5df2\u8bb0\u5f55"
		line = "\u4eca\u65e5\u673a\u4f1a\uff1a%s" % display_text
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), line]
	_show_npc_event_menu(npc_id)
	_refresh_status()


func _on_npc_identity_pressed(npc_id: String, identity_id: String) -> void:
	var service = _npc_interaction_service()
	if not service.has_method("select_residual_identity_for_npc"):
		return
	var result: Dictionary = service.call("select_residual_identity_for_npc", npc_id, GameState, identity_id)
	var line := "身份：%s" % _reason_text_zh(str(result.get("reason", "")))
	if bool(result.get("ok", false)):
		line = "以 %s 身份接近" % _npc_identity_display_name(identity_id)
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), line]
	_append_npc_ai_gm_text(str(result.get("ai_gm_text", "")))
	_show_npc_root_menu(npc_id)
	_refresh_status()


func _on_npc_deep_chat_pressed(npc_id: String) -> void:
	var result: Dictionary = _npc_interaction_service().commit_dialogue_outcome(npc_id, _default_npc_deep_chat_outcome(npc_id), GameState)
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), _npc_deep_chat_result_text(result)]
		var ai_gm_texts: Dictionary = result.get("ai_gm_texts", {}) if result.get("ai_gm_texts", {}) is Dictionary else {}
		for ai_text in ai_gm_texts.values():
			_append_npc_ai_gm_text(str(ai_text))
	_show_npc_talk_menu(npc_id)
	_refresh_status()


func _default_npc_deep_chat_outcome(npc_id: String) -> Dictionary:
	return {
		"dialogue_rounds": NPC_DEEP_CHAT_ROUNDS,
		"trust_delta": NPC_DEEP_CHAT_TRUST_DELTA,
		"suspicion_delta": 0,
		"unlocked_dialogue_branches": ["%s.deep_chat" % npc_id],
	}


func _npc_deep_chat_result_text(result: Dictionary) -> String:
	if not bool(result.get("ok", false)):
		var cost := int(result.get("ap_cost", ApServiceScript.npc_dialogue_cost(NPC_DEEP_CHAT_ROUNDS, false)))
		if str(result.get("reason", "")) == "ap_short":
			return "深入交谈：AP 不足，需要 %d AP。" % cost
		return "深入交谈：%s" % _reason_text_zh(str(result.get("reason", "")))
	var cost := int(result.get("ap_cost", 0))
	var trust := int(result.get("trust", 0))
	var text := "深入交谈：消耗 %d AP，关系 +%d，信任 %d，对话进度 +1。" % [
		cost,
		NPC_DEEP_CHAT_TRUST_DELTA,
		trust,
	]
	var thresholds: Array = _array_from_variant(result.get("triggered_thresholds", []))
	if thresholds.size() > 0:
		text += "关系阶段有新进展。"
	return text


func _on_npc_intel_pressed(npc_id: String, intel_id: String) -> void:
	var result: Dictionary = _npc_interaction_service().ask_intel(npc_id, GameState, intel_id)
	var line := ""
	if bool(result.get("ok", false)):
		line = "问情报：%s（-%d 灵石）" % [
			str(result.get("display_text", "")),
			int(result.get("lingstones_cost", 0)),
		]
	else:
		line = "问情报：%s" % _reason_text_zh(str(result.get("reason", "")))
	if _npc_dialog != null:
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), line]
	_show_npc_service_menu(npc_id)
	_refresh_status()


func _on_npc_commission_pressed(npc_id: String, commission_id: String) -> void:
	var result: Dictionary = _npc_interaction_service().accept_npc_commission(npc_id, GameState, commission_id)
	if _npc_dialog != null:
		var line := "委托：%s" % _reason_text_zh(str(result.get("reason", "")))
		if bool(result.get("ok", false)):
			var commission: Dictionary = result.get("commission", {}) if result.get("commission", {}) is Dictionary else {}
			var commission_name := str(commission.get("display_name", commission.get("title", commission.get("name", ""))))
			if commission_name == "" or not _has_cjk(commission_name):
				commission_name = "一项委托"
			line = "接受委托：%s。可在告示板执行。" % commission_name
		_npc_dialog.dialog_text = "%s\n%s" % [str(_npc_dialog.dialog_text), line]
	_show_npc_event_menu(npc_id)
	if _commission_panel != null and _commission_panel.has_method("_refresh"):
		_commission_panel.call("_refresh")
	_refresh_status()


func _on_npc_job_pressed(npc_id: String, job_id: String) -> void:
	var result: Dictionary = _npc_interaction_service().start_npc_job(npc_id, GameState, job_id, _default_job_options(job_id))
	var lines: Array[String] = []
	if _npc_dialog != null and str(_npc_dialog.dialog_text) != "":
		lines.append(str(_npc_dialog.dialog_text))
	lines.append("打工结果：%s，%s，消耗 %d AP" % [
		_job_name(job_id),
		_result_text_zh(result, "grade"),
		int(result.get("ap_cost", 0)),
	])
	if bool(result.get("ok", false)):
		var commission_result := _record_city_job_commission_completion(job_id, result)
		var commission_text := _city_commission_completion_text(commission_result)
		if commission_text != "":
			lines.append(commission_text)
		for intel_text in _granted_intel_texts(result):
			lines.append("获得情报：%s" % intel_text)
		if job_id == "errand_runner":
			var action_result := _try_city_action_encounter("errand")
			lines.append(_action_encounter_text(action_result, "跑腿结束"))
	if _npc_dialog != null:
		_npc_dialog.dialog_text = _join_lines(lines)
	_show_npc_service_menu(npc_id)
	if _commission_panel != null and _commission_panel.has_method("_refresh"):
		_commission_panel.call("_refresh")
	_refresh_status()


func _on_npc_drill_pressed(npc_id: String, drill_id: String) -> void:
	var result: Dictionary = _npc_interaction_service().resolve_npc_drill(npc_id, GameState, drill_id, _default_drill_options(drill_id))
	var lines: Array[String] = []
	var ai_gm_text := str(result.get("ai_gm_text", "")).strip_edges()
	if ai_gm_text != "":
		lines.append(ai_gm_text)
	if _npc_dialog != null and str(_npc_dialog.dialog_text) != "":
		lines.append(str(_npc_dialog.dialog_text))
	lines.append("演练结果：%s，%s，消耗 %d AP" % [
		_drill_name(drill_id),
		_result_text_zh(result, "outcome"),
		int(result.get("ap_cost", 0)),
	])
	if bool(result.get("ok", false)):
		var commission_result := _record_city_drill_commission_completion(drill_id, result)
		var commission_text := _city_commission_completion_text(commission_result)
		if commission_text != "":
			lines.append(commission_text)
		for intel_text in _granted_intel_texts(result):
			lines.append("获得情报：%s" % intel_text)
	if _npc_dialog != null:
		_npc_dialog.dialog_text = _join_lines(lines)
	_show_npc_service_menu(npc_id)
	if _commission_panel != null and _commission_panel.has_method("_refresh"):
		_commission_panel.call("_refresh")
	_refresh_status()


func _open_main_story_from_city_hotspot(hotspot: Dictionary) -> void:
	var node_id := _mainline_node_id_from_hotspot(hotspot)
	if node_id == "":
		_show_city_hotspot_placeholder(hotspot, "主线热点", ["node_id", "story_anchors"])
		return
	_record_mainline_node_from_hotspot(node_id)
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var label := str(hotspot.get("label", "主线线索"))
	var title_text := str(payload.get("title", label))
	if title_text == "":
		title_text = "主线线索"
	var body_text := str(payload.get("popup_text", payload.get("description", "")))
	_setup_mainline_dialog()
	_mainline_dialog.title = "主线线索"
	var lines: Array[String] = [title_text]
	if body_text != "" and body_text != title_text:
		lines.append(body_text)
	lines.append("线索已记录。")
	_mainline_dialog.dialog_text = _join_lines(lines)
	_hide_placeholder_if_visible()
	if is_inside_tree():
		_mainline_dialog.popup_centered()
	else:
		_mainline_dialog.show()
	_refresh_status()


func _mainline_node_id_from_hotspot(hotspot: Dictionary) -> String:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	for key in ["node_id", "mainline_node_id", "story_node_id", "anchor_id"]:
		var value := str(payload.get(key, hotspot.get(key, "")))
		if value != "":
			return value
	var anchors: Variant = payload.get("story_anchors", hotspot.get("story_anchors", []))
	if anchors is Array:
		for anchor in anchors:
			var value := str(anchor)
			if value != "":
				return value
	return ""


func _record_mainline_node_from_hotspot(node_id: String) -> void:
	if node_id == "" or not is_instance_valid(GameState):
		return
	var daodian: Dictionary = GameState.daodian if GameState.daodian is Dictionary else {}
	var completed: Array = []
	var raw: Variant = daodian.get("completed_main_story_nodes", [])
	if raw is Array:
		for item in raw:
			completed.append(str(item))
	for value in _mainline_node_aliases_for_hotspot(node_id):
		if value != "" and not value in completed:
			completed.append(value)
	daodian["completed_main_story_nodes"] = completed
	GameState.daodian = daodian


func _mainline_node_aliases_for_hotspot(node_id: String) -> Array[String]:
	var result: Array[String] = [node_id]
	var parts := node_id.split("_", false)
	if parts.size() >= 2 and str(parts[0]) == "node":
		var generic_id := "%s_%s" % [str(parts[0]), str(parts[1])]
		if not generic_id in result:
			result.append(generic_id)
	return result


func _open_rumor_from_city_hotspot(hotspot: Dictionary) -> void:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var pool_id := str(payload.get("rumor_pool", ""))
	if pool_id == "":
		_show_city_hotspot_placeholder(hotspot, "情报热点", ["rumor_pool"])
		return
	if int(GameState.church_awareness) >= 75:
		_setup_rumor_dialog()
		_rumor_dialog.dialog_text = "街角说书人不在这里。有人把他的凳子和木箱一起搬走了。"
		if is_inside_tree():
			_rumor_dialog.popup_centered()
		else:
			_rumor_dialog.show()
		return
	var current_draws := _rumor_draw_count_today(pool_id)
	if current_draws >= 2:
		_setup_rumor_dialog()
		_rumor_dialog.dialog_text = "今天已经听过两次这里的消息。明天再来。"
		if is_inside_tree():
			_rumor_dialog.popup_centered()
		else:
			_rumor_dialog.show()
		return
	var spend: Dictionary = ApServiceScript.try_spend(GameState, ApServiceScript.listen_rumor_cost(), "listen_rumor")
	if not bool(spend.get("ok", false)):
		_setup_rumor_dialog()
		_rumor_dialog.dialog_text = "AP 不足：听情报需要 %d AP。当前 AP %d。" % [int(spend.get("cost", ApServiceScript.listen_rumor_cost())), int(GameState.ap)]
		if is_inside_tree():
			_rumor_dialog.popup_centered()
		else:
			_rumor_dialog.show()
		return
	var service = _intel_service()
	var draw_result: Dictionary = service.draw_streettalker_rumor(GameState, pool_id, 3, _rumor_seed(pool_id, current_draws))
	var granted_texts: Array[String] = []
	for text in draw_result.get("granted_intel_texts", []):
		granted_texts.append(str(text))
	var ai_gm_texts: Array[String] = []
	for text in draw_result.get("ai_gm_texts", []):
		var ai_text := str(text).strip_edges()
		if ai_text != "":
			ai_gm_texts.append(ai_text)
	_record_rumor_draw(pool_id)
	_refresh_status()
	_setup_rumor_dialog()
	var lines: Array[String] = [
		"你停下听了一会儿。",
	]
	if granted_texts.is_empty():
		lines.append("今天没有听到新的情报。")
	else:
		lines.append("你听到：")
		for text in granted_texts:
			lines.append("· %s" % text)
	for ai_text in ai_gm_texts:
		lines.append(ai_text)
	_rumor_dialog.dialog_text = _join_lines(lines)
	if is_inside_tree():
		_rumor_dialog.popup_centered()
	else:
		_rumor_dialog.show()


func _open_shop_from_city_hotspot(hotspot: Dictionary) -> void:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var shop_id := str(payload.get("shop_id", ""))
	if shop_id == "donen_blackmarket" and _black_market_panel != null and _black_market_panel.has_method("open"):
		_black_market_panel.open(GameState)
		return
	_show_city_hotspot_placeholder(hotspot, "商店入口", ["shop_id"])


func _open_casino_from_city_hotspot(hotspot: Dictionary) -> void:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var npc_id := str(payload.get("npc_id", "eel_fan"))
	var game_ids: Array = payload.get("game_ids", []) if payload.get("game_ids", []) is Array else []
	var service = MinigameServiceScript.new()
	var options: Array = service.available_casino_games(GameState, npc_id, game_ids)
	var lines: Array[String] = [
		"鳗鱼·凡把骰盅往桌上一扣。",
		"灵石 %d · AP %d" % [int(GameState.lingstones), int(GameState.ap)],
	]
	for option in options:
		if not option is Dictionary:
			continue
		var available_text := "可玩" if bool(option.get("available", false)) else "暂不可玩：%s" % _reason_text_zh(str(option.get("reason", "")))
		lines.append("%s | %s | AP %d | %d-%d 灵石" % [
			_minigame_name(str(option.get("id", "")), str(option.get("display_name", ""))),
			available_text,
			int(option.get("ap_cost", 0)),
			int(option.get("bet_min", 0)),
			int(option.get("bet_max", 0)),
		])
	if options.is_empty():
		lines.append("今晚没有可玩的局。")
	_setup_casino_dialog()
	_refresh_casino_buttons(options)
	_hide_placeholder_if_visible()
	_casino_dialog.dialog_text = _join_lines(lines)
	if is_inside_tree():
		_casino_dialog.popup_centered()
	else:
		_casino_dialog.show()


func _open_auction_from_city_hotspot(hotspot: Dictionary) -> void:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var auction_id := str(payload.get("auction_id", "misty_port_weekly"))
	var service = AuctionServiceScript.new()
	var check: Dictionary = service.can_start(GameState, auction_id)
	var lots: Array = service.generate_lots(GameState, auction_id, 3)
	var lines: Array[String] = [
		"走私者拍卖会",
		"状态：%s" % ("可开始" if bool(check.get("ok", false)) else _reason_text_zh(str(check.get("reason", "")))),
	]
	for lot in lots:
		if not lot is Dictionary:
			continue
		lines.append("%s | 起拍 %d | 估值 %d" % [
			str(lot.get("display_name", "拍品")),
			int(lot.get("start_price", 0)),
			int(lot.get("appraised_value", 0)),
		])
	_setup_auction_dialog()
	_refresh_auction_button(auction_id)
	_hide_placeholder_if_visible()
	_auction_dialog.dialog_text = _join_lines(lines)
	if is_inside_tree():
		_auction_dialog.popup_centered()
	else:
		_auction_dialog.show()


func _open_job_from_city_hotspot(hotspot: Dictionary) -> void:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var job_id := str(payload.get("job_id", ""))
	if job_id == "":
		_show_city_hotspot_placeholder(hotspot, "打工入口", ["job_id"])
		return
	var service = JobServiceScript.new()
	var definition: Dictionary = service.load_job_definition(job_id)
	var check: Dictionary = service.can_start(GameState, job_id, _default_job_options(job_id))
	var lines: Array[String] = [
		"%s" % _job_name(job_id, definition),
		"状态：%s" % ("可开始" if bool(check.get("ok", false)) else _reason_text_zh(str(check.get("reason", "")))),
		"AP %d · 消耗 %d" % [int(GameState.ap), int(definition.get("ap_cost", 0))],
	]
	_setup_job_dialog()
	_refresh_job_button(job_id, check)
	_hide_placeholder_if_visible()
	_job_dialog.dialog_text = _join_lines(lines)
	if is_inside_tree():
		_job_dialog.popup_centered()
	else:
		_job_dialog.show()


func _open_drill_from_city_hotspot(hotspot: Dictionary) -> void:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var drill_id := str(payload.get("drill_id", ""))
	if drill_id == "":
		_show_city_hotspot_placeholder(hotspot, "演练入口", ["drill_id"])
		return
	var runner = _drill_runner()
	var definition: Dictionary = runner.load_drill_definition(drill_id)
	var check: Dictionary = runner.can_start(GameState, drill_id, _default_drill_options(drill_id))
	var lines: Array[String] = [
		"%s" % _drill_name(drill_id, definition),
		"状态：%s" % ("可开始" if bool(check.get("ok", false)) else _reason_text_zh(str(check.get("reason", "")))),
		"AP %d · 消耗 %d" % [int(GameState.ap), int(definition.get("ap_cost", 1))],
	]
	_setup_drill_dialog()
	_refresh_drill_button(drill_id, check)
	_hide_placeholder_if_visible()
	_drill_dialog.dialog_text = _join_lines(lines)
	if is_inside_tree():
		_drill_dialog.popup_centered()
	else:
		_drill_dialog.show()


func _refresh_casino_buttons(options: Array) -> void:
	_clear_owned_dialog_buttons(_casino_dialog, "CasinoButton_")
	for option in options:
		if not option is Dictionary:
			continue
		var game_id := str(option.get("id", ""))
		if game_id == "":
			continue
		var button := Button.new()
		button.name = "CasinoButton_%s" % game_id
		button.text = _minigame_name(game_id, str(option.get("display_name", "")))
		button.disabled = not bool(option.get("available", false))
		button.pressed.connect(_on_casino_button_pressed.bind(game_id))
		_casino_dialog.add_child(button)


func _refresh_auction_button(auction_id: String) -> void:
	_clear_owned_dialog_buttons(_auction_dialog, "AuctionButton_")
	var button := Button.new()
	button.name = "AuctionButton_start"
	button.text = "开始拍卖"
	button.pressed.connect(_on_auction_start_pressed.bind(auction_id))
	_auction_dialog.add_child(button)


func _refresh_job_button(job_id: String, check: Dictionary) -> void:
	_clear_owned_dialog_buttons(_job_dialog, "JobButton_")
	var definition: Dictionary = JobServiceScript.new().load_job_definition(job_id)
	var button := Button.new()
	button.name = "JobButton_%s" % job_id
	button.text = _job_name(job_id, definition)
	button.disabled = not bool(check.get("ok", false))
	button.pressed.connect(_on_job_start_pressed.bind(job_id))
	_job_dialog.add_child(button)


func _refresh_drill_button(drill_id: String, check: Dictionary) -> void:
	_clear_owned_dialog_buttons(_drill_dialog, "DrillButton_")
	var definition: Dictionary = _drill_runner().load_drill_definition(drill_id)
	var button := Button.new()
	button.name = "DrillButton_%s" % drill_id
	button.text = _drill_name(drill_id, definition)
	button.disabled = not bool(check.get("ok", false))
	button.pressed.connect(_on_drill_start_pressed.bind(drill_id))
	_drill_dialog.add_child(button)


func _clear_owned_dialog_buttons(dialog: AcceptDialog, prefix: String) -> void:
	if dialog == null:
		return
	for child in dialog.find_children("%s*" % prefix, "Button", true, false):
		if child is Button and str(child.name).begins_with(prefix):
			var parent := child.get_parent()
			if parent == dialog:
				dialog.remove_child(child)
			elif dialog.has_method("remove_button"):
				dialog.remove_button(child)
				if child.get_parent() != null:
					child.get_parent().remove_child(child)
			elif parent != null:
				parent.remove_child(child)
			child.queue_free()


func _on_casino_button_pressed(game_id: String) -> void:
	var service = MinigameServiceScript.new()
	var result: Dictionary = service.start_game(GameState, game_id, _default_casino_options(game_id))
	var lines: Array[String] = []
	if _casino_dialog != null and str(_casino_dialog.dialog_text) != "":
		lines.append(str(_casino_dialog.dialog_text))
	lines.append("本局结果：%s，%s" % [
		_minigame_name(game_id),
		_result_text_zh(result, "grade"),
	])
	if bool(result.get("ok", false)):
		var action_result := _try_city_action_encounter("casino_leave")
		lines.append(_action_encounter_text(action_result, "离开赌窟"))
	_casino_dialog.dialog_text = _join_lines(lines)
	_refresh_status()


func _on_auction_start_pressed(auction_id: String) -> void:
	var service = AuctionServiceScript.new()
	var result: Dictionary = service.start_auction(GameState, auction_id, {
		"lot_count": 1,
		"player_bids": [300],
		"ai_rolls": [[0.0, 0.0]],
	})
	var lines: Array[String] = []
	if _auction_dialog != null and str(_auction_dialog.dialog_text) != "":
		lines.append(str(_auction_dialog.dialog_text))
	lines.append("拍卖结果：%s" % _auction_result_text(result))
	_auction_dialog.dialog_text = _join_lines(lines)
	_refresh_status()


func _on_job_start_pressed(job_id: String) -> void:
	var service = JobServiceScript.new()
	var result: Dictionary = service.start_job(GameState, job_id, _default_job_options(job_id))
	var lines: Array[String] = []
	if _job_dialog != null and str(_job_dialog.dialog_text) != "":
		lines.append(str(_job_dialog.dialog_text))
	lines.append("结算结果：%s，%s，消耗 %d AP" % [
		_job_name(job_id),
		_result_text_zh(result, "grade"),
		int(result.get("ap_cost", 0)),
	])
	if bool(result.get("ok", false)):
		var commission_result := _record_city_job_commission_completion(job_id, result)
		var commission_text := _city_commission_completion_text(commission_result)
		if commission_text != "":
			lines.append(commission_text)
		for intel_text in _granted_intel_texts(result):
			lines.append("获得情报：%s" % intel_text)
	if job_id == "errand_runner" and bool(result.get("ok", false)):
		var action_result := _try_city_action_encounter("errand")
		lines.append(_action_encounter_text(action_result, "跑腿结束"))
	_job_dialog.dialog_text = _join_lines(lines)
	_refresh_status()


func _on_drill_start_pressed(drill_id: String) -> void:
	var runner = _drill_runner()
	var result: Dictionary = runner.resolve_drill(GameState, drill_id, _default_drill_options(drill_id))
	var lines: Array[String] = []
	var ai_gm_text := str(result.get("ai_gm_text", "")).strip_edges()
	if ai_gm_text != "":
		lines.append(ai_gm_text)
	if _drill_dialog != null and str(_drill_dialog.dialog_text) != "":
		lines.append(str(_drill_dialog.dialog_text))
	lines.append("演练结果：%s，%s，消耗 %d AP" % [
		_drill_name(drill_id),
		_result_text_zh(result, "outcome"),
		int(result.get("ap_cost", 0)),
	])
	if bool(result.get("ok", false)):
		var commission_result := _record_city_drill_commission_completion(drill_id, result)
		var commission_text := _city_commission_completion_text(commission_result)
		if commission_text != "":
			lines.append(commission_text)
		for intel_text in _granted_intel_texts(result):
			lines.append("获得情报：%s" % intel_text)
	_drill_dialog.dialog_text = _join_lines(lines)
	_refresh_status()


func _default_casino_options(game_id: String) -> Dictionary:
	match game_id:
		"dice_cup":
			return {"bet": 3, "choice": "big", "dice": [4, 4, 3]}
		"tarot_divination":
			return {"bet": 50, "roll": 0.70, "reward_roll": 1.0}
		"fate_cards":
			return {"bet": 200, "choice_id": "truth_halfmoon", "truth_id": "truth_halfmoon"}
		_:
			return {}


func _default_job_options(job_id: String) -> Dictionary:
	match job_id:
		"factory_shift":
			return {"grade": "perfect"}
		"dock_shift":
			return {"mode": "cargo"}
		"fishing_shift":
			return {"mode": "fishing", "roll": 0.01}
		"errand_runner":
			return {"same_district": true}
		"worship_observation":
			return {"grade": "perfect"}
		"mountain_solitary_walk":
			return {"grade": "perfect"}
		_:
			return {}


func _default_drill_options(drill_id: String) -> Dictionary:
	var runner = DrillRunnerScript.new()
	var definition: Dictionary = runner.load_drill_definition(drill_id)
	var rules: Array = definition.get("rules", []) if definition.get("rules", []) is Array else []
	var rule_ids: Array[String] = []
	for rule in rules:
		if rule is Dictionary:
			rule_ids.append(str((rule as Dictionary).get("id", "")))
	var thought_ids := _default_thought_card_ids()
	var rule_card_map := {}
	if thought_ids.size() > 0:
		for rule_id in rule_ids:
			rule_card_map[rule_id] = thought_ids[0]
	return {
		"satisfied_rule_ids": rule_ids,
		"thought_card_ids": thought_ids,
		"rule_card_map": rule_card_map,
	}


func _default_thought_card_ids() -> Array[String]:
	var result: Array[String] = []
	if not is_instance_valid(GameState):
		return result
	for card in GameState.cards_inventory:
		if card != null and str(card.get("id")) != "":
			result.append(str(card.get("id")))
			return result
	for card in GameState.temp_picked_cards:
		if card != null and str(card.get("id")) != "":
			result.append(str(card.get("id")))
			return result
	return result


func _rumor_draw_count_today(pool_id: String) -> int:
	if not is_instance_valid(GameState):
		return 0
	var history: Dictionary = GameState.minigame_history if GameState.minigame_history is Dictionary else {}
	var daily: Dictionary = history.get("daily", {}) if history.get("daily", {}) is Dictionary else {}
	return int(daily.get(_rumor_daily_key(pool_id), 0))


func _record_rumor_draw(pool_id: String) -> void:
	if not is_instance_valid(GameState):
		return
	var history: Dictionary = GameState.minigame_history if GameState.minigame_history is Dictionary else {}
	var daily: Dictionary = history.get("daily", {}) if history.get("daily", {}) is Dictionary else {}
	var key := _rumor_daily_key(pool_id)
	daily[key] = int(daily.get(key, 0)) + 1
	history["daily"] = daily
	GameState.minigame_history = history


func _rumor_daily_key(pool_id: String) -> String:
	return "rumor:%d:%d:%s" % [int(GameState.cycle), int(GameState.day), pool_id]


func _rumor_seed(pool_id: String, draw_index: int) -> int:
	return absi(hash("%d:%d:%s:%d" % [int(GameState.cycle), int(GameState.day), pool_id, draw_index]))


func _active_rumors(game_state) -> Array:
	if game_state == null:
		return []
	var value: Variant = game_state.get("active_rumors")
	return value if value is Array else []


func _try_city_action_encounter(action_id: String) -> Dictionary:
	if _city_scene_panel == null or not _city_scene_panel.has_method("trigger_action_encounter"):
		return {"ok": false, "triggered": false, "reason": "missing_city_scene"}
	if _city_scene_panel.has_method("on_action_complete"):
		return _city_scene_panel.on_action_complete(
			action_id,
			str(GameState.current_district),
			_encounter_meta_float("encounter_action_roll"),
			_encounter_meta_float("encounter_action_pool_roll")
		)
	return _city_scene_panel.trigger_action_encounter(
		action_id,
		_encounter_meta_float("encounter_action_roll"),
		_encounter_meta_float("encounter_action_pool_roll")
	)


func _record_city_job_commission_completion(job_id: String, result: Dictionary) -> Dictionary:
	var dispatch := _active_activity_commission_dispatch("job", job_id)
	if dispatch.is_empty():
		return {}
	var target := _commission_dispatch_target(dispatch)
	var commission_type := str(dispatch.get("commission_type", ""))
	var event := {}
	match commission_type:
		"gather":
			var item_id := str(target.get("item_id", ""))
			if item_id == "":
				return {}
			event = {
				"event": "loot_resolved",
				"district": _activity_dispatch_district(dispatch),
				"time": str(GameState.time_of_day),
				"item_id": item_id,
				"count_added": maxi(1, int(target.get("count", result.get("count_added", 1)))),
			}
		"perform":
			event = {
				"event": "perform_action",
				"district": _activity_dispatch_district(dispatch),
				"action_id": str(target.get("action_id", job_id)),
				"witness_count": int(result.get("witness_count", 0)),
			}
		_:
			return {}
	return _record_city_commission_completion(dispatch, event)


func _record_city_drill_commission_completion(drill_id: String, result: Dictionary) -> Dictionary:
	if str(result.get("outcome", "")) == "fail":
		return {}
	var dispatch := _active_activity_commission_dispatch("drill", drill_id)
	if dispatch.is_empty():
		return {}
	var target := _commission_dispatch_target(dispatch)
	var commission_type := str(dispatch.get("commission_type", ""))
	var event := {}
	match commission_type:
		"perform":
			event = {
				"event": "perform_action",
				"district": _activity_dispatch_district(dispatch),
				"action_id": str(target.get("action_id", drill_id)),
				"witness_count": int(result.get("witness_count", 0)),
			}
		"gather":
			var item_id := str(target.get("item_id", ""))
			if item_id == "":
				return {}
			event = {
				"event": "loot_resolved",
				"district": _activity_dispatch_district(dispatch),
				"time": str(GameState.time_of_day),
				"item_id": item_id,
				"count_added": maxi(1, int(target.get("count", 1))),
			}
		_:
			return {}
	return _record_city_commission_completion(dispatch, event)


func _record_city_commission_completion(dispatch: Dictionary, event: Dictionary) -> Dictionary:
	if dispatch.is_empty() or event.is_empty() or not is_instance_valid(GameState):
		return {}
	var completion_result: Dictionary = CommissionServiceScript.new().record_completion_event(GameState, event)
	if _array_from_variant(completion_result.get("completed_ids", [])).size() > 0:
		if _completion_includes_active_dispatch(completion_result) and GameState.has_method("remove_meta") and GameState.has_meta("commission_active_dispatch"):
			GameState.remove_meta("commission_active_dispatch")
		if _commission_panel != null and _commission_panel.has_method("_refresh"):
			_commission_panel.call("_refresh")
	return completion_result


func _active_activity_commission_dispatch(dispatch_kind: String, activity_id: String) -> Dictionary:
	if not is_instance_valid(GameState):
		return {}
	if GameState.has_method("get_meta"):
		var value: Variant = GameState.get_meta("commission_active_dispatch", {})
		if value is Dictionary:
			var dispatch: Dictionary = value.duplicate(true)
			if _activity_dispatch_matches(dispatch, dispatch_kind, activity_id):
				return dispatch
	return _accepted_activity_commission_dispatch(dispatch_kind, activity_id)


func _accepted_activity_commission_dispatch(dispatch_kind: String, activity_id: String) -> Dictionary:
	if not is_instance_valid(GameState):
		return {}
	for raw_id in GameState.accepted_commissions:
		var commission_id := str(raw_id)
		var commission := _commission_dict_for_state(commission_id)
		if commission.is_empty():
			continue
		var status := str(commission.get("status", ""))
		if ["completed", "claimed", "expired"].has(status):
			continue
		var target: Dictionary = commission.get("dispatch_target", {}) if commission.get("dispatch_target", {}) is Dictionary else {}
		if not _activity_target_matches(target, commission, dispatch_kind, activity_id):
			continue
		return {
			"commission_id": commission_id,
			"commission_type": str(commission.get("commission_type", "")),
			"dispatch_kind": dispatch_kind,
			"dispatch_target": target.duplicate(true),
			"district": str(commission.get("district", target.get("district", ""))),
		}
	return {}


func _activity_dispatch_matches(dispatch: Dictionary, dispatch_kind: String, activity_id: String) -> bool:
	if str(dispatch.get("dispatch_kind", "")) != dispatch_kind:
		return false
	var target := _commission_dispatch_target(dispatch)
	return _activity_target_matches(target, dispatch, dispatch_kind, activity_id)


func _activity_target_matches(target: Dictionary, source: Dictionary, dispatch_kind: String, activity_id: String) -> bool:
	if str(target.get("kind", dispatch_kind)) != dispatch_kind:
		return false
	var id_key := "%s_id" % dispatch_kind
	if str(target.get(id_key, "")) != activity_id:
		return false
	var target_district := str(target.get("district", source.get("district", "")))
	var current_district := str(GameState.current_district) if is_instance_valid(GameState) else ""
	if target_district != "" and current_district != "" and target_district != current_district:
		return false
	return true


func _commission_dict_for_state(commission_id: String) -> Dictionary:
	if not is_instance_valid(GameState) or commission_id == "":
		return {}
	var available: Variant = GameState.get("available_commissions")
	if available is Array:
		for item in available:
			if not item is Dictionary:
				continue
			var data: Dictionary = item
			if str(data.get("id", "")) == commission_id:
				return data.duplicate(true)
	var template = CommissionServiceScript.new().get_library().get_template(commission_id)
	if template != null and template.has_method("to_dict") and not template.is_empty():
		return template.to_dict()
	return {}


func _completion_includes_active_dispatch(completion_result: Dictionary) -> bool:
	if not is_instance_valid(GameState) or not GameState.has_method("get_meta") or not GameState.has_meta("commission_active_dispatch"):
		return false
	var value: Variant = GameState.get_meta("commission_active_dispatch", {})
	if not value is Dictionary:
		return false
	var commission_id := str((value as Dictionary).get("commission_id", ""))
	if commission_id == "":
		return false
	for completed_id in _array_from_variant(completion_result.get("completed_ids", [])):
		if str(completed_id) == commission_id:
			return true
	return false


func _activity_dispatch_district(dispatch: Dictionary) -> String:
	var target := _commission_dispatch_target(dispatch)
	var target_district := str(target.get("district", dispatch.get("district", "")))
	if target_district != "":
		return target_district
	return str(GameState.current_district) if is_instance_valid(GameState) else ""


func _city_commission_completion_text(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	if _array_from_variant(result.get("completed_ids", [])).size() > 0:
		return "委托进度：已完成，可回告示牌交差。"
	if _array_from_variant(result.get("progress_ids", [])).size() > 0:
		return "委托进度：已记录。"
	return ""


func _granted_intel_texts(result: Dictionary) -> Array[String]:
	var output: Array[String] = []
	var texts: Variant = result.get("granted_intel_texts", [])
	if not texts is Array:
		return output
	for text in texts:
		var value := str(text)
		if value != "":
			output.append(value)
	return output


func _array_from_variant(value: Variant) -> Array:
	return value if value is Array else []


func _encounter_meta_float(key: String) -> float:
	if is_instance_valid(GameState) and GameState.has_meta(key):
		return float(GameState.get_meta(key))
	return -1.0


func _hide_placeholder_if_visible() -> void:
	if _placeholder_dialog != null and _placeholder_dialog.visible:
		_placeholder_dialog.hide()


func _show_city_hotspot_placeholder(hotspot: Dictionary, title_text: String, payload_keys: Array) -> void:
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var lines: Array[String] = [
		"%s：%s" % [title_text, str(hotspot.get("label", hotspot.get("id", "")))],
		"暂时还没有接好。",
	]
	for key in payload_keys:
		var key_text := str(key)
		if payload.has(key_text):
			lines.append("需要的线索已记录。")
	_show_placeholder(_join_lines(lines))


func _on_tower_runner_completed(tower) -> void:
	if not is_instance_valid(GameState):
		return
	var tower_district := _tower_district(tower)
	var dispatch := _active_tower_commission_dispatch(tower_district)
	if dispatch.is_empty():
		return
	var target := _commission_dispatch_target(dispatch)
	var boss_id := _tower_boss_id(tower)
	if boss_id == "":
		boss_id = str(target.get("boss", target.get("boss_defeated_id", "")))
	var event := {
		"event": "tower_complete",
		"district": _event_district_for_tower(tower, dispatch),
		"tower_size": _tower_size(tower),
		"tower_id": _tower_id(tower),
		"boss_defeated_id": boss_id,
		"victory": true,
	}
	var completion_result: Dictionary = CommissionServiceScript.new().record_completion_event(GameState, event)
	if completion_result.has("completed_ids") and Array(completion_result.get("completed_ids", [])).size() > 0:
		if GameState.has_method("remove_meta") and GameState.has_meta("commission_active_dispatch"):
			GameState.remove_meta("commission_active_dispatch")
	if _commission_panel != null and _commission_panel.has_method("_refresh"):
		_commission_panel.call("_refresh")


func _on_tower_runner_event_resolved(tower, event_result: Dictionary) -> void:
	if not is_instance_valid(GameState):
		return
	var tower_district := _tower_district(tower)
	var dispatch := _active_tower_commission_dispatch(tower_district)
	if dispatch.is_empty() or str(dispatch.get("dispatch_kind", "")) != "tower_event":
		return
	var event := {
		"event": "tower_event_resolved",
		"district": _event_district_for_tower(tower, dispatch),
		"tower_id": _tower_id(tower),
		"event_id": str(event_result.get("event_id", "")),
		"choice_id": str(event_result.get("choice_id", "")),
	}
	var completion_result: Dictionary = CommissionServiceScript.new().record_completion_event(GameState, event)
	if completion_result.has("completed_ids") and Array(completion_result.get("completed_ids", [])).size() > 0:
		if GameState.has_method("remove_meta") and GameState.has_meta("commission_active_dispatch"):
			GameState.remove_meta("commission_active_dispatch")
	if _commission_panel != null and _commission_panel.has_method("_refresh"):
		_commission_panel.call("_refresh")


func _active_tower_commission_dispatch(district_id: String) -> Dictionary:
	if not is_instance_valid(GameState) or not GameState.has_method("get_meta"):
		return {}
	var value: Variant = GameState.get_meta("commission_active_dispatch", {})
	if not value is Dictionary:
		return {}
	var dispatch: Dictionary = value.duplicate(true)
	if not (str(dispatch.get("dispatch_kind", "")) in ["tower", "tower_event"]):
		return {}
	var commission_id := str(dispatch.get("commission_id", ""))
	if commission_id != "" and not (commission_id in GameState.accepted_commissions):
		return {}
	var target := _commission_dispatch_target(dispatch)
	var target_district := str(target.get("district", dispatch.get("district", "")))
	if target_district != "" and district_id != "" and target_district != district_id:
		return {}
	return dispatch


func _commission_dispatch_target(dispatch: Dictionary) -> Dictionary:
	var target: Variant = dispatch.get("dispatch_target", {})
	return target.duplicate(true) if target is Dictionary else {}


func _commission_title_for_dispatch(dispatch: Dictionary) -> String:
	var commission_id := str(dispatch.get("commission_id", ""))
	if is_instance_valid(GameState):
		var available: Variant = GameState.get("available_commissions")
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
	return "当前委托"


func _event_district_for_tower(tower, dispatch: Dictionary) -> String:
	var target := _commission_dispatch_target(dispatch)
	var target_district := str(target.get("district", dispatch.get("district", "")))
	if target_district != "":
		return target_district
	return _tower_district(tower)


func _apply_commission_dispatch_to_tower(tower, dispatch: Dictionary) -> void:
	if tower == null or dispatch.is_empty():
		return
	var target := _commission_dispatch_target(dispatch)
	tower.theme_modifiers["commission_dispatch"] = dispatch.duplicate(true)
	tower.theme_modifiers["commission_id"] = str(dispatch.get("commission_id", ""))
	var target_district := str(target.get("district", dispatch.get("district", "")))
	if target_district != "":
		tower.district = target_district
	var target_size := str(target.get("tower_size", ""))
	if target_size != "":
		tower.size = target_size
	var target_theme := str(target.get("theme", ""))
	if target_theme != "":
		tower.theme_modifiers["commission_theme"] = target_theme
	var boss_id := str(target.get("boss", target.get("boss_defeated_id", "")))
	if boss_id != "":
		_set_tower_boss_id(tower, boss_id)
	if str(dispatch.get("dispatch_kind", "")) == "tower_event":
		_apply_commission_event_to_tower(tower, dispatch)


func _apply_commission_event_to_tower(tower, dispatch: Dictionary) -> void:
	if tower == null:
		return
	var target := _commission_dispatch_target(dispatch)
	var event_id := str(target.get("required_event_id", ""))
	if event_id == "":
		return
	var event_index := _first_commission_event_floor_index(tower)
	if event_index < 0:
		return
	var floor = tower.floors[event_index]
	if floor == null:
		return
	floor.event_type = "event"
	floor.resolution = "pending"
	floor.event_data = _commission_event_data(dispatch, event_id)
	tower.theme_modifiers["commission_required_event_id"] = event_id


func _first_commission_event_floor_index(tower) -> int:
	if tower == null:
		return -1
	for i in range(tower.floors.size()):
		var floor = tower.floors[i]
		if floor != null and str(floor.event_type) != "boss":
			return i
	return -1


func _commission_event_data(dispatch: Dictionary, event_id: String) -> Dictionary:
	var target := _commission_dispatch_target(dispatch)
	var title: String = _commission_title_for_dispatch(dispatch)
	if title == "" or not _has_cjk(title):
		title = "委托线索"
	var accepted: Array = _array_from_variant(target.get("accepted_choices", []))
	if accepted.is_empty():
		accepted.append("resolve")
	var choices: Array = []
	for choice_id in accepted:
		choices.append({
			"id": str(choice_id),
			"text": _commission_event_choice_text(str(choice_id)),
			"outcome": {},
		})
	choices.append({"id": "leave", "text": "暂且离开", "outcome": {}})
	return {
		"event_id": event_id,
		"title": title,
		"narrative_template": "你按委托留下的线索抵达这里。关键痕迹已经出现，完成选择后回告示牌交差。",
		"choices": choices,
	}


func _commission_event_choice_text(choice_id: String) -> String:
	match choice_id:
		"listen":
			return "伏身倾听"
		"copy_manifest":
			return "抄下货单"
		"observe_quietly":
			return "安静旁观"
		"touch_reflection":
			return "触碰倒影"
		"enter_with_mask":
			return "戴面具入内"
		_:
			return "按线索行动"


func _set_tower_boss_id(tower, boss_id: String) -> void:
	if tower == null or boss_id == "":
		return
	tower.theme_modifiers["commission_boss_id"] = boss_id
	for i in range(tower.floors.size() - 1, -1, -1):
		var floor = tower.floors[i]
		if floor != null and str(floor.event_type) == "boss":
			if floor.event_data is Dictionary:
				floor.event_data["boss_id"] = boss_id
			return


func _tower_boss_id(tower) -> String:
	if tower == null:
		return ""
	for i in range(tower.floors.size() - 1, -1, -1):
		var floor = tower.floors[i]
		if floor != null and str(floor.event_type) == "boss":
			var data: Dictionary = floor.event_data if floor.event_data is Dictionary else {}
			return str(data.get("boss_id", ""))
	return ""


func _tower_district(tower) -> String:
	if tower == null:
		return str(GameState.current_district) if is_instance_valid(GameState) else ""
	return str(tower.district)


func _tower_size(tower) -> String:
	return "" if tower == null else str(tower.size)


func _tower_id(tower) -> String:
	return "" if tower == null else str(tower.tower_id)


func _open_tower_from_city_hotspot(hotspot: Dictionary) -> void:
	if _tower_runner_panel == null or not _tower_runner_panel.has_method("open"):
		_show_placeholder("塔内场景暂时不可用。")
		return
	var payload: Dictionary = hotspot.get("payload", {}) if hotspot.get("payload", {}) is Dictionary else {}
	var tower_size := str(payload.get("tower_size", "small"))
	var district_id := str(GameState.current_district)
	if district_id == "":
		district_id = "shadow_alley"
	var dispatch := _active_tower_commission_dispatch(district_id)
	var dispatch_target := _commission_dispatch_target(dispatch)
	if not dispatch_target.is_empty():
		var target_district := str(dispatch_target.get("district", dispatch.get("district", "")))
		if target_district != "":
			district_id = target_district
		var target_size := str(dispatch_target.get("tower_size", ""))
		if target_size != "":
			tower_size = target_size
	var generator = TowerGeneratorScript.new()
	var tower = generator.spawn_tower(tower_size, district_id, GameState)
	if tower == null:
		_show_placeholder("塔的结构暂时生成失败。")
		return
	var tower_template := str(payload.get("tower_template", ""))
	if tower_template != "":
		tower.theme_modifiers["tower_template"] = tower_template
	for key in ["mainline_hook_id", "mainline_node_id", "cycle_end_on_complete"]:
		if payload.has(key):
			tower.theme_modifiers[key] = payload[key]
	if payload.has("tower_label"):
		tower.tower_name = str(payload.get("tower_label", tower.tower_name))
	if not dispatch.is_empty():
		_apply_commission_dispatch_to_tower(tower, dispatch)
	if _should_prompt_contract_picker(tower):
		_pending_tower_open = {"tower": tower}
		_open_contract_picker_for_tower()
		return
	_finalize_tower_open(tower)


func _should_prompt_contract_picker(tower) -> bool:
	if tower != null and bool(tower.is_ritual_tower):
		return false
	if GameState == null:
		return false
	var active: Array = GameState.active_contract if GameState.active_contract is Array else []
	return active.size() < ContractPickerScript.REQUIRED_RULE_COUNT


func _setup_contract_picker_dialog() -> void:
	if _contract_picker_dialog != null:
		return
	var scene_path := "res://scenes/ui/contract_picker_dialog.tscn"
	var dialog: Control = null
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		if scene != null and scene.can_instantiate():
			dialog = scene.instantiate()
	if dialog == null:
		dialog = ContractPickerScript.new()
	dialog.name = "ContractPickerDialog"
	dialog.hide()
	add_child(dialog)
	_contract_picker_dialog = dialog
	if dialog.has_signal("contract_locked") and not dialog.contract_locked.is_connected(_on_contract_picker_locked):
		dialog.contract_locked.connect(_on_contract_picker_locked)
	if dialog.has_signal("contract_cancelled") and not dialog.contract_cancelled.is_connected(_on_contract_picker_cancelled):
		dialog.contract_cancelled.connect(_on_contract_picker_cancelled)


func _open_contract_picker_for_tower() -> void:
	_setup_contract_picker_dialog()
	if _contract_picker_dialog == null or not _contract_picker_dialog.has_method("open"):
		# 兜底：UI 不可用时仍走默认契约
		var tower = _pending_tower_open.get("tower", null)
		_pending_tower_open = {}
		if tower != null:
			_finalize_tower_open(tower)
		return
	if _district_select_panel != null:
		_district_select_panel.hide()
	_set_city_interaction_surface_visible(false)
	_contract_picker_dialog.open(GameState)


func _on_contract_picker_locked(_rules: Array) -> void:
	var tower = _pending_tower_open.get("tower", null)
	_pending_tower_open = {}
	if tower != null:
		_finalize_tower_open(tower)


func _on_contract_picker_cancelled() -> void:
	_pending_tower_open = {}
	_set_city_interaction_surface_visible(true)
	_show_placeholder("已取消进塔：未锁定契约。")


func _finalize_tower_open(tower) -> void:
	var result: Dictionary = _tower_runner_panel.open(tower, GameState)
	if bool(result.get("ok", false)):
		if _city_scene_panel != null:
			_city_scene_panel.hide()
	else:
		_set_city_interaction_surface_visible(true)
		_show_placeholder("暂时无法进入塔内：%s" % _reason_text_zh(str(result.get("reason", ""))))


func _on_promotion_pressed() -> void:
	if _promotion_ready_dialog != null and _promotion_ready_dialog.visible:
		_promotion_ready_dialog.hide()
	if _try_force_sleep_before_action():
		return
	var service = load(PROMOTION_SERVICE_PATH)
	if service == null:
		return
	var gate_id: String = service.next_gate_id(GameState)
	if gate_id == "" or not bool(service.can_start_ritual(gate_id, GameState)):
		_refresh_promotion_button()
		return
	var result: Dictionary = service.start_ritual(gate_id, GameState)
	if not bool(result.get("ok", false)):
		_refresh_promotion_button()
		return
	var tower = result.get("tower", null)
	if tower != null and _tower_runner_panel != null and _tower_runner_panel.has_method("open"):
		_tower_runner_panel.open(tower, GameState)
	_refresh_promotion_button()


func _all_subpanels_hidden() -> bool:
	var panels: Array = [
		_card_inventory_panel,
		_brand_workshop_panel,
		_deck_builder_panel,
		_black_market_panel,
		_commission_panel,
		_district_select_panel,
		_city_scene_panel,
		_tower_runner_panel,
		_meditation_panel,
		_settings_panel,
		_gray_crown_daily_dialog,
	]
	for panel in panels:
		if panel != null and is_instance_valid(panel) and panel.visible:
			return false
	return true
