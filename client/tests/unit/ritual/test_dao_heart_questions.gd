extends RefCounted

const ForgeStageScript = preload("res://scripts/ritual/forge_stage.gd")
const ForgeSceneScript = preload("res://scripts/ritual/forge_scene.gd")
const GlyphWorkshopScript = preload("res://scripts/ritual/glyph_workshop.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")

class ForgeSceneInputProbe:
	extends ForgeSceneScript

	var return_pressed_count := 0

	func _ready() -> void:
		pass

	func _on_return_pressed() -> void:
		return_pressed_count += 1


class GlyphWorkshopSizingProbe:
	extends GlyphWorkshopScript

	var fake_window := Window.new()

	func _ready() -> void:
		pass

	func _root_window() -> Window:
		return fake_window


class FakeAIGMService:
	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "pollution stage transition narration"


var _passed := 0
var _failed := 0
var _checkpoints: Array = []


func run() -> Dictionary:
	print("\n-- test_dao_heart_questions.gd --")
	await test_forge_stage_pauses_at_30_and_70_percent()
	await test_sfx_player_is_active_after_setup()
	await test_play_hit_sfx_restarts_inactive_generator()
	await test_input_handles_missing_viewport_gracefully()
	await test_input_in_tree_handles_cancel()
	test_project_window_uses_canvas_items_keep_aspect()
	await test_glyph_workshop_presents_structured_forge_workbench()
	await test_glyph_workshop_controls_fit_common_viewports()
	await test_glyph_workshop_uses_visible_canvas_size_before_physical_window()
	await test_reforge_button_is_visible_in_viewport()
	await test_reforge_button_disabled_without_branded_cards()
	await test_reforge_button_enabled_with_any_card_in_inventory()
	await test_reforge_button_enabled_with_branded_cards()
	await test_forge_scene_scales_stage_to_current_viewport()
	await test_forge_stage_scaled_mouse_click_hits_right_eye_lane()
	await test_abort_button_is_clickable_exit_surface()
	test_abort_button_interrupts_active_forge_stage()
	await test_forge_scene_shows_reforge_entry_when_branded_cards_exist()
	await test_forge_scene_records_two_star_choices_and_adjusts_rate()
	await test_wrong_dao_choice_adds_pollution_and_penalizes_rate()
	await test_wrong_dao_choice_routes_pollution_through_game_state_hooks()
	await test_dao_heart_dialog_shows_perfect_rate_preview()
	await test_dao_heart_dialog_fits_viewport()
	return {"passed": _passed, "failed": _failed}


func test_forge_stage_pauses_at_30_and_70_percent() -> void:
	_checkpoints.clear()
	var stage = ForgeStageScript.new()
	Engine.get_main_loop().root.add_child(stage)
	await Engine.get_main_loop().process_frame
	if not stage.has_signal("dao_heart_checkpoint_reached"):
		assert_true(false, "ForgeStage exposes dao_heart_checkpoint_reached")
		stage.queue_free()
		return
	stage.dao_heart_checkpoint_reached.connect(_on_checkpoint)
	stage.start_forge(_chart_with_notes(10), Chart.new())
	await Engine.get_main_loop().process_frame
	_mark_player_notes_judged(stage, 3)
	await Engine.get_main_loop().process_frame
	assert_eq(_checkpoints, [0.3], "30% checkpoint emitted once")
	assert_true(stage.is_paused_for_dao_question(), "stage pauses at 30% checkpoint")
	stage.resume_after_dao_question()
	_mark_player_notes_judged(stage, 7)
	await Engine.get_main_loop().process_frame
	assert_eq(_checkpoints, [0.3, 0.7], "70% checkpoint emitted after resume")
	assert_true(stage.is_paused_for_dao_question(), "stage pauses at 70% checkpoint")
	stage.queue_free()


func test_sfx_player_is_active_after_setup() -> void:
	var stage = ForgeStageScript.new()
	Engine.get_main_loop().root.add_child(stage)
	await Engine.get_main_loop().process_frame
	assert_true(stage._sfx_player != null, "ForgeStage creates a hit SFX player")
	assert_true(stage._sfx_player.playing, "ForgeStage keeps generator SFX player active after setup")
	stage.queue_free()


