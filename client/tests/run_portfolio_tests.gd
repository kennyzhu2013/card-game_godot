extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/unit/ai_gm/test_prompt_context.gd",
	"res://tests/unit/ai_gm/test_ai_gm_network.gd",
	"res://tests/unit/ai_gm/test_ai_gm_service.gd",
	"res://tests/unit/ai_gm/test_ai_gm_cost_sampler.gd",
	"res://tests/unit/ai_gm/test_template_fill.gd",
]

var _passed := 0
var _failed := 0


func _init() -> void:
	print("=== Greycrown AI GM Portfolio Tests ===")
	await process_frame
	for script_path in TEST_SCRIPTS:
		await _run_test_script(script_path)
	print("\n=== Portfolio Results: %d passed, %d failed ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run_test_script(script_path: String) -> void:
	var script := load(script_path)
	if script == null or not script.can_instantiate():
		_failed += 1
		print("  FAIL: %s loads" % script_path)
		return
	var suite = script.new()
	if not suite.has_method("run"):
		_failed += 1
		print("  FAIL: %s exposes run()" % script_path)
		return
	var result = await suite.call("run")
	if typeof(result) != TYPE_DICTIONARY:
		_failed += 1
		print("  FAIL: %s run() returns Dictionary" % script_path)
		return
	_passed += int(result.get("passed", 0))
	_failed += int(result.get("failed", 0))
