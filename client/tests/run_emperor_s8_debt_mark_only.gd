extends SceneTree

const EmperorS8DebtMarkTestScript = preload("res://tests/unit/combat/card/test_emperor_s8_debt_mark.gd")


func _init() -> void:
	print("=== Emperor S8 Debt Mark Only Tests ===")
	await process_frame
	var suite = EmperorS8DebtMarkTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Emperor S8 Debt Mark Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