func test_play_hit_sfx_restarts_inactive_generator() -> void:
	var stage = ForgeStageScript.new()
	Engine.get_main_loop().root.add_child(stage)
	await Engine.get_main_loop().process_frame
	stage._sfx_player.stop()
	stage.call("_play_hit_sfx", "perfect")
	assert_true(stage._sfx_player.playing, "hit SFX restarts inactive generator playback before pushing samples")
	stage.queue_free()


func test_input_handles_missing_viewport_gracefully() -> void:
	var scene := _forge_scene_input_probe()
	scene.call("_input", _make_ui_cancel_event())
	assert_eq(scene.return_pressed_count, 0, "detached forge scene ignores ui_cancel without a viewport")
	scene.queue_free()


func test_input_in_tree_handles_cancel() -> void:
	var scene := _forge_scene_input_probe()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	assert_eq(scene._equip_buttons.size(), 0, "forge scene script probe does not keep null equip slot refs")
	scene._result_panel = PanelContainer.new()
	scene._result_panel.visible = false
	scene.call("_input", _make_ui_cancel_event())
	assert_eq(scene.return_pressed_count, 1, "forge scene ui_cancel triggers return while inside tree")
	scene.queue_free()


func test_project_window_uses_canvas_items_keep_aspect() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 1280, "project viewport width uses 1280 baseline")
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 720, "project viewport height uses 720 baseline")
	assert_eq(int(ProjectSettings.get_setting("display/window/size/mode")), 3, "project launches in common fullscreen mode")
	assert_eq(int(ProjectSettings.get_setting("display/window/size/window_width_override")), 0, "project does not force an oversized debug window width")
	assert_eq(int(ProjectSettings.get_setting("display/window/size/window_height_override")), 0, "project does not force an oversized debug window height")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/mode")), "canvas_items", "project uses canvas_items stretch mode")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/aspect")), "keep", "project keeps the 16:9 canvas aspect in fullscreen without stretching the UI")
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "gl_compatibility", "project uses Compatibility rendering to avoid Vulkan swapchain resize failures on 2D UI")


func test_glyph_workshop_presents_structured_forge_workbench() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.cards_inventory.clear()
	var workshop = await _glyph_workshop()
	if workshop == null:
		GameState.from_dict(previous)
		return
	for node_name in [
		"ForgeWorkshopTitle",
		"ForgeStatusBar",
		"SymbolPalettePanel",
		"ArrangementPanel",
		"ReactionPreviewPanel",
		"ForgeActionBar",
	]:
		assert_true(workshop.find_child(node_name, true, false) != null, "glyph workshop exposes structured UI node %s" % node_name)
	var title = workshop.find_child("ForgeWorkshopTitle", true, false)
	if title is Label:
		assert_true(str((title as Label).text).strip_edges().length() >= 4, "forge workshop title is visible and specific")
	var confirm = workshop.find_child("ConfirmButton", true, false)
	var reforge = workshop.find_child("ReforgeEntryButton", true, false)
	assert_true(confirm is Button and (confirm as Button).custom_minimum_size.y >= 48.0, "forge confirm keeps a 48px+ action target")
	assert_true(reforge is Button and (reforge as Button).custom_minimum_size.y >= 48.0, "reforge entry keeps a 48px+ action target")
	workshop.queue_free()
	GameState.from_dict(previous)


func test_glyph_workshop_controls_fit_common_viewports() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.cards_inventory.clear()
	GameState.cards_inventory.append(_branded_card("layout_branded_card"))
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size = root.size
	for size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await Engine.get_main_loop().process_frame
		var workshop = await _glyph_workshop()
		if workshop == null:
			root.size = original_size
			GameState.from_dict(previous)
			return
		await Engine.get_main_loop().process_frame
		var viewport_rect: Rect2 = workshop.get_viewport_rect()
		for node_name in ["ForgeStatusBar", "SymbolPalettePanel", "ArrangementPanel", "ReactionPreviewPanel", "ForgeActionBar", "ConfirmButton", "ReturnButton", "ReforgeEntryButton"]:
			var control = workshop.find_child(node_name, true, false)
			assert_true(control is Control and viewport_rect.encloses((control as Control).get_global_rect()), "%s fits inside visible canvas for window %s" % [node_name, str(size)])
		workshop.queue_free()
	root.size = original_size
	GameState.from_dict(previous)


