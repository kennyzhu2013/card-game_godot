extends RefCounted

const SCRIPT_PATH := "res://scripts/ui/battle_scene.gd"
const SCENE_PATH := "res://scenes/combat/battle_scene.tscn"
const CardScript = preload("res://scripts/combat/card.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const BattleCardViewScript = preload("res://scripts/ui/battle/battle_card_view.gd")

class FakeBattleAIGMService:
	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "battle AI GM visible narration"


var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_battle_scene.gd --")
	test_script_loads_and_can_instantiate()
	test_scene_loads_and_can_instantiate()
	test_panel_exposes_start_battle_api()
	await test_battle_scene_has_arena_layout_regions()
	await test_battle_scene_arena_layout_keeps_controls_inside_1280x720_dense_state()
	await test_battle_scene_retires_old_vstack_region_names()
	await test_battle_scene_player_standee_replaces_player_hud_rail()
	await test_battle_scene_enemy_row_uses_enemy_standee_per_enemy()
	await test_battle_scene_does_not_render_intent_in_separate_rail()
	await test_battle_scene_has_slayspire_stage_regions()
	await test_battle_scene_shows_learned_rules()
	test_reward_card_buttons_show_effect_summary()
	test_hand_card_buttons_show_clean_summary_and_hide_raw_tokens()
	test_hand_card_tooltip_shows_mounted_brand_effects()
	await test_battle_scene_uses_card_views_for_hand()
	await test_battle_scene_hand_buttons_use_art_driven_portrait_size()
	await test_battle_scene_initial_layout_uses_larger_cards_and_compact_bottom_rail()
	await test_battle_scene_card_peek_uses_card_face_as_full_background()
	await test_battle_scene_slice5_card_ratio_reserves_standee_status_space_1280x720()
	await test_battle_scene_slice5_bottom_controls_stay_visible_in_compact_card_ratio_viewport()
	await test_battle_scene_slice5_bottom_controls_are_clamped_in_short_embedded_viewport()
	await test_battle_scene_layout_keeps_controls_inside_1280x720()
	await test_battle_scene_dense_state_keeps_critical_controls_inside_1280x720()
	await test_battle_scene_slice4_6_dense_presentation_matrix()
	await test_battle_scene_slice4_6_dense_arena_matrix()
	await test_battle_scene_slice4_6_drag_preview_remains_inside_viewport()
	await test_battle_scene_slice4_6_battle_finished_payload_unchanged()
	await test_battle_scene_slice4_7_dense_arena_matrix()
	await test_battle_scene_slice4_7_drag_preview_remains_inside_viewport()
	await test_battle_scene_slice4_7_battle_finished_payload_unchanged()
	await test_battle_scene_slice4_7_no_mouse_target_buttons_visible_in_default_arena()
	await test_battle_scene_slice4_7_top_bar_chips_do_not_truncate_at_1280()
	await test_battle_scene_slice4_7_top_bar_contracts_are_interpreted_in_chinese()
	await test_battle_scene_top_bar_shows_visible_contract_rule_detail()
	await test_battle_scene_top_bar_uses_single_contract_summary_with_rule_detail_slot()
	await test_battle_scene_top_bar_does_not_repeat_contract_rules_as_learned_rules()
	await test_battle_scene_slice4_7_enemy_stage_right_blank_is_tight_at_1280()
	await test_battle_scene_slice4_7_screenshot_hand_cards_use_clean_repeated_name()
	await test_battle_scene_three_enemy_stage_fits_1280x720()
	await test_battle_scene_selection_state_is_visible()
	await test_battle_scene_full_hand_keeps_cards_inside_1280x720()
	await test_battle_scene_battle_log_stays_scroll_constrained()
	await test_battle_scene_draw_pile_chip_shows_count_at_bottom_left()
	await test_battle_scene_discard_pile_chip_shows_count_at_bottom_right()
	await test_draw_pile_chip_click_opens_pile_inspect_panel_with_sorted_cards()
	await test_discard_pile_chip_click_opens_pile_inspect_panel_in_chronological_order()
	await test_pile_inspect_panel_closes_on_close_button_or_outside_click()
	await test_pile_inspect_panel_card_rows_show_clean_summaries_not_raw_tokens()
	await test_arena_top_bar_shows_active_contract_chips_at_top_of_screen()
	await test_arena_top_bar_shows_turn_counter_and_learned_rule_chips()
	await test_battle_scene_uses_full_aoe_drop_surface_without_arena_play_zone()
	await test_arena_center_does_not_leave_large_empty_band()
	await test_battle_scene_energy_orb_shows_current_and_max()
	await test_battle_scene_end_turn_button_anchored_bottom_right_and_responds()
	await test_battle_scene_battle_log_side_drawer_fills_right_side_and_collapses_on_click()
	await test_battle_scene_charge_zone_and_field_state_render_as_player_chips()
	await test_battle_scene_mounts_pollution_hud_and_updates_visual_nodes()
	await test_battle_scene_lost_control_start_auto_plays_and_disables_manual_cards()
	await test_battle_scene_marks_sequence_locked_cards_unusable()
	await test_battle_scene_respects_flame_stream_discount()
	await test_battle_scene_surfaces_persistent_field_state()
	await test_battle_scene_surfaces_created_temp_card_name_and_destination()
	await test_battle_scene_surfaces_mirror_generated_card_name_and_destination()
	await test_battle_scene_draw_filter_uses_player_choice()
	await test_battle_scene_draw_filter_copy_is_player_facing()
	await test_battle_scene_renders_actionable_enemy_intent_payload()
	await test_revealed_intent_uses_status_modified_damage()
	await test_revealed_intent_labels_enemy_defense_bypass_options()
	await test_revealed_enemy_intent_damage_survives_preview_refresh()
	await test_resolve_renders_contract_state()
	await test_battle_scene_surfaces_ai_gm_text_after_reward_pick()
	await test_battle_scene_renders_statuses_and_active_contract()
	await test_battle_scene_player_status_line_lists_multiple_statuses()
	await test_battle_scene_surfaces_multiple_statuses_and_defense_changes()
	await test_battle_scene_renders_status_detail_panel()
	await test_battle_scene_allows_select_targets_cards_to_choose_multiple_enemies()
	await test_battle_scene_old_click_to_select_flow_is_disabled_under_mouse()
	await test_battle_scene_keyboard_click_fallback_still_plays_card()
	await test_battle_scene_surfaces_intent_reveal_result_summary()
	await test_battle_scene_surfaces_last_card_result_summary()
	await test_battle_scene_last_action_feedback_does_not_replace_battle_log()
	await test_battle_scene_preserves_action_history_when_message_changes()
	await test_battle_scene_surfaces_charge_resolution_across_turns()
	await test_battle_scene_surfaces_delayed_brand_resolution_across_turns()
	await test_battle_scene_surfaces_echo_brand_replay_across_turns()
	await test_battle_scene_surfaces_enemy_turn_result_summary()
	await test_battle_scene_labels_common_runtime_result_reasons()
	return {"passed": _passed, "failed": _failed}


func test_script_loads_and_can_instantiate() -> void:
	var script = load(SCRIPT_PATH)
	assert_true(script != null and script.can_instantiate(), "battle_scene.gd loads")


func test_scene_loads_and_can_instantiate() -> void:
	var scene = load(SCENE_PATH)
	assert_true(scene != null and scene.can_instantiate(), "battle_scene.tscn instantiable")


func test_panel_exposes_start_battle_api() -> void:
	var script = load(SCRIPT_PATH)
	if script == null:
		return
	var inst = script.new()
	assert_true(inst.has_method("start_battle"), "battle scene exposes start_battle()")
	assert_true(inst.has_signal("battle_finished"), "battle scene exposes battle_finished signal")


func test_battle_scene_has_arena_layout_regions() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleArenaRegionViewport")
	if scene == null:
		return
	for region_name in [
		"BattleArenaLayerStack",
		"BattleAoeDropSurface",
		"BattleArenaRoot",
		"PlayerStage",
		"ArenaCenter",
		"ArenaMessageRibbon",
		"EnemyStage",
		"HandRail",
		"DrawPileChip",
		"DiscardPileChip",
		"EnergyOrb",
		"EndTurnButton",
		"BattleLogSideDrawer",
	]:
		assert_true(_find_control(scene, region_name) != null, "%s exists in the arena layout shell" % region_name)
	scene.get_parent().queue_free()


func test_battle_scene_arena_layout_keeps_controls_inside_1280x720_dense_state() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleArenaDenseViewport")
	if scene == null:
		return
	var cards: Array = []
	for i in range(10):
		cards.append(_layout_probe_card("arena_dense_card_%d" % i))
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("arena_dense_enemy_%d" % i, "Arena Dense Enemy %d With Long Name" % i)
		enemy.hp = 18 + i
		enemy.max_hp = 42 + i
		enemy.def = 2 + i
		enemy.add_status("weak", {"duration": 2, "magnitude": 1})
		enemy.add_status("vulnerable", {"duration": 2, "magnitude": 2})
		enemy.add_status("burn", {"duration": 2, "magnitude": 3})
		enemy.add_marker("paper_doll_marker", 1 + i)
		enemies.append(enemy)
	var player = CombatActorScript.new()
	player.display_name = "Arena Dense Player"
	player.hp = 44
	player.max_hp = 60
	player.def = 4
	player.add_status("fear", {"duration": 2})
	player.add_status("damage_reduction", {"duration": 2, "magnitude": 3})
	player.add_marker("paper_doll_marker", 3)
	scene.start_battle(cards, [], enemies, [
		"rule_use_debuff",
		"rule_no_consecutive_attack",
		"rule_draw_fate",
	] as Array[String], player, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	scene._battle.field_state["adjacent_burn"] = 3
	for i in range(14):
		scene.call("_set_last_action_message", "Arena dense log entry %02d with long battle feedback copy." % i)
	scene._selected_card = cards[0]
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	for region_name in ["BattleArenaRoot", "HandRail", "DrawPileChip", "DiscardPileChip", "EnergyOrb", "EndTurnButton"]:
		var region := _find_control(scene, region_name)
		assert_true(region != null, "%s exists for dense arena bounds check" % region_name)
		if region != null:
			assert_true(_rect_inside(region.get_global_rect(), bounds), "%s stays inside the 1280x720 dense arena viewport" % region_name)
	scene.get_parent().queue_free()


func test_battle_scene_retires_old_vstack_region_names() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleRetiredVStackViewport")
	if scene == null:
		return
	for retired_name in ["PlayerHudRail", "PileHudRail", "HandFan", "CombatMessageRail", "BattleInfoRoot", "StatusDetailPanel"]:
		assert_true(_find_control(scene, retired_name) == null, "%s is retired from the canonical arena layout" % retired_name)
	scene.get_parent().queue_free()


func test_battle_scene_player_standee_replaces_player_hud_rail() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattlePlayerStandeeViewport")
	if scene == null:
		return
	var player = CombatActorScript.new()
	player.display_name = "Battle Standee Player"
	player.hp = 31
	player.max_hp = 50
	player.def = 7
	player.add_status("weak", {"duration": 2, "description": "BattleScene weak detail."})
	player.add_status("burn", {"duration": 2, "description": "BattleScene burn detail."})
	var gs = _state()
	gs.learned_rules = ["rule_use_debuff"] as Array[String]
	scene.start_battle([_layout_probe_card("player_standee_card")], [], [], ["rule_use_debuff"] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	var player_stage := _find_control(scene, "PlayerStage")
	assert_true(player_stage != null, "PlayerStage exists for PlayerStandee replacement")
	var standees := _find_named_controls(player_stage, "PlayerStandee")
	assert_eq(standees.size(), 1, "PlayerStage contains exactly one PlayerStandee")
	var standee := standees[0] if not standees.is_empty() else null
	var standee_script = load("res://scripts/ui/battle/player_standee.gd")
	assert_true(standee != null and standee_script != null and standee.get_script() == standee_script, "PlayerStage child is a PlayerStandee instance")
	var text := _collect_label_text(standee)
	assert_true(text.contains("31") and text.contains("50"), "PlayerStandee receives player HP values from BattleScene")
	assert_true(text.contains("7"), "PlayerStandee receives player DEF from BattleScene")
	var status_strip = standee.find_child("StatusFeetStrip", true, false) if standee != null else null
	assert_true(status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() == 2, "PlayerStandee receives player statuses from BattleScene")
	scene.get_parent().queue_free()


func test_battle_scene_enemy_row_uses_enemy_standee_per_enemy() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleEnemyStandeeViewport")
	if scene == null:
		return
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("enemy_standee_scene_%d" % i, "Enemy Standee Scene %d" % i)
		enemy.hp = 18 + i
		enemy.max_hp = 30 + i
		enemy.def = i + 1
		enemy.add_status("weak", {"duration": 1 + i})
		enemies.append(enemy)
	scene.start_battle([_layout_probe_card("enemy_standee_card")], [], enemies, [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var enemy_row := _find_control(scene, "EnemyRow")
	assert_true(enemy_row != null, "EnemyRow exists for EnemyStandee replacement")
	var standee_script = load("res://scripts/ui/battle/enemy_standee.gd")
	var standees := _find_controls_by_script(enemy_row, standee_script)
	assert_eq(standees.size(), enemies.size(), "EnemyRow contains one EnemyStandee per enemy")
	for standee in standees:
		assert_true(standee_script != null and standee.get_script() == standee_script, "EnemyRow child is an EnemyStandee instance")
		var status_strip = standee.find_child("StatusFeetStrip", true, false)
		assert_true(status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() >= 1, "EnemyStandee receives enemy statuses from BattleScene")
	scene.get_parent().queue_free()


func test_battle_scene_does_not_render_intent_in_separate_rail() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleIntentRailRetiredViewport")
	if scene == null:
		return
	var enemy = EnemyScript.from_json({
		"id": "intent_rail_probe_enemy",
		"display_name": "Intent Rail Probe Enemy",
		"stats": {"hp": 28, "max_hp": 28, "atk": 5, "def": 2, "spd": 1},
		"skills": [{
			"id": "intent_rail_probe_skill",
			"name": "Intent Rail Probe Skill",
			"damage": 9,
			"target": "single",
			"intent_type": "attack",
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill_id": "intent_rail_probe_skill"}],
	})
	scene.start_battle([_layout_probe_card("intent_rail_probe_card")], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var enemy_standee_script = load("res://scripts/ui/battle/enemy_standee.gd")
	var labels := _collect_labels(scene)
	var outside_intent_labels := 0
	for label in labels:
		var text := (label as Label).text.strip_edges()
		if text.begins_with("意图：") and not _is_descendant_of_script(label, enemy_standee_script):
			outside_intent_labels += 1
	assert_eq(outside_intent_labels, 0, "battle scene renders no old-prefix intent labels outside EnemyStandee")
	scene.get_parent().queue_free()


func test_battle_scene_has_slayspire_stage_regions() -> void:
	var viewport := Control.new()
	viewport.name = "BattleStageRegionViewport"
	viewport.position = Vector2.ZERO
	viewport.size = Vector2(1280, 720)
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for stage-region test")
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(10):
		cards.append(_layout_probe_card("stage_region_card_%d" % i))
	var enemies: Array = []
	for i in range(3):
		enemies.append(_enemy("stage_region_enemy_%d" % i, "Stage Region Enemy %d" % i))
	var gs = _state()
	gs.learned_rules = ["rule_use_debuff", "rule_draw_fate", "rule_shadow_takes_hit"] as Array[String]
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_draw_fate"] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	var long_text := _long_layout_text("stage-region overflow probe", 28)
	scene._rules_label.text = long_text
	scene._rules_label.visible = true
	scene._contract_label.text = long_text
	scene._contract_label.visible = true
	scene._status_detail_label.text = long_text
	scene._battle_log_label.text = long_text
	scene._message_label.text = long_text
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport.size)
	for region_name in ["BattleArenaLayerStack", "BattleAoeDropSurface", "BattleArenaRoot", "PlayerStage", "ArenaCenter", "ArenaMessageRibbon", "EnemyStage", "HandRail", "DrawPileChip", "DiscardPileChip", "EnergyOrb", "BattleLogSideDrawer"]:
		var region := _find_control(scene, region_name)
		assert_true(region != null, "%s exists as a named battle stage region" % region_name)
		if region != null:
			var rect := region.get_global_rect()
			assert_true(_rect_inside(rect, bounds), "%s stays inside the 1280x720 viewport" % region_name)
	var top_summary := _find_control(scene, "PlayerStage")
	var hand_fan := _find_control(scene, "HandRail")
	var flee_button := _find_control(scene, "FleeButton")
	for control in [top_summary, hand_fan, scene._end_turn_button, flee_button]:
		assert_true(control != null and control.is_visible_in_tree(), "critical battle control remains visible with long info text")
		if control != null:
			assert_true(_rect_inside(control.get_global_rect(), bounds), "critical battle control stays inside viewport with long info text")
	viewport.queue_free()


func test_battle_scene_shows_learned_rules() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var rules: Array[String] = ["shadow_silence", "promotion_misdirection"]
	gs.learned_rules = rules
	var contract: Array[String] = []
	scene.start_battle([], [], [], contract, null, gs)
	await Engine.get_main_loop().process_frame
	var standee := _find_control(scene, "PlayerStandee")
	var detail_text := standee.tooltip_text if standee != null else ""
	assert_true(detail_text.contains(str(scene.call("_rule_label_text", "shadow_silence"))), "battle scene exposes learned rule text in PlayerStandee tooltip")
	assert_true(detail_text.contains(str(scene.call("_rule_label_text", "promotion_misdirection"))), "battle scene exposes second learned rule text in PlayerStandee tooltip")
	for raw in rules:
		assert_true(not detail_text.contains(raw), "PlayerStandee tooltip hides raw learned rule id %s" % raw)
	scene.queue_free()


func test_reward_card_buttons_show_effect_summary() -> void:
	var script = load(SCRIPT_PATH)
	if script == null:
		assert_true(false, "battle scene script loads for reward label test")
		return
	var scene = script.new()
	var card = CardScript.from_json({
		"id": "reward_summary_probe",
		"display_name": "奖励说明探针",
		"description": "让纸张替你挡下一次灾厄",
		"energy_cost": 1,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "self",
			"range": 0,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 3}],
		},
		"world_effect": {"type": "create_residual_identity", "duration_days": 1},
	})
	var text := str(scene.call("_card_button_text", card))
	assert_true(text.contains("奖励说明探针"), "reward card button keeps card name")
	assert_true(text.contains("让纸张替你挡下一次灾厄"), "reward card button includes readable card description")
	assert_true(text.contains("纸人替身") or text.contains("paper_doll_marker"), "reward card button includes combat status effect summary")
	assert_true(text.contains("世界") and text.contains("残留身份"), "reward card button includes field/world effect summary")


func test_hand_card_buttons_show_clean_summary_and_hide_raw_tokens() -> void:
	var script = load(SCRIPT_PATH)
	if script == null:
		assert_true(false, "battle scene script loads for hand button summary test")
		return
	var scene = script.new()
	var card = CardScript.from_json({
		"id": "hand_summary_probe",
		"display_name": "战斗说明探针",
		"description": "让纸张替你承受一次灾厄。",
		"energy_cost": 2,
		"combat_effect": {
			"damage": 12,
			"heal": 0,
			"target": "single",
			"range": 3,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 3}],
		},
		"social_effect": {"type": "identity_mask", "suspicion_delta": -10},
		"world_effect": {"type": "create_residual_identity", "allowed_locations": ["shadow_alley"]},
	})
	var text := str(scene.call("_card_button_text_with_cost", card, 2))
	assert_true(text.contains("战斗说明探针"), "hand card button keeps card name")
	assert_true(text.contains("费用：2"), "hand card button shows clean cost")
	assert_true(text.contains("纸人替身"), "hand card button includes readable combat effect summary")
	assert_true(text.contains("场外·社交") and text.contains("场外·世界"), "hand card button includes field summaries")
	for raw in ["paper_doll_marker", "identity_mask", "create_residual_identity", "shadow_alley", "{", "}"]:
		assert_true(not text.contains(raw), "hand card button hides raw token %s" % raw)


func test_hand_card_tooltip_shows_mounted_brand_effects() -> void:
	var script = load(SCRIPT_PATH)
	if script == null:
		assert_true(false, "battle scene script loads for hand brand summary test")
		return
	var scene = script.new()
	var card = CardScript.from_json({
		"id": "hand_brand_summary_probe",
		"display_name": "战斗烙印探针",
		"description": "用于验证战斗手牌提示展示挂载烙印效果。",
		"brand_slots": 3,
		"brands": ["damage_plus_low", "pierce"],
		"energy_cost": 0,
		"combat_effect": {
			"damage": 8,
			"heal": 0,
			"target": "single",
			"range": 2,
			"status_effects": [],
		},
	})
	var text := str(scene.call("_card_button_text_with_cost", card, 0))
	assert_true(text.contains("烙印"), "hand card tooltip has a mounted-brand section")
	assert_true(text.contains("锐利之纹") and text.contains("该卡伤害增加3"), "hand card tooltip explains damage brand")
	assert_true(text.contains("破甲之纹") and text.contains("忽视3点防御"), "hand card tooltip explains pierce brand")
	for raw in ["damage_plus_low", "pierce", "effect_payload", "{", "}"]:
		assert_true(not text.contains(raw), "hand card tooltip hides raw token %s" % raw)


func test_battle_scene_uses_card_views_for_hand() -> void:
	var viewport := Control.new()
	viewport.name = "BattleCardViewHandViewport"
	viewport.position = Vector2.ZERO
	viewport.size = Vector2(1280, 720)
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for card-view hand test")
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(10):
		var card := _layout_probe_card("battle_card_view_hand_%d" % i)
		if i == 0:
			card.energy_cost = 9
		cards.append(card)
	scene.start_battle(cards, [], [_enemy("battle_card_view_enemy", "Battle Card View Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 0
	scene._battle.hand = cards
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport.size)
	var disabled_reason_count := 0
	assert_eq(scene._hand_box.get_child_count(), 10, "battle scene renders all ten hand cards")
	for child in scene._hand_box.get_children():
		var card_view := _find_battle_card_view(child)
		assert_true(card_view != null, "hand child is or contains a BattleCardView")
		if card_view is Control:
			var rect := (card_view as Control).get_global_rect()
			assert_true(_rect_inside(rect, bounds), "BattleCardView stays inside 1280x720 viewport")
			assert_true(rect.size.x >= 48.0 and rect.size.y >= 48.0, "BattleCardView keeps 48px+ touch target")
			var reason_label = card_view.find_child("DisabledReasonLabel", true, false)
			if reason_label is Label and (reason_label as Label).visible and (reason_label as Label).text.strip_edges() != "":
				disabled_reason_count += 1
	assert_true(disabled_reason_count > 0, "disabled hand cards show a visible reason label")
	viewport.queue_free()


func test_battle_scene_hand_buttons_use_art_driven_portrait_size() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice5T15ArtDrivenHandViewport")
	if scene == null:
		return
	var ids := [
		"shadow_arrow",
		"fool_s9_spirit_vision",
		"fool_s9_star_chart_divination",
		"fool_s9_pendulum_query",
		"fool_s9_ritual_chant",
		"chariot_s7_thunder_boarding",
	]
	var cards: Array = []
	for i in range(ids.size()):
		var card := _layout_probe_card("slice5_art_driven_hand_%d" % i)
		card.template_id = str(ids[i])
		card.display_name = "Slice 5 Art Driven Card %d" % i
		card.energy_cost = i % 3
		cards.append(card)
	scene.start_battle(cards, [], [_enemy("slice5_art_driven_enemy", "Slice 5 Art Driven Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var hand_rail := _find_control(scene, "HandRail")
	assert_true(hand_rail != null, "BattleScene has a HandRail for art-driven card sizing")
	var tallest_card_height := 0.0
	for child in scene._hand_box.get_children():
		assert_true(child is Control, "hand child is a sized Control wrapper")
		if not child is Control:
			continue
		var wrapper := child as Control
		var card_view := _find_battle_card_view(wrapper)
		assert_true(card_view != null, "art-driven hand wrapper contains a BattleCardView")
		var wrapper_size := wrapper.custom_minimum_size
		assert_true(wrapper_size.y > wrapper_size.x * 1.40, "hand card wrapper follows portrait card art aspect instead of a fixed short button")
		if card_view != null:
			assert_eq((card_view as Control).custom_minimum_size, wrapper_size, "BattleCardView and its button wrapper use the same art-driven card size")
			var art = card_view.find_child("CardArt", true, false)
			assert_true(art is TextureRect and (art as TextureRect).texture != null, "art-driven hand card binds an integrated card texture")
		var rect := wrapper.get_global_rect()
		assert_true(rect.size.y > rect.size.x * 1.35, "rendered hand card stays visibly portrait in the 1280x720 hand rail")
		assert_true(_rect_inside(rect, Rect2(Vector2.ZERO, viewport_size)), "art-driven hand card stays inside the 1280x720 viewport")
		tallest_card_height = maxf(tallest_card_height, wrapper_size.y)
	if hand_rail != null:
		assert_true(hand_rail.custom_minimum_size.y >= tallest_card_height + 16.0, "HandRail height grows around the art-driven card height")
	scene.get_parent().queue_free()


func test_battle_scene_initial_layout_uses_larger_cards_and_compact_bottom_rail() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice5InitialLargeCardViewport")
	if scene == null:
		return
	var ids := [
		"shadow_arrow",
		"fool_s9_spirit_vision",
		"fool_s9_star_chart_divination",
		"fool_s9_pendulum_query",
		"fool_s9_ritual_chant",
		"chariot_s7_thunder_boarding",
	]
	var cards: Array = []
	for i in range(ids.size()):
		var card := _layout_probe_card("slice5_initial_large_card_%d" % i)
		card.template_id = str(ids[i])
		card.display_name = "Slice 5 Initial Large Card %d" % i
		card.energy_cost = i % 3
		cards.append(card)
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("slice5_initial_large_enemy_%d" % i, "Slice 5 Initial Enemy %d" % (i + 1))
		enemy.hp = 24 + i
		enemy.max_hp = 48 + i
		enemy.def = 2 + i
		enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
		enemies.append(enemy)
	var player = CombatActorScript.new()
	player.display_name = "Slice 5 Initial Player"
	player.hp = 45
	player.max_hp = 62
	player.def = 5
	player.add_status("ward", {"duration": 3, "magnitude": 6})
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String], player, _state())
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var hand_rail := _find_control(scene, "HandRail")
	var bottom_rail := _find_control(scene, "BottomChipRail")
	assert_true(hand_rail != null, "initial Slice 5 battle renders HandRail")
	assert_true(bottom_rail != null, "initial Slice 5 battle renders BottomChipRail")
	if hand_rail != null and bottom_rail != null:
		assert_true(_rect_inside(hand_rail.get_global_rect(), bounds), "initial HandRail is inside 1280x720 before any card is played")
		assert_true(_rect_inside(bottom_rail.get_global_rect(), bounds), "initial BottomChipRail is inside 1280x720 before any card is played")
		assert_true(hand_rail.get_global_rect().end.y <= bottom_rail.get_global_rect().position.y, "initial HandRail is clamped above compact bottom rail")
		assert_true(bottom_rail.custom_minimum_size.y <= 38.0, "initial BottomChipRail is compact so card art receives the vertical budget")
		assert_true(bottom_rail.get_global_rect().size.y <= 42.0, "initial BottomChipRail rendered height stays visually compact")
	for control_name in ["DrawPileChip", "EnergyOrb", "EndTurnButton", "FleeButton", "DiscardPileChip"]:
		var control := _find_control(scene, control_name)
		assert_true(control != null, "%s exists in the compact initial bottom rail" % control_name)
		if control != null:
			assert_true(_rect_inside(control.get_global_rect(), bounds), "%s stays inside 1280x720 on the first battle frame" % control_name)
			assert_true(control.custom_minimum_size.y <= 34.0, "%s uses compact bottom-row sizing" % control_name)
	var tallest_card_height := 0.0
	for child in scene._hand_box.get_children():
		if not child is Control:
			continue
		var wrapper := child as Control
		tallest_card_height = maxf(tallest_card_height, wrapper.custom_minimum_size.y)
		assert_true(wrapper.custom_minimum_size.y >= 224.0, "initial hand card is large enough for the integrated art face")
		assert_true(_rect_inside(wrapper.get_global_rect(), bounds), "initial hand card stays inside 1280x720 without waiting for a card play")
	if hand_rail != null:
		assert_true(hand_rail.custom_minimum_size.y >= tallest_card_height + 16.0, "initial HandRail reserves the larger card height on first render")
	scene.get_parent().queue_free()


func test_battle_scene_card_peek_uses_card_face_as_full_background() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice5CardPeekBackgroundViewport")
	if scene == null:
		return
	var card := _layout_probe_card("slice5_peek_background_card")
	card.template_id = "fool_s9_spirit_vision"
	card.display_name = "Slice 5 Peek Background Card"
	scene.start_battle([card], [], [_enemy("slice5_peek_background_enemy", "Slice 5 Peek Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene.call("_open_card_peek", card)
	await Engine.get_main_loop().process_frame
	var peek_panel := _find_control(scene, "CardPeekPanel")
	var peek_content := _find_control(scene, "CardPeekContent")
	var peek_body := _find_control(scene, "CardPeekBody")
	var peek_art := _find_control(scene, "CardPeekArt")
	assert_true(peek_panel != null and peek_panel.visible, "CardPeekPanel opens for a Slice 5 hand card")
	assert_true(peek_content != null and _rect_inside(peek_content.get_global_rect(), Rect2(Vector2.ZERO, viewport_size)), "CardPeekContent stays inside 1280x720")
	assert_true(peek_art is TextureRect, "CardPeekArt exists as the detail background art node")
	if peek_art is TextureRect:
		var art_rect := peek_art as TextureRect
		assert_true(art_rect.texture != null, "CardPeekArt receives the actual card face texture")
		assert_true(art_rect.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "CardPeekArt ignores its source size as a background layer")
		assert_true(art_rect.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "CardPeekArt covers the detail panel instead of centering as a small inline image")
		if peek_content != null:
			assert_true(art_rect.get_global_rect().size.y >= peek_content.get_global_rect().size.y * 0.82, "CardPeekArt fills most of the detail panel height as a card-face background")
		if peek_body != null:
			assert_true(not _is_descendant_of(art_rect, peek_body), "CardPeekArt is not inside the text body flow")
	scene.get_parent().queue_free()


func test_battle_scene_slice5_card_ratio_reserves_standee_status_space_1280x720() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice5CardRatioArenaReserveViewport")
	if scene == null:
		return
	var ids := [
		"shadow_arrow",
		"fool_s9_spirit_vision",
		"fool_s9_star_chart_divination",
		"fool_s9_pendulum_query",
		"fool_s9_ritual_chant",
		"chariot_s7_thunder_boarding",
	]
	var cards: Array = []
	for i in range(ids.size()):
		var card := _layout_probe_card("slice5_card_ratio_card_%d" % i)
		card.template_id = str(ids[i])
		card.display_name = "Slice 5 Card Ratio Probe %d" % i
		card.energy_cost = i % 3
		cards.append(card)
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("slice5_card_ratio_enemy_%d" % i, "Slice 5 Ratio Enemy %d" % (i + 1))
		enemy.hp = 22 + i
		enemy.max_hp = 46 + i
		enemy.def = 2 + i
		enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
		if i == 1:
			enemy.add_status("defense_break", {"duration": 2, "magnitude": 2})
		enemies.append(enemy)
	var player = CombatActorScript.new()
	player.display_name = "Slice 5 Ratio Player"
	player.hp = 45
	player.max_hp = 62
	player.def = 5
	player.add_status("ward", {"duration": 3, "magnitude": 6})
	player.add_status("chant_charge", {"duration": 2, "stacks": 2})
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String], player, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var hand_rail := _find_control(scene, "HandRail")
	var hand_rect := hand_rail.get_global_rect() if hand_rail != null else Rect2()
	assert_true(hand_rail != null, "Slice 5 ratio battle renders HandRail")
	if hand_rail != null:
		assert_true(hand_rail.custom_minimum_size.y <= viewport_size.y * 0.34, "HandRail leaves enough vertical room for the battle stage at 1280x720")
	var arena_stack := _find_control(scene, "BattleArenaLayerStack")
	assert_true(arena_stack != null, "Slice 5 ratio battle renders BattleArenaLayerStack")
	if arena_stack != null:
		assert_true(arena_stack.custom_minimum_size.y >= 280.0, "BattleArenaLayerStack reserves model/status height after portrait cards")
		assert_true(arena_stack.get_global_rect().size.y >= 280.0, "BattleArenaLayerStack receives visible model/status height at 1280x720")
	var player_stage := _find_control(scene, "PlayerStage")
	assert_true(player_stage != null, "Slice 5 ratio battle renders PlayerStage")
	if player_stage != null:
		assert_true(player_stage.custom_minimum_size.y >= 210.0, "PlayerStage reserves the PlayerStandee default height")
	var player_standee := _find_control(scene, "PlayerStandee")
	assert_true(player_standee != null, "Slice 5 ratio battle renders PlayerStandee")
	if player_standee != null and hand_rail != null:
		assert_true(player_standee.get_global_rect().size.y >= 210.0, "PlayerStandee keeps full model/status height at 1280x720")
		assert_true(not player_standee.get_global_rect().intersects(hand_rect), "PlayerStandee does not disappear under HandRail")
		for child_name in ["PortraitSlot", "HpBar", "HpText", "StatusFeetStrip"]:
			var child := _find_control(player_standee, child_name)
			assert_true(child != null, "PlayerStandee exposes %s for visibility checks" % child_name)
			if child != null:
				assert_true(_rect_inside(child.get_global_rect(), bounds), "PlayerStandee %s stays inside the 1280x720 viewport" % child_name)
				assert_true(child.get_global_rect().end.y <= hand_rect.position.y, "PlayerStandee %s stays above the hand rail" % child_name)
	var enemy_standee_script = load("res://scripts/ui/battle/enemy_standee.gd")
	var enemy_standees := _find_controls_by_script(scene, enemy_standee_script)
	assert_eq(enemy_standees.size(), 3, "Slice 5 ratio battle renders all three EnemyStandees")
	for standee in enemy_standees:
		assert_true(standee.custom_minimum_size.y >= 210.0, "EnemyStandee reserves its full default model/status height")
		assert_true(standee.get_global_rect().size.y >= 210.0, "EnemyStandee keeps full model/status height at 1280x720")
		assert_true(not standee.get_global_rect().intersects(hand_rect), "EnemyStandee does not disappear under HandRail")
		for child_name in ["PortraitSlot", "HpBar", "HpText", "StatusFeetStrip"]:
			var child := _find_control(standee, child_name)
			assert_true(child != null, "EnemyStandee exposes %s for visibility checks" % child_name)
			if child != null:
				assert_true(_rect_inside(child.get_global_rect(), bounds), "EnemyStandee %s stays inside the 1280x720 viewport" % child_name)
				assert_true(child.get_global_rect().end.y <= hand_rect.position.y, "EnemyStandee %s stays above the hand rail" % child_name)
	scene.get_parent().queue_free()


func test_battle_scene_slice5_bottom_controls_stay_visible_in_compact_card_ratio_viewport() -> void:
	var viewport_size := Vector2(1280, 600)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice5CompactBottomRailViewport")
	if scene == null:
		return
	var ids := [
		"shadow_arrow",
		"fool_s9_spirit_vision",
		"fool_s9_star_chart_divination",
		"fool_s9_pendulum_query",
		"fool_s9_ritual_chant",
		"chariot_s7_thunder_boarding",
	]
	var cards: Array = []
	for i in range(ids.size()):
		var card := _layout_probe_card("slice5_compact_bottom_card_%d" % i)
		card.template_id = str(ids[i])
		card.display_name = "Slice 5 Compact Bottom Card %d" % i
		card.energy_cost = i % 3
		cards.append(card)
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("slice5_compact_bottom_enemy_%d" % i, "Slice 5 Compact Enemy %d" % (i + 1))
		enemy.hp = 21 + i
		enemy.max_hp = 44 + i
		enemy.def = 2 + i
		enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
		enemies.append(enemy)
	var player = CombatActorScript.new()
	player.display_name = "Slice 5 Compact Player"
	player.hp = 45
	player.max_hp = 62
	player.def = 5
	player.add_status("ward", {"duration": 3, "magnitude": 6})
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String], player, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.draw_pile = cards.slice(0, 3)
	scene._battle.discard_pile = cards.slice(3, 5)
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	for i in range(12):
		scene.call("_set_last_action_message", "Slice 5 compact bottom log entry %02d." % i)
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var hand_rail := _find_control(scene, "HandRail")
	var bottom_rail := _find_control(scene, "BottomChipRail")
	assert_true(hand_rail != null, "compact Slice 5 battle renders HandRail")
	assert_true(bottom_rail != null, "compact Slice 5 battle renders BottomChipRail")
	if hand_rail != null and bottom_rail != null:
		var hand_rect := hand_rail.get_global_rect()
		var bottom_rect := bottom_rail.get_global_rect()
		assert_true(_rect_inside(bottom_rect, bounds), "BottomChipRail stays fully visible in a compact battle viewport rect=%s bounds=%s hand=%s" % [str(bottom_rect), str(bounds), str(hand_rect)])
		assert_true(bottom_rect.size.y >= 32.0 and bottom_rect.size.y <= 42.0, "BottomChipRail keeps a compact usable touch height")
		assert_true(hand_rect.end.y <= bottom_rect.position.y, "HandRail does not overlap the bottom operation rail")
	for control_name in ["DrawPileChip", "EnergyOrb", "EndTurnButton", "FleeButton", "DiscardPileChip"]:
		var control := _find_control(scene, control_name)
		assert_true(control != null, "%s exists for compact bottom rail visibility" % control_name)
		if control != null:
			assert_true(control.is_visible_in_tree(), "%s remains visible in compact viewport" % control_name)
			assert_true(_rect_inside(control.get_global_rect(), bounds), "%s stays inside the compact battle viewport rect=%s bounds=%s" % [control_name, str(control.get_global_rect()), str(bounds)])
	scene.get_parent().queue_free()


func test_battle_scene_slice5_bottom_controls_are_clamped_in_short_embedded_viewport() -> void:
	var viewport_size := Vector2(1280, 540)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice5ShortEmbeddedBottomRailViewport")
	if scene == null:
		return
	var ids := [
		"shadow_arrow",
		"fool_s9_spirit_vision",
		"fool_s9_star_chart_divination",
		"fool_s9_pendulum_query",
		"fool_s9_ritual_chant",
		"chariot_s7_thunder_boarding",
	]
	var cards: Array = []
	for i in range(ids.size()):
		var card := _layout_probe_card("slice5_short_bottom_card_%d" % i)
		card.template_id = str(ids[i])
		card.display_name = "Slice 5 Short Bottom Card %d" % i
		card.energy_cost = i % 3
		cards.append(card)
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("slice5_short_bottom_enemy_%d" % i, "Slice 5 Short Enemy %d" % (i + 1))
		enemy.hp = 21 + i
		enemy.max_hp = 44 + i
		enemy.def = 2 + i
		enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
		enemies.append(enemy)
	var player = CombatActorScript.new()
	player.display_name = "Slice 5 Short Player"
	player.hp = 45
	player.max_hp = 62
	player.def = 5
	player.add_status("ward", {"duration": 3, "magnitude": 6})
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String], player, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.draw_pile = cards.slice(0, 3)
	scene._battle.discard_pile = cards.slice(3, 5)
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	for i in range(12):
		scene.call("_set_last_action_message", "Slice 5 short bottom log entry %02d." % i)
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var arena_stack := _find_control(scene, "BattleArenaLayerStack")
	var hand_rail := _find_control(scene, "HandRail")
	var bottom_rail := _find_control(scene, "BottomChipRail")
	assert_true(arena_stack != null, "short embedded battle renders BattleArenaLayerStack")
	assert_true(hand_rail != null, "short embedded battle renders HandRail")
	assert_true(bottom_rail != null, "short embedded battle renders BottomChipRail")
	if arena_stack != null and hand_rail != null:
		assert_true(arena_stack.get_global_rect().end.y <= hand_rail.get_global_rect().position.y, "short embedded arena is clamped above HandRail")
	if hand_rail != null and bottom_rail != null:
		assert_true(hand_rail.get_global_rect().end.y <= bottom_rail.get_global_rect().position.y, "short embedded HandRail is clamped above BottomChipRail")
	if bottom_rail != null:
		assert_true(_rect_inside(bottom_rail.get_global_rect(), bounds), "short embedded BottomChipRail stays fully inside the visible viewport rect=%s bounds=%s" % [str(bottom_rail.get_global_rect()), str(bounds)])
		assert_true(bottom_rail.get_global_rect().end.y <= viewport_size.y - 2.0, "short embedded BottomChipRail leaves a visible bottom inset")
	for control_name in ["DrawPileChip", "EnergyOrb", "EndTurnButton", "FleeButton", "DiscardPileChip"]:
		var control := _find_control(scene, control_name)
		assert_true(control != null, "%s exists in short embedded bottom rail" % control_name)
		if control != null:
			assert_true(control.is_visible_in_tree(), "%s remains visible in short embedded viewport" % control_name)
			assert_true(_rect_inside(control.get_global_rect(), bounds), "%s stays inside the short embedded viewport rect=%s bounds=%s" % [control_name, str(control.get_global_rect()), str(bounds)])
	scene.get_parent().queue_free()


func test_battle_scene_layout_keeps_controls_inside_1280x720() -> void:
	var viewport := Control.new()
	viewport.name = "BattleLayoutViewport"
	viewport.position = Vector2.ZERO
	viewport.size = Vector2(1280, 720)
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for layout test")
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(5):
		cards.append(_layout_probe_card("layout_probe_%d" % i))
	scene.start_battle(cards, [], [], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport.size)
	assert_true(_rect_inside(scene.get_global_rect(), bounds), "battle root fits 1280x720 viewport")
	assert_true(_rect_inside(scene._hand_box.get_global_rect(), bounds), "battle hand row fits 1280x720 viewport")
	assert_true(_rect_inside(scene._end_turn_button.get_global_rect(), bounds), "battle end-turn button stays visible inside 1280x720 viewport")
	for child in scene._hand_box.get_children():
		if child is Control:
			assert_true(_rect_inside((child as Control).get_global_rect(), bounds), "battle hand card button stays inside 1280x720 viewport")
	viewport.queue_free()


func test_battle_scene_dense_state_keeps_critical_controls_inside_1280x720() -> void:
	var viewport := Control.new()
	viewport.name = "BattleDenseLayoutViewport"
	viewport.position = Vector2.ZERO
	viewport.size = Vector2(1280, 720)
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for dense layout test")
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(8):
		cards.append(_layout_probe_card("dense_layout_probe_%d" % i))
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("dense_layout_enemy_%d" % i, "Dense Layout Enemy %d" % i)
		enemy.add_status("weak", {"duration": 2, "magnitude": 1})
		enemy.add_status("vulnerable", {"duration": 2, "magnitude": 2})
		enemy.add_marker("paper_doll_marker", 2)
		enemies.append(enemy)
	var gs = _state()
	var rules: Array[String] = [
		"rule_use_debuff",
		"rule_no_consecutive_attack",
		"rule_draw_fate",
		"rule_no_light_element",
		"rule_shadow_takes_hit",
	]
	gs.learned_rules = rules
	var player = CombatActorScript.new()
	player.display_name = "Dense Layout Player"
	player.hp = 42
	player.max_hp = 58
	player.def = 4
	player.add_status("fear", {"duration": 2})
	player.add_status("damage_reduction", {"duration": 2, "magnitude": 3})
	player.add_marker("paper_doll_marker", 3)
	scene.start_battle(cards, [], enemies, [
		"rule_use_debuff",
		"rule_no_consecutive_attack",
		"rule_draw_fate",
	] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.hand = cards
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
		{"source_card": cards[2], "remaining": 3},
	]
	scene._battle.field_state["flame_markers"] = 4
	scene._battle.field_state["adjacent_burn"] = 3
	for i in range(16):
		scene.call("_set_last_action_message", "Dense battle log entry %02d with enough copy to exercise constrained scrolling." % i)
	scene._selected_card = cards[0]
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport.size)
	var hand_scroll = scene.find_child("HandScroll", true, false)
	var status_panel = scene.find_child("PlayerStage", true, false)
	var charge_zone = scene.find_child("ChargeZone", true, false)
	var log_panel = scene.find_child("BattleLogSideDrawer", true, false)
	assert_true(hand_scroll is ScrollContainer, "dense battle hand uses a scroll container")
	if hand_scroll is Control:
		assert_true(_rect_inside((hand_scroll as Control).get_global_rect(), bounds), "dense battle hand scroll stays inside 1280x720 viewport")
	assert_true(_rect_inside(scene._hand_box.get_global_rect(), bounds), "dense battle hand row stays visible inside 1280x720 viewport")
	assert_true(_rect_inside(scene._end_turn_button.get_global_rect(), bounds), "dense battle end-turn button stays visible inside 1280x720 viewport")
	for panel in [status_panel, charge_zone, log_panel]:
		if panel is Control:
			assert_true(_rect_inside((panel as Control).get_global_rect(), bounds), "%s stays inside dense 1280x720 viewport" % str((panel as Control).name))
	viewport.queue_free()


func test_battle_scene_slice4_6_dense_presentation_matrix() -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080)]:
		await _run_slice4_6_dense_presentation_probe(viewport_size)


func test_battle_scene_slice4_6_dense_arena_matrix() -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080)]:
		await _run_slice4_6_dense_arena_matrix_probe(viewport_size)


