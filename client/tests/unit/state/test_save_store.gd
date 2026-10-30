extends RefCounted

const SaveStoreScript = preload("res://scripts/state/save_store.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const BASE_PATH := "user://save_store_unit"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_save_store.gd --")
	test_manual_slot_save_and_load_roundtrip()
	test_load_missing_slot_returns_empty_dictionary()
	test_auto_save_writes_auto_slot()
	test_save_three_roundtrip()
	test_apply_payload_restores_game_state()
	return {"passed": _passed, "failed": _failed}


func test_manual_slot_save_and_load_roundtrip() -> void:
	if not _has_method("save") or not _has_method("load") or not _has_method("slot_path"):
		return
	var gs = _state()
	gs.day = 5
	gs.sequence = 8
	gs.current_district = "mist_harbor"
	gs.lingstones = 123
	var ok: bool = SaveStoreScript.save("save_1", gs, BASE_PATH)
	assert_true(ok, "manual save_1 writes successfully")
	assert_true(FileAccess.file_exists(SaveStoreScript.slot_path("save_1", BASE_PATH)), "save_1 file exists")
	var payload: Dictionary = SaveStoreScript.load("save_1", BASE_PATH)
	assert_eq(int(payload.get("save_version", 0)), 1, "save payload version = 1")
	assert_true(payload.has("timestamp"), "save payload has timestamp")
	assert_eq(int(payload.get("summary", {}).get("day", -1)), 5, "summary records day")
	assert_eq(int(payload.get("summary", {}).get("sequence", -1)), 8, "summary records sequence")
	assert_eq(str(payload.get("summary", {}).get("location", "")), "mist_harbor", "summary records location")
	assert_eq(str(payload.get("game_state", {}).get("current_district", "")), "mist_harbor", "game_state records district")


func test_load_missing_slot_returns_empty_dictionary() -> void:
	if not _has_method("load"):
		return
	var payload: Dictionary = SaveStoreScript.load("save_3", "user://save_store_unit_missing")
	assert_true(payload.is_empty(), "missing save slot loads as empty Dictionary")


func test_auto_save_writes_auto_slot() -> void:
	if not _has_method("auto_save") or not _has_method("load"):
		return
	var gs = _state()
	gs.day = 7
	gs.time_of_day = "night"
	var ok: bool = SaveStoreScript.auto_save(gs, BASE_PATH)
	assert_true(ok, "auto_save writes successfully")
	var payload: Dictionary = SaveStoreScript.load("auto", BASE_PATH)
	assert_eq(int(payload.get("game_state", {}).get("day", -1)), 7, "auto slot stores day")
	assert_eq(str(payload.get("game_state", {}).get("time_of_day", "")), "night", "auto slot stores time_of_day")


func test_save_three_roundtrip() -> void:
	if not _has_method("save") or not _has_method("load") or not _has_method("slot_path"):
		return
	var gs = _state()
	gs.day = 11
	gs.sequence = 7
	gs.current_district = "stone_tower"
	gs.lingstones = 321
	var ok: bool = SaveStoreScript.save("save_3", gs, BASE_PATH)
	assert_true(ok, "manual save_3 writes successfully")
	assert_true(FileAccess.file_exists(SaveStoreScript.slot_path("save_3", BASE_PATH)), "save_3 file exists")
	var payload: Dictionary = SaveStoreScript.load("save_3", BASE_PATH)
	assert_eq(int(payload.get("summary", {}).get("day", -1)), 11, "save_3 summary records day")
	assert_eq(str(payload.get("summary", {}).get("location", "")), "stone_tower", "save_3 summary records location")
	assert_eq(int(payload.get("game_state", {}).get("sequence", -1)), 7, "save_3 game_state records sequence")


func test_apply_payload_restores_game_state() -> void:
	if not _has_method("save") or not _has_method("load") or not _has_method("apply_payload"):
		return
	var saved = _state()
	saved.day = 9
	saved.sequence = 7
	saved.current_district = "seven_saints"
	SaveStoreScript.save("save_2", saved, BASE_PATH)
	var target = _state()
	target.day = 1
	target.sequence = 9
	target.current_district = ""
	var payload: Dictionary = SaveStoreScript.load("save_2", BASE_PATH)
	var ok: bool = SaveStoreScript.apply_payload(payload, target)
	assert_true(ok, "apply_payload succeeds")
	assert_eq(target.day, 9, "apply_payload restores day")
	assert_eq(target.sequence, 7, "apply_payload restores sequence")
	assert_eq(target.current_district, "seven_saints", "apply_payload restores current_district")


func _has_method(method_name: String) -> bool:
	var inst = SaveStoreScript.new()
	var exists := inst.has_method(method_name)
	assert_true(exists, "SaveStore exposes %s()" % method_name)
	return exists


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


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
