extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const DebugPanelScript = preload("res://scripts/debug/debug_panel.gd")
const TemplatePoolsScript = preload("res://scripts/ai_gm/template_pools.gd")

const HUD_PATH := "res://scripts/ui/hud.gd"
const HUB_PATH := "res://scripts/hub/hub.gd"

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		if ctx != null and str(ctx.scene) == "lost_control_narration":
			return "lost control narration"
		return "ai text"


func run() -> Dictionary:
	print("\n-- test_lost_control_full.gd --")
	test_pollution_100_enters_fool_lost_control_state()
	test_lost_control_narration_builds_valid_prompt_context()
	test_hud_and_hub_expose_lost_control_visual_state()
	test_lost_control_auto_play_is_deterministic_and_requests_narration()
	test_lost_control_battle_setup_auto_plays_first_player_turn()
	test_second_lost_control_turn_death_resets_and_preserves_five_rules()
	await test_debug_panel_fill_pollution_triggers_lost_control()
	return {"passed": _passed, "failed": _failed}


func test_pollution_100_enters_fool_lost_control_state() -> void:
	var gs = _game_state()
	assert_true(gs.has_method("enter_lost_control"), "GameState exposes enter_lost_control(recent_actions)")
	var result: Dictionary = gs.set_pollution(100, ["slice4_t8_probe"])
	assert_eq(int(gs.pollution), 100, "pollution clamps at 100")
	assert_eq(int(gs.pollution_stage), 5, "pollution 100 maps to lost-control stage 5")
	assert_true(bool(gs.is_lost_control), "pollution 100 sets is_lost_control")
	assert_true(result.has("lost_control"), "set_pollution returns lost_control payload")
	var lost: Dictionary = result.get("lost_control", {}) if result.get("lost_control", {}) is Dictionary else {}
	assert_eq(str(lost.get("state", "")), "fool_lost_control", "lost-control state names Fool form")
	assert_eq(int(lost.get("death_after_turns", 0)), 2, "Fool lost-control MVP death timer is 2 turns")
	assert_eq(int(lost.get("turns_elapsed", -1)), 0, "lost-control starts before any auto turn")
	var visuals: Array = lost.get("visual_motifs", []) if lost.get("visual_motifs", []) is Array else []
	assert_true(visuals.has("shadow_consumes_body"), "lost-control payload includes shadow-consuming visual")
	assert_true(visuals.has("split_doubles"), "lost-control payload includes doubles visual")
	assert_true(visuals.has("open_doors"), "lost-control payload includes open-door visual")


func test_lost_control_narration_builds_valid_prompt_context() -> void:
	var gs = _game_state()
	var fake := FakeAIGMService.new()
	gs.set_ai_gm_service(fake)
	gs.set_pollution(100, ["narration_probe"])
	assert_true(gs.has_method("request_lost_control_narration_ai_gm"), "GameState exposes lost-control AI GM narration request")
	if not gs.has_method("request_lost_control_narration_ai_gm"):
		return
	var text := str(gs.call("request_lost_control_narration_ai_gm", {
		"turn_index": 1,
		"source": "battle_turn_start",
		"auto_card_id": "mask_a",
	}))
	assert_eq(text, "lost control narration", "lost-control narration returns AI GM text")
	assert_true(fake.calls.size() >= 1, "lost-control narration calls AI GM")
	if fake.calls.is_empty():
		return
	var ctx = fake.calls[fake.calls.size() - 1]
	assert_eq(str(ctx.scene), "lost_control_narration", "lost-control narration uses new scene id")
	assert_eq(str(ctx.fallback_template_pool), "LOST_CONTROL_TEMPLATES", "lost-control narration uses fallback pool")
	assert_eq(int(ctx.player_state.get("pollution", -1)), 100, "lost-control narration player_state has pollution 100")
	assert_eq(int(ctx.player_state.get("pollution_stage", -1)), 5, "lost-control narration player_state has stage 5")
	assert_eq(str(ctx.scene_payload.get("lost_control_state", "")), "fool_lost_control", "payload includes state")
	assert_eq(str(ctx.scene_payload.get("pathway", "")), "fool", "payload includes Fool pathway")
	assert_eq(int(ctx.scene_payload.get("turn_index", -1)), 1, "payload includes turn_index")
	assert_eq(str(ctx.scene_payload.get("source", "")), "battle_turn_start", "payload includes source")
	assert_eq(str(ctx.scene_payload.get("auto_card_id", "")), "mask_a", "payload includes auto card id")
	assert_true(bool(ctx.validate().get("valid", false)), "lost-control PromptContext validates")
	var pools = TemplatePoolsScript.new()
	assert_true(pools.get_templates("LOST_CONTROL_TEMPLATES").size() >= 30, "lost-control fallback pool has at least 30 templates")