func test_glyph_workshop_uses_visible_canvas_size_before_physical_window() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size = root.size
	root.size = Vector2i(1280, 720)
	await Engine.get_main_loop().process_frame
	var probe := GlyphWorkshopSizingProbe.new()
	probe.fake_window.size = Vector2i(1920, 1080)
	root.add_child(probe)
	await Engine.get_main_loop().process_frame
	var visible_size := probe.get_viewport().get_visible_rect().size
	var runtime_size: Vector2 = probe.call("_runtime_window_size")
	assert_eq(Vector2i(roundi(runtime_size.x), roundi(runtime_size.y)), Vector2i(roundi(visible_size.x), roundi(visible_size.y)), "glyph workshop sizes itself from the visible canvas before the physical window")
	assert_true(runtime_size.x < float(probe.fake_window.size.x) and runtime_size.y < float(probe.fake_window.size.y), "glyph workshop ignores oversized physical window dimensions under keep-aspect stretch")
	probe.fake_window.free()
	probe.queue_free()
	root.size = original_size


func test_reforge_button_is_visible_in_viewport() -> void:
	var previous: Dictionary = GameState.to_dict()
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size = root.size
	root.size = Vector2i(960, 540)
	GameState.cards_inventory.clear()
	GameState.pending_forge_arrangement.clear()
	GameState.cards_inventory.append(_branded_card("viewport_branded_card"))
	var workshop = await _glyph_workshop()
	if workshop == null:
		root.size = original_size
		GameState.from_dict(previous)
		return
	await Engine.get_main_loop().process_frame
	var button = workshop.find_child("ReforgeEntryButton", true, false)
	assert_true(button != null and button.visible, "reforge button is visible at 960x540 in glyph workshop")
	if button != null:
		assert_rect_within(button.get_global_rect(), workshop.get_viewport_rect(), "reforge button stays inside viewport")
	workshop.queue_free()
	root.size = original_size
	GameState.from_dict(previous)


func test_reforge_button_disabled_without_branded_cards() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.cards_inventory.clear()
	GameState.pending_forge_arrangement.clear()
	var workshop = await _glyph_workshop()
	if workshop == null:
		GameState.from_dict(previous)
		return
	var button = workshop.find_child("ReforgeEntryButton", true, false)
	assert_true(button != null, "reforge button is mounted on glyph workshop")
	if button != null:
		assert_true(button.disabled, "reforge button is disabled with empty card inventory")
		assert_true(button.tooltip_text.contains("卡库空"), "disabled reforge button explains empty inventory")
	workshop.queue_free()
	GameState.from_dict(previous)


func test_reforge_button_enabled_with_any_card_in_inventory() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.cards_inventory.clear()
	GameState.pending_forge_arrangement.clear()
	GameState.cards_inventory.append(CardScript.from_json({
		"id": "plain_card",
		"template_id": "shadow_arrow",
		"display_name": "Plain Test Card",
		"quality": 3,
		"brands": [],
	}))
	var workshop = await _glyph_workshop()
	if workshop == null:
		GameState.from_dict(previous)
		return
	var button = workshop.find_child("ReforgeEntryButton", true, false)
	assert_true(button != null, "reforge button mounts on workshop with a card present")
	if button != null:
		assert_true(not button.disabled, "reforge button is enabled (default reforge needs no brand)")
	workshop.queue_free()
	GameState.from_dict(previous)


func test_reforge_button_enabled_with_branded_cards() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.cards_inventory.clear()
	GameState.pending_forge_arrangement.clear()
	GameState.cards_inventory.append(_branded_card("enabled_branded_card"))
	var workshop = await _glyph_workshop()
	if workshop == null:
		GameState.from_dict(previous)
		return
	var button = workshop.find_child("ReforgeEntryButton", true, false)
	assert_true(button != null, "reforge button is mounted with branded card")
	if button != null:
		assert_true(not button.disabled, "reforge button is enabled with branded cards")
	workshop.queue_free()
	GameState.from_dict(previous)


