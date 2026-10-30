extends SceneTree

const ShadowWaterTestScript = preload("res://tests/unit/combat/card/test_shadow_water.gd")


func _init() -> void:
	print("=== Shadow Water Only Tests ===")
	await process_frame
	var suite = ShadowWaterTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Shadow Water Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
