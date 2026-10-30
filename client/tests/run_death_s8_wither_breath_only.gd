extends SceneTree

const DeathS8WitherBreathTestScript = preload("res://tests/unit/combat/card/test_death_s8_wither_breath.gd")


func _init() -> void:
	print("=== Death S8 Wither Breath Only Tests ===")
	await process_frame
	var suite = DeathS8WitherBreathTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Death S8 Wither Breath Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
