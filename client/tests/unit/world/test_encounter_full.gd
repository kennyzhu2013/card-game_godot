extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const EncounterScript = preload("res://scripts/world/encounter.gd")
const EncounterPoolScript = preload("res://scripts/world/encounter_pool.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")
const EncounterTriggerScript = preload("res://scripts/world/encounter_trigger.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const EXPECTED_DISTRICTS := [
	"shadow_alley",
	"steelworks",
	"misty_port",
	"sacred_seven",
	"stone_tower",
	"ascetic_mountain",
]
const REQUIRED_CHAIN_STEPS := {
	"widow_child_chain": ["enc_widow_child_first", "enc_widow_child_resemble"],
	"reflection_chain": ["enc_reflection_first", "enc_reflection_secret"],
	"red_hand_chain": ["enc_red_hand_first", "enc_red_hand_proof_1"],
	"pendulum_chain": ["enc_pendulum_dialog_0", "enc_pendulum_dialog_1"],
}
const IRON_SHARD_PATH := "res://data/encounters/steelworks/resource_iron_shard.json"
const MOONLIGHT_GRASS_PATH := "res://data/encounters/misty_port/resource_moonlight_grass.json"

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "visible encounter ai gm text"


func run() -> Dictionary:
	print("\n-- test_encounter_full.gd --")
	test_t9_city_pool_counts_and_pollution_variants()
	test_encounter_payload_copy_is_chinese_player_facing()
	test_slice35_first_pass_risk_and_npc_lead_encounters_exist()
	await test_t9_pollution_variant_render_text()
	await test_t9_chain_step_zero_one_data_and_progression()
	await test_t9_trigger_chance_and_caps()
	await test_t9_time_segment_and_action_trigger_methods()
	await test_t9_action_complete_sampling_rate()
	await test_t9_hub_casino_action_trigger_opens_runner()
	await test_city_scene_encounter_runner_is_clickable_overlay()
	await test_encounter_runner_keeps_ai_gm_resolution_visible()
	await test_moonlight_grass_encounter_completes_active_commission()
	return {"passed": _passed, "failed": _failed}


func test_t9_city_pool_counts_and_pollution_variants() -> void:
	var pool = EncounterPoolScript.new()
	var loaded: Array = pool.load_all()
	assert_true(loaded.size() >= 44, "R27 pool loads 36 city encounters plus 8 chain step 0-1 encounters")
	var counts := {}
	for district_id in EXPECTED_DISTRICTS:
		counts[district_id] = 0
	var seen_ids := {}
	for encounter in loaded:
		var encounter_id := _field(encounter, "id")
		assert_true(encounter_id != "", "encounter has structured id")
		assert_true(not seen_ids.has(encounter_id), "encounter id is unique: %s" % encounter_id)
		seen_ids[encounter_id] = true
		if _field(encounter, "chain_id") != "":
			continue
		var districts := _array_field(encounter, "districts")
		for district_id in EXPECTED_DISTRICTS:
			if districts.has(district_id):
				counts[district_id] = int(counts.get(district_id, 0)) + 1
		if _field(encounter, "encounter_type") == "flavor" and int(_value(encounter, "weight", 0)) >= 25:
			var data := _to_dict(encounter)
			var variants = data.get("pollution_variant", {})
			assert_true(variants is Dictionary and (variants as Dictionary).size() >= 4, "high-frequency flavor %s has pollution_variant stages 0-3" % encounter_id)
	for district_id in EXPECTED_DISTRICTS:
		var count := int(counts.get(district_id, 0))
		assert_true(count >= 5 and count <= 10, "%s has 5-10 non-chain city encounters after Slice 3.5 extension, got %d" % [district_id, count])


func test_encounter_payload_copy_is_chinese_player_facing() -> void:
	var pool = EncounterPoolScript.new()
	var loaded: Array = pool.load_all()
	assert_true(loaded.size() > 0, "encounter data loads for player-facing copy audit")
	for encounter in loaded:
		var data := _to_dict(encounter)
		var encounter_id := str(data.get("id", "unknown"))
		assert_true(_has_cjk(str(data.get("display_name", ""))), "%s display_name is Chinese player-facing text" % encounter_id)
		var payload: Variant = data.get("scene_payload", {})
		if payload is Dictionary:
			var text := str((payload as Dictionary).get("text", ""))
			if text != "":
				assert_true(_has_cjk(text), "%s scene text is Chinese player-facing text" % encounter_id)
			var choices: Variant = (payload as Dictionary).get("choices", [])
			if choices is Array:
				for choice in choices:
					if choice is Dictionary:
						var label := str((choice as Dictionary).get("label", ""))
						assert_true(_has_cjk(label), "%s choice %s label is Chinese player-facing text" % [encounter_id, str((choice as Dictionary).get("id", ""))])
		var variants: Variant = data.get("pollution_variant", {})
		if variants is Dictionary:
			for key in (variants as Dictionary).keys():
				var variant: Variant = (variants as Dictionary).get(key, {})
				if variant is Dictionary and (variant as Dictionary).has("text"):
					assert_true(_has_cjk(str((variant as Dictionary).get("text", ""))), "%s pollution variant %s text is Chinese player-facing text" % [encounter_id, str(key)])