func _run_slice4_6_dense_arena_matrix_probe(viewport_size: Vector2) -> void:
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice46FinalDenseArena_%dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	if scene == null:
		return
	var cards: Array = []
	for i in range(10):
		var card := _layout_probe_card("slice46_final_matrix_card_%d_%d" % [int(viewport_size.x), i])
		card.display_name = "Slice 4.6 Final Matrix Card %02d" % i
		card.energy_cost = i % 4
		cards.append(card)
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("slice46_final_matrix_enemy_%d_%d" % [int(viewport_size.x), i], "Slice 4.6 Final Enemy %d With Long Name" % i)
		enemy.hp = 24 + i
		enemy.max_hp = 48 + i
		enemy.def = 3 + i
		enemy.add_status("weak", {"duration": 3, "magnitude": 1, "description": "Dense enemy weak detail"})
		enemy.add_status("vulnerable", {"duration": 2, "magnitude": 2, "description": "Dense enemy vulnerable detail"})
		enemy.add_status("burn", {"duration": 2, "magnitude": 3, "description": "Dense enemy burn detail"})
		if i == 2:
			enemy.add_status("obscure_intent", {"duration": 1})
		enemies.append(enemy)
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_use_debuff", "rule_no_consecutive_attack", "rule_draw_fate", "rule_shadow_takes_hit"])
	var player = CombatActorScript.new()
	player.display_name = "Slice 4.6 Final Matrix Player"
	player.hp = 45
	player.max_hp = 62
	player.def = 5
	player.add_status("fear", {"duration": 3, "description": "Dense fear detail"})
	player.add_status("damage_reduction", {"duration": 2, "magnitude": 3, "description": "Dense reduction detail"})
	player.add_marker("paper_doll_marker", 4)
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_no_consecutive_attack", "rule_draw_fate"] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	scene._battle.field_state["adjacent_burn"] = 3
	for i in range(14):
		scene.call("_set_last_action_message", "Slice 4.6 final dense matrix log entry %02d with constrained long copy." % i)
	scene.call("_render")
	scene.call("_set_battle_log_drawer_expanded", true)
	var result := {
		"outcome": "victory",
		"reward_options": [cards[0], cards[1], cards[2]],
		"selected_card": cards[1],
		"brand_drop": {"display_name": "Slice 4.6 Final Matrix Brand Drop"},
		"contract": {"outcome": "broken", "tier": 2, "pollution_delta": 5, "acting_check_base_difficulty": 2, "acting_check_difficulty": 2, "acting_check_weather_modifier": -1},
		"ai_gm_text": "slice 4.6 final dense matrix battle narrative expanded",
	}
	scene.call("_show_result_overlay", result, "Slice 4.6 final matrix victory")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	for region_name in ["BattleArenaLayerStack", "BattleAoeDropSurface", "BattleArenaRoot", "PlayerStage", "EnemyStage", "ArenaCenter", "ArenaMessageRibbon", "HandRail", "DrawPileChip", "DiscardPileChip", "EnergyOrb", "EndTurnButton", "BattleLogSideDrawer", "BattleResultOverlay", "BattleNarrativeRail"]:
		var region := _find_control(scene, region_name)
		assert_true(region != null and region.is_visible_in_tree(), "%s is visible in Slice 4.6 final dense matrix %s" % [region_name, str(viewport_size)])
		if region != null:
			var rect := region.get_global_rect()
			assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has non-zero rect in Slice 4.6 final dense matrix %s" % [region_name, str(viewport_size)])
			assert_true(_rect_inside(rect, bounds), "%s stays inside Slice 4.6 final dense matrix viewport %s" % [region_name, str(viewport_size)])
	var drawer := _find_control(scene, "BattleLogSideDrawer")
	assert_true(drawer != null and drawer.get_global_rect().size.x >= 240.0, "BattleLogSideDrawer is expanded in Slice 4.6 final dense matrix %s" % str(viewport_size))
	var hand := _find_control(scene, "HandRail")
	var hand_rect := hand.get_global_rect() if hand != null else Rect2()
	var player_standee := _find_control(scene, "PlayerStandee")
	assert_true(player_standee != null and not player_standee.get_global_rect().intersects(hand_rect), "PlayerStandee does not overlap HandRail in Slice 4.6 final dense matrix %s" % str(viewport_size))
	var enemy_standee_script = load("res://scripts/ui/battle/enemy_standee.gd")
	var enemy_standees := _find_controls_by_script(scene, enemy_standee_script)
	assert_eq(enemy_standees.size(), 3, "Slice 4.6 final dense matrix renders three EnemyStandees at %s" % str(viewport_size))
	for standee in enemy_standees:
		assert_true(not standee.get_global_rect().intersects(hand_rect), "EnemyStandee does not overlap HandRail in Slice 4.6 final dense matrix %s" % str(viewport_size))
	scene.get_parent().queue_free()


