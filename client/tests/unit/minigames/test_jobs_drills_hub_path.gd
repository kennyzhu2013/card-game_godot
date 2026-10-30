extends RefCounted

const HUB_SCENE := "res://scenes/hub/hub.tscn"
const CardScript = preload("res://scripts/combat/card.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")

var _passed := 0
var _failed := 0


class FakeFailingDrillRunner:
	extends RefCounted

	var calls: Array = []

	func load_drill_definition(drill_id: String) -> Dictionary:
		return {"id": drill_id, "display_name": "Fake Drill", "ap_cost": 1, "rules": []}

	func available_drills(_game_state, drill_ids: Array = []) -> Array:
		var result: Array = []
		for raw_id in drill_ids:
			var drill_id := str(raw_id)
			if drill_id == "":
				continue
			var entry := load_drill_definition(drill_id)
			entry["available"] = true
			entry["reason"] = ""
			result.append(entry)
		return result

	func can_start(_game_state, drill_id: String, _options: Dictionary = {}) -> Dictionary:
		return {"ok": true, "definition": load_drill_definition(drill_id), "ap_cost": 1}

	func resolve_drill(_game_state, drill_id: String, _options: Dictionary = {}) -> Dictionary:
		calls.append(drill_id)
		return {
			"ok": true,
			"id": drill_id,
			"drill_id": drill_id,
			"outcome": "fail",
			"ap_cost": 1,
			"granted_intel_texts": [],
			"ai_gm_text": "visible drill collapse ai gm text",
		}


func run() -> Dictionary:
	print("\n-- test_jobs_drills_hub_path.gd --")
	await test_steelworks_factory_hotspot_opens_playable_job_dialog()
	await test_stone_tower_drill_hotspot_opens_playable_drill_dialog()
	await test_city_drill_failure_displays_ai_gm_feedback()
	await test_errand_hotspot_surfaces_granted_intel_text()
	await test_factory_job_commission_can_be_completed_and_claimed_after_city_job()
	await test_drill_commission_can_be_completed_and_claimed_after_city_drill()
	await test_old_li_letter_commission_can_be_completed_and_claimed_after_sacred_seven_drill()
	return {"passed": _passed, "failed": _failed}


