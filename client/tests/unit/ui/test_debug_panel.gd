extends RefCounted

const CardLibraryScript = preload("res://scripts/combat/card_library.gd")
const DebugPanelScript = preload("res://scripts/debug/debug_panel.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_debug_panel.gd --")
	await test_grant_all_cards_uses_runtime_card_library()
	return {"passed": _passed, "failed": _failed}


func test_grant_all_cards_uses_runtime_card_library() -> void:
	var library = CardLibraryScript.new()
	library.load_all()
	var expected_cards: Array = library.all_cards()
	var expected_ids := _template_ids(expected_cards)

	var gs = GameStateScript.new()
	gs._ready()
	var panel = DebugPanelScript.new()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	panel.open(gs)

	var added := panel.grant_all_cards_once(3)
	var actual_ids := _template_ids(gs.cards_inventory)
	var missing: Array[String] = []
	for template_id in expected_ids:
		if not actual_ids.has(template_id):
			missing.append(template_id)

	assert_eq(added, expected_ids.size(), "debug grant-all count matches CardLibrary.all_cards")
	assert_eq(gs.cards_inventory.size(), expected_ids.size(), "debug grant-all inventory size matches runtime card templates")
	assert_true(missing.is_empty(), "debug grant-all includes runtime data/cards templates: %s" % str(missing))
	for template_id in ["fortune_thread", "inquiry_fortune", "jester_fortune", "mirror_shadow"]:
		assert_true(actual_ids.has(template_id), "debug grant-all includes %s from data/cards" % template_id)

	panel.queue_free()
	await Engine.get_main_loop().process_frame


func _template_ids(cards: Array) -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		if card == null:
			continue
		var template_id := str(card.template_id)
		if template_id == "":
			template_id = str(card.id)
		if template_id != "" and not result.has(template_id):
			result.append(template_id)
	result.sort()
	return result


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
