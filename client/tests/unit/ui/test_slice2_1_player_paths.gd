extends RefCounted

const MeditationServiceScript = preload("res://scripts/world/meditation_service.gd")
const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")
const CardScript = preload("res://scripts/combat/card.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_slice2_1_player_paths.gd --")
	await test_cushion_exit_button_closes_without_exp_gain()
	await test_cushion_escape_closes_without_exp_gain()
	await test_cushion_breathing_result_shows_fog_bonus()
	await test_cushion_sunny_result_hides_weather_bonus()
	await test_forge_result_panel_shows_fog_material_bonus()
	await test_forge_result_panel_shows_ai_gm_text()
	await test_notice_board_commission_accept_execute_complete_player_flow()
	await test_commission_panel_rejects_repeat_execute_and_complete()
	await test_hub_promotion_pending_shows_ready_prompt_and_enters_tower()
	await test_hub_promotion_progress_shows_remaining_requirements()
	await test_sleep_to_day3_shows_independent_mainline_prompt()
	await test_district_selector_lists_city_rows_without_legacy_event_hint()
	return {"passed": _passed, "failed": _failed}


func test_cushion_exit_button_closes_without_exp_gain() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.sequence_exp = 0
	GameState.meditation_count_today = 0
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var cushion = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/CushionButton")
	cushion.pressed.emit()
	await Engine.get_main_loop().process_frame
	var panel = hub.get_node_or_null("CushionMeditation")
	assert_true(panel != null and panel.visible, "player click opens cushion meditation panel")
	var exit_button = panel.find_child("MeditationExitButton", true, false) if panel != null else null
	assert_true(exit_button is Button, "meditation panel has visible exit button")
	if exit_button is Button:
		exit_button.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true(not panel.visible, "exit button closes meditation panel")
	assert_eq(int(GameState.sequence_exp), 0, "exiting before settlement grants no sequence_exp")
	hub.queue_free()
	GameState.from_dict(previous)


func test_cushion_escape_closes_without_exp_gain() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.sequence_exp = 0
	GameState.meditation_count_today = 0
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_on_zone_pressed", "cushion")
	await Engine.get_main_loop().process_frame
	var panel = hub.get_node_or_null("CushionMeditation")
	assert_true(panel != null and panel.visible, "cushion zone opens meditation panel before ESC")
	if panel != null:
		assert_true(panel.has_method("_input"), "meditation panel listens to ESC")
		if panel.has_method("_input"):
			panel.call("_input", _ui_action("ui_cancel"))
			await Engine.get_main_loop().process_frame
			assert_true(not panel.visible, "ESC closes meditation panel")
	assert_eq(int(GameState.sequence_exp), 0, "ESC before settlement grants no sequence_exp")
	hub.queue_free()
	GameState.from_dict(previous)


func test_cushion_breathing_result_shows_fog_bonus() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.sequence_exp = 0
	GameState.meditation_count_today = 0
	GameState.current_weather = "fog"
	GameState.pathway = "fool"
	var panel = await _cushion_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var hit_button = panel.find_child("BreathHitButton", true, false)
	assert_true(hit_button is Button, "breathing panel has hit button")
	if hit_button is Button and panel.has_method("set_next_judgement_for_test"):
		var hit_count := int(panel.call("breath_cycle_count")) * 2 if panel.has_method("breath_cycle_count") else 12
		for i in range(hit_count):
			panel.call("set_next_judgement_for_test", "perfect")
			hit_button.pressed.emit()
			await Engine.get_main_loop().process_frame
	var label = panel.find_child("MeditationResultLabel", true, false)
	assert_true(label != null and label.text.contains("天气加成 +20% 序列经验（20→24）"), "fog result panel shows visible weather bonus")
	assert_eq(int(GameState.sequence_exp), 24, "breathing judgement routes to MeditationService with fog bonus")
	panel.queue_free()
	GameState.from_dict(previous)


func test_cushion_sunny_result_hides_weather_bonus() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.sequence_exp = 0
	GameState.meditation_count_today = 0
	GameState.current_weather = "sunny"
	GameState.pathway = "fool"
	var panel = await _cushion_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var result: Dictionary = panel.call("settle_for_test", {"perfect": 6, "good": 0, "bad": 0, "miss": 0})
	assert_true(bool(result.get("ok", false)), "sunny breathing settlement succeeds")
	var label = panel.find_child("MeditationResultLabel", true, false)
	assert_true(label != null and not label.text.contains("天气加成"), "sunny result panel hides weather bonus line")
	panel.queue_free()
	GameState.from_dict(previous)


