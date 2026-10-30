extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_inquiry_fortune.gd --")
	await _case_inquiry_fortune()
	return _result()
