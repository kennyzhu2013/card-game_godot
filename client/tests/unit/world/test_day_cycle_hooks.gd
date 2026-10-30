extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const PromotionRitualServiceScript = preload("res://scripts/sequence/promotion_ritual_service.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")

const DAY_CYCLE_PATH := "res://scripts/world/day_cycle_service.gd"
const CYCLE_END_PATH := "res://scripts/world/cycle_end_service.gd"
const HUB_SCENE := "res://scenes/hub/hub.tscn"
const AUTO_SAVE_PATH := "user://day_cycle_hooks_auto.json"

const HOOKS := {
	1: {"file": "res://data/mainline/mainline_day1.json", "node": "node_1_tutorial_tower"},
	3: {"file": "res://data/mainline/mainline_day3.json", "node": "node_2_black_market"},
	7: {"file": "res://data/mainline/mainline_day7.json", "node": "node_3_halfmoon_contact"},
	10: {"file": "res://data/mainline/mainline_day10.json", "node": "node_4_promotion_98"},
	12: {"file": "res://data/mainline/mainline_day12.json", "node": "node_5_church_investigation"},
	14: {"file": "res://data/mainline/mainline_day14.json", "node": "node_6_final_tower"},
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_day_cycle_hooks.gd --")
	test_mainline_hook_data_files_exist()
	test_sleep_emits_day_changed_and_runs_day_hook()
	test_day_cycle_service_triggers_six_mainline_hooks()
	await test_day7_mainline_prompt_includes_ai_gm_text()
	await test_sequence_promotion_completion_surfaces_ai_gm_text()
	await test_day10_hub_promotion_button_highlight()
	test_advance_time_segment_cycles_to_night_without_silent_sleep()
	test_cycle_end_resets_to_cycle_two()
	await test_cycle_end_completion_surfaces_ai_gm_text()
	return {"passed": _passed, "failed": _failed}


func test_mainline_hook_data_files_exist() -> void:
	for day in HOOKS.keys():
		var path: String = str(HOOKS[day].get("file", ""))
		assert_true(FileAccess.file_exists(path), "mainline hook data exists for Day %d" % int(day))
		var data: Dictionary = _json(path)
		assert_eq(int(data.get("day", 0)), int(day), "mainline data day %d" % int(day))
		assert_eq(str(data.get("node_id", "")), str(HOOKS[day].get("node", "")), "mainline node id for Day %d" % int(day))


func test_sleep_emits_day_changed_and_runs_day_hook() -> void:
	var gs = _state()
	gs.day = 2
	gs.time_of_day = "night"
	var seen: Array = []
	if not gs.has_signal("day_changed"):
		assert_true(false, "GameState exposes day_changed signal")
		return
	gs.day_changed.connect(func(day: int, cycle: int) -> void:
		seen.append({"day": day, "cycle": cycle})
	)
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH, 0.0)
	assert_true(bool(result.get("ok", false)), "sleep succeeds for day cycle hook")
	assert_eq(int(gs.day), 3, "sleep advances to Day 3")
	assert_eq(seen.size(), 1, "sleep emits day_changed once")
	if seen.size() > 0:
		assert_eq(int(seen[0].get("day", 0)), 3, "day_changed emits new day")
	assert_true(_completed_nodes(gs).has("node_2_black_market"), "sleep Day 3 records black market hook")
	assert_true(bool(gs.get_meta("mainline_popup_pending", false)), "sleep Day 3 marks placeholder popup pending")


func test_day_cycle_service_triggers_six_mainline_hooks() -> void:
	var service = _script(DAY_CYCLE_PATH, "DayCycleService")
	if service == null:
		return
	for day in HOOKS.keys():
		var gs = _state()
		gs.day = int(day)
		var result: Dictionary = service.apply_day_hooks(gs)
		assert_true(bool(result.get("triggered", false)), "Day %d hook triggers" % int(day))
		assert_eq(str(result.get("node_id", "")), str(HOOKS[day].get("node", "")), "Day %d hook returns node" % int(day))
		assert_true(_completed_nodes(gs).has(str(HOOKS[day].get("node", ""))), "Day %d records completed node" % int(day))
		assert_true(str(gs.get_meta("mainline_popup_text", "")) != "", "Day %d has placeholder popup text" % int(day))


