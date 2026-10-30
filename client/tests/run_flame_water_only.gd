extends SceneTree

const FlameWaterTestScript = preload("res://tests/unit/combat/card/test_flame_water.gd")


func _init() -> void:
	print("=== Flame Water Only Tests ===")
	await process_frame
	var suite = FlameWaterTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Flame Water Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
