extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_jester_face.gd --")
	await _case_jester_face()
	return _result()
