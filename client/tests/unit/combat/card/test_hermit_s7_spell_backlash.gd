extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_hermit_s7_spell_backlash.gd --")
	await _case_hermit_s7_spell_backlash()
	return _result()
