extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_flame_arrow.gd --")
	await _case_flame_arrow()
	return _result()
