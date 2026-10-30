extends SceneTree

const TowerS8ShadowClawTestScript = preload("res://tests/unit/combat/card/test_tower_s8_shadow_claw.gd")


func _init() -> void:
	print("=== Tower S8 Shadow Claw Only Tests ===")
	await process_frame
	var suite = TowerS8ShadowClawTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Tower S8 Shadow Claw Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
