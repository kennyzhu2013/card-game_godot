extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")

const NPC_LIBRARY_PATH := "res://scripts/world/npc_library.gd"
const NPC_SERVICE_PATH := "res://scripts/world/npc_interaction_service.gd"
const HUB_SCENE := "res://scenes/hub/hub.tscn"

const VALID_TIMES := ["morning", "noon", "evening", "night"]

var _passed := 0
var _failed := 0


class FakeDialogicAdapter:
	var started_timelines: Array[String] = []
	var variables: Dictionary = {}

	func start(timeline_id: String) -> void:
		started_timelines.append(timeline_id)

	func set_variable(variable_name: String, value: Variant) -> void:
		variables[variable_name] = value


func run_contract(spec: Dictionary) -> Dictionary:
	test_definition_contract(spec)
	test_timeline_contract(spec)
	test_open_dialogue_contract(spec)
	test_relation_threshold_crossing(spec)
	test_available_intels_filter_by_trust(spec)
	if bool(spec.get("brendan_awareness", false)):
		test_brendan_church_awareness_threshold(spec)
	await test_hub_direct_npc_hotspot_opens_dialogue(spec)
	if spec.has("city_path") and spec["city_path"] is Dictionary:
		await test_city_path_hotspot_opens_dialogue(spec)
	return {"passed": _passed, "failed": _failed}


