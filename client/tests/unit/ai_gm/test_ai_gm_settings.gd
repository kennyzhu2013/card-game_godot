extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const SaveStoreScript = preload("res://scripts/state/save_store.gd")
const ServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

const SETTINGS_SCRIPT_PATH := "res://scripts/ui/ai_gm_settings_dialog.gd"
const SETTINGS_SCENE_PATH := "res://scenes/ui/ai_gm_settings_dialog.tscn"
const SECRET_STORE_PATH := "res://scripts/ai_gm/ai_gm_secret_store.gd"
const SYSTEM_PROMPT_PATH := "res://data/ai_gm/system_prompt.md"
const MANUAL_QA_PATH := "res://../docs/SLICE_4_MANUAL_QA.md"
const SAVE_BASE_PATH := "user://slice4_t2_ai_gm_settings_saves"
const SECRET_TEST_PATH := "user://slice4_t2_ai_gm_secret.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_ai_gm_settings.gd --")
	test_default_settings_are_offline_haiku()
	test_settings_persist_in_game_state_and_save_payload()
	test_api_key_secret_store_is_separate_from_save_payload()
	test_system_prompt_asset_contains_r09_style_contract()
	test_ai_gm_service_loads_system_prompt_asset()
	await test_settings_dialog_loads_and_applies_player_choices()
	if FileAccess.file_exists(ProjectSettings.globalize_path(MANUAL_QA_PATH)):
		test_manual_qa_checklist_records_style_review()
	return {"passed": _passed, "failed": _failed}


func test_default_settings_are_offline_haiku() -> void:
	var gs = _state()
	assert_true(_has_property(gs, "ai_gm_settings"), "GameState exposes ai_gm_settings")
	if not _has_property(gs, "ai_gm_settings"):
		return
	var settings: Dictionary = gs.get("ai_gm_settings")
	assert_eq(str(settings.get("provider", "")), "claude_haiku", "AI GM default provider is Claude Haiku")
	assert_eq(bool(settings.get("offline_mode", false)), true, "AI GM defaults to offline mode")
	assert_eq(bool(settings.get("network_enabled", true)), false, "AI GM network is disabled by default")


func test_settings_persist_in_game_state_and_save_payload() -> void:
	var gs = _state()
	if not _has_property(gs, "ai_gm_settings"):
		assert_true(false, "GameState exposes ai_gm_settings")
		return
	gs.set("ai_gm_settings", {
		"provider": "deepseek",
		"offline_mode": false,
		"network_enabled": true,
		"daily_call_cap": 64,
		"daily_cost_cap": 0.0125,
	})
	var payload: Dictionary = gs.to_dict()
	assert_true(payload.has("ai_gm_settings"), "GameState.to_dict includes AI GM settings")
	assert_eq(str(payload.get("ai_gm_settings", {}).get("provider", "")), "deepseek", "settings payload stores provider")
	assert_eq(bool(payload.get("ai_gm_settings", {}).get("offline_mode", true)), false, "settings payload stores offline mode")

	var restored = _state()
	restored.from_dict(payload)
	var restored_settings: Dictionary = restored.get("ai_gm_settings")
	assert_eq(str(restored_settings.get("provider", "")), "deepseek", "GameState.from_dict restores provider")
	assert_eq(bool(restored_settings.get("network_enabled", false)), true, "GameState.from_dict restores network_enabled")
	assert_eq(int(restored_settings.get("daily_call_cap", 0)), 64, "GameState.from_dict restores daily call cap")


func test_api_key_secret_store_is_separate_from_save_payload() -> void:
	var secret_script = _load_required(SECRET_STORE_PATH)
	if secret_script == null:
		return
	var secret_store = secret_script.new()
	secret_store.path = SECRET_TEST_PATH
	var secret := "test-secret-placeholder"
	assert_true(secret_store.save_api_key(secret), "secret store saves API key")
	assert_eq(secret_store.load_api_key(), secret, "secret store loads API key")
	assert_true(FileAccess.file_exists(SECRET_TEST_PATH), "secret file is written at user://ai_gm_secret.json-compatible path")

	var gs = _state()
	if _has_property(gs, "ai_gm_settings"):
		var settings: Dictionary = gs.get("ai_gm_settings")
		settings["provider"] = "claude_haiku"
		settings["network_enabled"] = true
		gs.set("ai_gm_settings", settings)
	SaveStoreScript.save("save_1", gs, SAVE_BASE_PATH)
	var save_path := SaveStoreScript.slot_path("save_1", SAVE_BASE_PATH)
	var save_text := FileAccess.get_file_as_string(save_path)
	assert_true(save_text.find(secret) == -1, "save payload does not contain API key plaintext")
	assert_true(save_text.find("api_key") == -1, "save payload does not contain api_key field")


