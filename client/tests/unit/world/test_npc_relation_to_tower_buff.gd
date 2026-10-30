extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")

const CARD_LIBRARY_PATH := "res://scripts/combat/card_library.gd"
const SHOP_SERVICE_PATH := "res://scripts/shop/shop_service.gd"
const TOWER_GENERATOR_PATH := "res://scripts/tower/tower_generator.gd"
const TOWER_RUNNER_SCENE := "res://scenes/tower/tower_runner.tscn"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_npc_relation_to_tower_buff.gd --")
	test_card_library_rolls_shadow_alley_low_pool()
	await test_tower_open_applies_relation_buffs_with_caps_and_shop_discount()
	await test_tower_open_applies_suspicion_debuffs_and_extra_elite()
	await test_hub_city_tower_hotspot_opens_tower_runner_with_relation_feedback()
	await test_hub_city_tower_contract_picker_suppresses_city_surface()
	return {"passed": _passed, "failed": _failed}


func test_card_library_rolls_shadow_alley_low_pool() -> void:
	var script = load(CARD_LIBRARY_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "CardLibrary script loads")
		return
	var library = script.new()
	assert_true(library.has_method("roll_from_pool"), "CardLibrary exposes roll_from_pool")
	if not library.has_method("roll_from_pool"):
		return
	var card = library.call("roll_from_pool", "shadow_alley_low", 17)
	assert_true(card != null, "shadow_alley_low pool rolls a card")
	if card == null:
		return
	assert_eq(str(card.pathway), "fool", "shadow_alley_low uses structured fool pathway")
	assert_eq(int(card.sequence), 9, "shadow_alley_low rolls sequence 9 low-tier cards")
	assert_true(str(card.template_id) != "", "rolled temp card keeps template_id")


func test_tower_open_applies_relation_buffs_with_caps_and_shop_discount() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var gs = _state()
	gs.ap = 12
	gs.npc_relations["old_li"] = _npc_state(95, 0)
	gs.npc_relations["xiao_ran"] = _npc_state(95, 0)
	var tower = _tower([_floor("event", {"choices": []}), _floor("boss", {"boss_id": "alley_horror"})])

	runner.open(tower, gs)

	assert_eq(gs.temp_picked_cards.size(), 1, "tower start grants at most one free temp card across NPCs")
	if gs.temp_picked_cards.size() > 0:
		var temp_card = gs.temp_picked_cards[0]
		assert_eq(str(temp_card.pathway), "fool", "free temp card is selected by structured pathway")
		assert_eq(int(temp_card.sequence), 9, "free temp card comes from low-tier sequence 9 pool")
	assert_eq(_count_string(gs.learned_rules, "shadow_silence"), 1, "tower start unlocks shadow_silence rule once")
	var discounts := _shop_discounts(gs)
	assert_eq(int(discounts.get("donen_blackmarket", 0)), 10, "old_li trusted buff prepares one donen black market discount")
	_free_runner(runner)


func test_tower_open_applies_suspicion_debuffs_and_extra_elite() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var generator = _tower_generator()
	if generator == null:
		_free_runner(runner)
		return
	assert_true(generator.has_method("inject_extra_elite_floor"), "TowerGenerator exposes inject_extra_elite_floor")
	var gs = _state()
	gs.ap = 12
	gs.church_awareness = 9
	gs.set_ai_gm_service(FakeThresholdAIGMService.new())
	gs.npc_relations["old_li"] = _npc_state(0, 80)
	var tower = _tower([_floor("battle", {"enemy_ids": ["drunkard"]}), _floor("boss", {"boss_id": "alley_horror"})])
	tower.theme_modifiers["npc_feedback_seed"] = 0
	var before_floor_count: int = tower.floors.size()

	runner.open(tower, gs)

	assert_eq(int(gs.church_awareness), 19, "suspicion 80 reports to church once on tower start")
	assert_true(_has_threshold(gs, 10), "tower suspicion report crossing 10 records church threshold event")
	assert_true(_threshold_ai_text(gs, 10) != "", "tower suspicion threshold event stores AI GM text")
	assert_eq(tower.floors.size(), before_floor_count + 1, "suspicion extra elite injects exactly one extra floor")
	assert_eq(_elite_count(tower), 1, "extra elite cap keeps one injected elite floor")
	assert_eq(str(tower.floors.back().event_type), "boss", "extra elite insertion keeps boss as final floor")
	_free_runner(runner)


