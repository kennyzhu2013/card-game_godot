extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")

const RESIDUAL_IDENTITY_PATH := "res://scripts/world/residual_identity.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_residual_identity.gd --")
	test_residual_identity_roundtrip_and_applicability()
	test_using_same_identity_again_adds_r20_risk()
	test_expired_identity_forces_awareness_and_check()
	test_game_state_persists_residual_identities_and_clears_on_cycle_reset()
	test_sleep_expires_active_perception_and_restores_hub_mana()
	return {"passed": _passed, "failed": _failed}


func test_residual_identity_roundtrip_and_applicability() -> void:
	var identity = _identity({
		"id": "borrowed_face_old_li",
		"name": "小张",
		"source_npc": "old_li",
		"source_persona": {"speech_style": "dry"},
		"created_at_day": 2,
		"expires_at_day": 5,
		"allowed_locations": ["old_li", "shadow_alley"],
		"uses_remaining": 3,
	})
	if identity == null:
		return
	assert_eq(str(identity.id), "borrowed_face_old_li", "ResidualIdentity stores id")
	assert_eq(str(identity.name), "小张", "ResidualIdentity stores borrowed name")
	assert_true(identity.has_method("can_use_for"), "ResidualIdentity exposes can_use_for()")
	assert_true(identity.has_method("is_expired"), "ResidualIdentity exposes is_expired()")
	if not identity.has_method("can_use_for") or not identity.has_method("is_expired"):
		return
	assert_true(bool(identity.call("can_use_for", "old_li", 3)), "identity can be used for allowed NPC before expiry")
	assert_true(bool(identity.call("can_use_for", "shadow_alley", 5)), "identity can be used on expiry day")
	assert_true(not bool(identity.call("can_use_for", "sacred_seven", 3)), "identity rejects disallowed location")
	assert_true(bool(identity.call("is_expired", 6)), "identity is expired after expires_at_day")
	var copy = _residual_script().from_dict(identity.to_dict())
	assert_eq(str(copy.id), "borrowed_face_old_li", "ResidualIdentity roundtrips id")
	assert_eq(int(copy.uses_remaining), 3, "ResidualIdentity roundtrips uses_remaining")


func test_using_same_identity_again_adds_r20_risk() -> void:
	var identity = _identity({
		"id": "borrowed_face_old_li",
		"name": "小张",
		"source_npc": "old_li",
		"created_at_day": 2,
		"expires_at_day": 5,
		"allowed_locations": ["old_li"],
		"uses_remaining": 3,
	})
	if identity == null:
		return
	var gs = _state()
	gs.church_awareness = 0
	var state = NpcKnowledgeStateScript.new()
	state.suspicion = 10
	assert_true(identity.has_method("consume_for"), "ResidualIdentity exposes consume_for()")
	if not identity.has_method("consume_for"):
		return
	var first: Dictionary = identity.call("consume_for", "old_li", 3, gs, state)
	assert_true(bool(first.get("ok", false)), "first residual identity use succeeds")
	assert_eq(int(identity.uses_remaining), 2, "first use decrements uses_remaining")
	assert_eq(int(gs.church_awareness), 0, "first use does not add repeat risk")
	var second: Dictionary = identity.call("consume_for", "old_li", 4, gs, state)
	assert_true(bool(second.get("ok", false)), "second residual identity use still succeeds")
	assert_eq(str(second.get("risk", "")), "repeat_target", "second use returns repeat_target risk")
	assert_eq(int(gs.church_awareness), 2, "second use adds church_awareness +2")
	assert_eq(int(state.suspicion), 40, "second use adds target suspicion +30")


func test_expired_identity_forces_awareness_and_check() -> void:
	var identity = _identity({
		"id": "expired_face",
		"name": "过期脸",
		"source_npc": "old_li",
		"created_at_day": 1,
		"expires_at_day": 2,
		"allowed_locations": ["old_li"],
		"uses_remaining": 1,
	})
	if identity == null:
		return
	var gs = _state()
	gs.church_awareness = 10
	var state = NpcKnowledgeStateScript.new()
	assert_true(identity.has_method("consume_for"), "ResidualIdentity exposes consume_for() for expiry path")
	if not identity.has_method("consume_for"):
		return
	var result: Dictionary = identity.call("consume_for", "old_li", 3, gs, state)
	assert_true(not bool(result.get("ok", true)), "expired identity use is blocked")
	assert_eq(str(result.get("reason", "")), "identity_expired", "expired identity returns identity_expired")
	assert_eq(int(gs.church_awareness), 15, "expired forced use adds church_awareness +5")
	assert_true(bool(result.get("acting_check_required", false)), "expired use requests forced acting check")


func test_game_state_persists_residual_identities_and_clears_on_cycle_reset() -> void:
	var identity = _identity({
		"id": "borrowed_face_old_li",
		"name": "小张",
		"source_npc": "old_li",
		"created_at_day": 2,
		"expires_at_day": 5,
		"allowed_locations": ["old_li"],
		"uses_remaining": 3,
	})
	if identity == null:
		return
	var gs = _state()
	assert_true(_has_property(gs, "residual_identities"), "GameState exposes residual_identities")
	if not _has_property(gs, "residual_identities"):
		return
	gs.residual_identities.append(identity)
	var restored = _state()
	restored.from_dict(gs.to_dict())
	assert_eq(restored.residual_identities.size(), 1, "GameState serializes residual identities")
	if restored.residual_identities.size() > 0:
		assert_eq(str(restored.residual_identities[0].id), "borrowed_face_old_li", "GameState restores residual identity object")
	restored.reset()
	assert_eq(restored.residual_identities.size(), 0, "cycle reset clears residual identities")


func test_sleep_expires_active_perception_and_restores_hub_mana() -> void:
	var gs = _state()
	if not _has_property(gs, "hub_mana") or not _has_property(gs, "hub_mana_max"):
		assert_true(false, "GameState exposes hub_mana/hub_mana_max")
		return
	gs.day = 4
	gs.ap = 12
	gs.hub_mana = 4
	gs.hub_mana_max = 10
	var state = NpcKnowledgeStateScript.new()
	state.active_perception = "stranger"
	state.perception_expires_at = 5
	gs.npc_relations["old_li"] = state
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, "user://slice3_t11_sleep_probe.json", 0.0)
	assert_true(bool(result.get("ok", false)), "sleep_to_next_day succeeds for R20 expiry probe")
	assert_eq(int(gs.day), 5, "sleep advances to day 5")
	assert_eq(int(gs.hub_mana), 7, "sleep restores hub_mana by +3 up to cap")
	assert_eq(str(state.active_perception), "harvey", "sleep expires active_perception at perception_expires_at day")
	assert_eq(int(state.perception_expires_at), 0, "sleep clears perception_expires_at")


func _identity(data: Dictionary):
	var script = _residual_script()
	if script == null:
		return null
	return script.from_dict(data)


func _residual_script():
	var script = load(RESIDUAL_IDENTITY_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "ResidualIdentity script loads and can instantiate")
		return null
	return script


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false
	for entry in obj.get_property_list():
		if str(entry.get("name", "")) == property_name:
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