func test_hud_and_hub_expose_lost_control_visual_state() -> void:
	var hud_script = load(HUD_PATH)
	assert_true(hud_script != null and hud_script.can_instantiate(), "Hud script loads")
	if hud_script != null and hud_script.can_instantiate():
		var hud = hud_script.new()
		var visual: Dictionary = hud.call("pollution_visual_for_stage", 5)
		assert_eq(str(visual.get("mode", "")), "lost_control", "HUD stage 5 visual marks lost_control mode")
		assert_true(float(visual.get("edge_intensity", 0.0)) >= 1.0, "HUD lost-control edge intensity is red-pressure maximum")
		assert_true(bool(visual.get("shadow_overlay", false)), "HUD lost-control visual enables shadow overlay")
		hud.free()

	var hub_script = load(HUB_PATH)
	assert_true(hub_script != null and hub_script.can_instantiate(), "Hub script loads")
	if hub_script == null or not hub_script.can_instantiate():
		return
	var hub = hub_script.new()
	assert_true(hub.has_method("lost_control_visual_state"), "Hub exposes lost_control_visual_state(game_state)")
	if not hub.has_method("lost_control_visual_state"):
		hub.free()
		return
	var gs = _game_state()
	gs.set_pollution(100, ["visual_probe"])
	var state: Dictionary = hub.call("lost_control_visual_state", gs)
	assert_eq(str(state.get("background_state", "")), "lost_control", "Hub switches to lost-control background state")
	var motifs: Array = state.get("visual_motifs", []) if state.get("visual_motifs", []) is Array else []
	assert_true(motifs.has("shadow_consumes_body"), "Hub visual includes shadow consuming body")
	assert_true(motifs.has("split_doubles"), "Hub visual includes multiple doubles")
	assert_true(motifs.has("open_doors"), "Hub visual includes unclosed doors")
	hub.free()


func test_lost_control_auto_play_is_deterministic_and_requests_narration() -> void:
	var first := _lost_control_battle()
	var second := _lost_control_battle()
	assert_true(first.battle.has_method("lost_control_auto_play_turn"), "TurnBattle exposes lost_control_auto_play_turn(seed)")
	if not first.battle.has_method("lost_control_auto_play_turn"):
		return
	var result_a: Dictionary = first.battle.call("lost_control_auto_play_turn", 407)
	var result_b: Dictionary = second.battle.call("lost_control_auto_play_turn", 407)
	assert_true(bool(result_a.get("ok", false)), "lost-control auto turn succeeds")
	assert_eq(str(result_a.get("card_id", "")), str(result_b.get("card_id", "")), "same seed chooses same card")
	assert_eq(str(result_a.get("target_id", "")), str(result_b.get("target_id", "")), "same seed chooses same target")
	assert_eq(int(first.battle.hand.size()), 1, "auto-play removes exactly one card from hand")
	assert_true(first.battle.used_cards.has(str(result_a.get("card_id", ""))), "auto-play records used card")
	assert_eq(int(first.gs.lost_control_state.get("turns_elapsed", -1)), 1, "auto-play advances lost-control turn count")
	assert_eq(first.fake.calls.size(), 1, "auto-play requests one lost-control narration")
	if not first.fake.calls.is_empty():
		assert_eq(str(first.fake.calls[0].scene), "lost_control_narration", "auto-play narration uses lost_control_narration")


func test_lost_control_battle_setup_auto_plays_first_player_turn() -> void:
	var gs = _game_state()
	var fake := FakeAIGMService.new()
	gs.set_ai_gm_service(fake)
	gs.set_pollution(100, ["runtime_setup_probe"])
	fake.calls.clear()
	var card_a = _card("setup_mask_a", 6)
	var card_b = _card("setup_door_b", 4)
	var enemy_a = _enemy("setup_enemy_a", 40, 0)
	var enemy_b = _enemy("setup_enemy_b", 40, 0)
	var battle = TurnBattleScript.new()
	battle.setup_battle([card_a, card_b], [], [enemy_a, enemy_b], [] as Array[String], null, gs)
	assert_eq(fake.calls.size(), 1, "lost-control battle setup requests narration during first automatic player turn")
	assert_eq(int(gs.lost_control_state.get("turns_elapsed", -1)), 1, "battle setup advances lost-control turn count after automatic play")
	assert_eq(battle.used_cards.size(), 1, "battle setup auto-plays exactly one card")
	assert_eq(int(battle.hand.size()), 1, "battle setup leaves one card in hand after auto-play")
	assert_eq(int(battle.phase), int(battle.Phase.ENEMY_TURN), "battle setup hands control to enemy phase after lost-control auto-play")