func test_slice35_first_pass_risk_and_npc_lead_encounters_exist() -> void:
	var pool = EncounterPoolScript.new()
	pool.load_all()
	assert_true(pool.has_method("encounter_by_id"), "EncounterPool exposes encounter_by_id")
	if not pool.has_method("encounter_by_id"):
		return
	for id in ["enc_shadow_alley_church_tail", "enc_misty_port_carl_manifest", "enc_misty_port_smuggler_check"]:
		var encounter = pool.encounter_by_id(id)
		assert_true(encounter != null, "Slice 3.5 encounter exists: %s" % id)
		if encounter != null:
			assert_true(_has_cjk(str(_value(encounter, "display_name", ""))), "%s has Chinese display name" % id)


func test_t9_pollution_variant_render_text() -> void:
	var encounter = EncounterScript.new().from_dict({
		"id": "enc_variant_probe",
		"encounter_type": "flavor",
		"display_name": "Variant Probe",
		"districts": ["shadow_alley"],
		"time_of_day": ["night"],
		"weight": 30,
		"step_count": 1,
		"scene_payload": {
			"text": "stage 0",
			"choices": [{"id": "leave", "label": "leave", "outcome": {}}],
		},
		"pollution_variant": {
			"0": {"text": "stage 0"},
			"1": {"text": "stage 1"},
			"2": {"text": "stage 2"},
			"3": {"text": "stage 3"},
		},
	})
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	assert_true(runner.has_method("render_text"), "EncounterRunner exposes render_text(encounter, game_state)")
	if runner.has_method("render_text"):
		var gs = _state()
		gs.pollution_stage = 2
		assert_eq(str(runner.call("render_text", encounter, gs)), "stage 2", "render_text selects pollution stage 2 variant")
	runner.queue_free()


func test_t9_chain_step_zero_one_data_and_progression() -> void:
	var pool = EncounterPoolScript.new()
	var loaded: Array = pool.load_all()
	var by_id := {}
	for encounter in loaded:
		by_id[_field(encounter, "id")] = encounter
	for chain_id in REQUIRED_CHAIN_STEPS.keys():
		for encounter_id in REQUIRED_CHAIN_STEPS[chain_id]:
			assert_true(by_id.has(encounter_id), "%s data exists for %s" % [encounter_id, chain_id])
	var step0 = by_id.get("enc_widow_child_first", null)
	var step1 = by_id.get("enc_widow_child_resemble", null)
	if step0 == null or step1 == null:
		return
	var gs = _state()
	gs.day = 4
	gs.ap = 12
	gs.current_district = "shadow_alley"
	gs.time_of_day = "evening"
	gs.daodian["completed_main_story_nodes"] = ["node_2"]
	var ctx := {"district_id": "shadow_alley", "time_of_day": "evening", "game_state": gs}
	assert_eq(_ids(pool.filter_candidates([step0, step1], ctx)), ["enc_widow_child_first"], "chain filter exposes step 0 before progression")
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	runner.start(step0, gs)
	await Engine.get_main_loop().process_frame
	runner.resolve_choice("approach")
	await Engine.get_main_loop().process_frame
	var chain = gs.encounter_chains.get("widow_child_chain", null)
	assert_true(chain != null, "resolving chain encounter creates chain state")
	if chain != null:
		assert_eq(int(chain.get("current_step")), 1, "resolving step 0 advances current_step to 1")
		var history: Array = chain.get("steps_history")
		assert_true(history.size() == 1, "chain state records one history entry")
		if history.size() > 0 and history[0] is Dictionary:
			assert_eq(str((history[0] as Dictionary).get("choice_id", "")), "approach", "chain history records chosen choice id")
	assert_eq(_ids(pool.filter_candidates([step0, step1], ctx)), ["enc_widow_child_resemble"], "chain filter exposes step 1 after progression")
	runner.queue_free()


