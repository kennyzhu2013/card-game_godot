extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_death_s7_reaper_hook.gd --")
	await _case_death_s7_reaper_hook()
	return _result()
