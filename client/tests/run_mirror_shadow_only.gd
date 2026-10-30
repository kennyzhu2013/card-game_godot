extends SceneTree

const MirrorShadowTestScript = preload("res://tests/unit/combat/card/test_mirror_shadow.gd")


func _init() -> void:
	print("=== Mirror Shadow Only Tests ===")
	await process_frame
	var suite = MirrorShadowTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Mirror Shadow Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
