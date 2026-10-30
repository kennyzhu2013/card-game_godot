extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/unit/audio/test_sfx_player.gd",
	"res://tests/unit/ui/test_enemy_standee.gd",
	"res://tests/unit/ui/test_battle_scene_tower_background.gd",
	"res://tests/unit/ui/test_battle_scene.gd",
	"res://tests/unit/ai_gm/test_ai_gm_settings.gd",
]

var _passed := 0
var _failed := 0


func _init() -> void:
	print("=== Publication Regression Tests ===")
	await process_frame
	for script_path in TEST_SCRIPTS:
		await _run_test_script(script_path)
	print("\n=== Publication Results: %d passed, %d failed ===" % [_passed, _failed])
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
