extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const R20EffectEngineScript = preload("res://scripts/world/r20_effect_engine.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "t13 ai gm text"


func run() -> Dictionary:
	print("\n-- test_social_pollution_full.gd --")
	test_social_effect_types_apply_t13_fixed_pollution_deltas()
	test_social_resolve_payload_reports_cost_and_side_effects()
	test_r20_social_pollution_uses_set_pollution_stage_hooks()
	return {"passed": _passed, "failed": _failed}


func test_social_effect_types_apply_t13_fixed_pollution_deltas() -> void:
	var rows := [
		{"type": "modify_suspicion", "delta": 1},
		{"type": "read_truth", "delta": 3},
		{"type": "extract_memory", "delta": 3},
		{"type": "extract_secret", "delta": 3},
		{"type": "forget_event", "delta": 5},
	]
	for row in rows:
		var social_type := str(row.get("type", ""))
		var expected_delta := int(row.get("delta", 0))
		var gs = _game_state()
		var result: Dictionary = R20EffectEngineScript.new().dispatch_card(_card(social_type), "old_li", {"game_state": gs})
		assert_true(bool(result.get("success", false)), "%s dispatch succeeds" % social_type)
		assert_eq(int(result.get("pollution_delta", -1)), expected_delta, "%s returns T13 fixed pollution delta" % social_type)
		assert_eq(int(gs.pollution), expected_delta, "%s applies T13 fixed pollution delta to GameState" % social_type)
		var side_effects: Dictionary = _dict(result.get("side_effects_applied", {}))
		assert_eq(int(side_effects.get("pollution", -1)), expected_delta, "%s side_effects_applied reports pollution delta" % social_type)
		gs.queue_free()

	var override_state = _game_state()
	var override_result: Dictionary = R20EffectEngineScript.new().dispatch_card(
		_card("forget_event", {"pollution_delta": 2}),
		"old_li",
		{"game_state": override_state}
	)
	assert_eq(int(override_result.get("pollution_delta", -1)), 2, "explicit pollution_delta override remains authoritative")
	assert_eq(int(override_state.pollution), 2, "explicit pollution_delta override applies to GameState")
	override_state.queue_free()


func test_social_resolve_payload_reports_cost_and_side_effects() -> void:
	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	var engine = R20EffectEngineScript.new()
	engine.set_ai_gm_service(fake_service)
	var result: Dictionary = engine.dispatch_card(_card("modify_suspicion", {"suspicion_delta": -7}), "old_li", {"game_state": gs})
	assert_true(bool(result.get("success", false)), "dispatch succeeds for payload cost test")
	assert_eq(int(gs.hub_mana), 8, "dispatch spends hub_mana once")
	var side_effects: Dictionary = _dict(result.get("side_effects_applied", {}))
	assert_eq(int(side_effects.get("hub_mana", 0)), -2, "side_effects_applied reports hub_mana cost")
	assert_eq(int(side_effects.get("pollution", 0)), 1, "side_effects_applied reports pollution")
	assert_eq(int(side_effects.get("church_awareness", 0)), 1, "side_effects_applied reports church awareness")
	assert_eq(int(side_effects.get("suspicion_delta", 0)), -7, "side_effects_applied reports suspicion_delta")
	var result_payload: Dictionary = _dict(result.get("ai_gm_payload", {}))
	assert_eq(int(result_payload.get("hub_mana_cost", 0)), 2, "result ai_gm_payload includes hub_mana_cost")
	assert_eq(_dict(result_payload.get("side_effects_applied", {})), side_effects, "result ai_gm_payload includes side_effects_applied")
	assert_eq(fake_service.calls.size(), 1, "social_resolve AI GM called once")
	if fake_service.calls.size() > 0:
		var payload: Dictionary = fake_service.calls[0].scene_payload
		assert_eq(int(payload.get("hub_mana_cost", 0)), 2, "social_resolve PromptContext includes hub_mana_cost")
		assert_eq(_dict(payload.get("side_effects_applied", {})), side_effects, "social_resolve PromptContext includes side_effects_applied")
	gs.queue_free()


func test_r20_social_pollution_uses_set_pollution_stage_hooks() -> void:
	var gs = _game_state()
	gs.pollution = 49
	gs.pollution_stage = 1
	var fake_service := FakeAIGMService.new()
	gs.set_ai_gm_service(fake_service)
	var engine = R20EffectEngineScript.new()
	engine.set_ai_gm_service(fake_service)
	var emitted: Array = []
	gs.pollution_stage_changed.connect(Callable(self, "_record_stage_signal").bind(emitted))

	var result: Dictionary = engine.dispatch_card(_card("read_truth"), "old_li", {"game_state": gs})
	assert_true(bool(result.get("success", false)), "read_truth social dispatch succeeds")
	assert_eq(int(gs.pollution), 52, "read_truth pushes pollution across stage 2 threshold")
	assert_eq(int(gs.pollution_stage), 2, "R20 social pollution recalculates pollution_stage")
	assert_eq(emitted, [[1, 2]], "R20 social pollution emits pollution_stage_changed through set_pollution")
	assert_true(_has_ai_scene(fake_service.calls, "pollution_stage_transition"), "R20 social pollution calls pollution_stage_transition AI GM")
	assert_true(_has_ai_scene(fake_service.calls, "social_resolve"), "R20 social dispatch still calls social_resolve AI GM")
	gs.queue_free()


func _record_stage_signal(from_stage: int, to_stage: int, emitted: Array) -> void:
	emitted.append([from_stage, to_stage])


func _card(social_type: String, extra: Dictionary = {}):
	var social := {"type": social_type}
	for key in extra.keys():
		social[key] = extra[key]
	return CardScript.from_json({
		"id": "slice4_t13_%s" % social_type,
		"template_id": "slice4_t13_%s" % social_type,
		"display_name": "Slice 4 T13 Probe",
		"pathway": "fool",
		"sequence": 8,
		"energy_cost": 2,
		"combat_effect": {"damage": 1, "target": "single"},
		"social_effect": social,
	})


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.day = 6
	gs.time_of_day = "evening"
	gs.current_district = "shadow_alley"
	gs.hub_mana = 10
	var state = NpcKnowledgeStateScript.new()
	state.suspicion = 40
	gs.npc_relations["old_li"] = state
	return gs


func _has_ai_scene(calls: Array, scene: String) -> bool:
	for ctx in calls:
		if ctx != null and str(ctx.scene) == scene:
			return true
	return false


func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


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
