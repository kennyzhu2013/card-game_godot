class_name BattleScene
extends Control

# R04 战斗场景 UI（杀戮尖塔风格）
# 上半屏敌人列、下半屏手牌列、左侧能量水晶/玩家血条、右侧抽弃牌堆/结束回合按钮
# 入口：BattleScene.start_battle(active_deck, picked_cards, enemies, contract, player_actor, game_state, victory_drops)

const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const ArtManifestScript = preload("res://scripts/art_manifest.gd")
const StatusTextScript = preload("res://scripts/combat/status_text.gd")
const BattleCardViewScript = preload("res://scripts/ui/battle/battle_card_view.gd")
const CardPeekPanelScript = preload("res://scripts/ui/battle/card_peek_panel.gd")
const PileInspectPanelScript = preload("res://scripts/ui/battle/pile_inspect_panel.gd")
const PlayerStandeeScript = preload("res://scripts/ui/battle/player_standee.gd")
const EnemyStandeeScript = preload("res://scripts/ui/battle/enemy_standee.gd")
const BattleDropSurfaceScript = preload("res://scripts/ui/battle/battle_drop_surface.gd")
const BattleFeedbackLayerScript = preload("res://scripts/ui/battle/battle_feedback_layer.gd")
const BattleResultOverlayScript = preload("res://scripts/ui/battle/battle_result_overlay.gd")

signal battle_finished(result: Dictionary)

const ENERGY_FONT_SIZE := 22
const HAND_CARD_WIDTH := 156
const HAND_CARD_MIN_WIDTH := 108
const HAND_CARD_COMPACT_MIN_WIDTH := 48.0
const HAND_CARD_HEIGHT := 162
const HAND_CARD_SEPARATION := 8
const BATTLE_SAFE_MARGIN_VERTICAL := 24.0
const BATTLE_ROOT_SEPARATION := 6.0
const HAND_RAIL_VERTICAL_PADDING := 16.0
const HAND_CARD_VIEWPORT_HEIGHT_RATIO := 0.317
const HAND_CARD_MAX_VIEWPORT_HEIGHT := 280.0
const HAND_CARD_ABSOLUTE_MIN_HEIGHT := 72.0
const ARENA_TOP_BAR_MIN_HEIGHT := 108.0
const BOTTOM_RAIL_MIN_HEIGHT := 36.0
const ARENA_MIN_HEIGHT := 280.0
const ARENA_COMPACT_MIN_HEIGHT := 160.0
const STANDEE_MIN_HEIGHT := 210.0
const STANDEE_COMPACT_MIN_HEIGHT := 150.0
const COMPACT_LAYOUT_SAFETY_GAP := 8.0
const ENEMY_STANDEE_BASE_WIDTH := 140.0
const ENEMY_STANDEE_MEDIUM_WIDTH := 180.0
const ENEMY_STANDEE_WIDE_WIDTH := 300.0

var _battle = null
var _game_state = null
var _player = null
var _victory_drops: Dictionary = {}
var _selected_card = null
var _selected_target = null
var _result: Dictionary = {}
var _last_action_message: String = ""

var _enemy_box: HBoxContainer
var _hand_rail: PanelContainer
var _hand_box: HBoxContainer
var _energy_label: Label
var _player_hp_label: Label
var _draw_pile_label: Label
var _discard_pile_label: Label
var _player_status_label: Label
var _end_turn_button: Button
var _message_label: Label
var _battle_log_label: Label
var _rules_label: Label
var _contract_label: Label
var _field_state_label: Label
var _status_detail_label: Label
var _charge_zone_box: VBoxContainer
var _reward_panel: Control
var _reward_box: VBoxContainer
var _draw_filter_panel: Panel
var _draw_filter_box: VBoxContainer
var _target_selection_panel: Panel
var _target_selection_box: VBoxContainer
var _battle_log_entries: Array[String] = []
var _target_selection_card = null
var _target_selection_targets: Array = []
var _pollution_hud: Control
var _feedback_layer: Control
var _narrative_rail: Control
var _narrative_label: Label
var _player_standee: Control
var _arena_layer_stack: Control
var _player_stage: Control
var _bottom_chip_rail: HBoxContainer
var _battle_log_drawer: PanelContainer
var _battle_log_drawer_content: Control
var _battle_log_drawer_toggle: Button
var _battle_log_drawer_expanded := false
var _card_peek_panel: Control
var _pile_inspect_panel: Control
var _last_input_was_keyboard := false
var _arena_top_bar: PanelContainer
var _contract_chip_rail: HBoxContainer
var _turn_counter_chip: PanelContainer
var _learned_rule_chip_rail: HBoxContainer
var _arena_rule_detail_label: Label
var _arena_background: TextureRect
var _arena_drop_surface: Control
var _drop_highlight_drag_active := false
var _pending_card_travel_animation: Dictionary = {}
var _layout_refresh_queued := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	_crossfade_bgm("tower_combat")


func _bgm_autoload() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Bgm")


func _crossfade_bgm(track_id: String, duration: float = 1.5) -> void:
	var bgm := _bgm_autoload()
	if bgm != null and bgm.has_method("crossfade_to"):
		bgm.call("crossfade_to", track_id, duration)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_drop_highlight_drag_active = true
		_update_drop_hover_flags(get_global_mouse_position())
	elif what == NOTIFICATION_DRAG_END:
		_drop_highlight_drag_active = false
		set_meta("background_aoe_drop_active", false)
		_clear_drop_highlights()


func _on_viewport_size_changed() -> void:
	_schedule_layout_refresh()


func _schedule_layout_refresh() -> void:
	if _layout_refresh_queued:
		return
	_layout_refresh_queued = true
	call_deferred("_refresh_layout_after_container_settle")


func _refresh_layout_after_container_settle() -> void:
	_layout_refresh_queued = false
	if _battle == null:
		return
	_apply_responsive_layout_budget()
	_render_hand()


func start_battle(active_deck: Array, picked_cards: Array, enemies: Array, contract: Array[String], player_actor, game_state, victory_drops: Dictionary = {}, battle_context: Dictionary = {}) -> void:
	_game_state = game_state if game_state != null else GameState
	_player = player_actor
	if _player == null:
		_player = _make_default_player()
	_last_action_message = ""
	_set_narrative_text("")
	_battle_log_entries.clear()
	_victory_drops = victory_drops
	_setup_pollution_hud()
	_apply_tower_background(battle_context)
	_battle = TurnBattleScript.new()
	if _battle.has_signal("battle_log_entry"):
		_battle.battle_log_entry.connect(_on_battle_log_entry)
	_battle.setup_battle(active_deck, picked_cards, enemies, contract, _player, _game_state)
	_render()
	_schedule_layout_refresh()


# === UI 构造 ===
func show_ai_gm_narration(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	_set_narrative_text(clean)
	_set_last_action_message(clean)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.name = "BattleSafeMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "BattleSceneRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", BATTLE_ROOT_SEPARATION)
	margin.add_child(root)

	_narrative_rail = PanelContainer.new()
	_narrative_rail.name = "BattleNarrativeRail"
	_narrative_rail.custom_minimum_size = Vector2(0, 0)
	_narrative_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_narrative_rail.visible = false
	root.add_child(_narrative_rail)
	var narrative_margin := MarginContainer.new()
	narrative_margin.add_theme_constant_override("margin_left", 10)
	narrative_margin.add_theme_constant_override("margin_top", 6)
	narrative_margin.add_theme_constant_override("margin_right", 10)
	narrative_margin.add_theme_constant_override("margin_bottom", 6)
	_narrative_rail.add_child(narrative_margin)
	_narrative_label = Label.new()
	_narrative_label.name = "BattleNarrativeLabel"
	_narrative_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrative_label.max_lines_visible = 2
	_narrative_label.clip_text = true
	_narrative_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	narrative_margin.add_child(_narrative_label)

	_arena_top_bar = PanelContainer.new()
	_arena_top_bar.name = "ArenaTopBar"
	_arena_top_bar.custom_minimum_size = Vector2(0, ARENA_TOP_BAR_MIN_HEIGHT)
	_arena_top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena_top_bar.add_theme_stylebox_override("panel", _battle_chip_style(Color(0.08, 0.09, 0.12), Color(0.30, 0.36, 0.44), 1, 6))
	root.add_child(_arena_top_bar)
	var top_bar_margin := MarginContainer.new()
	top_bar_margin.add_theme_constant_override("margin_left", 8)
	top_bar_margin.add_theme_constant_override("margin_top", 5)
	top_bar_margin.add_theme_constant_override("margin_right", 8)
	top_bar_margin.add_theme_constant_override("margin_bottom", 5)
	_arena_top_bar.add_child(top_bar_margin)
	var top_bar_body := VBoxContainer.new()
	top_bar_body.name = "ArenaTopBarBody"
	top_bar_body.add_theme_constant_override("separation", 3)
	top_bar_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_margin.add_child(top_bar_body)
	var top_bar_row := HBoxContainer.new()
	top_bar_row.name = "ArenaTopBarRow"
	top_bar_row.add_theme_constant_override("separation", 8)
	top_bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar_body.add_child(top_bar_row)
	var contract_scroll := ScrollContainer.new()
	contract_scroll.name = "ContractChipScroll"
	contract_scroll.custom_minimum_size = Vector2(560, 30)
	contract_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contract_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	contract_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contract_scroll.clip_contents = true
	top_bar_row.add_child(contract_scroll)
	_contract_chip_rail = HBoxContainer.new()
	_contract_chip_rail.name = "ContractChipRail"
	_contract_chip_rail.add_theme_constant_override("separation", 6)
	_contract_chip_rail.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	contract_scroll.add_child(_contract_chip_rail)
	_turn_counter_chip = _make_arena_top_chip("TurnCounterChip", "回合 1")
	top_bar_row.add_child(_turn_counter_chip)
	var learned_scroll := ScrollContainer.new()
	learned_scroll.name = "LearnedRuleChipScroll"
	learned_scroll.custom_minimum_size = Vector2(420, 30)
	learned_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	learned_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	learned_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	learned_scroll.clip_contents = true
	top_bar_row.add_child(learned_scroll)
	_learned_rule_chip_rail = HBoxContainer.new()
	_learned_rule_chip_rail.name = "LearnedRuleChipRail"
	_learned_rule_chip_rail.add_theme_constant_override("separation", 6)
	_learned_rule_chip_rail.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	learned_scroll.add_child(_learned_rule_chip_rail)
	_arena_rule_detail_label = Label.new()
	_arena_rule_detail_label.name = "ArenaRuleDetailLabel"
	_arena_rule_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena_rule_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_arena_rule_detail_label.max_lines_visible = 3
	_arena_rule_detail_label.clip_text = false
	_arena_rule_detail_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_arena_rule_detail_label.add_theme_font_size_override("font_size", 13)
	top_bar_body.add_child(_arena_rule_detail_label)
	# Contract/rule chips must stay at the first visible row even when battle narration appears.
	root.move_child(_arena_top_bar, 0)

	var arena_layer_stack := Control.new()
	arena_layer_stack.name = "BattleArenaLayerStack"
	arena_layer_stack.custom_minimum_size = Vector2(0, ARENA_MIN_HEIGHT)
	arena_layer_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_layer_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_layer_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	arena_layer_stack.z_index = 20
	root.add_child(arena_layer_stack)
	_arena_layer_stack = arena_layer_stack

	_arena_drop_surface = BattleDropSurfaceScript.new()
	_arena_drop_surface.name = "BattleAoeDropSurface"
	_arena_drop_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena_drop_surface.z_index = 100
	_arena_drop_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_layer_stack.add_child(_arena_drop_surface)

	var arena_root := HBoxContainer.new()
	arena_root.name = "BattleArenaRoot"
	arena_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_root.add_theme_constant_override("separation", 10)
	arena_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_layer_stack.add_child(arena_root)

	var player_stage := Control.new()
	player_stage.name = "PlayerStage"
	player_stage.custom_minimum_size = Vector2(200, STANDEE_MIN_HEIGHT)
	player_stage.size_flags_horizontal = Control.SIZE_FILL
	player_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_stage.clip_contents = true
	player_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_root.add_child(player_stage)
	_player_stage = player_stage
	_player_standee = PlayerStandeeScript.new()
	_player_standee.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player_standee.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_standee.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_stage.add_child(_player_standee)
	_player_hp_label = Label.new()
	_player_status_label = Label.new()
	_rules_label = Label.new()
	_contract_label = Label.new()
	_status_detail_label = Label.new()
	if _player_standee.has_method("charge_zone_box"):
		_charge_zone_box = _player_standee.call("charge_zone_box") as VBoxContainer
	if _player_standee.has_method("field_state_label"):
		_field_state_label = _player_standee.call("field_state_label") as Label

	var arena_center := VBoxContainer.new()
	arena_center.name = "ArenaCenter"
	arena_center.custom_minimum_size = Vector2(220, 0)
	arena_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arena_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_center.add_theme_constant_override("separation", 8)
	arena_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_root.add_child(arena_center)

	var message_container := PanelContainer.new()
	message_container.name = "ArenaMessageRibbon"
	message_container.custom_minimum_size = Vector2(0, 32)
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_center.add_child(message_container)
	var message_margin := MarginContainer.new()
	message_margin.add_theme_constant_override("margin_left", 8)
	message_margin.add_theme_constant_override("margin_top", 4)
	message_margin.add_theme_constant_override("margin_right", 8)
	message_margin.add_theme_constant_override("margin_bottom", 4)
	message_container.add_child(message_margin)
	_message_label = Label.new()
	_message_label.name = "ArenaMessageLabel"
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.max_lines_visible = 1
	_message_label.clip_text = true
	_message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_margin.add_child(_message_label)

	var enemy_stage := Control.new()
	enemy_stage.name = "EnemyStage"
	enemy_stage.custom_minimum_size = Vector2(760, 0)
	enemy_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_stage.clip_contents = true
	enemy_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_root.add_child(enemy_stage)
	var enemy_stage_row := HBoxContainer.new()
	enemy_stage_row.name = "EnemyStageRow"
	enemy_stage_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	enemy_stage_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_stage_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_stage_row.add_theme_constant_override("separation", 8)
	enemy_stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_stage.add_child(enemy_stage_row)
	var enemy_panel := PanelContainer.new()
	enemy_panel.name = "EnemyRowPanel"
	enemy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_stage_row.add_child(enemy_panel)
	var enemy_scroll := ScrollContainer.new()
	enemy_scroll.name = "EnemyStageScroll"
	enemy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_scroll.clip_contents = true
	enemy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	enemy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	enemy_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_panel.add_child(enemy_scroll)
	_enemy_box = HBoxContainer.new()
	_enemy_box.name = "EnemyRow"
	_enemy_box.add_theme_constant_override("separation", 16)
	_enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_scroll.add_child(_enemy_box)

	var battle_log_container := PanelContainer.new()
	battle_log_container.name = "BattleLogSideDrawer"
	battle_log_container.custom_minimum_size = Vector2(24, 0)
	battle_log_container.size_flags_horizontal = Control.SIZE_FILL
	battle_log_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_container.clip_contents = true
	battle_log_container.add_theme_stylebox_override("panel", _battle_chip_style(Color(0.06, 0.07, 0.09, 0.96), Color(0.42, 0.48, 0.58), 1, 6))
	enemy_stage_row.add_child(battle_log_container)
	_battle_log_drawer = battle_log_container
	var battle_log_row := HBoxContainer.new()
	battle_log_row.name = "BattleLogDrawerRow"
	battle_log_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_row.add_theme_constant_override("separation", 4)
	battle_log_container.add_child(battle_log_row)
	_battle_log_drawer_toggle = Button.new()
	_battle_log_drawer_toggle.name = "BattleLogDrawerToggleButton"
	_battle_log_drawer_toggle.text = ">"
	_battle_log_drawer_toggle.custom_minimum_size = Vector2(22, 0)
	_battle_log_drawer_toggle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_log_drawer_toggle.pressed.connect(_on_battle_log_drawer_toggle_pressed)
	battle_log_row.add_child(_battle_log_drawer_toggle)
	var battle_log_margin := MarginContainer.new()
	battle_log_margin.name = "BattleLogDrawerContent"
	battle_log_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_margin.add_theme_constant_override("margin_left", 4)
	battle_log_margin.add_theme_constant_override("margin_top", 6)
	battle_log_margin.add_theme_constant_override("margin_right", 6)
	battle_log_margin.add_theme_constant_override("margin_bottom", 6)
	battle_log_row.add_child(battle_log_margin)
	_battle_log_drawer_content = battle_log_margin
	var battle_log_alias := VBoxContainer.new()
	battle_log_alias.name = "BattleLog"
	battle_log_alias.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_alias.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_margin.add_child(battle_log_alias)
	var battle_log_scroll := ScrollContainer.new()
	battle_log_scroll.name = "BattleLogScroll"
	battle_log_scroll.custom_minimum_size = Vector2(220, 0)
	battle_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_scroll.clip_contents = true
	battle_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	battle_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	battle_log_alias.add_child(battle_log_scroll)
	_battle_log_label = Label.new()
	_battle_log_label.name = "BattleLogLabel"
	_battle_log_label.custom_minimum_size = Vector2(220, 180)
	_battle_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_battle_log_label.max_lines_visible = 8
	_battle_log_label.clip_text = true
	_battle_log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_battle_log_label.add_theme_font_size_override("font_size", 12)
	_battle_log_label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98))
	battle_log_scroll.add_child(_battle_log_label)
	_set_battle_log_drawer_expanded(true)

	var hand_container := PanelContainer.new()
	hand_container.name = "HandRail"
	hand_container.custom_minimum_size = Vector2(0, HAND_CARD_HEIGHT + HAND_RAIL_VERTICAL_PADDING)
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hand_container.z_index = 10
	root.add_child(hand_container)
	_hand_rail = hand_container
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_container.add_child(hand_scroll)
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", HAND_CARD_SEPARATION)
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hand_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(_hand_box)

	var bottom := HBoxContainer.new()
	bottom.name = "BottomChipRail"
	bottom.custom_minimum_size = Vector2(0, BOTTOM_RAIL_MIN_HEIGHT)
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_theme_constant_override("separation", 8)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.z_index = 5
	root.add_child(bottom)
	_bottom_chip_rail = bottom
	_draw_pile_label = Label.new()
	_draw_pile_label.name = "DrawPileCountLabel"
	var draw_pile_chip := _make_pile_chip("DrawPileChip", _draw_pile_label)
	draw_pile_chip.gui_input.connect(_on_draw_pile_chip_gui_input)
	bottom.add_child(draw_pile_chip)
	_energy_label = Label.new()
	_energy_label.name = "EnergyOrbLabel"
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_energy_label.add_theme_font_size_override("font_size", ENERGY_FONT_SIZE)
	bottom.add_child(_make_energy_orb(_energy_label))
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)
	_end_turn_button = Button.new()
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.text = "结束回合"
	_end_turn_button.custom_minimum_size = Vector2(96, 32)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	bottom.add_child(_end_turn_button)
	var flee := Button.new()
	flee.name = "FleeButton"
	flee.text = "投降"
	flee.custom_minimum_size = Vector2(70, 32)
	flee.pressed.connect(_on_flee_pressed)
	bottom.add_child(flee)
	_discard_pile_label = Label.new()
	_discard_pile_label.name = "DiscardPileCountLabel"
	var discard_pile_chip := _make_pile_chip("DiscardPileChip", _discard_pile_label)
	discard_pile_chip.gui_input.connect(_on_discard_pile_chip_gui_input)
	bottom.add_child(discard_pile_chip)

	_reward_panel = BattleResultOverlayScript.new()
	_reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	var reward_overlay_size := Vector2(760, 420)
	_reward_panel.custom_minimum_size = reward_overlay_size
	_reward_panel.offset_left = -reward_overlay_size.x * 0.5
	_reward_panel.offset_top = -reward_overlay_size.y * 0.5
	_reward_panel.offset_right = reward_overlay_size.x * 0.5
	_reward_panel.offset_bottom = reward_overlay_size.y * 0.5
	_reward_panel.z_index = 100
	_reward_panel.visible = false
	if _reward_panel.has_signal("reward_chosen"):
		_reward_panel.connect("reward_chosen", Callable(self, "_on_reward_picked"))
	add_child(_reward_panel)
	if _reward_panel.has_method("reward_box"):
		_reward_box = _reward_panel.call("reward_box") as VBoxContainer
	else:
		_reward_box = VBoxContainer.new()

	_draw_filter_panel = Panel.new()
	_draw_filter_panel.name = "DrawFilterPanel"
	_draw_filter_panel.set_anchors_preset(Control.PRESET_CENTER)
	_draw_filter_panel.custom_minimum_size = Vector2(480, 300)
	_draw_filter_panel.z_index = 50
	_draw_filter_panel.visible = false
	add_child(_draw_filter_panel)
	var draw_filter_margin := MarginContainer.new()
	draw_filter_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_filter_margin.add_theme_constant_override("margin_left", 16)
	draw_filter_margin.add_theme_constant_override("margin_top", 16)
	draw_filter_margin.add_theme_constant_override("margin_right", 16)
	draw_filter_margin.add_theme_constant_override("margin_bottom", 16)
	_draw_filter_panel.add_child(draw_filter_margin)
	_draw_filter_box = VBoxContainer.new()
	_draw_filter_box.add_theme_constant_override("separation", 8)
	draw_filter_margin.add_child(_draw_filter_box)

	_target_selection_panel = Panel.new()
	_target_selection_panel.name = "TargetSelectionPanel"
	_target_selection_panel.set_anchors_preset(Control.PRESET_CENTER)
	_target_selection_panel.custom_minimum_size = Vector2(460, 220)
	_target_selection_panel.z_index = 50
	_target_selection_panel.visible = false
	add_child(_target_selection_panel)
	var target_selection_margin := MarginContainer.new()
	target_selection_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	target_selection_margin.add_theme_constant_override("margin_left", 16)
	target_selection_margin.add_theme_constant_override("margin_top", 16)
	target_selection_margin.add_theme_constant_override("margin_right", 16)
	target_selection_margin.add_theme_constant_override("margin_bottom", 16)
	_target_selection_panel.add_child(target_selection_margin)
	_target_selection_box = VBoxContainer.new()
	_target_selection_box.add_theme_constant_override("separation", 8)
	target_selection_margin.add_child(_target_selection_box)

	_card_peek_panel = CardPeekPanelScript.new()
	_card_peek_panel.name = "CardPeekPanel"
	_card_peek_panel.z_index = 50
	_card_peek_panel.visible = false
	add_child(_card_peek_panel)

	_pile_inspect_panel = PileInspectPanelScript.new()
	_pile_inspect_panel.name = "PileInspectPanel"
	_pile_inspect_panel.z_index = 50
	_pile_inspect_panel.visible = false
	add_child(_pile_inspect_panel)


