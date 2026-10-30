extends Node

const MANIFEST_PATH := "res://assets/audio/sfx_manifest.json"
const POOL_SIZE := 8
const HOVER_THROTTLE_MS := 80

var _sfx: Dictionary = {}
var _manifest_loaded := false
var _player_pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _stream_cache: Dictionary = {}
var _warned_ids: Dictionary = {}
var _master_volume_db := 0.0
var _last_hover_time_msec := 0


func _ready() -> void:
	_ensure_pool()


func play(sfx_id: String, volume_offset_db: float = 0.0) -> void:
	if sfx_id == "card_hover":
		var now := Time.get_ticks_msec()
		if now - _last_hover_time_msec < HOVER_THROTTLE_MS:
			return
		_last_hover_time_msec = now

	_ensure_pool()
	var entry := _entry_for_sfx(sfx_id)
	if entry.is_empty():
		return
	var stream := _load_stream_cached(entry)
	if stream == null:
		return
	var player := _next_player()
	if player == null:
		return
	var target_volume := float(entry.get("volume_db", 0.0)) + _master_volume_db + volume_offset_db
	player.stream = stream
	player.volume_db = target_volume
	player.bus = _find_bus()
	player.play()


func set_master_volume_db(db: float) -> void:
	_master_volume_db = db


func _ensure_pool() -> void:
	if _player_pool.size() >= POOL_SIZE:
		return
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		add_child(player)
		_player_pool.append(player)
	_pool_index = 0


func _next_player() -> AudioStreamPlayer:
	if _player_pool.is_empty():
		return null
	var player := _player_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _player_pool.size()
	return player


func _entry_for_sfx(sfx_id: String) -> Dictionary:
	_load_manifest()
	if not _sfx.has(sfx_id):
		if not _warned_ids.has(sfx_id):
			push_warning("[Sfx] unknown sfx_id: %s" % sfx_id)
			_warned_ids[sfx_id] = true
		return {}
	var entry: Variant = _sfx.get(sfx_id, {})
	if not entry is Dictionary:
		if not _warned_ids.has(sfx_id):
			push_warning("[Sfx] malformed sfx entry: %s" % sfx_id)
			_warned_ids[sfx_id] = true
		return {}
	return (entry as Dictionary).duplicate(true)


func _load_manifest() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	_sfx.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("[Sfx] manifest not found: %s" % MANIFEST_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_warning("[Sfx] manifest is not a Dictionary")
		return
	var raw_sfx: Variant = (parsed as Dictionary).get("sfx", {})
	if not raw_sfx is Dictionary:
		push_warning("[Sfx] manifest sfx missing")
		return
	_sfx = (raw_sfx as Dictionary).duplicate(true)


func _load_stream_cached(entry: Dictionary) -> AudioStream:
	var path := str(entry.get("path", "")).strip_edges()
	if path == "":
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream := _load_stream_or_fallback(path)
	_stream_cache[path] = stream
	return stream


func _load_stream_or_fallback(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("[Sfx] file not found, using silent fallback: %s" % path)
		return _create_silent_stream()
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		push_warning("[Sfx] not an AudioStream, using silent fallback: %s" % path)
		return _create_silent_stream()
	return stream


func _create_silent_stream() -> AudioStream:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	return gen


func _find_bus() -> String:
	for i in range(AudioServer.bus_count):
		var bus_name := AudioServer.get_bus_name(i)
		if bus_name == "SFX":
			return "SFX"
	return "Master"
