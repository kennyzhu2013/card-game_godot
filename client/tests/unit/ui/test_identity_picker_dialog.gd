extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const IdentityPickerScript = preload("res://scripts/world/identity_picker_dialog.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")

const RESIDUAL_IDENTITY_PATH := "res://scripts/world/residual_identity.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_identity_picker_dialog.gd --")
	test_picker_defaults_to_harvey_without_residuals()
	test_picker_lists_only_applicable_active_identities()
	test_picker_consumes_selected_identity_for_npc()
	test_npc_interaction_service_passes_selected_residual_identity()
	return {"passed": _passed, "failed": _failed}


func test_picker_defaults_to_harvey_without_residuals() -> void:
	var picker = IdentityPickerScript.new()
	assert_eq(picker.choose_identity_for_npc("old_li", [], null), "harvey", "picker keeps harvey default for legacy empty array")
	assert_eq(picker.options_for_npc("old_li", []), ["harvey"], "picker legacy empty options return harvey")


func test_picker_lists_only_applicable_active_identities() -> void:
	var gs = _state()
	if not _has_property(gs, "residual_identities"):
		assert_true(false, "GameState exposes residual_identities for picker")
		return
	gs.day = 4
	gs.residual_identities = [
		_identity({"id": "borrowed_face_old_li", "name": "小张", "source_npc": "old_li", "created_at_day": 2, "expires_at_day": 5, "allowed_locations": ["old_li"], "uses_remaining": 2}),
		_identity({"id": "shadow_alibi", "name": "影代", "source_npc": "mirror_shadow", "created_at_day": 3, "expires_at_day": 6, "allowed_locations": ["shadow_alley"], "uses_remaining": 1}),
		_identity({"id": "expired_face", "name": "旧脸", "source_npc": "old_li", "created_at_day": 1, "expires_at_day": 3, "allowed_locations": ["old_li"], "uses_remaining": 2}),
		_identity({"id": "spent_face", "name": "空壳", "source_npc": "old_li", "created_at_day": 2, "expires_at_day": 5, "allowed_locations": ["old_li"], "uses_remaining": 0}),
	]
	var picker = IdentityPickerScript.new()
	assert_true(picker.has_method("options_for_npc"), "IdentityPickerDialog exposes options_for_npc()")
	if not picker.has_method("options_for_npc"):
		return
	var options: Array = picker.options_for_npc("old_li", gs)
	assert_true(options.has("harvey"), "identity picker always includes harvey")
	assert_true(options.has("borrowed_face_old_li"), "identity picker includes matching NPC identity")
	assert_true(not options.has("shadow_alibi"), "identity picker rejects location-only identity for NPC use")
	assert_true(not options.has("expired_face"), "identity picker hides expired identity")
	assert_true(not options.has("spent_face"), "identity picker hides spent identity")


func test_picker_consumes_selected_identity_for_npc() -> void:
	var gs = _state()
	if not _has_property(gs, "residual_identities"):
		assert_true(false, "GameState exposes residual_identities for consume")
		return
	gs.day = 4
	gs.church_awareness = 0
	var state = NpcKnowledgeStateScript.new()
	state.suspicion = 5
	gs.npc_relations["old_li"] = state
	var identity = _identity({"id": "borrowed_face_old_li", "name": "小张", "source_npc": "old_li", "created_at_day": 2, "expires_at_day": 5, "allowed_locations": ["old_li"], "uses_remaining": 2})
	gs.residual_identities = [identity]
	var picker = IdentityPickerScript.new()
	assert_true(picker.has_method("use_identity_for_npc"), "IdentityPickerDialog exposes use_identity_for_npc()")
	if not picker.has_method("use_identity_for_npc"):
		return
	var result: Dictionary = picker.use_identity_for_npc("old_li", gs, "borrowed_face_old_li")
	assert_true(bool(result.get("ok", false)), "picker consumes selected residual identity")
	assert_eq(str(result.get("identity", "")), "borrowed_face_old_li", "consume result returns selected identity id")
	assert_eq(int(identity.uses_remaining), 1, "consume decrements residual uses")
	assert_eq(str(state.dialogue_state.get("active_identity", "")), "borrowed_face_old_li", "consume records active_identity on NPC dialogue state")


func test_npc_interaction_service_passes_selected_residual_identity() -> void:
	var gs = _state()
	if not _has_property(gs, "residual_identities"):
		assert_true(false, "GameState exposes residual_identities for NpcInteractionService")
		return
	gs.day = 4
	gs.residual_identities = [
		_identity({"id": "borrowed_face_old_li", "name": "小张", "source_npc": "old_li", "created_at_day": 2, "expires_at_day": 5, "allowed_locations": ["old_li"], "uses_remaining": 2})
	]
	var service = NpcInteractionServiceScript.new()
	gs.set_meta("selected_identity_id", "borrowed_face_old_li")
	var result: Dictionary = service.open_dialogue("old_li", gs, null)
	assert_true(bool(result.get("ok", false)), "open_dialogue succeeds with selected residual identity")
	assert_eq(str(result.get("identity", "")), "borrowed_face_old_li", "open_dialogue returns selected residual identity")
	var state = gs.npc_relations.get("old_li", null)
	assert_true(state != null, "open_dialogue creates NPC state")
	if state != null:
		assert_eq(str(state.dialogue_state.get("active_identity", "")), "borrowed_face_old_li", "open_dialogue stores selected residual identity on state")
	assert_eq(int(gs.residual_identities[0].uses_remaining), 1, "open_dialogue consumes one residual identity use")


func _identity(data: Dictionary):
	var script = load(RESIDUAL_IDENTITY_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "ResidualIdentity script loads and can instantiate")
		return null
	return script.from_dict(data)


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