func test_steelworks_factory_hotspot_opens_playable_job_dialog() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state("steelworks", "morning", 4)
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "steelworks", "morning")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Hub debug path opens steelworks CityScene")
	var button = city.find_child("Hotspot_job_factory_shift", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes factory job hotspot")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("JobDialog")
	assert_true(dialog != null and dialog.visible, "factory hotspot opens JobDialog")
	if dialog != null:
		assert_true(_is_clean_player_text(str(dialog.dialog_text)) and str(dialog.dialog_text).find("工厂打工") >= 0, "job dialog uses Chinese player-facing text")
		var start_button = dialog.find_child("JobButton_factory_shift", true, false)
		assert_true(start_button is Button, "job dialog exposes playable factory button")
		if start_button is Button:
			assert_eq(str(start_button.text), "工厂打工", "job start button uses Chinese label")
			var before_ap := int(GameState.ap)
			start_button.pressed.emit()
			await Engine.get_main_loop().process_frame
			assert_eq(int(GameState.ap), before_ap - 3, "clicking factory job button spends 3 AP")
			assert_eq(int(GameState.lingstones), 120, "clicking factory job button settles wage")
			assert_true(str(dialog.dialog_text).find("结算结果") >= 0 and str(dialog.dialog_text).find("完美") >= 0, "job dialog writes Chinese settlement grade")
	var placeholder = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(placeholder == null or not placeholder.visible, "job hotspot no longer uses generic placeholder")
	hub.queue_free()
	GameState.from_dict(previous)


func test_stone_tower_drill_hotspot_opens_playable_drill_dialog() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state("stone_tower", "noon", 8)
	var thought_card = _add_global_thought_card()
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "stone_tower", "noon")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Hub debug path opens stone_tower CityScene")
	var button = city.find_child("Hotspot_drill_noble_salon", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes noble salon drill hotspot")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("DrillDialog")
	assert_true(dialog != null and dialog.visible, "drill hotspot opens DrillDialog")
	if dialog != null:
		assert_true(_is_clean_player_text(str(dialog.dialog_text)) and str(dialog.dialog_text).find("贵族沙龙演练") >= 0, "drill dialog uses Chinese player-facing text")
		var start_button = dialog.find_child("DrillButton_noble_salon", true, false)
		assert_true(start_button is Button, "drill dialog exposes playable noble_salon button")
		if start_button is Button:
			assert_eq(str(start_button.text), "贵族沙龙演练", "drill start button uses Chinese label")
			var before_ap := int(GameState.ap)
			start_button.pressed.emit()
			await Engine.get_main_loop().process_frame
			assert_eq(int(GameState.ap), before_ap - 2, "clicking noble_salon button spends 2 AP")
			assert_eq(int(thought_card.acting_exp), 1, "clicking drill button feeds acting_exp to thought card")
			assert_true("noble_grace" in GameState.learned_rules, "noble_salon success unlocks noble_grace")
			assert_true(str(dialog.dialog_text).find("演练结果") >= 0 and str(dialog.dialog_text).find("完美") >= 0, "drill dialog writes Chinese settlement outcome")
	var placeholder = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(placeholder == null or not placeholder.visible, "drill hotspot no longer uses generic placeholder")
	hub.queue_free()
	GameState.from_dict(previous)


func test_city_drill_failure_displays_ai_gm_feedback() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state("stone_tower", "noon", 8)
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	assert_true(hub.has_method("set_drill_runner"), "Hub can receive an injected DrillRunner for drill UI feedback")
	var fake := FakeFailingDrillRunner.new()
	if hub.has_method("set_drill_runner"):
		hub.call("set_drill_runner", fake)
	hub.call("open_city_for_debug", "stone_tower", "noon")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var button = city.find_child("Hotspot_drill_noble_salon", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes noble_salon drill hotspot for failure feedback")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("DrillDialog")
	var start_button = dialog.find_child("DrillButton_noble_salon", true, false) if dialog != null else null
	assert_true(start_button is Button, "drill dialog exposes injected-runner start button")
	if start_button is Button:
		start_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(fake.calls.size(), 1, "drill start uses the injected runner once")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("visible drill collapse ai gm text"), "drill failure dialog displays AI GM collapse narration")
	hub.queue_free()
	GameState.from_dict(previous)


func test_errand_hotspot_surfaces_granted_intel_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state("shadow_alley", "night", 5)
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	assert_true(city != null and city.visible, "Hub debug path opens shadow_alley CityScene")
	var button = city.find_child("Hotspot_job_errand_board", true, false) if city != null else null
	assert_true(button is Button, "CityScene exposes errand job hotspot")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("JobDialog")
	var start_button = dialog.find_child("JobButton_errand_runner", true, false) if dialog != null else null
	assert_true(start_button is Button, "errand dialog exposes playable start button")
	if start_button is Button:
		start_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var active: Array = _active_rumors()
	assert_true(_active_ids(active).has("intel_errand_shadow_001"), "errand city job grants the R26 route intel")
	var expected_text := _intel_text(active, "intel_errand_shadow_001")
	assert_true(expected_text != "", "test can resolve the errand intel display text")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("情报") or str(dialog.dialog_text).contains("鎯呮姤"), "errand settlement names the intel reward")
		assert_true(expected_text != "" and str(dialog.dialog_text).contains(expected_text), "errand settlement shows the player-facing intel text")
	var placeholder = hub.get_node_or_null("HubPlaceholderDialog")
	assert_true(placeholder == null or not placeholder.visible, "errand intel feedback does not use generic placeholder")
	hub.queue_free()
	GameState.from_dict(previous)


func test_factory_job_commission_can_be_completed_and_claimed_after_city_job() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state("steelworks", "morning", 4)
	var service = CommissionServiceScript.new()
	var commission_id := "commission_factory_shift_001"
	assert_true(bool(service.accept(GameState, commission_id).get("ok", false)), "factory commission accept succeeds")
	assert_true(bool(service.execute(GameState, commission_id).get("ok", false)), "factory commission execute writes active dispatch")
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "steelworks", "morning")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var button = city.find_child("Hotspot_job_factory_shift", true, false) if city != null else null
	assert_true(button is Button, "factory commission city job hotspot is reachable")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("JobDialog")
	var start_button = dialog.find_child("JobButton_factory_shift", true, false) if dialog != null else null
	assert_true(start_button is Button, "factory commission city job can be started")
	if start_button is Button:
		start_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(service.status_for(GameState, commission_id), "completed", "factory city job completion marks commission completed")
	assert_true(not GameState.has_meta("commission_active_dispatch"), "factory city job completion clears active commission dispatch")
	var before_claim := int(GameState.lingstones)
	var board = hub.get_node_or_null("CommissionBoard")
	assert_true(board != null, "hub has commission board after city job completion")
	if board != null and board.has_method("open"):
		board.open(GameState)
		await Engine.get_main_loop().process_frame
		var action = board.find_child("CommissionActionButton_%s" % commission_id, true, false)
		assert_true(action is Button and not action.disabled, "completed factory commission shows enabled claim action on notice board")
		if action is Button:
			action.pressed.emit()
			await Engine.get_main_loop().process_frame
	assert_true(commission_id in GameState.completed_commissions, "factory commission can be claimed after city job")
	assert_true(int(GameState.lingstones) > before_claim, "factory commission claim applies board reward")
	hub.queue_free()
	GameState.from_dict(previous)


