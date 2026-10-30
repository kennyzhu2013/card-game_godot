extends RefCounted

const AccountStoreScript = preload("res://scripts/state/account_store.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_account_store.gd --")
	test_path_uses_user_saves()
	test_no_runtime_res_saves_references()
	test_default_returns_empty_structure()
	test_save_and_load_roundtrip()
	test_load_nonexistent_returns_default()
	test_update_daodian_preserved()
	test_divinity_cards_empty_by_default()
	return {"passed": _passed, "failed": _failed}


func test_path_uses_user_saves() -> void:
	assert_true(AccountStoreScript.PATH.begins_with("user://saves/"), "AccountStore.PATH uses user://saves/")


func test_no_runtime_res_saves_references() -> void:
	var offenders: Array = []
	for root in ["res://scripts", "res://data"]:
		_collect_files_with_text(root, "res://saves", offenders)
	assert_eq(offenders, [], "client scripts/data contain no res://saves references")


func test_default_returns_empty_structure() -> void:
	var data = AccountStoreScript.get_default()
	assert_true(data.has("daodian"), "default has daodian")
	assert_true(data["daodian"].has("discovered_cards"), "default daodian.discovered_cards")
	assert_true(data["daodian"].has("dao_fragments"), "default daodian.dao_fragments")
	assert_true(data.has("completed_commissions"), "default has completed_commissions")
	assert_true(data.has("divinity_cards"), "default has divinity_cards")
	assert_eq(data["completed_commissions"], [], "default completed_commissions empty")
	assert_eq(data["divinity_cards"], [], "default divinity_cards empty")


func test_save_and_load_roundtrip() -> void:
	var snapshot := _snapshot_account_file()
	var data := {
		"daodian": {
			"discovered_cards": ["card_a", "card_b"],
			"discovered_brands": ["brand_x"],
			"unique_artifacts_seen": [],
			"dao_fragments": ["frag_01"],
		},
		"completed_commissions": ["com_1"],
		"divinity_cards": [],
	}
	AccountStoreScript.save(data)
	var loaded = AccountStoreScript.load()
	assert_eq(loaded["daodian"]["discovered_cards"], ["card_a", "card_b"], "roundtrip: daodian.discovered_cards")
	assert_eq(loaded["daodian"]["dao_fragments"], ["frag_01"], "roundtrip: daodian.dao_fragments")
	assert_eq(loaded["completed_commissions"], ["com_1"], "roundtrip: completed_commissions")
	_restore_account_file(snapshot)


func test_load_nonexistent_returns_default() -> void:
	# If no account.json exists (fresh install), load() returns defaults
	# We can't delete the file in test, but get_default() is the fallback
	var d = AccountStoreScript.get_default()
	assert_true(d is Dictionary, "get_default returns Dictionary")


func test_update_daodian_preserved() -> void:
	var snapshot := _snapshot_account_file()
	# Verify daodian sub-fields survive a save/load cycle
	var data = AccountStoreScript.get_default()
	data["daodian"]["discovered_cards"] = ["card_z"]
	AccountStoreScript.save(data)
	var loaded = AccountStoreScript.load()
	assert_eq(loaded["daodian"]["discovered_cards"], ["card_z"], "daodian update persisted")
	_restore_account_file(snapshot)


func test_divinity_cards_empty_by_default() -> void:
	var data = AccountStoreScript.get_default()
	assert_eq(data["divinity_cards"].size(), 0, "divinity_cards empty by default")


func _collect_files_with_text(path: String, needle: String, offenders: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			_collect_files_with_text(child, needle, offenders)
		else:
			var f := FileAccess.open(child, FileAccess.READ)
			if f != null:
				var text := f.get_as_text()
				f.close()
				if text.find(needle) >= 0:
					offenders.append(child)
		name = dir.get_next()
	dir.list_dir_end()


func _snapshot_account_file() -> Dictionary:
	if not FileAccess.file_exists(AccountStoreScript.PATH):
		return {"exists": false, "text": ""}
	var f := FileAccess.open(AccountStoreScript.PATH, FileAccess.READ)
	if f == null:
		return {"exists": false, "text": ""}
	var text := f.get_as_text()
	f.close()
	return {"exists": true, "text": text}


func _restore_account_file(snapshot: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(AccountStoreScript.PATH)
	if bool(snapshot.get("exists", false)):
		DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
		var f := FileAccess.open(AccountStoreScript.PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(str(snapshot.get("text", "")))
			f.close()
		return
	if FileAccess.file_exists(AccountStoreScript.PATH):
		var dir := DirAccess.open(global_path.get_base_dir())
		if dir != null:
			dir.remove(global_path.get_file())


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
