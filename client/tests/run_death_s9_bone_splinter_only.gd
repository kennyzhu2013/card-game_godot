extends SceneTree

const DeathS9BoneSplinterTestScript = preload("res://tests/unit/combat/card/test_death_s9_bone_splinter.gd")


func _init() -> void:
	print("=== Death S9 Bone Splinter Only Tests ===")
	await process_frame
	var suite = DeathS9BoneSplinterTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Death S9 Bone Splinter Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
