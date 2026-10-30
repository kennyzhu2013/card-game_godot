extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_shadow_thread.gd --")
	await _case_shadow_thread()
	return _result()
