extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_fortune_thread.gd --")
	await _case_fortune_thread()
	return _result()
