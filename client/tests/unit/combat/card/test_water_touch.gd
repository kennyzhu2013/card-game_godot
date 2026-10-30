extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_water_touch.gd --")
	await _case_water_touch()
	return _result()
