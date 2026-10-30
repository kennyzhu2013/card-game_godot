extends RefCounted

const ContextScript = preload("res://scripts/ai_gm/prompt_context.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_prompt_context.gd --")
	test_defaults()
	test_to_dict_from_dict_roundtrip()
	test_scene_payload_nested()
	test_t1_fields_roundtrip()
	test_to_dict_returns_deep_copies_for_t1_fields()
	return {"passed": _passed, "failed": _failed}


func test_defaults() -> void:
	var ctx = ContextScript.new()
	assert_eq(ctx.scene, "", "default scene empty")
	assert_eq(ctx.player_state, {}, "default player_state empty")
	assert_eq(ctx.scene_payload, {}, "default scene_payload empty")
	if not _assert_context_has_t1_fields(ctx):
		return
	assert_eq(ctx.get("contract_state"), {}, "default contract_state empty")
	assert_eq(ctx.get("npc_context"), {}, "default npc_context empty")
	assert_eq(ctx.get("fallback_template_pool"), "", "default fallback_template_pool empty")


func test_to_dict_from_dict_roundtrip() -> void:
	var ctx = ContextScript.new()
	ctx.scene = "forge_resolve"
	ctx.player_state = {"sequence": 9, "pollution": 20, "cycle": 1}
	ctx.scene_payload = {"card_id": "shadow_arrow_q3", "quality": 3}

	var d = ctx.to_dict()
	var ctx2 = ContextScript.from_dict(d)

	assert_eq(ctx2.scene, "forge_resolve", "rt scene")
	assert_eq(ctx2.player_state.get("sequence", 0), 9, "rt player_state.sequence")
	assert_eq(ctx2.player_state.get("pollution", 0), 20, "rt player_state.pollution")
	assert_eq(ctx2.scene_payload.get("card_id", ""), "shadow_arrow_q3", "rt scene_payload.card_id")
	assert_eq(ctx2.scene_payload.get("quality", 0), 3, "rt scene_payload.quality")


func test_scene_payload_nested() -> void:
	var ctx = ContextScript.new()
	ctx.scene = "npc_reveal"
	ctx.scene_payload = {"npc_id": "bishop_victor", "layer": 2, "revealed": ["true_name", "past_deed"]}
	var d = ctx.to_dict()
	var ctx2 = ContextScript.from_dict(d)
	assert_eq(ctx2.scene, "npc_reveal", "nested rt scene")
	var payload = ctx2.scene_payload
	assert_eq(payload.get("npc_id", ""), "bishop_victor", "nested rt npc_id")
	assert_eq(payload.get("layer", 0), 2, "nested rt layer")
	var revealed: Array = payload.get("revealed", [])
	assert_eq(revealed.size(), 2, "nested rt revealed size")


func test_t1_fields_roundtrip() -> void:
	var ctx = ContextScript.new()
	if not _assert_context_has_t1_fields(ctx):
		return
	ctx.scene = "social_resolve"
	ctx.player_state = {"sequence": 8, "pollution": 45, "cycle": 2}
	ctx.scene_payload = {"card_id": "mirror_shadow", "social_type": "identity_mask"}
	ctx.set("contract_state", {
		"active_contract": ["永远多一个面具", "不承诺真相"],
		"last_resolve_ratio": 0.66,
		"satisfied_rules": ["永远多一个面具"],
		"violated_rules": ["不承诺真相"],
	})
	ctx.set("npc_context", {"target_npc_id": "old_li", "active_perception": "stranger", "suspicion": 12, "trust": 45})
	ctx.set("fallback_template_pool", "SOCIAL_RESOLVE_TEMPLATES")

	var ctx2 = ContextScript.from_dict(ctx.to_dict())

	assert_eq(ctx2.get("contract_state").get("last_resolve_ratio", 0.0), 0.66, "rt contract_state.last_resolve_ratio")
	assert_eq(ctx2.get("contract_state").get("satisfied_rules", []).size(), 1, "rt contract_state.satisfied_rules")
	assert_eq(ctx2.get("npc_context").get("target_npc_id", ""), "old_li", "rt npc_context.target_npc_id")
	assert_eq(ctx2.get("npc_context").get("active_perception", ""), "stranger", "rt npc_context.active_perception")
	assert_eq(ctx2.get("fallback_template_pool"), "SOCIAL_RESOLVE_TEMPLATES", "rt fallback_template_pool")


func test_to_dict_returns_deep_copies_for_t1_fields() -> void:
	var ctx = ContextScript.new()
	if not _assert_context_has_t1_fields(ctx):
		return
	ctx.set("contract_state", {"active_contract": ["永远多一个面具"]})
	ctx.set("npc_context", {"traits": {"voice": "low"}})

	var payload := ctx.to_dict()
	payload["contract_state"]["active_contract"].append("不承诺真相")
	payload["npc_context"]["traits"]["voice"] = "changed"

	assert_eq(ctx.get("contract_state").get("active_contract", []).size(), 1, "contract_state deep copied")
	assert_eq(ctx.get("npc_context").get("traits", {}).get("voice", ""), "low", "npc_context deep copied")


func _assert_context_has_t1_fields(ctx) -> bool:
	var ok := true
	for prop in ["contract_state", "npc_context", "fallback_template_pool"]:
		var has_prop := _has_property(ctx, prop)
		assert_true(has_prop, "PromptContext exposes %s" % prop)
		ok = ok and has_prop
	return ok


func _has_property(obj, prop_name: String) -> bool:
	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == prop_name:
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
