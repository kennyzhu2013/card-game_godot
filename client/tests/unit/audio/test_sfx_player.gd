extends RefCounted

const SFX_MANIFEST_PATH := "res://assets/audio/sfx_manifest.json"
const SFX_SCRIPT_PATH := "res://scripts/audio/sfx_player.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_sfx_player.gd --")
	test_manifest_loads_ten_sfx()
	await test_play_unknown_sfx_does_not_crash()
	test_sfx_paths_in_manifest_are_well_formed()
	await test_pool_reuses_players()
	await test_hover_throttle_within_80ms()
	return {"passed": _passed, "failed": _failed}


func test_manifest_loads_ten_sfx() -> void:
	assert_true(FileAccess.file_exists(SFX_MANIFEST_PATH), "SFX manifest exists")
	if not FileAccess.file_exists(SFX_MANIFEST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SFX_MANIFEST_PATH))
	assert_true(parsed is Dictionary, "SFX manifest parses as a Dictionary")
	if not parsed is Dictionary:
		return
	var raw_sfx: Variant = (parsed as Dictionary).get("sfx", {})
	assert_true(raw_sfx is Dictionary, "SFX manifest exposes an sfx Dictionary")
	if not raw_sfx is Dictionary:
		return
	var sfx := raw_sfx as Dictionary
	assert_eq(sfx.size(), 10, "SFX manifest contains exactly ten entries")
	for sfx_id in [
		"card_draw", "card_hover", "card_play", "card_discard",
		"damage_player", "damage_enemy", "turn_end",
		"victory", "defeat", "ui_click",
	]:
		assert_true(sfx.has(sfx_id), "SFX manifest contains %s" % sfx_id)


func test_play_unknown_sfx_does_not_crash() -> void:
	var sfx_player := await _new_sfx_player()
	if sfx_player == null:
		return
	sfx_player.call("play", "nonexistent_sfx_id")
	await Engine.get_main_loop().process_frame
	assert_true(is_instance_valid(sfx_player) and sfx_player.is_inside_tree(), "unknown SFX id leaves the player alive")
	sfx_player.queue_free()
	await Engine.get_main_loop().process_frame


func test_sfx_paths_in_manifest_are_well_formed() -> void:
	if not FileAccess.file_exists(SFX_MANIFEST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SFX_MANIFEST_PATH))
	if not parsed is Dictionary:
		return
	var raw_sfx: Variant = (parsed as Dictionary).get("sfx", {})
	if not raw_sfx is Dictionary:
		return
	for sfx_id in (raw_sfx as Dictionary).keys():
		var entry: Variant = (raw_sfx as Dictionary).get(sfx_id, {})
		assert_true(entry is Dictionary, "%s SFX entry is a Dictionary" % sfx_id)
		if not entry is Dictionary:
			continue
		var path := str((entry as Dictionary).get("path", ""))
		assert_true(path.begins_with("res://"), "%s SFX path begins with res://" % sfx_id)
		assert_true(path.ends_with(".ogg"), "%s SFX path ends with .ogg" % sfx_id)


func test_pool_reuses_players() -> void:
	var sfx_player := await _new_sfx_player()
	if sfx_player == null:
		return
	for _i in range(9):
		sfx_player.call("play", "card_draw")
	await Engine.get_main_loop().process_frame
	assert_eq(_audio_player_count(sfx_player), 8, "SFX pool stays at eight AudioStreamPlayer nodes")
	sfx_player.queue_free()
	await Engine.get_main_loop().process_frame


func test_hover_throttle_within_80ms() -> void:
	var sfx_player := await _new_sfx_player()
	if sfx_player == null:
		return
	sfx_player.set("_last_hover_time_msec", Time.get_ticks_msec() - 1000)
	sfx_player.call("play", "card_hover")
	var first_pool_index := int(sfx_player.get("_pool_index"))
	sfx_player.call("play", "card_hover")
	var throttled_pool_index := int(sfx_player.get("_pool_index"))
	assert_eq(throttled_pool_index, first_pool_index, "second hover inside 80ms does not consume another pool player")
	await Engine.get_main_loop().create_timer(0.09).timeout
	sfx_player.call("play", "card_hover")
	var resumed_pool_index := int(sfx_player.get("_pool_index"))
	assert_true(resumed_pool_index != throttled_pool_index, "hover after 80ms resumes playback")
	sfx_player.queue_free()
	await Engine.get_main_loop().process_frame


func _new_sfx_player() -> Node:
	var script = load(SFX_SCRIPT_PATH)
	assert_true(script != null and script.can_instantiate(), "SFX player script loads and instantiates")
	if script == null or not script.can_instantiate():
		return null
	var sfx_player = script.new()
	Engine.get_main_loop().root.add_child(sfx_player)
	await Engine.get_main_loop().process_frame
	assert_eq(_audio_player_count(sfx_player), 8, "SFX player creates an eight-node pool")
	return sfx_player


func _audio_player_count(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is AudioStreamPlayer:
			count += 1
	return count


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
