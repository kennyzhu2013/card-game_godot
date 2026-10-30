extends SceneTree

const TowerS9QuietStepTestScript = preload("res://tests/unit/combat/card/test_tower_s9_quiet_step.gd")


func _init() -> void:
	print("=== Tower S9 Quiet Step Only Tests ===")
	await process_frame
	var suite = TowerS9QuietStepTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Tower S9 Quiet Step Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
