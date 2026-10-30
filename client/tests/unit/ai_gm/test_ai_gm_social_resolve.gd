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
		return "social resolve narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_social_resolve.gd --")
	test_social_resolve_builds_valid_prompt_context_from_dispatch()
	return {"passed": _passed, "failed": _failed}


func test_social_resolve_builds_valid_prompt_context_from_dispatch() -> void:
	var engine = R20EffectEngineScript.new()
	assert_true(engine.has_method("set_ai_gm_service"), "R20EffectEngine exposes set_ai_gm_service()")
	assert_true(engine.has_method("request_social_resolve_ai_gm"), "R20EffectEngine exposes request_social_resolve_ai_gm()")
	if not engine.has_method("set_ai_gm_service") or not engine.has_method("request_social_resolve_ai_gm"):
		return

	var gs = _game_state()
	var state = NpcKnowledgeStateScript.new()
	state.trust = 45
	state.suspicion = 35
	gs.npc_relations["old_li"] = state
	var fake_service := FakeAIGMService.new()
	engine.call("set_ai_gm_service", fake_service)

	var result: Dictionary = engine.call("dispatch_card", _social_card(), "old_li", {"game_state": gs, "source": "unit_test"})
	assert_true(bool(result.get("success", false)), "dispatch_card succeeds for social_resolve")
	assert_eq(str(result.get("ai_gm_text", "")), "social resolve narration", "dispatch_card returns social AI GM text")
	assert_eq(fake_service.calls.size(), 1, "social_resolve calls AI GM once")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "social_resolve", "SOCIAL_RESOLVE_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("card_id", "")), "shadow_jester_probe", "social_resolve payload includes card_id")
	assert_eq(str(payload.get("social_type", "")), "identity_mask", "social_resolve payload includes social_type")
	assert_eq(str(payload.get("target_npc_id", "")), "old_li", "social_resolve payload includes target_npc_id")
	assert_eq(int(payload.get("suspicion_delta", 0)), -12, "social_resolve payload includes suspicion_delta")
	assert_eq(int(payload.get("awareness_delta", 0)), 2, "social_resolve payload includes awareness_delta")
	assert_eq(str(ctx.npc_context.get("target_npc_id", "")), "old_li", "social_resolve npc_context target")
	assert_eq(str(ctx.npc_context.get("active_perception", "")), "stranger", "social_resolve npc_context perception after cast")


func _social_card():
	return CardScript.from_json({
		"id": "shadow_jester_probe",
		"template_id": "shadow_jester_probe",
		"display_name": "Shadow Jester Probe",
		"energy_cost": 1,
		"combat_effect": {"damage": 1, "target": "single"},
		"social_effect": {
			"type": "identity_mask",
			"duration_days": 2,
			"suspicion_delta": -12,
			"church_awareness_delta": 2,
			"pollution_delta": 1,
		},
	})


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 41
	gs.pollution_stage = 1
	gs.cycle = 1
	gs.day = 6
	gs.time_of_day = "night"
	gs.hub_mana = 10
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 8, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), 42, "%s player_state.pollution after social cast" % expected_scene)


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