func test_system_prompt_asset_contains_r09_style_contract() -> void:
	assert_true(FileAccess.file_exists(SYSTEM_PROMPT_PATH), "system prompt asset exists")
	if not FileAccess.file_exists(SYSTEM_PROMPT_PATH):
		return
	var text := FileAccess.get_file_as_string(SYSTEM_PROMPT_PATH)
	for phrase in ["AI GM", "维多利亚蒸汽朋克", "神秘学", "第二人称", "留悬念"]:
		assert_true(text.contains(phrase), "system prompt contains style phrase: %s" % phrase)
	for phrase in ["不能直接报数值", "不能跳出第四面墙", "不能超过规定字数", "不能直接说核心spoiler"]:
		assert_true(text.contains(phrase), "system prompt contains safety constraint: %s" % phrase)


func test_ai_gm_service_loads_system_prompt_asset() -> void:
	var service = ServiceScript.new()
	assert_true(service.has_method("load_system_prompt"), "AIGMService exposes load_system_prompt()")
	if not service.has_method("load_system_prompt"):
		return
	var prompt: String = service.load_system_prompt(SYSTEM_PROMPT_PATH)
	assert_true(prompt.contains("AI GM"), "AIGMService loads system prompt text")
	assert_eq(service.system_prompt, prompt, "AIGMService stores loaded system prompt")


func test_settings_dialog_loads_and_applies_player_choices() -> void:
	var script = _load_required(SETTINGS_SCRIPT_PATH)
	assert_true(ResourceLoader.exists(SETTINGS_SCENE_PATH), "AI GM settings dialog scene exists")
	var scene = load(SETTINGS_SCENE_PATH) if ResourceLoader.exists(SETTINGS_SCENE_PATH) else null
	assert_true(scene != null and scene.can_instantiate(), "AI GM settings dialog scene loads")
	if script == null or scene == null or not scene.can_instantiate():
		return

	var dialog = scene.instantiate()
	Engine.get_main_loop().root.add_child(dialog)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	dialog.open(gs, SECRET_TEST_PATH)
	assert_true(dialog.visible, "AI GM settings dialog is visible after open")
	assert_eq(dialog.selected_provider_id(), "claude_haiku", "dialog defaults to Claude Haiku")
	assert_eq(dialog.is_offline_mode(), true, "dialog defaults offline")
	dialog.set_provider_id("gemini")
	dialog.set_offline_mode(false)
	dialog.set_api_key_for_test("sk-dialog-secret")
	assert_true(dialog.apply_current_settings(), "dialog applies current AI GM settings")
	var settings: Dictionary = gs.get("ai_gm_settings")
	assert_eq(str(settings.get("provider", "")), "gemini", "dialog writes provider to GameState")
	assert_eq(bool(settings.get("offline_mode", true)), false, "dialog writes offline toggle to GameState")
	assert_eq(bool(settings.get("network_enabled", false)), true, "dialog enables network when offline is false")
	assert_eq(dialog.load_api_key_for_test(), "sk-dialog-secret", "dialog stores API key through secret store")
	var payload: Dictionary = SaveStoreScript.build_payload(gs)
	var save_text := JSON.stringify(payload)
	assert_true(save_text.find("sk-dialog-secret") == -1, "dialog secret is absent from save payload")
	dialog.queue_free()


func test_manual_qa_checklist_records_style_review() -> void:
	var text := _read_doc(MANUAL_QA_PATH)
	assert_true(text.contains("AI GM"), "Slice 4 manual QA doc contains AI GM section")
	for phrase in ["维多利亚蒸汽朋克", "神秘学", "第二人称", "留悬念", "不报数值", "不破第四面墙"]:
		assert_true(text.contains(phrase), "manual QA checklist contains style review item: %s" % phrase)


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _load_required(path: String):
	if not ResourceLoader.exists(path):
		assert_true(false, "%s exists" % path)
		return null
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s loads" % path)
		return null
	return script


func _read_doc(relative_path: String) -> String:
	var abs_path := ProjectSettings.globalize_path(relative_path)
	if not FileAccess.file_exists(abs_path):
		assert_true(false, "%s exists" % relative_path)
		return ""
	return FileAccess.get_file_as_string(abs_path)


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
