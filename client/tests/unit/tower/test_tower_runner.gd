extends RefCounted

const SCRIPT_PATH := "res://scripts/tower/tower_runner.gd"
const SCENE_PATH := "res://scenes/tower/tower_runner.tscn"

const TowerScript = preload("res://scripts/tower/tower.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")
const CommissionActionServiceScript = preload("res://scripts/world/commission_action_service.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_tower_runner.gd --")
	await test_scene_and_script_load()
	await test_open_spends_tower_ap_by_size()
	await test_open_blocks_when_tower_ap_is_short()
	await test_battle_floor_starts_battle_scene_with_enemy_pack()
	await test_battle_floor_blocks_when_active_deck_empty()
	await test_battle_floor_uses_only_active_deck_cards()
	await test_battle_victory_clears_floor_and_returns_when_done()
	await test_tower_commission_tower_gameplay_path_advances_time_to_night()
	await test_battle_failure_respawns_then_second_failure_collapses()
	await test_boss_failure_respawn_can_flee_from_boss_floor()
	await test_flee_return_to_hub_keeps_card_state_unchanged()
	await test_flee_button_does_not_spend_extra_ap()
	await test_merchant_floor_opens_tower_merchant_and_clears_on_leave()
	await test_event_choice_applies_outcome_and_advances()
	await test_shrine_applies_service_payload_and_advances()
	await test_hub_wires_district_selector_to_city_scene()
	await test_hub_records_live_tower_commission_completion()
	await test_hub_records_live_tower_event_commission_completion()
	return {"passed": _passed, "failed": _failed}


func test_scene_and_script_load() -> void:
	var script = load(SCRIPT_PATH)
	assert_true(script != null and script.can_instantiate(), "tower_runner.gd loads")
	var scene = load(SCENE_PATH)
	assert_true(scene != null and scene.can_instantiate(), "tower_runner.tscn instantiable")


func test_open_spends_tower_ap_by_size() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.ap = 6
	var tower = _tower([_floor("event", {"choices": []})])
	tower.size = "medium"
	runner.open(tower, gs)
	assert_eq(int(gs.ap), 2, "opening medium tower spends 4 AP")
	assert_eq(str(runner.get_last_return_reason()), "", "tower opens when AP is enough")
	_free_runner(runner)


func test_open_blocks_when_tower_ap_is_short() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.ap = 1
	var tower = _tower([_floor("event", {"choices": []})])
	tower.size = "small"
	runner.open(tower, gs)
	assert_eq(int(gs.ap), 1, "failed tower open does not spend AP")
	assert_eq(str(runner.get_last_return_reason()), "ap_short", "tower open records ap_short")
	assert_true(not runner.visible, "tower runner stays hidden when AP is short")
	_free_runner(runner)


