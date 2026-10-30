extends SceneTree

const NameArrowTestScript = preload("res://tests/unit/combat/card/test_name_arrow.gd")


func _init() -> void:
	print("=== Name Arrow Only Tests ===")
	await process_frame
	var suite = NameArrowTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Name Arrow Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
