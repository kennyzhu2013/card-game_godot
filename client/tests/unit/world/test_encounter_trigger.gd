extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const SleepServiceScript = preload("res://scripts/world/sleep_service.gd")

const ENCOUNTER_PATH := "res://scripts/world/encounter.gd"
const CHAIN_STATE_PATH := "res://scripts/world/encounter_chain_state.gd"
const POOL_PATH := "res://scripts/world/encounter_pool.gd"
const RUNNER_PATH := "res://scripts/world/encounter_runner.gd"
const CAT_PATH := "res://data/encounters/shadow_alley/flavor_cat.json"
const SEABREEZE_PATH := "res://data/encounters/misty_port/flavor_seabreeze.json"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_encounter_trigger.gd --")
	test_encounter_and_chain_state_roundtrip()
	test_encounter_pool_filters_and_picks_flavor_data()
	await test_encounter_runner_renders_static_payload_and_applies_choice()
	await test_city_scene_encounter_trigger_countdown_and_daily_caps()
	test_sleep_resets_daily_encounter_counts()
	return {"passed": _passed, "failed": _failed}


func test_encounter_and_chain_state_roundtrip() -> void:
	var encounter_script = _script(ENCOUNTER_PATH, "Encounter script loads")
	var chain_script = _script(CHAIN_STATE_PATH, "EncounterChainState script loads")
	if encounter_script == null or chain_script == null:
		return
	var encounter = encounter_script.new()
	assert_true(encounter.has_method("from_dict"), "Encounter exposes from_dict")
	assert_true(encounter.has_method("to_dict"), "Encounter exposes to_dict")
	if not encounter.has_method("from_dict") or not encounter.has_method("to_dict"):
		return
	encounter.from_dict(_cat_data())
	var roundtrip: Dictionary = encounter.to_dict()
	assert_eq(str(roundtrip.get("id", "")), "enc_alley_cat", "Encounter roundtrips id")
	assert_eq(str(roundtrip.get("encounter_type", "")), "flavor", "Encounter roundtrips structured type")
	assert_eq(str(roundtrip.get("districts", [])[0]), "shadow_alley", "Encounter roundtrips districts")
	assert_eq(int(roundtrip.get("weight", 0)), 30, "Encounter roundtrips weight")
	assert_true(roundtrip.get("scene_payload", {}) is Dictionary, "Encounter roundtrips static scene payload")

	var chain = chain_script.new()
	assert_true(chain.has_method("from_dict"), "EncounterChainState exposes from_dict")
	assert_true(chain.has_method("to_dict"), "EncounterChainState exposes to_dict")
	if not chain.has_method("from_dict") or not chain.has_method("to_dict"):
		return
	chain.from_dict({
		"chain_id": "widow_child_chain",
		"current_step": 2,
		"steps_history": [{"step": 1, "encounter_id": "enc_widow_child_resemble", "choice_id": "approach", "day": 4}],
		"locked": false,
	})
	var chain_rt: Dictionary = chain.to_dict()
	assert_eq(str(chain_rt.get("chain_id", "")), "widow_child_chain", "chain state roundtrips id")
	assert_eq(int(chain_rt.get("current_step", 0)), 2, "chain state roundtrips current step")
	assert_eq((chain_rt.get("steps_history", []) as Array).size(), 1, "chain state roundtrips history")

	var gs = _state()
	assert_true(_has_property(gs, "encounter_chains"), "GameState exposes encounter_chains")
	if not _has_property(gs, "encounter_chains"):
		return
	gs.set("encounter_chains", {"widow_child_chain": chain})
	var restored = _state()
	restored.from_dict(gs.to_dict())
	var restored_chains = restored.get("encounter_chains")
	assert_true(restored_chains is Dictionary, "GameState encounter_chains serializes as dictionary")
	if restored_chains is Dictionary:
		var restored_chain = restored_chains.get("widow_child_chain")
		assert_true(restored_chain != null and restored_chain.has_method("to_dict"), "GameState restores EncounterChainState objects")
		if restored_chain != null and restored_chain.has_method("to_dict"):
			assert_eq(int(restored_chain.to_dict().get("current_step", 0)), 2, "restored chain keeps current_step")


