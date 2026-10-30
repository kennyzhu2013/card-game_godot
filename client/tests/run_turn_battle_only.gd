extends SceneTree

const TurnBattleTestScript = preload("res://tests/unit/combat/test_turn_battle.gd")


func _init() -> void:
	print("=== TurnBattle Only Tests ===")
	await process_frame
	var suite = TurnBattleTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== TurnBattle Only Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