func test_battle_floor_starts_battle_scene_with_enemy_pack() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	var tower = _tower([_floor("battle", {"enemy_pack_id": "shadow_alley_t1", "enemy_ids": ["drunkard", "vagrant"], "drop_table": {"lingstones": [10, 20]}})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	assert_eq(str(runner.get_active_view_kind()), "battle", "battle floor switches active view to BattleScene")
	assert_true(runner.get_active_battle_scene() != null, "battle scene instance exists")
	var payload: Dictionary = runner.get_last_battle_payload()
	assert_eq(str(payload.get("enemy_pack_id", "")), "shadow_alley_t1", "battle payload keeps enemy_pack_id")
	assert_eq(Array(payload.get("enemy_ids", [])), ["drunkard", "vagrant"], "battle payload expands enemy ids")
	assert_eq(Array(payload.get("loaded_enemy_ids", [])), ["drunkard", "vagrant"], "battle scene receives loaded enemies")
	_free_runner(runner)


func test_battle_floor_blocks_when_active_deck_empty() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.active_deck.clear()
	var tower = _tower([_floor("battle", {"enemy_ids": ["drunkard"]})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	assert_eq(str(runner.get_active_view_kind()), "floor_select", "battle floor stays on floor select when active deck is empty")
	assert_true(runner.get_active_battle_scene() == null, "empty active deck does not start BattleScene from cards_inventory fallback")
	assert_eq(str(tower.floors[0].resolution), "pending", "empty active deck leaves the floor pending")
	_free_runner(runner)


func test_battle_floor_uses_only_active_deck_cards() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = GameStateScript.new()
	gs._ready()
	gs.cards_inventory.append(_card("equipped_card"))
	gs.cards_inventory.append(_card("inventory_only_card"))
	gs.active_deck.clear()
	gs.active_deck.append("equipped_card")
	var tower = _tower([_floor("battle", {"enemy_ids": ["drunkard"]})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	var scene = runner.get_active_battle_scene()
	assert_true(scene != null, "battle starts when active deck has an equipped card")
	if scene != null:
		var ids := _battle_card_ids(scene._battle)
		assert_true("equipped_card" in ids, "equipped active card enters battle zones")
		assert_true(not ("inventory_only_card" in ids), "inventory-only card stays out of battle zones")
	_free_runner(runner)


func test_battle_victory_clears_floor_and_returns_when_done() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.temp_picked_cards.append(_card("temp_keep_until_clear"))
	var tower = _tower([_floor("battle", {"enemy_ids": ["drunkard"]})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "victory"})
	assert_eq(str(tower.floors[0].resolution), "cleared", "victory marks floor cleared")
	assert_eq(str(tower.resolution), "cleared", "last floor victory clears tower")
	assert_eq(str(runner.get_last_return_reason()), "completed", "tower completion returns to hub")
	assert_eq(gs.temp_picked_cards.size(), 0, "tower completion discards temp picked cards")
	_free_runner(runner)


func test_tower_commission_tower_gameplay_path_advances_time_to_night() -> void:
	var gs = _state()
	gs.ap = 12
	gs.time_of_day = "morning"
	var runner_a = await _runner()
	if runner_a == null:
		return
	var tower_a = _tower([_floor("event", {"choices": [{"id": "go", "text": "Go", "outcome": {}}]})])
	runner_a.open(tower_a, gs)
	runner_a.enter_current_floor()
	runner_a.choose_event_option(0)
	assert_eq(str(gs.time_of_day), "noon", "morning tower return advances to noon")
	_free_runner(runner_a)
	gs.accepted_commissions.append("runner_job")
	var commission: Dictionary = CommissionActionServiceScript.execute_placeholder(gs, "runner_job", false, "")
	assert_true(bool(commission.get("ok", false)), "commission executes between tower runs")
	assert_eq(str(gs.time_of_day), "evening", "commission execution advances noon to evening")
	var runner_b = await _runner()
	if runner_b == null:
		return
	var tower_b = _tower([_floor("event", {"choices": [{"id": "go", "text": "Go", "outcome": {}}]})])
	runner_b.open(tower_b, gs)
	runner_b.enter_current_floor()
	runner_b.choose_event_option(0)
	assert_eq(str(gs.time_of_day), "night", "second tower return advances evening to night")
	assert_true(not bool(gs.get_meta("force_sleep_pending", false)), "tower return to night keeps night gameplay available")
	_free_runner(runner_b)


func test_battle_failure_respawns_then_second_failure_collapses() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.pollution = 10
	gs.temp_picked_cards.append(_card("temp_0"))
	gs.temp_picked_cards.append(_card("temp_1"))
	var inventory_before := _card_ids(gs.cards_inventory)
	var tower = _tower([_floor("battle", {"enemy_ids": ["drunkard"]})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "defeat"})
	assert_eq(str(runner.get_last_floor_result()), "respawn", "first battle failure respawns current floor")
	assert_eq(int(tower.floors[0].fail_count), 1, "first failure increments floor fail_count")
	assert_eq(int(gs.pollution), 15, "first failure applies +5 pollution")
	assert_eq(gs.temp_picked_cards.size(), 1, "first failure drops one temp card")
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "defeat"})
	assert_eq(str(tower.resolution), "collapsed", "second failure collapses tower")
	assert_eq(str(runner.get_last_return_reason()), "collapsed", "collapse returns to hub")
	assert_eq(gs.temp_picked_cards.size(), 0, "collapse clears temp cards")
	assert_eq(_card_ids(gs.cards_inventory), inventory_before, "collapse preserves permanent cards exactly")
	assert_eq(int(gs.pollution), 35, "collapse applies +20 after first failure")
	_free_runner(runner)


func test_boss_failure_respawn_can_flee_from_boss_floor() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.ap = 12
	var tower = _tower([_floor("boss", {"boss_id": "alley_horror"})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	runner.handle_battle_result({"outcome": "defeat"})
	assert_eq(str(runner.get_last_floor_result()), "respawn", "first boss failure respawns the boss floor")
	assert_eq(str(runner.get_active_view_kind()), "floor_select", "boss failure returns to tower floor select")
	runner.call("_on_flee_pressed")
	assert_eq(str(runner.get_last_return_reason()), "fled", "boss floor can be fled after a failed battle")
	assert_eq(str(tower.resolution), "pending", "fleeing after boss failure does not collapse the tower")
	_free_runner(runner)


func test_flee_return_to_hub_keeps_card_state_unchanged() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.temp_picked_cards.append(_card("temp_flee_0"))
	gs.temp_picked_cards.append(_card("temp_flee_1"))
	var inventory_before := _card_ids(gs.cards_inventory)
	var temp_before := _card_ids(gs.temp_picked_cards)
	var tower = _tower([_floor("battle", {"enemy_ids": ["drunkard"]})])
	runner.open(tower, gs)
	runner.call("_return_to_hub", "flee")
	assert_eq(str(runner.get_last_return_reason()), "flee", "flee return reason recorded")
	assert_eq(_card_ids(gs.cards_inventory), inventory_before, "flee leaves cards_inventory unchanged")
	assert_eq(_card_ids(gs.temp_picked_cards), temp_before, "flee leaves temp_picked_cards unchanged")
	_free_runner(runner)


func test_flee_button_does_not_spend_extra_ap() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.ap = 12
	var tower = _tower([_floor("event", {"choices": []})])
	runner.open(tower, gs)
	var after_entry_ap := int(gs.ap)
	runner.call("_on_flee_pressed")
	assert_eq(int(gs.ap), after_entry_ap, "flee button returns without extra AP cost")
	assert_eq(str(runner.get_last_return_reason()), "fled", "flee button returns to hub")
	_free_runner(runner)


func test_merchant_floor_opens_tower_merchant_and_clears_on_leave() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	var tower = _tower([_floor("merchant", {"shop_id": "tower_merchant"})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	assert_eq(str(runner.get_active_view_kind()), "merchant", "merchant floor opens TowerMerchant")
	assert_true(runner.get_active_merchant() != null, "tower merchant instance exists")
	runner.handle_merchant_closed()
	assert_eq(str(tower.floors[0].resolution), "cleared", "leaving merchant clears floor")
	assert_eq(str(runner.get_last_return_reason()), "completed", "single merchant floor returns to hub")
	_free_runner(runner)


func test_event_choice_applies_outcome_and_advances() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.lingstones = 10
	var ap_events: Array = []
	var tower = _tower([_floor("event", {
		"event_id": "unit_event",
		"title": "Unit Event",
		"choices": [
			{"id": "take", "text": "Take", "outcome": {"lingstones": 25, "pollution": 5, "material_id": "shadow_dust", "ap_loss": 2}}
		],
	})])
	runner.open(tower, gs)
	gs.ap_changed.connect(func(current_ap: int, max_ap: int) -> void:
		ap_events.append({"ap": current_ap, "max": max_ap})
	)
	runner.enter_current_floor()
	assert_eq(str(runner.get_active_view_kind()), "event", "event floor opens choice panel")
	assert_eq(runner.get_event_choice_count(), 1, "event exposes one choice")
	runner.choose_event_option(0)
	assert_eq(int(gs.lingstones), 35, "event outcome grants lingstones")
	assert_eq(int(gs.pollution), 5, "event outcome applies pollution")
	assert_eq(int(gs.forge_materials.get("shadow_dust", 0)), 1, "event outcome grants material")
	assert_eq(int(gs.ap), 8, "event ap_loss spends AP after tower entry")
	assert_eq(ap_events.size(), 1, "event ap_loss emits ap_changed via spend_ap")
	assert_eq(str(tower.floors[0].resolution), "cleared", "event choice clears floor")
	_free_runner(runner)


func test_shrine_applies_service_payload_and_advances() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	var tower = _tower([_floor("shrine", {"shrine_type": "heal", "service_payload": {"heal_amount": 25}})])
	runner.open(tower, gs)
	runner.enter_current_floor()
	assert_eq(str(runner.get_active_view_kind()), "shrine", "shrine floor opens choice panel")
	runner.choose_event_option(0)
	assert_eq(int(gs.get_meta("tower_pending_heal", 0)), 25, "heal shrine records pending heal amount")
	assert_eq(str(tower.floors[0].resolution), "cleared", "shrine clears floor")
	_free_runner(runner)


func test_hub_wires_district_selector_to_city_scene() -> void:
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for district selector wiring")
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var district_panel = hub.get_node_or_null("DistrictSelect")
	assert_true(district_panel != null, "hub has DistrictSelect child")
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null, "hub creates CityScene child")
	if city != null and district_panel != null:
		district_panel.city_scene_requested.emit("shadow_alley")
		await Engine.get_main_loop().process_frame
		assert_true(city.visible, "district city_scene_requested opens CityScene")
		var title = city.find_child("DistrictNameLabel", true, false)
		assert_true(title is Label and str(title.text).contains("影巷"), "CityScene receives selected district")
	hub.queue_free()


func test_hub_records_live_tower_commission_completion() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_commission_state()
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for live commission completion")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var service = CommissionServiceScript.new()
	var accept: Dictionary = service.accept(GameState, "commission_steelworks_missing_001")
	assert_true(bool(accept.get("ok", false)), "steelworks commission accepts for live completion path")
	var execute: Dictionary = service.execute(GameState, "commission_steelworks_missing_001")
	assert_true(bool(execute.get("ok", false)), "steelworks commission executes for live completion path")
	hub.call("open_city_for_debug", "steelworks", "morning")
	await Engine.get_main_loop().process_frame
	_force_active_contract(GameState)
	var city = hub.get_node_or_null("CityScene")
	var tower_button = city.find_child("Hotspot_tower_entry_steelworks", true, false) if city != null else null
	assert_true(tower_button is Button, "steelworks city exposes tower hotspot")
	if tower_button is Button:
		tower_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var runner = hub.get_node_or_null("TowerRunner")
	assert_true(runner != null and runner.visible, "tower hotspot opens TowerRunner")
	if runner != null:
		var tower = runner.get_tower()
		assert_true(tower != null, "opened tower exists")
		if tower != null:
			assert_eq(str(tower.size), "medium", "accepted commission overrides tower size from hotspot")
			assert_eq(_tower_boss_id(tower), "slag_golem", "accepted commission overrides tower boss")
		runner.call("_complete_tower")
		await Engine.get_main_loop().process_frame
	assert_eq(str(service.status_for(GameState, "commission_steelworks_missing_001")), "completed", "tower completion records commission event")
	var claim: Dictionary = service.claim(GameState, "commission_steelworks_missing_001")
	assert_true(bool(claim.get("ok", false)), "completed tower commission can be claimed")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_records_live_tower_event_commission_completion() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_commission_state()
	GameState.day = 3
	GameState.current_district = "shadow_alley"
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for live tower-event commission")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var service = CommissionServiceScript.new()
	var accept: Dictionary = service.accept(GameState, "commission_shadow_well_inquiry_001")
	assert_true(bool(accept.get("ok", false)), "investigate commission accepts for live tower-event path")
	var execute: Dictionary = service.execute(GameState, "commission_shadow_well_inquiry_001")
	assert_true(bool(execute.get("ok", false)), "investigate commission executes for live tower-event path")
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	_force_active_contract(GameState)
	var city = hub.get_node_or_null("CityScene")
	var tower_button = city.find_child("Hotspot_tower_entry_shadow_alley", true, false) if city != null else null
	assert_true(tower_button is Button, "shadow alley city exposes marked tower-event hotspot")
	if tower_button is Button:
		tower_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var runner = hub.get_node_or_null("TowerRunner")
	assert_true(runner != null and runner.visible, "tower-event hotspot opens TowerRunner")
	if runner != null:
		var tower = runner.get_tower()
		assert_true(tower != null, "opened tower exists for tower-event commission")
		if tower != null:
			assert_true(_tower_has_event(tower, "well_bottom", "listen"), "commission tower injects required event and accepted choice")
		runner.enter_current_floor()
		await Engine.get_main_loop().process_frame
		assert_eq(str(runner.get_active_view_kind()), "event", "tower-event commission opens the required event floor first")
		runner.choose_event_option(0)
		await Engine.get_main_loop().process_frame
	assert_eq(str(service.status_for(GameState, "commission_shadow_well_inquiry_001")), "completed", "tower event choice records investigate commission completion")
	assert_true(not GameState.has_meta("commission_active_dispatch"), "completed tower-event commission clears active dispatch")
	var claim: Dictionary = service.claim(GameState, "commission_shadow_well_inquiry_001")
	assert_true(bool(claim.get("ok", false)), "completed tower-event commission can be claimed")
	hub.queue_free()
	GameState.from_dict(previous)


func _setup_commission_state() -> void:
	GameState.day = 4
	GameState.sequence = 9
	GameState.ap_max = 12
	GameState.ap = 12
	GameState.time_of_day = "morning"
	GameState.current_district = "steelworks"
	GameState.available_commissions.clear()
	GameState.accepted_commissions.clear()
	GameState.completed_commissions.clear()
	GameState.cards_inventory.clear()
	GameState.active_deck.clear()
	for card_id in ["starter_0", "starter_1", "starter_2", "starter_3", "starter_4"]:
		GameState.cards_inventory.append(_card(card_id))
		GameState.active_deck.append(card_id)
	for key in ["commission_active_dispatch", "commission_pending_completion", "commission_pending_includes_tower"]:
		if GameState.has_method("remove_meta") and GameState.has_meta(key):
			GameState.remove_meta(key)


func _runner():
	var scene = load(SCENE_PATH)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower_runner.tscn instantiable")
		return null
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	return runner


func _free_runner(runner) -> void:
	if runner != null:
		runner.queue_free()


func _tower(floors: Array):
	var tower = TowerScript.new()
	tower.tower_id = "unit_tower"
	tower.tower_name = "Unit Tower"
	tower.size = "small"
	tower.district = "shadow_alley"
	tower.floors = floors
	tower.floor_count = floors.size()
	return tower


func _floor(event_type: String, event_data: Dictionary):
	var floor = FloorScript.new()
	floor.floor_index = 0
	floor.event_type = event_type
	floor.event_data = event_data.duplicate(true)
	return floor


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.cards_inventory.append(_card("starter_0"))
	gs.cards_inventory.append(_card("starter_1"))
	gs.cards_inventory.append(_card("starter_2"))
	gs.cards_inventory.append(_card("starter_3"))
	gs.cards_inventory.append(_card("starter_4"))
	gs.active_deck.clear()
	for card_id in ["starter_0", "starter_1", "starter_2", "starter_3", "starter_4"]:
		gs.active_deck.append(str(card_id))
	return gs


func _card(id: String):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"quality": 3,
		"sequence": 9,
		"energy_cost": 1,
		"combat_effect": {"damage": 4, "heal": 0, "target": "single", "range": 1, "status_effects": []},
	})


func _card_ids(cards: Array) -> Array:
	var result: Array = []
	for card in cards:
		if card != null:
			result.append(str(card.id))
	return result


func _battle_card_ids(battle) -> Array:
	if battle == null:
		return []
	var result: Array = []
	for zone in [battle.draw_pile, battle.hand, battle.discard_pile, battle.exhaust_pile, battle.temp_picked_cards]:
		for card in zone:
			if card != null:
				result.append(str(card.id))
	return result


func _force_active_contract(state) -> void:
	if state == null:
		return
	var rules: Array[String] = []
	for rule in state.learned_rules:
		rules.append(str(rule))
		if rules.size() >= 3:
			break
	if rules.size() < 3:
		rules = ["rule_a", "rule_b", "rule_c"]
	state.active_contract.clear()
	for rule in rules:
		state.active_contract.append(str(rule))


func _tower_boss_id(tower) -> String:
	if tower == null:
		return ""
	for i in range(tower.floors.size() - 1, -1, -1):
		var floor = tower.floors[i]
		if floor != null and str(floor.event_type) == "boss":
			var data: Dictionary = floor.event_data if floor.event_data is Dictionary else {}
			return str(data.get("boss_id", ""))
	return ""


func _tower_has_event(tower, event_id: String, choice_id: String) -> bool:
	if tower == null:
		return false
	for floor in tower.floors:
		if floor == null or str(floor.event_type) != "event":
			continue
		var data: Dictionary = floor.event_data if floor.event_data is Dictionary else {}
		if str(data.get("event_id", "")) != event_id:
			continue
		var choices: Variant = data.get("choices", [])
		if choices is Array:
			for choice in choices:
				if choice is Dictionary and str((choice as Dictionary).get("id", "")) == choice_id:
					return true
	return false


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
