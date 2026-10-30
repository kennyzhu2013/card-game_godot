extends SceneTree

const DeathS9GraveChillTestScript = preload("res://tests/unit/combat/card/test_death_s9_grave_chill.gd")


func _init() -> void:
	print("=== Death S9 Grave Chill Only Tests ===")
	await process_frame
	var suite = DeathS9GraveChillTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Death S9 Grave Chill Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
