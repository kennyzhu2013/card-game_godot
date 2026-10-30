extends SceneTree

const PriestessS9KeyTurnTestScript = preload("res://tests/unit/combat/card/test_priestess_s9_key_turn.gd")


func _init() -> void:
	print("=== Priestess S9 Key Turn Only Tests ===")
	await process_frame
	var suite = PriestessS9KeyTurnTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Priestess S9 Key Turn Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
