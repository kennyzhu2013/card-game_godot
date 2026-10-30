extends SceneTree

const MinorTrickTestScript = preload("res://tests/unit/combat/card/test_fool_s7_minor_trick.gd")


func _init() -> void:
	print("=== Fool Minor Trick Only Tests ===")
	await process_frame
	var suite = MinorTrickTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Minor Trick Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
