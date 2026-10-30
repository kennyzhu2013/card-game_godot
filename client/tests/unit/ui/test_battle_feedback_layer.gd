extends RefCounted

const BattleFeedbackLayerScript = preload("res://scripts/ui/battle/battle_feedback_layer.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_battle_feedback_layer.gd --")
	await test_battle_feedback_layer_records_damage_status_and_card_events()
	await test_battle_feedback_layer_is_compact_single_line_surface()
	return {"passed": _passed, "failed": _failed}


func test_battle_feedback_layer_records_damage_status_and_card_events() -> void:
	var layer = BattleFeedbackLayerScript.new()
	Engine.get_main_loop().root.add_child(layer)
	layer.push_event({"type": "card_played", "card_name": "Feedback Probe"})
	layer.push_event({"type": "damage", "target": "Enemy Probe", "amount": 7})
	layer.push_event({"type": "defense_change", "target": "Enemy Probe", "before": 5, "after": 2})
	layer.push_event({"type": "status_applied", "status": "weak"})
	await Engine.get_main_loop().process_frame
	var initial_text := _collect_label_text(layer)
	assert_true(initial_text.contains("Feedback Probe"), "feedback layer records card-played events")
	assert_true(initial_text.contains("Enemy Probe") and initial_text.contains("7"), "feedback layer records damage events")
	assert_true(initial_text.contains("DEF") and initial_text.contains("5") and initial_text.contains("2"), "feedback layer records defense-change events")
	assert_true(initial_text.contains("weak"), "feedback layer records status-applied events")
	for i in range(12):
		layer.push_event({"type": "damage", "target": "Overflow Probe %d" % i, "amount": i + 1})
	await Engine.get_main_loop().process_frame
	var max_visible := int(layer.call("max_visible_events"))
	assert_true(int(layer.call("event_label_count")) <= max_visible, "feedback layer caps pooled visible labels")
	layer.queue_free()


func test_battle_feedback_layer_is_compact_single_line_surface() -> void:
	var layer = BattleFeedbackLayerScript.new()
	Engine.get_main_loop().root.add_child(layer)
	layer.bind_state(
		"Compact Card",
		"Compact recent action",
		["older log entry", "newest log entry"],
		[
			{"reason": "status_applied", "status": "weak"},
			{"reason": "marker_added", "added": 2},
		]
	)
	await Engine.get_main_loop().process_frame
	assert_true(layer.custom_minimum_size.y <= 28.0, "feedback layer is compact enough to avoid a mega-panel footprint")
	assert_true(int(layer.call("event_label_count")) <= 1, "feedback layer uses at most one compact event label")
	var visible_text := _collect_label_text(layer)
	assert_true(visible_text.contains("Compact recent action"), "compact feedback layer keeps the recent action readable")
	layer.queue_free()


func _collect_label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
