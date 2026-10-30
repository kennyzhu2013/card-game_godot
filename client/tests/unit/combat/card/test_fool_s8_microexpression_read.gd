extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_fool_s8_microexpression_read.gd --")
	await _case_fool_s8_microexpression_read()
	return _result()
