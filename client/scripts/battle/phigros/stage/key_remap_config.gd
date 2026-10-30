class_name PhigrosKeyRemapConfig
extends Resource

const LANE_KEYS_4 := [KEY_D, KEY_F, KEY_J, KEY_K]
const LANE_KEYS_6 := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_J, KEY_K]
const LANE_KEYS_8 := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_J, KEY_K, KEY_L, KEY_I]

var lane_keycodes: Dictionary = {
	0: KEY_D,
	1: KEY_F,
	2: KEY_J,
	3: KEY_K,
}
var key_map: Dictionary = {
	"lane_0": KEY_D,
	"lane_1": KEY_F,
	"lane_2": KEY_J,
	"lane_3": KEY_K,
}
var lane_count: int = 4


func _init() -> void:
	_sync_default_key_map()


func set_lane_count(n: int) -> void:
	if n != 4 and n != 6 and n != 8:
		return
	lane_count = n
	_sync_default_key_map()


func keys_for_active_layout() -> Array:
	match lane_count:
		6:
			return LANE_KEYS_6
		8:
			return LANE_KEYS_8
		_:
			return LANE_KEYS_4


func key_for_lane(lane: int) -> int:
	var keys := keys_for_active_layout()
	var safe_lane := clampi(lane, 0, keys.size() - 1)
	return int(key_map.get("lane_%d" % safe_lane, lane_keycodes.get(safe_lane, keys[safe_lane])))


func lane_for_key(keycode: int) -> int:
	for lane in range(lane_count):
		if key_for_lane(lane) == keycode:
			return lane
	return -1


func lane_for_keycode(keycode: int) -> int:
	return lane_for_key(keycode)


func lane_label(lane: int) -> String:
	return OS.get_keycode_string(key_for_lane(lane))


func _sync_default_key_map() -> void:
	lane_keycodes.clear()
	key_map.clear()
	var keys := keys_for_active_layout()
	for i in range(keys.size()):
		lane_keycodes[i] = keys[i]
		key_map["lane_%d" % i] = keys[i]