func test_hub_city_tower_hotspot_opens_tower_runner_with_relation_feedback() -> void:
	var previous: Dictionary = GameState.to_dict()
	var fresh = _state()
	GameState.from_dict(fresh.to_dict())
	fresh.queue_free()
	GameState.ap = 12
	GameState.npc_relations["old_li"] = _npc_state(40, 0)
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame

	var door = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	if door is Button:
		door.pressed.emit()
		await Engine.get_main_loop().process_frame
	var selector = hub.get_node_or_null("DistrictSelect")
	if selector != null:
		var shadow = selector.find_child("DistrictRow_shadow_alley", true, false)
		if shadow is Button:
			shadow.pressed.emit()
			await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Hub path opens CityScene before tower entry")
	if city != null:
		var tower_button = city.find_child("Hotspot_tower_entry_shadow_alley", true, false)
		assert_true(tower_button is Button, "CityScene exposes shadow_alley tower hotspot")
		if tower_button is Button:
			_seed_active_contract(GameState)
			tower_button.pressed.emit()
			await Engine.get_main_loop().process_frame
	var tower_runner = hub.get_node_or_null("TowerRunner")
	assert_true(tower_runner != null and tower_runner.visible, "tower hotspot opens visible TowerRunner from Hub path")
	assert_eq(GameState.temp_picked_cards.size(), 1, "Hub tower path applies relation free temp card")
	assert_eq(int(GameState.ap), 10, "Hub tower path spends small tower AP after 0 AP city roaming")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_city_tower_contract_picker_suppresses_city_surface() -> void:
	var previous: Dictionary = GameState.to_dict()
	var fresh = _state()
	GameState.from_dict(fresh.to_dict())
	fresh.queue_free()
	GameState.ap = 12
	GameState.active_contract.clear()
	_replace_string_array(GameState.learned_rules, ["rule_a", "rule_b", "rule_c", "rule_d"])
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for contract picker overlay path")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame

	var door = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	if door is Button:
		door.pressed.emit()
		await Engine.get_main_loop().process_frame
	var selector = hub.get_node_or_null("DistrictSelect")
	if selector != null:
		var shadow = selector.find_child("DistrictRow_shadow_alley", true, false)
		if shadow is Button:
			shadow.pressed.emit()
			await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Hub path opens CityScene before contract picker")
	var city_surface = city.get_node_or_null("UILayer/RootMargin") if city != null else null
	assert_true(city_surface != null and city_surface.visible, "CityScene interaction surface is visible before tower contract picker")
	if city != null:
		var tower_button = city.find_child("Hotspot_tower_entry_shadow_alley", true, false)
		assert_true(tower_button is Button, "CityScene exposes tower hotspot for contract picker path")
		if tower_button is Button:
			tower_button.pressed.emit()
			await Engine.get_main_loop().process_frame
	var picker = hub.get_node_or_null("ContractPickerDialog")
	assert_true(picker != null and picker.visible, "tower hotspot opens contract picker when active contract is incomplete")
	assert_true(selector == null or not selector.visible, "district selector stays hidden under contract picker")
	assert_true(city_surface != null and not city_surface.visible, "CityScene interaction surface is suppressed under contract picker")
	if picker != null and picker.has_method("select_rule"):
		picker.call("select_rule", "rule_a", true)
		picker.call("select_rule", "rule_b", true)
		picker.call("select_rule", "rule_c", true)
	if picker != null and picker.has_method("lock_selection"):
		picker.call("lock_selection")
		await Engine.get_main_loop().process_frame
	var tower_runner = hub.get_node_or_null("TowerRunner")
	assert_true(tower_runner != null and tower_runner.visible, "locking contract opens TowerRunner")
	assert_true(city == null or not city.visible, "CityScene hides after contract lock enters tower")
	hub.queue_free()
	GameState.from_dict(previous)


func _runner():
	var scene = load(TOWER_RUNNER_SCENE)
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


func _tower_generator():
	var script = load(TOWER_GENERATOR_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "TowerGenerator script loads")
		return null
	return script.new()


func _tower(floors: Array):
	var tower = TowerScript.new()
	tower.tower_id = "npc_feedback_unit_tower"
	tower.tower_name = "NPC Feedback Unit Tower"
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
	return gs


func _seed_active_contract(state) -> void:
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


func _replace_string_array(target: Array[String], values: Array) -> void:
	target.clear()
	for value in values:
		target.append(str(value))


func _npc_state(trust: int, suspicion: int):
	var state = NpcKnowledgeStateScript.new()
	state.trust = trust
	state.suspicion = suspicion
	return state


func _shop_discounts(game_state) -> Dictionary:
	var value = game_state.get("shop_discounts")
	if value is Dictionary:
		return value
	return {}


func _elite_count(tower) -> int:
	var count := 0
	for floor in tower.floors:
		if floor != null and str(floor.event_type) == "elite":
			count += 1
	return count


func _count_string(values: Array, expected: String) -> int:
	var count := 0
	for value in values:
		if str(value) == expected:
			count += 1
	return count


func _has_threshold(gs, threshold: int) -> bool:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return true
	return false


func _threshold_ai_text(gs, threshold: int) -> String:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return str((event as Dictionary).get("ai_gm_text", "")).strip_edges()
	return ""


class FakeThresholdAIGMService:
	extends RefCounted

	func call_ai_gm(_ctx) -> String:
		return "church threshold test text"


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
