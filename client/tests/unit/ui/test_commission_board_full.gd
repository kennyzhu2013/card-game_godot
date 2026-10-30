extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const CommissionLibraryPath := "res://scripts/world/commission_library.gd"
const CommissionServicePath := "res://scripts/world/commission_service.gd"
const FieldOpportunityServicePath := "res://scripts/world/field_opportunity_service.gd"
const DistrictSelectScript = preload("res://scripts/ui/district_select.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_commission_board_full.gd --")
	await test_board_opens_from_hub_and_refreshes_real_day3_hook()
	await test_board_player_facing_copy_is_chinese()
	await test_board_accept_execute_progress_and_claim_real_commission()
	await test_board_claims_old_li_daily_opportunity_after_external_completion()
	await test_board_claims_old_li_daily_opportunity_after_target_drill_without_notice_execute()
	await test_accepted_battle_commission_marks_front_door_district()
	await test_commission_board_surfaces_modifier_text()
	return {"passed": _passed, "failed": _failed}


func test_board_opens_from_hub_and_refreshes_real_day3_hook() -> void:
	var previous: Dictionary = GameState.to_dict()
	_reset_global_state()
	GameState.day = 3
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	var notice = hub.get_node_or_null("MarginContainer/VBoxContainer/ZoneGrid/NoticeBoardButton")
	assert_true(notice is Button, "Hub has notice board button")
	if notice is Button:
		notice.pressed.emit()
		await Engine.get_main_loop().process_frame
	var panel = hub.get_node_or_null("CommissionBoard")
	assert_true(panel != null and panel.visible, "notice board opens CommissionBoard")
	var hook_row = panel.find_child("CommissionRow_commission_main_black_market_intro_001", true, false) if panel != null else null
	assert_true(hook_row != null, "board refreshes real Day 3 main-story commission row")
	var reject_button = panel.find_child("CommissionRejectButton_commission_main_black_market_intro_001", true, false) if panel != null else null
	assert_true(reject_button is Button and reject_button.disabled, "main-story hook row exposes disabled reject button")
	hub.queue_free()
	GameState.from_dict(previous)


func test_board_player_facing_copy_is_chinese() -> void:
	var previous: Dictionary = GameState.to_dict()
	_reset_global_state()
	GameState.day = 1
	var panel = await _commission_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var title = panel.find_child("CommissionTitleLabel", true, false)
	assert_true(title is Label and str(title.text) == "告示牌", "notice board title is Chinese")
	var hint = panel.find_child("CommissionHintLabel", true, false)
	assert_true(hint is Label and _is_clean_player_text(str(hint.text)), "notice board hint is Chinese player-facing copy")
	var close_button = panel.find_child("CommissionCloseButton", true, false)
	assert_true(close_button is Button and str(close_button.text) == "关闭", "notice board close button is Chinese")
	var status = panel.find_child("CommissionStatusLabel", true, false)
	assert_true(status is Label and str(status.text) == "选择一项委托。", "notice board status prompt is Chinese")
	var reject = panel.find_child("CommissionRejectButton_commission_rumor_delivery_001", true, false)
	assert_true(reject is Button and str(reject.text) == "拒绝", "notice board reject button is Chinese")
	var state = panel.find_child("CommissionStateLabel_commission_rumor_delivery_001", true, false)
	assert_true(state is Label and str(state.text) == "可接", "available commission state label reads 可接 instead of duplicating 接受")
	var row_title = panel.find_child("CommissionTitle_commission_rumor_delivery_001", true, false)
	assert_true(row_title is Label and _is_clean_player_text(str(row_title.text)), "notice board commission title is Chinese")
	var row_description = panel.find_child("CommissionDescription_commission_rumor_delivery_001", true, false)
	assert_true(row_description is Label and _is_clean_player_text(str(row_description.text)), "notice board commission description is Chinese")
	var action = panel.find_child("CommissionActionButton_commission_rumor_delivery_001", true, false)
	assert_true(action is Button and str(action.text) == "接受", "notice board action button is Chinese")
	if action is Button and status is Label:
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true(_is_clean_player_text(str(status.text)) and str(status.text).begins_with("已接受："), "accept status is Chinese and hides raw ids")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true(_is_clean_player_text(str(status.text)) and str(status.text).begins_with("已派发："), "dispatch status is Chinese and hides raw ids")
	panel.queue_free()
	GameState.from_dict(previous)


