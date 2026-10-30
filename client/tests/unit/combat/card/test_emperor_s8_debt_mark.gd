extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_emperor_s8_debt_mark.gd --")
	await _case_emperor_s8_debt_mark()
	return _result()
