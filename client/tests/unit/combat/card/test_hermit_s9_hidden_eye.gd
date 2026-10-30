extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_hermit_s9_hidden_eye.gd --")
	await _case_hermit_s9_hidden_eye()
	return _result()