func _render_arena_top_bar() -> void:
	if _arena_top_bar == null:
		return
	_clear_container_children(_contract_chip_rail)
	var contract_rules := _active_contract_rule_ids()
	if not contract_rules.is_empty():
		_contract_chip_rail.add_child(_make_arena_top_chip("ContractSummaryChip", _contract_summary_chip_text(contract_rules)))
	_set_arena_top_chip_text(_turn_counter_chip, "回合 %d" % _current_turn_number())
	_clear_container_children(_learned_rule_chip_rail)
	var learned_rules := _learned_rule_ids()
	if not learned_rules.is_empty():
		_learned_rule_chip_rail.add_child(_make_arena_top_chip("LearnedRuleSummaryChip", _learned_rule_summary_chip_text(learned_rules)))


	if _arena_rule_detail_label != null:
		_arena_rule_detail_label.text = _arena_top_rule_detail_text()
		_arena_rule_detail_label.visible = _arena_rule_detail_label.text.strip_edges() != ""


func _make_arena_top_chip(chip_name: String, text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.tooltip_text = text
	chip.custom_minimum_size = Vector2(maxf(104.0, float(text.length() * 12 + 24)), 26)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _battle_chip_style(Color(0.12, 0.14, 0.18), Color(0.42, 0.48, 0.58), 1, 6))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	chip.add_child(margin)
	var label := Label.new()
	label.name = "ChipLabel"
	label.text = text
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return chip


func _set_arena_top_chip_text(chip: PanelContainer, text: String) -> void:
	if chip == null:
		return
	var label := chip.find_child("ChipLabel", true, false)
	if label is Label:
		(label as Label).text = text


func _arena_top_rule_label_text(rule: String) -> String:
	return _rule_label_text(rule)


func _contract_summary_chip_text(rules: Array[String]) -> String:
	var unresolved_count := 0
	var satisfied_count := 0
	var failed_count := 0
	if _battle != null:
		for rule in rules:
			match str(_battle.rule_satisfaction.get(rule, "unresolved")):
				"satisfied":
					satisfied_count += 1
				"failed", "broken":
					failed_count += 1
				_:
					unresolved_count += 1
	else:
		unresolved_count = rules.size()
	var state_parts: Array[String] = []
	if satisfied_count > 0:
		state_parts.append("\u5df2\u6ee1\u8db3%d" % satisfied_count)
	if failed_count > 0:
		state_parts.append("\u672a\u6ee1\u8db3%d" % failed_count)
	if unresolved_count > 0:
		state_parts.append("\u672a\u5224\u5b9a%d" % unresolved_count)
	if state_parts.is_empty():
		state_parts.append("\u672a\u5224\u5b9a0")
	return "\u626e\u6f14\u5b88\u5219\uff1a%d\u6761 \u00b7 %s" % [rules.size(), _join_strings(state_parts, " / ")]


func _learned_rule_summary_chip_text(rules: Array[String]) -> String:
	return "\u9886\u609f\u89c4\u5219\uff1a%d\u6761" % rules.size()


func _arena_top_rule_detail_text() -> String:
	var contract_parts: Array[String] = []
	if _battle != null:
		for rule in _active_contract_rule_ids():
			var state_text := _rule_state_text(str(_battle.rule_satisfaction.get(rule, "unresolved")))
			contract_parts.append(_arena_top_contract_detail_part(rule, state_text))
	var learned_parts: Array[String] = []
	for rule in _learned_rule_ids():
		learned_parts.append(_arena_top_learned_rule_detail_part(rule))
	if contract_parts.is_empty() and learned_parts.is_empty():
		return ""
	var lines: Array[String] = ["\u89c4\u5219\u89e3\u8bfb\uff1a"]
	if not contract_parts.is_empty():
		lines.append("\u626e\u6f14\u5b88\u5219\uff1a%s" % _join_strings(contract_parts, " / "))
	if not learned_parts.is_empty():
		lines.append("\u9886\u609f\u89c4\u5219\uff1a%s" % _join_strings(learned_parts, " / "))
	return "\n".join(lines)


func _arena_top_contract_detail_part(rule: String, state_text: String) -> String:
	return "%s\uff08\u505a\u6cd5\uff1a%s\uff1b\u72b6\u6001\uff1a%s\uff09" % [
		_rule_detail_label_text(rule),
		_rule_detail_instruction_text(rule),
		state_text,
	]


func _arena_top_learned_rule_detail_part(rule: String) -> String:
	return "%s\uff08\u505a\u6cd5\uff1a%s\uff09" % [
		_rule_detail_label_text(rule),
		_rule_detail_instruction_text(rule),
	]


func _rule_detail_label_text(rule: String) -> String:
	if _rule_has_authored_instruction(rule):
		return _arena_top_rule_label_text(rule)
	return "\u672a\u547d\u540d\u5b88\u5219"


func _rule_detail_instruction_text(rule: String) -> String:
	if _rule_has_authored_instruction(rule):
		return _rule_instruction_text(rule)
	return "\u89e3\u8bfb\u5f85\u8865"


func _rule_has_authored_instruction(rule: String) -> bool:
	match rule:
		"rule_use_debuff", \
		"rule_no_consecutive_attack", \
		"rule_no_consec_attack", \
		"rule_draw_fate", \
		"rule_no_light_element", \
		"rule_shadow_takes_hit", \
		"rule_first_question", \
		"shadow_silence", \
		"holy_silence", \
		"halfmoon_silence", \
		"quiet_confession", \
		"promotion_misdirection", \
		"confession_without_name", \
		"innocent_confession", \
		"confession_plain_story", \
		"shift_terms", \
		"mirror_step", \
		"noble_grace", \
		"smuggler_cover", \
		"tavern_loss_before_boast", \
		"debt_phrase", \
		"church_smalltalk", \
		"halfmoon_reflection":
			return true
		_:
			return false


func _clear_container_children(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _active_contract_rule_ids() -> Array[String]:
	var rules: Array[String] = []
	if _battle != null:
		for rule in _battle.contracted_rules:
			rules.append(str(rule))
	if rules.is_empty() and _game_state != null and _game_state.has_method("get"):
		var active = _game_state.get("active_contract")
		if active is Array:
			for rule in active:
				rules.append(str(rule))
	return rules


func _learned_rule_ids() -> Array[String]:
	var rules: Array[String] = []
	var active_rules := {}
	for active_rule in _active_contract_rule_ids():
		active_rules[str(active_rule)] = true
	if _game_state != null and _game_state.has_method("get"):
		var learned = _game_state.get("learned_rules")
		if learned is Array:
			for rule in learned:
				var rule_id := str(rule)
				if active_rules.has(rule_id):
					continue
				rules.append(rule_id)
	return rules


func _current_turn_number() -> int:
	if _battle == null:
		return 1
	return int(_battle.turn_count) + 1


func _make_pile_chip(chip_name: String, count_label: Label) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.custom_minimum_size = Vector2(82, 30)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.add_theme_stylebox_override("panel", _battle_chip_style(Color(0.09, 0.11, 0.14), Color(0.35, 0.42, 0.50), 1, 6))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 3)
	chip.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)
	var icon := Panel.new()
	icon.name = "PileIcon"
	icon.custom_minimum_size = Vector2(10, 14)
	icon.add_theme_stylebox_override("panel", _battle_chip_style(Color(0.18, 0.21, 0.26), Color(0.48, 0.55, 0.64), 1, 3))
	row.add_child(icon)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 12)
	row.add_child(count_label)
	return chip


