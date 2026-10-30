# client/tests/unit/phigros/test_pokemon_character_pulse.gd
extends RefCounted

const PokemonCharacter = preload("res://scripts/battle/phigros/stage/pokemon_character.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_pokemon_character_pulse.gd --")
	test_pulse_period_for_bpm_90()
	test_pulse_period_for_bpm_120()
	test_stop_pulse_clears_timer()
	test_judge_feedback_records_last_verdict()
	test_judge_feedback_miss_marks_shake_pending()
	return {"passed": _passed, "failed": _failed}


func test_pulse_period_for_bpm_90() -> void:
	var pc = PokemonCharacter.new()
	var period_ms := pc.compute_pulse_period_ms(90)
	assert_eq(period_ms, 667, "90 BPM -> 667ms period")


func test_pulse_period_for_bpm_120() -> void:
	var pc = PokemonCharacter.new()
	var period_ms := pc.compute_pulse_period_ms(120)
	assert_eq(period_ms, 500, "120 BPM -> 500ms period")


func test_stop_pulse_clears_timer() -> void:
	var pc = PokemonCharacter.new()
	pc.start_bpm_pulse(120)
	pc.stop_bpm_pulse()
	assert_true(not pc.is_pulsing(), "is_pulsing false after stop")


func test_judge_feedback_records_last_verdict() -> void:
	var pc = PokemonCharacter.new()
	pc.play_judge_feedback("perfect")
	assert_eq(pc.last_judge_verdict, "perfect", "last_judge_verdict tracks input")


func test_judge_feedback_miss_marks_shake_pending() -> void:
	var pc = PokemonCharacter.new()
	pc.play_judge_feedback("miss")
	assert_true(pc.shake_pending, "shake_pending true after miss")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s expected '%s' got '%s'" % [msg, str(expected), str(actual)])
