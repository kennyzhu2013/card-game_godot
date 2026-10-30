extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const R20EffectEngineScript = preload("res://scripts/world/r20_effect_engine.gd")
const FieldOpportunityServiceScript = preload("res://scripts/world/field_opportunity_service.gd")
const ChantButtonFactoryScript = preload("res://scripts/world/chant_button_factory.gd")
const LootTableScript = preload("res://scripts/world/loot_table.gd")

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const CITY_SCENE := "res://scenes/world/city_scene.tscn"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_r20_field_hooks.gd --")
	test_read_truth_reveals_gated_npc_intel()
	test_identity_mask_lowers_current_suspicion_by_default_hook()
	test_premonition_reveals_hidden_district_event()
	test_real_spawn_event_card_reveals_hidden_district_opportunity()
	test_influence_behavior_rerolls_npc_daily_opportunity()
	test_chant_tooltip_names_first_pass_field_hooks()
	await test_modify_node_atmosphere_surfaces_in_city_scene()
	await test_attract_visitor_surfaces_arrived_hub_visitor()
	test_alter_drop_table_changes_real_loot_resolution()
	return {"passed": _passed, "failed": _failed}


func test_read_truth_reveals_gated_npc_intel() -> void:
	var gs = _state()
	var state = NpcKnowledgeStateScript.new()
	state.trust = 0
	gs.npc_relations["xiao_ran"] = state
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(_card("read_truth", {}, "read_truth"), "xiao_ran", {"game_state": gs, "source": "npc_dialogue"})
	assert_true(bool(result.get("ok", false)), "read_truth R20 dispatch succeeds")
	assert_eq(str(_dict(result.get("field_hook_result", {})).get("hook_type", "")), "read_truth", "read_truth returns field hook result")
	assert_true(_active_ids(gs).has("intel_xiao_ran_well_node4_001"), "read_truth grants a gated NPC intel")
	assert_true(_hook_log_has(gs, "read_truth", "xiao_ran"), "read_truth records field hook log")


func test_identity_mask_lowers_current_suspicion_by_default_hook() -> void:
	var gs = _state()
	var state = NpcKnowledgeStateScript.new()
	state.suspicion = 40
	gs.npc_relations["carl_smuggler"] = state
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(_card("identity_mask", {}, ""), "carl_smuggler", {"game_state": gs})
	assert_true(bool(result.get("ok", false)), "identity_mask dispatch succeeds")
	assert_eq(str(_dict(result.get("field_hook_result", {})).get("hook_type", "")), "identity_mask", "identity_mask returns field hook result")
	assert_true(int(state.suspicion) < 40, "identity_mask field hook lowers suspicion by default")
	assert_true(_hook_log_has(gs, "identity_mask", "carl_smuggler"), "identity_mask records field hook log")


func test_premonition_reveals_hidden_district_event() -> void:
	var gs = _state()
	gs.current_district = "misty_port"
	gs.time_of_day = "night"
	var carl = NpcKnowledgeStateScript.new()
	carl.trust = 20
	gs.npc_relations["carl_smuggler"] = carl
	FieldOpportunityServiceScript.new().refresh_daily(gs, 35005)
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(_card("premonition", {}, ""), "carl_smuggler", {"game_state": gs, "district_id": "misty_port"})
	assert_true(bool(result.get("ok", false)), "premonition dispatch succeeds")
	assert_eq(str(_dict(result.get("field_hook_result", {})).get("hook_type", "")), "premonition", "premonition returns field hook result")
	var visible: Array = FieldOpportunityServiceScript.new().visible_district_opportunities("misty_port", gs)
	assert_true(_ids(visible).has("misty_carl_manifest"), "premonition reveals a hidden Misty Port event")
	assert_true(_hook_log_has(gs, "premonition", "misty_port"), "premonition records field hook log")


