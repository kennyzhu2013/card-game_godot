extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_inquiry_name.gd --")
	await _case_inquiry_name()
	return _result()
