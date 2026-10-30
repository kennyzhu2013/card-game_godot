extends SceneTree

const ShadowThreadTestScript = preload("res://tests/unit/combat/card/test_shadow_thread.gd")


func _init() -> void:
	print("=== Shadow Thread Only Tests ===")
	await process_frame
	var suite = ShadowThreadTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Shadow Thread Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