func test_t9_trigger_chance_and_caps() -> void:
	var trigger = EncounterTriggerScript.new()
	Engine.get_main_loop().root.add_child(trigger)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	gs.day = 3
	gs.pollution_stage = 2
	gs.current_district = "shadow_alley"
	gs.time_of_day = "evening"
	trigger.configure(gs, {"district_id": "shadow_alley", "encounter_pool_id": "city_roaming"})
	assert_float_eq(float(trigger.calc_trigger_chance()), 0.40, "trigger chance applies base + pollution + mainline day")
	gs.last_encounter_today = {"global": 2, "districts": {"shadow_alley": 2}}
	assert_float_eq(float(trigger.calc_trigger_chance()), 0.35, "trigger chance applies repeated-district dampening")
	gs.last_encounter_today = {"global": 8, "districts": {"shadow_alley": 0}}
	assert_eq(str(trigger.try_trigger(0.0, 0.0).get("reason", "")), "daily_global_cap", "global daily cap 8 blocks trigger")
	gs.last_encounter_today = {"global": 3, "districts": {"shadow_alley": 4}}
	assert_eq(str(trigger.try_trigger(0.0, 0.0).get("reason", "")), "daily_district_cap", "district daily cap 4 blocks trigger")
	trigger.queue_free()


func test_t9_time_segment_and_action_trigger_methods() -> void:
	var trigger = EncounterTriggerScript.new()
	Engine.get_main_loop().root.add_child(trigger)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	gs.day = 3
	gs.ap = 12
	gs.current_district = "shadow_alley"
	gs.time_of_day = "morning"
	trigger.configure(gs, {"district_id": "shadow_alley", "encounter_pool_id": "city_roaming"})
	var has_time := trigger.has_method("try_time_segment_spawn")
	var has_action := trigger.has_method("on_action_complete")
	assert_true(has_time, "EncounterTrigger exposes time-segment 5% spawn API")
	assert_true(has_action, "EncounterTrigger exposes on_action_complete(source, district_id) 5% API")
	if not has_time or not has_action:
		trigger.queue_free()
		return
	var time_result: Dictionary = trigger.call("try_time_segment_spawn", 0.0, 0.0)
	assert_true(bool(time_result.get("triggered", false)), "time-segment roll 0 triggers a current-district encounter")
	assert_eq(str(time_result.get("trigger_source", "")), "time_segment", "time segment trigger result records source")
	gs.last_encounter_today = {"global": 0, "districts": {}}
	var action_result: Dictionary = trigger.call("on_action_complete", "errand", "shadow_alley", 0.0, 0.0)
	assert_true(bool(action_result.get("triggered", false)), "errand action-complete roll 0 triggers encounter")
	assert_eq(str(action_result.get("trigger_source", "")), "errand", "action trigger result records source")
	trigger.queue_free()


func test_t9_action_complete_sampling_rate() -> void:
	var errand_rate := await _action_rate("errand", "shadow_alley")
	assert_true(errand_rate >= 0.04 and errand_rate <= 0.06, "errand completion action trigger rate stays near 5%%, got %.3f" % errand_rate)
	var casino_rate := await _action_rate("casino_leave", "misty_port")
	assert_true(casino_rate >= 0.04 and casino_rate <= 0.06, "casino leave action trigger rate stays near 5%%, got %.3f" % casino_rate)