func test_real_spawn_event_card_reveals_hidden_district_opportunity() -> void:
	var gs = _state()
	gs.current_district = "misty_port"
	gs.time_of_day = "night"
	var carl = NpcKnowledgeStateScript.new()
	carl.trust = 20
	gs.npc_relations["carl_smuggler"] = carl
	var service = FieldOpportunityServiceScript.new()
	service.refresh_daily(gs, 35005)
	var before: Array = service.visible_district_opportunities("misty_port", gs)
	assert_true(not _ids(before).has("misty_carl_manifest"), "real spawn_event starts with Carl lead hidden")
	var card = _skill_card("res://data/skills/fool_s9_premonition.json")
	var engine = R20EffectEngineScript.new()
	var result: Dictionary = engine.dispatch_card(card, "carl_smuggler", {"game_state": gs, "district_id": "misty_port"})
	assert_true(bool(result.get("ok", false)), "real spawn_event card dispatch succeeds")
	var field_hook: Dictionary = _dict(result.get("field_hook_result", {}))
	assert_eq(str(field_hook.get("hook_type", "")), "spawn_event", "real spawn_event returns field hook result")
	var visible: Array = service.visible_district_opportunities("misty_port", gs)
	assert_true(_ids(visible).has("misty_carl_manifest"), "real spawn_event reveals a hidden Misty Port event")
	var entry: Dictionary = _dict(field_hook.get("entry", {}))
	assert_eq(str(entry.get("revealed_by", "")), "spawn_event:premonition_flash", "real spawn_event records event source on revealed opportunity")
	var feedback := "\n".join(engine.player_feedback_lines(result))
	assert_true(feedback.contains("\u573a\u5916\u8054\u52a8") and feedback.find("misty_carl_manifest") < 0, "real spawn_event feedback is player-visible without raw opportunity id")
	assert_true(_hook_log_has(gs, "spawn_event", "misty_port"), "real spawn_event records field hook log")


func test_influence_behavior_rerolls_npc_daily_opportunity() -> void:
	var gs = _state()
	var old_li = NpcKnowledgeStateScript.new()
	old_li.trust = 45
	gs.npc_relations["old_li"] = old_li
	var service = FieldOpportunityServiceScript.new()
	service.refresh_daily(gs, 35003)
	var before: Array = service.available_npc_opportunities("old_li", gs)
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(_card("influence_behavior", {}, ""), "old_li", {"game_state": gs})
	assert_true(bool(result.get("ok", false)), "influence_behavior dispatch succeeds")
	assert_eq(str(_dict(result.get("field_hook_result", {})).get("hook_type", "")), "influence_behavior", "influence_behavior returns field hook result")
	var after: Array = service.available_npc_opportunities("old_li", gs)
	assert_true(str(before) != str(after) or _array(gs.daily_field_opportunities.get("rerolled_keys", [])).has("old_li"), "influence_behavior marks or changes NPC opportunity reroll")
	assert_true(_hook_log_has(gs, "influence_behavior", "old_li"), "influence_behavior records field hook log")


func test_chant_tooltip_names_first_pass_field_hooks() -> void:
	var gs = _state()
	gs.hub_mana = 10
	gs.hub_mana_max = 10
	var cards := [
		_card("read_truth", {}, ""),
		_card("identity_mask", {}, ""),
		_card("premonition", {}, ""),
		_card("influence_behavior", {}, ""),
	]
	var active_deck: Array[String] = []
	for card in cards:
		gs.add_card(card)
		active_deck.append(str(card.get("id")))
	gs.active_deck = active_deck
	var parent := VBoxContainer.new()
	var buttons: Array = ChantButtonFactoryScript.add_chant_buttons(parent, gs, "old_li")
	assert_eq(buttons.size(), 4, "chant factory creates buttons for the four first-pass hooks")
	var text := _collect_tooltips(buttons)
	assert_true(text.contains("\u573a\u5916") and text.contains("\u60c5\u62a5"), "read_truth tooltip names field intel hook")
	assert_true(text.contains("\u573a\u5916") and text.contains("\u6000\u7591"), "identity_mask tooltip names suspicion hook")
	assert_true(text.contains("\u573a\u5916") and text.contains("\u9690\u85cf"), "premonition tooltip names hidden event hook")
	assert_true(text.contains("\u573a\u5916") and text.contains("\u673a\u4f1a"), "influence_behavior tooltip names opportunity hook")
	assert_true(text.find("read_truth") < 0 and text.find("identity_mask") < 0 and text.find("premonition") < 0 and text.find("influence_behavior") < 0, "field hook tooltips hide raw hook ids")
	parent.queue_free()
	gs.queue_free()