func test_board_accept_execute_progress_and_claim_real_commission() -> void:
	var previous: Dictionary = GameState.to_dict()
	_reset_global_state()
	var panel = await _commission_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	GameState.day = 1
	GameState.lingstones = 0
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var action = panel.find_child("CommissionActionButton_commission_rumor_delivery_001", true, false)
	assert_true(action is Button, "rumor delivery action button exists")
	if action is Button:
		assert_true(_text_is(str(action.text), ["接受", "鎺ュ彈"]), "real commission starts as accept")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true("commission_rumor_delivery_001" in GameState.accepted_commissions, "board accept writes accepted_commissions")
		assert_true(_text_is(str(action.text), ["执行", "鎵ц"]), "accepted real commission button says execute")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true(GameState.has_meta("commission_active_dispatch"), "board execute writes active dispatch meta")
		assert_true(_text_is(str(action.text), ["执行", "鎵ц", "交差", "浜ゅ樊"]), "execute keeps progress/claim button state structured")
		var service = _service()
		if service != null:
			service.record_completion_event(GameState, {
				"event": "perform_action",
				"district": "shadow_alley",
				"action_id": "deliver_rumor",
				"witness_count": 0,
			})
		if panel.has_method("_refresh"):
			panel.call("_refresh")
		await Engine.get_main_loop().process_frame
		assert_true(_text_is(str(action.text), ["交差", "浜ゅ樊"]), "completed real commission button says claim")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
		assert_true("commission_rumor_delivery_001" in GameState.completed_commissions, "claim records completed commission")
		assert_true(GameState.lingstones > 0, "claim applies real rewards")
	panel.queue_free()
	GameState.from_dict(previous)


func test_board_claims_old_li_daily_opportunity_after_external_completion() -> void:
	var previous: Dictionary = GameState.to_dict()
	_reset_global_state()
	GameState.day = 1
	GameState.sequence = 9
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.lingstones = 0
	GameState.halfmoon_trust = 0
	GameState.learned_rules.clear()
	var old_li := NpcKnowledgeStateScript.new()
	old_li.trust = 45
	old_li.last_seen_day = 1
	old_li.interaction_fatigue = 0
	GameState.npc_relations["old_li"] = old_li
	var field_service = _field_service()
	var service = _service()
	if field_service == null or service == null:
		GameState.from_dict(previous)
		return
	field_service.refresh_daily(GameState, 35001)
	var accept_result: Dictionary = field_service.resolve_npc_opportunity(GameState, "old_li", "old_li_private_request")
	assert_true(bool(accept_result.get("ok", false)), "Old Li daily opportunity accepts the board commission")
	assert_true("commission_old_li_letter_001" in GameState.accepted_commissions, "Old Li daily opportunity records accepted commission")
	var completion_result: Dictionary = service.record_completion_event(GameState, {
		"event": "perform_action",
		"district": "sacred_seven",
		"action_id": "recite_letter",
		"witness_count": 0,
	})
	assert_true(_array_has_string(completion_result.get("completed_ids", []), "commission_old_li_letter_001"), "external Old Li letter completion marks commission completed")
	var panel = await _commission_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var action = panel.find_child("CommissionActionButton_commission_old_li_letter_001", true, false)
	assert_true(action is Button, "notice board shows Old Li letter action after daily opportunity completion")
	if action is Button:
		assert_true(not action.disabled, "completed Old Li letter has enabled notice-board submit action")
		assert_true(_text_is(str(action.text), ["交差", "浜ゅ樊"]), "completed Old Li letter button says claim")
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_true("commission_old_li_letter_001" in GameState.completed_commissions, "notice board submit claims Old Li daily commission")
	assert_true(not "commission_old_li_letter_001" in GameState.accepted_commissions, "notice board submit removes Old Li daily commission from accepted list")
	assert_true("shadow_silence" in GameState.learned_rules, "notice board submit applies Old Li contract rule reward")
	assert_true(int(GameState.halfmoon_trust) > 0, "notice board submit applies Old Li trust reward")
	panel.queue_free()
	GameState.from_dict(previous)


