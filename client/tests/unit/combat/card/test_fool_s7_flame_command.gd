extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_fool_s7_flame_command.gd --")
	await _case_fool_s7_flame_command()
	return _result()
