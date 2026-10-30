extends SceneTree

const EmperorS9ContractBindTestScript = preload("res://tests/unit/combat/card/test_emperor_s9_contract_bind.gd")


func _init() -> void:
	print("=== Emperor S9 Contract Bind Only Tests ===")
	await process_frame
	var suite = EmperorS9ContractBindTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Emperor S9 Contract Bind Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
