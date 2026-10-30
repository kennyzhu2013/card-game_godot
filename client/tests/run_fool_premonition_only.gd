extends SceneTree

const PremonitionTestScript = preload("res://tests/unit/combat/card/test_fool_s9_premonition.gd")


func _init() -> void:
	print("=== Fool Premonition Only Tests ===")
	await process_frame
	var suite = PremonitionTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Premonition Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