func test_definition_contract(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var npc := _npc_def(npc_id)
	assert_true(not npc.is_empty(), "%s definition loads" % npc_id)
	if npc.is_empty():
		return
	assert_true(not bool(npc.get("placeholder", false)), "%s is no longer a placeholder" % npc_id)
	assert_eq(str(npc.get("dialogue_tree", "")), str(spec.get("timeline", "")), "%s dialogue_tree matches timeline" % npc_id)
	assert_true(str(npc.get("display_name", "")) != "", "%s has display_name" % npc_id)
	assert_true(npc.get("public", {}) is Dictionary, "%s has public layer" % npc_id)
	assert_true(npc.get("hidden", {}) is Dictionary, "%s has hidden layer" % npc_id)
	assert_true(npc.get("truth", {}) is Dictionary, "%s has truth layer" % npc_id)
	_assert_relation_thresholds(npc, npc_id)
	_assert_city_presence(npc, spec)
	_assert_available_intels(npc, npc_id)
	_assert_commission_pool(npc, npc_id)


func test_timeline_contract(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var timeline := str(spec.get("timeline", ""))
	var timeline_id := "npc/%s" % timeline
	var timeline_path := "res://dialogic/npc/%s.dtl" % timeline
	assert_true(FileAccess.file_exists(timeline_path), "%s Dialogic timeline exists" % npc_id)
	assert_eq(_registered_timeline_path(timeline_id), timeline_path, "%s Dialogic timeline is registered" % npc_id)
	if not FileAccess.file_exists(timeline_path):
		return
	var content := FileAccess.get_file_as_string(timeline_path)
	for branch_id in spec.get("branches", []):
		assert_true(content.find("branch:%s" % str(branch_id)) >= 0, "%s timeline has branch:%s" % [npc_id, str(branch_id)])
	assert_true(content.find("npc_first_meet") >= 0, "%s timeline marks npc_first_meet" % npc_id)
	var npc := _npc_def(npc_id)
	var first_intel_id := _first_intel_id(npc)
	if first_intel_id != "":
		assert_true(content.find("grant_intel:%s" % first_intel_id) >= 0, "%s timeline links first available intel" % npc_id)
	var commission_pool := str(npc.get("commission_pool", ""))
	if commission_pool != "":
		assert_true(content.find("commission_pool:%s" % commission_pool) >= 0, "%s timeline links commission_pool" % npc_id)


func test_open_dialogue_contract(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = int(spec.get("day", 6))
	gs.sequence = int(spec.get("sequence", 9))
	gs.time_of_day = str(spec.get("time_of_day", "morning"))
	gs.ap = 10
	var adapter := FakeDialogicAdapter.new()
	var result: Dictionary = service.open_dialogue(npc_id, gs, adapter)
	var expected_timeline := "npc/%s" % str(spec.get("timeline", ""))
	assert_true(bool(result.get("ok", false)), "%s open_dialogue succeeds" % npc_id)
	assert_eq(str(result.get("timeline_id", "")), expected_timeline, "%s open_dialogue returns timeline" % npc_id)
	assert_eq(adapter.started_timelines, [expected_timeline], "%s Dialogic adapter starts timeline" % npc_id)
	assert_eq(adapter.variables.get("npc_dialog_count", -1), 0, "%s binds npc_dialog_count variable" % npc_id)
	gs.queue_free()


func test_relation_threshold_crossing(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	var gs = _fresh_state()
	gs.ap = 10
	var state = NpcKnowledgeStateScript.new()
	state.trust = 29
	gs.npc_relations[npc_id] = state
	var result: Dictionary = service.commit_dialogue_outcome(npc_id, {"trust_delta": 1, "dialogue_rounds": 1}, gs)
	assert_true(bool(result.get("ok", false)), "%s commit_dialogue_outcome succeeds" % npc_id)
	assert_true(result.get("triggered_thresholds", []).has("acquainted"), "%s crossing trust 30 triggers acquainted" % npc_id)
	assert_eq(state.dialog_count, 1, "%s commit increments dialog count" % npc_id)
	gs.queue_free()


func test_available_intels_filter_by_trust(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var npc := _npc_def(npc_id)
	var intels: Array = _array(npc.get("available_intels", []))
	if intels.is_empty():
		assert_true(false, "%s has at least one available intel for trust filtering" % npc_id)
		return
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	assert_true(service.has_method("available_intels_for_npc"), "NpcInteractionService exposes available_intels_for_npc for %s" % npc_id)
	if not service.has_method("available_intels_for_npc"):
		return
	var first: Dictionary = intels[0] if intels[0] is Dictionary else {}
	var intel_id := str(first.get("intel_id", ""))
	var required_trust := int(first.get("trust", 0))
	var gs = _fresh_state()
	var state = NpcKnowledgeStateScript.new()
	state.trust = max(0, required_trust - 1)
	gs.npc_relations[npc_id] = state
	var locked: Array = service.call("available_intels_for_npc", npc_id, gs)
	if required_trust > 0:
		assert_true(not _has_intel_id(locked, intel_id), "%s locked intel stays hidden below trust threshold" % npc_id)
	state.trust = required_trust
	var unlocked: Array = service.call("available_intels_for_npc", npc_id, gs)
	assert_true(_has_intel_id(unlocked, intel_id), "%s available intel unlocks at trust threshold" % npc_id)
	gs.queue_free()


func test_brendan_church_awareness_threshold(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var service = _new_instance(NPC_SERVICE_PATH, "NpcInteractionService")
	if service == null:
		return
	var gs = _fresh_state()
	gs.church_awareness = 10
	gs.ap = 10
	var result: Dictionary = service.open_dialogue(npc_id, gs, FakeDialogicAdapter.new())
	assert_eq(result.get("variables", {}).get("church_awareness", -1), 10, "Brendan dialogue binds church_awareness")
	assert_eq(str(result.get("church_awareness_branch", "")), "threshold_10_interrogation", "Brendan opens threshold 10 interrogation branch")
	var state = gs.npc_relations.get(npc_id, null)
	assert_true(state != null, "Brendan state exists after threshold dialogue")
	if state != null:
		assert_eq(str(state.dialogue_state.get("church_awareness_interrogation", "")), "threshold_10", "Brendan state records threshold interrogation")
	gs.queue_free()


func test_hub_direct_npc_hotspot_opens_dialogue(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var previous: Dictionary = GameState.to_dict()
	var fresh = _fresh_state()
	GameState.from_dict(fresh.to_dict())
	GameState.day = int(spec.get("day", 6))
	GameState.sequence = int(spec.get("sequence", 9))
	GameState.time_of_day = str(spec.get("time_of_day", "morning"))
	GameState.ap = 10
	GameState.daodian["completed_main_story_nodes"] = spec.get("nodes", [])
	fresh.queue_free()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("_on_city_hotspot_selected", {"type": "npc", "label": npc_id, "payload": {"npc_id": npc_id}})
	await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "%s direct Hub NPC hotspot opens visible dialogue" % npc_id)
	if dialog != null:
		_assert_player_dialogue_text(str(dialog.dialog_text), "%s direct Hub dialogue is player-facing Chinese" % npc_id)
	hub.queue_free()
	GameState.from_dict(previous)


func test_city_path_hotspot_opens_dialogue(spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var path: Dictionary = spec.get("city_path", {})
	var previous: Dictionary = GameState.to_dict()
	var fresh = _fresh_state()
	GameState.from_dict(fresh.to_dict())
	GameState.day = int(path.get("day", spec.get("day", 6)))
	GameState.sequence = int(path.get("sequence", spec.get("sequence", 9)))
	GameState.time_of_day = str(path.get("time_of_day", spec.get("time_of_day", "morning")))
	GameState.ap = 12
	GameState.daodian["completed_main_story_nodes"] = path.get("nodes", spec.get("nodes", []))
	fresh.queue_free()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", str(path.get("district", "")), str(path.get("time_of_day", "")))
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "%s Hub path opens CityScene" % npc_id)
	var button = null
	if city != null:
		button = city.find_child(str(path.get("hotspot_id", "")), true, false)
	assert_true(button is Button, "%s CityScene exposes NPC hotspot %s" % [npc_id, str(path.get("hotspot_id", ""))])
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "%s CityScene hotspot opens visible dialogue" % npc_id)
	if dialog != null:
		_assert_player_dialogue_text(str(dialog.dialog_text), "%s CityScene dialogue is player-facing Chinese" % npc_id)
	hub.queue_free()
	GameState.from_dict(previous)


func _assert_relation_thresholds(npc: Dictionary, npc_id: String) -> void:
	var thresholds: Variant = npc.get("relation_thresholds", null)
	assert_true(thresholds is Dictionary, "%s has relation_thresholds" % npc_id)
	if not thresholds is Dictionary:
		return
	for key in ["neutral", "acquainted", "friend", "trusted", "kin"]:
		assert_true((thresholds as Dictionary).has(key), "%s relation_thresholds has %s" % [npc_id, key])


func _assert_city_presence(npc: Dictionary, spec: Dictionary) -> void:
	var npc_id := str(spec.get("npc_id", ""))
	var raw: Variant = npc.get("city_presence", null)
	assert_true(raw is Array, "%s has city_presence array" % npc_id)
	if not raw is Array:
		return
	var presence: Array = raw
	for entry in presence:
		if not entry is Dictionary:
			assert_true(false, "%s city_presence entry is dictionary" % npc_id)
			continue
		assert_true(VALID_TIMES.has(str(entry.get("time_of_day", ""))), "%s city_presence uses valid time_of_day %s" % [npc_id, str(entry.get("time_of_day", ""))])
	for expected in spec.get("presence", []):
		if expected is Dictionary:
			assert_true(_has_presence(presence, expected), "%s city_presence includes %s/%s" % [npc_id, str(expected.get("district", "")), str(expected.get("time_of_day", ""))])
	for district_id in spec.get("districts", []):
		assert_true(_presence_has_district(presence, str(district_id)), "%s appears in district %s" % [npc_id, str(district_id)])


func _assert_available_intels(npc: Dictionary, npc_id: String) -> void:
	var intels: Variant = npc.get("available_intels", null)
	assert_true(intels is Array, "%s has available_intels array" % npc_id)
	if not intels is Array:
		return
	assert_true((intels as Array).size() >= 1 and (intels as Array).size() <= 3, "%s has 1-3 available_intels" % npc_id)
	for intel in (intels as Array):
		if not intel is Dictionary:
			assert_true(false, "%s intel entry is dictionary" % npc_id)
			continue
		for key in ["intel_id", "trust", "source_type", "topic", "summary"]:
			assert_true((intel as Dictionary).has(key), "%s intel has %s" % [npc_id, key])
		assert_true(str((intel as Dictionary).get("intel_id", "")) != "", "%s intel_id is non-empty" % npc_id)


func _assert_commission_pool(npc: Dictionary, npc_id: String) -> void:
	assert_true(npc.has("commission_pool"), "%s has commission_pool field" % npc_id)
	assert_true(str(npc.get("commission_pool", "")) != "", "%s commission_pool is non-empty" % npc_id)
	var templates: Variant = npc.get("commission_templates", [])
	if templates is Array:
		assert_true((templates as Array).size() <= 3, "%s commission_templates has at most 3 entries" % npc_id)


func _has_presence(presence: Array, expected: Dictionary) -> bool:
	for entry in presence:
		if not entry is Dictionary:
			continue
		if str(entry.get("district", "")) != str(expected.get("district", "")):
			continue
		if str(entry.get("time_of_day", "")) != str(expected.get("time_of_day", "")):
			continue
		if expected.has("visible_when") and str(entry.get("visible_when", "")) != str(expected.get("visible_when", "")):
			continue
		return true
	return false


func _presence_has_district(presence: Array, district_id: String) -> bool:
	for entry in presence:
		if entry is Dictionary and str(entry.get("district", "")) == district_id:
			return true
	return false


func _npc_def(npc_id: String) -> Dictionary:
	var library = _new_instance(NPC_LIBRARY_PATH, "NpcLibrary")
	if library == null:
		return {}
	library.load_all()
	return library.get_definition(npc_id)


func _registered_timeline_path(timeline_id: String) -> String:
	var timelines: Dictionary = ProjectSettings.get_setting("dialogic/directories/dtl_directory", {})
	return str(timelines.get(timeline_id, ""))


func _first_intel_id(npc: Dictionary) -> String:
	var intels: Array = _array(npc.get("available_intels", []))
	for intel in intels:
		if intel is Dictionary:
			var intel_id := str((intel as Dictionary).get("intel_id", ""))
			if intel_id != "":
				return intel_id
	return ""


func _has_intel_id(intels: Array, intel_id: String) -> bool:
	for intel in intels:
		if intel is Dictionary and str((intel as Dictionary).get("intel_id", "")) == intel_id:
			return true
	return false


func _assert_player_dialogue_text(value: String, message: String) -> void:
	assert_true(value.strip_edges() != "", "%s is not empty" % message)
	assert_true(_has_cjk(value), "%s contains Chinese text" % message)
	for fragment in ["Dialogic timeline", "npc_id:", "npc/", "timeline_id"]:
		assert_true(value.find(fragment) < 0, "%s hides %s" % [message, fragment])


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _new_instance(path: String, label: String):
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s script loads and can instantiate" % label)
		return null
	var instance = script.new()
	assert_true(instance != null, "%s instance creates" % label)
	return instance


func _fresh_state():
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
