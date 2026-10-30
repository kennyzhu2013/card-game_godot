extends SceneTree

const DeathS7ReaperHookTestScript = preload("res://tests/unit/combat/card/test_death_s7_reaper_hook.gd")


func _init() -> void:
	print("=== Death S7 Reaper Hook Only Tests ===")
	await process_frame
	var suite = DeathS7ReaperHookTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Death S7 Reaper Hook Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
