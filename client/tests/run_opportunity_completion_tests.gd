extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/unit/world/test_field_opportunity_service.gd",
	"res://tests/unit/ui/test_district_entry_selector.gd",
]

var _passed := 0
var _failed := 0


func _init() -> void:
	print("=== Opportunity Completion Tests ===")
	await process_frame
	for script_path in TEST_SCRIPTS:
		await _run_test_script(script_path)
	print("\n=== Opportunity Completion Results: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		print("OPPORTUNITY COMPLETION TESTS FAILED!")
	else:
		print("OPPORTUNITY COMPLETION TESTS PASSED!")
	quit(1 if _failed > 0 else 0)


func _run_test_script(script_path: String) -> void:
	var script := load(script_path)
	if script == null or not script.can_instantiate():
		_record(false, "%s loads" % script_path)
		return
	var suite = script.new()
	if not suite.has_method("run"):
		_record(false, "%s exposes run()" % script_path)
		return
	var result = await suite.call("run")
	if typeof(result) != TYPE_DICTIONARY:
		_record(false, "%s run() returns Dictionary" % script_path)
		return
	_passed += int(result.get("passed", 0))
	_failed += int(result.get("failed", 0))


func _record(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