func _make_energy_orb(label: Label) -> PanelContainer:
	var orb := PanelContainer.new()
	orb.name = "EnergyOrb"
	orb.custom_minimum_size = Vector2(62, 34)
	orb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	orb.add_theme_stylebox_override("panel", _battle_chip_style(Color(0.16, 0.12, 0.05), Color(0.74, 0.55, 0.19), 2, 18))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	orb.add_child(center)
	center.add_child(label)
	return orb


func _apply_tower_background(battle_context: Dictionary) -> void:
	_clear_tower_background()
	var district_id := str(battle_context.get("tower_district", "")).strip_edges()
	if district_id == "":
		return
	var phase := str(battle_context.get("time_of_day", "")).strip_edges()
	var path := ArtManifestScript.tower_texture_path(district_id, phase)
	if path == "":
		return
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		return
	if _arena_layer_stack == null:
		_arena_layer_stack = find_child("BattleArenaLayerStack", true, false) as Control
	if _arena_layer_stack == null:
		return
	_arena_background = TextureRect.new()
	_arena_background.name = "BattleArenaBackground"
	_arena_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_background.z_index = -10
	_arena_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arena_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_arena_background.modulate = Color(1.0, 1.0, 1.0, 0.55)
	_arena_background.texture = texture
	_arena_layer_stack.add_child(_arena_background)
	_arena_layer_stack.move_child(_arena_background, 0)


func _clear_tower_background() -> void:
	if not is_instance_valid(_arena_background):
		_arena_background = null
		return
	var parent := _arena_background.get_parent()
	if parent != null:
		parent.remove_child(_arena_background)
	_arena_background.queue_free()
	_arena_background = null


func _battle_chip_style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _build_ui_legacy() -> void:
	var margin := MarginContainer.new()
	margin.name = "BattleSafeMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "RetiredStageRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# 顶栏：玩家血/能量/抽弃牌堆
	var top := HBoxContainer.new()
	top.name = "RetiredPlayerRail"
	top.add_theme_constant_override("separation", 24)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(top)
	_player_hp_label = Label.new()
	_player_hp_label.add_theme_font_size_override("font_size", 18)
	top.add_child(_player_hp_label)
	_player_status_label = Label.new()
	_player_status_label.name = "PlayerStatusLabel"
	_player_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_status_label.clip_text = true
	_player_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(_player_status_label)
	_energy_label = Label.new()
	_energy_label.add_theme_font_size_override("font_size", ENERGY_FONT_SIZE)
	top.add_child(_energy_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var pile_hud := HBoxContainer.new()
	pile_hud.name = "RetiredPileRail"
	pile_hud.add_theme_constant_override("separation", 12)
	top.add_child(pile_hud)
	_draw_pile_label = Label.new()
	pile_hud.add_child(_draw_pile_label)
	_discard_pile_label = Label.new()
	pile_hud.add_child(_discard_pile_label)

	var info_scroll := ScrollContainer.new()
	info_scroll.name = "RetiredInfoScroll"
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.custom_minimum_size = Vector2(0, 72)
	info_scroll.clip_contents = true
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(info_scroll)
	var info_root := VBoxContainer.new()
	info_root.name = "RetiredInfoRoot"
	info_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_root.add_theme_constant_override("separation", 6)
	info_scroll.add_child(info_root)

	_rules_label = Label.new()
	_rules_label.name = "RulesLabel"
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_root.add_child(_rules_label)
	_contract_label = Label.new()
	_contract_label.name = "ContractLabel"
	_contract_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_root.add_child(_contract_label)

	# 敌人区
	var enemy_container := PanelContainer.new()
	enemy_container.name = "EnemyStage"
	enemy_container.custom_minimum_size = Vector2(0, 128)
	enemy_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_container.size_flags_vertical = Control.SIZE_FILL
	root.add_child(enemy_container)
	root.move_child(enemy_container, 1)
	_enemy_box = HBoxContainer.new()
	_enemy_box.add_theme_constant_override("separation", 16)
	_enemy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_container.add_child(_enemy_box)

	var charge_container := PanelContainer.new()
	charge_container.name = "ChargeZone"
	charge_container.custom_minimum_size = Vector2(0, 64)
	info_root.add_child(charge_container)
	_charge_zone_box = VBoxContainer.new()
	_charge_zone_box.name = "ChargeZoneBox"
	_charge_zone_box.add_theme_constant_override("separation", 4)
	charge_container.add_child(_charge_zone_box)

	_field_state_label = Label.new()
	_field_state_label.name = "FieldStateLabel"
	_field_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_root.add_child(_field_state_label)

	var status_detail_container := PanelContainer.new()
	status_detail_container.name = "RetiredStatusDetail"
	status_detail_container.custom_minimum_size = Vector2(0, 84)
	info_root.add_child(status_detail_container)
	var status_detail_margin := MarginContainer.new()
	status_detail_margin.add_theme_constant_override("margin_left", 8)
	status_detail_margin.add_theme_constant_override("margin_top", 6)
	status_detail_margin.add_theme_constant_override("margin_right", 8)
	status_detail_margin.add_theme_constant_override("margin_bottom", 6)
	status_detail_container.add_child(status_detail_margin)
	var status_detail_scroll := ScrollContainer.new()
	status_detail_scroll.name = "StatusDetailScroll"
	status_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	status_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	status_detail_margin.add_child(status_detail_scroll)
	_status_detail_label = Label.new()
	_status_detail_label.name = "StatusDetailLabel"
	_status_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_detail_scroll.add_child(_status_detail_label)

	# 信息
	var message_container := PanelContainer.new()
	message_container.name = "RetiredMessageRail"
	message_container.custom_minimum_size = Vector2(0, 72)
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(message_container)
	var message_margin := MarginContainer.new()
	message_margin.add_theme_constant_override("margin_left", 8)
	message_margin.add_theme_constant_override("margin_top", 6)
	message_margin.add_theme_constant_override("margin_right", 8)
	message_margin.add_theme_constant_override("margin_bottom", 6)
	message_container.add_child(message_margin)
	var message_body := VBoxContainer.new()
	message_body.name = "RetiredMessageBody"
	message_body.add_theme_constant_override("separation", 4)
	message_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_margin.add_child(message_body)
	_feedback_layer = BattleFeedbackLayerScript.new()
	_feedback_layer.name = "BattleFeedbackLayer"
	message_body.add_child(_feedback_layer)
	var message_scroll := ScrollContainer.new()
	message_scroll.name = "RetiredMessageScroll"
	message_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_scroll.clip_contents = true
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	message_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	message_body.add_child(message_scroll)
	_message_label = Label.new()
	_message_label.name = "RetiredMessageLabel"
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_scroll.add_child(_message_label)
	var battle_log_container := PanelContainer.new()
	battle_log_container.name = "RetiredLogDrawer"
	battle_log_container.custom_minimum_size = Vector2(0, 92)
	battle_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(battle_log_container)
	var battle_log_margin := MarginContainer.new()
	battle_log_margin.add_theme_constant_override("margin_left", 8)
	battle_log_margin.add_theme_constant_override("margin_top", 6)
	battle_log_margin.add_theme_constant_override("margin_right", 8)
	battle_log_margin.add_theme_constant_override("margin_bottom", 6)
	battle_log_container.add_child(battle_log_margin)
	var battle_log_alias := VBoxContainer.new()
	battle_log_alias.name = "BattleLog"
	battle_log_alias.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_alias.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_margin.add_child(battle_log_alias)
	var battle_log_scroll := ScrollContainer.new()
	battle_log_scroll.name = "BattleLogScroll"
	battle_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_log_scroll.clip_contents = true
	battle_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	battle_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	battle_log_alias.add_child(battle_log_scroll)
	_battle_log_label = Label.new()
	_battle_log_label.name = "BattleLogLabel"
	_battle_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_log_scroll.add_child(_battle_log_label)

	# 手牌
	var hand_container := PanelContainer.new()
	hand_container.name = "RetiredHandRail"
	hand_container.custom_minimum_size = Vector2(0, HAND_CARD_HEIGHT + 18)
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(hand_container)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.name = "HandScroll"
	hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_container.add_child(hand_scroll)
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", HAND_CARD_SEPARATION)
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hand_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.add_child(_hand_box)

	# 底栏按钮
	var bottom := HBoxContainer.new()
	bottom.name = "BattleControlRail"
	bottom.add_theme_constant_override("separation", 12)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	_end_turn_button = Button.new()
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.text = "结束回合"
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	bottom.add_child(_end_turn_button)
	var flee := Button.new()
	flee.name = "FleeButton"
	flee.text = "投降"
	flee.pressed.connect(_on_flee_pressed)
	bottom.add_child(flee)

	# 奖励面板
	_reward_panel = BattleResultOverlayScript.new()
	_reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	var reward_overlay_size := Vector2(760, 420)
	_reward_panel.custom_minimum_size = reward_overlay_size
	_reward_panel.offset_left = -reward_overlay_size.x * 0.5
	_reward_panel.offset_top = -reward_overlay_size.y * 0.5
	_reward_panel.offset_right = reward_overlay_size.x * 0.5
	_reward_panel.offset_bottom = reward_overlay_size.y * 0.5
	_reward_panel.z_index = 100
	_reward_panel.visible = false
	if _reward_panel.has_signal("reward_chosen"):
		_reward_panel.connect("reward_chosen", Callable(self, "_on_reward_picked"))
	add_child(_reward_panel)
	if _reward_panel.has_method("reward_box"):
		_reward_box = _reward_panel.call("reward_box") as VBoxContainer
	else:
		_reward_box = VBoxContainer.new()

	_draw_filter_panel = Panel.new()
	_draw_filter_panel.name = "DrawFilterPanel"
	_draw_filter_panel.set_anchors_preset(Control.PRESET_CENTER)
	_draw_filter_panel.custom_minimum_size = Vector2(480, 300)
	_draw_filter_panel.z_index = 50
	_draw_filter_panel.visible = false
	add_child(_draw_filter_panel)
	var draw_filter_margin := MarginContainer.new()
	draw_filter_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_filter_margin.add_theme_constant_override("margin_left", 16)
	draw_filter_margin.add_theme_constant_override("margin_top", 16)
	draw_filter_margin.add_theme_constant_override("margin_right", 16)
	draw_filter_margin.add_theme_constant_override("margin_bottom", 16)
	_draw_filter_panel.add_child(draw_filter_margin)
	_draw_filter_box = VBoxContainer.new()
	_draw_filter_box.add_theme_constant_override("separation", 8)
	draw_filter_margin.add_child(_draw_filter_box)

	_target_selection_panel = Panel.new()
	_target_selection_panel.name = "TargetSelectionPanel"
	_target_selection_panel.set_anchors_preset(Control.PRESET_CENTER)
	_target_selection_panel.custom_minimum_size = Vector2(460, 220)
	_target_selection_panel.z_index = 50
	_target_selection_panel.visible = false
	add_child(_target_selection_panel)
	var target_selection_margin := MarginContainer.new()
	target_selection_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	target_selection_margin.add_theme_constant_override("margin_left", 16)
	target_selection_margin.add_theme_constant_override("margin_top", 16)
	target_selection_margin.add_theme_constant_override("margin_right", 16)
	target_selection_margin.add_theme_constant_override("margin_bottom", 16)
	_target_selection_panel.add_child(target_selection_margin)
	_target_selection_box = VBoxContainer.new()
	_target_selection_box.add_theme_constant_override("separation", 8)
	target_selection_margin.add_child(_target_selection_box)


func _setup_pollution_hud() -> void:
	if _pollution_hud == null or not is_instance_valid(_pollution_hud):
		_pollution_hud = HudScript.new()
		_pollution_hud.name = "PollutionHud"
		_pollution_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pollution_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_pollution_hud)
	if _pollution_hud.has_method("bind_game_state"):
		_pollution_hud.call("bind_game_state", _game_state)


func _set_narrative_text(text: String) -> void:
	var clean := text.strip_edges()
	if _narrative_label != null:
		_narrative_label.text = clean
	if _narrative_rail != null:
		_narrative_rail.visible = clean != ""
		_narrative_rail.custom_minimum_size = Vector2(0, 44 if clean != "" else 0)


# === 渲染 ===
func _render() -> void:
	if _battle == null:
		return
	_apply_responsive_layout_budget()
	if _player_standee != null and _player_standee.has_method("bind_player"):
		_player_standee.call("bind_player", _player, _active_contract_text(), _learned_rules_text())
	_player_hp_label.text = "玩家 生命 %d/%d  防御 %d" % [int(_player.hp), int(_player.max_hp), _actor_defense_value(_player)]
	_player_status_label.text = _actor_status_line(_player)
	_player_status_label.tooltip_text = _player_status_label.text
	_energy_label.text = "⚡ %d/%d" % [int(_battle.energy), int(_battle.energy_max)]
	_draw_pile_label.text = "抽 %d" % _battle.draw_pile.size()
	_discard_pile_label.text = "弃 %d" % _battle.discard_pile.size()
	_render_arena_top_bar()
	_rules_label.text = _learned_rules_text()
	_rules_label.visible = _rules_label.text != ""
	_contract_label.text = _active_contract_text()
	_contract_label.visible = _contract_label.text != ""
	_render_enemies()
	_render_player_chips()
	_render_status_detail()
	_render_hand()
	_render_target_selection_panel()
	_message_label.text = _last_action_message
	_render_battle_log()
	if _target_selection_active():
		_message_label.text = "已选：%s（点击敌人选择多个目标）" % _card_name(_target_selection_card)
	elif _selected_card != null:
		_message_label.text = "已选：%s（点击敌人指定目标）" % _card_name(_selected_card)
	_render_feedback_layer()


