extends SceneTree

const MirrorFaceTestScript = preload("res://tests/unit/combat/card/test_mirror_face.gd")


func _init() -> void:
	print("=== Mirror Face Only Tests ===")
	await process_frame
	var suite = MirrorFaceTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Mirror Face Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
