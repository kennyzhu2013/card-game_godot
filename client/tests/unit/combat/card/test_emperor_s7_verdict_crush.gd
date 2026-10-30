extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_emperor_s7_verdict_crush.gd --")
	await _case_emperor_s7_verdict_crush()
	return _result()