func test_modify_node_atmosphere_surfaces_in_city_scene() -> void:
	var gs = _state()
	gs.current_district = "shadow_alley"
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(
		_world_card({
			"type": "modify_node_atmosphere",
			"district": "shadow_alley",
			"atmosphere": "ritual_echo",
			"duration_days": 2,
		}),
		"old_li",
		{"game_state": gs}
	)
	assert_true(bool(result.get("ok", false)), "modify_node_atmosphere dispatch succeeds")
	var world_result: Dictionary = _dict(result.get("world_result", {}))
	assert_eq(str(world_result.get("type", "")), "modify_node_atmosphere", "modify_node_atmosphere returns structured world result")
	assert_true(str(world_result.get("display_text", "")).strip_edges() != "", "modify_node_atmosphere returns player-facing result text")

	var scene = load(CITY_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "CityScene scene loads for atmosphere mount")
		gs.queue_free()
		return
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	city.open_district("shadow_alley", gs)
	await Engine.get_main_loop().process_frame
	var label = city.find_child("R20AtmosphereLabel", true, false)
	assert_true(label is Label and label.visible, "CityScene exposes a visible R20 atmosphere indicator")
	if label is Label:
		var text := str(label.text) + "\n" + str(label.tooltip_text)
		assert_true(text.contains("\u6c1b\u56f4") and text.contains("\u4eea\u5f0f"), "R20 atmosphere indicator names the changed district mood")
		assert_true(text.find("modify_node_atmosphere") < 0 and text.find("ritual_echo") < 0, "R20 atmosphere indicator hides raw effect payload ids")
	city.queue_free()
	gs.queue_free()


func test_attract_visitor_surfaces_arrived_hub_visitor() -> void:
	var previous: Dictionary = GameState.to_dict()
	if GameState.has_meta("r20_pending_visitors"):
		GameState.remove_meta("r20_pending_visitors")
	GameState.reset()
	GameState.day = 5
	GameState.sequence = 9
	GameState.hub_mana = 5
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(
		_world_card({
			"type": "attract_visitor",
			"npc_id": "old_li",
			"display_name": "\u8001\u674e",
			"delay_days": 0,
			"message": "\u4ed6\u5e26\u6765\u4e86\u5df7\u53e3\u7684\u56de\u97f3\u3002",
		}),
		"old_li",
		{"game_state": GameState}
	)
	assert_true(bool(result.get("ok", false)), "attract_visitor dispatch succeeds")
	var world_result: Dictionary = _dict(result.get("world_result", {}))
	assert_eq(str(world_result.get("type", "")), "attract_visitor", "attract_visitor returns structured world result")
	assert_true(str(world_result.get("display_text", "")).strip_edges() != "", "attract_visitor returns player-facing result text")

	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "Hub scene loads for visitor mount")
		_restore_global_state(previous)
		return
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	var button = hub.find_child("R20VisitorButton_old_li", true, false)
	assert_true(button is Button and button.visible, "Hub status bar exposes arrived R20 visitor button")
	if button is Button:
		var text := str(button.text) + "\n" + str(button.tooltip_text)
		assert_true(text.contains("\u8bbf\u5ba2") and text.contains("\u8001\u674e"), "Hub visitor button names the arrived visitor")
		assert_true(text.find("attract_visitor") < 0 and text.find("r20_pending_visitors") < 0, "Hub visitor button hides raw visitor payload ids")
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.find_child("R20VisitorDialog", true, false)
	assert_true(dialog != null and dialog.visible, "Hub visitor button opens a visible visitor dialog")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("\u5df7\u53e3"), "Hub visitor dialog displays the visitor message")
	hub.queue_free()
	_restore_global_state(previous)


