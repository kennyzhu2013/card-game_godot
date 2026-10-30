extends SceneTree

const PriestessS9MistBoltTestScript = preload("res://tests/unit/combat/card/test_priestess_s9_mist_bolt.gd")


func _init() -> void:
	print("=== Priestess S9 Mist Bolt Only Tests ===")
	await process_frame
	var suite = PriestessS9MistBoltTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Priestess S9 Mist Bolt Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
