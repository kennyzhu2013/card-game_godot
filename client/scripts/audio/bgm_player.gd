extends Node

const MANIFEST_PATH := "res://assets/audio/bgm_manifest.json"
const PLAYER_A_NAME := "BgmPlayerA"
const PLAYER_B_NAME := "BgmPlayerB"
const SILENT_VOLUME_DB := -80.0

var _tracks: Dictionary = {}
var _manifest_loaded := false
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null
var _inactive_player: AudioStreamPlayer = null
var _current_track_id := ""
var _master_volume_db := 0.0
var _fade_tween: Tween = null


func _ready() -> void:
	_ensure_players()


func play(track_id: String, fade_in: float = 1.0) -> void:
	_ensure_players()
	var entry := _entry_for_track(track_id)
	if entry.is_empty():
		return
	var stream := _load_stream(entry)
	if stream == null:
		return
	_stop_player(_inactive_player)
	_current_track_id = track_id
	_start_player(_active_player, stream, _target_volume_db(entry), maxf(fade_in, 0.0))


func crossfade_to(track_id: String, duration: float = 1.5) -> void:
	_ensure_players()
	if track_id == _current_track_id:
		return
	var entry := _entry_for_track(track_id)
	if entry.is_empty():
		return
	var stream := _load_stream(entry)
	if stream == null:
		return
	if _current_track_id == "" or _active_player == null or _active_player.stream == null:
		_current_track_id = track_id
		_start_player(_active_player, stream, _target_volume_db(entry), maxf(duration, 0.0))
		return
	var outgoing := _active_player
	var incoming := _inactive_player
	_active_player = incoming
	_inactive_player = outgoing
	_current_track_id = track_id
	_start_crossfade(incoming, outgoing, stream, _target_volume_db(entry), maxf(duration, 0.0))


func stop(fade_out: float = 1.0) -> void:
	_ensure_players()
	if _active_player == null or _active_player.stream == null:
		_current_track_id = ""
		return
	var outgoing := _active_player
	_current_track_id = ""
	var duration := maxf(fade_out, 0.0)
	if duration <= 0.0 or not is_inside_tree():
		_stop_player(outgoing)
		return
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(outgoing, "volume_db", SILENT_VOLUME_DB, duration)
	_fade_tween.tween_callback(_stop_player.bind(outgoing))


func set_master_volume_db(db: float) -> void:
	_master_volume_db = db
	if _current_track_id == "" or _active_player == null or _active_player.stream == null:
		return
	var entry := _entry_for_track(_current_track_id)
	if entry.is_empty():
		return
	_active_player.volume_db = _target_volume_db(entry)


func current_track() -> String:
	return _current_track_id


func _ensure_players() -> void:
	if _player_a != null and _player_b != null:
		return
	_player_a = get_node_or_null(PLAYER_A_NAME) as AudioStreamPlayer
	if _player_a == null:
		_player_a = AudioStreamPlayer.new()
		_player_a.name = PLAYER_A_NAME
		add_child(_player_a)
	_player_b = get_node_or_null(PLAYER_B_NAME) as AudioStreamPlayer
	if _player_b == null:
		_player_b = AudioStreamPlayer.new()
		_player_b.name = PLAYER_B_NAME
		add_child(_player_b)
	_player_a.volume_db = SILENT_VOLUME_DB
	_player_b.volume_db = SILENT_VOLUME_DB
	_active_player = _player_a
	_inactive_player = _player_b


func _entry_for_track(track_id: String) -> Dictionary:
	_load_manifest()
	if not _tracks.has(track_id):
		push_warning("[Bgm] unknown track_id: %s" % track_id)
		return {}
	var entry: Variant = _tracks.get(track_id, {})
	if not entry is Dictionary:
		push_warning("[Bgm] malformed track entry: %s" % track_id)
		return {}
	return (entry as Dictionary).duplicate(true)


func _load_manifest() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	_tracks.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("[Bgm] manifest not found: %s" % MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_warning("[Bgm] manifest is not a Dictionary")
		return
	var raw_tracks: Variant = (parsed as Dictionary).get("tracks", {})
	if not raw_tracks is Dictionary:
		push_warning("[Bgm] manifest tracks missing")
		return
	_tracks = (raw_tracks as Dictionary).duplicate(true)


func _load_stream(entry: Dictionary) -> AudioStream:
	var path := str(entry.get("path", "")).strip_edges()
	if path == "":
		push_warning("[Bgm] track path is empty")
		return null
	if not ResourceLoader.exists(path):
		push_warning("[Bgm] track resource missing: %s" % path)
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		push_warning("[Bgm] track is not an AudioStream: %s" % path)
		return null
	if stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = bool(entry.get("loop", true))
		mp3.loop_offset = 0.0
	return stream


func _target_volume_db(entry: Dictionary) -> float:
	return float(entry.get("volume_db", 0.0)) + _master_volume_db


func _start_player(player: AudioStreamPlayer, stream: AudioStream, target_volume_db: float, fade_in: float) -> void:
	if player == null:
		return
	_kill_fade_tween()
	player.stream = stream
	player.volume_db = SILENT_VOLUME_DB if fade_in > 0.0 else target_volume_db
	player.play()
	if fade_in <= 0.0 or not is_inside_tree():
		player.volume_db = target_volume_db
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", target_volume_db, fade_in)


func _start_crossfade(incoming: AudioStreamPlayer, outgoing: AudioStreamPlayer, stream: AudioStream, target_volume_db: float, duration: float) -> void:
	if incoming == null:
		return
	_kill_fade_tween()
	incoming.stream = stream
	incoming.volume_db = SILENT_VOLUME_DB if duration > 0.0 else target_volume_db
	incoming.play()
	if duration <= 0.0 or not is_inside_tree():
		incoming.volume_db = target_volume_db
		_stop_player(outgoing)
		return
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", target_volume_db, duration)
	if outgoing != null and outgoing.stream != null:
		_fade_tween.tween_property(outgoing, "volume_db", SILENT_VOLUME_DB, duration)
	_fade_tween.set_parallel(false)
	_fade_tween.tween_callback(_stop_player.bind(outgoing))


func _stop_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.stream = null
	player.volume_db = SILENT_VOLUME_DB


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
