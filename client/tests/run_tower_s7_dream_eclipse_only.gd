extends SceneTree

const TowerS7DreamEclipseTestScript = preload("res://tests/unit/combat/card/test_tower_s7_dream_eclipse.gd")


func _init() -> void:
	print("=== Tower S7 Dream Eclipse Only Tests ===")
	await process_frame
	var suite = TowerS7DreamEclipseTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Tower S7 Dream Eclipse Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
