extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")

const HUD_PATH := "res://scripts/ui/hud.gd"
const HUB_PATH := "res://scripts/hub/hub.gd"
const HUB_SCENE_PATH := "res://scenes/hub/hub.tscn"
const AUTO_SAVE_PATH := "user://slice4_t7_sleep_auto.json"
const POLLUTION_NPCS := [
	"old_li",
	"peter_furnace",
	"vera_lighthouse",
	"victor_kelsey",
	"hanna_gardener",
	"xuming_recluse",
]

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		if ctx != null and str(ctx.scene) == "dream_pollution_stage":
			return "AI dream stage text"
		return "AI pollution stage text"


func run() -> Dictionary:
	print("\n-- test_pollution_stages_full.gd --")
	test_pollution_stage_transition_calls_once_per_adjacent_crossing()
	test_hud_pollution_stage_visuals_have_five_distinct_configs()
	await test_hub_scene_mounts_runtime_pollution_hud()
	await test_hub_scene_applies_lost_control_visual_tint()
	test_sleep_dream_calls_ai_gm_with_stage_context()
	test_npc_dialogue_adds_pollution_stage_gated_line_for_six_residents()
	test_contract_pollution_multiplier_retests_all_five_stages_and_signs()
	test_high_pollution_window_summary_mentions_other_self()
	return {"passed": _passed, "failed": _failed}


func test_pollution_stage_transition_calls_once_per_adjacent_crossing() -> void:
	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	var emitted: Array = []
	gs.set_ai_gm_service(fake_service)
	assert_true(gs.has_signal("pollution_stage_changed"), "GameState exposes pollution_stage_changed for HUD timing")
	if gs.has_signal("pollution_stage_changed"):
		gs.connect("pollution_stage_changed", Callable(self, "_record_stage_signal").bind(emitted))

	for value in [30, 49, 50, 79, 80, 94, 95, 99, 100]:
		gs.set_pollution(int(value), ["slice4_t7_probe"])

	var expected_pairs := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5]]
	assert_eq(fake_service.calls.size(), expected_pairs.size(), "pollution stage AI GM calls once per adjacent crossing")
	assert_eq(emitted, expected_pairs, "pollution_stage_changed emits only on cross-stage changes")
	for i in range(mini(fake_service.calls.size(), expected_pairs.size())):
		var ctx = fake_service.calls[i]
		var expected_pair: Array = expected_pairs[i]
		assert_eq(str(ctx.scene), "pollution_stage_transition", "transition %d uses pollution_stage_transition scene" % i)
		assert_eq(str(ctx.fallback_template_pool), "POLLUTION_STAGE_TEMPLATES", "transition %d uses pollution fallback pool" % i)
		assert_eq(int(ctx.scene_payload.get("from_stage", -1)), int(expected_pair[0]), "transition %d from_stage" % i)
		assert_eq(int(ctx.scene_payload.get("to_stage", -1)), int(expected_pair[1]), "transition %d to_stage" % i)
		assert_true(bool(ctx.validate().get("valid", false)), "transition %d PromptContext validates" % i)


func test_hud_pollution_stage_visuals_have_five_distinct_configs() -> void:
	assert_true(ResourceLoader.exists(HUD_PATH), "client/scripts/ui/hud.gd exists")
	if not ResourceLoader.exists(HUD_PATH):
		return
	var hud_script = load(HUD_PATH)
	assert_true(hud_script != null and hud_script.can_instantiate(), "Hud script loads and can instantiate")
	if hud_script == null or not hud_script.can_instantiate():
		return
	var hud = hud_script.new()
	assert_true(hud.has_method("pollution_visual_for_stage"), "Hud exposes pollution_visual_for_stage(stage)")
	assert_true(hud.has_method("apply_pollution_stage_visual"), "Hud exposes apply_pollution_stage_visual(stage)")
	assert_true(hud.has_method("bind_game_state"), "Hud can bind to GameState stage-change timing")
	if not hud.has_method("pollution_visual_for_stage"):
		hud.free()
		return
	var signatures: Array[String] = []
	for stage in range(5):
		var visual: Dictionary = hud.call("pollution_visual_for_stage", stage)
		assert_true(visual.has("filter_color"), "stage %d visual has filter_color" % stage)
		assert_true(visual.has("status_bar_color"), "stage %d visual has status_bar_color" % stage)
		assert_true(visual.has("edge_color"), "stage %d visual has edge_color" % stage)
		assert_true(visual.has("edge_intensity"), "stage %d visual has edge_intensity" % stage)
		assert_true(str(visual.get("label", "")).length() > 0, "stage %d visual has label" % stage)
		var signature := "%s|%s|%s|%.3f" % [
			str(visual.get("filter_color", "")),
			str(visual.get("status_bar_color", "")),
			str(visual.get("edge_color", "")),
			float(visual.get("edge_intensity", 0.0)),
		]
		if not signatures.has(signature):
			signatures.append(signature)
	assert_eq(signatures.size(), 5, "pollution stages 0-4 have five distinct HUD visual configs")
	hud.free()


