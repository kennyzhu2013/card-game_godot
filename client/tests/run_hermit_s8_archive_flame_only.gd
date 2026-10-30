extends SceneTree

const HermitS8ArchiveFlameTestScript = preload("res://tests/unit/combat/card/test_hermit_s8_archive_flame.gd")


func _init() -> void:
	print("=== Hermit S8 Archive Flame Only Tests ===")
	await process_frame
	var suite = HermitS8ArchiveFlameTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Hermit S8 Archive Flame Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