func _render_enemies() -> void:
	for child in _enemy_box.get_children():
		child.queue_free()
	for enemy in _battle.enemies:
		if enemy == null:
			continue
		var intent: Dictionary = _battle.current_enemy_intents.get(enemy.id, {})
		var target_limits := _select_targets_limits(_target_selection_card)
		var max_targets := int(target_limits.get("max", 1))
		var blocked_by_max: bool = _target_selection_active() and not (enemy in _target_selection_targets) and _target_selection_targets.size() >= max_targets
		var target_text := "选为目标"
		if _target_selection_active() and enemy in _target_selection_targets:
			target_text = "已选择"
		var target_disabled: bool = enemy.is_dead() or ((_selected_card == null and not _target_selection_active()) or blocked_by_max)
		var slot = EnemyStandeeScript.new()
		slot.custom_minimum_size = Vector2(_enemy_standee_width(), _standee_min_height_for_viewport())
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.bind_enemy(
			enemy,
			"意图：被遮蔽" if enemy.has_status("obscure_intent") else _intent_text(intent, enemy),
			_actor_status_line(enemy),
			_actor_defense_value(enemy),
			target_disabled,
			target_text,
			intent,
			enemy.has_status("obscure_intent"),
			_target_selection_active() and enemy in _target_selection_targets
		)
		var target_button = slot.target_button() if slot.has_method("target_button") else null
		if target_button is Button:
			(target_button as Button).visible = _enemy_target_buttons_visible()
		slot.set_meta("valid_target", not target_disabled)
		slot.set_meta("selected_target", _target_selection_active() and enemy in _target_selection_targets)
		slot.set_meta("blocked_by_target_limit", blocked_by_max)
		slot.target_pressed.connect(_on_target_pressed)
		_enemy_box.add_child(slot)


func _enemy_standee_width() -> float:
	var scene_width := get_global_rect().size.x
	if scene_width <= 0.0:
		scene_width = get_viewport_rect().size.x
	if scene_width >= 1700.0:
		return ENEMY_STANDEE_WIDE_WIDTH
	if scene_width >= 1320.0:
		return ENEMY_STANDEE_MEDIUM_WIDTH
	return ENEMY_STANDEE_BASE_WIDTH


func _enemy_target_buttons_visible() -> bool:
	if _target_selection_active():
		return true
	return _selected_card != null and _last_input_was_keyboard


func _render_charge_zone() -> void:
	_render_player_chips()


func _render_field_state() -> void:
	_render_player_chips()


func _render_player_chips() -> void:
	if _player_standee == null or not _player_standee.has_method("set_player_chip_texts"):
		return
	var chips: Array[String] = []
	if _battle == null:
		_player_standee.call("set_player_chip_texts", chips)
		return
	for entry in _battle.charged_zone:
		if not entry is Dictionary:
			continue
		var card = entry.get("source_card", null)
		var name_text := "unknown"
		if card != null and card.has_method("get_display_name"):
			name_text = card.get_display_name()
		elif card != null:
			name_text = str(card)
		var remaining := int(entry.get("remaining", 0))
		chips.append("充能 %s 剩余 %d" % [name_text, remaining])
	var parts: Array[String] = []
	var flame_markers := 0
	if _battle.has_method("get_field_marker_count"):
		flame_markers = int(_battle.get_field_marker_count("flame_markers"))
	else:
		flame_markers = int(_battle.field_state.get("flame_markers", 0))
	if flame_markers > 0:
		parts.append("火焰标记 %d" % flame_markers)
	var field_state: Dictionary = _battle.field_state if _battle.field_state is Dictionary else {}
	var adjacent_burn := int(field_state.get("adjacent_burn", 0))
	if adjacent_burn > 0:
		parts.append("相邻燃烧 %d" % adjacent_burn)
	for part in parts:
		chips.append(part)
	_player_standee.call("set_player_chip_texts", chips)


func _render_status_detail() -> void:
	var detail_text := _status_detail_text()
	if _status_detail_label == null:
		if _player_standee != null and _player_standee.has_method("set_status_detail_text"):
			_player_standee.call("set_status_detail_text", detail_text)
		return
	_status_detail_label.text = detail_text
	if _player_standee != null and _player_standee.has_method("set_status_detail_text"):
		_player_standee.call("set_status_detail_text", detail_text)


func _render_hand() -> void:
	for child in _hand_box.get_children():
		_hand_box.remove_child(child)
		child.queue_free()
	var hand_card_width := _hand_card_width_for_count(_battle.hand.size())
	var tallest_card_height := float(HAND_CARD_HEIGHT)
	for hand_card in _battle.hand:
		var effective_cost := int(hand_card.energy_cost)
		if _battle.has_method("effective_card_cost"):
			effective_cost = int(_battle.effective_card_cost(hand_card))
		var unusable_reason := _card_unusable_reason_text(hand_card)
		if unusable_reason == "":
			unusable_reason = _hand_interaction_lock_reason_text()
		var card_texture := _card_texture_for(hand_card)
		var card_view = BattleCardViewScript.new()
		var card_size := Vector2(float(hand_card_width), float(HAND_CARD_HEIGHT))
		if card_view.has_method("preferred_card_size_for_art"):
			card_size = card_view.call("preferred_card_size_for_art", card_texture, float(hand_card_width))
		card_size = _fit_card_size_to_battle_layout(card_size, card_texture, card_view)
		tallest_card_height = maxf(tallest_card_height, card_size.y)
		var compat_button := Button.new()
		compat_button.custom_minimum_size = card_size
		compat_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		compat_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		compat_button.clip_text = true
		compat_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		compat_button.text = _card_button_text_compact(hand_card, effective_cost)
		compat_button.tooltip_text = _card_button_text_with_cost(hand_card, effective_cost)
		if unusable_reason != "":
			compat_button.text += "\n不可用：" + unusable_reason
			compat_button.tooltip_text += "\n\n不可用：" + unusable_reason
		compat_button.disabled = unusable_reason != ""
		compat_button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
		compat_button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0))
		card_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_view.custom_minimum_size = card_size
		card_view.bind_card(
			hand_card,
			effective_cost,
			_card_effect_summary(hand_card),
			unusable_reason,
			_card_button_text_with_cost(hand_card, effective_cost),
			hand_card == _selected_card,
			card_texture
		)
		card_view.peek_requested.connect(_open_card_peek)
		card_view.pressed.connect(_on_card_pressed_from_input)
		compat_button.pressed.connect(card_view.activate)
		compat_button.add_child(card_view)
		_hand_box.add_child(compat_button)
	_update_hand_rail_height(tallest_card_height)


func _update_hand_rail_height(card_height: float) -> void:
	var rail := _hand_rail
	if rail == null or not is_instance_valid(rail):
		var found := find_child("HandRail", true, false)
		if found is PanelContainer:
			rail = found as PanelContainer
	if rail == null or not is_instance_valid(rail):
		return
	var capped_card_height := minf(card_height, _max_hand_card_height_for_viewport())
	rail.custom_minimum_size = Vector2(0, maxf(HAND_CARD_ABSOLUTE_MIN_HEIGHT + HAND_RAIL_VERTICAL_PADDING, capped_card_height + HAND_RAIL_VERTICAL_PADDING))


func _fit_card_size_to_battle_layout(card_size: Vector2, card_texture: Texture2D, card_view: Control) -> Vector2:
	var max_card_height := _max_hand_card_height_for_viewport()
	if card_size.y <= max_card_height:
		return card_size
	if card_view == null or not card_view.has_method("preferred_card_size_for_art"):
		var scale_factor := max_card_height / maxf(1.0, card_size.y)
		return Vector2(floor(card_size.x * scale_factor + 0.5), floor(max_card_height + 0.5))
	var min_width := _min_hand_card_width_for_viewport()
	var scaled_width := maxf(min_width, floor(card_size.x * (max_card_height / maxf(1.0, card_size.y))))
	var fitted_size: Vector2 = card_view.call("preferred_card_size_for_art", card_texture, scaled_width)
	if fitted_size.y > max_card_height + 1.0 and fitted_size.y > 0.0:
		scaled_width = maxf(min_width, floor(fitted_size.x * (max_card_height / fitted_size.y)))
		fitted_size = card_view.call("preferred_card_size_for_art", card_texture, scaled_width)
	return fitted_size


func _max_hand_card_height_for_viewport() -> float:
	var viewport_size := _layout_viewport_size()
	var visible_rows := 4.0
	if _narrative_rail != null and is_instance_valid(_narrative_rail) and _narrative_rail.visible:
		visible_rows += 1.0
	var narrative_height := 44.0 if visible_rows > 4.0 else 0.0
	var fixed_height := (
		BATTLE_SAFE_MARGIN_VERTICAL
		+ narrative_height
		+ ARENA_TOP_BAR_MIN_HEIGHT
		+ _arena_min_height_for_viewport()
		+ BOTTOM_RAIL_MIN_HEIGHT
		+ BATTLE_ROOT_SEPARATION * maxf(0.0, visible_rows - 1.0)
		+ COMPACT_LAYOUT_SAFETY_GAP
	)
	var available_card_height := viewport_size.y - fixed_height - HAND_RAIL_VERTICAL_PADDING
	var ratio_cap := viewport_size.y * HAND_CARD_VIEWPORT_HEIGHT_RATIO
	var height_cap := minf(ratio_cap, minf(HAND_CARD_MAX_VIEWPORT_HEIGHT, available_card_height))
	if height_cap >= float(HAND_CARD_HEIGHT):
		return height_cap
	return maxf(HAND_CARD_ABSOLUTE_MIN_HEIGHT, height_cap)


func _apply_responsive_layout_budget() -> void:
	var arena_height := _arena_min_height_for_viewport()
	var standee_height := _standee_min_height_for_viewport()
	if _arena_layer_stack == null or not is_instance_valid(_arena_layer_stack):
		var arena_found := find_child("BattleArenaLayerStack", true, false)
		if arena_found is Control:
			_arena_layer_stack = arena_found as Control
	if _arena_layer_stack != null and is_instance_valid(_arena_layer_stack):
		_arena_layer_stack.custom_minimum_size = Vector2(0, arena_height)
	if _player_stage == null or not is_instance_valid(_player_stage):
		var player_stage_found := find_child("PlayerStage", true, false)
		if player_stage_found is Control:
			_player_stage = player_stage_found as Control
	if _player_stage != null and is_instance_valid(_player_stage):
		_player_stage.custom_minimum_size = Vector2(200, standee_height)
	if _bottom_chip_rail == null or not is_instance_valid(_bottom_chip_rail):
		var bottom_found := find_child("BottomChipRail", true, false)
		if bottom_found is HBoxContainer:
			_bottom_chip_rail = bottom_found as HBoxContainer
	if _bottom_chip_rail != null and is_instance_valid(_bottom_chip_rail):
		_bottom_chip_rail.custom_minimum_size = Vector2(0, BOTTOM_RAIL_MIN_HEIGHT)


func _arena_min_height_for_viewport() -> float:
	var available := _available_height_for_arena_with_minimum_hand()
	if available >= ARENA_MIN_HEIGHT:
		return ARENA_MIN_HEIGHT
	return maxf(ARENA_COMPACT_MIN_HEIGHT, available)


func _standee_min_height_for_viewport() -> float:
	var arena_height := _arena_min_height_for_viewport()
	if arena_height >= ARENA_MIN_HEIGHT:
		return STANDEE_MIN_HEIGHT
	return clampf(arena_height - 36.0, STANDEE_COMPACT_MIN_HEIGHT, STANDEE_MIN_HEIGHT)


func _available_height_for_arena_with_minimum_hand() -> float:
	var viewport_size := _layout_viewport_size()
	var visible_rows := 4.0
	if _narrative_rail != null and is_instance_valid(_narrative_rail) and _narrative_rail.visible:
		visible_rows += 1.0
	var narrative_height := 44.0 if visible_rows > 4.0 else 0.0
	var minimum_hand_rail_height := HAND_CARD_ABSOLUTE_MIN_HEIGHT + HAND_RAIL_VERTICAL_PADDING
	var fixed_without_arena := (
		BATTLE_SAFE_MARGIN_VERTICAL
		+ narrative_height
		+ ARENA_TOP_BAR_MIN_HEIGHT
		+ minimum_hand_rail_height
		+ BOTTOM_RAIL_MIN_HEIGHT
		+ BATTLE_ROOT_SEPARATION * maxf(0.0, visible_rows - 1.0)
		+ COMPACT_LAYOUT_SAFETY_GAP
	)
	return viewport_size.y - fixed_without_arena


func _min_hand_card_width_for_viewport() -> float:
	var viewport_size := _layout_viewport_size()
	if viewport_size.y < 680.0:
		return HAND_CARD_COMPACT_MIN_WIDTH
	return float(HAND_CARD_MIN_WIDTH)


func _layout_viewport_size() -> Vector2:
	var viewport_size := Vector2(1280, 720)
	if is_inside_tree():
		var parent_control := get_parent() as Control
		if parent_control != null and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
			viewport_size = parent_control.size
		elif size.x > 0.0 and size.y > 0.0:
			viewport_size = size
		else:
			viewport_size = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(1280, 720)
	return viewport_size


# === 交互 ===
func _hand_card_width_for_count(card_count: int) -> int:
	var count := maxi(1, int(card_count))
	var viewport_width := float(_layout_viewport_size().x)
	viewport_width = minf(viewport_width, 1280.0)
	var available_width: float = maxf(360.0, viewport_width - 128.0)
	var total_gap: float = float(maxi(0, count - 1) * HAND_CARD_SEPARATION)
	var width: float = floor((available_width - total_gap) / float(count))
	return clampi(int(width), HAND_CARD_MIN_WIDTH, HAND_CARD_WIDTH)


func _hand_interaction_lock_reason_text() -> String:
	if _draw_filter_choice_active():
		return "Finish draw-filter choice first"
	if _target_selection_active():
		return "Finish target selection first"
	return ""


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var accepted := _accepts_background_aoe_drop(data)
	set_meta("background_aoe_drop_active", accepted)
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	set_meta("background_aoe_drop_active", false)
	if not _accepts_background_aoe_drop(data):
		return
	var card = (data as Dictionary).get("card", null)
	_play_card_from_drop(card, null)


func _can_drop_surface_data(global_position: Vector2, data: Variant) -> bool:
	_update_drop_hover_flags(global_position)
	var accepted := _accepts_drop_surface_data(global_position, data)
	set_meta("background_aoe_drop_active", accepted and _drop_surface_payload_is_aoe(data))
	_apply_drop_surface_highlight(global_position, data, accepted)
	return accepted


func _drop_surface_data(global_position: Vector2, data: Variant) -> void:
	set_meta("background_aoe_drop_active", false)
	if not _accepts_drop_surface_data(global_position, data):
		_clear_drop_highlights()
		return
	var card = (data as Dictionary).get("card", null)
	if _card_has_select_targets_effect(card):
		var select_enemy = _enemy_at_global_position(global_position)
		if select_enemy != null:
			_drop_select_targets_card_on_enemy(card, select_enemy)
		_clear_drop_highlights()
		return
	var target := _background_drop_card_target(card)
	if target == "self":
		if _player_standee_at_global_position(global_position):
			_play_card_from_drop(card, _player)
		_clear_drop_highlights()
		return
	if _is_background_aoe_target(target):
		_play_card_from_drop(card, null)
		_clear_drop_highlights()
		return
	var enemy = _enemy_at_global_position(global_position)
	if enemy != null:
		_play_card_from_drop(card, enemy)
	_clear_drop_highlights()


