extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"


func run() -> Dictionary:
	print("\n-- test_hermit_s9_glyph_spark.gd --")
	await _case_hermit_s9_glyph_spark()
	return _result()