func test_forge_result_panel_shows_fog_material_bonus() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.pending_forge_arrangement.clear()
	GameState.pending_reforge = {}
	var scene = await _forge_scene()
	if scene == null:
		GameState.from_dict(previous)
		return
	var card = CardScript.from_json({
		"id": "fog_result_card",
		"template_id": "shadow_arrow",
		"display_name": "Fog Result Card",
		"quality": 3,
		"damage": 12,
		"energy_cost": 1,
	})
	scene.call("_show_result_panel", {
		"quality": {"id": 3, "name": "普品", "stars": 3},
		"forged_card": card,
		"combined_summary": {"perfect": 4, "good": 1, "bad": 0, "miss": 0},
		"perfect_rate": 0.8,
		"forge_weather_bonus_percent": 20,
		"material_outputs": {"愚者残页": 4},
	})
	await Engine.get_main_loop().process_frame
	var detail = scene.find_child("ResultDetail", true, false)
	assert_true(detail != null and detail.text.contains("天气加成 +20% 锻造材料"), "forge result panel shows visible weather material bonus")
	scene.queue_free()
	GameState.from_dict(previous)


func test_forge_result_panel_shows_ai_gm_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.pending_forge_arrangement.clear()
	GameState.pending_reforge = {}
	var scene = await _forge_scene()
	if scene == null:
		GameState.from_dict(previous)
		return
	var card = CardScript.from_json({
		"id": "ai_gm_result_card",
		"template_id": "shadow_arrow",
		"display_name": "AI GM Result Card",
		"quality": 3,
		"damage": 12,
		"energy_cost": 1,
	})
	scene.call("_show_result_panel", {
		"quality": {"id": 3, "name": "Fine", "stars": 3},
		"forged_card": card,
		"combined_summary": {"perfect": 4, "good": 1, "bad": 0, "miss": 0},
		"perfect_rate": 0.8,
		"ai_gm_text": "forge ai gm visible text",
	})
	await Engine.get_main_loop().process_frame
	var detail = scene.find_child("ResultDetail", true, false)
	assert_true(detail != null and detail.text.contains("forge ai gm visible text"), "forge result panel shows AI GM narration")
	scene.queue_free()
	GameState.from_dict(previous)


func test_notice_board_commission_accept_execute_complete_player_flow() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	_setup_commission_state()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var notice = hub.get_node("MarginContainer/VBoxContainer/ZoneGrid/NoticeBoardButton")
	notice.pressed.emit()
	await Engine.get_main_loop().process_frame
	var panel = hub.get_node_or_null("CommissionBoard")
	assert_true(panel != null and panel.visible, "notice board opens commission panel")
	var action = panel.find_child("CommissionActionButton_runner_job", true, false) if panel != null else null
	assert_true(action is Button, "runner commission action button exists")
	if action is Button:
		assert_eq(str(action.text), "接受", "initial commission button says accept")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true("runner_job" in GameState.accepted_commissions, "accept writes accepted_commissions")
		assert_eq(str(action.text), "执行", "accepted commission button says execute")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_eq(str(GameState.get_meta("commission_pending_completion", "")), "runner_job", "execute marks pending completion")
		assert_eq(str(action.text), "完成", "executed commission button says complete")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true(not "runner_job" in GameState.accepted_commissions, "complete removes accepted commission")
		assert_true("runner_job" in GameState.completed_commissions, "complete records completed commission")
		assert_eq(str(action.text), "已完成", "completed commission button says completed")
	hub.queue_free()
	GameState.from_dict(previous)


func test_commission_panel_rejects_repeat_execute_and_complete() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	_setup_commission_state()
	var panel = await _commission_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	panel.call("_accept_commission", "runner_job")
	var executed: Dictionary = panel.call("_execute_commission", "runner_job")
	assert_true(bool(executed.get("ok", false)), "commission panel execute succeeds once")
	var repeated_execute: Dictionary = panel.call("_execute_commission", "runner_job")
	assert_true(not bool(repeated_execute.get("ok", true)), "commission panel repeated execute is rejected")
	assert_eq(str(repeated_execute.get("reason", "")), "already_pending", "repeated execute returns already_pending")
	var completed: Dictionary = panel.call("_complete_commission", "runner_job")
	assert_true(bool(completed.get("ok", false)), "commission panel complete succeeds once")
	var repeated_complete: Dictionary = panel.call("_complete_commission", "runner_job")
	assert_true(not bool(repeated_complete.get("ok", true)), "commission panel repeated complete is rejected")
	assert_eq(str(repeated_complete.get("reason", "")), "already_completed", "repeated complete returns already_completed")
	var status = panel.find_child("CommissionStatusLabel", true, false)
	assert_true(status != null and status.text.contains("已经交差"), "commission panel shows repeat complete reason in Chinese")
	panel.queue_free()
	GameState.from_dict(previous)


