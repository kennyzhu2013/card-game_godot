class_name BeatClock
extends RefCounted

const DEFAULT_WINDOW_MS := 50


static func beat_ms_for_bpm(bpm: int) -> int:
	if bpm <= 0:
		return 0
	return int(round(60000.0 / float(bpm)))


# is_on_beat: checks whether time_ms is within ±window_ms of the nearest beat.
# beat_phase_ms offsets the beat grid; 0 means chart start = beat 0.
static func is_on_beat(time_ms: int, beat_ms: int, beat_phase_ms: int, window_ms: int) -> bool:
	if beat_ms <= 0:
		return false
	var phase := (time_ms - beat_phase_ms) % beat_ms
	if phase < 0:
		phase += beat_ms
	var dist := mini(phase, beat_ms - phase)
	return dist <= window_ms
