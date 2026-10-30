extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "npc event narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_npc_events.gd --")
	test_npc_first_meet_relation_shift_layer_reveal_and_perception_swap_contexts()
	return {"passed": _passed, "failed": _failed}


func test_npc_first_meet_relation_shift_layer_reveal_and_perception_swap_contexts() -> void:
	var service = NpcInteractionServiceScript.new()
	assert_true(service.has_method("set_ai_gm_service"), "NpcInteractionService exposes set_ai_gm_service()")
	assert_true(service.has_method("request_npc_perception_swap_ai_gm"), "NpcInteractionService exposes request_npc_perception_swap_ai_gm()")
	if not service.has_method("set_ai_gm_service") or not service.has_method("request_npc_perception_swap_ai_gm"):
		return

	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	service.call("set_ai_gm_service", fake_service)
	var open_result: Dictionary = service.call("open_dialogue", "old_li", gs)
	assert_true(bool(open_result.get("ok", false)), "open_dialogue succeeds for npc_first_meet")
	assert_eq(str(open_result.get("ai_gm_text", "")), "npc event narration", "open_dialogue returns npc_first_meet AI GM text")

	var state = gs.npc_relations.get("old_li", null)
	assert_true(state != null, "old_li state exists after first meet")
	if state == null:
		return
	state.trust = 58
	state.layer_revealed = 0
	var commit_result: Dictionary = service.call("commit_dialogue_outcome", "old_li", {
		"trust_delta": 2,
		"layer_revealed_to": 1,
		"dialogue_rounds": 1,
	}, gs)
	assert_true(bool(commit_result.get("ok", false)), "commit_dialogue_outcome succeeds for relation/layer events")
	assert_true(commit_result.get("ai_gm_texts", {}) is Dictionary, "commit result stores npc AI GM text map")
	var swap_text: String = str(service.call("request_npc_perception_swap_ai_gm", "old_li", gs, "harvey", "borrowed_name"))
	assert_eq(swap_text, "npc event narration", "npc_perception_swap returns AI GM text")

	assert_eq(fake_service.calls.size(), 4, "NPC service calls AI GM for first_meet, relation_shift, layer_reveal, perception_swap")
	if fake_service.calls.size() < 4:
		return
	_assert_context(fake_service.calls[0], "npc_first_meet", "NPC_FIRST_MEET_TEMPLATES")
	_assert_context(fake_service.calls[1], "npc_relation_shift", "NPC_RELATION_SHIFT_TEMPLATES")
	_assert_context(fake_service.calls[2], "npc_layer_reveal", "NPC_LAYER_REVEAL_TEMPLATES")
	_assert_context(fake_service.calls[3], "npc_perception_swap", "NPC_PERCEPTION_SWAP_TEMPLATES")


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 26
	gs.pollution_stage = 0
	gs.cycle = 1
	gs.day = 3
	gs.time_of_day = "night"
	gs.current_district = "shadow_alley"
	gs.ap = 12
	return gs


func _assert_context(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("npc_id", "")), "old_li", "%s payload npc_id" % expected_scene)
	assert_eq(str(ctx.npc_context.get("target_npc_id", "")), "old_li", "%s npc_context target" % expected_scene)


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
