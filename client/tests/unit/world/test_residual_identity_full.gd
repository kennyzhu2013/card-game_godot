extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const HubScript = preload("res://scripts/hub/hub.gd")
const NpcInteractionServiceScript = preload("res://scripts/world/npc_interaction_service.gd")
const IdentityPickerScript = preload("res://scripts/world/identity_picker_dialog.gd")
const ResidualIdentityScript = preload("res://scripts/world/residual_identity.gd")
const EncounterScript = preload("res://scripts/world/encounter.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "identity expired narration"


func run() -> Dictionary:
	print("\n-- test_residual_identity_full.gd --")
	test_npc_use_exhausts_identity_and_calls_expire_ai_gm()
	test_time_expired_identity_is_pruned_before_location_options()
	await test_hub_front_door_exposes_location_identity_choice()
	test_city_entry_helper_routes_location_identity_before_open()
	test_npc_dialogue_path_returns_identity_expiry_result()
	await test_encounter_start_uses_location_identity()
	return {"passed": _passed, "failed": _failed}


func test_npc_use_exhausts_identity_and_calls_expire_ai_gm() -> void:
	var gs = _state()
	gs.day = 4
	var fake := FakeAIGMService.new()
	var identity = _identity({
		"id": "borrowed_face_old_li",
		"name": "Borrowed Old Li",
		"source_npc": "old_li",
		"created_at_day": 2,
		"expires_at_day": 6,
		"allowed_locations": ["old_li"],
		"uses_remaining": 1,
	}, fake)
	gs.residual_identities = [identity]
	var picker = IdentityPickerScript.new()
	assert_true(picker.has_method("use_identity_for_npc"), "IdentityPickerDialog exposes NPC identity use")
	if not picker.has_method("use_identity_for_npc"):
		return
	var result: Dictionary = picker.use_identity_for_npc("old_li", gs, "borrowed_face_old_li")
	assert_true(bool(result.get("ok", false)), "NPC residual identity use succeeds before expiry")
	assert_eq(int(identity.uses_remaining), 0, "NPC use decrements final residual use to zero")
	assert_eq(_identity_ids(gs.residual_identities), [], "uses_remaining zero removes residual identity from GameState")
	assert_eq(_string_array(result.get("expired_identity_ids", [])), ["borrowed_face_old_li"], "NPC use reports exhausted identity id")
	assert_eq(str(result.get("expire_reason", "")), "uses_exhausted", "NPC use reports uses_exhausted expiry reason")
	assert_eq(str(result.get("ai_gm_text", "")), "identity expired narration", "NPC use returns residual_identity_expire narration")
	_assert_ai_call(fake, 1, "residual_identity_expire", "borrowed_face_old_li")


func test_time_expired_identity_is_pruned_before_location_options() -> void:
	var gs = _state()
	gs.day = 8
	var fake := FakeAIGMService.new()
	var expired = _identity({
		"id": "expired_face",
		"name": "Expired Face",
		"source_npc": "old_li",
		"created_at_day": 1,
		"expires_at_day": 6,
		"allowed_locations": ["shadow_alley"],
		"uses_remaining": 2,
	}, fake)
	var active = _identity({
		"id": "active_face",
		"name": "Active Face",
		"source_npc": "xiao_ran",
		"created_at_day": 7,
		"expires_at_day": 10,
		"allowed_locations": ["shadow_alley"],
		"uses_remaining": 2,
	}, fake)
	gs.residual_identities = [expired, active]
	var picker = IdentityPickerScript.new()
	assert_true(picker.has_method("prune_expired_identities"), "IdentityPickerDialog exposes time-expiry pruning")
	if not picker.has_method("prune_expired_identities"):
		return
	var prune: Dictionary = picker.prune_expired_identities(gs)
	assert_eq(_string_array(prune.get("expired_identity_ids", [])), ["expired_face"], "time-expired identity is reported")
	assert_eq(_identity_ids(gs.residual_identities), ["active_face"], "time-expired identity is removed while active identity stays")
	assert_eq(picker.options_for_location("shadow_alley", gs), ["harvey", "active_face"], "location options hide expired identities after prune")
	_assert_ai_call(fake, 1, "residual_identity_expire", "expired_face")


func test_hub_front_door_exposes_location_identity_choice() -> void:
	var previous: Dictionary = GameState.to_dict()
	GameState.from_dict(_state().to_dict())
	_clear_identity_meta(GameState)
	GameState.day = 4
	GameState.ap = 12
	var fake := FakeAIGMService.new()
	var identity = _identity({
		"id": "shadow_entry_face",
		"name": "Shadow Entry",
		"source_npc": "old_li",
		"created_at_day": 3,
		"expires_at_day": 7,
		"allowed_locations": ["shadow_alley"],
		"uses_remaining": 2,
	}, fake)
	GameState.residual_identities = [identity]
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads for district identity selection")
		GameState.from_dict(previous)
		_clear_identity_meta(GameState)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var door = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/FrontDoorButton")
	if door is Button:
		door.pressed.emit()
		await Engine.get_main_loop().process_frame
	var selector = hub.get_node_or_null("DistrictSelect")
	assert_true(selector != null and selector.visible, "front door opens selector before district identity selection")
	var identity_button = selector.find_child("DistrictIdentityButton_shadow_alley_shadow_entry_face", true, false) if selector != null else null
	assert_true(identity_button is Button and identity_button.visible, "selector exposes a district residual identity button")
	if identity_button is Button:
		identity_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(str(GameState.get_meta("selected_identity_id", "")), "shadow_entry_face", "pressing district identity button selects residual identity for entry")
	if selector != null:
		var shadow = selector.find_child("DistrictRow_shadow_alley", true, false)
		if shadow is Button:
			shadow.pressed.emit()
			await Engine.get_main_loop().process_frame
		else:
			assert_true(false, "shadow_alley row exists after identity selection")
	assert_eq(str(GameState.get_meta("active_location_identity", "")), "shadow_entry_face", "entering district consumes selected residual identity")
	assert_eq(int(identity.uses_remaining), 1, "district entry decrements selected residual identity use")
	hub.queue_free()
	GameState.from_dict(previous)
	_clear_identity_meta(GameState)


func test_city_entry_helper_routes_location_identity_before_open() -> void:
	var gs = _state()
	gs.day = 4
	var fake := FakeAIGMService.new()
	var identity = _identity({
		"id": "shadow_entry_face",
		"name": "Shadow Entry",
		"source_npc": "old_li",
		"created_at_day": 3,
		"expires_at_day": 7,
		"allowed_locations": ["shadow_alley"],
		"uses_remaining": 2,
	}, fake)
	gs.residual_identities = [identity]
	gs.set_meta("selected_identity_id", "shadow_entry_face")
	var hub = HubScript.new()
	assert_true(hub.has_method("prepare_district_identity"), "Hub exposes prepare_district_identity before city open")
	if not hub.has_method("prepare_district_identity"):
		return
	var result: Dictionary = hub.call("prepare_district_identity", "shadow_alley", gs)
	assert_true(bool(result.get("ok", false)), "Hub district entry applies selected location identity")
	assert_eq(str(result.get("identity", "")), "shadow_entry_face", "Hub district entry reports active location identity")
	assert_eq(int(identity.uses_remaining), 1, "Hub district entry consumes one residual identity use")
	assert_eq(str(gs.get_meta("active_location_identity", "")), "shadow_entry_face", "Hub district entry records active location identity")
	assert_true(not gs.has_meta("selected_identity_id"), "Hub district entry clears selected identity meta after use")


func test_npc_dialogue_path_returns_identity_expiry_result() -> void:
	var gs = _state()
	gs.day = 4
	var fake := FakeAIGMService.new()
	var identity = _identity({
		"id": "dialogue_face",
		"name": "Dialogue Face",
		"source_npc": "old_li",
		"created_at_day": 2,
		"expires_at_day": 6,
		"allowed_locations": ["old_li"],
		"uses_remaining": 1,
	}, fake)
	gs.residual_identities = [identity]
	gs.set_meta("selected_identity_id", "dialogue_face")
	var service = NpcInteractionServiceScript.new()
	var result: Dictionary = service.open_dialogue("old_li", gs, null)
	assert_true(bool(result.get("ok", false)), "NpcInteractionService dialogue opens with residual identity")
	var identity_result: Dictionary = result.get("identity_result", {}) if result.get("identity_result", {}) is Dictionary else {}
	assert_eq(_string_array(identity_result.get("expired_identity_ids", [])), ["dialogue_face"], "NPC dialogue propagates exhausted identity id")
	assert_eq(str(identity_result.get("ai_gm_text", "")), "identity expired narration", "NPC dialogue propagates expiry narration")
	assert_eq(_identity_ids(gs.residual_identities), [], "NPC dialogue removes exhausted residual identity")
	_assert_ai_call(fake, 1, "residual_identity_expire", "dialogue_face")


func test_encounter_start_uses_location_identity() -> void:
	var gs = _state()
	gs.day = 4
	gs.ap = 12
	gs.current_district = "shadow_alley"
	var fake := FakeAIGMService.new()
	var identity = _identity({
		"id": "encounter_face",
		"name": "Encounter Face",
		"source_npc": "old_li",
		"created_at_day": 3,
		"expires_at_day": 7,
		"allowed_locations": ["shadow_alley"],
		"uses_remaining": 2,
	}, fake)
	gs.residual_identities = [identity]
	gs.set_meta("selected_identity_id", "encounter_face")
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	var encounter = EncounterScript.new().from_dict({
		"id": "enc_identity_probe",
		"encounter_type": "flavor",
		"display_name": "Identity Probe",
		"districts": ["shadow_alley"],
		"step_count": 1,
		"scene_payload": {
			"text": "Identity probe text",
			"choices": [{"id": "leave", "label": "Leave", "outcome": {}}],
		},
	})
	var result: Dictionary = runner.start(encounter, gs)
	assert_true(bool(result.get("ok", false)), "EncounterRunner starts identity probe encounter")
	var identity_result: Dictionary = result.get("identity_result", {}) if result.get("identity_result", {}) is Dictionary else {}
	assert_eq(str(identity_result.get("identity", "")), "encounter_face", "EncounterRunner start applies selected location identity")
	assert_eq(int(identity.uses_remaining), 1, "EncounterRunner start consumes one residual identity use")
	assert_eq(str(gs.get_meta("active_encounter_identity", "")), "encounter_face", "EncounterRunner records active encounter identity")
	runner.queue_free()


func _identity(data: Dictionary, fake_service = null):
	var identity = ResidualIdentityScript.from_dict(data)
	if fake_service != null:
		identity.set_ai_gm_service(fake_service)
	return identity


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _identity_ids(identities: Array) -> Array[String]:
	var result: Array[String] = []
	for identity in identities:
		if identity == null:
			continue
		if identity is Dictionary:
			result.append(str((identity as Dictionary).get("id", "")))
		else:
			result.append(str(identity.get("id")))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _assert_ai_call(fake: FakeAIGMService, expected_count: int, expected_scene: String, expected_identity_id: String) -> void:
	assert_eq(fake.calls.size(), expected_count, "%s called AI GM %d time(s)" % [expected_scene, expected_count])
	if fake.calls.size() < expected_count:
		return
	var ctx = fake.calls[expected_count - 1]
	assert_eq(str(ctx.scene), expected_scene, "%s scene id" % expected_scene)
	var payload: Dictionary = ctx.scene_payload
	assert_eq(str(payload.get("identity_id", "")), expected_identity_id, "%s payload identity id" % expected_scene)


func _clear_identity_meta(game_state) -> void:
	if game_state == null or not game_state.has_method("has_meta"):
		return
	for key in ["selected_identity_id", "selected_identity_location_id", "active_location_identity", "active_encounter_identity", "last_district_identity_result", "force_sleep_pending"]:
		if game_state.has_meta(key):
			game_state.remove_meta(key)


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
