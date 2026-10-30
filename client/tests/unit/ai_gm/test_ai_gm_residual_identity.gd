extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const ResidualIdentityScript = preload("res://scripts/world/residual_identity.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "residual identity narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_residual_identity.gd --")
	test_residual_identity_create_and_expire_build_valid_prompt_contexts()
	return {"passed": _passed, "failed": _failed}


func test_residual_identity_create_and_expire_build_valid_prompt_contexts() -> void:
	var identity = _identity()
	assert_true(identity.has_method("set_ai_gm_service"), "ResidualIdentity exposes set_ai_gm_service()")
	assert_true(identity.has_method("request_residual_identity_create_ai_gm"), "ResidualIdentity exposes request_residual_identity_create_ai_gm()")
	assert_true(identity.has_method("request_residual_identity_expire_ai_gm"), "ResidualIdentity exposes request_residual_identity_expire_ai_gm()")
	if not identity.has_method("set_ai_gm_service") or not identity.has_method("request_residual_identity_create_ai_gm") or not identity.has_method("request_residual_identity_expire_ai_gm"):
		return

	var gs = _game_state()
	var fake_service := FakeAIGMService.new()
	identity.call("set_ai_gm_service", fake_service)
	var create_text: String = str(identity.call("request_residual_identity_create_ai_gm", gs))
	var expire_text: String = str(identity.call("request_residual_identity_expire_ai_gm", gs))

	assert_eq(create_text, "residual identity narration", "residual_identity_create returns AI GM text")
	assert_eq(expire_text, "residual identity narration", "residual_identity_expire returns AI GM text")
	assert_eq(fake_service.calls.size(), 2, "residual identity create/expire call AI GM")
	if fake_service.calls.size() < 2:
		return
	_assert_context(fake_service.calls[0], "residual_identity_create", 4)
	_assert_context(fake_service.calls[1], "residual_identity_expire", 0)


func _identity():
	return ResidualIdentityScript.from_dict({
		"id": "borrowed_face_old_li",
		"name": "Old Li's Borrowed Face",
		"source_npc": "old_li",
		"created_at_day": 4,
		"expires_at_day": 9,
		"allowed_locations": ["old_li", "shadow_alley"],
		"uses_remaining": 2,
	})


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 8
	gs.pollution = 37
	gs.pollution_stage = 1
	gs.cycle = 1
	gs.day = 5
	gs.time_of_day = "night"
	return gs


func _assert_context(ctx, expected_scene: String, expected_days_remaining: int) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), "RESIDUAL_IDENTITY_TEMPLATES", "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("identity_id", "")), "borrowed_face_old_li", "%s payload identity_id" % expected_scene)
	assert_eq(str(payload.get("source_npc", "")), "old_li", "%s payload source_npc" % expected_scene)
	assert_eq(str(payload.get("name", "")), "Old Li's Borrowed Face", "%s payload name" % expected_scene)
	assert_eq(int(payload.get("days_remaining", -1)), expected_days_remaining, "%s payload days_remaining" % expected_scene)


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