func test_board_claims_old_li_daily_opportunity_after_target_drill_without_notice_execute() -> void:
	var previous: Dictionary = GameState.to_dict()
	_reset_global_state()
	GameState.day = 1
	GameState.sequence = 9
	GameState.time_of_day = "night"
	GameState.current_district = "shadow_alley"
	GameState.halfmoon_trust = 0
	GameState.learned_rules.clear()
	var old_li := NpcKnowledgeStateScript.new()
	old_li.trust = 45
	old_li.last_seen_day = 1
	old_li.interaction_fatigue = 0
	GameState.npc_relations["old_li"] = old_li
	_add_global_thought_card()
	var field_service = _field_service()
	var service = _service()
	if field_service == null or service == null:
		GameState.from_dict(previous)
		return
	field_service.refresh_daily(GameState, 35001)
	var accept_result: Dictionary = field_service.resolve_npc_opportunity(GameState, "old_li", "old_li_private_request")
	assert_true(bool(accept_result.get("ok", false)), "Old Li daily opportunity accepts commission before direct drill")
	assert_true(not GameState.has_meta("commission_active_dispatch"), "daily opportunity accept does not require notice-board execute")
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "sacred_seven", "morning")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var drill_button = city.find_child("Hotspot_drill_confess_innocent", true, false) if city != null else null
	assert_true(drill_button is Button, "Old Li daily opportunity target drill is reachable")
	if drill_button is Button:
		drill_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var drill_dialog = hub.get_node_or_null("DrillDialog")
	var start_button = drill_dialog.find_child("DrillButton_confess_innocent", true, false) if drill_dialog != null else null
	assert_true(start_button is Button and not start_button.disabled, "Old Li daily opportunity target drill can be started")
	if start_button is Button:
		start_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(service.status_for(GameState, "commission_old_li_letter_001"), "completed", "target drill completes Old Li daily opportunity commission without notice-board execute")
	var board = hub.get_node_or_null("CommissionBoard")
	assert_true(board != null, "hub has notice board after direct target drill")
	if board != null and board.has_method("open"):
		board.open(GameState)
		await Engine.get_main_loop().process_frame
		var claim_action = board.find_child("CommissionActionButton_commission_old_li_letter_001", true, false)
		assert_true(claim_action is Button and not claim_action.disabled, "completed Old Li daily opportunity has enabled notice-board submit")
		if claim_action is Button:
			assert_true(_text_is(str(claim_action.text), ["交差", "浜ゅ樊"]), "completed Old Li daily opportunity button says claim")
			claim_action.pressed.emit()
			await Engine.get_main_loop().process_frame
	assert_true("commission_old_li_letter_001" in GameState.completed_commissions, "notice board submit claims direct-drill Old Li daily commission")
	assert_true("shadow_silence" in GameState.learned_rules, "direct-drill Old Li submit applies reward")
	assert_true(int(GameState.halfmoon_trust) > 0, "direct-drill Old Li submit applies trust reward")
	hub.queue_free()
	GameState.from_dict(previous)


func test_accepted_battle_commission_marks_front_door_district() -> void:
	var previous: Dictionary = GameState.to_dict()
	_reset_global_state()
	var library = _library()
	if library == null:
		GameState.from_dict(previous)
		return
	library.load_all()
	var steel: Variant = library.get_template("commission_steelworks_missing_001")
	assert_true(not steel.is_empty(), "steelworks battle commission template exists")
	GameState.available_commissions.append(steel.to_dict())
	var panel = await _commission_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var action = panel.find_child("CommissionActionButton_commission_steelworks_missing_001", true, false)
	assert_true(action is Button, "steelworks battle action button exists")
	if action is Button:
		action.pressed.emit()
		await Engine.get_main_loop().process_frame
	var entries := DistrictSelectScript.selector_entries_for(GameState)
	var marked := false
	for entry in entries:
		if entry is Dictionary and str(entry.get("commission_id", "")) == "commission_steelworks_missing_001":
			marked = bool(entry.get("has_commission_marker", false)) and str(entry.get("district_id", "")) == "steelworks"
			break
	assert_true(marked, "accepted battle commission marks the structured front-door district entry")
	panel.queue_free()
	GameState.from_dict(previous)


