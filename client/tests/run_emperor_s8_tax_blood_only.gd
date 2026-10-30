extends SceneTree

const EmperorS8TaxBloodTestScript = preload("res://tests/unit/combat/card/test_emperor_s8_tax_blood.gd")


func _init() -> void:
	print("=== Emperor S8 Tax Blood Only Tests ===")
	await process_frame
	var suite = EmperorS8TaxBloodTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Emperor S8 Tax Blood Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