func _accepts_drop_surface_data(global_position: Vector2, data: Variant) -> bool:
	if not _is_battle_card_payload(data):
		return false
	if not _drop_surface_point_inside_arena(global_position):
		return false
	if _battle == null or _draw_filter_choice_active() or _target_selection_active():
		return false
	var card = (data as Dictionary).get("card", null)
	if _card_has_select_targets_effect(card):
		return _enemy_at_global_position(global_position) != null
	var target := _background_drop_card_target(card)
	if target == "self":
		return _player_standee_at_global_position(global_position)
	if _is_background_aoe_target(target):
		return true
	return _enemy_at_global_position(global_position) != null


func _drop_surface_payload_is_aoe(data: Variant) -> bool:
	if not _is_battle_card_payload(data):
		return false
	var card = (data as Dictionary).get("card", null)
	if _card_has_select_targets_effect(card):
		return false
	return _is_background_aoe_target(_background_drop_card_target(card))


func _drop_surface_point_inside_arena(global_position: Vector2) -> bool:
	var arena_root := find_child("BattleArenaRoot", true, false)
	if not arena_root is Control:
		return false
	return (arena_root as Control).get_global_rect().has_point(global_position)


func _enemy_at_global_position(global_position: Vector2):
	var standee := _enemy_standee_at_global_position(global_position)
	if standee != null:
		return standee.get("enemy")
	return null


func _enemy_standee_at_global_position(global_position: Vector2) -> Control:
	if _enemy_box == null:
		return null
	for child in _enemy_box.get_children():
		if not child is Control:
			continue
		var control := child as Control
		if not control.is_visible_in_tree():
			continue
		if not control.get_global_rect().has_point(global_position):
			continue
		return control
	return null


func _player_standee_at_global_position(global_position: Vector2) -> bool:
	if not _player_standee is Control:
		return false
	var control := _player_standee as Control
	return control.is_visible_in_tree() and control.get_global_rect().has_point(global_position)


func _accepts_background_aoe_drop(data: Variant) -> bool:
	if not _is_battle_card_payload(data):
		return false
	if _battle == null or _draw_filter_choice_active() or _target_selection_active():
		return false
	var card = (data as Dictionary).get("card", null)
	if _card_has_select_targets_effect(card):
		return false
	return _is_background_aoe_target(_background_drop_card_target(card))


func _apply_drop_surface_highlight(global_position: Vector2, data: Variant, accepted: bool) -> void:
	if not _is_battle_card_payload(data):
		_clear_drop_highlights()
		return
	var card = (data as Dictionary).get("card", null)
	if _card_has_select_targets_effect(card):
		_probe_drop_highlight(_enemy_standee_at_global_position(global_position), global_position, data)
		return
	var target := _background_drop_card_target(card)
	if target == "self":
		_probe_drop_highlight(_player_standee as Control, global_position, data)
		return
	if _is_background_aoe_target(target):
		return
	_probe_drop_highlight(_enemy_standee_at_global_position(global_position), global_position, data)


func _probe_drop_highlight(control: Control, global_position: Vector2, data: Variant) -> void:
	if control == null or not is_instance_valid(control):
		return
	if not control.has_method("_can_drop_data"):
		return
	var local_position := global_position - control.get_global_rect().position
	control.call("_can_drop_data", local_position, data)


func _is_battle_card_payload(data: Variant) -> bool:
	return data is Dictionary and str((data as Dictionary).get("kind", "")) == "battle_card" and (data as Dictionary).get("card", null) != null


func _background_drop_card_target(card) -> String:
	if card == null or not card.has_method("get"):
		return ""
	return str(card.get("target"))


func _is_background_aoe_target(target: String) -> bool:
	return target in ["all_enemies", "aoe", "field", "deck", "random_enemies"]


func _card_travel_animation_data(card, target) -> Dictionary:
	if card == null:
		return {}
	var source_rect := _global_rect_for_card(card)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		source_rect = Rect2(get_global_rect().position + Vector2(32, get_global_rect().size.y - HAND_CARD_HEIGHT - 32), Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT))
	var target_rect := _global_rect_for_play_target(target)
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		var scene_rect := get_global_rect()
		target_rect = Rect2(scene_rect.get_center(), Vector2.ZERO)
	var start_point := source_rect.get_center()
	var end_point := target_rect.get_center()
	return {
		"card": card,
		"card_name": _card_name(card),
		"source_rect": source_rect,
		"target_rect": target_rect,
		"start": start_point,
		"end": end_point,
		"duration": 0.22,
	}


func _global_rect_for_card(card) -> Rect2:
	if _hand_box == null:
		return Rect2()
	for child in _hand_box.get_children():
		var card_view := _find_battle_card_view_in_node(child)
		if card_view == null:
			continue
		if card_view.get("card") == card:
			return card_view.get_global_rect()
	return Rect2()


func _find_battle_card_view_in_node(root_node: Node) -> Control:
	if root_node == null:
		return null
	if root_node is Control and root_node.get_script() == BattleCardViewScript:
		return root_node as Control
	for child in root_node.get_children():
		var result := _find_battle_card_view_in_node(child)
		if result != null:
			return result
	return null


func _global_rect_for_play_target(target) -> Rect2:
	if target == _player and _player_standee is Control:
		return (_player_standee as Control).get_global_rect()
	if target != null and _enemy_box != null:
		for child in _enemy_box.get_children():
			if child is Control and child.get("enemy") == target:
				return (child as Control).get_global_rect()
	var arena_root := find_child("BattleArenaRoot", true, false)
	if arena_root is Control:
		return (arena_root as Control).get_global_rect()
	return get_global_rect()


