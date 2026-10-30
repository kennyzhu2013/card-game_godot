extends SceneTree

const JesterNameTestScript = preload("res://tests/unit/combat/card/test_jester_name.gd")


func _init() -> void:
	print("=== Jester Name Only Tests ===")
	await process_frame
	var suite = JesterNameTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Jester Name Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
