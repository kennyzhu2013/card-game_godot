extends SceneTree


func _init() -> void:
	print("=== Forge Workbench UI Tests ===")
	await process_frame
	var script := load("res://tests/unit/ritual/test_dao_heart_questions.gd")
	if script == null or not script.can_instantiate():
		print("  FAIL: forge workbench test script loads")
		quit(1)
		return
	var suite = script.new()
	await suite.test_glyph_workshop_presents_structured_forge_workbench()
	await suite.test_glyph_workshop_controls_fit_common_viewports()
	await suite.test_glyph_workshop_uses_visible_canvas_size_before_physical_window()
	await suite.test_reforge_button_is_visible_in_viewport()
	await suite.test_forge_scene_scales_stage_to_current_viewport()
	await suite.test_forge_stage_scaled_mouse_click_hits_right_eye_lane()
	await suite.test_abort_button_is_clickable_exit_surface()
	suite.test_abort_button_interrupts_active_forge_stage()
	await process_frame
	var passed := int(suite._passed)
	var failed := int(suite._failed)
	print("\n=== Forge Workbench Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