func test_forge_scene_scales_stage_to_current_viewport() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size = root.size
	root.size = Vector2i(1280, 720)
	var scene = await _forge_scene()
	if scene == null:
		root.size = original_size
		return
	var stage = ForgeStageScript.new()
	scene.add_child(stage)
	scene._stage = stage
	await Engine.get_main_loop().process_frame
	if not scene.has_method("_layout_runtime_ui"):
		assert_true(false, "forge scene exposes runtime layout for scaled rhythm stage")
		scene.queue_free()
		root.size = original_size
		return
	scene.call("_layout_runtime_ui")
	await Engine.get_main_loop().process_frame
	var stage_size: Vector2 = ForgeStageScript.VIEWPORT * stage.scale
	assert_true(stage.scale.x > 1.0 and stage.scale.y > 1.0, "forge rhythm stage scales above the legacy 960x540 footprint at 1280x720")
	assert_true(stage_size.x >= 1050.0 and stage_size.y >= 590.0, "forge rhythm stage uses most of the available viewport")
	assert_rect_within(Rect2(stage.global_position, stage_size), scene.get_viewport_rect(), "scaled forge rhythm stage stays inside viewport")
	scene.queue_free()
	root.size = original_size


func test_forge_stage_scaled_mouse_click_hits_right_eye_lane() -> void:
	var stage = ForgeStageScript.new()
	Engine.get_main_loop().root.add_child(stage)
	await Engine.get_main_loop().process_frame
	stage.global_position = Vector2(24.0, 18.0)
	stage.scale = Vector2(1.25, 1.25)
	var note_time_ms := 9000
	var mouse_chart = Chart.new(12000.0, 120.0, [{"id": 1, "time_ms": note_time_ms, "lane": 3}], "mouse_scaled_test", {}, [])
	stage.start_forge(Chart.new(), mouse_chart)
	await Engine.get_main_loop().process_frame
	var visible_lane_center := stage.to_global(Vector2(ForgeStageScript.MOUSE_LANE_X[3], ForgeStageScript.MOUSE_JUDGE_Y))
	stage.call("_handle_mouse_click", visible_lane_center, note_time_ms)
	assert_eq(int(stage._mouse_summary.get("perfect", 0)), 1, "scaled forge stage maps visible right-side heart-eye clicks back to local lanes")
	stage.queue_free()
	await Engine.get_main_loop().process_frame


func test_abort_button_is_clickable_exit_surface() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size = root.size
	root.size = Vector2i(960, 540)
	var scene = await _forge_scene()
	if scene == null:
		root.size = original_size
		return
	await Engine.get_main_loop().process_frame
	var button = scene.find_child("AbortButton", true, false)
	assert_true(button is Button and (button as Button).visible, "forge scene exposes a visible abort button")
	if button is Button:
		assert_true((button as Button).custom_minimum_size.y >= 48.0, "abort button keeps a 48px+ click target")
		assert_rect_within((button as Control).get_global_rect(), scene.get_viewport_rect(), "abort button stays inside viewport")
	scene.queue_free()
	root.size = original_size


func test_abort_button_interrupts_active_forge_stage() -> void:
	var scene = ForgeSceneScript.new()
	assert_true(scene.has_signal("forge_aborted"), "forge scene exposes forge_aborted signal for interrupt exit")
	assert_true(scene.has_method("_on_abort_pressed"), "forge scene exposes a dedicated abort callback")
	if not scene.has_signal("forge_aborted") or not scene.has_method("_on_abort_pressed"):
		scene.queue_free()
		return
	var emitted: Array = []
	scene.connect("forge_aborted", func(): emitted.append("aborted"))
	scene._stage = ForgeStageScript.new()
	scene._finished = false
	scene.call("_on_abort_pressed")
	assert_eq(emitted, ["aborted"], "abort button emits forge_aborted")
	assert_true(scene._stage == null, "abort button clears the active forge stage")
	assert_true(scene._finished, "abort button marks forge scene finished so no result settlement runs")
	scene.queue_free()