func test_hub_scene_mounts_runtime_pollution_hud() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.pollution = 0
	GameState.pollution_stage = 0
	GameState.is_lost_control = false
	GameState.lost_control_state.clear()
	var scene = load(HUB_SCENE_PATH)
	assert_true(scene != null and scene.can_instantiate(), "Hub scene loads for runtime HUD mount")
	if scene == null or not scene.can_instantiate():
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var hud = hub.find_child("PollutionHud", true, false)
	assert_true(hud != null, "Hub scene mounts PollutionHud at runtime")
	if hud != null:
		assert_true(hud.has_method("bind_game_state"), "runtime PollutionHud exposes bind_game_state")
		var filter = hud.find_child("PollutionFilter", true, false)
		var status_bar = hud.find_child("PollutionStatusBar", true, false)
		var edge_top = hud.find_child("PollutionEdgeTop", true, false)
		assert_true(filter is ColorRect, "runtime HUD renders a pollution filter ColorRect")
		assert_true(status_bar is ColorRect, "runtime HUD renders a status-bar tint ColorRect")
		assert_true(edge_top is ColorRect, "runtime HUD renders screen-edge ColorRects")
		GameState.set_pollution(80, ["hub_runtime_hud_probe"])
		await Engine.get_main_loop().process_frame
		assert_eq(int(hud.current_pollution_stage), 3, "runtime PollutionHud follows GameState pollution_stage_changed")
		if filter is ColorRect:
			assert_true((filter as ColorRect).color.a > 0.2, "runtime HUD filter alpha visibly increases at pollution stage 3")
		if edge_top is ColorRect:
			assert_true((edge_top as ColorRect).color.a > 0.25, "runtime HUD edge tint visibly increases at pollution stage 3")
	hub.queue_free()
	await Engine.get_main_loop().process_frame
	GameState.from_dict(previous)


