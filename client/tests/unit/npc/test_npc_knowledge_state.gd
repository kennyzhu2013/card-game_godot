extends RefCounted

const StateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_npc_knowledge_state.gd --")
	test_defaults()
	test_to_dict_from_dict_roundtrip()
	test_r20_placeholders()
	test_layer_revealed_bounds()
	test_dialog_count_default_and_roundtrip()
	return {"passed": _passed, "failed": _failed}


func test_defaults() -> void:
	var s = StateScript.new()
	assert_eq(s.layer_revealed, 0, "default layer_revealed = 0")
	assert_eq(s.trust, 0, "default trust = 0")
	assert_eq(s.suspicion, 0, "default suspicion = 0")
	assert_eq(s.active_perception, "harvey", "default active_perception = harvey")
	assert_eq(s.perception_expires_at, 0, "default perception_expires_at = 0")
	assert_eq(s.residual_identities, [], "default residual_identities = []")
	assert_eq(s.social_effects_active, [], "default social_effects_active = []")
	assert_eq(s.first_met_day, -1, "default first_met_day = -1")


func test_to_dict_from_dict_roundtrip() -> void:
	var s = StateScript.new()
	s.trust = 80
	s.suspicion = 20
	s.layer_revealed = 1
	s.active_perception = "stranger"
	s.perception_expires_at = 15
	s.residual_identities = ["name_a", "name_b"]
	s.social_effects_active = ["identity_mask"]
	s.first_met_day = 3

	var d = s.to_dict()
	var s2 = StateScript.from_dict(d)

	assert_eq(s2.trust, 80, "rt trust")
	assert_eq(s2.suspicion, 20, "rt suspicion")
	assert_eq(s2.layer_revealed, 1, "rt layer_revealed")
	assert_eq(s2.active_perception, "stranger", "rt active_perception")
	assert_eq(s2.perception_expires_at, 15, "rt perception_expires_at")
	assert_eq(s2.residual_identities, ["name_a", "name_b"], "rt residual_identities")
	assert_eq(s2.social_effects_active, ["identity_mask"], "rt social_effects_active")
	assert_eq(s2.first_met_day, 3, "rt first_met_day")


func test_r20_placeholders() -> void:
	# R20 字段占位，切片 1 不写值 (R11 §6.4)
	var s = StateScript.new()
	assert_eq(s.active_perception, "harvey", "R20 placeholder: active_perception default")
	assert_eq(s.perception_expires_at, 0, "R20 placeholder: perception_expires_at default")
	assert_eq(s.residual_identities, [], "R20 placeholder: residual_identities default")
	assert_eq(s.social_effects_active, [], "R20 placeholder: social_effects_active default")


func test_layer_revealed_bounds() -> void:
	var s = StateScript.new()
	s.layer_revealed = 2
	assert_eq(s.layer_revealed, 2, "layer_revealed = 2 (truth revealed)")
	s.layer_revealed = 0
	assert_eq(s.layer_revealed, 0, "layer_revealed = 0 (public only)")


func test_dialog_count_default_and_roundtrip() -> void:
	# R11 §6.4 第 137 行 + §6.5 触发条件 (dialog_count >= 5)
	var s = StateScript.new()
	assert_eq(s.dialog_count, 0, "default dialog_count = 0")
	s.dialog_count = 7
	var s2 = StateScript.from_dict(s.to_dict())
	assert_eq(s2.dialog_count, 7, "rt dialog_count")


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
