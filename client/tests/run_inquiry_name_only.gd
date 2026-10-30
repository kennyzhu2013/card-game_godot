extends SceneTree

const InquiryNameTestScript = preload("res://tests/unit/combat/card/test_inquiry_name.gd")


func _init() -> void:
	print("=== Inquiry Name Only Tests ===")
	await process_frame
	var suite = InquiryNameTestScript.new()
	var result = await suite.run()
	var passed := int(result.get("passed", 0))
	var failed := int(result.get("failed", 0))
	print("\n=== Inquiry Name Contract Results: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)
