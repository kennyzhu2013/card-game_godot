extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const FloorScript = preload("res://scripts/tower/floor.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")

const TOWER_RUNNER_SCENE := "res://scenes/tower/tower_runner.tscn"

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		match str(ctx.scene):
			"mainline_boss":
				return "visible mainline boss ai gm narration"
			"boss_victory":
				return "visible boss victory ai gm narration"
			"tower_floor_transition":
				return "visible floor transition ai gm narration"
			_:
				return "visible generic ai gm narration"


func run() -> Dictionary:
	print("\n-- test_tower_runner_ai_gm_visibility.gd --")
	await test_mainline_boss_ai_gm_text_surfaces_in_active_battle_scene()
	await test_boss_victory_ai_gm_text_surfaces_after_battle_result()
	return {"passed": _passed, "failed": _failed}


func test_mainline_boss_ai_gm_text_surfaces_in_active_battle_scene() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var fake := FakeAIGMService.new()
	runner.set_ai_gm_service(fake)
	var gs = _state()
	var tower = _tower()
	var opened: Dictionary = runner.open(tower, gs)
	assert_true(bool(opened.get("ok", false)), "TowerRunner opens mainline boss tower")
	runner.enter_current_floor()
	await Engine.get_main_loop().process_frame
	var battle_scene = runner.get_active_battle_scene()
	assert_true(battle_scene != null, "TowerRunner starts an active BattleScene for boss floor")
	var visible_text = _collect_label_text(battle_scene)
	assert_true(visible_text.contains("visible mainline boss ai gm narration"), "mainline boss AI GM narration is visible in active BattleScene")
	runner.queue_free()
	gs.queue_free()


func test_boss_victory_ai_gm_text_surfaces_after_battle_result() -> void:
	var runner = await _runner()
	if runner == null:
		return
	var fake := FakeAIGMService.new()
	runner.set_ai_gm_service(fake)
	var gs = _state()
	var tower = _tower()
	var opened: Dictionary = runner.open(tower, gs)
	assert_true(bool(opened.get("ok", false)), "TowerRunner opens boss victory visibility tower")
	runner.enter_current_floor()
	await Engine.get_main_loop().process_frame
	runner.handle_battle_result({"outcome": "victory", "contract": {"ratio": 1.0}})
	await Engine.get_main_loop().process_frame
	var visible_text = _collect_label_text(runner)
	assert_true(visible_text.contains("visible boss victory ai gm narration"), "boss victory AI GM narration remains visible after battle result")
	runner.queue_free()
	gs.queue_free()


func _runner():
	var scene = load(TOWER_RUNNER_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "tower_runner scene loads for AI GM visibility")
		return null
	var runner = scene.instantiate()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	return runner


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.ap = 12
	gs.sequence = 6
	gs.pollution = 64
	gs.pollution_stage = 2
	var card = _card("visible_ai_gm_test_card")
	gs.add_card(card)
	gs.set_active_deck([card.id])
	return gs


func _tower():
	var tower = TowerScript.new()
	tower.tower_id = "visible_ai_gm_tower"
	tower.tower_name = "Visible AI GM Tower"
	tower.size = "small"
	tower.district = "ascetic_mountain"
	tower.theme_modifiers = {"mainline_node_id": "node_6_final_tower"}
	tower.floors = [
		_floor(0, "boss", {"boss_id": "pseudo_god_shadow"}),
		_floor(1, "event", {
			"title": "After Boss",
			"narrative_template": "The next landing waits.",
			"choices": [{"id": "continue", "text": "Continue", "outcome": {}}],
		}),
	]
	tower.floor_count = tower.floors.size()
	return tower


func _floor(index: int, event_type: String, event_data: Dictionary):
	var floor = FloorScript.new()
	floor.floor_index = index
	floor.event_type = event_type
	floor.event_data = event_data.duplicate(true)
	return floor


func _card(card_id: String):
	return CardScript.from_json({
		"id": card_id,
		"template_id": card_id,
		"display_name": card_id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 1,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})


func _collect_label_text(root: Node) -> String:
	var parts: Array[String] = []
	_collect_label_text_recursive(root, parts)
	return "\n".join(parts)


func _collect_label_text_recursive(node: Node, parts: Array[String]) -> void:
	if node is Label:
		parts.append(str((node as Label).text))
	for child in node.get_children():
		_collect_label_text_recursive(child, parts)


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
