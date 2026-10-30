extends RefCounted

const BattleCardViewScript = preload("res://scripts/ui/battle/battle_card_view.gd")
const BattleSceneScript = preload("res://scripts/ui/battle_scene.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const PLAYER_STANDEE_PATH := "res://scripts/ui/battle/player_standee.gd"
const ENEMY_STANDEE_PATH := "res://scripts/ui/battle/enemy_standee.gd"
const ARENA_PLAY_ZONE_PATH := "res://scripts/ui/battle/arena_play_zone.gd"

var _passed := 0
var _failed := 0


class DropRouter:
	extends Control

	var played_called := false
	var played_target = null
	var target_selection_card = null
	var target_selection_targets: Array = []

	func _play_selected(target) -> void:
		played_called = true
		played_target = target

	func _start_target_selection(card) -> void:
		target_selection_card = card

	func _toggle_target_selection(enemy) -> void:
		if not target_selection_targets.has(enemy):
			target_selection_targets.append(enemy)


func run() -> Dictionary:
	print("\n-- test_battle_drag_play.gd --")
	await test_card_view_provides_drag_data_with_card_payload()
	await test_card_view_left_mouse_press_does_not_emit_pressed_for_play()
	await test_card_view_left_mouse_press_opens_card_peek_panel()
	await test_card_view_keyboard_ui_accept_still_emits_pressed_for_accessibility()
	await test_drag_then_drop_on_enemy_plays_card_via_drop_handler_only()
	await test_drag_drop_spawns_card_lift_and_travel_animation()
	await test_dragging_card_hides_original_hand_slot_until_drag_end()
	await test_card_peek_panel_closes_on_drag_start()
	await test_enemy_standee_accepts_single_target_card_drop()
	await test_enemy_standee_rejects_self_target_card_drop()
	await test_drag_over_enemy_highlights_only_that_enemy()
	await test_drag_over_invalid_drop_target_shows_rejection_style()
	await test_player_standee_accepts_self_target_card_drop()
	await test_arena_play_zone_accepts_aoe_card_drop_above_threshold()
	await test_arena_play_zone_rejects_single_target_card()
	await test_battle_scene_background_accepts_aoe_drop_outside_arena_play_zone()
	await test_battle_scene_enemy_layer_keeps_single_target_priority_over_aoe_background()
	await test_battle_scene_mounts_real_aoe_drop_surface_over_arena()
	await test_battle_scene_real_drop_surface_keeps_enemy_single_target_priority()
	await test_battle_scene_aoe_drop_surface_lives_in_arena_background_layer()
	await test_battle_scene_aoe_drop_surface_arms_as_top_drag_router()
	await test_battle_scene_aoe_drop_surface_does_not_cover_bottom_ui_controls()
	await test_select_targets_card_drop_on_enemy_opens_target_selection_panel()
	return {"passed": _passed, "failed": _failed}


func test_card_view_provides_drag_data_with_card_payload() -> void:
	var card := _card("drag_single_payload_card", "single")
	var view = BattleCardViewScript.new()
	Engine.get_main_loop().root.add_child(view)
	view.bind_card(card)
	await Engine.get_main_loop().process_frame
	assert_true(view.has_method("_get_drag_data"), "BattleCardView exposes _get_drag_data")
	var payload = view.call("_get_drag_data", Vector2(8, 8)) if view.has_method("_get_drag_data") else {}
	assert_true(payload is Dictionary, "BattleCardView drag data is a dictionary")
	if payload is Dictionary:
		assert_eq(payload.get("kind", ""), "battle_card", "BattleCardView drag payload has battle_card kind")
		assert_true(payload.get("card", null) == card, "BattleCardView drag payload keeps the card ref")
		assert_true(payload.get("view", null) == view, "BattleCardView drag payload keeps the view ref")
	view.queue_free()


func test_card_view_left_mouse_press_does_not_emit_pressed_for_play() -> void:
	var scene = BattleSceneScript.new()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("mouse_press_not_play_enemy", "Mouse Press Not Play Enemy")
	var card := _readable_card("mouse_press_not_play_card", "single")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var card_view = _first_battle_card_view(scene)
	assert_true(card_view != null, "BattleScene renders a card view for mouse press routing")
	var pressed_cards: Array = []
	if card_view != null:
		card_view.pressed.connect(func(pressed_card): pressed_cards.append(pressed_card))
		card_view.call("_gui_input", _mouse_left_press_event())
	await Engine.get_main_loop().process_frame
	assert_eq(pressed_cards.size(), 0, "left mouse press does not emit BattleCardView.pressed")
	assert_true(scene._selected_card == null, "left mouse press does not select a card for old click-to-play")
	assert_eq(int(enemy.hp), int(enemy.max_hp), "left mouse press does not invoke play resolution")
	scene.queue_free()


func test_card_view_left_mouse_press_opens_card_peek_panel() -> void:
	var scene = BattleSceneScript.new()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var card := _readable_card("mouse_press_peek_card", "single")
	scene.start_battle([card], [], [_enemy("mouse_press_peek_enemy", "Mouse Press Peek Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var card_view = _first_battle_card_view(scene)
	assert_true(card_view != null, "BattleScene renders a card view for peek routing")
	if card_view != null:
		card_view.call("_gui_input", _mouse_left_press_event())
	await Engine.get_main_loop().process_frame
	var panel := _find_control(scene, "CardPeekPanel")
	assert_true(panel != null and panel.visible, "left mouse press opens CardPeekPanel")
	var text := _collect_label_text(panel)
	assert_true(text.contains("Readable peek description"), "CardPeekPanel shows the card's clean readable summary")
	assert_true(text.contains(card.get_display_name()), "CardPeekPanel shows the enlarged card name")
	assert_true(not text.contains("paper_doll_marker") and not text.contains("{") and not text.contains("}"), "CardPeekPanel hides raw card payload tokens")
	scene.queue_free()


func test_card_view_keyboard_ui_accept_still_emits_pressed_for_accessibility() -> void:
	var card := _readable_card("keyboard_accept_accessibility_card", "single")
	var view = BattleCardViewScript.new()
	Engine.get_main_loop().root.add_child(view)
	view.bind_card(card)
	await Engine.get_main_loop().process_frame
	var pressed_cards: Array = []
	view.pressed.connect(func(pressed_card): pressed_cards.append(pressed_card))
	view.call("_gui_input", _keyboard_accept_event())
	assert_eq(pressed_cards.size(), 1, "keyboard ui_accept still emits BattleCardView.pressed")
	assert_true(pressed_cards[0] == card, "keyboard ui_accept emits the bound card")
	view.queue_free()


func test_drag_then_drop_on_enemy_plays_card_via_drop_handler_only() -> void:
	var scene = BattleSceneScript.new()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("drag_drop_handler_only_enemy", "Drag Drop Handler Only Enemy")
	var card := _card("drag_drop_handler_only_card", "single")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	var card_view = _first_battle_card_view(scene)
	var standee = _first_enemy_standee(scene)
	assert_true(card_view != null, "BattleScene renders a card view for drag-drop routing")
	assert_true(standee != null, "BattleScene renders an enemy standee for drag-drop routing")
	var pressed_cards: Array = []
	if card_view != null:
		card_view.pressed.connect(func(pressed_card): pressed_cards.append(pressed_card))
		card_view.call("_gui_input", _mouse_left_press_event())
	var payload = card_view.call("_get_drag_data", Vector2(8, 8)) if card_view != null and card_view.has_method("_get_drag_data") else {}
	if standee != null and standee.has_method("_drop_data"):
		standee.call("_drop_data", Vector2(4, 4), payload)
	await Engine.get_main_loop().process_frame
	assert_eq(pressed_cards.size(), 0, "drag play does not route through BattleCardView.pressed")
	assert_true(int(enemy.hp) < int(enemy.max_hp), "drag drop on enemy plays the card through the drop handler")
	assert_true(scene._selected_card == null, "drag drop resolution clears selected card after play")
	scene.queue_free()


func test_drag_drop_spawns_card_lift_and_travel_animation() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("drag_travel_animation_enemy", "Drag Travel Animation Enemy")
	var card := _card("drag_travel_animation_card", "single")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	var card_view = _first_battle_card_view(scene)
	var standee = _first_enemy_standee(scene)
	assert_true(card_view != null, "BattleScene renders a card view for drag travel animation")
	assert_true(standee != null, "BattleScene renders an enemy standee for drag travel animation")
	var target_center := (standee as Control).get_global_rect().get_center() if standee is Control else Vector2.ZERO
	var payload = card_view.call("_get_drag_data", Vector2(8, 8)) if card_view != null and card_view.has_method("_get_drag_data") else {}
	if standee != null and standee.has_method("_drop_data"):
		standee.call("_drop_data", Vector2(4, 4), payload)
	var travel = scene.get_meta("last_card_travel_animation", {})
	assert_true(travel is Dictionary and not (travel as Dictionary).is_empty(), "BattleScene records the most recent card travel animation contract")
	if travel is Dictionary:
		var start_point: Vector2 = (travel as Dictionary).get("start", Vector2.ZERO)
		var end_point: Vector2 = (travel as Dictionary).get("end", Vector2.ZERO)
		assert_true(start_point.distance_to(end_point) > 48.0, "card travel animation moves from the hand toward the play target")
		assert_true(end_point.distance_to(target_center) <= 12.0, "card travel animation ends on the target standee center")
		assert_true(float((travel as Dictionary).get("duration", 0.0)) >= 0.12, "card travel animation has a visible duration")
	var anim_node := scene.find_child("BattleCardTravelAnimation", true, false)
	assert_true(anim_node is Control, "BattleScene spawns a visible BattleCardTravelAnimation node on drop play")
	if anim_node is Control:
		assert_true(bool((anim_node as Control).get_meta("card_travel_animation", false)), "travel animation node is marked for screenshot/QA inspection")
		assert_true((anim_node as Control).z_index >= 400, "travel animation node renders above the hand and arena")
	scene.queue_free()


func test_dragging_card_hides_original_hand_slot_until_drag_end() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("drag_source_hide_enemy", "Drag Source Hide Enemy")
	var card := _card("drag_source_hide_card", "single")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	var card_view = _first_battle_card_view(scene)
	assert_true(card_view != null, "BattleScene renders a source card view for drag-source hiding")
	var wrapper := card_view.get_parent() as Control if card_view != null else null
	assert_true(wrapper != null, "BattleScene hand card view has a Control wrapper")
	var original_wrapper_size := wrapper.custom_minimum_size if wrapper != null else Vector2.ZERO
	var payload = card_view.call("_get_drag_data", Vector2(8, 8)) if card_view != null and card_view.has_method("_get_drag_data") else {}
	assert_true(payload is Dictionary, "BattleScene source card drag payload exists")
	if wrapper != null:
		assert_true(wrapper.visible, "drag source wrapper stays in the hand layout as an invisible slot")
		assert_true(bool(wrapper.get_meta("drag_source_placeholder", false)), "drag source wrapper is marked as the hidden source placeholder")
		assert_true(wrapper.modulate.a <= 0.05, "original hand card wrapper disappears while its lifted preview is dragged")
		assert_eq(wrapper.custom_minimum_size, original_wrapper_size, "hidden source wrapper keeps the same layout footprint during drag")
	if payload is Dictionary:
		assert_true((payload as Dictionary).get("source_view", null) == card_view, "drag payload keeps the source card view for lifecycle restoration")
		assert_true((payload as Dictionary).get("source_placeholder", null) == wrapper, "drag payload exposes the source hand placeholder")
		assert_true(bool((payload as Dictionary).get("source_hidden_during_drag", false)), "drag payload records that the original hand card is hidden")
	if card_view != null:
		card_view.notification(Control.NOTIFICATION_DRAG_END)
	await Engine.get_main_loop().process_frame
	if wrapper != null:
		assert_true(not bool(wrapper.get_meta("drag_source_placeholder", false)), "drag source wrapper clears placeholder state after drag end")
		assert_true(wrapper.modulate.a >= 0.99, "original hand card wrapper returns when the drag is cancelled")
	scene.queue_free()


func test_card_peek_panel_closes_on_drag_start() -> void:
	var scene = BattleSceneScript.new()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var card := _readable_card("peek_closes_on_drag_card", "single")
	scene.start_battle([card], [], [_enemy("peek_closes_on_drag_enemy", "Peek Closes On Drag Enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var card_view = _first_battle_card_view(scene)
	if card_view != null:
		card_view.call("_gui_input", _mouse_left_press_event())
	await Engine.get_main_loop().process_frame
	var panel := _find_control(scene, "CardPeekPanel")
	assert_true(panel != null and panel.visible, "CardPeekPanel is visible before drag starts")
	if panel != null:
		panel.notification(Control.NOTIFICATION_DRAG_BEGIN)
	await Engine.get_main_loop().process_frame
	assert_true(panel != null and not panel.visible, "CardPeekPanel closes on drag start")
	scene.queue_free()


func test_enemy_standee_accepts_single_target_card_drop() -> void:
	var router := DropRouter.new()
	Engine.get_main_loop().root.add_child(router)
	var enemy = _enemy("drop_enemy_single", "Drop Enemy Single")
	var standee = _new_enemy_standee()
	if standee == null:
		router.queue_free()
		return
	router.add_child(standee)
	standee.call("bind_enemy", enemy, {"intent_type": "attack", "damage": 4}, "", false, false, false)
	var card := _card("drop_single_target_attack", "single")
	var payload := _payload(card)
	assert_true(standee.has_method("_can_drop_data"), "EnemyStandee exposes _can_drop_data")
	assert_true(standee.has_method("_drop_data"), "EnemyStandee exposes _drop_data")
	var accepted := bool(standee.call("_can_drop_data", Vector2(4, 4), payload)) if standee.has_method("_can_drop_data") else false
	assert_true(accepted, "EnemyStandee accepts single-target card drop")
	if accepted and standee.has_method("_drop_data"):
		standee.call("_drop_data", Vector2(4, 4), payload)
	assert_true(router.played_called and router.played_target == enemy, "EnemyStandee drop routes through _play_selected(enemy)")
	router.queue_free()


func test_enemy_standee_rejects_self_target_card_drop() -> void:
	var enemy = _enemy("drop_enemy_reject_self", "Drop Enemy Reject Self")
	var standee = _new_enemy_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	standee.call("bind_enemy", enemy, {"intent_type": "attack", "damage": 4}, "", false, false, false)
	var accepted := bool(standee.call("_can_drop_data", Vector2.ZERO, _payload(_card("drop_self_rejected_by_enemy", "self")))) if standee.has_method("_can_drop_data") else false
	assert_true(not accepted, "EnemyStandee rejects self-target card drop")
	standee.queue_free()


func test_drag_over_enemy_highlights_only_that_enemy() -> void:
	var router := DropRouter.new()
	Engine.get_main_loop().root.add_child(router)
	var standees: Array = []
	for i in range(3):
		var standee = _new_enemy_standee()
		if standee == null:
			router.queue_free()
			return
		router.add_child(standee)
		standee.call("bind_enemy", _enemy("drop_hover_enemy_%d" % i, "Drop Hover Enemy %d" % i), {"intent_type": "attack", "damage": 4}, "", false, false, false)
		standee.set_meta("drop_hovered", i == 1)
		standees.append(standee)
	var payload := _payload(_card("drop_hover_single_target", "single"))
	for standee in standees:
		standee.call("_can_drop_data", Vector2(4, 4), payload)
	assert_eq(_drop_highlight_state(standees[0]), "none", "non-hovered enemy before the hovered target has no highlight")
	assert_eq(_drop_highlight_state(standees[1]), "valid", "hovered enemy shows the valid drop highlight")
	assert_eq(_drop_highlight_state(standees[2]), "none", "non-hovered enemy after the hovered target has no highlight")
	router.queue_free()


func test_drag_over_invalid_drop_target_shows_rejection_style() -> void:
	var enemy = _enemy("drop_invalid_enemy", "Drop Invalid Enemy")
	var standee = _new_enemy_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	standee.call("bind_enemy", enemy, {"intent_type": "attack", "damage": 4}, "", false, false, false)
	standee.set_meta("drop_hovered", true)
	var accepted := bool(standee.call("_can_drop_data", Vector2.ZERO, _payload(_card("drop_invalid_self_card", "self")))) if standee.has_method("_can_drop_data") else true
	assert_true(not accepted, "EnemyStandee still rejects a self-target card during drag")
	assert_eq(_drop_highlight_state(standee), "invalid", "EnemyStandee shows an invalid drop highlight for rejected hovered payloads")
	standee.queue_free()


func test_player_standee_accepts_self_target_card_drop() -> void:
	var router := DropRouter.new()
	Engine.get_main_loop().root.add_child(router)
	var player = CombatActorScript.new()
	player.display_name = "Drop Player"
	player.hp = 30
	player.max_hp = 30
	var standee = _new_player_standee()
	if standee == null:
		router.queue_free()
		return
	router.add_child(standee)
	standee.call("bind_player", player, "", "")
	var card := _card("drop_self_target_card", "self")
	var payload := _payload(card)
	assert_true(standee.has_method("_can_drop_data"), "PlayerStandee exposes _can_drop_data")
	assert_true(standee.has_method("_drop_data"), "PlayerStandee exposes _drop_data")
	var accepted := bool(standee.call("_can_drop_data", Vector2(4, 4), payload)) if standee.has_method("_can_drop_data") else false
	assert_true(accepted, "PlayerStandee accepts self-target card drop")
	if accepted and standee.has_method("_drop_data"):
		standee.call("_drop_data", Vector2(4, 4), payload)
	assert_true(router.played_called and router.played_target == player, "PlayerStandee drop routes through _play_selected(player)")
	router.queue_free()


func test_arena_play_zone_accepts_aoe_card_drop_above_threshold() -> void:
	var router := DropRouter.new()
	Engine.get_main_loop().root.add_child(router)
	var zone = _new_arena_play_zone()
	if zone == null:
		router.queue_free()
		return
	router.add_child(zone)
	var card := _card("drop_aoe_card", "all_enemies")
	var payload := _payload(card)
	assert_true(zone.has_method("_can_drop_data"), "ArenaPlayZone exposes _can_drop_data")
	assert_true(zone.has_method("_drop_data"), "ArenaPlayZone exposes _drop_data")
	var accepted := bool(zone.call("_can_drop_data", Vector2(4, 4), payload)) if zone.has_method("_can_drop_data") else false
	assert_true(accepted, "ArenaPlayZone accepts AOE card drop")
	if accepted and zone.has_method("_drop_data"):
		zone.call("_drop_data", Vector2(4, 4), payload)
	assert_true(router.played_called and router.played_target == null, "ArenaPlayZone drop routes through _play_selected(null)")
	router.queue_free()


func test_arena_play_zone_rejects_single_target_card() -> void:
	var zone = _new_arena_play_zone()
	if zone == null:
		return
	Engine.get_main_loop().root.add_child(zone)
	var accepted := bool(zone.call("_can_drop_data", Vector2.ZERO, _payload(_card("drop_single_rejected_by_arena", "single")))) if zone.has_method("_can_drop_data") else false
	assert_true(not accepted, "ArenaPlayZone rejects single-target card drop")
	zone.queue_free()


func test_battle_scene_background_accepts_aoe_drop_outside_arena_play_zone() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy_a = _enemy("background_aoe_enemy_a", "Background AOE Enemy A")
	var enemy_b = _enemy("background_aoe_enemy_b", "Background AOE Enemy B")
	var card := _card("background_aoe_card", "all_enemies")
	scene.start_battle([card], [], [enemy_a, enemy_b], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	var play_zone := _find_control(scene, "ArenaPlayZone")
	assert_true(play_zone == null, "BattleScene no longer renders the old small ArenaPlayZone AOE window")
	var background_point := Vector2(18, 18)
	assert_true(scene.has_method("_can_drop_data"), "BattleScene root exposes _can_drop_data for the wide AOE background")
	assert_true(scene.has_method("_drop_data"), "BattleScene root exposes _drop_data for the wide AOE background")
	var payload := _payload(card)
	var accepted := bool(scene.call("_can_drop_data", background_point, payload)) if scene.has_method("_can_drop_data") else false
	assert_true(accepted, "BattleScene background accepts AOE card drops without the old ArenaPlayZone")
	if accepted and scene.has_method("_drop_data"):
		scene.call("_drop_data", background_point, payload)
	await Engine.get_main_loop().process_frame
	assert_true(int(enemy_a.hp) < int(enemy_a.max_hp) and int(enemy_b.hp) < int(enemy_b.max_hp), "BattleScene background AOE drop plays against all enemies")
	scene.queue_free()


func test_battle_scene_enemy_layer_keeps_single_target_priority_over_aoe_background() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("layer_priority_enemy", "Layer Priority Enemy")
	var single_card := _card("layer_priority_single_card", "single")
	var aoe_card := _card("layer_priority_aoe_card", "all_enemies")
	scene.start_battle([single_card, aoe_card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [single_card, aoe_card]
	var standee = _first_enemy_standee(scene)
	assert_true(standee != null, "BattleScene renders EnemyStandee for layered drop priority")
	var single_payload := _payload(single_card)
	var aoe_payload := _payload(aoe_card)
	var standee_accepts_single := bool(standee.call("_can_drop_data", Vector2.ZERO, single_payload)) if standee != null and standee.has_method("_can_drop_data") else false
	var standee_accepts_aoe := bool(standee.call("_can_drop_data", Vector2.ZERO, aoe_payload)) if standee != null and standee.has_method("_can_drop_data") else true
	var scene_accepts_single := bool(scene.call("_can_drop_data", Vector2(32, 32), single_payload)) if scene.has_method("_can_drop_data") else true
	var scene_accepts_aoe := bool(scene.call("_can_drop_data", Vector2(32, 32), aoe_payload)) if scene.has_method("_can_drop_data") else false
	assert_true(standee_accepts_single, "EnemyStandee remains the upper single-target drop layer")
	assert_true(not standee_accepts_aoe, "EnemyStandee does not steal AOE drops from the background layer")
	assert_true(not scene_accepts_single, "BattleScene background does not accept single-target card drops")
	assert_true(scene_accepts_aoe, "BattleScene background accepts AOE card drops behind enemy standees")
	scene.queue_free()


func test_battle_scene_mounts_real_aoe_drop_surface_over_arena() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy_a = _enemy("real_surface_aoe_enemy_a", "Real Surface AOE Enemy A")
	var enemy_b = _enemy("real_surface_aoe_enemy_b", "Real Surface AOE Enemy B")
	var card := _card("real_surface_aoe_card", "all_enemies")
	scene.start_battle([card], [], [enemy_a, enemy_b], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [card]
	var surface := _find_control(scene, "BattleAoeDropSurface")
	var arena_root := _find_control(scene, "BattleArenaRoot")
	var play_zone := _find_control(scene, "ArenaPlayZone")
	assert_true(surface != null, "BattleScene mounts a real transparent AOE drop surface")
	assert_true(arena_root != null, "BattleScene renders BattleArenaRoot for mounted surface coverage")
	assert_true(play_zone == null, "BattleScene does not mount the old visible ArenaPlayZone when the real AOE surface is present")
	if surface != null and arena_root != null:
		var surface_rect := surface.get_global_rect()
		var arena_rect := arena_root.get_global_rect()
		assert_true(surface_rect.has_point(arena_rect.position + Vector2(12, 12)) and surface_rect.has_point(arena_rect.position + arena_rect.size - Vector2(12, 12)), "mounted AOE drop surface covers the battle arena rect")
		var global_drop_point := arena_rect.position + Vector2(maxf(16.0, arena_rect.size.x - 24.0), 24.0)
		var local_drop_point := global_drop_point - surface_rect.position
		var accepted := bool(surface.call("_can_drop_data", local_drop_point, _payload(card))) if surface.has_method("_can_drop_data") else false
		assert_true(accepted, "mounted AOE drop surface accepts AOE drops without the old ArenaPlayZone")
		if accepted and surface.has_method("_drop_data"):
			surface.call("_drop_data", local_drop_point, _payload(card))
	await Engine.get_main_loop().process_frame
	assert_true(int(enemy_a.hp) < int(enemy_a.max_hp) and int(enemy_b.hp) < int(enemy_b.max_hp), "mounted AOE drop surface plays the card against all enemies")
	scene.queue_free()


func test_battle_scene_real_drop_surface_keeps_enemy_single_target_priority() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("real_surface_single_enemy", "Real Surface Single Enemy")
	var single_card := _card("real_surface_single_card", "single")
	scene.start_battle([single_card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	scene._battle.energy = 99
	scene._battle.hand = [single_card]
	var surface := _find_control(scene, "BattleAoeDropSurface")
	var standee = _first_enemy_standee(scene)
	assert_true(surface != null, "BattleScene mounts a real drop surface for layered target routing")
	assert_true(standee != null, "BattleScene renders EnemyStandee for mounted single-target routing")
	if surface != null and standee != null:
		var surface_rect := surface.get_global_rect()
		var standee_control := standee as Control
		var standee_center: Vector2 = standee_control.get_global_rect().get_center()
		var local_drop_point: Vector2 = standee_center - surface_rect.position
		var accepted := bool(surface.call("_can_drop_data", local_drop_point, _payload(single_card))) if surface.has_method("_can_drop_data") else false
		assert_true(accepted, "mounted drop surface delegates single-target cards to the enemy under the cursor")
		if accepted and surface.has_method("_drop_data"):
			surface.call("_drop_data", local_drop_point, _payload(single_card))
	await Engine.get_main_loop().process_frame
	assert_true(int(enemy.hp) < int(enemy.max_hp), "single-target card dropped on mounted surface still damages the enemy standee target")
	scene.queue_free()


func test_battle_scene_aoe_drop_surface_lives_in_arena_background_layer() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("aoe_background_layer_enemy", "AOE Background Layer Enemy")
	var card := _card("aoe_background_layer_card", "all_enemies")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var surface := _find_control(scene, "BattleAoeDropSurface")
	var layer := _find_control(scene, "BattleArenaLayerStack")
	var arena_root := _find_control(scene, "BattleArenaRoot")
	assert_true(surface != null, "BattleScene mounts BattleAoeDropSurface")
	assert_true(layer != null, "BattleScene mounts a dedicated arena background layer stack")
	assert_true(arena_root != null, "BattleScene still exposes BattleArenaRoot above the background layer")
	if surface != null and layer != null and arena_root != null:
		assert_true(surface.get_parent() == layer, "AOE drop surface is parented to the arena layer, not the top-level scene")
		assert_true(arena_root.get_parent() == layer, "BattleArenaRoot shares the arena layer with the background drop surface")
		assert_true(surface.get_index() < arena_root.get_index(), "AOE drop surface is drawn below player/enemy arena content")
		var surface_rect := surface.get_global_rect()
		var arena_rect := arena_root.get_global_rect()
		assert_true(surface_rect.has_point(arena_rect.position + Vector2(12, 12)) and surface_rect.has_point(arena_rect.position + arena_rect.size - Vector2(12, 12)), "lower AOE surface still covers the full battle arena row")
	scene.queue_free()


func test_battle_scene_aoe_drop_surface_arms_as_top_drag_router() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("aoe_top_router_enemy", "AOE Top Router Enemy")
	var card := _card("aoe_top_router_card", "all_enemies")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var surface := _find_control(scene, "BattleAoeDropSurface")
	var arena_root := _find_control(scene, "BattleArenaRoot")
	assert_true(surface != null, "BattleScene mounts BattleAoeDropSurface for drag-time routing")
	assert_true(arena_root != null, "BattleScene renders BattleArenaRoot below the drag router")
	if surface != null and arena_root != null:
		assert_true(surface.z_index > arena_root.z_index, "AOE drop surface is z-ordered above arena content during drag hit testing")
		assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE, "AOE drop surface does not cover standee hover/clicks when no drag is active")
		surface.notification(Control.NOTIFICATION_DRAG_BEGIN)
		await Engine.get_main_loop().process_frame
		assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_STOP, "AOE drop surface arms itself as the real top drag router")
		var surface_rect := surface.get_global_rect()
		var arena_rect := arena_root.get_global_rect()
		var local_drop_point := (arena_rect.position + arena_rect.size - Vector2(18, 18)) - surface_rect.position
		assert_true(bool(surface.call("_can_drop_data", local_drop_point, _payload(card))), "armed top drag router accepts AOE drops across the arena")
		surface.notification(Control.NOTIFICATION_DRAG_END)
		await Engine.get_main_loop().process_frame
		assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE, "AOE drop surface disarms after drag end")
	scene.queue_free()


func test_battle_scene_aoe_drop_surface_does_not_cover_bottom_ui_controls() -> void:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy = _enemy("aoe_surface_not_ui_enemy", "AOE Surface Not UI Enemy")
	var card := _card("aoe_surface_not_ui_card", "all_enemies")
	scene.start_battle([card], [], [enemy], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	await Engine.get_main_loop().process_frame
	var surface := _find_control(scene, "BattleAoeDropSurface")
	assert_true(surface != null, "BattleScene mounts BattleAoeDropSurface for bottom UI coverage check")
	if surface != null:
		var surface_rect := surface.get_global_rect()
		for control_name in ["ArenaTopBar", "HandRail", "DrawPileChip", "DiscardPileChip", "EnergyOrb", "EndTurnButton"]:
			var control := _find_control(scene, control_name)
			assert_true(control != null, "%s exists while checking AOE surface bounds" % control_name)
			if control != null:
				assert_true(not surface_rect.has_point(control.get_global_rect().get_center()), "AOE drop surface does not sit on top of %s" % control_name)
	scene.queue_free()


func test_select_targets_card_drop_on_enemy_opens_target_selection_panel() -> void:
	var scene = BattleSceneScript.new()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var enemy_a = _enemy("drop_select_targets_a", "Drop Select Targets A")
	var enemy_b = _enemy("drop_select_targets_b", "Drop Select Targets B")
	var card := _select_targets_card()
	scene.start_battle([card], [], [enemy_a, enemy_b], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var standee = _first_enemy_standee(scene)
	assert_true(standee != null, "BattleScene renders EnemyStandee for select_targets drop")
	var payload := _payload(card)
	var accepted := bool(standee.call("_can_drop_data", Vector2.ZERO, payload)) if standee != null and standee.has_method("_can_drop_data") else false
	assert_true(accepted, "EnemyStandee accepts select_targets card drop")
	if accepted and standee.has_method("_drop_data"):
		standee.call("_drop_data", Vector2.ZERO, payload)
	await Engine.get_main_loop().process_frame
	var panel = scene.find_child("TargetSelectionPanel", true, false)
	assert_true(panel != null and panel.visible, "select_targets drop opens TargetSelectionPanel")
	assert_true(scene._target_selection_targets.has(enemy_a), "select_targets drop toggles the dropped enemy into target selection")
	scene.queue_free()


func _new_player_standee():
	var script = load(PLAYER_STANDEE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "player_standee.gd loads for drag tests")
		return null
	return script.new()


func _new_enemy_standee():
	var script = load(ENEMY_STANDEE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "enemy_standee.gd loads for drag tests")
		return null
	return script.new()


func _new_arena_play_zone():
	var script = load(ARENA_PLAY_ZONE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "arena_play_zone.gd loads for drag tests")
		return null
	return script.new()


func _payload(card, view = null) -> Dictionary:
	return {"kind": "battle_card", "card": card, "view": view}


func _card(id: String, target: String) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 6,
			"heal": 0,
			"target": target,
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})


func _select_targets_card() -> Card:
	return CardScript.from_json({
		"id": "drop_select_targets_card",
		"template_id": "drop_select_targets_card",
		"display_name": "drop_select_targets_card",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 5,
			"heal": 0,
			"target": "multi",
			"range": 3,
			"status_effects": [{"id": "select_targets", "min": 2, "max": 3}],
		},
		"tags": ["attack", "multi_target"],
	})


func _readable_card(id: String, target: String) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": "Readable Peek Card",
		"description": "Readable peek description with full clean effect text.",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 9,
			"heal": 0,
			"target": target,
			"range": 1,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 2}],
		},
		"tags": ["attack"],
	})


func _enemy(id: String, display_name: String):
	return EnemyScript.from_json({
		"id": id,
		"display_name": display_name,
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _first_enemy_standee(root: Node):
	var script = load(ENEMY_STANDEE_PATH)
	return _find_control_by_script(root, script)


func _first_battle_card_view(root: Node):
	return _find_control_by_script(root, BattleCardViewScript)


func _find_control(root: Node, node_name: String) -> Control:
	if root == null:
		return null
	var found := root.find_child(node_name, true, false)
	if found is Control:
		return found as Control
	return null


func _find_control_by_script(root: Node, script: Variant):
	if root == null:
		return null
	if script != null and root is Control and root.get_script() == script:
		return root
	for child in root.get_children():
		var found = _find_control_by_script(child, script)
		if found != null:
			return found
	return null


func _collect_label_text(node: Node) -> String:
	if node == null:
		return ""
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


func _drop_highlight_state(control: Control) -> String:
	if control == null:
		return "none"
	if control.has_meta("drop_highlight_state"):
		return str(control.get_meta("drop_highlight_state"))
	if bool(control.get_meta("valid_drop_target", false)):
		return "valid"
	return "none"


func _mouse_left_press_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(8, 8)
	return event


func _keyboard_accept_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	event.echo = false
	return event


func assert_eq(actual, expected, message: String) -> void:
	assert_true(actual == expected, "%s - expected '%s', got '%s'" % [message, str(expected), str(actual)])


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
