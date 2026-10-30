extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_name_arrow.gd --")
	await _case_name_arrow()
	return _result()
