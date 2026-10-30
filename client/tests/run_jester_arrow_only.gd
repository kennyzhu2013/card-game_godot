extends SceneTree

const JesterArrowTestScript = preload("res://tests/unit/combat/card/test_jester_arrow.gd")


func _init() -> void:
	print("=== Jester Arrow Only Tests ===")
	await process_frame
	var suite = JesterArrowTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Jester Arrow Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