func test_drill_commission_can_be_completed_and_claimed_after_city_drill() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state("stone_tower", "noon", 8)
	_add_global_thought_card()
	var service = CommissionServiceScript.new()
	var commission_id := "commission_stone_tower_salon_001"
	assert_true(bool(service.accept(GameState, commission_id).get("ok", false)), "drill commission accept succeeds")
	assert_true(bool(service.execute(GameState, commission_id).get("ok", false)), "drill commission execute writes active dispatch")
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "stone_tower", "noon")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var button = city.find_child("Hotspot_drill_noble_salon", true, false) if city != null else null
	assert_true(button is Button, "drill commission city drill hotspot is reachable")
	if button is Button:
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("DrillDialog")
	var start_button = dialog.find_child("DrillButton_noble_salon", true, false) if dialog != null else null
	assert_true(start_button is Button, "drill commission city drill can be started")
	if start_button is Button:
		start_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(service.status_for(GameState, commission_id), "completed", "city drill completion marks commission completed")
	assert_true(not GameState.has_meta("commission_active_dispatch"), "city drill completion clears active commission dispatch")
	var before_claim := int(GameState.lingstones)
	var board = hub.get_node_or_null("CommissionBoard")
	assert_true(board != null, "hub has commission board after city drill completion")
	if board != null and board.has_method("open"):
		board.open(GameState)
		await Engine.get_main_loop().process_frame
		var action = board.find_child("CommissionActionButton_%s" % commission_id, true, false)
		assert_true(action is Button and not action.disabled, "completed drill commission shows enabled claim action on notice board")
		if action is Button:
			action.pressed.emit()
			await Engine.get_main_loop().process_frame
	assert_true(commission_id in GameState.completed_commissions, "drill commission can be claimed after city drill")
	assert_true(int(GameState.lingstones) > before_claim, "drill commission claim applies board reward")
	hub.queue_free()
	GameState.from_dict(previous)


func test_old_li_letter_commission_can_be_completed_and_claimed_after_sacred_seven_drill() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state("shadow_alley", "night", 1)
	GameState.sequence = 9
	_add_global_thought_card()
	var service = CommissionServiceScript.new()
	var commission_id := "commission_old_li_letter_001"
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "shadow_alley", "night")
	await Engine.get_main_loop().process_frame
	var shadow_city = hub.get_node_or_null("CityScene")
	var old_li_button = shadow_city.find_child("Hotspot_npc_old_li", true, false) if shadow_city != null else null
	assert_true(old_li_button is Button, "Old Li letter path reaches Old Li in Shadow Alley")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var npc_dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(_press_dialog_button(npc_dialog, "NpcEventMenuButton_old_li"), "Old Li dialogue exposes event menu before commission buttons")
	await Engine.get_main_loop().process_frame
	var npc_commission_button = npc_dialog.find_child("NpcCommissionButton_%s" % commission_id, true, false) if npc_dialog != null else null
	assert_true(npc_commission_button is Button, "Old Li dialogue exposes the letter commission button")
	if npc_commission_button is Button:
		npc_commission_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_true(commission_id in GameState.accepted_commissions, "Old Li letter commission can be accepted from NPC dialogue")
	var board = hub.get_node_or_null("CommissionBoard")
	assert_true(board != null, "hub has notice board for Old Li letter execution")
	if board != null and board.has_method("open"):
		board.open(GameState)
		await Engine.get_main_loop().process_frame
		var execute_action = board.find_child("CommissionActionButton_%s" % commission_id, true, false)
		assert_true(execute_action is Button and not execute_action.disabled, "accepted Old Li letter shows enabled execute action")
		if execute_action is Button:
			execute_action.pressed.emit()
			await Engine.get_main_loop().process_frame
	assert_true(GameState.has_meta("commission_active_dispatch"), "executing Old Li letter writes active city dispatch")
	hub.call("open_city_for_debug", "sacred_seven", "morning")
	await Engine.get_main_loop().process_frame
	var sacred_city = hub.get_node_or_null("CityScene")
	var drill_button = sacred_city.find_child("Hotspot_drill_confess_innocent", true, false) if sacred_city != null else null
	assert_true(drill_button is Button, "Old Li letter dispatch exposes Sacred Seven confess_innocent drill hotspot")
	if drill_button is Button:
		drill_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var drill_dialog = hub.get_node_or_null("DrillDialog")
	var start_button = drill_dialog.find_child("DrillButton_confess_innocent", true, false) if drill_dialog != null else null
	assert_true(start_button is Button and not start_button.disabled, "Old Li letter target drill can be started")
	if start_button is Button:
		start_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(service.status_for(GameState, commission_id), "completed", "Sacred Seven drill completion marks Old Li letter completed")
	assert_true(not GameState.has_meta("commission_active_dispatch"), "Old Li letter drill completion clears active dispatch")
	var before_claim_trust := int(GameState.halfmoon_trust)
	if board != null and board.has_method("open"):
		board.open(GameState)
		await Engine.get_main_loop().process_frame
		var claim_action = board.find_child("CommissionActionButton_%s" % commission_id, true, false)
		assert_true(claim_action is Button and not claim_action.disabled, "completed Old Li letter shows enabled claim action")
		if claim_action is Button:
			claim_action.pressed.emit()
			await Engine.get_main_loop().process_frame
	assert_true(commission_id in GameState.completed_commissions, "Old Li letter commission can be claimed after target drill")
	assert_true("shadow_silence" in GameState.learned_rules, "Old Li letter claim grants its contract rule reward")
	assert_true(int(GameState.halfmoon_trust) > before_claim_trust, "Old Li letter claim applies halfmoon trust reward")
	hub.queue_free()
	GameState.from_dict(previous)


