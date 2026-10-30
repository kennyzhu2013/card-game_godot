extends SceneTree

const ChariotS9TideCutTestScript = preload("res://tests/unit/combat/card/test_chariot_s9_tide_cut.gd")


func _init() -> void:
	print("=== Chariot S9 Tide Cut Only Tests ===")
	await process_frame
	var suite = ChariotS9TideCutTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Chariot S9 Tide Cut Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