func test_encounter_pool_filters_and_picks_flavor_data() -> void:
	var pool_script = _script(POOL_PATH, "EncounterPool script loads")
	var encounter_script = _script(ENCOUNTER_PATH, "Encounter script loads for pool test")
	if pool_script == null or encounter_script == null:
		return
	var pool = pool_script.new()
	assert_true(pool.has_method("load_all"), "EncounterPool exposes load_all")
	assert_true(pool.has_method("pick"), "EncounterPool exposes pick")
	assert_true(pool.has_method("filter_candidates"), "EncounterPool exposes filter_candidates")
	if not pool.has_method("load_all") or not pool.has_method("pick") or not pool.has_method("filter_candidates"):
		return
	var loaded: Array = pool.load_all()
	assert_true(loaded.size() >= 2, "EncounterPool loads at least two Slice 2.5 encounter files")
	var gs = _state()
	gs.day = 3
	gs.time_of_day = "evening"
	gs.pollution = 0
	gs.current_district = "shadow_alley"
	var cat = pool.pick("city_roaming", {"district_id": "shadow_alley", "time_of_day": "evening", "game_state": gs}, 0.0)
	assert_eq(_field(cat, "id"), "enc_alley_cat", "shadow alley evening pick returns cat flavor encounter")
	var cat_only = encounter_script.new()
	cat_only.from_dict(_cat_data())
	var morning_cat_candidates: Array = pool.filter_candidates([cat_only], {"district_id": "shadow_alley", "time_of_day": "morning", "game_state": gs})
	assert_eq(_ids(morning_cat_candidates), [], "cat flavor encounter is filtered outside evening/night")
	gs.current_district = "misty_port"
	gs.time_of_day = "noon"
	var breeze = pool.pick("city_roaming", {"district_id": "misty_port", "time_of_day": "noon", "game_state": gs}, 0.0)
	assert_eq(_field(breeze, "id"), "enc_misty_port_seabreeze", "misty port noon pick returns seabreeze flavor encounter")

	var low = encounter_script.new()
	low.from_dict({"id": "enc_low", "encounter_type": "flavor", "districts": ["shadow_alley"], "time_of_day": ["evening"], "weight": 1})
	var high = encounter_script.new()
	high.from_dict({"id": "enc_high_pollution", "encounter_type": "horror", "districts": ["shadow_alley"], "time_of_day": ["evening"], "weight": 1, "preconditions": ["pollution >= 50"]})
	gs.current_district = "shadow_alley"
	gs.time_of_day = "evening"
	gs.pollution = 10
	var filtered: Array = pool.filter_candidates([low, high], {"district_id": "shadow_alley", "time_of_day": "evening", "game_state": gs})
	assert_eq(_ids(filtered), ["enc_low"], "EncounterPool filters preconditions with structured fields")


func test_encounter_runner_renders_static_payload_and_applies_choice() -> void:
	var runner_script = _script(RUNNER_PATH, "EncounterRunner script loads")
	var encounter = _encounter_from_dict(_cat_data())
	if runner_script == null or encounter == null:
		return
	var runner = runner_script.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	assert_true(runner.has_method("start"), "EncounterRunner exposes start")
	if not runner.has_method("start"):
		runner.queue_free()
		return
	var gs = _state()
	gs.lingstones = 10
	runner.start(encounter, gs)
	await Engine.get_main_loop().process_frame
	assert_true(runner.visible, "EncounterRunner shows static encounter card")
	var runner_text := _collect_label_text(runner)
	assert_true(_has_cjk(runner_text), "EncounterRunner renders Chinese player-facing text")
	assert_true(not runner_text.contains("thin alley cat") and not runner_text.contains("Pocket it") and not runner_text.contains("Ignore it"), "EncounterRunner hides English source copy")
	var choice = runner.find_child("EncounterChoice_give_food", true, false)
	assert_true(choice is Button, "EncounterRunner renders structured choice button")
	if choice is Button:
		choice.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(int(gs.lingstones), 9, "EncounterRunner applies lingstones_delta outcome")
	assert_true(not runner.visible, "EncounterRunner hides after resolving static choice")
	runner.queue_free()