func test_day7_mainline_prompt_includes_ai_gm_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_state().to_dict())
	GameState.day = 7
	var service = _script(DAY_CYCLE_PATH, "DayCycleService")
	if service == null:
		GameState.from_dict(previous)
		return
	var result: Dictionary = service.apply_day_hooks(GameState)
	assert_true(bool(result.get("triggered", false)), "Day 7 mainline hook triggers")
	assert_true(str(result.get("ai_gm_text", "")) != "", "Day 7 mainline hook returns AI GM text")
	assert_true(str(GameState.get_meta("mainline_ai_gm_text", "")) != "", "Day 7 mainline hook stores AI GM text on GameState")
	GameState.set_meta("mainline_ai_gm_text", "day7 surface probe")
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_show_mainline_prompt", {
		"triggered": true,
		"day": 7,
		"title": "Day 7 Hook",
		"popup_text": "Hook body",
	})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("MainlineDialog")
	assert_true(dialog != null and dialog.visible, "Day 7 mainline prompt opens visible dialog")
	if dialog != null:
		var text := str(dialog.dialog_text)
		assert_true(text.contains("Hook body"), "Day 7 mainline prompt keeps the hook body")
		assert_true(text.contains("day7 surface probe"), "Day 7 mainline prompt surfaces AI GM text")
	hub.queue_free()
	GameState.from_dict(previous)


func test_sequence_promotion_completion_surfaces_ai_gm_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_state().to_dict())
	GameState.sequence = 9
	GameState.sequence_exp = 100
	GameState.known_reactions.clear()
	for i in range(8):
		GameState.known_reactions.append("rx_%d" % i)
	GameState.active_contract.clear()
	GameState.active_contract.append("rule_a")
	GameState.active_contract.append("rule_b")
	GameState.active_contract.append("rule_c")
	GameState.daodian["completed_main_story_nodes"] = ["node_4_promotion_98"]
	var start_result: Dictionary = PromotionRitualServiceScript.start_ritual("fool_9_to_8", GameState)
	assert_true(bool(start_result.get("ok", false)), "sequence promotion ritual starts for AI GM visibility")
	var tower = start_result.get("tower", null)
	if tower == null:
		GameState.from_dict(previous)
		return
	var complete_result: Dictionary = PromotionRitualServiceScript.complete(tower, GameState)
	assert_true(str(complete_result.get("ai_gm_text", "")) != "", "sequence promotion completion returns AI GM text")
	assert_true(str(GameState.get_meta("sequence_promotion_ai_gm_text", "")) != "", "sequence promotion completion stores AI GM text on GameState")
	GameState.set_meta("sequence_promotion_ai_gm_text", "sequence promotion surface probe")
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_on_tower_runner_returned", "completed")
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("MainlineDialog")
	assert_true(dialog != null and dialog.visible, "sequence promotion completion opens a visible dialog")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("sequence promotion surface probe"), "sequence promotion completion surfaces AI GM text")
	hub.queue_free()
	GameState.from_dict(previous)


func test_day10_hub_promotion_button_highlight() -> void:
	var previous: Dictionary = GameState.to_dict()
	_configure_day10_promotable(GameState, 10)
	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for Day10 promotion highlight")
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var prompt = hub.find_child("PromotionButton", true, false)
	assert_true(prompt != null, "Day10 hub promotion prompt exists")
	if prompt != null:
		var has_visual_override: bool = prompt.modulate != Color.WHITE or prompt.has_theme_stylebox_override("normal")
		assert_true(has_visual_override, "Day10 promotion prompt has visual highlight beyond text")
	hub.queue_free()
	_configure_day10_promotable(GameState, 9)
	hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	prompt = hub.find_child("PromotionButton", true, false)
	assert_true(prompt != null, "Day9 promotion prompt exists for negative highlight check")
	if prompt != null:
		assert_true(prompt.modulate == Color.WHITE and not prompt.has_theme_stylebox_override("normal"), "Day9 promotion prompt has no Day10 visual override")
	hub.queue_free()
	GameState.from_dict(previous)


func test_advance_time_segment_cycles_to_night_without_silent_sleep() -> void:
	var service = _script(DAY_CYCLE_PATH, "DayCycleService")
	if service == null:
		return
	var gs = _state()
	gs.day = 4
	gs.time_of_day = "morning"
	assert_eq(str(service.advance_time_segment(gs).get("time_of_day", "")), "noon", "morning advances to noon")
	assert_eq(str(service.advance_time_segment(gs).get("time_of_day", "")), "evening", "noon advances to evening")
	assert_eq(str(service.advance_time_segment(gs).get("time_of_day", "")), "night", "evening advances to night")
	assert_true(not bool(gs.get_meta("force_sleep_pending", false)), "reaching night keeps night gameplay available")
	var blocked: Dictionary = service.advance_time_segment(gs, AUTO_SAVE_PATH, 0.0)
	assert_true(bool(blocked.get("forced_sleep_required", false)), "night advance requires Hub forced sleep prompt instead of silent sleep")
	assert_true(bool(gs.get_meta("force_sleep_pending", false)), "advancing beyond night marks force sleep pending for Hub")
	assert_eq(int(gs.day), 4, "night advance does not silently advance day")
	assert_eq(str(gs.time_of_day), "night", "night advance keeps time at night until player confirms sleep")


