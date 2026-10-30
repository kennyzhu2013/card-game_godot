extends RefCounted

const BgmPlayer = preload("res://scripts/battle/phigros/stage/bgm_player.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_bgm_player.gd --")
	test_load_missing_file_marks_not_ready()
	test_play_when_not_ready_is_noop()
	test_stop_when_not_ready_is_noop()
	return {"passed": _passed, "failed": _failed}


func test_load_missing_file_marks_not_ready() -> void:
	var player = BgmPlayer.new()
	player.load_stream("res://assets/audio/phigros/__nonexistent__.wav")
	assert_true(not player.is_ready(), "missing file -> is_ready false")


func test_play_when_not_ready_is_noop() -> void:
	var player = BgmPlayer.new()
	player.load_stream("res://assets/audio/phigros/__nonexistent__.wav")
	# Should not crash
	player.play_loop()
	assert_true(not player.is_ready(), "play_loop on missing file does not flip ready")


func test_stop_when_not_ready_is_noop() -> void:
	var player = BgmPlayer.new()
	player.load_stream("res://assets/audio/phigros/__nonexistent__.wav")
	player.stop()
	assert_true(not player.is_ready(), "stop on missing file does not crash")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s" % msg)
