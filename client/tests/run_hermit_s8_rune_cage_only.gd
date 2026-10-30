extends SceneTree

const HermitS8RuneCageTestScript = preload("res://tests/unit/combat/card/test_hermit_s8_rune_cage.gd")


func _init() -> void:
	print("=== Hermit S8 Rune Cage Only Tests ===")
	await process_frame
	var suite = HermitS8RuneCageTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Hermit S8 Rune Cage Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
