extends RefCounted

const BattleResultOverlayScript = preload("res://scripts/ui/battle/battle_result_overlay.gd")
const BattleCardViewScript = preload("res://scripts/ui/battle/battle_card_view.gd")
const CardScript = preload("res://scripts/combat/card.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_battle_result_overlay.gd --")
	await test_battle_result_overlay_renders_three_card_rewards_as_cards()
	await test_battle_result_overlay_renders_contract_drops_and_defeat()
	return {"passed": _passed, "failed": _failed}


func test_battle_result_overlay_renders_three_card_rewards_as_cards() -> void:
	var overlay = BattleResultOverlayScript.new()
	Engine.get_main_loop().root.add_child(overlay)
	var rewards: Array = [_card("reward_a", "Reward A", 0), _card("reward_b", "Reward B", 1), _card("reward_c", "Reward C", 2)]
	overlay.show_rewards(rewards, "Choose one reward", "visible battle narrative")
	await Engine.get_main_loop().process_frame
	assert_true(overlay.visible, "BattleResultOverlay is visible for reward choices")
	assert_true(_collect_label_text(overlay).contains("visible battle narrative"), "BattleResultOverlay shows narrative rail text")
	var card_views := _find_card_views(overlay)
	assert_true(card_views.size() == 3, "BattleResultOverlay renders three reward cards as BattleCardView")
	for i in range(card_views.size()):
		var view: Control = card_views[i]
		assert_true(view.find_child("CostBadge", true, false) is Label, "reward card %d exposes CostBadge" % i)
		assert_true(view.find_child("NameLabel", true, false) is Label, "reward card %d exposes NameLabel" % i)
		assert_true(view.find_child("EffectLabel", true, false) is Label, "reward card %d exposes EffectLabel" % i)
	var choose_buttons := _find_buttons_named(overlay, "RewardChooseButton")
	assert_true(choose_buttons.size() == 3, "BattleResultOverlay renders three focusable choose actions")
	for button in choose_buttons:
		assert_true((button as Button).focus_mode != Control.FOCUS_NONE and (button as Button).custom_minimum_size.y >= 48, "reward choose action is keyboard/gamepad reachable")
	overlay.queue_free()


func test_battle_result_overlay_renders_contract_drops_and_defeat() -> void:
	var overlay = BattleResultOverlayScript.new()
	Engine.get_main_loop().root.add_child(overlay)
	var selected := _card("selected_reward", "Selected Reward", 1)
	overlay.show_result({
		"outcome": "victory",
		"selected_card": selected,
		"brand_drop": {"display_name": "Readable Brand Drop"},
		"sequence_exp_delta": 2,
		"contract": {"outcome": "broken", "tier": 2, "pollution_delta": 5, "acting_check_difficulty": 7},
		"ai_gm_text": "victory narrative text",
	}, "Victory summary")
	await Engine.get_main_loop().process_frame
	var victory_text := _collect_label_text(overlay)
	assert_true(victory_text.contains("Victory summary"), "BattleResultOverlay renders victory summary")
	assert_true(victory_text.contains("破契") and victory_text.contains("污染 +5") and victory_text.contains("判定 7"), "BattleResultOverlay renders contract drop state")
	assert_true(victory_text.contains("Selected Reward") and victory_text.contains("Readable Brand Drop"), "BattleResultOverlay renders selected reward and brand drop")
	assert_true(victory_text.contains("victory narrative text"), "BattleResultOverlay renders result AI GM narrative")
	overlay.show_result({
		"outcome": "defeat",
		"contract": {"outcome": "broken", "pollution_delta": 5},
		"ai_gm_text": "defeat narrative text",
	}, "Defeat summary")
	await Engine.get_main_loop().process_frame
	var defeat_text := _collect_label_text(overlay)
	assert_true(defeat_text.contains("Defeat summary"), "BattleResultOverlay renders defeat summary")
	assert_true(defeat_text.contains("defeat narrative text"), "BattleResultOverlay renders defeat narrative")
	assert_true(not defeat_text.contains("Selected Reward") and not defeat_text.contains("Readable Brand Drop"), "BattleResultOverlay clears stale victory drops in defeat state")
	overlay.queue_free()


func _card(id: String, display_name: String, cost: int) -> Card:
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": display_name,
		"description": "Readable result overlay card.",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": cost,
		"combat_effect": {
			"damage": 4 + cost,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 1}],
		},
		"tags": ["attack"],
	})


func _find_card_views(root: Node) -> Array:
	var found: Array = []
	if root != null and root.get_script() == BattleCardViewScript:
		found.append(root)
	for child in root.get_children():
		found.append_array(_find_card_views(child))
	return found


func _find_buttons_named(root: Node, prefix: String) -> Array:
	var found: Array = []
	if root is Button and root.name.begins_with(prefix):
		found.append(root)
	for child in root.get_children():
		found.append_array(_find_buttons_named(child, prefix))
	return found


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