func test_hub_promotion_pending_shows_ready_prompt_and_enters_tower() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	_configure_promotable_8_to_7()
	var check: Dictionary = PromotionRitualServiceScript.check_after_exp_gain(GameState)
	assert_true(bool(check.get("can_promote", false)), "test setup reaches promotion gate")
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_refresh_promotion_button")
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("PromotionReadyDialog")
	assert_true(dialog != null and dialog.visible, "Hub shows promotion ready prompt from pending meta")
	if dialog != null:
		assert_true(dialog.dialog_text.contains("可以晋升了"), "promotion ready prompt gives visible guidance")
	var button = hub.find_child("PromotionButton", true, false)
	assert_true(button != null and button.visible, "promotion button visible when gate is satisfied")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
		var runner = hub.get_node_or_null("TowerRunner")
		assert_true(runner != null and runner.visible, "clicking promotion button enters ritual tower")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_promotion_progress_shows_remaining_requirements() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.sequence = 8
	GameState.sequence_exp = 120
	GameState.pollution = 20
	GameState.known_reactions.clear()
	for i in range(10):
		GameState.known_reactions.append("rx_%d" % i)
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_refresh_promotion_button")
	await Engine.get_main_loop().process_frame
	var label = hub.find_child("PromotionProgressLabel", true, false)
	assert_true(label != null and label.visible, "promotion progress stays visible before gate is satisfied")
	if label != null:
		assert_true(label.text.contains("还差 130 经验"), "progress label shows remaining exp")
		assert_true(label.text.contains("还差 8 反应"), "progress label shows remaining reactions")
	hub.queue_free()
	GameState.from_dict(previous)


func test_sleep_to_day3_shows_independent_mainline_prompt() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	GameState.day = 2
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.time_of_day = "night"
	GameState.current_weather = "sunny"
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_confirm_sleep")
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("MainlineDialog")
	assert_true(dialog != null and dialog.visible, "sleeping into Day 3 shows independent mainline prompt")
	if dialog != null:
		assert_true(dialog.title.contains("主线·Day3"), "mainline prompt title names Day3")
		assert_true(str(dialog.dialog_text).length() > 0, "mainline prompt has body text")
	hub.queue_free()
	GameState.from_dict(previous)


func test_district_selector_lists_city_rows_without_legacy_event_hint() -> void:
	var previous: Dictionary = GameState.to_dict()
	_clear_slice21_meta()
	var panel = await _district_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var rows: Array = []
	_collect_buttons_with_prefix(panel, "DistrictRow_", rows)
	assert_eq(rows.size(), 6, "district selector lists six city rows")
	var hint = panel.find_child("DistrictHintLabel", true, false)
	assert_true(hint == null, "district selector no longer shows legacy event/tower hint")
	panel.queue_free()
	GameState.from_dict(previous)


func _hub():
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _cushion_panel():
	var scene = load("res://scenes/hub/cushion_meditation.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "cushion meditation scene loads")
		return null
	var panel = scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	return panel


func _commission_panel():
	if not ResourceLoader.exists("res://scenes/ui/commission_board.tscn"):
		assert_true(false, "commission board scene loads")
		return null
	var scene = load("res://scenes/ui/commission_board.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "commission board scene loads")
		return null
	var panel = scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	return panel


func _district_panel():
	var scene = load("res://scenes/ui/district_select.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "district select scene loads")
		return null
	var panel = scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	return panel


func _collect_buttons_with_prefix(node: Node, prefix: String, result: Array) -> void:
	if node is Button and str(node.name).begins_with(prefix):
		result.append(node)
	for child in node.get_children():
		_collect_buttons_with_prefix(child, prefix, result)


func _forge_scene():
	var scene = load("res://scenes/ritual/forge_phigros.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "forge scene loads")
		return null
	var panel = scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	return panel


func _setup_commission_state() -> void:
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.sequence_exp = 0
	GameState.time_of_day = "morning"
	GameState.available_commissions.clear()
	GameState.accepted_commissions.clear()
	GameState.completed_commissions.clear()
	GameState.available_commissions.append({
		"id": "runner_job",
		"title": "跑腿委托",
		"description": "把一封信送到影巷口。",
		"includes_tower": false,
	})


func _configure_promotable_8_to_7() -> void:
	GameState.sequence = 8
	GameState.sequence_exp = 250
	GameState.pollution = 20
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.time_of_day = "morning"
	GameState.current_weather = "sunny"
	GameState.known_reactions.clear()
	for i in range(18):
		GameState.known_reactions.append("rx_%d" % i)
	GameState.daodian["completed_main_story_nodes"] = ["node_4b_promotion_87"]
	GameState.paper_blade_kill_count = 1
	GameState.promotion_cooldown_until_day = 0
	GameState.promotion_cooldown_gate_id = ""
	GameState.active_contract.clear()
	for rule_id in ["rule_a", "rule_b", "rule_c"]:
		GameState.active_contract.append(rule_id)


func _clear_slice21_meta() -> void:
	for key in [
		"promotion_prompt_pending",
		"promotion_prompt_gate_id",
		"commission_pending_completion",
		"commission_pending_includes_tower",
		"mainline_popup_pending",
		"mainline_popup_text",
		"mainline_popup_title",
		"mainline_day",
		"force_sleep_pending",
	]:
		if GameState.has_meta(key):
			GameState.remove_meta(key)


func _ui_action(action_name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	return event


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
