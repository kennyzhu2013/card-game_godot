extends SceneTree

const ChariotS7ThunderBoardingTestScript = preload("res://tests/unit/combat/card/test_chariot_s7_thunder_boarding.gd")


func _init() -> void:
	print("=== Chariot S7 Thunder Boarding Only Tests ===")
	await process_frame
	var suite = ChariotS7ThunderBoardingTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Chariot S7 Thunder Boarding Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