func test_t9_hub_casino_action_trigger_opens_runner() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_hub_action_state()
	GameState.set_meta("encounter_action_roll", 0.0)
	GameState.set_meta("encounter_action_pool_roll", 0.0)
	var hub = await _hub()
	if hub == null:
		_restore_global_state(previous)
		return
	hub.call("open_city_for_debug", "misty_port", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var hotspot = city.find_child("Hotspot_casino_eel_fan", true, false) if city != null else null
	assert_true(hotspot is Button, "Hub -> CityScene exposes casino hotspot for action trigger path")
	if hotspot is Button:
		hotspot.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("CasinoMenuDialog")
	var play_button = dialog.find_child("CasinoButton_dice_cup", true, false) if dialog != null else null
	assert_true(play_button is Button, "casino action path exposes dice play button")
	if play_button is Button:
		play_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var runner = city.find_child("EncounterRunner", true, false) if city != null else null
	assert_true(runner != null and runner.visible, "casino action trigger opens EncounterRunner from Hub city path")
	hub.queue_free()
	_restore_global_state(previous)


func test_city_scene_encounter_runner_is_clickable_overlay() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 3
	gs.ap = 12
	gs.current_district = "steelworks"
	gs.time_of_day = "night"
	gs.lingstones = 10
	city.open_from_data(_district_with_pool("steelworks"), gs)
	await Engine.get_main_loop().process_frame
	var runner = city.find_child("EncounterRunner", true, false)
	assert_true(runner != null, "CityScene exposes EncounterRunner overlay")
	if runner == null:
		city.queue_free()
		return
	var encounter = EncounterScript.new().from_dict(_load_json(IRON_SHARD_PATH))
	runner.start(encounter, gs)
	await Engine.get_main_loop().process_frame
	assert_true(runner.visible, "steelworks resource encounter opens runner")
	var ui_layer = city.get_node_or_null("UILayer")
	assert_true(ui_layer != null and ui_layer.get_child(ui_layer.get_child_count() - 1) == runner, "EncounterRunner is above CityScene controls so choices can receive clicks")
	var visible_text := _collect_label_text(runner)
	assert_true(_has_cjk(visible_text), "steelworks resource encounter renders Chinese copy")
	assert_true(not visible_text.contains("A chipped iron shard") and not visible_text.contains("Pocket it") and not visible_text.contains("Ignore it"), "steelworks resource encounter hides English source copy")
	var choice = runner.find_child("EncounterChoice_take", true, false)
	assert_true(choice is Button and not (choice as Button).disabled, "steelworks resource encounter renders an enabled take button")
	if choice is Button:
		(choice as Button).pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(int(gs.lingstones), 11, "clicking steelworks resource choice applies outcome")
	assert_true(not runner.visible, "clicking steelworks resource choice closes runner")
	city.queue_free()


func test_encounter_runner_keeps_ai_gm_resolution_visible() -> void:
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	assert_true(runner.has_method("set_ai_gm_service"), "EncounterRunner can receive an injected AI GM service")
	var fake := FakeAIGMService.new()
	if runner.has_method("set_ai_gm_service"):
		runner.call("set_ai_gm_service", fake)
	var gs = _state()
	gs.day = 7
	gs.ap = 12
	gs.current_district = "shadow_alley"
	gs.time_of_day = "night"
	gs.pollution_stage = 3
	var encounter = EncounterScript.new().from_dict({
		"id": "enc_visible_ai_probe",
		"encounter_type": "mystery_seed",
		"display_name": "Visible AI Probe",
		"districts": ["shadow_alley"],
		"time_of_day": ["night"],
		"scene_payload": {
			"text": "A shadow waits.",
			"choices": [
				{"id": "approach", "label": "Approach", "outcome": {"ai_gm": {"scene": "encounter_resolve", "tone": "haunting"}}},
			],
		},
	})
	runner.start(encounter, gs)
	await Engine.get_main_loop().process_frame
	var choice = runner.find_child("EncounterChoice_approach", true, false)
	assert_true(choice is Button, "AI GM encounter renders a choice")
	if choice is Button:
		(choice as Button).pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(fake.calls.size(), 1, "AI GM encounter resolve calls injected service once")
	assert_true(runner.visible, "AI GM encounter resolution remains visible instead of disappearing")
	var visible_text := _collect_label_text(runner)
	assert_true(visible_text.contains("visible encounter ai gm text"), "AI GM encounter resolution shows the generated narration")
	var close_button = runner.find_child("EncounterCloseButton", true, false)
	assert_true(close_button is Button, "AI GM encounter resolution exposes a close button")
	if close_button is Button:
		(close_button as Button).pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_true(not runner.visible, "closing the AI GM encounter resolution hides the runner")
	runner.queue_free()


func test_moonlight_grass_encounter_completes_active_commission() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 3
	gs.sequence = 9
	gs.ap = 12
	gs.current_district = "misty_port"
	gs.time_of_day = "night"
	gs.available_commissions.clear()
	gs.accepted_commissions.clear()
	gs.completed_commissions.clear()
	for key in ["commission_active_dispatch", "commission_pending_completion", "commission_pending_includes_tower"]:
		if gs.has_method("remove_meta") and gs.has_meta(key):
			gs.remove_meta(key)
	var service = CommissionServiceScript.new()
	assert_true(bool(service.accept(gs, "commission_moonlight_grass_001").get("ok", false)), "moonlight grass commission accepts")
	var execute: Dictionary = service.execute(gs, "commission_moonlight_grass_001")
	assert_true(bool(execute.get("ok", false)), "moonlight grass commission executes")
	assert_eq(str(execute.get("dispatch_kind", "")), "encounter", "moonlight grass dispatch points at encounter path")
	city.open_from_data(_district_with_pool("misty_port"), gs)
	await Engine.get_main_loop().process_frame
	var runner = city.find_child("EncounterRunner", true, false)
	assert_true(runner != null, "CityScene exposes EncounterRunner for moonlight grass")
	var encounter = EncounterScript.new().from_dict(_load_json(MOONLIGHT_GRASS_PATH))
	if runner != null:
		runner.start(encounter, gs)
		await Engine.get_main_loop().process_frame
		var choice = runner.find_child("EncounterChoice_gather", true, false)
		assert_true(choice is Button, "moonlight grass encounter exposes gather choice")
		if choice is Button:
			(choice as Button).pressed.emit()
			await Engine.get_main_loop().process_frame
	assert_eq(str(service.status_for(gs, "commission_moonlight_grass_001")), "completed", "moonlight grass encounter loot completes commission")
	assert_true(not gs.has_meta("commission_active_dispatch"), "completed moonlight grass commission clears active dispatch")
	var claim: Dictionary = service.claim(gs, "commission_moonlight_grass_001")
	assert_true(bool(claim.get("ok", false)), "completed moonlight grass commission can be claimed")
	city.queue_free()


func _action_rate(source: String, district_id: String) -> float:
	var trigger = EncounterTriggerScript.new()
	Engine.get_main_loop().root.add_child(trigger)
	await Engine.get_main_loop().process_frame
	var gs = _state()
	gs.day = 3
	gs.ap = 12
	gs.current_district = district_id
	gs.time_of_day = "morning"
	trigger.configure(gs, {"district_id": district_id, "encounter_pool_id": "city_roaming"})
	var triggered := 0
	for i in range(1000):
		gs.last_encounter_today = {"global": 0, "districts": {}}
		var roll := float(i) / 1000.0
		var result: Dictionary = trigger.call("on_action_complete", source, district_id, roll, 0.0)
		if bool(result.get("triggered", false)):
			triggered += 1
	trigger.queue_free()
	return float(triggered) / 1000.0


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _hub() -> Control:
	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _city() -> Control:
	var scene = load("res://scenes/world/city_scene.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "city_scene.tscn loads")
		return null
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	return city


func _setup_hub_action_state() -> void:
	GameState.day = 6
	GameState.time_of_day = "night"
	GameState.sequence = 9
	GameState.ap = 12
	GameState.lingstones = 1000
	GameState.current_district = "misty_port"
	GameState.last_encounter_today = {"global": 0, "districts": {}}


func _restore_global_state(previous: Dictionary) -> void:
	for key in ["encounter_action_roll", "encounter_action_pool_roll"]:
		if GameState.has_meta(key):
			GameState.remove_meta(key)
	GameState.from_dict(previous)


func _district_with_pool(district_id: String) -> Dictionary:
	return {
		"$schema": "city_hotspot_v1",
		"district_id": district_id,
		"display_name": district_id,
		"encounter_pool_id": "city_roaming",
		"hotspots": [
			{"id": "tower_entry_%s" % district_id, "label": "Tower", "icon": "T", "type": "tower", "ap_cost": 2, "visible_when": "always"},
		],
	}


func _field(value, field_name: String) -> String:
	var raw = _value(value, field_name, "")
	return str(raw)


func _value(value, field_name: String, fallback: Variant = null) -> Variant:
	if value == null:
		return fallback
	if value is Dictionary:
		return value.get(field_name, fallback)
	var raw = value.get(field_name)
	return fallback if raw == null else raw


func _array_field(value, field_name: String) -> Array:
	var raw = _value(value, field_name, [])
	if raw is Array:
		return raw
	return []


func _to_dict(value) -> Dictionary:
	if value != null and value.has_method("to_dict"):
		return value.to_dict()
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		assert_true(false, "%s exists" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s parses as JSON object" % path)
	if parsed is Dictionary:
		return parsed.duplicate(true)
	return {}


func _ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_field(value, "id"))
	return result


func _collect_label_text(node) -> String:
	if node == null:
		return ""
	var text := ""
	if node is Label:
		text += str(node.text) + "\n"
	if node is Button:
		text += str(node.text) + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


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


func assert_float_eq(actual: float, expected: float, message: String) -> void:
	if is_equal_approx(actual, expected):
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
