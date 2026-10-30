extends SceneTree

const AcrobatTestScript = preload("res://tests/unit/combat/card/test_fool_s8_acrobat_strike.gd")


func _init() -> void:
	print("=== Fool Acrobat Strike Only Tests ===")
	await process_frame
	var suite = AcrobatTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Acrobat Strike Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
