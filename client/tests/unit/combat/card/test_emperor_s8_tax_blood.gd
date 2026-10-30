extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_emperor_s8_tax_blood.gd --")
	await _case_emperor_s8_tax_blood()
	return _result()