func test_forge_scene_records_two_star_choices_and_adjusts_rate() -> void:
	var scene = await _forge_scene()
	if scene == null:
		return
	scene.show_dao_heart_question(0.3)
	assert_true(scene.is_dao_heart_question_visible(), "dao-heart panel is visible at checkpoint")
	assert_eq(scene.get_dao_heart_option_count(), 3, "dao-heart panel exposes A/B/C")
	scene.answer_dao_heart_option(1)
	scene.show_dao_heart_question(0.7)
	scene.answer_dao_heart_option(1)
	assert_eq(scene.get_dao_choices(), ["★★", "★★"], "two B choices record all ★★")
	assert_almost_eq(scene.apply_dao_heart_to_perfect_rate(0.94), 0.98, 0.0001, "two ★★ answers add +0.04 perfect_rate")
	scene.queue_free()


func test_forge_scene_shows_reforge_entry_when_branded_cards_exist() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.cards_inventory.clear()
	GameState.pending_forge_arrangement.clear()
	GameState.cards_inventory.append(_branded_card("branded_card"))
	GameState.pending_reforge = {"card_id": "branded_card", "mode": "default"}
	var scene = await _forge_scene()
	if scene == null:
		GameState.from_dict(previous)
		return
	assert_true(scene._reforge_source_card != null, "forge scene picks up reforge target from pending_reforge")
	if scene._reforge_source_card != null:
		assert_eq(str(scene._reforge_source_card.id), "branded_card", "forge scene uses correct reforge source")
	assert_eq(scene._reforge_mode, "default", "forge scene uses pending reforge mode")
	assert_true(GameState.pending_reforge.is_empty(), "forge scene clears pending_reforge after consuming")
	scene.queue_free()
	GameState.from_dict(previous)


func test_wrong_dao_choice_adds_pollution_and_penalizes_rate() -> void:
	var scene = await _forge_scene()
	if scene == null:
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.pollution = 10
	scene.set_game_state(gs)
	scene.show_dao_heart_question(0.3)
	scene.answer_dao_heart_option(2)
	assert_eq(gs.pollution, 15, "wrong dao-heart answer adds +5 pollution")
	assert_eq(scene.get_dao_choices(), ["×"], "wrong option records × choice")
	assert_almost_eq(scene.apply_dao_heart_to_perfect_rate(0.80), 0.75, 0.0001, "wrong answer applies -0.05 perfect_rate")
	scene.queue_free()


func test_wrong_dao_choice_routes_pollution_through_game_state_hooks() -> void:
	var scene = await _forge_scene()
	if scene == null:
		return
	var gs = GameStateScript.new()
	gs._ready()
	var fake_service := FakeAIGMService.new()
	var emitted: Array = []
	gs.set_ai_gm_service(fake_service)
	gs.pollution = 49
	gs.pollution_stage = 1
	gs.pollution_stage_changed.connect(_record_stage_signal.bind(emitted))
	scene.set_game_state(gs)
	scene.show_dao_heart_question(0.3)
	scene.answer_dao_heart_option(2)
	assert_eq(gs.pollution, 54, "wrong dao-heart answer keeps +5 pollution through GameState")
	assert_eq(gs.pollution_stage, 2, "wrong dao-heart answer crosses into stage 2")
	assert_eq(emitted, [[1, 2]], "wrong dao-heart answer emits pollution_stage_changed")
	assert_eq(fake_service.calls.size(), 1, "wrong dao-heart answer calls pollution-stage AI GM once")
	if fake_service.calls.size() > 0:
		var ctx = fake_service.calls[0]
		assert_eq(str(ctx.scene), "pollution_stage_transition", "wrong dao-heart answer uses pollution_stage_transition scene")
		assert_eq(str(ctx.fallback_template_pool), "POLLUTION_STAGE_TEMPLATES", "wrong dao-heart answer uses pollution-stage fallback pool")
	scene.queue_free()


