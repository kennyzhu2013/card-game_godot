extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_mirror_face.gd --")
	await _case_mirror_face()
	return _result()
