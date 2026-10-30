extends SceneTree

const SpellBacklashTestScript = preload("res://tests/unit/combat/card/test_hermit_s7_spell_backlash.gd")


func _init() -> void:
	print("=== Hermit Spell Backlash Only Tests ===")
	await process_frame
	var suite = SpellBacklashTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Spell Backlash Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