func test_city_scene_encounter_trigger_countdown_and_daily_caps() -> void:
	var city = await _city()
	if city == null:
		return
	var gs = _state()
	gs.day = 3
	gs.current_district = "shadow_alley"
	gs.time_of_day = "evening"
	gs.lingstones = 10
	city.open_from_data(_district_with_pool("shadow_alley"), gs)
	await Engine.get_main_loop().process_frame
	var trigger = city.find_child("EncounterTrigger", true, false)
	assert_true(trigger != null, "CityScene has EncounterTrigger node")
	if trigger == null:
		city.queue_free()
		return
	assert_true(trigger.has_method("process_roaming_delta"), "EncounterTrigger exposes process_roaming_delta")
	assert_true(trigger.has_method("try_trigger"), "EncounterTrigger exposes try_trigger")
	var interval = trigger.get("base_check_interval_sec")
	assert_eq(float(interval if interval != null else -1.0), 30.0, "EncounterTrigger interval is 30 seconds")
	if not trigger.has_method("process_roaming_delta") or not trigger.has_method("try_trigger"):
		city.queue_free()
		return
	var early: Dictionary = trigger.process_roaming_delta(29.0, 0.0, 0.0)
	assert_true(not bool(early.get("triggered", true)), "29 seconds of roaming does not trigger encounter")
	var triggered: Dictionary = trigger.process_roaming_delta(1.0, 0.0, 0.0)
	assert_true(bool(triggered.get("triggered", false)), "30 seconds of roaming checks and triggers encounter at roll 0")
	assert_eq(_daily_global(gs), 1, "trigger records global daily encounter count")
	assert_eq(_daily_district(gs, "shadow_alley"), 1, "trigger records district daily encounter count")
	var runner = city.find_child("EncounterRunner", true, false)
	assert_true(runner != null and runner.visible, "CityScene opens EncounterRunner from roaming trigger")

	gs.set("last_encounter_today", {"global": 8, "districts": {"shadow_alley": 0}})
	var capped_global: Dictionary = trigger.try_trigger(0.0, 0.0)
	assert_eq(str(capped_global.get("reason", "")), "daily_global_cap", "global daily cap blocks encounter trigger")
	gs.set("last_encounter_today", {"global": 3, "districts": {"shadow_alley": 4}})
	var capped_district: Dictionary = trigger.try_trigger(0.0, 0.0)
	assert_eq(str(capped_district.get("reason", "")), "daily_district_cap", "district daily cap blocks encounter trigger")
	city.queue_free()


func test_sleep_resets_daily_encounter_counts() -> void:
	var gs = _state()
	assert_true(_has_property(gs, "last_encounter_today"), "GameState exposes last_encounter_today")
	if not _has_property(gs, "last_encounter_today"):
		return
	gs.set("last_encounter_today", {"global": 7, "districts": {"shadow_alley": 4, "misty_port": 2}})
	var result: Dictionary = SleepServiceScript.sleep_to_next_day(gs, 1, "user://slice2_5_t8_sleep_reset.save", 0.0)
	assert_true(bool(result.get("ok", false)), "sleep_to_next_day returns ok while resetting encounter counts")
	assert_eq(_daily_global(gs), 0, "sleep resets global daily encounter count")
	assert_eq(_daily_district(gs, "shadow_alley"), 0, "sleep resets district encounter count")


func _script(path: String, message: String):
	if not FileAccess.file_exists(path):
		assert_true(false, message)
		return null
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, message)
		return null
	assert_true(true, message)
	return script


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _city() -> Control:
	var scene = load("res://scenes/world/city_scene.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "city_scene.tscn loads")
		return null
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	return city


func _cat_data() -> Dictionary:
	return _load_json(CAT_PATH)


func _encounter_from_dict(data: Dictionary):
	var script = _script(ENCOUNTER_PATH, "Encounter script loads for static runner")
	if script == null:
		return null
	var encounter = script.new()
	if not encounter.has_method("from_dict"):
		assert_true(false, "Encounter exposes from_dict for static runner")
		return null
	encounter.from_dict(data)
	return encounter


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		assert_true(false, "%s exists" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s parses as JSON object" % path)
	if parsed is Dictionary:
		return parsed.duplicate(true)
	return {}


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
	if value == null:
		return ""
	var raw = value.get(field_name)
	return str(raw)


func _ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_field(value, "id"))
	return result


func _daily_global(game_state) -> int:
	var counts = game_state.get("last_encounter_today")
	if counts is Dictionary:
		return int(counts.get("global", 0))
	return -1


func _daily_district(game_state, district_id: String) -> int:
	var counts = game_state.get("last_encounter_today")
	if not counts is Dictionary:
		return -1
	var districts = counts.get("districts", {})
	if districts is Dictionary:
		return int(districts.get(district_id, 0))
	return -1


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


func _has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false
	for entry in obj.get_property_list():
		if str(entry.get("name", "")) == property_name:
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
