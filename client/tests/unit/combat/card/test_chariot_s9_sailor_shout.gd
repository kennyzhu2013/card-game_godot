extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_chariot_s9_sailor_shout.gd --")
	await _case_chariot_s9_sailor_shout()
	return _result()
