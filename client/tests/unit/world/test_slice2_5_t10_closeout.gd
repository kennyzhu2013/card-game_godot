extends RefCounted

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_slice2_5_t10_closeout.gd --")
	test_slice2_5_plan_marks_t10_complete()
	test_project_status_advances_to_slice_3_batch_gamma()
	test_agent_progress_reports_t10_closeout_and_next_track()
	return {"passed": _passed, "failed": _failed}


func test_slice2_5_plan_marks_t10_complete() -> void:
	var text := _read_doc("res://../docs/SLICE_2_5_PLAN.md")
	assert_true(text.contains("| T10 | 集成手测 + 测试基线 + commit | T1-T9 | 3 d | ✅ |"), "Slice 2.5 plan marks T10 complete")


func test_project_status_advances_to_slice_3_batch_gamma() -> void:
	var text := _read_doc("res://../docs/PROJECT_STATUS.md")
	assert_true(text.contains("Slice 2.5 T1-T10 are complete."), "Project status marks batch beta complete")
	assert_true(text.contains("docs/SLICE_3_PLAN.md"), "Project status points to Slice 3 plan next")
	assert_true(text.contains("batch gamma") or text.contains("Batch gamma"), "Project status remains on Slice 3 batch gamma")


func test_agent_progress_reports_t10_closeout_and_next_track() -> void:
	var text := _read_doc("res://../output/agent-progress.md")
	assert_true(text.contains("Slice 2.5 T1-T10 are code/test/doc complete."), "Agent progress records T10 closeout")
	assert_true(text.contains("Batch gamma") or text.contains("batch gamma"), "Agent progress remains on Slice 3 batch gamma")


func _read_doc(relative_path: String) -> String:
	var abs_path := ProjectSettings.globalize_path(relative_path)
	if not FileAccess.file_exists(abs_path):
		assert_true(false, "%s exists" % relative_path)
		return ""
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		assert_true(false, "%s opens" % relative_path)
		return ""
	return file.get_as_text()


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
