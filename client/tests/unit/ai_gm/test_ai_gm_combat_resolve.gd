extends RefCounted

const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "combat critical narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_combat_resolve.gd --")
	test_combat_resolve_critical_context_is_called_on_victory_resolution()
	return {"passed": _passed, "failed": _failed}


func test_combat_resolve_critical_context_is_called_on_victory_resolution() -> void:
	var battle = TurnBattleScript.new()
	assert_true(battle.has_method("set_ai_gm_service"), "TurnBattle exposes set_ai_gm_service()")
	if not battle.has_method("set_ai_gm_service"):
		return
	var fake_service := FakeAIGMService.new()
	battle.call("set_ai_gm_service", fake_service)

	var gs = _game_state()
	var card = _card("decisive_card", ["rule_a"])
	var enemy = _enemy("critical_target", 3, 0)
	battle.setup_battle([card], [], [enemy], ["rule_a"] as Array[String], null, gs)
	assert_true(battle.play_card(card, enemy), "decisive card can be played before combat resolve")

	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)

	assert_eq(str(result.get("ai_gm_text", "")), "combat critical narration", "resolve_battle returns combat AI GM text")
	assert_eq(fake_service.calls.size(), 1, "combat_resolve_critical calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "combat_resolve_critical", "COMBAT_RESOLVE_TEMPLATES", int(gs.pollution))
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("decisive_card_id", "")), "decisive_card", "combat_resolve payload includes decisive_card_id")
	assert_eq(str(payload.get("target", "")), "critical_target", "combat_resolve payload includes target")
	assert_eq(int(payload.get("hp_remaining", -1)), 0, "combat_resolve payload includes hp_remaining")
	assert_eq(str(payload.get("contract_outcome", "")), "full", "combat_resolve payload includes contract_outcome")


func _card(id: String, acting_rules: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"energy_cost": 0,
		"quality": 3,
		"sequence": 9,
		"acting_rules": acting_rules,
		"combat_effect": {"damage": 5, "heal": 0, "target": "single", "range": 1, "status_effects": []},
	})


func _enemy(id: String, hp: int, defense: int):
	return EnemyScript.from_json({
		"id": id,
		"display_name": id,
		"stats": {"hp": hp, "max_hp": hp, "atk": 1, "def": defense, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 9
	gs.pollution = 24
	gs.pollution_stage = 0
	gs.cycle = 1
	gs.day = 4
	gs.time_of_day = "noon"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String, expected_pollution: int) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 9, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), expected_pollution, "%s player_state.pollution" % expected_scene)
	assert_eq(str(ctx.player_state.get("time_of_day", "")), "noon", "%s player_state.time_of_day" % expected_scene)


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
