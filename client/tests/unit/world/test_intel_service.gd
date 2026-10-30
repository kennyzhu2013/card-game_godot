extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const JobServiceScript = preload("res://scripts/world/job_service.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")

const INTEL_SERVICE_PATH := "res://scripts/world/intel_service.gd"

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_intel_service.gd --")
	test_game_state_active_rumors_roundtrip()
	test_intel_service_grant_records_history()
	test_intel_service_cleanup_and_shop_discount_apply()
	test_player_display_text_uses_in_world_copy_without_system_labels()
	test_r25_activity_rewards_grant_real_intel()
	return {"passed": _passed, "failed": _failed}


func test_game_state_active_rumors_roundtrip() -> void:
	var gs = _fresh_state()
	assert_true(gs.get("active_rumors") is Array, "GameState exposes active_rumors array")
	assert_true(gs.get("heard_rumor_history") is Dictionary, "GameState exposes heard_rumor_history dictionary")
	gs.set("active_rumors", [_sample_intel("intel_roundtrip_today", "today")])
	gs.set("heard_rumor_history", {"3": ["intel_roundtrip_today"]})
	var snapshot: Dictionary = gs.to_dict()
	var restored = _fresh_state()
	restored.from_dict(snapshot)
	var restored_active: Variant = restored.get("active_rumors")
	var restored_history: Variant = restored.get("heard_rumor_history")
	assert_true(restored_active is Array and restored_active.size() == 1, "active_rumors roundtrips through GameState")
	if restored_active is Array and restored_active.size() > 0:
		assert_eq(str(restored_active[0].get("id", "")), "intel_roundtrip_today", "active rumor id roundtrips")
	assert_true(restored_history is Dictionary and restored_history.has("3"), "heard_rumor_history roundtrips day key")
	gs.queue_free()
	restored.queue_free()


func test_intel_service_grant_records_history() -> void:
	var service = _new_service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 4
	gs.time_of_day = "evening"
	var result: Dictionary = service.grant(gs, "intel_shadow_alley_enemy_001", {"source_type": "unit_test"})
	assert_true(bool(result.get("ok", false)), "IntelService.grant succeeds for known intel id")
	var active: Array = _active_rumors(gs)
	assert_eq(active.size(), 1, "grant appends one active rumor")
	if active.size() > 0:
		assert_eq(str(active[0].get("id", "")), "intel_shadow_alley_enemy_001", "grant stores structured intel id")
		assert_eq(int(active[0].get("acquired_at_day", -1)), 4, "grant stamps acquired day")
		assert_eq(str(active[0].get("acquired_at_time", "")), "evening", "grant stamps acquired time")
	var history: Dictionary = _heard_history(gs)
	assert_true(history.has("4") and history["4"].has("intel_shadow_alley_enemy_001"), "grant records heard_rumor_history by day")
	gs.queue_free()


func test_intel_service_cleanup_and_shop_discount_apply() -> void:
	var service = _new_service()
	if service == null:
		return
	var gs = _fresh_state()
	gs.day = 1
	gs.time_of_day = "night"
	service.grant(gs, _sample_intel("intel_cleanup_today", "today"))
	service.grant(gs, _sample_intel("intel_cleanup_sleep", "until_sleep"))
	service.grant(gs, _sample_intel("intel_cleanup_permanent", "permanent"))
	gs.day = 2
	var cleanup: Dictionary = service.cleanup_expired(gs)
	assert_true(bool(cleanup.get("ok", false)), "cleanup_expired returns ok")
	var remaining_ids := _active_ids(gs)
	assert_eq(remaining_ids, ["intel_cleanup_permanent"], "sleep cleanup keeps only permanent intel")

	var discount_result: Dictionary = service.grant(gs, "intel_blackmarket_discount_001")
	assert_true(bool(discount_result.get("ok", false)), "known shop discount intel grants")
	var apply_result: Dictionary = service.apply(gs, "shop_discount.one_time", {"shop_id": "donen_blackmarket"})
	assert_true(bool(apply_result.get("ok", false)), "IntelService.apply shop discount succeeds")
	assert_eq(int(gs.shop_discounts.get("donen_blackmarket", 0)), 15, "shop discount intel writes one-time discount")
	assert_true(_intel_applied(gs, "intel_blackmarket_discount_001"), "shop discount intel is marked applied")
	gs.queue_free()


func test_player_display_text_uses_in_world_copy_without_system_labels() -> void:
	var service_script = load(INTEL_SERVICE_PATH)
	assert_true(service_script != null, "IntelService script loads for player display text test")
	if service_script == null:
		return
	var weather_text := str(service_script.player_display_text({
		"id": "intel_weather_copy_probe",
		"category": "weather",
		"display_text": "Tomorrow's smoke predicts fog",
		"source_type": "newspaper",
		"source_district": "steelworks",
		"expires_after": "next_morning",
		"apply_target": {
			"kind": "weather_forecast.next_day",
			"payload": {"predicted_weather_id": "fog"},
		},
		"truth_value": 100,
	}))
	assert_true(_has_cjk(weather_text), "weather intel renders as Chinese player-facing copy")
	assert_true(weather_text.contains("雾"), "weather intel still communicates the predicted weather")
	for forbidden in ["天气预报", "weather_forecast", "predicted_weather_id", "fog", "得到了一条"]:
		assert_true(not weather_text.contains(forbidden), "weather intel hides system wording/token %s" % forbidden)

	var tower_text := str(service_script.player_display_text({
		"id": "intel_tower_copy_probe",
		"category": "tower_hint",
		"display_text": "steel_small floor 1 shows enemy intent",
		"source_type": "newspaper",
		"source_district": "steelworks",
		"expires_after": "today",
		"apply_target": {
			"kind": "tower_intel.enemy_intent_reveal",
			"payload": {"tower_template": "steel_small", "floor_index_min": 0, "floor_index_max": 1},
		},
		"truth_value": 100,
	}))
	assert_true(_has_cjk(tower_text), "tower intel renders as Chinese player-facing copy")
	assert_true(tower_text.contains("1-2") and tower_text.contains("敌人意图"), "tower intel remains mechanically useful")
	for forbidden in ["明牌", "steel_small", "tower_intel", "得到了一条"]:
		assert_true(not tower_text.contains(forbidden), "tower intel hides system wording/token %s" % forbidden)