func test_commission_board_surfaces_modifier_text() -> void:
	var previous: Dictionary = GameState.to_dict()
	_reset_global_state()
	GameState.day = 3
	var service = _service()
	if service == null:
		GameState.from_dict(previous)
		return
	var refresh: Dictionary = service.refresh_daily(GameState, 35123)
	assert_true(bool(refresh.get("ok", false)), "commission refresh succeeds for modifier display path")
	var modifier_commission_id := ""
	for commission in GameState.available_commissions:
		if commission is Dictionary and str((commission as Dictionary).get("modifier_display_text", "")) != "":
			modifier_commission_id = str((commission as Dictionary).get("id", ""))
			break
	assert_true(modifier_commission_id != "", "seeded refresh produces at least one visible commission modifier")
	var panel = await _commission_panel()
	if panel == null:
		GameState.from_dict(previous)
		return
	panel.open(GameState)
	await Engine.get_main_loop().process_frame
	var text := _collect_label_text(panel)
	assert_true(
		_contains_any(text, [
			"\u52a0\u6025",
			"\u5371\u9669",
			"\u989d\u5916\u8bc1\u636e",
			"\u907f\u4eba\u8033\u76ee",
			"\u719f\u4eba\u59d4\u6258",
			"\u4fe1\u4efb\u52a0\u6210",
		]),
		"commission board shows visible modifier text"
	)
	var badge = panel.find_child("CommissionModifierBadge_%s" % modifier_commission_id, true, false)
	assert_true(badge is Label and badge.visible, "commission board renders modifier badge on the modified row")
	panel.queue_free()
	GameState.from_dict(previous)


func _commission_panel():
	var scene = load("res://scenes/ui/commission_board.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "commission board scene loads")
		return null
	var panel = scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)
	await Engine.get_main_loop().process_frame
	return panel


func _hub():
	var scene = load("res://scenes/hub/hub.tscn")
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _library():
	if not ResourceLoader.exists(CommissionLibraryPath):
		assert_true(false, "CommissionLibrary script exists")
		return null
	return load(CommissionLibraryPath).new()


func _service():
	if not ResourceLoader.exists(CommissionServicePath):
		assert_true(false, "CommissionService script exists")
		return null
	return load(CommissionServicePath).new()


func _field_service():
	if not ResourceLoader.exists(FieldOpportunityServicePath):
		assert_true(false, "FieldOpportunityService script exists")
		return null
	return load(FieldOpportunityServicePath).new()


func _reset_global_state() -> void:
	GameState.day = 1
	GameState.time_of_day = "morning"
	GameState.ap = 12
	GameState.ap_max = 12
	GameState.lingstones = 10
	GameState.dao_pages = 0
	GameState.available_commissions.clear()
	GameState.accepted_commissions.clear()
	GameState.completed_commissions.clear()
	GameState.cards_inventory.clear()
	GameState.temp_picked_cards.clear()
	GameState.minigame_history.clear()
	for key in ["commission_active_dispatch", "commission_pending_completion", "commission_pending_includes_tower"]:
		if GameState.has_meta(key):
			GameState.remove_meta(key)


func _add_global_thought_card():
	var card = CardScript.from_json({
		"id": "commission_board_thought_card",
		"template_id": "commission_board_thought_card",
		"display_name": "commission_board_thought_card",
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


func _array_has_string(value: Variant, expected: String) -> bool:
	if value is Array:
		for item in value:
			if str(item) == expected:
				return true
	return false


func _text_is(value: String, expected_values: Array[String]) -> bool:
	for expected in expected_values:
		if value == expected:
			return true
	return false


func _collect_label_text(root: Node) -> String:
	var pieces: Array[String] = []
	_collect_label_text_recursive(root, pieces)
	return "\n".join(pieces)


func _collect_label_text_recursive(node: Node, pieces: Array[String]) -> void:
	if node is Label:
		pieces.append(str((node as Label).text))
	for child in node.get_children():
		_collect_label_text_recursive(child, pieces)


func _contains_any(value: String, needles: Array[String]) -> bool:
	for needle in needles:
		if value.contains(needle):
			return true
	return false


func _is_clean_player_text(value: String) -> bool:
	if value.strip_edges() == "":
		return false
	for fragment in [
		"Commission Board",
		"Select a commission",
		"Daily commissions",
		"accepted:",
		"rejected:",
		"dispatch:",
		"claimed:",
		"already_completed",
		"legacy_execute_ok",
		"Unknown commission fallback",
		"commission_",
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
