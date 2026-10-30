extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_thread_arrow.gd --")
	await _case_thread_arrow()
	return _result()