func test_r25_activity_rewards_grant_real_intel() -> void:
	var _service = _new_service()
	if _service == null:
		return
	var gs = _fresh_state()
	gs.ap = 12
	gs.day = 5
	gs.time_of_day = "evening"
	var job_result: Dictionary = JobServiceScript.new().start_job(gs, "errand_runner", {"same_district": true})
	assert_true(bool(job_result.get("ok", false)), "errand_runner job still settles")
	assert_true(_active_ids(gs).has("intel_errand_shadow_001"), "errand_runner grants a real R26 intel instead of an intel_stub")
	assert_true(_result_intel_ids(job_result).has("intel_errand_shadow_001"), "errand_runner result surfaces the granted intel id for UI feedback")
	assert_true(_result_intel_texts(job_result).size() == 1 and _has_cjk(str(_result_intel_texts(job_result)[0])), "errand_runner result surfaces player-facing intel text")

	var drill = DrillRunnerScript.new()
	var tavern_result: Dictionary = drill.resolve_drill(gs, "tavern_brag", {
		"satisfied_rule_ids": ["name_ports", "tell_one_loss", "avoid_church_boast"],
	})
	assert_true(bool(tavern_result.get("ok", false)), "tavern_brag drill settles")
	assert_true(_active_ids(gs).has("intel_tavern_brag_001"), "tavern_brag grants first tavern intel")
	assert_true(_active_ids(gs).has("intel_tavern_brag_002"), "tavern_brag grants second tavern intel")
	assert_eq(_result_intel_ids(tavern_result), ["intel_tavern_brag_001", "intel_tavern_brag_002"], "tavern_brag result surfaces both granted intel ids")
	assert_true(_result_intel_texts(tavern_result).size() == 2, "tavern_brag result surfaces both player-facing intel texts")

	var smuggle_result: Dictionary = drill.resolve_drill(gs, "smuggle_role", {
		"satisfied_rule_ids": ["official_tone", "ask_manifest_first", "avoid_smuggler_jargon"],
	})
	assert_true(bool(smuggle_result.get("ok", false)), "smuggle_role drill settles")
	assert_true(_active_ids(gs).has("intel_smuggle_mainline_001"), "smuggle_role grants mainline intel")
	assert_true(_result_intel_ids(smuggle_result).has("intel_smuggle_mainline_001"), "smuggle_role result surfaces granted mainline intel id")
	gs.queue_free()


func _new_service():
	var script = load(INTEL_SERVICE_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "IntelService script loads and can instantiate")
		return null
	var service = script.new()
	assert_true(service.has_method("grant"), "IntelService exposes grant")
	assert_true(service.has_method("cleanup_expired"), "IntelService exposes cleanup_expired")
	assert_true(service.has_method("apply"), "IntelService exposes apply")
	if not service.has_method("grant") or not service.has_method("cleanup_expired") or not service.has_method("apply"):
		return null
	return service


func _sample_intel(intel_id: String, expires_after: String) -> Dictionary:
	return {
		"id": intel_id,
		"category": "tower_hint",
		"display_text": intel_id,
		"source_type": "unit_test",
		"source_district": "shadow_alley",
		"expires_after": expires_after,
		"apply_target": {"kind": "tower_intel.enemy_intent_reveal", "payload": {"tower_template": "shadow_alley_small", "floor_index_min": 0, "floor_index_max": 0}},
		"truth_value": 100,
	}


func _fresh_state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _active_rumors(game_state) -> Array:
	var value: Variant = game_state.get("active_rumors")
	return value if value is Array else []


func _heard_history(game_state) -> Dictionary:
	var value: Variant = game_state.get("heard_rumor_history")
	return value if value is Dictionary else {}


func _active_ids(game_state) -> Array:
	var ids: Array = []
	for intel in _active_rumors(game_state):
		if intel is Dictionary:
			ids.append(str(intel.get("id", "")))
	return ids


func _result_intel_ids(result: Dictionary) -> Array:
	var ids: Variant = result.get("granted_intel_ids", [])
	return ids if ids is Array else []


func _result_intel_texts(result: Dictionary) -> Array:
	var texts: Variant = result.get("granted_intel_texts", [])
	return texts if texts is Array else []


func _intel_applied(game_state, intel_id: String) -> bool:
	for intel in _active_rumors(game_state):
		if intel is Dictionary and str(intel.get("id", "")) == intel_id:
			return bool(intel.get("has_applied", false))
	return false


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
