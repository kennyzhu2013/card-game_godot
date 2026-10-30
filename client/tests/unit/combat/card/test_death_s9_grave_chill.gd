extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_death_s9_grave_chill.gd --")
	await _case_death_s9_grave_chill()
	return _result()