func test_battle_scene_slice4_6_drag_preview_remains_inside_viewport() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice46DragPreviewViewport")
	if scene == null:
		return
	var cards: Array = []
	for i in range(10):
		var card := _lost_control_scene_card("slice46_drag_preview_card_%d" % i)
		card.display_name = "Slice 4.6 Drag Preview Card %02d" % i
		cards.append(card)
	scene.start_battle(cards, [], [_enemy("slice46_drag_preview_enemy", "Slice 4.6 Drag Preview Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var rightmost_card := _find_battle_card_view(scene._hand_box.get_child(scene._hand_box.get_child_count() - 1))
	assert_true(rightmost_card != null, "Slice 4.6 drag preview probe finds the rightmost hand card")
	if rightmost_card != null:
		assert_true(not _battle_card_is_disabled(rightmost_card), "Slice 4.6 drag preview probe uses an enabled rightmost hand card")
		var payload: Dictionary = rightmost_card.call("_get_drag_data", Vector2(8, 8))
		assert_true(payload.has("preview_rect"), "BattleCardView drag payload exposes a preview_rect for viewport bounds QA")
		var preview_rect: Rect2 = payload.get("preview_rect", Rect2())
		assert_true(_rect_inside(preview_rect, Rect2(Vector2.ZERO, viewport_size)), "Slice 4.6 drag preview rect stays inside 1280x720 viewport")
	scene.get_parent().queue_free()


func test_battle_scene_slice4_6_battle_finished_payload_unchanged() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var emitted_results: Array = []
	scene.battle_finished.connect(func(result: Dictionary): emitted_results.append(result))
	var reward_card := _layout_probe_card("slice46_payload_reward")
	var active_card := _layout_probe_card("slice46_payload_active")
	var gs = _state()
	gs.sequence = 9
	scene.start_battle([active_card], [], [_enemy("slice46_payload_enemy", "Slice 4.6 Payload Enemy")], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene.call("_on_reward_picked", [reward_card], 0)
	await Engine.get_main_loop().process_frame
	assert_eq(emitted_results.size(), 1, "battle_finished emits exactly once for the Slice 4.6 payload probe")
	if emitted_results.is_empty():
		scene.queue_free()
		return
	var payload: Dictionary = emitted_results[0]
	var keys := _sorted_string_keys(payload)
	assert_eq(keys, [
		"ai_gm_text",
		"base_sequence_exp",
		"brand_drop",
		"contract",
		"outcome",
		"promotion_available",
		"promotion_gate_id",
		"reward_options",
		"selected_card",
		"sequence_exp_delta",
		"weather_pollution_delta",
	], "battle_finished payload keys match the Slice 4.5 victory contract")
	assert_true(typeof(payload.get("outcome")) == TYPE_STRING, "battle_finished outcome remains String")
	assert_true(typeof(payload.get("reward_options")) == TYPE_ARRAY, "battle_finished reward_options remains Array")
	assert_true(payload.get("selected_card") == reward_card, "battle_finished selected_card remains the selected Card reference")
	assert_true(typeof(payload.get("contract")) == TYPE_DICTIONARY, "battle_finished contract remains Dictionary")
	assert_true(typeof(payload.get("weather_pollution_delta")) == TYPE_INT, "battle_finished weather_pollution_delta remains int")
	assert_true(typeof(payload.get("base_sequence_exp")) == TYPE_INT, "battle_finished base_sequence_exp remains int")
	assert_true(typeof(payload.get("sequence_exp_delta")) == TYPE_INT, "battle_finished sequence_exp_delta remains int")
	assert_true(typeof(payload.get("promotion_available")) == TYPE_BOOL, "battle_finished promotion_available remains bool")
	assert_true(typeof(payload.get("promotion_gate_id")) == TYPE_STRING, "battle_finished promotion_gate_id remains String")
	assert_true(typeof(payload.get("ai_gm_text")) == TYPE_STRING, "battle_finished ai_gm_text remains String")
	scene.queue_free()


func test_battle_scene_slice4_7_dense_arena_matrix() -> void:
	for viewport_size in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080)]:
		await _run_slice4_7_dense_arena_matrix_probe(viewport_size)


func _run_slice4_7_dense_arena_matrix_probe(viewport_size: Vector2) -> void:
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice47DenseArena_%dx%d" % [int(viewport_size.x), int(viewport_size.y)])
	if scene == null:
		return
	var cards: Array = []
	for i in range(10):
		var card := _layout_probe_card("slice47_matrix_card_%d_%d" % [int(viewport_size.x), i])
		card.display_name = "Slice 4.7 Matrix Card %02d" % i
		card.energy_cost = i % 4
		cards.append(card)
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("slice47_matrix_enemy_%d_%d" % [int(viewport_size.x), i], "Slice 4.7 Matrix Enemy %d With Long Name" % i)
		enemy.hp = 22 + i
		enemy.max_hp = 46 + i
		enemy.def = 2 + i
		enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
		enemy.add_status("defense_break", {"duration": 2, "magnitude": 2})
		if i == 2:
			enemy.add_status("mirror_seal", {"duration": 1, "stacks": 1})
		enemies.append(enemy)
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_use_debuff", "rule_draw_fate"])
	var player = CombatActorScript.new()
	player.display_name = "Slice 4.7 Matrix Player"
	player.hp = 45
	player.max_hp = 62
	player.def = 5
	player.add_status("ward", {"duration": 3, "magnitude": 6})
	player.add_status("chant_charge", {"duration": 2, "stacks": 2})
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	scene._battle.field_state["adjacent_burn"] = 3
	for i in range(14):
		scene.call("_set_last_action_message", "Slice 4.7 dense matrix log entry %02d with constrained long copy." % i)
	scene.call("_render")
	scene.call("_set_battle_log_drawer_expanded", true)
	var result := {
		"outcome": "victory",
		"reward_options": [cards[0], cards[1], cards[2]],
		"selected_card": cards[1],
		"brand_drop": {"display_name": "Slice 4.7 Matrix Brand Drop"},
		"contract": {"outcome": "partial", "tier": 2, "pollution_delta": 3, "acting_check_base_difficulty": 2, "acting_check_difficulty": 3, "acting_check_weather_modifier": 1},
		"ai_gm_text": "slice 4.7 dense matrix battle narrative expanded",
	}
	scene.call("_show_result_overlay", result, "Slice 4.7 final matrix victory")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	for region_name in ["ArenaTopBar", "ContractChipRail", "TurnCounterChip", "LearnedRuleChipRail", "BattleArenaLayerStack", "BattleAoeDropSurface", "BattleArenaRoot", "PlayerStage", "EnemyStage", "ArenaCenter", "ArenaMessageRibbon", "HandRail", "DrawPileChip", "DiscardPileChip", "EnergyOrb", "EndTurnButton", "BattleLogSideDrawer", "BattleResultOverlay", "BattleNarrativeRail"]:
		var region := _find_control(scene, region_name)
		assert_true(region != null and region.is_visible_in_tree(), "%s is visible in Slice 4.7 dense matrix %s" % [region_name, str(viewport_size)])
		if region != null:
			var rect := region.get_global_rect()
			assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has non-zero rect in Slice 4.7 dense matrix %s" % [region_name, str(viewport_size)])
			assert_true(_rect_inside(rect, bounds), "%s stays inside Slice 4.7 dense matrix viewport %s" % [region_name, str(viewport_size)])
	var arena_top_bar := _find_control(scene, "ArenaTopBar")
	assert_true(arena_top_bar != null and arena_top_bar.get_global_rect().position.y < 60.0, "ArenaTopBar stays at the top of Slice 4.7 dense matrix %s" % str(viewport_size))
	var arena_center := _find_control(scene, "ArenaCenter")
	if arena_center != null:
		assert_true(arena_center.get_global_rect().size.x <= 240.0, "ArenaCenter empty band is <= 240px in Slice 4.7 dense matrix %s" % str(viewport_size))
	var player_stage := _find_control(scene, "PlayerStage")
	var enemy_stage := _find_control(scene, "EnemyStage")
	if player_stage != null and enemy_stage != null:
		var gap := enemy_stage.get_global_rect().position.x - player_stage.get_global_rect().end.x
		assert_true(gap <= 240.0, "PlayerStage-to-EnemyStage empty band is <= 240px in Slice 4.7 dense matrix %s" % str(viewport_size))
	var drawer := _find_control(scene, "BattleLogSideDrawer")
	assert_true(drawer != null and drawer.get_global_rect().size.x >= 240.0, "BattleLogSideDrawer is expanded in Slice 4.7 dense matrix %s" % str(viewport_size))
	if drawer != null:
		var right_blank := viewport_size.x - drawer.get_global_rect().end.x
		assert_true(right_blank <= viewport_size.x * 0.08, "BattleLogSideDrawer stays near the right viewport edge in Slice 4.7 dense matrix %s" % str(viewport_size))
		var last_enemy_right := 0.0
		var first_enemy_left := INF
		for enemy_child in scene._enemy_box.get_children():
			if enemy_child is Control:
				var enemy_rect := (enemy_child as Control).get_global_rect()
				first_enemy_left = minf(first_enemy_left, enemy_rect.position.x)
				last_enemy_right = maxf(last_enemy_right, enemy_rect.end.x)
		var enemy_to_log_blank := drawer.get_global_rect().position.x - last_enemy_right
		var max_visual_gap := minf(180.0, viewport_size.x * 0.12)
		assert_true(enemy_to_log_blank >= 0.0, "Enemy row does not sit under the right log drawer in Slice 4.7 dense matrix %s" % str(viewport_size))
		assert_true(enemy_to_log_blank <= max_visual_gap, "Enemy row stays visually connected to the right log drawer in Slice 4.7 dense matrix %s" % str(viewport_size))
		if enemy_stage != null and first_enemy_left < INF:
			var enemy_left_gap := first_enemy_left - enemy_stage.get_global_rect().position.x
			assert_true(enemy_left_gap <= max_visual_gap, "Enemy row stays visually connected to the center arena in Slice 4.7 dense matrix %s" % str(viewport_size))
	scene.call("_open_card_peek", cards[0])
	await Engine.get_main_loop().process_frame
	var peek_panel := _find_control(scene, "CardPeekPanel")
	var peek_content := _find_control(scene, "CardPeekContent")
	assert_true(peek_panel != null and peek_panel.visible, "CardPeekPanel can open from the Slice 4.7 dense matrix %s" % str(viewport_size))
	assert_true(peek_content != null and _rect_inside(peek_content.get_global_rect(), bounds), "CardPeekPanel ready slot stays inside viewport %s" % str(viewport_size))
	if peek_panel != null:
		peek_panel.hide()
	scene.call("_show_pile_inspect_panel", "Draw Pile", cards.slice(0, 3))
	await Engine.get_main_loop().process_frame
	var pile_panel := _find_control(scene, "PileInspectPanel")
	var pile_content := _find_control(scene, "PileInspectContent")
	assert_true(pile_panel != null and pile_panel.visible, "PileInspectPanel can open from the Slice 4.7 dense matrix %s" % str(viewport_size))
	assert_true(pile_content != null and _rect_inside(pile_content.get_global_rect(), bounds), "PileInspectPanel ready slot stays inside viewport %s" % str(viewport_size))
	scene.get_parent().queue_free()


func test_battle_scene_slice4_7_drag_preview_remains_inside_viewport() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice47DragPreviewViewport")
	if scene == null:
		return
	var cards: Array = []
	for i in range(10):
		var card := _lost_control_scene_card("slice47_drag_preview_card_%d" % i)
		card.display_name = "Slice 4.7 Drag Preview Card %02d" % i
		cards.append(card)
	var enemies := [
		_enemy("slice47_drag_preview_enemy_0", "Slice 4.7 Drag Preview Enemy 0"),
		_enemy("slice47_drag_preview_enemy_1", "Slice 4.7 Drag Preview Enemy 1"),
		_enemy("slice47_drag_preview_enemy_2", "Slice 4.7 Drag Preview Enemy 2"),
	]
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_draw_fate"] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var rightmost_card := _find_battle_card_view(scene._hand_box.get_child(scene._hand_box.get_child_count() - 1))
	assert_true(rightmost_card != null, "Slice 4.7 drag preview probe finds the rightmost hand card")
	if rightmost_card != null:
		assert_true(not _battle_card_is_disabled(rightmost_card), "Slice 4.7 drag preview probe uses an enabled rightmost hand card")
		var payload: Dictionary = rightmost_card.call("_get_drag_data", Vector2(8, 8))
		assert_true(payload.has("preview_rect"), "Slice 4.7 BattleCardView drag payload exposes a preview_rect")
		var preview_rect: Rect2 = payload.get("preview_rect", Rect2())
		assert_true(_rect_inside(preview_rect, Rect2(Vector2.ZERO, viewport_size)), "Slice 4.7 drag preview rect stays inside 1280x720 viewport")
	scene.get_parent().queue_free()


func test_battle_scene_slice4_7_battle_finished_payload_unchanged() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var emitted_results: Array = []
	scene.battle_finished.connect(func(result: Dictionary): emitted_results.append(result))
	var reward_card := _layout_probe_card("slice47_payload_reward")
	var active_card := _layout_probe_card("slice47_payload_active")
	var gs = _state()
	gs.sequence = 9
	scene.start_battle([active_card], [], [_enemy("slice47_payload_enemy", "Slice 4.7 Payload Enemy")], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene.call("_on_reward_picked", [reward_card], 0)
	await Engine.get_main_loop().process_frame
	assert_eq(emitted_results.size(), 1, "battle_finished emits exactly once for the Slice 4.7 payload probe")
	if emitted_results.is_empty():
		scene.queue_free()
		return
	var payload: Dictionary = emitted_results[0]
	var keys := _sorted_string_keys(payload)
	assert_eq(keys, [
		"ai_gm_text",
		"base_sequence_exp",
		"brand_drop",
		"contract",
		"outcome",
		"promotion_available",
		"promotion_gate_id",
		"reward_options",
		"selected_card",
		"sequence_exp_delta",
		"weather_pollution_delta",
	], "battle_finished payload keys still match the Slice 4.5/4.6 victory contract in Slice 4.7")
	assert_true(typeof(payload.get("outcome")) == TYPE_STRING, "Slice 4.7 battle_finished outcome remains String")
	assert_true(typeof(payload.get("reward_options")) == TYPE_ARRAY, "Slice 4.7 battle_finished reward_options remains Array")
	assert_true(payload.get("selected_card") == reward_card, "Slice 4.7 battle_finished selected_card remains the selected Card reference")
	assert_true(typeof(payload.get("contract")) == TYPE_DICTIONARY, "Slice 4.7 battle_finished contract remains Dictionary")
	assert_true(typeof(payload.get("weather_pollution_delta")) == TYPE_INT, "Slice 4.7 battle_finished weather_pollution_delta remains int")
	assert_true(typeof(payload.get("base_sequence_exp")) == TYPE_INT, "Slice 4.7 battle_finished base_sequence_exp remains int")
	assert_true(typeof(payload.get("sequence_exp_delta")) == TYPE_INT, "Slice 4.7 battle_finished sequence_exp_delta remains int")
	assert_true(typeof(payload.get("promotion_available")) == TYPE_BOOL, "Slice 4.7 battle_finished promotion_available remains bool")
	assert_true(typeof(payload.get("promotion_gate_id")) == TYPE_STRING, "Slice 4.7 battle_finished promotion_gate_id remains String")
	assert_true(typeof(payload.get("ai_gm_text")) == TYPE_STRING, "Slice 4.7 battle_finished ai_gm_text remains String")
	scene.queue_free()


func test_battle_scene_slice4_7_no_mouse_target_buttons_visible_in_default_arena() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleSlice47T7NoMouseTargetButtonsViewport")
	if scene == null:
		return
	var enemies := [
		_enemy("slice47_t7_no_button_enemy_0", "Slice 4.7 T7 Enemy 0"),
		_enemy("slice47_t7_no_button_enemy_1", "Slice 4.7 T7 Enemy 1"),
		_enemy("slice47_t7_no_button_enemy_2", "Slice 4.7 T7 Enemy 2"),
	]
	scene.start_battle([_layout_probe_card("slice47_t7_no_button_card")], [], enemies, [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var target_buttons := _find_named_controls(scene, "TargetButton")
	assert_eq(target_buttons.size(), 3, "EnemyStandees keep target controls available for non-mouse fallback")
	var visible_target_buttons := 0
	for button in target_buttons:
		if button.is_visible_in_tree():
			visible_target_buttons += 1
	assert_eq(visible_target_buttons, 0, "default mouse arena shows no EnemyStandee target buttons")
	scene.get_parent().queue_free()


func test_battle_scene_slice4_7_top_bar_chips_do_not_truncate_at_1280() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleSlice47T7TopBarChipViewport")
	if scene == null:
		return
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_shadow_takes_hit", "rule_draw_fate"])
	scene.start_battle(
		[_layout_probe_card("slice47_t7_chip_card")],
		[],
		[_enemy("slice47_t7_chip_enemy", "Slice 4.7 T7 Chip Enemy")],
		["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String],
		null,
		gs
	)
	await Engine.get_main_loop().process_frame
	var top_bar := _find_control(scene, "ArenaTopBar")
	assert_true(top_bar != null, "ArenaTopBar exists for T7 chip truncation probe")
	var chip_labels: Array[Label] = []
	for rail_name in ["ContractChipRail", "LearnedRuleChipRail"]:
		var rail := _find_control(top_bar, rail_name) if top_bar != null else null
		assert_true(rail != null, "%s exists for T7 chip truncation probe" % rail_name)
		if rail != null:
			for chip in rail.get_children():
				var label = chip.find_child("ChipLabel", true, false)
				if label is Label:
					chip_labels.append(label as Label)
	assert_eq(chip_labels.size(), 2, "ArenaTopBar renders one contract summary chip and one learned-rule summary chip at 1280x720")
	var all_chip_text := ""
	for label in chip_labels:
		all_chip_text += "%s\n" % label.text
		assert_true(not label.text.contains("..."), "ArenaTopBar chip source text never contains ellipsis")
		assert_true(not label.clip_text, "ArenaTopBar chip label does not clip text")
		assert_true(label.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS, "ArenaTopBar chip label does not use ellipsis overrun")
		assert_true(label.get_global_rect().size.x + 0.5 >= label.get_combined_minimum_size().x, "ArenaTopBar chip label has enough visible width for its full text")
	assert_true(all_chip_text.contains("\u626e\u6f14\u5b88\u5219"), "ArenaTopBar has a single acting-rule summary chip")
	assert_true(all_chip_text.contains("\u9886\u609f\u89c4\u5219"), "ArenaTopBar has a single learned-rule summary chip")
	var detail := _find_control(top_bar, "ArenaRuleDetailLabel") if top_bar != null else null
	var detail_text := _collect_label_text(detail) if detail != null else ""
	for expected_text in [
		str(scene.call("_rule_label_text", "rule_use_debuff")),
		str(scene.call("_rule_label_text", "rule_no_consecutive_attack")),
		str(scene.call("_rule_label_text", "rule_shadow_takes_hit")),
		str(scene.call("_rule_label_text", "rule_draw_fate")),
	]:
		assert_true(detail_text.contains(expected_text), "ArenaRuleDetailLabel carries detailed text for %s instead of duplicating chips" % expected_text)
	scene.get_parent().queue_free()


func test_battle_scene_slice4_7_top_bar_contracts_are_interpreted_in_chinese() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleSlice47ContractInterpretationViewport")
	if scene == null:
		return
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_draw_fate"])
	scene.start_battle(
		[_layout_probe_card("slice47_contract_interpret_card")],
		[],
		[_enemy("slice47_contract_interpret_enemy", "Slice 4.7 Contract Enemy")],
		["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String],
		null,
		gs
	)
	await Engine.get_main_loop().process_frame
	var top_bar := _find_control(scene, "ArenaTopBar")
	assert_true(top_bar != null, "ArenaTopBar exists for contract interpretation")
	if top_bar != null:
		var contract_rail := _find_control(top_bar, "ContractChipRail")
		var learned_rail := _find_control(top_bar, "LearnedRuleChipRail")
		var turn_chip := _find_control(top_bar, "TurnCounterChip")
		var contract_text := _collect_label_text(contract_rail) if contract_rail != null else ""
		var learned_text := _collect_label_text(learned_rail) if learned_rail != null else ""
		var turn_text := _collect_label_text(turn_chip) if turn_chip != null else ""
		var detail := _find_control(top_bar, "ArenaRuleDetailLabel")
		var detail_text := _collect_label_text(detail) if detail != null else ""
		assert_true(contract_text.contains("\u626e\u6f14\u5b88\u5219"), "Contract rail uses one acting-rule summary chip")
		assert_true(learned_text.contains("\u9886\u609f\u89c4\u5219"), "Learned rail uses one learned-rule summary chip")
		assert_true(detail_text.contains(str(scene.call("_rule_label_text", "rule_use_debuff"))), "Rule detail uses the full interpreted debuff-rule text")
		assert_true(detail_text.contains(str(scene.call("_rule_label_text", "rule_no_consecutive_attack"))), "Rule detail uses the full interpreted no-repeat-attack text")
		assert_true(detail_text.contains(str(scene.call("_rule_label_text", "rule_draw_fate"))), "Rule detail uses the full interpreted fate-rule text")
		assert_true(turn_text.contains("回合") and not turn_text.contains("Turn"), "Turn chip is localized instead of code-like English")
		for raw in ["rule_use_debuff", "rule_no_consecutive_attack", "rule_draw_fate"]:
			assert_true(not contract_text.contains(raw) and not learned_text.contains(raw) and not detail_text.contains(raw), "ArenaTopBar hides raw rule id %s" % raw)
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_scene_top_bar_shows_visible_contract_rule_detail() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice47RuleDetailViewport")
	if scene == null:
		return
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_draw_fate"])
	scene.start_battle(
		[_layout_probe_card("slice47_rule_detail_card")],
		[],
		[_enemy("slice47_rule_detail_enemy", "Slice 4.7 Rule Detail Enemy")],
		["shadow_silence", "rule_use_debuff"] as Array[String],
		null,
		gs
	)
	await Engine.get_main_loop().process_frame
	var detail := _find_control(scene, "ArenaRuleDetailLabel")
	assert_true(detail is Label and detail.is_visible_in_tree(), "ArenaTopBar exposes a visible rule detail label, not tooltip-only copy")
	if detail is Label:
		var text := str((detail as Label).text)
		assert_true(text.contains("\u89c4\u5219\u89e3\u8bfb"), "rule detail label has an explicit interpretation heading")
		assert_true(text.contains("\u626e\u6f14\u5b88\u5219"), "rule detail label names the acting-rule section")
		assert_true(text.contains(str(scene.call("_rule_label_text", "shadow_silence"))), "rule detail label explains shadow_silence with the interpreted contract text")
		assert_true(text.contains("\u505a\u6cd5"), "rule detail label includes a concrete how-to interpretation")
		assert_true(text.contains(str(scene.call("_rule_label_text", "rule_draw_fate"))), "rule detail label includes learned-rule detail when learned rules exist")
		for raw in ["shadow_silence", "rule_use_debuff", "rule_draw_fate", "{", "}"]:
			assert_true(not text.contains(raw), "rule detail label hides raw rule token %s" % raw)
		assert_true(_rect_inside((detail as Label).get_global_rect(), Rect2(Vector2.ZERO, viewport_size)), "rule detail label stays inside 1280x720 viewport")
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_scene_top_bar_uses_single_contract_summary_with_rule_detail_slot() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleSlice47RuleSummaryViewport")
	if scene == null:
		return
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_draw_fate"])
	scene.start_battle(
		[_layout_probe_card("slice47_rule_summary_card")],
		[],
		[_enemy("slice47_rule_summary_enemy", "Slice 4.7 Rule Summary Enemy")],
		["rule_use_debuff", "owner_unmapped_contract_probe"] as Array[String],
		null,
		gs
	)
	await Engine.get_main_loop().process_frame
	var top_bar := _find_control(scene, "ArenaTopBar")
	assert_true(top_bar != null, "ArenaTopBar exists for single-summary rule probe")
	if top_bar != null:
		var contract_rail := _find_control(top_bar, "ContractChipRail")
		assert_true(contract_rail != null, "ContractChipRail exists for single-summary rule probe")
		if contract_rail != null:
			assert_eq(contract_rail.get_child_count(), 1, "ContractChipRail renders exactly one acting-rule summary chip")
			var contract_text := _collect_label_text(contract_rail)
			assert_true(contract_text.contains("\u626e\u6f14\u5b88\u5219"), "single contract summary chip is labeled as acting rules")
			assert_true(contract_text.contains("2"), "single contract summary chip shows how many acting rules are active")
			assert_true(not contract_text.contains(str(scene.call("_rule_label_text", "rule_use_debuff"))), "individual contract names move out of the top chip row")
		var detail := _find_control(top_bar, "ArenaRuleDetailLabel")
		assert_true(detail is Label and detail.is_visible_in_tree(), "ArenaRuleDetailLabel is the visible detail slot")
		if detail is Label:
			var text := str((detail as Label).text)
			assert_true(text.contains("\u89c4\u5219\u89e3\u8bfb"), "detail slot visibly announces rule interpretation")
			assert_true(text.contains(str(scene.call("_rule_label_text", "rule_use_debuff"))), "detail slot includes the known acting-rule name")
			assert_true(text.contains("\u89e3\u8bfb\u5f85\u8865"), "detail slot shows a placeholder when a rule has no authored interpretation yet")
			assert_true(not text.contains("owner_unmapped_contract_probe"), "detail slot hides raw unmapped rule ids")
			assert_true(_rect_inside((detail as Label).get_global_rect(), Rect2(Vector2.ZERO, viewport_size)), "detail slot stays inside 1280x720 viewport")
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_scene_top_bar_does_not_repeat_contract_rules_as_learned_rules() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleSlice47DuplicateRuleViewport")
	if scene == null:
		return
	var gs = _state()
	_replace_string_array(gs.learned_rules, ["rule_use_debuff", "rule_draw_fate"])
	scene.start_battle(
		[_layout_probe_card("slice47_duplicate_rule_card")],
		[],
		[_enemy("slice47_duplicate_rule_enemy", "Slice 4.7 Duplicate Rule Enemy")],
		["rule_use_debuff"] as Array[String],
		null,
		gs
	)
	await Engine.get_main_loop().process_frame
	var top_bar := _find_control(scene, "ArenaTopBar")
	assert_true(top_bar != null, "ArenaTopBar exists for duplicate-rule filtering")
	if top_bar != null:
		var detail := _find_control(top_bar, "ArenaRuleDetailLabel")
		var text := _collect_label_text(detail) if detail != null else ""
		var debuff_label := str(scene.call("_rule_label_text", "rule_use_debuff"))
		assert_eq(text.count(debuff_label), 1, "ArenaTopBar shows a contract rule once even if it is also learned")
		assert_true(text.contains(str(scene.call("_rule_label_text", "rule_draw_fate"))), "ArenaTopBar still shows learned rules that are not active contracts")
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_scene_slice4_7_enemy_stage_right_blank_is_tight_at_1280() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleSlice47EnemyRightBlankViewport")
	if scene == null:
		return
	var enemies := [
		_enemy("slice47_right_blank_enemy_0", "Right Blank Enemy 0"),
		_enemy("slice47_right_blank_enemy_1", "Right Blank Enemy 1"),
		_enemy("slice47_right_blank_enemy_2", "Right Blank Enemy 2"),
	]
	scene.start_battle([_layout_probe_card("slice47_right_blank_card")], [], enemies, [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var enemy_stage := _find_control(scene, "EnemyStage")
	var drawer := _find_control(scene, "BattleLogSideDrawer")
	assert_true(enemy_stage != null, "EnemyStage exists for right blank measurement")
	assert_true(drawer != null, "BattleLogSideDrawer exists for right blank measurement")
	if enemy_stage != null and drawer != null:
		var right_limit := drawer.get_global_rect().position.x
		var last_enemy_right := enemy_stage.get_global_rect().position.x
		var drawer_rect := drawer.get_global_rect()
		for child in scene._enemy_box.get_children():
			if child is Control:
				var child_rect := (child as Control).get_global_rect()
				last_enemy_right = maxf(last_enemy_right, child_rect.end.x)
				assert_true(not child_rect.intersects(drawer_rect), "Enemy standee does not overlap the expanded right drawer at 1280x720")
		var blank_width := right_limit - last_enemy_right
		assert_true(blank_width >= 0.0, "EnemyStage leaves no negative overlap strip before the right drawer at 1280x720")
		assert_true(blank_width <= 96.0, "EnemyStage leaves at most 96px of blank strip before the right drawer at 1280x720")
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_scene_slice4_7_screenshot_hand_cards_use_clean_repeated_name() -> void:
	var capture_path := ProjectSettings.globalize_path("res://../output/qa/slice4_7/capture_battle_screens.gd")
	var capture_source := FileAccess.get_file_as_string(capture_path)
	assert_true(capture_source != "", "Slice 4.7 screenshot capture script is readable")
	assert_true(capture_source.contains("\"display_name\": \"Slice 4.7 screenshot\""), "screenshot fixture cards use the clean repeated display name")
	assert_true(not capture_source.contains("Slice 4.7 Capture Card"), "screenshot fixture no longer uses noisy unique capture card names")
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleSlice47T7ScreenshotNameViewport")
	if scene == null:
		return
	var cards: Array = []
	for i in range(10):
		var card := _layout_probe_card("slice47_t7_screenshot_name_%d" % i)
		card.display_name = "Slice 4.7 screenshot"
		card.energy_cost = i % 4
		cards.append(card)
	scene.start_battle(cards, [], [_enemy("slice47_t7_screenshot_name_enemy", "Slice 4.7 T7 Screenshot Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	for i in range(6):
		var card_view := _find_battle_card_view(scene._hand_box.get_child(i))
		assert_true(card_view != null, "screenshot hand card %d renders a BattleCardView" % i)
		if card_view != null:
			var name_label = card_view.find_child("NameLabel", true, false)
			assert_true(name_label is Label, "screenshot hand card %d exposes a name label" % i)
			if name_label is Label:
				assert_eq((name_label as Label).text, "Slice 4.7 screenshot", "screenshot hand card %d uses the clean repeated card name" % i)
	scene.get_parent().queue_free()


func _run_slice4_6_dense_presentation_probe(viewport_size: Vector2) -> void:
	var viewport := Control.new()
	viewport.name = "BattleSlice46DenseMatrixViewport_%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
	viewport.position = Vector2.ZERO
	viewport.size = viewport_size
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for Slice 4.6 dense matrix %s" % str(viewport_size))
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(10):
		var card := _layout_probe_card("slice46_matrix_card_%d_%d" % [int(viewport_size.x), i])
		card.display_name = "Slice 4.6 Matrix Card %02d" % i
		card.energy_cost = i % 4
		cards.append(card)
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("slice46_matrix_enemy_%d_%d" % [int(viewport_size.x), i], "Slice 4.6 Matrix Enemy %d With Long Name" % i)
		enemy.hp = 18 + i
		enemy.max_hp = 42 + i
		enemy.def = 2 + i
		enemy.add_status("weak", {"duration": 2, "magnitude": 1})
		enemy.add_status("vulnerable", {"duration": 2, "magnitude": 2})
		enemy.add_status("burn", {"duration": 2, "magnitude": 3})
		enemy.add_marker("paper_doll_marker", 1 + i)
		if i == 2:
			enemy.add_status("obscure_intent", {"duration": 1})
		enemies.append(enemy)
	var gs = _state()
	var rules: Array[String] = [
		"rule_use_debuff",
		"rule_no_consecutive_attack",
		"rule_draw_fate",
		"rule_no_light_element",
		"rule_shadow_takes_hit",
	]
	gs.learned_rules = rules
	var player = CombatActorScript.new()
	player.display_name = "Slice 4.6 Matrix Player"
	player.hp = 44
	player.max_hp = 60
	player.def = 4
	player.add_status("fear", {"duration": 2})
	player.add_status("damage_reduction", {"duration": 2, "magnitude": 3})
	player.add_marker("paper_doll_marker", 3)
	scene.start_battle(cards, [], enemies, [
		"rule_use_debuff",
		"rule_no_consecutive_attack",
		"rule_draw_fate",
	] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	scene._battle.field_state["adjacent_burn"] = 3
	for i in range(12):
		scene.call("_set_last_action_message", "Slice 4.6 dense matrix log entry %02d with long battle feedback copy." % i)
	scene._selected_card = cards[0]
	scene.call("_render")
	var result := {
		"outcome": "victory",
		"reward_options": [cards[0], cards[1], cards[2]],
		"selected_card": cards[1],
		"brand_drop": {"display_name": "Slice 4.6 Matrix Brand Drop"},
		"contract": {"outcome": "broken", "tier": 2, "pollution_delta": 5, "acting_check_base_difficulty": 2, "acting_check_difficulty": 2, "acting_check_weather_modifier": -1},
		"ai_gm_text": "slice 4.6 matrix visible battle narrative",
	}
	scene.call("_show_result_overlay", result, "胜利｜契约：破契（污染 +5，判定 2 (-1)）")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport_size)
	var hand_fan := _find_control(scene, "HandRail")
	var hand_scroll := _find_control(scene, "HandScroll")
	var end_turn := _find_control(scene, "EndTurnButton")
	assert_true(hand_fan != null and _rect_inside(hand_fan.get_global_rect(), bounds), "Slice 4.6 dense matrix HandRail stays inside %s" % str(viewport_size))
	assert_true(hand_scroll != null and _rect_inside(hand_scroll.get_global_rect(), bounds), "Slice 4.6 dense matrix HandScroll stays inside %s" % str(viewport_size))
	assert_true(end_turn != null and _rect_inside(end_turn.get_global_rect(), bounds), "Slice 4.6 dense matrix EndTurnButton stays inside %s" % str(viewport_size))
	var hand_rect := hand_fan.get_global_rect() if hand_fan != null else Rect2()
	var end_rect := end_turn.get_global_rect() if end_turn != null else Rect2()
	for region_name in ["BattleArenaLayerStack", "BattleAoeDropSurface", "BattleArenaRoot", "PlayerStage", "ArenaCenter", "ArenaMessageRibbon", "EnemyStage", "HandRail", "DrawPileChip", "DiscardPileChip", "EnergyOrb", "BattleLogSideDrawer", "BattleResultOverlay", "BattleNarrativeRail"]:
		var region := _find_control(scene, region_name)
		assert_true(region != null and region.is_visible_in_tree(), "%s is visible in Slice 4.6 dense matrix %s" % [region_name, str(viewport_size)])
		if region != null:
			var rect := region.get_global_rect()
			assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "%s has non-zero layout size in Slice 4.6 dense matrix %s" % [region_name, str(viewport_size)])
			assert_true(_rect_inside(rect, bounds), "%s stays inside Slice 4.6 dense matrix viewport %s" % [region_name, str(viewport_size)])
	for text_region_name in ["EnemyStage", "ArenaMessageRibbon", "BattleLogSideDrawer"]:
		var text_region := _find_control(scene, text_region_name)
		if text_region != null:
			var text_rect := text_region.get_global_rect()
			assert_true(not text_rect.intersects(hand_rect), "%s does not overlap HandRail in Slice 4.6 dense matrix %s" % [text_region_name, str(viewport_size)])
			assert_true(not text_rect.intersects(end_rect), "%s does not overlap EndTurnButton in Slice 4.6 dense matrix %s" % [text_region_name, str(viewport_size)])
	assert_eq(scene._hand_box.get_child_count(), 10, "Slice 4.6 dense matrix renders ten hand cards at %s" % str(viewport_size))
	assert_eq(scene._enemy_box.get_child_count(), 3, "Slice 4.6 dense matrix renders three enemy slots at %s" % str(viewport_size))
	var narrative_rail := _find_control(scene, "BattleNarrativeRail")
	var narrative_text := _collect_label_text(narrative_rail) if narrative_rail != null else ""
	assert_true(narrative_text.contains("slice 4.6 matrix visible battle narrative"), "Slice 4.6 dense matrix keeps AI GM narrative visible at %s" % str(viewport_size))
	var overlay_text := _collect_label_text(_find_control(scene, "BattleResultOverlay"))
	assert_true(overlay_text.contains("Slice 4.6 Matrix Card 01") and overlay_text.contains("Slice 4.6 Matrix Brand Drop"), "Slice 4.6 dense matrix result overlay shows reward and drop text at %s" % str(viewport_size))
	viewport.queue_free()


func test_battle_scene_three_enemy_stage_fits_1280x720() -> void:
	var viewport := Control.new()
	viewport.name = "BattleThreeEnemyStageViewport"
	viewport.position = Vector2.ZERO
	viewport.size = Vector2(1280, 720)
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for three-enemy stage test")
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(7):
		cards.append(_layout_probe_card("three_enemy_stage_card_%d" % i))
	var enemies: Array = []
	for i in range(3):
		var enemy = _enemy("three_enemy_stage_%d" % i, "Very Long Enemy Stage Name Probe %d With Status Text" % i)
		enemy.hp = 14 + i
		enemy.max_hp = 28 + i
		enemy.def = 2 + i
		enemy.add_status("weak", {"duration": 2, "magnitude": 1})
		enemy.add_status("vulnerable", {"duration": 1, "magnitude": 2})
		if i == 1:
			enemy.add_status("obscure_intent", {"duration": 1})
		enemy.add_marker("paper_doll_marker", 2 + i)
		enemies.append(enemy)
	scene.start_battle(cards, [], enemies, [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.hand = cards
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport.size)
	var enemy_stage := _find_control(scene, "EnemyStage")
	var hand_fan := _find_control(scene, "HandRail")
	assert_true(enemy_stage != null, "three-enemy battle renders EnemyStage")
	assert_true(hand_fan != null, "three-enemy battle renders HandRail")
	assert_eq(scene._enemy_box.get_child_count(), 3, "three-enemy battle renders three enemy stage slots")
	if enemy_stage != null and hand_fan != null:
		var enemy_stage_rect := enemy_stage.get_global_rect()
		var hand_rect := hand_fan.get_global_rect()
		assert_true(_rect_inside(enemy_stage_rect, bounds), "three-enemy EnemyStage stays inside 1280x720 viewport")
		assert_true(_rect_inside(hand_rect, bounds), "three-enemy HandRail stays inside 1280x720 viewport")
		assert_true(not enemy_stage_rect.intersects(hand_rect), "three-enemy EnemyStage does not overlap HandRail")
		for child in scene._enemy_box.get_children():
			if child is Control:
				var slot_rect := (child as Control).get_global_rect()
				assert_true(_rect_inside(slot_rect, enemy_stage_rect), "enemy stage slot stays inside EnemyStage")
				assert_true(not slot_rect.intersects(hand_rect), "enemy stage slot does not overlap the hand")
				assert_true((child as Control).find_child("NameLabel", true, false) is Label, "enemy standee exposes NameLabel")
				assert_true((child as Control).find_child("IntentFloater", true, false) is Label, "enemy standee exposes IntentFloater")
	viewport.queue_free()


func test_battle_scene_selection_state_is_visible() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var card = _card("selection_state_probe", 0, [], ["attack"])
	card.display_name = "Selection State Probe"
	var enemy_a = _enemy("selection_target_a", "Selection Target A")
	var enemy_b = _enemy("selection_target_b", "Selection Target B")
	scene.start_battle([card], [], [enemy_a, enemy_b], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene.call("_on_card_pressed", card)
	await Engine.get_main_loop().process_frame
	var selected_rail = _find_control(scene, "ArenaMessageRibbon")
	var selected_text := _collect_label_text(selected_rail) if selected_rail != null else ""
	assert_true(selected_rail is Control and (selected_rail as Control).is_visible_in_tree(), "battle scene shows selected-card state in ArenaMessageRibbon")
	assert_true(selected_text.contains("Selection State Probe"), "ArenaMessageRibbon names the selected card")
	var valid_slots := 0
	for child in scene._enemy_box.get_children():
		if child is Control:
			assert_true((child as Control).has_meta("valid_target"), "enemy slot exposes valid-target state")
			assert_true((child as Control).has_meta("selected_target"), "enemy slot exposes selected-target state")
			if bool((child as Control).get_meta("valid_target", false)):
				valid_slots += 1
			var target_button = (child as Control).find_child("TargetButton", true, false)
			assert_true(target_button is Button and not (target_button as Button).disabled, "valid enemy target remains actionable")
	assert_eq(valid_slots, 2, "all live enemy slots are valid targets after selecting a single-target card")
	scene.queue_free()


func test_battle_scene_full_hand_keeps_cards_inside_1280x720() -> void:
	var viewport := Control.new()
	viewport.name = "BattleFullHandLayoutViewport"
	viewport.position = Vector2.ZERO
	viewport.size = Vector2(1280, 720)
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for full-hand layout test")
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(10):
		cards.append(_layout_probe_card("full_hand_layout_probe_%d" % i))
	scene.start_battle(cards, [], [_enemy("full_hand_enemy", "Full Hand Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.hand = cards
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport.size)
	var hand_scroll = scene.find_child("HandScroll", true, false)
	assert_true(hand_scroll is ScrollContainer, "full-hand battle keeps the hand in a scroll container")
	if hand_scroll is Control:
		assert_true(_rect_inside((hand_scroll as Control).get_global_rect(), bounds), "full-hand hand scroll stays inside 1280x720 viewport")
	assert_true(_rect_inside(scene._hand_box.get_global_rect(), bounds), "full-hand hand row stays inside 1280x720 viewport")
	for child in scene._hand_box.get_children():
		if child is Control:
			assert_true(_rect_inside((child as Control).get_global_rect(), bounds), "full-hand card button stays inside 1280x720 viewport")
	assert_true(_rect_inside(scene._end_turn_button.get_global_rect(), bounds), "full-hand end-turn button stays inside 1280x720 viewport")
	viewport.queue_free()


func test_battle_scene_battle_log_stays_scroll_constrained() -> void:
	var viewport := Control.new()
	viewport.name = "BattleLogLayoutViewport"
	viewport.position = Vector2.ZERO
	viewport.size = Vector2(1280, 720)
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var packed = load(SCENE_PATH)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle scene instantiates for battle log layout test")
		viewport.queue_free()
		return
	var scene = packed.instantiate()
	viewport.add_child(scene)
	await Engine.get_main_loop().process_frame
	var cards: Array = []
	for i in range(5):
		cards.append(_layout_probe_card("log_layout_probe_%d" % i))
	scene.start_battle(cards, [], [], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	for i in range(12):
		scene.call("_set_last_action_message", "日志条目 %02d：这是一条较长的战斗结果，用于验证日志不会把底部控件顶出屏幕。" % i)
	await Engine.get_main_loop().process_frame
	var bounds := Rect2(Vector2.ZERO, viewport.size)
	var log_panel = scene.find_child("BattleLog", true, false)
	var log_scroll = scene.find_child("BattleLogScroll", true, false)
	assert_true(log_scroll != null and log_scroll is ScrollContainer, "battle log uses a scroll container for long history")
	if log_panel is Control:
		assert_true(_rect_inside((log_panel as Control).get_global_rect(), bounds), "battle log panel stays inside 1280x720 viewport")
	assert_true(_rect_inside(scene._hand_box.get_global_rect(), bounds), "battle hand row stays visible with long battle log")
	assert_true(_rect_inside(scene._end_turn_button.get_global_rect(), bounds), "battle end-turn button stays visible with long battle log")
	var log_text := _collect_label_text(scene)
	assert_true(log_text.contains("日志条目 11"), "battle log keeps the latest long entry visible")
	viewport.queue_free()


func test_battle_scene_draw_pile_chip_shows_count_at_bottom_left() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleDrawPileChipViewport")
	if scene == null:
		return
	var cards: Array = []
	for i in range(8):
		cards.append(_layout_probe_card("draw_pile_chip_probe_%d" % i))
	scene.start_battle(cards, [], [_enemy("draw_chip_enemy", "Draw Chip Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var chip := _find_control(scene, "DrawPileChip")
	assert_true(chip != null, "DrawPileChip exists")
	if chip != null:
		var rect := chip.get_global_rect()
		assert_true(rect.get_center().x < viewport_size.x * 0.5, "DrawPileChip is positioned in the bottom-left half")
		assert_true(rect.get_center().y > viewport_size.y * 0.75, "DrawPileChip is anchored in the bottom band")
		assert_true(_collect_label_text(chip).contains(str(scene._battle.draw_pile.size())), "DrawPileChip shows the current draw-pile count")
	scene.get_parent().queue_free()


func test_battle_scene_discard_pile_chip_shows_count_at_bottom_right() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleDiscardPileChipViewport")
	if scene == null:
		return
	var cards: Array = []
	for i in range(8):
		cards.append(_layout_probe_card("discard_pile_chip_probe_%d" % i))
	scene.start_battle(cards, [], [_enemy("discard_chip_enemy", "Discard Chip Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var chip := _find_control(scene, "DiscardPileChip")
	assert_true(chip != null, "DiscardPileChip exists")
	if chip != null:
		var rect := chip.get_global_rect()
		assert_true(rect.get_center().x > viewport_size.x * 0.5, "DiscardPileChip is positioned in the bottom-right half")
		assert_true(rect.get_center().y > viewport_size.y * 0.75, "DiscardPileChip is anchored in the bottom band")
		assert_true(_collect_label_text(chip).contains(str(scene._battle.discard_pile.size())), "DiscardPileChip shows the current discard-pile count")
	scene.get_parent().queue_free()


func test_draw_pile_chip_click_opens_pile_inspect_panel_with_sorted_cards() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleDrawPileInspectViewport")
	if scene == null:
		return
	var cards := [
		_pile_probe_card("draw_zeta", "Zeta Lens", 2),
		_pile_probe_card("draw_alpha", "Alpha Lens", 0),
		_pile_probe_card("draw_delta", "Delta Lens", 1),
		_pile_probe_card("draw_beta", "Beta Lens", 3),
		_pile_probe_card("draw_gamma", "Gamma Lens", 1),
		_pile_probe_card("draw_epsilon", "Epsilon Lens", 2),
	]
	scene.start_battle([], [], [_enemy("draw_pile_inspect_enemy", "Draw Pile Inspect Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.draw_pile = cards.duplicate()
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var panel := await _open_pile_panel_by_click(scene, "DrawPileChip")
	assert_true(panel != null and panel.visible, "DrawPileChip click opens PileInspectPanel")
	if panel != null:
		assert_true(_collect_label_text(panel).contains("Draw Pile"), "draw pile inspect panel uses Draw Pile title")
		assert_eq(_pile_inspect_card_names(panel), ["Alpha Lens", "Beta Lens", "Delta Lens", "Epsilon Lens", "Gamma Lens", "Zeta Lens"], "draw pile inspect panel sorts card names alphabetically")
	scene.get_parent().queue_free()


func test_discard_pile_chip_click_opens_pile_inspect_panel_in_chronological_order() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleDiscardPileInspectViewport")
	if scene == null:
		return
	var discarded := [
		_pile_probe_card("discard_first", "First Discarded", 1),
		_pile_probe_card("discard_second", "Second Discarded", 1),
		_pile_probe_card("discard_third", "Third Discarded", 1),
	]
	scene.start_battle([], [], [_enemy("discard_pile_inspect_enemy", "Discard Pile Inspect Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.discard_pile = discarded.duplicate()
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var panel := await _open_pile_panel_by_click(scene, "DiscardPileChip")
	assert_true(panel != null and panel.visible, "DiscardPileChip click opens PileInspectPanel")
	if panel != null:
		assert_true(_collect_label_text(panel).contains("Discard Pile"), "discard pile inspect panel uses Discard Pile title")
		assert_eq(_pile_inspect_card_names(panel), ["First Discarded", "Second Discarded", "Third Discarded"], "discard pile inspect panel preserves discard chronology")
	scene.get_parent().queue_free()


func test_pile_inspect_panel_closes_on_close_button_or_outside_click() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattlePileInspectDismissViewport")
	if scene == null:
		return
	scene.start_battle([], [], [_enemy("pile_inspect_dismiss_enemy", "Pile Inspect Dismiss Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.draw_pile = [_pile_probe_card("dismiss_draw", "Dismiss Draw", 1)]
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var panel := await _open_pile_panel_by_click(scene, "DrawPileChip")
	assert_true(panel != null and panel.visible, "pile inspect panel opens before close-button dismissal")
	var close_button := panel.find_child("PileInspectCloseButton", true, false) if panel != null else null
	assert_true(close_button is Button, "pile inspect panel exposes a close button")
	if close_button is Button:
		(close_button as Button).pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_true(panel != null and not panel.visible, "PileInspectPanel closes from the close button")
	panel = await _open_pile_panel_by_click(scene, "DrawPileChip")
	assert_true(panel != null and panel.visible, "pile inspect panel reopens before outside-click dismissal")
	if panel != null:
		panel.call("_gui_input", _mouse_left_press_at(Vector2(2, 2)))
	await Engine.get_main_loop().process_frame
	assert_true(panel != null and not panel.visible, "PileInspectPanel closes from an outside click")
	scene.get_parent().queue_free()


func test_pile_inspect_panel_card_rows_show_clean_summaries_not_raw_tokens() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattlePileInspectCleanRowsViewport")
	if scene == null:
		return
	var card := _pile_probe_card("clean_summary_probe", "Clean Summary Probe", 2)
	scene.start_battle([], [], [_enemy("pile_inspect_clean_enemy", "Pile Inspect Clean Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.draw_pile = [card]
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var panel := await _open_pile_panel_by_click(scene, "DrawPileChip")
	assert_true(panel != null and panel.visible, "pile inspect panel opens for clean summary assertion")
	if panel != null:
		var row_texts := _pile_inspect_row_texts(panel)
		assert_eq(row_texts.size(), 1, "pile inspect panel renders one row for one card")
		if not row_texts.is_empty():
			var row_text := row_texts[0]
			assert_true(row_text.contains("Cost 2"), "pile inspect row shows the card cost")
			assert_true(row_text.contains("Clean pile summary"), "pile inspect row shows the card's clean summary")
			for raw in ["effect:", "paper_doll_marker", "identity_mask", "{", "}"]:
				assert_true(not row_text.contains(raw), "pile inspect row hides raw token %s" % raw)
	scene.get_parent().queue_free()


func test_arena_top_bar_shows_active_contract_chips_at_top_of_screen() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleArenaTopBarContractViewport")
	if scene == null:
		return
	var contract: Array[String] = ["rule_use_debuff", "rule_draw_fate"]
	scene.start_battle([_layout_probe_card("arena_top_bar_contract_card")], [], [_enemy("arena_top_bar_contract_enemy", "Arena Top Bar Contract Enemy")], contract, null, _state())
	await Engine.get_main_loop().process_frame
	var top_bar := _find_control(scene, "ArenaTopBar")
	assert_true(top_bar != null, "ArenaTopBar exists for active contract chips")
	if top_bar != null:
		assert_eq(str(top_bar.get_parent().name), "BattleSceneRoot", "ArenaTopBar is a direct child of the BattleScene root layout")
		assert_true(top_bar.get_global_rect().position.y < 60.0, "ArenaTopBar stays at the top of the screen")
		var contract_rail := _find_control(top_bar, "ContractChipRail")
		assert_true(contract_rail != null, "ArenaTopBar exposes ContractChipRail")
		if contract_rail != null:
			assert_eq(contract_rail.get_child_count(), 1, "ContractChipRail renders one summary chip for the active contract")
			var chip_text := _collect_label_text(contract_rail)
			assert_true(chip_text.contains("\u626e\u6f14\u5b88\u5219"), "ContractChipRail shows the acting-rule summary")
			var detail := _find_control(top_bar, "ArenaRuleDetailLabel")
			var detail_text := _collect_label_text(detail) if detail != null else ""
			assert_true(detail_text.contains(str(scene.call("_arena_top_rule_label_text", "rule_use_debuff"))), "ArenaRuleDetailLabel shows the first human-readable contract clause")
			assert_true(detail_text.contains(str(scene.call("_arena_top_rule_label_text", "rule_draw_fate"))), "ArenaRuleDetailLabel shows the second human-readable contract clause")
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_arena_top_bar_shows_turn_counter_and_learned_rule_chips() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleArenaTopBarRulesViewport")
	if scene == null:
		return
	var gs = _state()
	gs.learned_rules = ["rule_shadow_takes_hit", "shadow_silence"] as Array[String]
	scene.start_battle([_layout_probe_card("arena_top_bar_rule_card")], [], [_enemy("arena_top_bar_rule_enemy", "Arena Top Bar Rule Enemy")], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.turn_count = 2
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var top_bar := _find_control(scene, "ArenaTopBar")
	assert_true(top_bar != null, "ArenaTopBar exists for turn and learned-rule chips")
	if top_bar != null:
		var turn_chip := _find_control(top_bar, "TurnCounterChip")
		assert_true(turn_chip != null, "ArenaTopBar exposes TurnCounterChip")
		if turn_chip != null:
			var turn_text := _collect_label_text(turn_chip)
			assert_true(turn_text.contains("回合") and turn_text.contains("3") and not turn_text.contains("Turn"), "TurnCounterChip reads from battle turn_count with localized text")
		var learned_rule_rail := _find_control(top_bar, "LearnedRuleChipRail")
		assert_true(learned_rule_rail != null, "ArenaTopBar exposes LearnedRuleChipRail")
		if learned_rule_rail != null:
			assert_eq(learned_rule_rail.get_child_count(), 1, "LearnedRuleChipRail renders one learned-rule summary chip")
			var rule_text := _collect_label_text(learned_rule_rail)
			assert_true(rule_text.contains("\u9886\u609f\u89c4\u5219") and rule_text.contains("2"), "LearnedRuleChipRail shows the learned-rule summary")
			assert_true(not rule_text.contains("shadow_silence"), "LearnedRuleChipRail hides raw runtime learned rule ids")
		var detail := _find_control(top_bar, "ArenaRuleDetailLabel")
		var detail_text := _collect_label_text(detail) if detail != null else ""
		assert_true(detail_text.contains(str(scene.call("_arena_top_rule_label_text", "rule_shadow_takes_hit"))), "ArenaRuleDetailLabel shows the first human-readable learned rule")
		assert_true(detail_text.contains(str(scene.call("_arena_top_rule_label_text", "shadow_silence"))), "ArenaRuleDetailLabel shows the second human-readable learned rule")
		assert_true(not detail_text.contains("shadow_silence"), "ArenaRuleDetailLabel hides raw runtime learned rule ids")
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_scene_uses_full_aoe_drop_surface_without_arena_play_zone() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleFullAoeSurfaceViewport")
	if scene == null:
		return
	var card := _layout_probe_card("full_aoe_surface_card")
	card.target = "all_enemies"
	scene.start_battle([card], [], [_enemy("full_aoe_surface_enemy", "Full AOE Surface Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var play_zone := _find_control(scene, "ArenaPlayZone")
	assert_true(play_zone == null, "BattleScene no longer mounts the old visible ArenaPlayZone AOE window")
	var surface := _find_control(scene, "BattleAoeDropSurface")
	var arena_root := _find_control(scene, "BattleArenaRoot")
	assert_true(surface != null, "BattleScene keeps the full-arena AOE drop surface")
	assert_true(arena_root != null, "BattleScene keeps BattleArenaRoot as the visual arena")
	if surface != null and arena_root != null:
		var surface_rect := surface.get_global_rect()
		var arena_rect := arena_root.get_global_rect()
		assert_true(surface_rect.has_point(arena_rect.position + Vector2(8, 8)) and surface_rect.has_point(arena_rect.position + arena_rect.size - Vector2(8, 8)), "BattleAoeDropSurface covers the full arena row")
		surface.notification(Control.NOTIFICATION_DRAG_BEGIN)
		await Engine.get_main_loop().process_frame
		var local_drop_point := arena_rect.get_center() - surface_rect.position
		assert_true(bool(surface.call("_can_drop_data", local_drop_point, {"kind": "battle_card", "card": card})), "full-arena AOE drop surface accepts AOE payloads during drag")
		assert_eq(str(surface.get_meta("drop_surface_visual_state", "none")), "valid", "full-arena AOE surface owns the drag visual state")
		surface.notification(Control.NOTIFICATION_DRAG_END)
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_arena_center_does_not_leave_large_empty_band() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleArenaCenterTightViewport")
	if scene == null:
		return
	scene.start_battle([_layout_probe_card("arena_center_tight_card")], [], [_enemy("arena_center_tight_enemy", "Arena Center Tight Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var player_stage := _find_control(scene, "PlayerStage")
	var enemy_stage := _find_control(scene, "EnemyStage")
	assert_true(player_stage != null and enemy_stage != null, "PlayerStage and EnemyStage exist for empty-band measurement")
	if player_stage != null and enemy_stage != null:
		var empty_band_width := enemy_stage.get_global_rect().position.x - player_stage.get_global_rect().end.x
		assert_true(empty_band_width <= 240.0, "ArenaCenter empty horizontal band is <= 240px")
	scene.get_parent().queue_free()
	await Engine.get_main_loop().process_frame


func test_battle_scene_energy_orb_shows_current_and_max() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleEnergyOrbViewport")
	if scene == null:
		return
	scene.start_battle([_layout_probe_card("energy_orb_probe")], [], [_enemy("energy_orb_enemy", "Energy Orb Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 2
	scene._battle.energy_max = 5
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var orb := _find_control(scene, "EnergyOrb")
	assert_true(orb != null, "EnergyOrb exists")
	if orb != null:
		assert_true(_collect_label_text(orb).contains("2/5"), "EnergyOrb shows current/max energy")
	scene.get_parent().queue_free()


func test_battle_scene_end_turn_button_anchored_bottom_right_and_responds() -> void:
	var viewport_size := Vector2(1280, 720)
	var scene = await _instantiate_in_viewport(viewport_size, "BattleEndTurnChipViewport")
	if scene == null:
		return
	scene.start_battle([_layout_probe_card("end_turn_probe")], [], [_enemy("end_turn_enemy", "End Turn Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var button := _find_control(scene, "EndTurnButton")
	assert_true(button is Button, "EndTurnButton exists as a Button")
	if button is Button:
		var rect := button.get_global_rect()
		assert_true(rect.get_center().x > viewport_size.x * 0.5, "EndTurnButton is anchored in the right half")
		assert_true(rect.get_center().y > viewport_size.y * 0.75, "EndTurnButton is anchored in the bottom band")
		var before_turn := int(scene._battle.turn_count)
		(button as Button).emit_signal("pressed")
		await Engine.get_main_loop().process_frame
		assert_true(int(scene._battle.turn_count) > before_turn, "EndTurnButton advances the battle turn when pressed")
	scene.get_parent().queue_free()


func test_battle_scene_battle_log_side_drawer_fills_right_side_and_collapses_on_click() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattleLogDrawerToggleViewport")
	if scene == null:
		return
	scene.start_battle([_layout_probe_card("drawer_toggle_probe")], [], [_enemy("drawer_toggle_enemy", "Drawer Toggle Enemy")], [] as Array[String], null, _state())
	scene.call("_set_last_action_message", "T5 drawer log entry")
	await Engine.get_main_loop().process_frame
	var drawer := _find_control(scene, "BattleLogSideDrawer")
	assert_true(drawer != null, "BattleLogSideDrawer exists")
	if drawer != null:
		assert_true(drawer.get_global_rect().size.x >= 240.0, "BattleLogSideDrawer fills the right side by default")
		assert_true(_collect_label_text(drawer).contains("T5 drawer log entry"), "default BattleLogSideDrawer exposes log content")
		var log_label := _find_control(drawer, "BattleLogLabel")
		assert_true(log_label != null and log_label.is_visible_in_tree(), "expanded BattleLogSideDrawer keeps its log label visible")
		if log_label != null:
			assert_true(log_label.get_global_rect().size.x >= 160.0, "expanded BattleLogSideDrawer gives log text visible horizontal room")
			assert_true(log_label.get_global_rect().size.y >= 96.0, "expanded BattleLogSideDrawer gives log text visible vertical room")
		var toggle = drawer.find_child("BattleLogDrawerToggleButton", true, false)
		assert_true(toggle is Button, "BattleLogSideDrawer exposes a pull-tab toggle button")
		if toggle is Button:
			(toggle as Button).emit_signal("pressed")
			await Engine.get_main_loop().process_frame
			assert_true(drawer.get_global_rect().size.x <= 32.0, "BattleLogSideDrawer can still collapse after clicking the pull tab")
	scene.get_parent().queue_free()


func test_battle_scene_charge_zone_and_field_state_render_as_player_chips() -> void:
	var scene = await _instantiate_in_viewport(Vector2(1280, 720), "BattlePlayerChipStripViewport")
	if scene == null:
		return
	var card := _layout_probe_card("player_chip_charge_card")
	card.display_name = "T5 Charge Chip Card"
	scene.start_battle([card], [], [_enemy("player_chip_enemy", "Player Chip Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.charged_zone = [{"source_card": card, "remaining": 2}]
	scene._battle.field_state["flame_markers"] = 4
	scene._battle.field_state["adjacent_burn"] = 3
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var player_standee := _find_control(scene, "PlayerStandee")
	var chip_strip := _find_control(scene, "PlayerChipStrip")
	assert_true(chip_strip != null, "charged-zone and field-state markers render in PlayerChipStrip")
	assert_true(chip_strip != null and player_standee != null and _is_descendant_of(chip_strip, player_standee), "PlayerChipStrip is parented under PlayerStandee")
	if chip_strip != null:
		var chip_text := _collect_label_text(chip_strip)
		assert_true(chip_text.contains("T5 Charge Chip Card") and chip_text.contains("2"), "PlayerChipStrip shows charged-zone card and remaining turns")
		assert_true(chip_text.contains("4") and chip_text.contains("3"), "PlayerChipStrip shows field-state marker counts")
		for raw in ["flame_markers", "adjacent_burn", "{", "}"]:
			assert_true(not chip_text.contains(raw), "PlayerChipStrip hides raw field-state token %s" % raw)
		scene._battle.charged_zone.clear()
		scene._battle.field_state["flame_markers"] = 0
		scene._battle.field_state["adjacent_burn"] = 0
		scene.call("_render")
		await Engine.get_main_loop().process_frame
		assert_true(not chip_strip.visible or chip_strip.get_child_count() == 0, "PlayerChipStrip does not occupy visible chip space when charge and field state are empty")
	scene.get_parent().queue_free()


func test_battle_scene_mounts_pollution_hud_and_updates_visual_nodes() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.pollution = 50
	gs.pollution_stage = 2
	scene.start_battle([_layout_probe_card("hud_runtime_probe")], [], [_enemy("hud_enemy", "Hud Enemy")], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	var hud = scene.find_child("PollutionHud", true, false)
	assert_true(hud != null, "battle scene mounts PollutionHud at runtime")
	if hud != null:
		var filter = hud.find_child("PollutionFilter", true, false)
		var status_bar = hud.find_child("PollutionStatusBar", true, false)
		var edge_top = hud.find_child("PollutionEdgeTop", true, false)
		assert_true(filter is ColorRect, "battle PollutionHud renders filter ColorRect")
		assert_true(status_bar is ColorRect, "battle PollutionHud renders status-bar ColorRect")
		assert_true(edge_top is ColorRect, "battle PollutionHud renders edge ColorRect")
		gs.set_pollution(95, ["battle_runtime_hud_probe"])
		await Engine.get_main_loop().process_frame
		assert_eq(int(hud.current_pollution_stage), 4, "battle PollutionHud follows GameState stage changes")
		if filter is ColorRect:
			assert_true((filter as ColorRect).color.a > 0.3, "battle PollutionHud filter alpha reflects high pollution")
		if edge_top is ColorRect:
			assert_true((edge_top as ColorRect).color.a > 0.4, "battle PollutionHud edge alpha reflects high pollution")
	scene.queue_free()


func test_battle_scene_lost_control_start_auto_plays_and_disables_manual_cards() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.set_pollution(100, ["battle_scene_lost_control_probe"])
	var cards: Array = [_lost_control_scene_card("lost_control_scene_card_a"), _lost_control_scene_card("lost_control_scene_card_b")]
	scene.start_battle(cards, [], [_enemy("lost_control_scene_enemy_a", "Lost Control Enemy A"), _enemy("lost_control_scene_enemy_b", "Lost Control Enemy B")], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	assert_eq(scene._battle.used_cards.size(), 1, "battle scene lost-control start auto-plays one card")
	assert_eq(int(scene._battle.phase), int(scene._battle.Phase.ENEMY_TURN), "battle scene lost-control start waits in enemy phase after auto-play")
	var enabled_cards := 0
	for child in scene._hand_box.get_children():
		var card_view := _find_battle_card_view(child)
		if card_view != null and not _battle_card_is_disabled(card_view):
			enabled_cards += 1
	assert_eq(enabled_cards, 0, "battle scene disables manual hand buttons during lost-control enemy phase")
	assert_true(scene._end_turn_button.text.length() > 0, "battle scene keeps a visible proceed button after lost-control auto-play")
	scene.queue_free()


func test_battle_scene_marks_sequence_locked_cards_unusable() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 9
	var locked = _card_with_sequence_tags("seq8_battle_locked", 8, ["attack", "multi_strike"])
	scene.start_battle([locked], [], [], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	var card_view := _find_battle_card_view(scene._hand_box.get_child(0))
	var expected_reason := str(scene.call("_card_unusable_reason_text", locked))
	assert_true(card_view != null and _battle_card_is_disabled(card_view), "battle scene disables sequence-locked cards")
	assert_true(_battle_card_disabled_reason_text(card_view).contains(expected_reason), "battle scene explains unusable cards")
	assert_true(expected_reason != "" and card_view.tooltip_text.contains(expected_reason), "battle scene tooltip includes sequence lock reason")
	scene.queue_free()


func test_battle_scene_respects_flame_stream_discount() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var flame_jump = _card("flame_jump", 2, [{"id": "cost_zero_if_flame_stream"}], ["skill"])
	var flame_stream = _card("flame_stream_support", 0, [], ["flame_stream"])
	var contract: Array[String] = []
	scene.start_battle([flame_jump, flame_stream], [], [], contract, null, gs)
	scene._battle.energy = 0
	scene._battle.hand = [flame_jump, flame_stream]
	scene.call("_render")
	var flame_card := _find_battle_card_view(scene._hand_box.get_child(0))
	assert_true(flame_card != null, "battle scene renders the flame jump card view")
	assert_true(flame_card != null and not _battle_card_is_disabled(flame_card), "battle scene keeps flame jump enabled when a flame_stream card is in hand at zero energy")
	scene.queue_free()


func test_battle_scene_surfaces_persistent_field_state() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 7
	var flame_command = CardScript.from_json({
		"id": "field_state_flame_probe",
		"template_id": "field_state_flame_probe",
		"display_name": "操焰状态探针",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "field",
			"range": 5,
			"status_effects": [
				{"id": "create_or_move_flame_markers", "magnitude": 2},
				{"id": "adjacent_burn", "magnitude": 3},
			],
		},
		"tags": ["skill", "field_marker"],
	})
	var enemy = _enemy("field_state_dummy_enemy", "场地状态靶子")
	scene.start_battle([flame_command], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [flame_command]
	scene._selected_card = flame_command
	scene.call("_play_selected", null)
	await Engine.get_main_loop().process_frame
	assert_true(scene._battle.get_field_marker_count("flame_markers") == 2, "flame command creates persistent flame markers")
	assert_true(int(scene._battle.field_state.get("adjacent_burn", 0)) == 3, "flame command stores adjacent burn magnitude")
	var field_chip_strip := _find_control(scene, "PlayerChipStrip")
	assert_true(field_chip_strip != null, "battle scene exposes persistent field state through PlayerChipStrip")
	if field_chip_strip != null:
		var field_text := _collect_label_text(field_chip_strip)
		assert_true(field_text.contains("火焰标记 2"), "PlayerChipStrip shows current flame marker count")
		assert_true(field_text.contains("相邻燃烧 3"), "PlayerChipStrip shows adjacent burn magnitude")
		for raw in ["flame_markers", "adjacent_burn", "{", "}"]:
			assert_true(not field_text.contains(raw), "PlayerChipStrip hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_surfaces_created_temp_card_name_and_destination() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 7
	var temp_option = {
		"id": "minor_trick_temp_raw_id",
		"template_id": "minor_trick_temp_raw_id",
		"display_name": "临时火花",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "戏法",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "self",
			"range": 0,
			"status_effects": [],
		},
		"tags": ["skill", "temporary"],
	}
	var card = CardScript.from_json({
		"id": "temp_card_summary_probe",
		"template_id": "temp_card_summary_probe",
		"display_name": "临时生成探针",
		"pathway": "fool",
		"sequence": 7,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "deck",
			"range": 0,
			"status_effects": [{"id": "create_random_temp_card", "options": [temp_option]}],
		},
		"tags": ["skill", "temporary_card"],
	})
	var enemy = _enemy("temp_card_summary_enemy", "临时卡靶子")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._battle.draw_pile = []
	scene._selected_card = card
	scene.call("_play_selected", null)
	await Engine.get_main_loop().process_frame
	assert_true(scene._battle.draw_pile.size() > 0, "temporary card generation inserts a card into draw pile")
	if scene._battle.draw_pile.size() > 0:
		assert_true(str(scene._battle.draw_pile[0].get_display_name()) == "临时火花", "temporary card generation keeps the generated display name")
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("生成临时卡") and visible_text.contains("临时火花"), "temp-card summary names the generated card")
	assert_true(visible_text.contains("抽牌堆顶"), "temp-card summary explains the generated card destination")
	for raw in ["minor_trick_temp_raw_id", "temp_card_created", "create_random_temp_card", "{", "}"]:
		assert_true(not visible_text.contains(raw), "temp-card summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_surfaces_mirror_generated_card_name_and_destination() -> void:
	seed(12001)
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 9
	var enemy = EnemyScript.from_json({
		"id": "mirror_summary_enemy",
		"display_name": "镜像靶子",
		"stats": {"hp": 60, "max_hp": 60, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = _brand_card("mirror_summary_probe", "镜像生成探针", 4, ["mirror_image"])
	card.energy_cost = 1
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._selected_card = card
	scene.call("_play_selected", enemy)
	await Engine.get_main_loop().process_frame
	assert_true(scene._battle.hand.size() > 0, "mirror image adds a generated card to hand")
	var generated = scene._battle.hand[0] if scene._battle.hand.size() > 0 else null
	var generated_name := str(generated.get_display_name()) if generated != null and generated.has_method("get_display_name") else ""
	assert_true(generated_name != "", "mirror image generated card has a display name")
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("烙印触发：生成临时卡") and visible_text.contains(generated_name), "mirror summary names the generated card")
	assert_true(visible_text.contains("手牌"), "mirror summary explains the generated card destination")
	for raw in ["brand_mirror_card_created", "mirror_image", str(generated.id) if generated != null else "", "{", "}"]:
		if raw != "":
			assert_true(not visible_text.contains(raw), "mirror summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_draw_filter_uses_player_choice() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var filter_card = _card(
		"draw_filter_ui_probe",
		0,
		[{"id": "draw_filter", "peek": 3, "choose": 1, "rest_policy": "return_top"}],
		["skill", "draw_filter"]
	)
	filter_card.target = "self"
	var first = _card("draw_filter_first", 0, [], ["skill"])
	var second = _card("draw_filter_second", 0, [], ["skill"])
	var third = _card("draw_filter_third", 0, [], ["skill"])
	scene.start_battle([filter_card], [], [], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [filter_card]
	scene._battle.draw_pile = [first, second, third]
	scene._battle.discard_pile = []
	scene.call("_render")
	scene.call("_on_card_pressed", filter_card)
	await Engine.get_main_loop().process_frame
	var panel = scene.find_child("DrawFilterPanel", true, false)
	assert_true(panel != null and panel.visible, "draw_filter opens a BattleScene choice panel instead of auto-selecting")
	assert_true(scene.has_method("_on_draw_filter_choice_pressed"), "draw_filter panel exposes a choice callback")
	if not scene.has_method("_on_draw_filter_choice_pressed"):
		scene.queue_free()
		return
	scene.call("_on_draw_filter_choice_pressed", 1)
	await Engine.get_main_loop().process_frame
	assert_true(_card_in_zone(scene._battle.hand, "draw_filter_second"), "draw_filter adds the player-chosen candidate to hand")
	assert_true(not _card_in_zone(scene._battle.hand, "draw_filter_first"), "draw_filter does not force-select the first candidate")
	assert_true(_card_in_zone(scene._battle.draw_pile, "draw_filter_first"), "draw_filter returns unchosen earlier candidate to draw pile")
	assert_true(_card_in_zone(scene._battle.draw_pile, "draw_filter_third"), "draw_filter returns unchosen later candidate to draw pile")
	assert_true(filter_card in scene._battle.discard_pile, "draw_filter source card still reaches discard after choice")
	var result: Dictionary = scene._battle.last_effect_results[0] if scene._battle.last_effect_results.size() > 0 else {}
	assert_true(str(result.get("selected_card_id", "")) == "draw_filter_second", "draw_filter result records the player-chosen card id")
	assert_true(panel != null and not panel.visible, "draw_filter panel closes after the choice resolves")
	scene.queue_free()


func test_battle_scene_draw_filter_copy_is_player_facing() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var filter_card = _card(
		"draw_filter_copy_probe",
		0,
		[{"id": "draw_filter", "peek": 1, "choose": 1, "rest_policy": "return_top"}],
		["skill", "draw_filter"]
	)
	filter_card.target = "self"
	var first = _card("draw_filter_copy_first", 0, [], ["skill"])
	scene.start_battle([filter_card], [], [], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [filter_card]
	scene._battle.draw_pile = [first]
	scene.call("_render")
	scene.call("_on_card_pressed", filter_card)
	await Engine.get_main_loop().process_frame
	var panel_text := _collect_label_text(scene)
	assert_true(panel_text.contains("抽牌筛选") and panel_text.contains("选择 1 张牌"), "draw_filter choice panel uses Chinese player-facing copy")
	assert_true(not panel_text.contains("Draw filter") and not panel_text.contains("choose"), "draw_filter choice panel hides English debug copy")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	var blocked_text := _collect_label_text(scene)
	assert_true(blocked_text.contains("先完成抽牌筛选"), "draw_filter blocks end turn with a Chinese reason")
	assert_true(not blocked_text.contains("Finish draw filter"), "draw_filter end-turn block hides English debug copy")
	scene.queue_free()


func test_resolve_renders_contract_state() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.current_weather = "fog"
	gs.pathway = "fool"
	gs.pollution = 0
	var contract: Array[String] = ["rule_a", "rule_b", "rule_c"]
	scene.start_battle([], [], [], contract, null, gs)
	scene.call("_on_reward_picked", [], -1)
	await Engine.get_main_loop().process_frame
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("破契"), "battle settlement renders broken contract in Chinese")
	assert_true(visible_text.contains("污染 +5"), "battle settlement renders pollution delta")
	assert_true(visible_text.contains("判定 2"), "battle settlement renders acting_check difficulty")
	assert_true(visible_text.contains("(-1)"), "battle settlement renders fog acting_check modifier")
	scene.queue_free()


func test_battle_scene_surfaces_ai_gm_text_after_reward_pick() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var fake_service := FakeBattleAIGMService.new()
	var gs = _state()
	gs.sequence = 9
	gs.pollution = 24
	gs.pollution_stage = 0
	gs.cycle = 1
	gs.day = 4
	gs.time_of_day = "noon"
	var card := _layout_probe_card("battle_ai_gm_reward_probe")
	scene.start_battle([card], [], [_enemy("battle_ai_gm_target", "Battle AI GM Target")], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.set_ai_gm_service(fake_service)
	scene.call("_on_reward_picked", [], -1)
	await Engine.get_main_loop().process_frame
	assert_eq(str(scene._result.get("ai_gm_text", "")), "battle AI GM visible narration", "battle result contains AI GM text")
	assert_eq(fake_service.calls.size(), 1, "battle reward-pick path requests combat AI GM once")
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("battle AI GM visible narration"), "battle scene displays combat AI GM narration after reward pick")
	var narrative_rail := _find_control(scene, "BattleNarrativeRail")
	assert_true(narrative_rail != null and narrative_rail.is_visible_in_tree(), "battle scene renders BattleNarrativeRail for result narration")
	if narrative_rail != null:
		var narrative_text := _collect_label_text(narrative_rail)
		assert_true(narrative_text.contains("battle AI GM visible narration"), "BattleNarrativeRail displays combat AI GM narration")
	scene.queue_free()


func test_battle_scene_renders_statuses_and_active_contract() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.learned_rules = ["rule_use_debuff"] as Array[String]
	var player = CombatActorScript.new()
	player.display_name = "哈维"
	player.hp = 31
	player.max_hp = 50
	player.add_status("weak", {"duration": 2})
	var enemy = _enemy("status_target", "状态靶子")
	enemy.add_status("vulnerable", {"duration": 1})
	scene.start_battle([], [], [enemy], ["rule_use_debuff"] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	var standee := _find_control(scene, "PlayerStandee")
	var detail_text := standee.tooltip_text if standee != null else ""
	assert_true(detail_text.contains("虚弱") and detail_text.contains("1") and not detail_text.contains("duration 1"), "PlayerStandee tooltip shows localized player status duration after turn-start tick")
	assert_true(detail_text.contains("扮演契约：") and detail_text.contains("已领悟规则："), "PlayerStandee tooltip exposes localized active contract and learned rules")
	var enemy_standee := _find_control(scene, "EnemyStandee")
	var enemy_tooltip_text := _collect_tooltip_text(enemy_standee)
	assert_true(enemy_tooltip_text.contains("易伤") and enemy_tooltip_text.contains("1") and not enemy_tooltip_text.contains("duration 1"), "EnemyStandee status feet expose localized enemy status duration")
	scene.queue_free()
	return
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("状态：虚弱 1"), "battle scene shows player status duration after turn-start tick")
	assert_true(visible_text.contains("易伤 1"), "battle scene shows enemy status duration")
	assert_true(visible_text.contains("本场契约"), "battle scene shows active battle contract")
	assert_true(visible_text.contains("使用1张状态削弱类卡"), "battle scene localizes contract rule ids")
	assert_true(visible_text.contains("未判定"), "battle scene shows unresolved contract state")
	scene.queue_free()


func test_battle_scene_player_status_line_lists_multiple_statuses() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var player = CombatActorScript.new()
	player.display_name = "player"
	player.hp = 40
	player.max_hp = 50
	player.add_status("weak", {"duration": 3})
	player.add_status("blind", {"duration": 2})
	var enemy = _enemy("player_status_line_target", "status line target")
	scene.start_battle([], [], [enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	var standee := _find_control(scene, "PlayerStandee")
	assert_true(standee != null, "battle scene exposes PlayerStandee for player status details")
	var status_strip = standee.find_child("StatusFeetStrip", true, false) if standee != null else null
	assert_true(status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() == 2, "PlayerStandee feet strip lists multiple statuses")
	var standee_status_text := standee.tooltip_text if standee != null else ""
	assert_true(standee_status_text.contains("虚弱") and standee_status_text.contains("致盲"), "PlayerStandee tooltip lists multiple localized player statuses")
	for raw in ["weak", "blind", "{", "}"]:
		assert_true(not standee_status_text.contains(raw), "PlayerStandee tooltip hides raw payload token %s" % raw)
	scene.queue_free()
	return
	var label = scene.find_child("PlayerStatusLabel", true, false)
	assert_true(label is Label, "battle scene exposes player compressed status label")
	var status_text := ""
	if label is Label:
		status_text = (label as Label).text
	var weak_label := str(scene.call("_status_label_text", "weak"))
	var blind_label := str(scene.call("_status_label_text", "blind"))
	assert_true(status_text.contains(weak_label) and status_text.contains(blind_label) and status_text.contains(" / "), "player status line lists multiple statuses")
	if label is Label:
		assert_true((label as Label).clip_text, "player status line clips instead of resizing the battle header")
		assert_true((label as Label).text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "player status line trims overflow with ellipsis")
		assert_true((label as Label).tooltip_text.contains(weak_label) and (label as Label).tooltip_text.contains(blind_label), "player status line tooltip keeps the full multi-status text")
	for raw in ["weak", "blind", "{", "}"]:
		assert_true(not status_text.contains(raw), "player status line hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_surfaces_multiple_statuses_and_defense_changes() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy = EnemyScript.from_json({
		"id": "defense_surface_target",
		"display_name": "Defense Surface Target",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 5, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	enemy.add_status("weak", {"duration": 2})
	enemy.add_status("vulnerable", {"duration": 2})
	var card = CardScript.from_json({
		"id": "block_break_visibility_probe",
		"template_id": "block_break_visibility_probe",
		"display_name": "Block Break Visibility Probe",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 11,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "block_break", "magnitude": 3}],
		},
		"tags": ["attack", "block_break"],
	})
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	var status_summary := str(scene.call("_actor_status_summary", enemy))
	assert_true(status_summary.contains("虚弱") and status_summary.contains("易伤") and status_summary.contains(" / "), "battle scene shows multiple localized statuses on one enemy")
	var before_text := _collect_label_text(scene)
	assert_true(before_text.contains("防御 5"), "battle scene exposes localized enemy defense before block_break")
	scene._battle.energy = 99
	assert_true(scene._battle.play_card(card, enemy), "block_break visibility probe can be played")
	scene.call("_render")
	var after_text := _collect_label_text(scene)
	assert_true(after_text.contains("防御 2"), "battle scene updates localized enemy defense after block_break")
	scene.queue_free()


func test_battle_scene_renders_status_detail_panel() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var player = CombatActorScript.new()
	player.display_name = "哈维"
	player.hp = 40
	player.max_hp = 50
	player.add_status("weak", {"duration": 3})
	player.add_status("blind", {"duration": 2})
	var enemy = _enemy("status_detail_target", "状态明细靶子")
	enemy.add_status("vulnerable", {"duration": 2})
	enemy.add_status("burn", {"duration": 2, "magnitude": 3})
	scene.start_battle([], [], [enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	var standee := _find_control(scene, "PlayerStandee")
	assert_true(standee != null, "battle scene exposes PlayerStandee for hover status detail")
	var standee_detail := standee.tooltip_text if standee != null else ""
	assert_true(standee_detail.contains("虚弱") and standee_detail.contains("致盲"), "PlayerStandee tooltip lists localized player statuses after start-turn tick")
	var enemy_standee := _find_control(scene, "EnemyStandee")
	var enemy_detail := _collect_tooltip_text(enemy_standee)
	assert_true(enemy_detail.contains("易伤") and enemy_detail.contains("燃烧") and enemy_detail.contains("3") and not enemy_detail.contains("magnitude"), "EnemyStandee status feet tooltips list localized enemy statuses with human magnitude text")
	for raw in ["weak", "blind", "vulnerable", "burn", "{", "}"]:
		assert_true(not standee_detail.contains(raw) and not enemy_detail.contains(raw), "standee status detail hides raw payload token %s" % raw)
	scene.queue_free()
	return
	var detail_label = scene.find_child("StatusDetailLabel", true, false)
	assert_true(detail_label is Label, "battle scene exposes a dedicated status detail label")
	var detail_text := ""
	if detail_label is Label:
		detail_text = (detail_label as Label).text
	assert_true(detail_text.contains("状态明细"), "status detail panel has a clear title")
	assert_true(detail_text.contains("玩家：哈维") and detail_text.contains("虚弱 2") and detail_text.contains("致盲 1"), "status detail panel lists player statuses after start-turn tick")
	assert_true(detail_text.contains("敌人：状态明细靶子") and detail_text.contains("易伤 2") and detail_text.contains("燃烧 2 强度 3"), "status detail panel lists enemy statuses with magnitude")
	for raw in ["weak", "blind", "vulnerable", "burn", "status_detail_target", "{", "}"]:
		assert_true(not detail_text.contains(raw), "status detail panel hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_allows_select_targets_cards_to_choose_multiple_enemies() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy_a = EnemyScript.from_json({
		"id": "select_targets_ui_a",
		"display_name": "多目标甲",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var enemy_b = EnemyScript.from_json({
		"id": "select_targets_ui_b",
		"display_name": "多目标乙",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var enemy_c = EnemyScript.from_json({
		"id": "select_targets_ui_c",
		"display_name": "多目标丙",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = CardScript.from_json({
		"id": "select_targets_ui_probe",
		"template_id": "select_targets_ui_probe",
		"display_name": "多目标测试牌",
		"pathway": "fool",
		"sequence": 8,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 10,
			"heal": 0,
			"target": "multi",
			"range": 4,
			"status_effects": [{"id": "select_targets", "min": 1, "max": 3}],
		},
		"tags": ["attack", "multi_target"],
	})
	scene.start_battle([card], [], [enemy_a, enemy_b, enemy_c], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene.call("_on_card_pressed", card)
	await Engine.get_main_loop().process_frame
	var panel = scene.find_child("TargetSelectionPanel", true, false)
	assert_true(panel != null and panel.visible, "select_targets card opens a multi-target selection panel")
	var selecting_text := _collect_label_text(scene)
	assert_true(selecting_text.contains("选择目标") and selecting_text.contains("0/3"), "target selection panel shows the current and max target counts")
	scene.call("_on_target_pressed", enemy_a)
	scene.call("_on_target_pressed", enemy_b)
	scene.call("_on_target_pressed", enemy_c)
	await Engine.get_main_loop().process_frame
	var selected_text := _collect_label_text(scene)
	assert_true(selected_text.contains("3/3"), "target selection panel updates after selecting three targets")
	var confirm = scene.find_child("TargetSelectionConfirmButton", true, false)
	assert_true(confirm is Button and not (confirm as Button).disabled, "target selection confirm becomes enabled after selecting enough targets")
	if confirm is Button:
		(confirm as Button).pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_true(int(enemy_a.hp) == 35, "select_targets UI applies three-target damage to target A")
	assert_true(int(enemy_b.hp) == 35, "select_targets UI applies three-target damage to target B")
	assert_true(int(enemy_c.hp) == 35, "select_targets UI applies three-target damage to target C")
	var result_text := _collect_label_text(scene)
	assert_true(result_text.contains("多目标甲 受到 5 伤害"), "select_targets summary reports target A damage")
	assert_true(result_text.contains("多目标乙 受到 5 伤害"), "select_targets summary reports target B damage")
	assert_true(result_text.contains("多目标丙 受到 5 伤害"), "select_targets summary reports target C damage")
	assert_true(result_text.contains("目标选择 1-3"), "select_targets summary labels the target-selection mechanic")
	for raw in ["select_targets_ui_probe", "select_targets", "target_selection_registered", "{", "}"]:
		assert_true(not result_text.contains(raw), "select_targets summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_keyboard_click_fallback_still_plays_card() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var enemy = _enemy("keyboard_click_fallback_enemy", "Keyboard Click Fallback Enemy")
	var card := _lost_control_scene_card("keyboard_click_fallback_card")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var card_view := _find_battle_card_view(scene._hand_box.get_child(0))
	assert_true(card_view != null, "battle scene renders card view for keyboard/click fallback")
	if card_view != null:
		var key_event := _keyboard_accept_event()
		scene.call("_input", key_event)
		card_view.call("_gui_input", key_event)
	await Engine.get_main_loop().process_frame
	assert_true(scene._selected_card == card, "keyboard/click fallback selects the card")
	var enemy_standee_script = load("res://scripts/ui/battle/enemy_standee.gd")
	var enemy_standees := _find_controls_by_script(scene, enemy_standee_script)
	assert_true(not enemy_standees.is_empty(), "battle scene renders an EnemyStandee target for fallback play")
	var target_button = enemy_standees[0].find_child("TargetButton", true, false) if not enemy_standees.is_empty() else null
	assert_true(target_button is Button and not (target_button as Button).disabled, "fallback target button is enabled after selecting a single-target card")
	if target_button is Button:
		(target_button as Button).pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_true(int(enemy.hp) < int(enemy.max_hp), "keyboard/click fallback plays the selected card through target_pressed")
	scene.queue_free()


func test_battle_scene_old_click_to_select_flow_is_disabled_under_mouse() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var enemy = _enemy("mouse_click_flow_disabled_enemy", "Mouse Click Flow Disabled Enemy")
	var card := _lost_control_scene_card("mouse_click_flow_disabled_card")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var card_view := _find_battle_card_view(scene._hand_box.get_child(0))
	assert_true(card_view != null, "battle scene renders card view for mouse-only click flow test")
	if card_view != null:
		var mouse_event := _mouse_left_press_event()
		scene.call("_input", mouse_event)
		card_view.call("_gui_input", mouse_event)
	await Engine.get_main_loop().process_frame
	var message_text := ""
	if scene._message_label != null:
		message_text = scene._message_label.text
	assert_true(scene._selected_card == null, "mouse-only card press does not set selected card")
	assert_true(not message_text.contains("点击敌人指定目标"), "mouse-only card press does not show the legacy click-to-select target prompt")
	scene.queue_free()


func test_battle_scene_surfaces_intent_reveal_result_summary() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var player = CombatActorScript.new()
	player.display_name = "玩家"
	player.hp = 50
	player.max_hp = 50
	var enemy = EnemyScript.from_json({
		"id": "intent_reveal_summary_target",
		"display_name": "意图摘要靶子",
		"stats": {"hp": 30, "max_hp": 30, "atk": 7, "def": 0, "spd": 1},
		"skills": [{
			"id": "raw_secret_skill",
			"name": "暗爪",
			"damage": 9,
			"target": "single",
			"status_effects": [{"id": "fear", "chance": 1.0, "duration": 1}],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "raw_secret_skill"}],
	})
	var card = CardScript.from_json({
		"id": "intent_reveal_summary_probe",
		"template_id": "intent_reveal_summary_probe",
		"display_name": "揭示摘要探针",
		"pathway": "fool",
		"sequence": 8,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "all_enemies",
			"range": 5,
			"status_effects": [],
		},
		"tags": ["skill", "intent_reveal", "mind_read"],
	})
	scene.start_battle([card], [], [enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._selected_card = card
	scene.call("_play_selected", null)
	await Engine.get_main_loop().process_frame
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("出牌：揭示摘要探针"), "intent reveal summary keeps the played card name")
	assert_true(visible_text.contains("读心揭示 1"), "intent reveal summary labels the revealed target count")
	for raw in ["intent_revealed_by_card", "intent_reveal_summary_probe", "raw_secret_skill", "{", "}"]:
		assert_true(not visible_text.contains(raw), "intent reveal summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_surfaces_last_card_result_summary() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy = EnemyScript.from_json({
		"id": "last_result_surface_target",
		"display_name": "结果靶子",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 5, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = CardScript.from_json({
		"id": "last_result_surface_probe",
		"template_id": "last_result_surface_probe",
		"display_name": "破防反馈探针",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 11,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "block_break", "magnitude": 3}],
		},
		"tags": ["attack", "block_break"],
	})
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._selected_card = card
	scene.call("_play_selected", enemy)
	await Engine.get_main_loop().process_frame
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("出牌：破防反馈探针"), "battle scene keeps a visible last-card result summary")
	assert_true(visible_text.contains("结果靶子 受到 9 伤害"), "battle scene result summary reports actual damage dealt")
	assert_true(visible_text.contains("防御 5→2"), "battle scene result summary reports defense change")
	assert_true(visible_text.contains("破防 3"), "battle scene result summary labels the block_break effect")
	for raw in ["last_result_surface_probe", "block_break", "defense_shredded", "{", "}"]:
		assert_true(not visible_text.contains(raw), "battle scene result summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_last_action_feedback_does_not_replace_battle_log() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy = EnemyScript.from_json({
		"id": "feedback_log_target",
		"display_name": "Feedback Log Target",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = CardScript.from_json({
		"id": "feedback_log_probe",
		"template_id": "feedback_log_probe",
		"display_name": "Feedback Log Strike",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 5,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._selected_card = card
	scene.call("_play_selected", enemy)
	await Engine.get_main_loop().process_frame
	var first_action := str(scene._last_action_message)
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	var second_action := str(scene._last_action_message)
	var message_rail = _find_control(scene, "ArenaMessageRibbon")
	var log_drawer = _find_control(scene, "BattleLogSideDrawer")
	assert_true(message_rail != null, "battle scene renders ArenaMessageRibbon for recent feedback")
	assert_true(log_drawer != null, "battle scene renders BattleLogSideDrawer for persistent history")
	var message_text := _collect_label_text(message_rail)
	var log_text := _collect_label_text(log_drawer)
	assert_true(second_action != "" and message_text.contains(second_action), "ArenaMessageRibbon shows the most recent action feedback")
	assert_true(log_text.contains(first_action), "BattleLogSideDrawer preserves the previous card action")
	assert_true(log_text.contains(second_action), "BattleLogSideDrawer appends the latest action instead of replacing history")
	assert_true(_find_control(scene, "BattleFeedbackLayer") == null, "BattleScene does not mount a separate BattleFeedbackLayer panel")
	scene.queue_free()


func test_battle_scene_preserves_action_history_when_message_changes() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy = EnemyScript.from_json({
		"id": "battle_log_target",
		"display_name": "日志靶子",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var played_card = CardScript.from_json({
		"id": "battle_log_played_probe",
		"template_id": "battle_log_played_probe",
		"display_name": "日志命中探针",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 6,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})
	var next_card = _card("battle_log_next_probe", 0, [], ["skill"])
	next_card.display_name = "下一张测试牌"
	scene.start_battle([played_card, next_card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [played_card]
	scene._selected_card = played_card
	scene.call("_play_selected", enemy)
	await Engine.get_main_loop().process_frame
	var result_text := _collect_label_text(scene)
	assert_true(result_text.contains("出牌：日志命中探针"), "battle scene shows the first action result immediately")
	scene._battle.hand = [next_card]
	scene.call("_on_card_pressed", next_card)
	await Engine.get_main_loop().process_frame
	var history_text := _collect_label_text(scene)
	assert_true(history_text.contains("已选：下一张测试牌"), "battle scene message line can change after selecting another card")
	assert_true(history_text.contains("战斗日志"), "battle scene renders a persistent battle log")
	assert_true(history_text.contains("出牌：日志命中探针"), "battle log preserves the previous action summary after the message line changes")
	scene.queue_free()


func test_battle_scene_surfaces_charge_resolution_across_turns() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy = EnemyScript.from_json({
		"id": "charge_ui_target",
		"display_name": "充能靶子",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = CardScript.from_json({
		"id": "charge_ui_probe",
		"template_id": "charge_ui_probe",
		"display_name": "充能测试牌",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "charge", "magnitude": 1, "payload": [{"id": "weak", "duration": 1}]}],
		},
		"tags": ["skill", "charge_skill"],
	})
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._selected_card = card
	scene.call("_play_selected", enemy)
	await Engine.get_main_loop().process_frame
	var played_text := _collect_label_text(scene)
	assert_true(played_text.contains("出牌：充能测试牌"), "charge play keeps the card summary visible")
	assert_true(played_text.contains("进入充能区"), "charge play explains that the card entered the charge zone")
	assert_true(played_text.contains("充能测试牌") and played_text.contains("剩余"), "charge zone shows the source card and remaining turns")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	var resolved_text := _collect_label_text(scene)
	assert_true(resolved_text.contains("敌方行动"), "charge resolution is attached to the next turn summary")
	assert_true(resolved_text.contains("充能靶子 获得状态") and resolved_text.contains("虚弱"), "charge resolution summary reports the applied payload status")
	assert_true(resolved_text.contains("充能效果结算"), "charge resolution summary labels the charge-zone settlement")
	for raw in ["charge_payload_resolved", "charge_ui_probe", "{", "}"]:
		assert_true(not resolved_text.contains(raw), "charge resolution summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_surfaces_delayed_brand_resolution_across_turns() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy = EnemyScript.from_json({
		"id": "delayed_brand_ui_target",
		"display_name": "延迟靶子",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = _brand_card("delayed_brand_ui_probe", "延迟测试牌", 10, ["delay_brand"])
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._selected_card = card
	scene.call("_play_selected", enemy)
	await Engine.get_main_loop().process_frame
	var played_text := _collect_label_text(scene)
	assert_true(played_text.contains("出牌：延迟测试牌"), "delayed brand play keeps the card summary visible")
	assert_true(played_text.contains("烙印触发：延迟结算"), "delayed brand play explains the delayed settlement")
	assert_true(not played_text.contains("延迟靶子 受到 10 伤害"), "delayed brand does not report immediate damage")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	var resolved_text := _collect_label_text(scene)
	assert_true(resolved_text.contains("敌方行动"), "delayed brand resolution is attached to the next turn summary")
	assert_true(resolved_text.contains("延迟靶子 受到 15 伤害"), "delayed brand summary reports the 1.5x delayed damage")
	assert_true(resolved_text.contains("延迟效果结算"), "delayed brand summary labels the delayed resolution result")
	for raw in ["brand_delayed_card_effect_resolved", "delay_brand", "{", "}"]:
		assert_true(not resolved_text.contains(raw), "delayed brand summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_surfaces_echo_brand_replay_across_turns() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var enemy = EnemyScript.from_json({
		"id": "echo_brand_ui_target",
		"display_name": "回放靶子",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = _brand_card("echo_brand_ui_probe", "回放测试牌", 10, ["echo"])
	scene.start_battle([card], [], [enemy], [] as Array[String], null, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	scene._selected_card = card
	scene.call("_play_selected", enemy)
	await Engine.get_main_loop().process_frame
	var played_text := _collect_label_text(scene)
	assert_true(played_text.contains("出牌：回放测试牌"), "echo brand play keeps the card summary visible")
	assert_true(played_text.contains("回放靶子 受到 10 伤害"), "echo brand source play reports immediate damage")
	assert_true(played_text.contains("烙印触发：下回合重放"), "echo brand play explains the scheduled replay")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	var replay_text := _collect_label_text(scene)
	assert_true(replay_text.contains("敌方行动"), "echo brand replay is attached to the next turn summary")
	assert_true(replay_text.contains("回放靶子 受到 10 伤害"), "echo brand summary reports replay damage")
	assert_true(replay_text.contains("烙印重放结算"), "echo brand summary labels replay resolution")
	for raw in ["brand_next_turn_replay_resolved", "echo_brand_ui_probe", "{", "}"]:
		assert_true(not replay_text.contains(raw), "echo brand summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_surfaces_enemy_turn_result_summary() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var player = CombatActorScript.new()
	player.display_name = "玩家"
	player.hp = 30
	player.max_hp = 30
	player.def = 2
	var enemy = EnemyScript.from_json({
		"id": "enemy_turn_result_probe",
		"display_name": "恐惧爪手",
		"stats": {"hp": 24, "max_hp": 24, "atk": 7, "def": 1, "spd": 1},
		"skills": [{
			"id": "fear_claw_raw",
			"name": "恐惧爪",
			"damage": 7,
			"target": "single",
			"status_effects": [{"id": "fear", "chance": 1.0, "duration": 2}],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "fear_claw_raw"}],
	})
	scene.start_battle([], [], [enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	var visible_text := _collect_label_text(scene)
	assert_true(visible_text.contains("敌方行动"), "battle scene keeps a visible enemy-turn summary")
	assert_true(visible_text.contains("玩家 受到 5 伤害"), "enemy-turn summary reports defense-reduced damage")
	assert_true(visible_text.contains("玩家 获得状态 恐惧"), "enemy-turn summary reports newly applied player status")
	for raw in ["fear_claw_raw", "use_skill", "{", "}"]:
		assert_true(not visible_text.contains(raw), "enemy-turn summary hides raw token %s" % raw)
	scene.queue_free()


func test_battle_scene_labels_common_runtime_result_reasons() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var cases: Array = [
		[{"reason": "intent_revealed_by_card", "id": "mind_read", "detail_level": 2, "target_count": 1}, "读心揭示 1"],
		[{"reason": "cleanse_applied", "id": "cleanse_debuff", "removed": ["poison", "burn"]}, "净化"],
		[{"reason": "cleanse_incoming_debuff", "id": "weak"}, "净化抵挡减益"],
		[{"reason": "immune_debuff", "id": "weak"}, "免疫减益"],
		[{"reason": "self_damage_applied", "id": "self_damage", "damage": 7}, "自伤 7"],
		[{"reason": "linked_damage", "id": "link", "damage": 4}, "连锁伤害 4"],
		[{"reason": "next_card_cost_delta_applied", "id": "next_fool_skill_cost_delta", "magnitude": -1}, "下一张愚者技能费用 -1"],
		[{"reason": "reroll_next_target_applied", "id": "reroll_next_target"}, "重定下次目标"],
		[{"reason": "teleported_to_flame", "id": "teleport_to_flame", "damage": 6}, "火焰跳跃 6"],
		[{"reason": "condition_not_met", "id": "bonus_if_attack"}, "条件未满足"],
		[{"reason": "adjacent_burn_set", "id": "adjacent_burn", "magnitude": 3}, "相邻燃烧 3"],
		[{"reason": "attack_play_damage_growth_registered", "id": "attack_play_damage_growth", "magnitude": 2, "cap": 10}, "攻击成长 +2"],
		[{"reason": "per_use_damage_growth_registered", "id": "per_use_damage_growth", "magnitude": 1, "cap": 8}, "使用成长 +1"],
		[{"reason": "cost_modifier_registered", "id": "cost_zero_if_flame_stream"}, "费用修正"],
		[{"reason": "life_steal_registered", "id": "life_steal"}, "吸血"],
		[{"reason": "target_selection_registered", "id": "select_targets", "min": 1, "max": 3, "selected_count": 2}, "目标选择 1-3"],
		[{"reason": "multi_strike_registered", "id": "multi_strike", "hits": 3, "damage_each": 4}, "多段 3×4"],
		[{"reason": "draw_filter_pending", "id": "draw_filter", "peeked": 3}, "抽牌筛选待选择"],
		[{"reason": "delayed_card_effect_pending", "id": "draw_filter"}, "延迟效果待结算"],
		[{"reason": "missing_flame_marker", "id": "teleport_to_flame"}, "缺少火焰标记"],
		[{"reason": "brand_once_per_battle_already_used", "id": "truename_brand"}, "烙印已触发过"],
		[{"reason": "brand_face_mask_no_enemy_target", "id": "fool_face_mask_mark"}, "烙印未触发：无可改判目标"],
	]
	for case in cases:
		var result: Dictionary = case[0]
		var expected := str(case[1])
		var text := str(scene.call("_effect_result_text", result))
		assert_true(text.contains(expected), "battle scene labels runtime result %s as %s" % [str(result.get("reason", "")), expected])
		assert_true(not text.contains(str(result.get("reason", ""))) and not text.contains("{") and not text.contains("}"), "runtime result label hides raw reason %s" % str(result.get("reason", "")))
	scene.queue_free()


func test_battle_scene_renders_actionable_enemy_intent_payload() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var player = CombatActorScript.new()
	player.display_name = "玩家"
	player.hp = 50
	player.max_hp = 50
	var enemy = EnemyScript.from_json({
		"id": "battle_intent_probe",
		"display_name": "意图样本",
		"stats": {"hp": 24, "max_hp": 24, "atk": 7, "def": 1, "spd": 1},
		"skills": [{
			"id": "fear_claw",
			"name": "恐惧爪",
			"damage": 13,
			"target": "single",
			"status_effects": [{"id": "fear", "chance": 1.0, "duration": 1}],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "fear_claw"}],
	})
	var reveal_card = CardScript.from_json({
		"id": "intent_reveal_ui_probe",
		"template_id": "intent_reveal_ui_probe",
		"display_name": "intent_reveal_ui_probe",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "all_enemies",
			"range": 5,
			"status_effects": [],
		},
		"tags": ["skill", "intent_reveal"],
	})
	scene.start_battle([reveal_card], [], [enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	var hidden_text := _collect_label_text(scene)
	assert_true(not hidden_text.contains("造成 8 伤害"), "unrevealed battle intent hides actual enemy damage number")
	assert_true(not hidden_text.contains("fear_claw"), "unrevealed battle intent hides raw skill id")
	scene._battle.energy = 99
	assert_true(scene._battle.play_card(reveal_card, null), "intent reveal card can be played from the battle scene hand")
	scene.call("_render")
	var revealed_text := _collect_label_text(scene)
	assert_true(revealed_text.contains("造成 8 伤害"), "revealed battle intent shows defense-reduced enemy damage number")
	var visible_text := revealed_text
	assert_true(visible_text.contains("恐惧"), "battle scene intent text shows enemy status payload")
	assert_true(not revealed_text.contains("fear_claw"), "revealed battle intent still hides raw skill id")
	scene.queue_free()


func test_revealed_intent_uses_status_modified_damage() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var player = CombatActorScript.new()
	player.display_name = "玩家"
	player.hp = 50
	player.max_hp = 50
	var enemy = EnemyScript.from_json({
		"id": "modified_intent_probe",
		"display_name": "受咒敌人",
		"stats": {"hp": 24, "max_hp": 24, "atk": 7, "def": 1, "spd": 1},
		"skills": [{
			"id": "heavy_hit",
			"name": "重击",
			"damage": 20,
			"target": "single",
			"status_effects": [],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "heavy_hit"}],
	})
	enemy.add_status("weak", {"duration": 1})
	var reveal_card = CardScript.from_json({
		"id": "intent_reveal_modified_probe",
		"template_id": "intent_reveal_modified_probe",
		"display_name": "意图揭示探针",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "all_enemies",
			"range": 5,
			"status_effects": [],
		},
		"tags": ["skill", "intent_reveal"],
	})
	scene.start_battle([reveal_card], [], [enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	assert_true(scene._battle.play_card(reveal_card, null), "modified intent reveal card can be played")
	scene.call("_render")
	var revealed_text := _collect_label_text(scene)
	assert_true(revealed_text.contains("造成 10 伤害"), "revealed intent shows the actual weak-and-defense-modified enemy damage")
	assert_true(not revealed_text.contains("造成 20 伤害"), "revealed intent hides the raw unmodified skill damage")
	scene.queue_free()


func test_revealed_intent_labels_enemy_defense_bypass_options() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	gs.sequence = 8
	var player = CombatActorScript.new()
	player.display_name = "玩家"
	player.hp = 60
	player.max_hp = 60
	player.def = 5
	var pierce_enemy = EnemyScript.from_json({
		"id": "pierce_intent_probe",
		"display_name": "穿透意图靶子",
		"stats": {"hp": 24, "max_hp": 24, "atk": 7, "def": 1, "spd": 1},
		"skills": [{
			"id": "pierce_secret_skill",
			"name": "穿透剑",
			"damage": 18,
			"target": "single",
			"pierce_defense": 2,
			"status_effects": [],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "pierce_secret_skill"}],
	})
	var ignore_enemy = EnemyScript.from_json({
		"id": "ignore_intent_probe",
		"display_name": "无视意图靶子",
		"stats": {"hp": 24, "max_hp": 24, "atk": 7, "def": 1, "spd": 1},
		"skills": [{
			"id": "ignore_secret_skill",
			"name": "银弹",
			"damage": 22,
			"target": "single",
			"ignore_defense": true,
			"status_effects": [],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "ignore_secret_skill"}],
	})
	var reveal_card = CardScript.from_json({
		"id": "intent_reveal_defense_bypass_probe",
		"template_id": "intent_reveal_defense_bypass_probe",
		"display_name": "防线读心探针",
		"pathway": "fool",
		"sequence": 8,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "all_enemies",
			"range": 5,
			"status_effects": [],
		},
		"tags": ["skill", "intent_reveal", "mind_read"],
	})
	scene.start_battle([reveal_card], [], [pierce_enemy, ignore_enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	assert_true(scene._battle.play_card(reveal_card, null), "defense-bypass intent reveal card can be played")
	scene.call("_render")
	var revealed_text := _collect_label_text(scene)
	assert_true(revealed_text.contains("造成 15 伤害"), "revealed pierce intent damage reflects partial player-defense penetration")
	assert_true(revealed_text.contains("穿透防御 2"), "revealed pierce intent labels fixed defense penetration")
	assert_true(revealed_text.contains("造成 22 伤害"), "revealed ignore intent damage reflects full player-defense ignore")
	assert_true(revealed_text.contains("无视防御"), "revealed ignore intent labels full defense ignore")
	for raw in ["pierce_defense", "ignore_defense", "pierce_secret_skill", "ignore_secret_skill", "{", "}"]:
		assert_true(not revealed_text.contains(raw), "defense-bypass intent text hides raw token %s" % raw)
	scene.queue_free()


func test_revealed_enemy_intent_damage_survives_preview_refresh() -> void:
	var scene = await _instantiate()
	if scene == null:
		return
	var gs = _state()
	var player = CombatActorScript.new()
	player.display_name = "\u73a9\u5bb6"
	player.hp = 50
	player.max_hp = 50
	player.def = 5
	var enemy = EnemyScript.from_json({
		"id": "repeat_reveal_intent_probe",
		"display_name": "\u4e8c\u6b21\u610f\u56fe\u9762\u677f",
		"stats": {"hp": 24, "max_hp": 24, "atk": 7, "def": 1, "spd": 1},
		"skills": [{
			"id": "repeat_fear_claw",
			"name": "\u6050\u60e7\u722a",
			"damage": 13,
			"target": "single",
			"status_effects": [{"id": "fear", "chance": 1.0, "duration": 1}],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "repeat_fear_claw"}],
	})
	var reveal_card = CardScript.from_json({
		"id": "repeat_intent_reveal_probe",
		"template_id": "repeat_intent_reveal_probe",
		"display_name": "\u91cd\u590d\u63ed\u793a\u63a2\u9488",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "all_enemies",
			"range": 5,
			"status_effects": [],
		},
		"tags": ["skill", "intent_reveal"],
	})
	scene.start_battle([reveal_card], [], [enemy], [] as Array[String], player, gs)
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	assert_true(scene._battle.play_card(reveal_card, null), "intent reveal card can be played before the refresh probe")
	scene.call("_render")
	var revealed_text := _collect_label_text(scene)
	assert_true(revealed_text.contains("\u9020\u6210 8 \u4f24\u5bb3"), "first revealed intent render shows defense-reduced damage")
	scene._battle.preview_enemy_intents()
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	var refreshed_text := _collect_label_text(scene)
	assert_true(refreshed_text.contains("\u9020\u6210 8 \u4f24\u5bb3"), "revealed intent keeps showing damage after the next intent preview refresh")
	assert_true(not refreshed_text.contains("repeat_fear_claw"), "refreshed revealed intent still hides raw skill id")
	scene.queue_free()


func _card(id: String, energy_cost: int, effects: Array, tags: Array) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": energy_cost,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": effects,
		},
		"tags": tags,
	})


func _brand_card(id: String, display_name: String, damage: int, brands: Array) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": display_name,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"brand_slots": maxi(1, brands.size()),
		"brands": brands,
		"combat_effect": {
			"damage": damage,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})


func _enemy(id: String, display_name: String):
	return EnemyScript.from_json({
		"id": id,
		"display_name": display_name,
		"stats": {"hp": 20, "max_hp": 20, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func _layout_probe_card(id: String) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": "布局探针卡",
		"description": "用于验证战斗界面在常见 16:9 屏幕内完整显示。",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 2,
		"combat_effect": {
			"damage": 12,
			"heal": 0,
			"target": "single",
			"range": 3,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 3}],
		},
		"social_effect": {"type": "identity_mask", "suspicion_delta": -10},
		"world_effect": {"type": "create_residual_identity", "allowed_locations": ["shadow_alley"]},
	})


func _pile_probe_card(id: String, display_name: String, energy_cost: int) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": display_name,
		"description": "Clean pile summary for %s." % display_name,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": energy_cost,
		"element": "normal",
		"combat_effect": {
			"damage": 7,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 2}],
		},
		"social_effect": {"type": "identity_mask", "suspicion_delta": -3},
		"tags": ["attack"],
	})


func _lost_control_scene_card(id: String) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": "失控出牌探针",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 6,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})


func _card_with_sequence_tags(id: String, sequence: int, tags: Array) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": "未解锁探针",
		"pathway": "fool",
		"sequence": sequence,
		"energy_cost": 1,
		"combat_effect": {
			"damage": 6,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": tags,
	})


func _card_in_zone(zone: Array, card_id: String) -> bool:
	for card in zone:
		if card != null and str(card.id) == card_id:
			return true
	return false


func _instantiate() -> Control:
	var scene = load(SCENE_PATH)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "battle_scene.tscn instantiates for UI test")
		return null
	var instance = scene.instantiate()
	Engine.get_main_loop().root.add_child(instance)
	await Engine.get_main_loop().process_frame
	return instance


func _instantiate_in_viewport(viewport_size: Vector2, viewport_name: String) -> Control:
	var viewport := Control.new()
	viewport.name = viewport_name
	viewport.position = Vector2.ZERO
	viewport.size = viewport_size
	viewport.clip_contents = true
	Engine.get_main_loop().root.add_child(viewport)
	var scene = load(SCENE_PATH)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "battle_scene.tscn instantiates for %s" % viewport_name)
		viewport.queue_free()
		return null
	var instance = scene.instantiate()
	viewport.add_child(instance)
	await Engine.get_main_loop().process_frame
	return instance


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _long_layout_text(prefix: String, line_count: int) -> String:
	var lines: Array[String] = []
	for i in range(line_count):
		lines.append("%s %02d -- long copy for constrained battle presentation regions." % [prefix, i])
	return "\n".join(lines)


func _safe_zone_bounds(viewport_size: Vector2) -> Rect2:
	var margin := Vector2(viewport_size.x * 0.05, viewport_size.y * 0.05)
	return Rect2(margin, viewport_size - margin * 2.0)


func _sorted_string_keys(value: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in value.keys():
		keys.append(str(key))
	keys.sort()
	return keys


func _replace_string_array(target: Array, values: Array) -> void:
	target.clear()
	for value in values:
		target.append(str(value))


func _find_control(root: Node, node_name: String) -> Control:
	if root == null:
		return null
	var found := root.find_child(node_name, true, false)
	if found is Control:
		return found
	return null


func _find_named_controls(root: Node, node_name: String) -> Array[Control]:
	var results: Array[Control] = []
	if root == null:
		return results
	if root is Control and root.name == node_name:
		results.append(root as Control)
	for child in root.get_children():
		results.append_array(_find_named_controls(child, node_name))
	return results


func _find_controls_by_script(root: Node, script: Variant) -> Array[Control]:
	var results: Array[Control] = []
	if root == null or script == null:
		return results
	if root is Control and root.get_script() == script:
		results.append(root as Control)
	for child in root.get_children():
		results.append_array(_find_controls_by_script(child, script))
	return results


func _collect_labels(root: Node) -> Array[Label]:
	var results: Array[Label] = []
	if root == null:
		return results
	if root is Label:
		results.append(root as Label)
	for child in root.get_children():
		results.append_array(_collect_labels(child))
	return results


func _is_descendant_of_script(node: Node, script: Variant) -> bool:
	var current := node
	while current != null:
		if script != null and current is Control and current.get_script() == script:
			return true
		current = current.get_parent()
	return false


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _find_battle_card_view(root: Node) -> Control:
	if root == null:
		return null
	if root.get_script() == BattleCardViewScript:
		return root as Control
	var found := root.find_child("BattleCardView", true, false)
	if found is Control and found.get_script() == BattleCardViewScript:
		return found as Control
	for child in root.get_children():
		var card_view := _find_battle_card_view(child)
		if card_view != null:
			return card_view
	return null


func _battle_card_is_disabled(card_view: Control) -> bool:
	if card_view == null:
		return true
	if card_view.has_method("is_disabled"):
		return bool(card_view.call("is_disabled"))
	return _battle_card_disabled_reason_text(card_view) != ""


func _battle_card_disabled_reason_text(card_view: Control) -> String:
	if card_view == null:
		return ""
	var label = card_view.find_child("DisabledReasonLabel", true, false)
	if label is Label:
		return (label as Label).text
	return ""


func _control_has_static_or_interactive_content(control: Control) -> bool:
	if control == null:
		return false
	if control is Label or control is Button or control is RichTextLabel:
		return true
	for child in control.get_children():
		if child is Control and _control_has_static_or_interactive_content(child):
			return true
	return false


func _collect_label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


func _collect_tooltip_text(node: Node) -> String:
	if node == null:
		return ""
	var text := ""
	if node is Control:
		text += (node as Control).tooltip_text + "\n"
	for child in node.get_children():
		text += _collect_tooltip_text(child)
	return text


func _open_pile_panel_by_click(scene: Control, chip_name: String) -> Control:
	var chip := _find_control(scene, chip_name)
	assert_true(chip != null, "%s exists for pile inspect click" % chip_name)
	if chip != null:
		chip.gui_input.emit(_mouse_left_press_event())
	await Engine.get_main_loop().process_frame
	return _find_control(scene, "PileInspectPanel")


func _pile_inspect_rows(panel: Control) -> Array[Control]:
	var results: Array[Control] = []
	if panel == null:
		return results
	_collect_pile_inspect_rows(panel, results)
	return results


func _collect_pile_inspect_rows(node: Node, results: Array[Control]) -> void:
	if node == null:
		return
	if node is Control:
		var control := node as Control
		if control.name == "PileInspectRow" or (control.has_meta("pile_inspect_row") and bool(control.get_meta("pile_inspect_row"))):
			results.append(control)
	for child in node.get_children():
		_collect_pile_inspect_rows(child, results)


func _pile_inspect_card_names(panel: Control) -> Array[String]:
	var names: Array[String] = []
	for row in _pile_inspect_rows(panel):
		var label := row.find_child("PileInspectNameLabel", true, false)
		if label is Label:
			names.append((label as Label).text)
	return names


func _pile_inspect_row_texts(panel: Control) -> Array[String]:
	var texts: Array[String] = []
	for row in _pile_inspect_rows(panel):
		texts.append(_collect_label_text(row))
	return texts


func _mouse_left_press_event() -> InputEventMouseButton:
	return _mouse_left_press_at(Vector2(8, 8))


func _mouse_left_press_at(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	return event


func _keyboard_accept_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	event.echo = false
	return event


func _rect_inside(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x \
		and rect.position.y >= bounds.position.y \
		and rect.end.x <= bounds.end.x \
		and rect.end.y <= bounds.end.y


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
