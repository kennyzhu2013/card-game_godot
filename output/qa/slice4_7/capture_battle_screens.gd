extends SceneTree

const CardScript = preload("res://scripts/combat/card.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const BattleCardViewScript = preload("res://scripts/ui/battle/battle_card_view.gd")
const EnemyStandeeScript = preload("res://scripts/ui/battle/enemy_standee.gd")

const SCENE_PATH := "res://scenes/combat/battle_scene.tscn"
const OUT_DIR_RES := "res://../output/qa/slice4_7"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_dir_res := OS.get_environment("SLICE47_CAPTURE_OUT_DIR").strip_edges()
	if out_dir_res.is_empty():
		out_dir_res = OUT_DIR_RES
	var out_dir := ProjectSettings.globalize_path(out_dir_res)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shots := [
		{"size": Vector2i(1280, 720), "state": "fresh", "file": "battle_1280x720_fresh-turn.png"},
		{"size": Vector2i(1280, 720), "state": "drag", "file": "battle_1280x720_drag-in-progress.png"},
		{"size": Vector2i(1280, 720), "state": "victory", "file": "battle_1280x720_victory.png"},
		{"size": Vector2i(1366, 768), "state": "fresh", "file": "battle_1366x768_fresh-turn.png"},
		{"size": Vector2i(1920, 1080), "state": "expanded_log", "file": "battle_1920x1080_fresh-turn-expanded-log.png"},
	]
	var failed := false
	for shot in shots:
		var ok := await _capture_shot(shot, out_dir)
		failed = failed or not ok
	quit(1 if failed else 0)


func _capture_shot(shot: Dictionary, out_dir: String) -> bool:
	var viewport := SubViewport.new()
	viewport.name = "Slice47CaptureViewport"
	viewport.size = shot["size"]
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var host := Control.new()
	host.name = "Slice47CaptureHost"
	host.position = Vector2.ZERO
	host.size = Vector2(shot["size"])
	host.clip_contents = true
	viewport.add_child(host)

	var scene = load(SCENE_PATH).instantiate()
	if scene == null:
		push_error("Could not instantiate %s" % SCENE_PATH)
		viewport.queue_free()
		return false
	scene.name = "Slice47CaptureBattleScene"
	host.add_child(scene)
	if scene is Control:
		(scene as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(scene as Control).offset_left = 0
		(scene as Control).offset_top = 0
		(scene as Control).offset_right = 0
		(scene as Control).offset_bottom = 0
	await process_frame

	var cards := _make_cards()
	var enemies := _make_enemies()
	var game_state = _make_state()
	var player = _make_player()
	scene.start_battle(cards, [], enemies, ["rule_use_debuff", "rule_no_consecutive_attack"] as Array[String], player, game_state)
	await process_frame
	scene._battle.energy = 99
	scene._battle.hand = cards
	scene._battle.draw_pile = cards.slice(0, 3)
	scene._battle.discard_pile = cards.slice(3, 5)
	scene._battle.charged_zone = [
		{"source_card": cards[0], "remaining": 2},
		{"source_card": cards[1], "remaining": 1},
	]
	scene._battle.field_state["flame_markers"] = 4
	scene._battle.field_state["adjacent_burn"] = 3
	for i in range(12):
		scene.call("_set_last_action_message", "Slice 4.7 screenshot log entry %02d with constrained battle copy." % i)
	scene.call("_render")
	await process_frame
	_prepare_hand_cards_for_owner_capture(scene)
	await process_frame

	match str(shot["state"]):
		"drag":
			_apply_drag_state(scene, cards[0])
		"victory":
			scene.call("_show_reward_picker")
		"expanded_log":
			scene.call("_set_battle_log_drawer_expanded", true)
		_:
			pass
	await process_frame
	for _i in range(4):
		await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		push_error("Capture viewport has no texture for %s" % str(shot["file"]))
		viewport.queue_free()
		await process_frame
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Capture viewport image is empty for %s" % str(shot["file"]))
		viewport.queue_free()
		await process_frame
		return false
	var path := out_dir.path_join(str(shot["file"]))
	var err := image.save_png(path)
	viewport.queue_free()
	await process_frame
	if err != OK:
		push_error("Failed to save %s: %s" % [path, str(err)])
		return false
	print("CAPTURED %s" % path)
	return true


func _prepare_hand_cards_for_owner_capture(scene: Control) -> void:
	if scene == null or scene._hand_box == null:
		return
	var owner_card_width := 198.0
	for child in scene._hand_box.get_children():
		if child is Control:
			var control := child as Control
			control.custom_minimum_size = Vector2(owner_card_width, control.custom_minimum_size.y)
			control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var card_views := _find_controls_by_script(child, BattleCardViewScript)
		for card_view in card_views:
			card_view.custom_minimum_size = Vector2(owner_card_width, card_view.custom_minimum_size.y)
			var name_label = card_view.find_child("NameLabel", true, false)
			if name_label is Label:
				(name_label as Label).clip_text = false
				(name_label as Label).text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


func _apply_drag_state(scene: Control, card) -> void:
	scene.notification(Control.NOTIFICATION_DRAG_BEGIN)
	var surface := scene.find_child("BattleAoeDropSurface", true, false)
	var arena_root := scene.find_child("BattleArenaRoot", true, false)
	if surface is Control and arena_root is Control:
		(surface as Control).notification(Control.NOTIFICATION_DRAG_BEGIN)
		var surface_rect := (surface as Control).get_global_rect()
		var arena_rect := (arena_root as Control).get_global_rect()
		var global_drop_point := arena_rect.position + arena_rect.size - Vector2(36, 36)
		(surface as Control).call("_can_drop_data", global_drop_point - surface_rect.position, {"kind": "battle_card", "card": card, "view": null})
	var preview_source := BattleCardViewScript.new()
	preview_source.bind_card(card, int(card.energy_cost), _card_summary(card), "", _card_summary(card), false, null)
	var preview := preview_source.call("_make_drag_preview", Vector2(144, 136)) as Control
	preview_source.free()
	if preview == null:
		var fallback_preview := BattleCardViewScript.new()
		fallback_preview.bind_card(card, int(card.energy_cost), _card_summary(card), "", _card_summary(card), false, null)
		preview = fallback_preview
	preview.name = "ScreenshotDragPreview"
	preview.position = Vector2(560, 462)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1, 1, 1, 0.86)
	scene.add_child(preview)


func _make_cards() -> Array:
	var cards: Array = []
	for i in range(6):
		var target := "all_enemies" if i == 0 else "single"
		cards.append(CardScript.from_json({
			"id": "slice47_capture_card_%02d" % i,
			"template_id": "slice47_capture_card_%02d" % i,
			"display_name": "Slice 4.7 screenshot",
			"description": "Clean screenshot summary card.",
			"pathway": "fool",
			"sequence": 9,
			"energy_cost": i % 4,
			"combat_effect": {
				"damage": 9 + i,
				"heal": 0,
				"target": target,
				"range": 3,
				"status_effects": [{"id": "flame_wound", "duration": 2, "magnitude": 4}],
			},
			"tags": ["attack"],
		}))
	return cards


func _make_enemies() -> Array:
	var enemies: Array = []
	for i in range(3):
		var enemy = EnemyScript.from_json({
			"id": "slice47_capture_enemy_%d" % i,
			"display_name": "Slice 4.7 Enemy %d" % (i + 1),
			"stats": {"hp": 22 + i, "max_hp": 46 + i, "atk": 5, "def": 2 + i, "spd": 1},
			"skills": [{
				"id": "capture_claw_%d" % i,
				"name": "Capture Claw %d" % (i + 1),
				"damage": 8 + i,
				"target": "single",
				"intent_type": "attack",
			}],
			"ai_pattern": [{"condition": "default", "action": "use_skill", "skill_id": "capture_claw_%d" % i}],
		})
		enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
		if i == 1:
			enemy.add_status("defense_break", {"duration": 2, "magnitude": 2})
		enemies.append(enemy)
	return enemies


func _make_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.learned_rules = ["rule_use_debuff", "rule_draw_fate"] as Array[String]
	return gs


func _make_player():
	var player = CombatActorScript.new()
	player.display_name = "Slice 4.7 Capture Player"
	player.hp = 45
	player.max_hp = 62
	player.def = 5
	player.add_status("ward", {"duration": 3, "magnitude": 6})
	player.add_status("chant_charge", {"duration": 2, "stacks": 2})
	return player


func _card_summary(card) -> String:
	if card != null and card.has_method("effect_summary_text"):
		return str(card.call("effect_summary_text")).strip_edges()
	return ""


func _find_controls_by_script(root_node: Node, script: Variant) -> Array[Control]:
	var results: Array[Control] = []
	if root_node == null or script == null:
		return results
	if root_node is Control and root_node.get_script() == script:
		results.append(root_node as Control)
	for child in root_node.get_children():
		results.append_array(_find_controls_by_script(child, script))
	return results
