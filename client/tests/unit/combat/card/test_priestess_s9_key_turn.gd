extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_priestess_s9_key_turn.gd --")
	await _case_priestess_s9_key_turn()
	return _result()
