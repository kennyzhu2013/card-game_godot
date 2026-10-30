extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "card upgrade narration"


func run() -> Dictionary:
	print("\n-- test_ai_gm_card_upgrade.gd --")
	test_card_upgrade_trigger_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_card_upgrade_trigger_builds_valid_prompt_context() -> void:
	var card = _card()
	assert_true(card.has_method("set_ai_gm_service"), "Card exposes set_ai_gm_service() for card_upgrade")
	assert_true(card.has_method("request_card_upgrade_ai_gm"), "Card exposes request_card_upgrade_ai_gm()")
	if not card.has_method("set_ai_gm_service") or not card.has_method("request_card_upgrade_ai_gm"):
		return

	var fake_service := FakeAIGMService.new()
	card.call("set_ai_gm_service", fake_service)
	card.acting_exp = 9
	assert_true(card.grant_acting_exp(1), "grant_acting_exp upgrades the card at 10 acting_exp")
	assert_eq(fake_service.calls.size(), 1, "card_upgrade calls AI GM once on upgrade")
	if fake_service.calls.is_empty():
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "card_upgrade", "CARD_UPGRADE_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("card_template_id", "")), "fool_upgrade_template", "card_upgrade payload includes card_template_id")
	assert_eq(int(payload.get("new_upgrade_level", -1)), 1, "card_upgrade payload includes new_upgrade_level")
	assert_eq(str(payload.get("primary_acting_rule", "")), "rule_first", "card_upgrade payload includes primary_acting_rule")


func _card():
	return CardScript.from_json({
		"id": "upgrade_card",
		"template_id": "fool_upgrade_template",
		"display_name": "Upgrade Card",
		"quality": 3,
		"sequence": 9,
		"acting_rules": ["rule_first", "rule_second"],
	})


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)


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