func test_alter_drop_table_changes_real_loot_resolution() -> void:
	var gs = _state()
	gs.current_district = "shadow_alley"
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(
		_world_card({
			"type": "alter_drop_table",
			"district": "shadow_alley",
			"table_id": "shadow_probe",
			"bonus_material_id": "moon_dust",
			"bonus_material_amount": 2,
			"duration_days": 1,
		}),
		"old_li",
		{"game_state": gs}
	)
	assert_true(bool(result.get("ok", false)), "alter_drop_table dispatch succeeds")
	var loot: Dictionary = LootTableScript.resolve("shadow_probe", gs, 12345)
	assert_true(bool(loot.get("r20_drop_modifier_applied", false)), "LootTable.resolve consumes active R20 drop modifier")
	assert_eq(int(_dict(loot.get("materials", {})).get("moon_dust", 0)), 2, "R20 drop modifier adds deterministic bonus material to loot result")
	assert_eq(int(gs.forge_materials.get("moon_dust", 0)), 2, "R20 drop modifier writes bonus material to player inventory")
	var text := str(loot.get("drop_modifier_text", ""))
	assert_true(text.contains("\u6389\u843d") and text.find("alter_drop_table") < 0, "R20 drop modifier result text is player-facing")
	gs.queue_free()


func _card(social_type: String, social_extra: Dictionary, world_type: String):
	var social := {"type": social_type}
	for key in social_extra.keys():
		social[key] = social_extra[key]
	var world := {"type": world_type} if world_type != "" else {}
	return CardScript.from_json({
		"id": "r20_hook_probe_%s" % social_type,
		"template_id": "r20_hook_probe_%s" % social_type,
		"display_name": "R20 Hook Probe",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 1,
		"combat_effect": {"damage": 1, "target": "single"},
		"social_effect": social,
		"world_effect": world,
	})


func _world_card(world_effect: Dictionary):
	return CardScript.from_json({
		"id": "r20_world_probe_%s" % str(world_effect.get("type", "world")),
		"template_id": "r20_world_probe_%s" % str(world_effect.get("type", "world")),
		"display_name": "R20 World Probe",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 1,
		"combat_effect": {"damage": 0, "target": "self"},
		"social_effect": {},
		"world_effect": world_effect.duplicate(true),
	})


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.day = 3
	gs.sequence = 9
	gs.hub_mana = 5
	gs.current_district = "shadow_alley"
	gs.time_of_day = "night"
	return gs


func _skill_card(path: String):
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s parses as skill JSON" % path)
	if not parsed is Dictionary:
		return null
	return CardScript.from_skill_json(parsed)


func _active_ids(gs) -> Array:
	var result: Array = []
	for intel in _array(gs.active_rumors):
		if intel is Dictionary:
			result.append(str((intel as Dictionary).get("id", "")))
	return result


func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		if entry is Dictionary:
			result.append(str((entry as Dictionary).get("id", "")))
	return result


func _hook_log_has(gs, hook_type: String, target_id: String) -> bool:
	for item in _array(gs.field_hook_log):
		if not item is Dictionary:
			continue
		var entry: Dictionary = item
		if str(entry.get("hook_type", "")) == hook_type and str(entry.get("target_id", "")) == target_id:
			return true
	return false


func _collect_tooltips(buttons: Array) -> String:
	var lines: Array[String] = []
	for item in buttons:
		if item is Button:
			lines.append(str((item as Button).tooltip_text))
	return "\n".join(lines)


func _restore_global_state(previous: Dictionary) -> void:
	if GameState.has_meta("r20_pending_visitors"):
		GameState.remove_meta("r20_pending_visitors")
	GameState.from_dict(previous)


func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return value.duplicate(true) if value is Array else []


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