func test_second_lost_control_turn_death_resets_and_preserves_five_rules() -> void:
	var gs = _game_state()
	_replace_string_array(gs.learned_rules, ["rule_a", "rule_b", "rule_c", "rule_d", "rule_e", "rule_f"])
	gs.set_pollution(100, ["death_probe"])
	assert_true(gs.has_method("advance_lost_control_turn"), "GameState exposes advance_lost_control_turn(context)")
	if not gs.has_method("advance_lost_control_turn"):
		return
	var first: Dictionary = gs.call("advance_lost_control_turn", {"source": "unit_first"})
	assert_true(not bool(first.get("dead", true)), "first lost-control turn does not kill")
	var second: Dictionary = gs.call("advance_lost_control_turn", {"source": "unit_second"})
	assert_true(bool(second.get("dead", false)), "second lost-control turn kills MVP character")
	assert_eq(str(second.get("outcome", "")), "lost_control_death", "death payload names lost_control_death")
	assert_true(second.get("death_screen", {}) is Dictionary, "death payload includes death_screen data for UI")
	assert_eq(int(gs.cycle), 2, "lost-control death resets into next cycle")
	assert_eq(int(gs.pollution), 0, "lost-control reset clears pollution")
	assert_eq(int(gs.pollution_stage), 0, "lost-control reset clears pollution stage")
	assert_true(not bool(gs.is_lost_control), "lost-control reset clears is_lost_control")
	var inherited: Array = gs.daodian.get("inherited_lost_control_rules", []) if gs.daodian.get("inherited_lost_control_rules", []) is Array else []
	assert_eq(inherited, ["rule_a", "rule_b", "rule_c", "rule_d", "rule_e"], "Daodian inherits first five learned rules")
	for rule in inherited:
		assert_true(str(rule) in gs.learned_rules, "new character learned_rules keeps inherited rule %s" % str(rule))


func test_debug_panel_fill_pollution_triggers_lost_control() -> void:
	var gs = _game_state()
	var panel = DebugPanelScript.new()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	panel.open(gs)
	assert_true(panel.has_method("fill_pollution_to_lost_control"), "DebugPanel exposes fill_pollution_to_lost_control()")
	if panel.has_method("fill_pollution_to_lost_control"):
		var result: Dictionary = panel.call("fill_pollution_to_lost_control")
		assert_true(bool(result.get("ok", false)), "DebugPanel fill pollution reports ok")
		assert_eq(int(gs.pollution), 100, "DebugPanel fills pollution to 100")
		assert_eq(int(gs.pollution_stage), 5, "DebugPanel fill reaches stage 5")
		assert_true(bool(gs.is_lost_control), "DebugPanel fill triggers lost control")
	panel.queue_free()
	await Engine.get_main_loop().process_frame


func _lost_control_battle() -> Dictionary:
	var gs = _game_state()
	var fake := FakeAIGMService.new()
	gs.set_ai_gm_service(fake)
	gs.set_pollution(100, ["auto_probe"])
	fake.calls.clear()
	var card_a = _card("mask_a", 7)
	var card_b = _card("door_b", 5)
	var enemy_a = _enemy("enemy_a", 30, 0)
	var enemy_b = _enemy("enemy_b", 30, 0)
	var battle = TurnBattleScript.new()
	battle.setup_battle([card_a, card_b], [], [enemy_a, enemy_b], [] as Array[String], null, gs)
	battle.phase = battle.Phase.PLAYER_TURN
	gs.lost_control_state["turns_elapsed"] = 0
	fake.calls.clear()
	battle.hand = [card_a, card_b]
	battle.draw_pile.clear()
	battle.discard_pile.clear()
	battle.energy = 10
	return {"gs": gs, "fake": fake, "battle": battle}


func _card(id: String, damage: int):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"quality": 1,
		"energy_cost": 0,
		"combat_effect": {"damage": damage, "target": "single"},
		"acting_rules": [],
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
	gs.cycle = 1
	gs.pollution = 0
	gs.pollution_stage = 0
	gs.is_lost_control = false
	return gs


func _replace_string_array(target: Array[String], values: Array) -> void:
	target.clear()
	for value in values:
		target.append(str(value))


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
