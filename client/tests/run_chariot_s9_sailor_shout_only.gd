extends SceneTree

const ChariotS9SailorShoutTestScript = preload("res://tests/unit/combat/card/test_chariot_s9_sailor_shout.gd")


func _init() -> void:
	print("=== Chariot S9 Sailor Shout Only Tests ===")
	await process_frame
	var suite = ChariotS9SailorShoutTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Chariot S9 Sailor Shout Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
