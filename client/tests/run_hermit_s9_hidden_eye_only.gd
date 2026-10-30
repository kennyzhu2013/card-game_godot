extends SceneTree

const HermitS9HiddenEyeTestScript = preload("res://tests/unit/combat/card/test_hermit_s9_hidden_eye.gd")


func _init() -> void:
	print("=== Hermit S9 Hidden Eye Only Tests ===")
	await process_frame
	var suite = HermitS9HiddenEyeTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Hermit S9 Hidden Eye Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
