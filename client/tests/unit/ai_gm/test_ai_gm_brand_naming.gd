extends RefCounted

const BrandWorkshopScript = preload("res://scripts/hub/brand_workshop_panel.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const BrandScript = preload("res://scripts/combat/brand.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "named brand fusion"


func run() -> Dictionary:
	print("\n-- test_ai_gm_brand_naming.gd --")
	test_brand_naming_builds_valid_prompt_context()
	return {"passed": _passed, "failed": _failed}


func test_brand_naming_builds_valid_prompt_context() -> void:
	var panel = BrandWorkshopScript.new()
	assert_true(panel.has_method("set_ai_gm_service"), "BrandWorkshopPanel exposes set_ai_gm_service()")
	assert_true(panel.has_method("request_brand_naming_ai_gm"), "BrandWorkshopPanel exposes request_brand_naming_ai_gm()")
	if not panel.has_method("set_ai_gm_service") or not panel.has_method("request_brand_naming_ai_gm"):
		panel.free()
		return

	var fake_service := FakeAIGMService.new()
	panel.call("set_ai_gm_service", fake_service)
	panel.open(_game_state())
	var text: String = str(panel.call("request_brand_naming_ai_gm", _card(), _brand("ash_brand"), _brand("gear_brand"), {
		"fusion_outcome": "ash_gear_oath",
	}))

	assert_eq(text, "named brand fusion", "brand_naming returns AI GM text")
	assert_eq(fake_service.calls.size(), 1, "brand_naming calls AI GM once")
	if fake_service.calls.is_empty():
		panel.free()
		return
	var ctx = fake_service.calls[0]
	_assert_context_header(ctx, "brand_naming", "BRAND_NAMING_TEMPLATES")
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("brand_id_a", "")), "ash_brand", "brand_naming payload includes brand_id_a")
	assert_eq(str(payload.get("brand_id_b", "")), "gear_brand", "brand_naming payload includes brand_id_b")
	assert_eq(str(payload.get("card_template_id", "")), "fool_card_alpha", "brand_naming payload includes card_template_id")
	assert_eq(str(payload.get("fusion_outcome", "")), "ash_gear_oath", "brand_naming payload includes fusion_outcome")
	panel.free()


func _card():
	return CardScript.from_json({
		"id": "card_alpha",
		"template_id": "fool_card_alpha",
		"display_name": "Card Alpha",
		"quality": 3,
		"sequence": 7,
	})


func _brand(id: String):
	return BrandScript.from_dict({
		"id": id,
		"display_name": id,
		"pathway_affinity": "any",
		"sequence_min": 9,
		"effect_type": "stat",
		"effect_payload": {"stat_target": "damage", "operation": "add", "value": 1},
	})


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 7
	gs.pollution = 33
	gs.pollution_stage = 1
	gs.cycle = 2
	gs.day = 6
	gs.time_of_day = "noon"
	return gs


func _assert_context_header(ctx, expected_scene: String, expected_pool: String) -> void:
	assert_true(ctx != null, "%s context exists" % expected_scene)
	if ctx == null:
		return
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	assert_eq(str(ctx.fallback_template_pool), expected_pool, "%s fallback pool" % expected_scene)
	assert_true(bool(ctx.validate().get("valid", false)), "%s PromptContext validates" % expected_scene)
	assert_eq(int(ctx.player_state.get("sequence", -1)), 7, "%s player_state.sequence" % expected_scene)
	assert_eq(int(ctx.player_state.get("pollution", -1)), 33, "%s player_state.pollution" % expected_scene)


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