func test_hub_scene_applies_lost_control_visual_tint() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(previous)
	GameState.pollution = 0
	GameState.pollution_stage = 0
	GameState.is_lost_control = false
	GameState.lost_control_state.clear()
	var scene = load(HUB_SCENE_PATH)
	assert_true(scene != null and scene.can_instantiate(), "Hub scene loads for lost-control visual tint")
	if scene == null or not scene.can_instantiate():
		GameState.from_dict(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	GameState.set_pollution(100, ["hub_lost_control_visual_probe"])
	await Engine.get_main_loop().process_frame
	var tint = hub.find_child("LostControlBackgroundTint", true, false)
	assert_true(tint is ColorRect, "Hub scene mounts a runtime lost-control background tint")
	if tint is ColorRect:
		assert_true((tint as ColorRect).visible, "Hub lost-control tint becomes visible at pollution 100")
		assert_true((tint as ColorRect).color.a >= 0.25, "Hub lost-control tint has visible alpha")
		assert_eq(int((tint as ColorRect).mouse_filter), int(Control.MOUSE_FILTER_IGNORE), "Hub lost-control tint does not intercept input")
	GameState.pollution = 0
	GameState.pollution_stage = 0
	GameState.is_lost_control = false
	GameState.lost_control_state.clear()
	await Engine.get_main_loop().process_frame
	if tint is ColorRect:
		assert_true(not (tint as ColorRect).visible, "Hub lost-control tint hides outside lost-control state")
	hub.queue_free()
	await Engine.get_main_loop().process_frame
	GameState.from_dict(previous)


func test_sleep_dream_calls_ai_gm_with_stage_context() -> void:
	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	gs.set_ai_gm_service(fake_service)
	gs.pollution = 80
	gs.pollution_stage = 3
	gs.ap = 12
	gs.ap_max = 12
	gs.day = 4
	gs.time_of_day = "night"
	gs.current_weather = "sunny"

	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, AUTO_SAVE_PATH, 0.0)
	var dream: Dictionary = result.get("dream", {}) if result.get("dream", {}) is Dictionary else {}
	assert_eq(int(dream.get("pollution_stage", -1)), 3, "sleep dream keeps stage 3")
	assert_eq(str(dream.get("ai_gm_text", "")), "AI dream stage text", "sleep dream includes AI GM text")
	assert_eq(fake_service.calls.size(), 1, "sleep dream calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	assert_eq(str(ctx.scene), "dream_pollution_stage", "dream AI GM uses dream_pollution_stage scene")
	assert_eq(str(ctx.fallback_template_pool), "DREAM_STAGE_TEMPLATES", "dream AI GM uses dream fallback pool")
	assert_eq(int(ctx.player_state.get("pollution_stage", -1)), 3, "dream AI GM player_state has pollution_stage")
	assert_eq(int(ctx.scene_payload.get("pollution_stage", -1)), 3, "dream AI GM payload has pollution_stage")
	assert_true(str(ctx.scene_payload.get("dream_title", "")).length() > 0, "dream AI GM payload has title")
	assert_true(str(ctx.scene_payload.get("dream_tone", "")).length() > 0, "dream AI GM payload has tone")
	assert_true(str(ctx.scene_payload.get("fallback_text", "")).length() > 0, "dream AI GM payload has fallback text")
	assert_true(bool(ctx.validate().get("valid", false)), "dream PromptContext validates")


func test_npc_dialogue_adds_pollution_stage_gated_line_for_six_residents() -> void:
	var service = NpcInteractionServiceScript.new()
	assert_true(service.has_method("pollution_stage_lines_for_npc"), "NpcInteractionService exposes pollution_stage_lines_for_npc()")
	if not service.has_method("pollution_stage_lines_for_npc"):
		return
	for npc_id in POLLUTION_NPCS:
		var low_state = _game_state()
		low_state.pollution = 49
		low_state.pollution_stage = 1
		var high_state = _game_state()
		high_state.pollution = 50
		high_state.pollution_stage = 2
		var low_lines: Array = service.call("pollution_stage_lines_for_npc", str(npc_id), low_state)
		var high_lines: Array = service.call("pollution_stage_lines_for_npc", str(npc_id), high_state)
		assert_eq(low_lines.size(), 0, "%s has no pollution line below stage 2" % str(npc_id))
		assert_eq(high_lines.size(), 1, "%s has one pollution line at stage 2+" % str(npc_id))
		if high_lines.is_empty():
			continue
		var line := str(high_lines[0])
		assert_true(line.contains("脸色") or line.contains("不对") or line.contains("污染"), "%s pollution line hints at abnormal appearance" % str(npc_id))
		var dialogue: Dictionary = service.open_dialogue(str(npc_id), high_state)
		assert_true(str(dialogue.get("dialogue_preview", "")).contains(line), "%s open_dialogue includes pollution stage line" % str(npc_id))


func test_contract_pollution_multiplier_retests_all_five_stages_and_signs() -> void:
	var rows := [
		{"stage": 0, "pollution": 10, "full_delta": -1, "broken_delta": 5},
		{"stage": 1, "pollution": 35, "full_delta": -2, "broken_delta": 5},
		{"stage": 2, "pollution": 60, "full_delta": -1, "broken_delta": 10},
		{"stage": 3, "pollution": 85, "full_delta": -1, "broken_delta": 10},
		{"stage": 4, "pollution": 96, "full_delta": -1, "broken_delta": 20},
	]
	for row in rows:
		var stage := int(row.get("stage", 0))
		var full := _resolve_contract_at_stage(stage, int(row.get("pollution", 0)), true)
		assert_eq(int(full.get("pollution_delta", 0)), int(row.get("full_delta", 0)), "stage %d full-contract multiplier delta" % stage)
		var broken := _resolve_contract_at_stage(stage, int(row.get("pollution", 0)), false)
		assert_eq(int(broken.get("pollution_delta", 0)), int(row.get("broken_delta", 0)), "stage %d broken-contract multiplier delta" % stage)


func test_high_pollution_window_summary_mentions_other_self() -> void:
	var hub_script = load(HUB_PATH)
	assert_true(hub_script != null and hub_script.can_instantiate(), "Hub script loads for window observation")
	if hub_script == null or not hub_script.can_instantiate():
		return
	var hub = hub_script.new()
	assert_true(hub.has_method("window_observation_text"), "Hub exposes window_observation_text(game_state)")
	if not hub.has_method("window_observation_text"):
		hub.free()
		return
	var high_state = _game_state()
	high_state.pollution = 100
	high_state.pollution_stage = 5
	high_state.current_weather = "storm"
	high_state.time_of_day = "night"
	var text := str(hub.call("window_observation_text", high_state))
	assert_true(text.contains("另一个你"), "stage 5 window observation mentions the other self")
	assert_true(text.begins_with("窗外"), "window observation remains player-facing window copy")
	hub.free()


func _record_stage_signal(from_stage: int, to_stage: int, emitted: Array) -> void:
	emitted.append([from_stage, to_stage])


func _resolve_contract_at_stage(stage: int, pollution: int, full: bool) -> Dictionary:
	var gs = _game_state()
	gs.pollution = pollution
	gs.pollution_stage = stage
	var card = _card("slice4_t7_stage_%d_%s" % [stage, "full" if full else "broken"], ["rule_a"] if full else [])
	var battle = TurnBattleScript.new()
	battle.setup_battle([card], [], [_enemy("slice4_t7_dummy", 200, 0)], ["rule_a"] as Array[String], null, gs)
	battle.play_card(card, battle.enemies[0])
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)
	return result.get("contract", {}) if result.get("contract", {}) is Dictionary else {}


func _card(id: String, rules: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"quality": 1,
		"energy_cost": 0,
		"combat_effect": {"damage": 1, "target": "single"},
		"acting_rules": rules,
	})


func _enemy(id: String, hp: int, defense: int):
	var enemy = EnemyScript.new()
	enemy.id = id
	enemy.display_name = id
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.def = defense
	return enemy


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.ap = 12
	gs.ap_max = 12
	gs.pollution = 0
	gs.pollution_stage = 0
	return gs


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