func test_cycle_end_resets_to_cycle_two() -> void:
	var service = _script(CYCLE_END_PATH, "CycleEndService")
	if service == null:
		return
	var gs = _state()
	gs.cycle = 1
	gs.day = 14
	gs.time_of_day = "night"
	gs.pollution = 40
	gs.cards_inventory.clear()
	gs.cards_inventory.append("card_a")
	gs.cards_inventory.append("card_b")
	gs.forge_materials = {"iron": 5}
	gs.npc_relations = {"old_li": {"dialog_count": 3}}
	gs.accepted_commissions.clear()
	gs.accepted_commissions.append("job_a")
	gs.accepted_commissions.append("job_b")
	gs.learned_rules.clear()
	gs.learned_rules.append("custom_rule")
	gs.lingstones = 99
	gs.halfmoon_trust = 1
	gs.shop_inventories = {"donen_blackmarket": {"stock": 1}}
	var day_events: Array = []
	gs.day_changed.connect(func(day: int, cycle: int) -> void:
		day_events.append({"day": day, "cycle": cycle})
	)
	var result: Dictionary = service.complete_cycle(gs)
	assert_true(bool(result.get("ok", false)), "cycle end completes")
	assert_eq(int(result.get("completed_cycle", 0)), 1, "cycle end reports completed cycle 1")
	assert_eq(int(gs.cycle), 2, "cycle end increments to cycle 2")
	assert_eq(int(gs.day), 1, "cycle end resets to Day 1")
	assert_eq(str(gs.time_of_day), "morning", "cycle end resets to morning")
	assert_eq(int(gs.pollution), 0, "cycle end reset clears pollution")
	assert_eq(gs.cards_inventory.size(), 0, "cycle end reset clears cards_inventory")
	assert_eq(gs.forge_materials, {}, "cycle end reset clears forge_materials")
	assert_eq(gs.npc_relations, {}, "cycle end reset clears npc_relations")
	assert_eq(gs.accepted_commissions, [], "cycle end reset clears accepted_commissions")
	assert_eq(gs.learned_rules.size(), 5, "cycle end reset rebuilds learned_rules defaults")
	assert_eq(int(gs.lingstones), 10, "cycle end reset restores lingstones to 10")
	assert_eq(int(gs.halfmoon_trust), 30, "cycle end reset restores halfmoon_trust to 30")
	assert_eq(gs.shop_inventories, {}, "cycle end reset clears shop_inventories")
	assert_eq(day_events.size(), 1, "cycle end emits day_changed after reset")
	if day_events.size() > 0:
		assert_eq(int(day_events[0].get("day", 0)), 1, "cycle end day_changed emits reset day 1")
		assert_eq(int(day_events[0].get("cycle", 0)), 2, "cycle end day_changed emits new cycle")
	assert_true(str(result.get("summary", "")) != "", "cycle end returns static placeholder summary")


func test_cycle_end_completion_surfaces_ai_gm_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_state().to_dict())
	var service = _script(CYCLE_END_PATH, "CycleEndService")
	if service == null:
		GameState.from_dict(previous)
		return
	var result: Dictionary = service.complete_cycle(GameState)
	assert_true(str(result.get("ai_gm_text", "")) != "", "cycle end service returns AI GM text")
	assert_true(str(GameState.get_meta("cycle_end_ai_gm_text", "")) != "", "cycle end service stores AI GM text on GameState")
	GameState.set_meta("cycle_end_summary", "cycle end summary probe")
	GameState.set_meta("cycle_end_ai_gm_text", "cycle end surface probe")
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_on_tower_runner_returned", "completed")
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("MainlineDialog")
	assert_true(dialog != null and dialog.visible, "cycle end completion opens a visible dialog")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("cycle end summary probe"), "cycle end completion surfaces cycle summary")
		assert_true(str(dialog.dialog_text).contains("cycle end surface probe"), "cycle end completion surfaces AI GM text")
	hub.queue_free()
	GameState.from_dict(previous)


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _script(path: String, label: String):
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s script loads" % label)
		return null
	return script


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _completed_nodes(gs) -> Array:
	var nodes: Variant = gs.daodian.get("completed_main_story_nodes", [])
	return nodes if nodes is Array else []


func _configure_day10_promotable(gs, day: int = 10) -> void:
	gs.day = day
	gs.sequence = 9
	gs.sequence_exp = 100
	gs.pollution = 10
	gs.known_reactions.clear()
	for i in range(8):
		gs.known_reactions.append("rx_%d" % i)
	gs.active_contract.clear()
	for rule in ["永远多一个面具", "旁观者守则", "不直呼神名"]:
		gs.active_contract.append(rule)
	gs.daodian["completed_main_story_nodes"] = ["node_4_promotion_98"]
	gs.set_meta("promotion_day10_highlight", true)


func _hub():
	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


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
