extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_tower_s9_night_pebble.gd --")
	await _case_tower_s9_night_pebble()
	return _result()