func _setup_global_state(district_id: String, time_id: String, day: int) -> void:
	GameState.day = day
	GameState.time_of_day = time_id
	GameState.current_district = district_id
	GameState.sequence = 8
	GameState.ap = 12
	GameState.lingstones = 0
	GameState.pollution = 0
	GameState.church_awareness = 0
	GameState.cards_inventory.clear()
	GameState.minigame_history.clear()
	GameState.available_commissions.clear()
	GameState.accepted_commissions.clear()
	GameState.completed_commissions.clear()
	GameState.learned_rules.clear()
	GameState.dao_pages = 0
	GameState.temp_picked_cards.clear()
	var modifiers = GameState.get("activity_modifiers")
	if modifiers is Dictionary:
		modifiers.clear()
	for key in ["commission_active_dispatch", "commission_pending_completion", "commission_pending_includes_tower"]:
		if GameState.has_meta(key):
			GameState.remove_meta(key)


func _add_global_thought_card():
	var card = CardScript.from_json({
		"id": "hub_thought_card",
		"template_id": "hub_thought_card",
		"display_name": "hub_thought_card",
		"pathway": "fool",
		"sequence": 9,
		"rarity": "common",
		"quality": 1,
		"energy_cost": 1,
		"combat_effect": {"damage": 3, "target": "single"},
		"acting_rules": ["practice_rule"],
	})
	GameState.add_card(card)
	return card


func _hub() -> Control:
	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _press_dialog_button(dialog, button_name: String) -> bool:
	if dialog == null:
		return false
	var button = dialog.find_child(button_name, true, false)
	if button is Button:
		button.pressed.emit()
		return true
	return false


func _is_clean_player_text(value: String) -> bool:
	if value.strip_edges() == "":
		return false
	for fragment in [
		"job_id=",
		"drill_id=",
		"factory_shift",
		"noble_salon",
		"status=",
		"mechanic=",
		"witness=",
		"result=",
		"grade=",
		"outcome=",
		"ap_cost=",
		"open",
		"locked:",
	]:
		if value.find(fragment) >= 0:
			return false
	return _has_cjk(value)


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _active_rumors() -> Array:
	var value: Variant = GameState.get("active_rumors")
	return value if value is Array else []


func _active_ids(active: Array) -> Array:
	var result: Array = []
	for intel in active:
		if intel is Dictionary:
			result.append(str(intel.get("id", "")))
	return result


func _intel_text(active: Array, intel_id: String) -> String:
	for intel in active:
		if intel is Dictionary and str(intel.get("id", "")) == intel_id:
			return IntelServiceScript.player_display_text(intel)
	return ""


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
