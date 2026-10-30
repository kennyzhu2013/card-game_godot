extends "res://tests/unit/combat/card/fool_card_e2e_harness.gd"

func run() -> Dictionary:
	print("\n-- test_fool_s9_star_chart_divination.gd --")
	await _case_fool_s9_star_chart_divination()
	return _result()
