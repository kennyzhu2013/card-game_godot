extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_hermit_s8_rune_cage.gd --")
	await _case_hermit_s8_rune_cage()
	return _result()
