extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_tower_s8_moonless_field.gd --")
	await _case_tower_s8_moonless_field()
	return _result()
