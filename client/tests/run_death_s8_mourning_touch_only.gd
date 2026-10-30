extends SceneTree

const DeathS8MourningTouchTestScript = preload("res://tests/unit/combat/card/test_death_s8_mourning_touch.gd")


func _init() -> void:
	print("=== Death S8 Mourning Touch Only Tests ===")
	await process_frame
	var suite = DeathS8MourningTouchTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Death S8 Mourning Touch Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
