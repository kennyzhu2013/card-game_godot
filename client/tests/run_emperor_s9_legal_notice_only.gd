extends SceneTree

const EmperorS9LegalNoticeTestScript = preload("res://tests/unit/combat/card/test_emperor_s9_legal_notice.gd")


func _init() -> void:
	print("=== Emperor S9 Legal Notice Only Tests ===")
	await process_frame
	var suite = EmperorS9LegalNoticeTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Emperor S9 Legal Notice Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
