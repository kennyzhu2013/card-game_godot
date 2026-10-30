extends RefCounted

const BGM_SCRIPT_PATH := "res://scripts/audio/bgm_player.gd"
const MANIFEST_PATH := "res://assets/audio/bgm_manifest.json"
const EXPECTED_TRACKS := {
	"hub_sanctuary": {
		"path": "res://assets/audio/bgm/hub_sanctuary.mp3",
		"title": "Hub Sanctuary",
		"volume_db": -6.0,
	},
	"tower_combat": {
		"path": "res://assets/audio/bgm/tower_combat.mp3",
		"title": "Lamplit Gambit",
		"volume_db": -8.0,
	},
	"hammer_forge": {
		"path": "res://assets/audio/bgm/hammer_forge.mp3",
		"title": "Clockwork Grid",
		"volume_db": -6.0,
	},
	"pendulum_dream": {
		"path": "res://assets/audio/bgm/pendulum_dream.mp3",
		"title": "Pendulum Under Glass",
		"volume_db": -8.0,
	},
	"whisper_alley": {
		"path": "res://assets/audio/bgm/whisper_alley.mp3",
		"title": "Gaslamp Footsteps",
		"volume_db": -7.0,
	},
	"foghorn_harbor": {
		"path": "res://assets/audio/bgm/foghorn_harbor.mp3",
		"title": "Fogline Harbor",
		"volume_db": -7.0,
	},
	"hollow_cathedral": {
		"path": "res://assets/audio/bgm/hollow_cathedral.mp3",
		"title": "Hollow Cathedral",
		"volume_db": -6.0,
	},
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_bgm_player.gd --")
	test_manifest_loads_seven_tracks()
	await test_play_unknown_track_does_not_crash()
	await test_crossfade_same_track_is_noop()
	test_track_paths_exist()
	return {"passed": _passed, "failed": _failed}


func test_manifest_loads_seven_tracks() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "BGM manifest exists")
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed is Dictionary, "BGM manifest parses as a Dictionary")
	if not parsed is Dictionary:
		return
	var tracks: Variant = (parsed as Dictionary).get("tracks", {})
	assert_true(tracks is Dictionary, "BGM manifest exposes tracks Dictionary")
	if not tracks is Dictionary:
		return
	var track_dict := tracks as Dictionary
	assert_eq(track_dict.size(), EXPECTED_TRACKS.size(), "BGM manifest contains exactly seven tracks")
	for track_id in EXPECTED_TRACKS.keys():
		assert_true(track_dict.has(track_id), "%s is registered in BGM manifest" % str(track_id))
		if not track_dict.has(track_id):
			continue
		var entry: Variant = track_dict[track_id]
		assert_true(entry is Dictionary, "%s manifest entry is a Dictionary" % str(track_id))
		if not entry is Dictionary:
			continue
		var expected: Dictionary = EXPECTED_TRACKS[track_id]
		var entry_dict := entry as Dictionary
		assert_eq(str(entry_dict.get("path", "")), str(expected.get("path", "")), "%s path matches target mp3" % str(track_id))
		assert_eq(str(entry_dict.get("title", "")), str(expected.get("title", "")), "%s title matches manifest spec" % str(track_id))
		assert_true(bool(entry_dict.get("loop", false)), "%s manifest loop is true" % str(track_id))
		assert_true(abs(float(entry_dict.get("volume_db", 0.0)) - float(expected.get("volume_db", 0.0))) <= 0.001, "%s volume_db matches manifest spec" % str(track_id))


func test_play_unknown_track_does_not_crash() -> void:
	var bgm := _new_bgm()
	if bgm == null:
		return
	Engine.get_main_loop().root.add_child(bgm)
	await Engine.get_main_loop().process_frame
	bgm.call("play", "__missing_track__", 0.0)
	await Engine.get_main_loop().process_frame
	assert_eq(str(bgm.call("current_track")), "", "unknown track leaves current_track empty")
	bgm.queue_free()
	await Engine.get_main_loop().process_frame


func test_crossfade_same_track_is_noop() -> void:
	var bgm := _new_bgm()
	if bgm == null:
		return
	Engine.get_main_loop().root.add_child(bgm)
	await Engine.get_main_loop().process_frame
	bgm.call("play", "hub_sanctuary", 0.0)
	await Engine.get_main_loop().process_frame
	var active_name_before := _active_player_name(bgm)
	var active_stream_before := _active_stream_id(bgm)
	var players_with_stream_before := _players_with_stream_count(bgm)
	bgm.call("crossfade_to", "hub_sanctuary", 0.0)
	await Engine.get_main_loop().process_frame
	assert_eq(str(bgm.call("current_track")), "hub_sanctuary", "same-track crossfade keeps current_track")
	assert_eq(_active_player_name(bgm), active_name_before, "same-track crossfade keeps the same active AudioStreamPlayer")
	assert_eq(_active_stream_id(bgm), active_stream_before, "same-track crossfade keeps the same active stream instance")
	assert_eq(_players_with_stream_count(bgm), players_with_stream_before, "same-track crossfade does not start a second stream")
	bgm.queue_free()
	await Engine.get_main_loop().process_frame


func test_track_paths_exist() -> void:
	for track_id in EXPECTED_TRACKS.keys():
		var path := str(EXPECTED_TRACKS[track_id].get("path", ""))
		assert_true(ResourceLoader.exists(path), "%s mp3 exists as a Godot resource" % str(track_id))
		var import_path := "%s.import" % path
		assert_true(FileAccess.file_exists(import_path), "%s mp3 import settings exist" % str(track_id))
		if FileAccess.file_exists(import_path):
			var import_text := FileAccess.get_file_as_string(import_path)
			assert_true(import_text.find("loop=true") >= 0, "%s mp3 import loop=true" % str(track_id))
			assert_true(import_text.find("loop_offset=0") >= 0, "%s mp3 import loop_offset=0" % str(track_id))


func _new_bgm() -> Node:
	var script = load(BGM_SCRIPT_PATH)
	assert_true(script != null, "global BGM player script loads")
	if script == null:
		return null
	assert_true(script.can_instantiate(), "global BGM player script can instantiate")
	if not script.can_instantiate():
		return null
	var bgm = script.new()
	assert_true(bgm is Node, "global BGM player is a Node")
	if not bgm is Node:
		return null
	return bgm as Node


func _audio_players(bgm: Node) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child in bgm.get_children():
		if child is AudioStreamPlayer:
			players.append(child as AudioStreamPlayer)
	return players


func _active_player_name(bgm: Node) -> String:
	for player in _audio_players(bgm):
		if player.stream != null:
			return player.name
	return ""


func _active_stream_id(bgm: Node) -> int:
	for player in _audio_players(bgm):
		if player.stream != null:
			return player.stream.get_instance_id()
	return 0


func _players_with_stream_count(bgm: Node) -> int:
	var count := 0
	for player in _audio_players(bgm):
		if player.stream != null:
			count += 1
	return count


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual, expected, message: String) -> void:
	if actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s (expected=%s actual=%s)" % [message, str(expected), str(actual)])
