extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_p0_chariot_storm_pulse.gd --")
	await _case_p0_chariot_storm_pulse()
	return _result()
