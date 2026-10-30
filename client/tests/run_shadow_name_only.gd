extends SceneTree

const ShadowNameTestScript = preload("res://tests/unit/combat/card/test_shadow_name.gd")


func _init() -> void:
	print("=== Shadow Name Only Tests ===")
	await process_frame
	var suite = ShadowNameTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Shadow Name Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