func test_dao_heart_dialog_shows_perfect_rate_preview() -> void:
	var scene = await _forge_scene()
	if scene == null:
		return
	scene.show_dao_heart_question(0.3)
	var text := _collect_control_text(scene)
	assert_true(text.contains("perfect_rate"), "dao-heart dialog shows perfect_rate preview")
	assert_true(text.contains("评级预测"), "dao-heart dialog shows rating preview")
	assert_true(text.contains("A：维持"), "dao-heart dialog explains A consequence")
	assert_true(text.contains("B：稳一手 +0.02"), "dao-heart dialog explains B consequence")
	assert_true(text.contains("C：放弃"), "dao-heart dialog explains C consequence")
	scene.queue_free()


func test_dao_heart_dialog_fits_viewport() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var original_size = root.size
	root.size = Vector2i(960, 540)
	var scene = await _forge_scene()
	if scene == null:
		root.size = original_size
		return
	scene.show_dao_heart_question(0.3)
	await Engine.get_main_loop().process_frame
	var panel = scene.find_child("DaoHeartQuestionPanel", true, false)
	assert_true(panel != null and panel.visible, "dao-heart dialog is visible for viewport fit check")
	if panel != null:
		assert_rect_within(panel.get_global_rect(), scene.get_viewport_rect(), "dao-heart dialog stays inside viewport")
		var body_labels: Array[Label] = []
		_collect_named_labels(panel, "DaoHeartLine", body_labels)
		assert_eq(body_labels.size(), 5, "dao-heart dialog lays out five body text labels")
		for label in body_labels:
			assert_true(label.get_minimum_size().y > 0.0, "%s has non-zero minimum height" % label.name)
	scene.queue_free()
	root.size = original_size


func _forge_scene():
	var packed = load("res://scenes/ritual/forge_phigros.tscn")
	if packed == null or not packed.can_instantiate():
		assert_true(false, "forge_phigros scene loads")
		return null
	var scene = packed.instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	return scene


func _glyph_workshop():
	var packed = load("res://scenes/ritual/glyph_workshop.tscn")
	if packed == null or not packed.can_instantiate():
		assert_true(false, "glyph_workshop scene loads")
		return null
	var scene = packed.instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	return scene


func _forge_scene_input_probe() -> ForgeSceneInputProbe:
	var scene := ForgeSceneInputProbe.new()
	scene._result_panel = PanelContainer.new()
	scene._result_panel.visible = false
	return scene


func _branded_card(card_id: String):
	return CardScript.from_json({
		"id": card_id,
		"template_id": "shadow_arrow",
		"display_name": "Branded Test Card",
		"quality": 4,
		"brands": ["forge_residue_low"],
	})


func _chart_with_notes(count: int):
	var notes: Array = []
	for i in range(count):
		notes.append({"id": i, "time_ms": 100000 + i * 1000, "lane": i % 4})
	return Chart.new(120000.0, 120.0, notes, "dao_test", {}, [])


func _mark_player_notes_judged(stage, count: int) -> void:
	for i in range(min(count, stage._player_notes.size())):
		if is_instance_valid(stage._player_notes[i]):
			stage._player_notes[i].judged = true


func _on_checkpoint(checkpoint: float) -> void:
	_checkpoints.append(checkpoint)


func _record_stage_signal(from_stage: int, to_stage: int, output: Array) -> void:
	output.append([from_stage, to_stage])


func _make_ui_cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func _collect_named_labels(node: Node, prefix: String, output: Array[Label]) -> void:
	if node is Label and str(node.name).begins_with(prefix):
		output.append(node)
	for child in node.get_children():
		_collect_named_labels(child, prefix, output)


func assert_rect_within(actual: Rect2, bounds: Rect2, message: String) -> void:
	var actual_right := actual.position.x + actual.size.x
	var actual_bottom := actual.position.y + actual.size.y
	var bounds_right := bounds.position.x + bounds.size.x
	var bounds_bottom := bounds.position.y + bounds.size.y
	var inside := actual.position.x >= bounds.position.x - 0.01 \
		and actual.position.y >= bounds.position.y - 0.01 \
		and actual_right <= bounds_right + 0.01 \
		and actual_bottom <= bounds_bottom + 0.01
	assert_true(inside, "%s (%s within %s)" % [message, str(actual), str(bounds)])


func _collect_control_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	elif node is Button:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_control_text(child)
	return text


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


func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) <= tolerance:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected %.4f, got %.4f" % [message, expected, actual])
