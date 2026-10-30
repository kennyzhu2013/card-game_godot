extends SceneTree

const ShadowFlameTestScript = preload("res://tests/unit/combat/card/test_shadow_flame.gd")


func _init() -> void:
	print("=== Shadow Flame Only Tests ===")
	await process_frame
	var suite = ShadowFlameTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Shadow Flame Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
