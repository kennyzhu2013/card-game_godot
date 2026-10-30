class_name BgmPlayer
extends Node

var _stream: AudioStream = null
var _player: AudioStreamPlayer = null
var _ready_flag: bool = false


# Read raw WAV bytes from disk and construct an AudioStreamWAV manually,
# bypassing the import pipeline. Supports 16-bit PCM mono/stereo.
static func _load_wav_from_disk(path: String) -> AudioStreamWAV:
	var abs_path := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		push_warning("[BgmPlayer] cannot open %s" % abs_path)
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 44:
		push_warning("[BgmPlayer] wav too short: %d bytes" % bytes.size())
		return null
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		push_warning("[BgmPlayer] not a RIFF/WAVE file: %s" % path)
		return null
	# Walk chunks to find fmt and data
	var pos := 12
	var fmt_channels := 1
	var fmt_rate := 44100
	var fmt_bits := 16
	var data_offset := -1
	var data_size := 0
	while pos + 8 <= bytes.size():
		var chunk_id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_size := bytes.decode_u32(pos + 4)
		var chunk_data_pos := pos + 8
		if chunk_id == "fmt ":
			fmt_channels = bytes.decode_u16(chunk_data_pos + 2)
			fmt_rate = int(bytes.decode_u32(chunk_data_pos + 4))
			fmt_bits = bytes.decode_u16(chunk_data_pos + 14)
		elif chunk_id == "data":
			data_offset = chunk_data_pos
			data_size = int(chunk_size)
			break
		pos = chunk_data_pos + int(chunk_size)
		if chunk_size % 2 == 1:
			pos += 1
	if data_offset < 0 or fmt_bits != 16:
		push_warning("[BgmPlayer] unsupported WAV: bits=%d data_offset=%d" % [fmt_bits, data_offset])
		return null
	var pcm := bytes.slice(data_offset, data_offset + data_size)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = fmt_rate
	stream.stereo = fmt_channels == 2
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = -1
	print("[BgmPlayer] manual WAV loaded: rate=%d, channels=%d, bits=%d, pcm_bytes=%d" % [fmt_rate, fmt_channels, fmt_bits, pcm.size()])
	return stream


func load_stream(path: String) -> void:
	_ready_flag = false
	if not ResourceLoader.exists(path):
		push_warning("[BgmPlayer] resource not found: %s" % path)
		return
	var res := ResourceLoader.load(path)
	if not (res is AudioStream):
		push_warning("[BgmPlayer] not an AudioStream: %s" % path)
		return
	_stream = res
	if _stream is AudioStreamWAV:
		var w := _stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		print("[BgmPlayer] loaded %s rate=%d stereo=%s data=%d format=%d" % [path, w.mix_rate, str(w.stereo), w.data.size(), w.format])
	else:
		print("[BgmPlayer] loaded %s (%s)" % [path, _stream.get_class()])
	_ready_flag = true


func is_ready() -> bool:
	return _ready_flag


func play_loop(volume_db: float = 0.0) -> void:
	if not _ready_flag or _stream == null:
		push_warning("[BgmPlayer] play_loop skipped: not ready")
		return
	if _stream is AudioStreamWAV:
		(_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.stream = _stream
		_player.volume_db = volume_db
		_player.bus = "Master"
		add_child(_player)
	_player.volume_db = volume_db
	if not _player.playing:
		_player.play()
	print("[BgmPlayer] play_loop -> playing=%s, volume_db=%s, bus=%s, master_db=%s, master_mute=%s" % [
		str(_player.playing), str(_player.volume_db), str(_player.bus),
		str(AudioServer.get_bus_volume_db(0)), str(AudioServer.is_bus_mute(0))
	])


func stop() -> void:
	if _player != null and is_instance_valid(_player) and _player.playing:
		_player.stop()