func _spawn_card_travel_animation(animation_data: Dictionary) -> void:
	if animation_data.is_empty():
		return
	var card = animation_data.get("card", null)
	if card == null:
		return
	var source_rect: Rect2 = animation_data.get("source_rect", Rect2())
	var start_point: Vector2 = animation_data.get("start", source_rect.get_center())
	var end_point: Vector2 = animation_data.get("end", get_global_rect().get_center())
	var duration := maxf(0.12, float(animation_data.get("duration", 0.22)))
	var card_size := source_rect.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = Vector2(HAND_CARD_WIDTH, HAND_CARD_HEIGHT)
	var animation := BattleCardViewScript.new()
	animation.name = "BattleCardTravelAnimation"
	animation.custom_minimum_size = card_size
	animation.size = card_size
	animation.position = _scene_local_point(start_point - card_size * 0.5)
	animation.pivot_offset = card_size * 0.5
	animation.scale = Vector2(1.08, 1.08)
	animation.z_index = 520
	animation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation.set_meta("card_travel_animation", true)
	animation.set_meta("travel_start", start_point)
	animation.set_meta("travel_end", end_point)
	animation.set_meta("travel_duration", duration)
	animation.bind_card(card, int(card.energy_cost), _card_effect_summary(card), "", _card_button_text_with_cost(card, int(card.energy_cost)), false, _card_texture_for(card))
	add_child(animation)
	set_meta("last_card_travel_animation", animation_data)
	if is_inside_tree():
		var target_position := _scene_local_point(end_point - card_size * 0.5)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(animation, "position", target_position, duration)
		tween.tween_property(animation, "scale", Vector2(0.82, 0.82), duration)
		tween.tween_property(animation, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(Callable(animation, "queue_free"))


func _scene_local_point(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _play_card_from_drop(card, target) -> void:
	if _draw_filter_choice_active():
		return
	if _target_selection_active():
		return
	_pending_card_travel_animation = _card_travel_animation_data(card, target)
	_selected_card = card
	_play_selected(target)


func _drop_select_targets_card_on_enemy(card, enemy) -> void:
	if _draw_filter_choice_active():
		return
	_start_target_selection(card)
	_toggle_target_selection(enemy)


func _on_card_pressed(card) -> void:
	if _draw_filter_choice_active():
		return
	if _target_selection_active():
		return
	_selected_card = card
	if _card_has_select_targets_effect(card):
		_start_target_selection(card)
		return
	# 自指卡（heal/self target）直接出
	if card.target == "self":
		_play_selected(_player)
		return
	if str(card.target) in ["all_enemies", "aoe", "field", "deck", "random_enemies"]:
		_play_selected(null)
		return
	_render()


func _on_card_pressed_from_input(card) -> void:
	if not _last_input_was_keyboard:
		return
	_on_card_pressed(card)


func _open_card_peek(card) -> void:
	if card == null or _card_peek_panel == null:
		return
	var effective_cost := int(card.energy_cost)
	if _battle != null and _battle.has_method("effective_card_cost"):
		effective_cost = int(_battle.effective_card_cost(card))
	if _card_peek_panel.has_method("show_for"):
		_card_peek_panel.call("show_for", card, effective_cost, _card_effect_summary(card), _card_texture_for(card))


func _on_draw_pile_chip_gui_input(event: InputEvent) -> void:
	if not _pile_chip_left_pressed(event):
		return
	_show_pile_inspect_panel("Draw Pile", _draw_pile_cards_for_inspect())
	accept_event()


func _on_discard_pile_chip_gui_input(event: InputEvent) -> void:
	if not _pile_chip_left_pressed(event):
		return
	_show_pile_inspect_panel("Discard Pile", _discard_pile_cards_for_inspect())
	accept_event()


func _pile_chip_left_pressed(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed


func _show_pile_inspect_panel(title: String, cards: Array) -> void:
	if _pile_inspect_panel == null or not _pile_inspect_panel.has_method("show_for"):
		return
	if _card_peek_panel != null:
		_card_peek_panel.hide()
	_pile_inspect_panel.call("show_for", title, cards)


func _draw_pile_cards_for_inspect() -> Array:
	if _battle == null:
		return []
	var cards: Array = _battle.draw_pile.duplicate()
	cards.sort_custom(Callable(self, "_card_display_name_less"))
	return cards


func _discard_pile_cards_for_inspect() -> Array:
	if _battle == null:
		return []
	return _battle.discard_pile.duplicate()


func _card_display_name_less(a, b) -> bool:
	return _card_name(a).to_lower() < _card_name(b).to_lower()


func _on_target_pressed(enemy) -> void:
	if _draw_filter_choice_active():
		return
	if _target_selection_active():
		_toggle_target_selection(enemy)
		return
	if _selected_card == null:
		return
	_play_selected(enemy)


func _play_selected(target) -> void:
	if _card_has_draw_filter_effect(_selected_card):
		_pending_card_travel_animation = {}
		_start_draw_filter_choice(_selected_card, target)
		return
	var played_card = _selected_card
	var travel_animation := _pending_card_travel_animation.duplicate(true)
	_pending_card_travel_animation = {}
	var before_snapshot := _battle_actor_snapshots()
	var before_result_count := int(_battle.last_effect_results.size())
	var played: bool = _battle.play_card(played_card, target)
	_selected_card = null
	if not played:
		_set_last_action_message("出牌失败（能量不足或卡受限）")
	else:
		Sfx.play("card_play")
		_spawn_card_travel_animation(travel_animation)
		_set_last_action_message(_last_card_result_summary(played_card, before_snapshot, before_result_count))
	_render()
	_check_resolution()


func _start_draw_filter_choice(card, target) -> void:
	if _battle == null or not _battle.has_method("prepare_draw_filter_choice"):
		return
	var result: Dictionary = _battle.prepare_draw_filter_choice(card, target)
	_selected_card = null
	if not bool(result.get("ok", false)):
		_hide_draw_filter_panel()
		_render()
		_set_last_action_message("抽牌筛选无法开始")
		return
	if bool(result.get("resolved", false)):
		_hide_draw_filter_panel()
		_render()
		_check_resolution()
		return
	_show_draw_filter_panel(result.get("candidates", []))
	_render()


func _show_draw_filter_panel(candidates: Array) -> void:
	if _draw_filter_panel == null or _draw_filter_box == null:
		return
	for child in _draw_filter_box.get_children():
		_draw_filter_box.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "抽牌筛选：选择 1 张牌"
	title.add_theme_font_size_override("font_size", 18)
	_draw_filter_box.add_child(title)
	for i in range(candidates.size()):
		var card = candidates[i]
		var btn := Button.new()
		btn.text = _card_button_text(card)
		btn.pressed.connect(_on_draw_filter_choice_pressed.bind(i))
		_draw_filter_box.add_child(btn)
	_draw_filter_panel.visible = true


func _hide_draw_filter_panel() -> void:
	if _draw_filter_panel == null:
		return
	_draw_filter_panel.visible = false


func _draw_filter_choice_active() -> bool:
	return _draw_filter_panel != null and _draw_filter_panel.visible


func _card_has_draw_filter_effect(card) -> bool:
	if card == null or not card.has_method("get"):
		return false
	var effects = card.get("status_effects")
	if not effects is Array:
		return false
	for effect in effects:
		if effect is Dictionary and str(effect.get("id", "")) == "draw_filter":
			return true
	return false


func _card_has_select_targets_effect(card) -> bool:
	return int(_select_targets_limits(card).get("max", 0)) > 0


func _select_targets_limits(card) -> Dictionary:
	if card == null or not card.has_method("get"):
		return {"min": 0, "max": 0}
	var effects = card.get("status_effects")
	if not effects is Array:
		return {"min": 0, "max": 0}
	for effect in effects:
		if effect is Dictionary and str(effect.get("id", "")) == "select_targets":
			var min_targets := maxi(1, int(effect.get("min", 1)))
			var max_targets := maxi(min_targets, int(effect.get("max", min_targets)))
			return {"min": min_targets, "max": max_targets}
	return {"min": 0, "max": 0}


func _start_target_selection(card) -> void:
	_target_selection_card = card
	_selected_card = card
	_target_selection_targets.clear()
	_render()


func _target_selection_active() -> bool:
	return _target_selection_card != null


func _toggle_target_selection(enemy) -> void:
	if enemy == null or enemy.is_dead():
		return
	if enemy in _target_selection_targets:
		_target_selection_targets.erase(enemy)
	else:
		var limits := _select_targets_limits(_target_selection_card)
		var max_targets := int(limits.get("max", 1))
		if _target_selection_targets.size() >= max_targets:
			return
		_target_selection_targets.append(enemy)
	_render()


func _render_target_selection_panel() -> void:
	if _target_selection_panel == null or _target_selection_box == null:
		return
	for child in _target_selection_box.get_children():
		_target_selection_box.remove_child(child)
		child.queue_free()
	if not _target_selection_active():
		_target_selection_panel.visible = false
		return
	var limits := _select_targets_limits(_target_selection_card)
	var min_targets := int(limits.get("min", 1))
	var max_targets := int(limits.get("max", min_targets))
	var selected_count := _target_selection_targets.size()
	var title := Label.new()
	title.text = "选择目标：%d/%d（至少 %d）" % [selected_count, max_targets, min_targets]
	title.add_theme_font_size_override("font_size", 18)
	_target_selection_box.add_child(title)
	var selected_names: Array[String] = []
	for target in _target_selection_targets:
		selected_names.append(_actor_name_text(target))
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if selected_names.is_empty():
		hint.text = "点击敌人按钮选择目标"
	else:
		hint.text = "已选：%s" % _join_strings(selected_names, "、")
	_target_selection_box.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_target_selection_box.add_child(row)
	var confirm := Button.new()
	confirm.name = "TargetSelectionConfirmButton"
	confirm.text = "确认"
	confirm.disabled = selected_count < min_targets or selected_count > max_targets
	confirm.pressed.connect(_on_target_selection_confirm_pressed)
	row.add_child(confirm)
	var cancel := Button.new()
	cancel.name = "TargetSelectionCancelButton"
	cancel.text = "取消"
	cancel.pressed.connect(_on_target_selection_cancel_pressed)
	row.add_child(cancel)
	_target_selection_panel.visible = true


func _on_target_selection_confirm_pressed() -> void:
	if not _target_selection_active():
		return
	var limits := _select_targets_limits(_target_selection_card)
	var min_targets := int(limits.get("min", 1))
	if _target_selection_targets.size() < min_targets:
		_set_last_action_message("先选择目标", false)
		return
	var card = _target_selection_card
	var targets := _target_selection_targets.duplicate()
	_target_selection_card = null
	_target_selection_targets.clear()
	if _target_selection_panel != null:
		_target_selection_panel.visible = false
	_selected_card = card
	_play_selected(targets)


func _on_target_selection_cancel_pressed() -> void:
	_target_selection_card = null
	_target_selection_targets.clear()
	_selected_card = null
	if _target_selection_panel != null:
		_target_selection_panel.visible = false
	_render()


func _on_draw_filter_choice_pressed(index: int) -> void:
	if _battle == null or not _battle.has_method("resolve_draw_filter_choice"):
		return
	var source_card = _battle.pending_draw_filter.get("source_card", null) if _battle.pending_draw_filter is Dictionary else null
	var before_snapshot := _battle_actor_snapshots()
	var before_result_count := int(_battle.last_effect_results.size())
	var result: Dictionary = _battle.resolve_draw_filter_choice(index)
	_hide_draw_filter_panel()
	_render()
	if not bool(result.get("ok", false)):
		_set_last_action_message("抽牌筛选选择失败")
		return
	if source_card != null:
		_set_last_action_message(_last_card_result_summary(source_card, before_snapshot, before_result_count))
	else:
		_set_last_action_message(_effect_result_text(result))
	_check_resolution()


func _on_end_turn_pressed() -> void:
	if _target_selection_active():
		_set_last_action_message("先完成目标选择")
		return
	if _draw_filter_choice_active():
		_set_last_action_message("先完成抽牌筛选选择")
		return
	Sfx.play("turn_end")
	var before_snapshot := _battle_actor_snapshots()
	var before_result_count := int(_battle.last_effect_results.size())
	if _battle.phase == _battle.Phase.PLAYER_TURN:
		_battle.end_player_turn()
	var enemy_result: Dictionary = _battle.run_enemy_turn()
	_set_last_action_message(_enemy_turn_result_summary(before_snapshot, before_result_count, enemy_result))
	_render()
	_check_resolution()


func _on_flee_pressed() -> void:
	_finish_battle(false)


func _check_resolution() -> void:
	if _battle == null:
		return
	if _battle.phase == _battle.Phase.RESOLVE:
		var won: bool = _player != null and not _player.is_dead()
		_finish_battle(won)


func _finish_battle(won: bool) -> void:
	if won:
		Sfx.play("victory")
		_show_reward_picker()
	else:
		Sfx.play("defeat")
		_result = _battle.resolve_battle(false, [], 0, _game_state, _victory_drops)
		var contract: Dictionary = _result.get("contract", {})
		var summary := "战斗失败"
		var contract_text := _contract_summary_text(contract)
		if contract_text != "":
			summary += "｜契约：%s" % contract_text
		_show_result_overlay(_result, summary)
		_set_last_action_message(_append_result_narration(summary, _result))
		battle_finished.emit(_result)


func _show_reward_picker() -> void:
	var rewards: Array = _generate_reward_candidates()
	if _reward_panel != null and _reward_panel.has_method("show_rewards"):
		_reward_panel.call("show_rewards", rewards, "胜利！选择 1 张临时卡", "")


func _on_reward_picked(rewards: Array, index: int) -> void:
	_result = _battle.resolve_battle(true, rewards, index, _game_state, _victory_drops)
	var contract: Dictionary = _result.get("contract", {})
	var summary: String = "胜利"
	var contract_text := _contract_summary_text(contract)
	if contract_text != "":
		summary += "｜契约：%s" % contract_text
	if _result.get("brand_drop", null) != null:
		summary += "｜BOSS 烙印：%s" % str(_result.get("brand_drop").display_name)
	_show_result_overlay(_result, summary)
	_set_last_action_message(_append_result_narration(summary, _result))
	battle_finished.emit(_result)


func _show_result_overlay(result: Dictionary, summary: String) -> void:
	if _reward_panel == null or not is_instance_valid(_reward_panel):
		return
	if _reward_panel.has_method("show_result"):
		_reward_panel.call("show_result", result, summary)
	_set_narrative_text(str(result.get("ai_gm_text", "")))


func _set_last_action_message(message: String, record_log: bool = true) -> void:
	_last_action_message = message
	if record_log:
		_append_battle_log(message)
	if _message_label != null:
		_message_label.text = _last_action_message
	_render_battle_log()
	_render_feedback_layer()


func _on_battle_log_entry(message: String) -> void:
	_set_last_action_message(message)


func _on_battle_log_drawer_toggle_pressed() -> void:
	_set_battle_log_drawer_expanded(not _battle_log_drawer_expanded)


func _set_battle_log_drawer_expanded(expanded: bool) -> void:
	_battle_log_drawer_expanded = expanded
	if _battle_log_drawer == null or not is_instance_valid(_battle_log_drawer):
		return
	var width := 280.0 if expanded else 24.0
	_battle_log_drawer.custom_minimum_size = Vector2(width, 0)
	if _battle_log_drawer_content != null and is_instance_valid(_battle_log_drawer_content):
		_battle_log_drawer_content.visible = expanded
	if _battle_log_drawer_toggle != null and is_instance_valid(_battle_log_drawer_toggle):
		_battle_log_drawer_toggle.text = "<" if expanded else ">"


func _append_battle_log(message: String) -> void:
	var text := message.strip_edges()
	if text == "":
		return
	_battle_log_entries.append(text)
	while _battle_log_entries.size() > 8:
		_battle_log_entries.pop_front()


func _render_battle_log() -> void:
	if _battle_log_label == null:
		return
	if _battle_log_entries.is_empty():
		_battle_log_label.text = "战斗日志：无"
		return
	var lines: Array[String] = ["战斗日志"]
	for entry in _battle_log_entries:
		lines.append("- %s" % entry)
	_battle_log_label.text = "\n".join(lines)


# === 工具 ===
func _render_feedback_layer() -> void:
	if _feedback_layer == null or not is_instance_valid(_feedback_layer):
		return
	if not _feedback_layer.has_method("bind_state"):
		return
	var selected_text := ""
	if _target_selection_active():
		selected_text = _card_name(_target_selection_card)
	elif _selected_card != null:
		selected_text = _card_name(_selected_card)
	var effect_results: Array = []
	if _battle != null:
		effect_results = _battle.last_effect_results
	var recent_text := _last_action_message
	if _message_label != null:
		recent_text = _message_label.text
	_feedback_layer.call("bind_state", selected_text, recent_text, _battle_log_entries, effect_results)


func _battle_actor_snapshots() -> Dictionary:
	var snapshots: Dictionary = {}
	_store_actor_snapshot(snapshots, _player)
	if _battle != null:
		for enemy in _battle.enemies:
			_store_actor_snapshot(snapshots, enemy)
	return snapshots


func _store_actor_snapshot(snapshots: Dictionary, actor) -> void:
	if actor == null:
		return
	snapshots[int(actor.get_instance_id())] = {
		"name": _actor_name_text(actor),
		"hp": int(actor.hp) if actor.has_method("get") else 0,
		"def": _actor_defense_value(actor),
		"statuses": _actor_statuses_copy(actor),
	}


func _last_card_result_summary(card, before_snapshot: Dictionary, before_result_count: int) -> String:
	var parts: Array[String] = ["出牌：%s" % _card_name(card)]
	for text in _actor_delta_texts(before_snapshot):
		if text != "":
			parts.append(text)
	for text in _effect_result_texts_since(before_result_count):
		if text != "" and not text in parts:
			parts.append(text)
	return _join_strings(parts, "｜")


func _enemy_turn_result_summary(before_snapshot: Dictionary, before_result_count: int, _enemy_result: Dictionary = {}) -> String:
	var parts: Array[String] = ["敌方行动"]
	for text in _actor_delta_texts(before_snapshot):
		if text != "":
			parts.append(text)
	for text in _effect_result_texts_since(before_result_count):
		if text != "" and not text in parts:
			parts.append(text)
	if parts.size() == 1:
		parts.append("未造成明显变化")
	return _join_strings(parts, "｜")


func _actor_delta_texts(before_snapshot: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	var actors: Array = []
	if _player != null:
		actors.append(_player)
	if _battle != null:
		actors.append_array(_battle.enemies)
	for actor in actors:
		if actor == null:
			continue
		var key := int(actor.get_instance_id())
		if not before_snapshot.has(key):
			continue
		var before: Dictionary = before_snapshot.get(key, {})
		var name := str(before.get("name", _actor_name_text(actor)))
		var before_hp := int(before.get("hp", 0))
		var after_hp := int(actor.hp) if actor.has_method("get") else before_hp
		if after_hp < before_hp:
			if actor == _player:
				Sfx.play("damage_player")
			else:
				Sfx.play("damage_enemy")
			parts.append("%s 受到 %d 伤害" % [name, before_hp - after_hp])
		elif after_hp > before_hp:
			parts.append("%s 治疗 %d" % [name, after_hp - before_hp])
		var before_def := int(before.get("def", 0))
		var after_def := _actor_defense_value(actor)
		if before_def != after_def:
			parts.append("%s 防御 %d→%d" % [name, before_def, after_def])
		var added_statuses := _added_statuses_text(before.get("statuses", {}), _actor_statuses_copy(actor))
		if added_statuses != "":
			parts.append("%s 获得状态 %s" % [name, added_statuses])
	return parts


func _effect_result_texts_since(start_index: int) -> Array[String]:
	var parts: Array[String] = []
	if _battle == null:
		return parts
	var results: Array = _battle.last_effect_results
	for i in range(maxi(0, start_index), results.size()):
		var result = results[i]
		if not result is Dictionary:
			continue
		var text := _effect_result_text(result)
		if text != "":
			parts.append(text)
	return parts


func _effect_result_text(result: Dictionary) -> String:
	var reason := str(result.get("reason", ""))
	var id := str(result.get("id", ""))
	match reason:
		"defense_shredded":
			return "破防 %d" % int(result.get("magnitude", 0))
		"defense_broken":
			return "破防 %d" % int(result.get("magnitude", 0))
		"chance_missed":
			return "%s 未触发" % _safe_status_label_text(id)
		"status_applied":
			return "附加 %s" % _safe_status_label_text(id)
		"conditional_status_applied":
			var applied_status := str(result.get("applied_status", id))
			return "附加 %s" % _safe_status_label_text(applied_status)
		"damage_reduction_triggered":
			return "减伤 %d" % int(result.get("prevented_damage", 0))
		"counter_spell_triggered":
			return "反咒 %d" % int(result.get("damage", 0))
		"dodge_counter_triggered":
			return "闪避反击 %d" % int(result.get("damage", 0))
		"cleanse_applied":
			return "净化减益"
		"cleanse_incoming_debuff":
			return "净化抵挡减益"
		"immune_debuff":
			return "免疫减益"
		"marker_added":
			var added := int(result.get("added", result.get("count", 1)))
			return "%s +%d" % [_safe_status_label_text(id), added]
		"paper_doll_absorbed_fatal":
			return "纸人吸收致命伤"
		"charged":
			return "进入充能区"
		"charge_payload_resolved":
			return "充能效果结算"
		"field_marker_added":
			var added := int(result.get("added", result.get("count", 1)))
			if id == "create_or_move_flame_markers":
				return "火焰标记 +%d" % added
			return "场地标记 +%d" % added
		"field_marker_consumed":
			return "消耗场地标记"
		"discarded_top_deck":
			Sfx.play("card_discard")
			return "弃置牌库顶牌"
		"attack_bonus_applied":
			return "本次伤害 +%d" % int(result.get("damage_bonus", 0))
		"condition_not_met":
			if id == "execute_bonus_below_hp_pct":
				return "低血斩杀未触发"
			return "条件未满足"
		"missing_flame_marker":
			return "缺少火焰标记"
		"damage_modifier":
			return _damage_modifier_result_text(id, result)
		"adjacent_burn_set":
			return "相邻燃烧 %d" % int(result.get("magnitude", 0))
		"attack_play_damage_growth_registered":
			return "攻击成长 +%d" % int(result.get("magnitude", 0))
		"per_use_damage_growth_registered":
			return "使用成长 +%d" % int(result.get("magnitude", 0))
		"cost_modifier_registered":
			return "费用修正"
		"life_steal_registered":
			return "吸血"
		"target_selection_registered":
			return "目标选择 %d-%d" % [int(result.get("min", 1)), int(result.get("max", 1))]
		"multi_strike_registered":
			return "多段 %d×%d" % [int(result.get("hits", 1)), int(result.get("damage_each", 0))]
		"self_damage_applied":
			return "自伤 %d" % int(result.get("damage", 0))
		"linked_damage":
			return "连锁伤害 %d" % int(result.get("damage", 0))
		"teleported_to_flame":
			var consumed := int(result.get("consumed_markers", 0))
			if consumed > 0:
				return "火焰跳跃 %d / 消耗火焰标记 %d" % [int(result.get("damage", 0)), consumed]
			return "火焰跳跃 %d" % int(result.get("damage", 0))
		"next_card_cost_delta_applied":
			return "下一张愚者技能费用 %s" % _signed_number_text(int(result.get("magnitude", 0)))
		"next_attack_damage_delta_applied":
			return "下次攻击伤害 %s" % _signed_number_text(int(result.get("magnitude", 0)))
		"reroll_next_target_applied":
			return "重定下次目标"
		"reroll_next_target_consumed":
			return "重定下次目标"
		"counter_intent_avoided":
			return "规避反制意图"
		"intent_revealed_by_card":
			var count := int(result.get("target_count", 0))
			return "读心揭示 %d" % count if int(result.get("detail_level", 1)) >= 2 else "揭示意图 %d" % count
		"drew_cards":
			Sfx.play("card_draw")
			if id == "draw_if_no_cleanse":
				return "未净化，抽牌 +%d" % int(result.get("drawn", 0))
			return "抽牌 +%d" % int(result.get("drawn", 0))
		"draw_skipped_after_cleanse":
			return "已净化，不抽牌"
		"draw_filter_pending":
			return "抽牌筛选待选择"
		"draw_filter_applied":
			return "抽牌筛选完成"
		"delayed_card_effect_pending":
			return "延迟效果待结算"
		"empty_draw_pile":
			return "牌库为空"
		"temp_card_created":
			return _generated_card_result_text("生成临时卡", result)
		"brand_draw_applied":
			return "烙印触发：抽牌 +%d" % int(result.get("drawn", 0))
		"brand_def_buff_applied":
			return "烙印触发：防御 +%d" % int(result.get("magnitude", 0))
		"brand_damage_growth_applied":
			return "烙印触发：伤害成长"
		"brand_permanent_transform_applied":
			return "烙印触发：永久成长"
		"brand_mirror_card_created":
			return _generated_card_result_text("烙印触发：生成临时卡", result)
		"brand_mirror_hand_full":
			return "烙印未触发：手牌已满"
		"brand_mirror_no_candidate":
			return "烙印未触发：没有可生成卡"
		"brand_energy_refunded":
			return "烙印触发：返还费用"
		"brand_energy_refund_missed":
			return "烙印未触发：返还费用"
		"brand_face_mask_redirect_applied":
			return "烙印准备：改判敌方目标"
		"brand_face_mask_redirect_triggered":
			return "烙印触发：改判敌方目标"
		"brand_face_mask_redirect_missed":
			return "烙印未触发：改判敌方目标"
		"brand_face_mask_no_enemy_target":
			return "烙印未触发：无可改判目标"
		"brand_truename_applied":
			return "烙印触发：真名揭示"
		"brand_once_per_battle_already_used":
			return "烙印已触发过"
		"brand_delayed_card_effect_scheduled":
			return "烙印触发：延迟结算"
		"brand_delayed_card_effect_resolved":
			return "延迟效果结算"
		"brand_next_turn_replay_scheduled":
			return "烙印触发：下回合重放"
		"brand_next_turn_replay_resolved":
			return "烙印重放结算"
		"brand_discard_returned_to_hand":
			return "烙印触发：弃牌返回手牌"
		"brand_discard_return_missed":
			return "烙印未触发：弃牌返回手牌"
		"brand_discard_return_hand_full":
			return "烙印未触发：手牌已满"
		"brand_crit_applied":
			return "烙印触发：暴击"
		"brand_lifesteal_applied":
			return "烙印触发：吸血"
		"brand_chain_damage_applied":
			return "烙印触发：弹射伤害"
		"brand_chain_no_target":
			return "烙印未触发：没有弹射目标"
		"brand_fatal_substitute_triggered":
			return "烙印触发：替死"
		"brand_fatal_substitute_missed":
			return "烙印未触发：替死"
		"brand_enemy_energy_delta_applied":
			return "烙印触发：压制敌方行动"
		"brand_forbidden_skill_tags_applied":
			return "烙印触发：禁用敌方技能"
		"brand_boss_intent_cancelled":
			return "烙印触发：取消 Boss 意图"
		"enemy_skill_blocked_by_forbidden_tags":
			return "敌方技能被禁用"
		"enemy_intent_cancelled_by_brand":
			return "敌方意图被烙印取消"
		"enemy_skill_cancelled_by_energy_delta":
			return "敌方技能被压制"
		_:
			return ""


func _generated_card_result_text(prefix: String, result: Dictionary) -> String:
	var text := prefix
	var card_name := str(result.get("card_name", ""))
	if card_name != "":
		text += "：" + card_name
	var destination := _generated_card_destination_text(str(result.get("destination", "")))
	if destination != "":
		text += "（%s）" % destination
	return text


func _damage_modifier_result_text(id: String, result: Dictionary) -> String:
	var magnitude := int(result.get("magnitude", 0))
	match id:
		"pierce_block":
			return "穿透防御 %d" % magnitude if magnitude > 0 else "穿透防御"
		"ignore_guard":
			return "固定忽略防御 %d" % magnitude if magnitude > 0 else "固定忽略防御"
		"range_bonus":
			return "距离加伤 +%d" % magnitude if magnitude > 0 else "距离加伤"
		"crit_up":
			return "暴击提升 1.5x"
		"execute_bonus_below_hp_pct":
			var bonus := int(result.get("bonus_damage", result.get("magnitude", 0)))
			return "低血斩杀 +%d" % bonus if bonus > 0 else "低血斩杀"
		"pierce":
			return "无视防御"
		_:
			return "伤害修正生效"


func _generated_card_destination_text(destination: String) -> String:
	match destination:
		"draw_pile_top":
			return "抽牌堆顶"
		"draw_pile":
			return "抽牌堆"
		"hand":
			return "手牌"
		"discard_pile":
			return "弃牌堆"
		_:
			return ""


func _actor_name_text(actor) -> String:
	if actor == null:
		return "目标"
	var text := str(actor.get("display_name")) if actor.has_method("get") else ""
	if text.strip_edges() == "":
		return "玩家" if actor == _player else "目标"
	return text


func _actor_statuses_copy(actor) -> Dictionary:
	if actor == null or not actor.has_method("get"):
		return {}
	var raw_statuses: Variant = actor.get("statuses")
	if raw_statuses is Dictionary:
		return (raw_statuses as Dictionary).duplicate(true)
	return {}


func _added_statuses_text(before_statuses: Variant, after_statuses: Dictionary) -> String:
	if not before_statuses is Dictionary:
		before_statuses = {}
	var labels: Array[String] = []
	for status_id in after_statuses.keys():
		if (before_statuses as Dictionary).has(status_id):
			continue
		labels.append(_safe_status_label_text(str(status_id)))
	return _join_strings(labels, "、")


func _safe_status_label_text(status_id: String) -> String:
	var label := StatusTextScript.label(status_id)
	if label == status_id and (status_id.contains("_") or status_id == ""):
		return "特殊状态"
	return label


func _generate_reward_candidates() -> Array:
	# MVP：从抽牌堆 + 弃牌堆抽 3 张去重；如果不够则补占位
	var pool: Array = []
	pool.append_array(_battle.draw_pile)
	pool.append_array(_battle.discard_pile)
	pool.shuffle()
	var picked: Array = []
	for card in pool:
		if picked.size() >= 3:
			break
		picked.append(card)
	return picked


func _card_button_text(card) -> String:
	var name_text: String = card.get_display_name() if card.has_method("get_display_name") else str(card.template_id)
	var lines: Array[String] = [
		name_text,
		"费用：%d  伤害：%d  治疗：%d" % [int(card.energy_cost), int(card.damage), int(card.heal)],
	]
	var summary := _card_effect_summary(card)
	if summary != "":
		lines.append(summary)
	return "\n".join(lines)


func _card_button_text_with_cost(card, effective_cost: int) -> String:
	var name_text: String = card.get_display_name() if card.has_method("get_display_name") else str(card.template_id)
	var lines: Array[String] = [
		name_text,
		"费用：%d  伤害：%d  治疗：%d" % [effective_cost, int(card.damage), int(card.heal)],
	]
	var summary := _card_effect_summary(card)
	if summary != "":
		lines.append(summary)
	return "\n".join(lines)


func _card_button_text_compact(card, effective_cost: int) -> String:
	var name_text: String = card.get_display_name() if card.has_method("get_display_name") else str(card.template_id)
	var summary := _card_effect_summary(card).replace("\n", " ")
	if summary.length() > 34:
		summary = summary.substr(0, 34) + "..."
	var lines: Array[String] = [
		name_text,
		"费用 %d  伤害 %d  治疗 %d" % [effective_cost, int(card.damage), int(card.heal)],
	]
	if summary != "":
		lines.append(summary)
	return "\n".join(lines)


func _card_texture_for(card) -> Texture2D:
	if card == null:
		return null
	var linked_id := _card_linked_data_id(card)
	if linked_id == "":
		return null
	return ArtManifestScript.texture_for("card", linked_id)


func _card_linked_data_id(card) -> String:
	if card == null:
		return ""
	var template_id := str(card.template_id)
	if template_id != "":
		return template_id
	return str(card.id)


func _card_name(card) -> String:
	return card.get_display_name() if card.has_method("get_display_name") else str(card.template_id)


func _card_effect_summary(card) -> String:
	if card != null and card.has_method("effect_summary_text"):
		return str(card.call("effect_summary_text")).strip_edges()
	return ""


func _card_unusable_reason_text(card) -> String:
	if _battle == null or card == null:
		return ""
	var reason := ""
	if _battle.has_method("card_play_block_reason"):
		reason = str(_battle.card_play_block_reason(card))
	else:
		if not _battle.can_play_card(card):
			reason = "card_limited"
		elif int(card.energy_cost) > int(_battle.energy):
			reason = "energy_short"
	if reason == "":
		return ""
	return _card_block_reason_text(reason, card)


func _card_block_reason_text(reason: String, card) -> String:
	match reason:
		"sequence_locked":
			var current_sequence := int(_battle.battle_sequence) if _battle != null else 9
			var card_sequence := int(card.sequence) if card != null else current_sequence
			return "序列未达，需晋升至序列 %d（当前 %d）" % [card_sequence, current_sequence]
		"mechanic_locked":
			var mechanisms: Array = []
			if _battle != null and _battle.has_method("_card_mechanism_tags"):
				mechanisms = _battle.call("_card_mechanism_tags", card)
			var mechanism_text := _mechanism_text(str(mechanisms[0])) if not mechanisms.is_empty() else "当前机制"
			return "机制未解锁：%s" % mechanism_text
		"flame_marker_required":
			return "需要先制造火焰标记"
		"contract_disabled":
			return "本层契约破坏后失效"
		"energy_short":
			return "能量不足"
		"fear":
			return "恐惧中无法使用攻击牌"
		"not_player_turn":
			return "当前不是你的回合"
		"not_in_hand":
			return "不在当前手牌中"
		_:
			return "卡牌受限"


func _mechanism_text(mechanism: String) -> String:
	match mechanism:
		"intent_reveal": return "意图揭示"
		"draw_filter": return "抽牌筛选"
		"charge_skill": return "蓄力"
		"damage_reduction": return "减伤"
		"status": return "状态"
		"multi_strike": return "连击"
		"multi_target": return "多目标"
		"dodge_counter": return "闪避反击"
		"mind_read": return "读心"
		"paper_blade": return "纸刃"
		"block_break": return "破防"
		"position_shift": return "位移"
		"paper_doll": return "纸人"
		"field_marker": return "战场标记"
		"control": return "控制"
		"summon_marker": return "召唤标记"
		"pierce": return "穿透"
		"cleanse": return "净化"
		"deck_transform": return "牌库改造"
		"temporary_card": return "临时卡"
		"cost_mod": return "费用调整"
		_: return mechanism


func _learned_rules_text() -> String:
	var rules: Array = []
	if _game_state != null:
		rules = _game_state.learned_rules
	if rules.is_empty():
		return ""
	var parts: Array[String] = []
	for rule in rules:
		parts.append(_rule_label_text(str(rule)))
	return "今日守则：%s" % _join_strings(parts, " / ")


func _active_contract_text() -> String:
	if _battle == null or _battle.contracted_rules.is_empty():
		return ""
	var lines: Array[String] = ["本场契约："]
	for rule in _battle.contracted_rules:
		var rule_text := _rule_label_text(str(rule))
		var state_text := _rule_state_text(str(_battle.rule_satisfaction.get(rule, "unresolved")))
		lines.append("%s：%s" % [rule_text, state_text])
	return "\n".join(lines)


func _rule_instruction_text(rule: String) -> String:
	match rule:
		"rule_use_debuff":
			return "\u81f3\u5c11\u6253\u51fa\u4e00\u5f20\u4f1a\u7ed9\u654c\u4eba\u9644\u52a0\u8d1f\u9762\u72b6\u6001\u7684\u724c"
		"rule_no_consecutive_attack", "rule_no_consec_attack":
			return "\u907f\u514d\u8fde\u7eed\u4e24\u56de\u5408\u90fd\u7528\u4e3b\u52a8\u653b\u51fb\u724c\u4f5c\u4e3a\u4e3b\u8981\u884c\u52a8"
		"rule_draw_fate":
			return "\u62bd\u5230\u547d\u8fd0\u4e3b\u9898\u724c\u65f6\u8bb0\u4e3a\u4eca\u65e5\u5b88\u5219\u8fdb\u5ea6"
		"rule_no_light_element":
			return "\u672c\u573a\u4e0d\u4f7f\u7528\u5f3a\u5149\u5143\u7d20\u724c"
		"rule_shadow_takes_hit":
			return "\u8ba9\u5f71\u5b50\u6216\u4ee3\u8eab\u627f\u53d7\u4e00\u6b21\u654c\u4eba\u653b\u51fb"
		"rule_first_question":
			return "\u9996\u6b21\u5bf9\u8bdd\u7528\u95ee\u53e5\u5f00\u573a"
		"shadow_silence", "holy_silence", "halfmoon_silence", "quiet_confession":
			return "\u884c\u52a8\u65f6\u4fdd\u6301\u6c89\u9ed8\u6216\u4f4e\u58f0\uff0c\u907f\u514d\u8bf4\u51fa\u4f1a\u66b4\u9732\u8eab\u4efd\u7684\u8bdd"
		"promotion_misdirection":
			return "\u664b\u5347\u51c6\u5907\u65f6\u7528\u8bef\u5bfc\u56de\u7b54\u907f\u5f00\u8ffd\u67e5"
		"confession_without_name":
			return "\u5fcf\u6094\u65f6\u4e0d\u8bf4\u51fa\u771f\u540d"
		"innocent_confession":
			return "\u7528\u65e0\u8f9c\u53e3\u543b\u5b8c\u6210\u5fcf\u6094"
		"confession_plain_story":
			return "\u5fcf\u6094\u65f6\u53ea\u8bb2\u6734\u7d20\u4e8b\u5b9e"
		"shift_terms":
			return "\u6309\u5de5\u5934\u672f\u8bed\u56de\u5e94"
		"mirror_step":
			return "\u884c\u52a8\u524d\u5148\u505a\u955c\u4e2d\u6b65"
		"noble_grace":
			return "\u4fdd\u6301\u8d35\u65cf\u793c\u8282\uff0c\u4e0d\u8981\u7c97\u9c81\u884c\u4e8b"
		"smuggler_cover":
			return "\u7528\u8d70\u79c1\u8eab\u4efd\u63a9\u62a4\u771f\u5b9e\u884c\u52a8"
		"tavern_loss_before_boast":
			return "\u5439\u5618\u524d\u5148\u627f\u8ba4\u4e00\u6b21\u5931\u8d25"
		"debt_phrase":
			return "\u8bf4\u51fa\u503a\u52a1\u6697\u8bed\u6765\u7ef4\u6301\u4f2a\u88c5"
		"church_smalltalk":
			return "\u5148\u7528\u6559\u4f1a\u5bd2\u6684\u5f00\u573a"
		"halfmoon_reflection":
			return "\u7528\u534a\u6708\u5012\u5f71\u7684\u8bf4\u6cd5\u56de\u5e94"
		_:
			return "\u6309\u4e0a\u65b9\u89c4\u5219\u884c\u52a8\uff0c\u7ed3\u7b97\u65f6\u68c0\u67e5\u662f\u5426\u6ee1\u8db3"


func _rule_label_text(rule: String) -> String:
	match rule:
		"rule_use_debuff":
			return "使用1张状态削弱类卡"
		"rule_no_consecutive_attack", "rule_no_consec_attack":
			return "不要连续2回合主动攻击"
		"rule_draw_fate":
			return "至少抽到1张命运主题卡"
		"rule_no_light_element":
			return "不使用强光元素卡"
		"rule_shadow_takes_hit":
			return "让敌人攻击影子1次"
		"rule_first_question":
			return "初次对话以问句开场"
		"shadow_silence":
			return "影巷行动保持沉默"
		"promotion_misdirection":
			return "晋升准备时误导追查"
		"confession_without_name":
			return "忏悔时不说出真名"
		"innocent_confession":
			return "以无辜口吻完成忏悔"
		"confession_plain_story":
			return "忏悔时只讲朴素事实"
		"shift_terms":
			return "按工头术语回应"
		"mirror_step":
			return "行动前先做镜中步"
		"noble_grace":
			return "沙龙中保持贵族礼节"
		"smuggler_cover":
			return "以走私身份掩护行动"
		"holy_silence":
			return "圣所内保持沉默"
		"tavern_loss_before_boast":
			return "吹嘘前先承认失败"
		"debt_phrase":
			return "使用债务暗语"
		"quiet_confession":
			return "低声完成忏悔"
		"church_smalltalk":
			return "先用教会寒暄开场"
		"halfmoon_silence":
			return "半月行动保持沉默"
		"halfmoon_reflection":
			return "以半月倒影回应"
		_:
			return _humanize_rule_id(rule)


func _humanize_rule_id(rule: String) -> String:
	var clean := rule.strip_edges()
	if clean == "":
		return "未知守则"
	var without_prefix := clean
	if without_prefix.begins_with("rule_"):
		without_prefix = without_prefix.substr("rule_".length())
	var words := without_prefix.replace("_", " ").strip_edges()
	if words == "":
		return "未知守则"
	return "自定义守则：%s" % words


func _rule_state_text(state: String) -> String:
	match state:
		"satisfied":
			return "已满足"
		"violated":
			return "已违反"
		_:
			return "未判定"


func _actor_status_line(actor) -> String:
	return "状态：%s" % _actor_status_summary(actor)


func _actor_defense_value(actor) -> int:
	if actor == null or not actor.has_method("get"):
		return 0
	return maxi(0, int(actor.get("def")))


func _actor_status_summary(actor) -> String:
	if actor == null:
		return "无"
	var statuses = actor.get("statuses") if actor.has_method("get") else {}
	var parts: Array[String] = []
	if statuses is Dictionary:
		for status_id in statuses.keys():
			parts.append(_status_display_text(str(status_id), statuses.get(status_id, {})))
	var markers = actor.get("markers") if actor.has_method("get") else {}
	if markers is Dictionary:
		for marker_id in markers.keys():
			var count := int(markers.get(marker_id, 0))
			if count > 0:
				parts.append(_marker_display_text(str(marker_id), count))
	if parts.is_empty():
		return "无"
	return _join_strings(parts, " / ")


func _status_detail_text() -> String:
	var lines: Array[String] = ["状态明细"]
	if _player != null:
		lines.append_array(_status_detail_lines_for_actor("玩家", _player))
	if _battle != null:
		for enemy in _battle.enemies:
			lines.append_array(_status_detail_lines_for_actor("敌人", enemy))
	if lines.size() == 1:
		lines.append("无")
	return "\n".join(lines)


func _status_detail_lines_for_actor(group_label: String, actor) -> Array[String]:
	var lines: Array[String] = []
	if actor == null or not actor.has_method("get"):
		return lines
	var statuses = actor.get("statuses")
	var markers = actor.get("markers")
	var has_statuses: bool = statuses is Dictionary and not (statuses as Dictionary).is_empty()
	var has_markers: bool = markers is Dictionary and not (markers as Dictionary).is_empty()
	if not has_statuses and not has_markers:
		return lines
	lines.append("%s：%s" % [group_label, _actor_name_text(actor)])
	if statuses is Dictionary:
		for status_id in statuses.keys():
			lines.append("  - %s" % _status_display_text(str(status_id), statuses.get(status_id, {})))
	if markers is Dictionary:
		for marker_id in markers.keys():
			var count := int(markers.get(marker_id, 0))
			if count > 0:
				lines.append("  - %s" % _marker_display_text(str(marker_id), count))
	return lines


func _status_display_text(status_id: String, raw_payload: Variant) -> String:
	var payload: Dictionary = {}
	if raw_payload is Dictionary:
		payload = raw_payload
	return StatusTextScript.describe(status_id, payload)


func _marker_display_text(marker_id: String, count: int) -> String:
	return "%s %d层" % [_safe_status_label_text(marker_id), count]


func _status_label_text(status_id: String) -> String:
	match status_id:
		"weak":
			return "虚弱"
		"fear":
			return "恐惧"
		"vulnerable":
			return "易伤"
		"mark":
			return "标记"
		"def_buff":
			return "防御强化"
		"invulnerable":
			return "无敌"
		"atk_boost":
			return "攻击提升"
		"hp_boost":
			return "生命膨胀"
		"mp_cost_up":
			return "耗费上升"
		"resistance_lost":
			return "抗性剥离"
		"confusion":
			return "混乱"
		"nightmare":
			return "噩梦"
		"obscure_intent":
			return "遮蔽意图"
		"delay_intent":
			return "延迟意图"
		"burn", "burning":
			return "燃烧"
		"poison":
			return "中毒"
		"damage_reduction":
			return "减伤"
		"dodge_counter":
			return "闪避反击"
		"counter_spell":
			return "反咒"
		"cleanse_incoming_debuff":
			return "净化下次负面"
		"immune_debuff":
			return "免疫负面"
		"fatal_damage_convert":
			return "致命转移"
		"consume_on_trigger":
			return "触发后消耗"
		"absorb_fatal_or_curse":
			return "替死吸收"
		"paper_doll_marker":
			return "纸人"
		"paper_doll":
			return "纸人"
		"next_card_cost_delta":
			return "下一张愚者技能费用"
		"reroll_next_target":
			return "改判下次目标"
		"stun":
			return "眩晕"
		"silence":
			return "沉默"
		"bind":
			return "束缚"
		"root":
			return "定身"
		"paralyze":
			return "麻痹"
		"suffocate":
			return "窒息"
		"slow":
			return "迟缓"
		"blind":
			return "致盲"
		"life_steal":
			return "吸血"
		"stealth":
			return "潜行"
		"next_attack_damage_delta":
			return "下次攻击伤害变化"
		"chill":
			return "寒意"
		"displace":
			return "错位"
		"revealed":
			return "暴露"
		"intent_revealed":
			return "揭示意图"
		"mind_revealed":
			return "读心揭示"
		_:
			return status_id


func _contract_summary_text(contract: Dictionary) -> String:
	if contract.is_empty():
		return ""
	var outcome_map := {
		"full": "完整契约",
		"partial": "部分契约",
		"broken": "破契",
		"no_contract": "无契约",
	}
	var outcome := str(contract.get("outcome", ""))
	var label := str(outcome_map.get(outcome, outcome))
	if outcome == "failed":
		label = "契约失败"
	var delta := int(contract.get("pollution_delta", 0))
	var sign := "+" if delta >= 0 else ""
	var acting_base := int(contract.get("acting_check_base_difficulty", 0))
	var acting_modifier := int(contract.get("acting_check_weather_modifier", 0))
	var acting_text := ""
	if acting_base > 0:
		var acting_sign := "+" if acting_modifier >= 0 else ""
		acting_text = "，判定 %d (%s%d)" % [int(contract.get("acting_check_difficulty", acting_base)), acting_sign, acting_modifier]
	return "%s（污染 %s%d%s）" % [label, sign, delta, acting_text]


func _append_result_narration(summary: String, result: Dictionary) -> String:
	var lines: Array[String] = [summary]
	var ai_gm_text := str(result.get("ai_gm_text", "")).strip_edges()
	if ai_gm_text != "":
		lines.append(ai_gm_text)
	var contract: Dictionary = result.get("contract", {}) if result.get("contract", {}) is Dictionary else {}
	var violation_text := str(contract.get("violation_ai_gm_text", "")).strip_edges()
	if violation_text != "" and violation_text != ai_gm_text:
		lines.append(violation_text)
	return _join_strings(lines, "\n")


func _join_strings(values: Array[String], separator: String) -> String:
	var text := ""
	for value in values:
		if text != "":
			text += separator
		text += value
	return text


func _signed_number_text(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _intent_text(intent: Dictionary, enemy = null) -> String:
	if not bool(intent.get("revealed_by_card", false)):
		return _generic_intent_text(intent)
	var structured := _structured_intent_text(intent, enemy)
	if structured != "":
		return structured
	var explicit_text := str(intent.get("intent_text", "")).strip_edges()
	if explicit_text != "" and explicit_text != str(intent.get("skill", "")):
		return "意图：%s" % explicit_text
	return _generic_intent_text(intent)


func _generic_intent_text(intent: Dictionary) -> String:
	var action: String = str(intent.get("action", ""))
	match action:
		"use_skill":
			match str(intent.get("intent_type", "")):
				"attack", "attack_debuff":
					return "意图：准备攻击"
				"self_buff":
					return "意图：准备强化"
				"self_heal", "heal":
					return "意图：准备恢复"
				"status":
					return "意图：准备施加状态"
				_:
					return "意图：准备技能"
		"defend":
			return "意图：防御"
		_:
			return "意图：观察"


func _structured_intent_text(intent: Dictionary, enemy = null) -> String:
	if intent.is_empty():
		return ""
	if str(intent.get("action", "")) != "use_skill":
		return ""
	if not bool(intent.get("revealed_by_card", false)):
		return ""
	var parts: Array[String] = []
	var skill_name := str(intent.get("skill_name", "")).strip_edges()
	if skill_name == "":
		skill_name = "技能"
	parts.append(skill_name)
	var damage := _intent_effective_damage(enemy, intent)
	if damage > 0:
		parts.append("造成 %d 伤害" % damage)
	var heal := int(intent.get("heal", 0))
	if heal > 0:
		parts.append("恢复 %d 生命" % heal)
	var status_text := _intent_status_summary(intent.get("status_effects", []))
	if status_text != "":
		if str(intent.get("target", "")) == "self":
			parts.append("自身获得 %s" % status_text)
		else:
			parts.append("附加 %s" % status_text)
	var defense_bypass_text := _intent_defense_bypass_summary(intent)
	if defense_bypass_text != "":
		parts.append(defense_bypass_text)
	if bool(intent.get("revealed_by_card", false)):
		var detail := int(intent.get("detail_level", 1))
		parts.append("已揭示%s" % ("·读心" if detail >= 2 else ""))
	if parts.is_empty():
		return ""
	return "意图：%s" % _join_strings(parts, "，")


func _intent_effective_damage(enemy, intent: Dictionary) -> int:
	if _battle != null and _battle.has_method("preview_enemy_intent_damage"):
		return int(_battle.preview_enemy_intent_damage(enemy, intent))
	return int(intent.get("damage", 0))


func _intent_defense_bypass_summary(intent: Dictionary) -> String:
	if _variant_truthy(intent.get("ignore_defense", false)):
		return "无视防御"
	var pierce := maxi(0, int(intent.get("pierce_defense", 0)))
	if pierce > 0:
		return "穿透防御 %d" % pierce
	return ""


func _variant_truthy(value: Variant) -> bool:
	if value is bool:
		return bool(value)
	var text := str(value).strip_edges().to_lower()
	return text == "true" or text == "1" or text == "yes"


func _intent_status_summary(raw_effects: Variant) -> String:
	if not raw_effects is Array:
		return ""
	var parts: Array[String] = []
	for raw_effect in raw_effects:
		if not raw_effect is Dictionary:
			continue
		var effect: Dictionary = raw_effect
		var label := _status_label_text(str(effect.get("id", "")))
		if label == "":
			continue
		if effect.has("duration"):
			label += " %d" % int(effect.get("duration", 0))
		if effect.has("magnitude"):
			label += " 强度 %s" % str(effect.get("magnitude", 0))
		parts.append(label)
	return _join_strings(parts, " / ")


func _make_default_player():
	var actor = CombatActorScript.new()
	actor.display_name = "玩家"
	actor.hp = 50
	actor.max_hp = 50
	actor.atk = 10
	actor.def = 3
	return actor


func _input(event: InputEvent) -> void:
	_update_last_input_source(event)
	if _drop_highlight_drag_active and event is InputEventMouseMotion:
		_update_drop_hover_flags(get_global_mouse_position())
	if _pile_inspect_panel != null and _pile_inspect_panel.visible and event.is_action_pressed("ui_cancel"):
		_pile_inspect_panel.hide()
		accept_event()
		return
	if _card_peek_panel != null and _card_peek_panel.visible and event.is_action_pressed("ui_cancel"):
		_card_peek_panel.hide()
		accept_event()
		return
	if event.is_action_pressed("ui_cancel") and not _reward_panel.visible:
		_on_flee_pressed()
		accept_event()


func _update_last_input_source(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			_last_input_was_keyboard = false
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.is_action_pressed("ui_accept") or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
				_last_input_was_keyboard = true
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		if joy_event.pressed and joy_event.is_action_pressed("ui_accept"):
			_last_input_was_keyboard = true


func _update_drop_hover_flags(global_mouse_position: Vector2) -> void:
	for control in _drop_highlight_controls():
		var hovered := control.is_visible_in_tree() and control.get_global_rect().has_point(global_mouse_position)
		if control.has_method("_set_drop_hovered"):
			control.call("_set_drop_hovered", hovered)
		else:
			control.set_meta("drop_hovered", hovered)


func _clear_drop_highlights() -> void:
	for control in _drop_highlight_controls():
		if control.has_method("_set_drop_hovered"):
			control.call("_set_drop_hovered", false)
		else:
			control.set_meta("drop_hovered", false)
		if control.has_method("_set_drop_highlight"):
			control.call("_set_drop_highlight", "none")
		else:
			control.set_meta("drop_highlight_state", "none")
			control.set_meta("valid_drop_target", false)


func _drop_highlight_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _player_standee is Control:
		controls.append(_player_standee as Control)
	if _enemy_box != null:
		for child in _enemy_box.get_children():
			if child is Control:
				controls.append(child as Control)
	return controls
