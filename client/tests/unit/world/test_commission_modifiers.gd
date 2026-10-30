extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CommissionScript = preload("res://scripts/world/commission.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const COMMISSION_MODIFIER_SERVICE_PATH := "res://scripts/world/commission_modifier_service.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_commission_modifiers.gd --")
	test_modifier_definitions_are_finite_slice35_set()
	test_commission_roundtrip_preserves_modifiers()
	test_refresh_daily_applies_seeded_visible_modifiers()
	test_modifier_effects_change_deadline_reward_and_expire_risk()
	return {"passed": _passed, "failed": _failed}


func test_modifier_definitions_are_finite_slice35_set() -> void:
	var service = _modifier_service()
	if service == null:
		return
	var defs: Dictionary = service.load_all()
	assert_eq(_sorted(defs.keys()), ["dangerous", "discreet", "extra_evidence", "familiar_issuer", "trust_bonus", "urgent"], "modifier set is finite and exact")


func test_commission_roundtrip_preserves_modifiers() -> void:
	var commission = CommissionScript.from_dict({
		"id": "modifier_roundtrip",
		"commission_type": "gather",
		"modifiers": ["urgent", "extra_evidence"],
		"modifier_effects": {"time_limit_delta": -1, "reward_multiplier": 1.25},
		"modifier_display_text": "加急 / 额外证据",
	})
	var encoded: Dictionary = commission.to_dict()
	assert_eq(_sorted(encoded.get("modifiers", [])), ["extra_evidence", "urgent"], "Commission roundtrips modifier ids")
	assert_eq(float(encoded.get("modifier_effects", {}).get("reward_multiplier", 0.0)), 1.25, "Commission roundtrips modifier effects")
	assert_true(str(encoded.get("modifier_display_text", "")).contains("加急"), "Commission roundtrips modifier display text")


func test_refresh_daily_applies_seeded_visible_modifiers() -> void:
	var gs = _state()
	gs.day = 3
	var service = CommissionServiceScript.new()
	var result: Dictionary = service.refresh_daily(gs, 35123)
	assert_true(bool(result.get("ok", false)), "commission refresh succeeds")
	var modified := _first_modified(gs)
	assert_true(not modified.is_empty(), "at least one visible commission receives modifier")
	assert_true(modified.get("modifiers", []) is Array and modified.get("modifiers", []).size() <= 2, "modifier stack is capped at two")
	assert_true(str(modified.get("modifier_display_text", "")) != "", "modifier display text is visible")


func test_modifier_effects_change_deadline_reward_and_expire_risk() -> void:
	var modifier_service = _modifier_service()
	if modifier_service == null:
		return
	var gs = _state()
	gs.day = 1
	var service = CommissionServiceScript.new()
	service.refresh_daily(gs, 35001)
	var commission_id := "commission_moonlight_grass_001"
	modifier_service.apply_for_ids(gs, commission_id, ["urgent", "extra_evidence"])
	var data := _available(gs, commission_id)
	assert_true(data.get("modifiers", []).has("urgent"), "urgent modifier applied")
	assert_true(int(data.get("time_limit_days", 0)) < 5, "urgent shortens visible time limit")
	assert_true(data.get("modifiers", []).has("extra_evidence"), "extra evidence modifier applied")
	service.accept(gs, commission_id)
	service.record_completion_event(gs, {
		"event": "loot_resolved",
		"district": "misty_port",
		"time": "night",
		"item_id": "moonlight_grass",
		"count_added": 3,
	})
	var before := int(gs.lingstones)
	var claim: Dictionary = service.claim(gs, commission_id)
	assert_true(bool(claim.get("ok", false)), "modified commission claim succeeds")
	assert_true(int(gs.lingstones) > before + 80, "extra evidence increases lingstone reward above base")
	gs.day = 1
	var expire_id := "commission_old_li_letter_001"
	service.accept(gs, expire_id)
	modifier_service.apply_for_ids(gs, expire_id, ["urgent"])
	var old_li = NpcKnowledgeStateScript.new()
	old_li.trust = 45
	gs.npc_relations["old_li"] = old_li
	gs.day = 5
	service.expire_overdue(gs)
	assert_true(int(old_li.trust) < 40, "urgent expiration applies stronger issuer trust risk")
	gs.queue_free()


func _modifier_service():
	var script = load(COMMISSION_MODIFIER_SERVICE_PATH)
	assert_true(script != null, "CommissionModifierService script exists")
	if script == null or not script.can_instantiate():
		return null
	var service = script.new()
	assert_true(service.has_method("load_all"), "CommissionModifierService exposes load_all")
	assert_true(service.has_method("apply_for_ids"), "CommissionModifierService exposes apply_for_ids")
	if not service.has_method("load_all") or not service.has_method("apply_for_ids"):
		return null
	return service


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _first_modified(gs) -> Dictionary:
	for item in gs.available_commissions:
		if item is Dictionary and item.get("modifiers", []) is Array and item.get("modifiers", []).size() > 0:
			return item.duplicate(true)
	return {}


func _available(gs, commission_id: String) -> Dictionary:
	for item in gs.available_commissions:
		if item is Dictionary and str(item.get("id", "")) == commission_id:
			return item.duplicate(true)
	return {}


func _sorted(values: Variant) -> Array:
	var result: Array = []
	if values is Array:
		for item in values:
			result.append(str(item))
	result.sort()
	return result


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
