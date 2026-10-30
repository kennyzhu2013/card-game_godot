class_name SleepService
extends RefCounted

# R19 §3 入梦：推日历 / 重置 AP / 推时段 + 钩子（自动存档 + 商店每日刷新）
# 调用方：床（R19）、调试面板的"推进天"、退出主菜单（自动存档而非推日）

const SaveStoreScript = preload("res://scripts/state/save_store.gd")
const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const DayCycleServiceScript = preload("res://scripts/world/day_cycle_service.gd")
const WeatherEffectsApplierScript = preload("res://scripts/state/weather_effects_applier.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")

const DREAM_FALLBACK_POOL_PATH := "res://data/dreams/fallback_pool.json"
const WEATHER_TABLE_PATH := "res://data/weather/weather_table.json"
const DEFAULT_BASE_AP_MAX := 12


static func sleep_to_next_day(game_state, days: int = 1, auto_save_path: String = SaveStoreScript.AUTO_PATH, weather_roll: float = -1.0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var last_payment: Dictionary = {}
	var last_deficit_result: Dictionary = {}
	var last_dream: Dictionary = {}
	var last_visitor: Dictionary = {}
	var last_weather: Dictionary = {}
	var last_day_hook: Dictionary = {}
	var last_weather_pollution_delta := 0
	var last_total_pollution_delta := 0
	_ensure_sleep_base_ap_max(game_state)
	for i in range(max(1, days)):
		var sleep_weather_id := str(game_state.current_weather)
		last_payment = ApServiceScript.spend_sleep_cost_or_deficit(game_state)
		game_state.day = int(game_state.day) + 1
		game_state.time_of_day = "morning"
		_restore_hub_mana(game_state)
		_expire_r20_perceptions(game_state)
		last_weather = _apply_weather_forecast_intel(game_state)
		if last_weather.is_empty():
			last_weather = roll_weather(weather_roll)
		if not last_weather.is_empty():
			game_state.current_weather = str(last_weather.get("weather_id", ""))
		IntelServiceScript.new().cleanup_expired(game_state)
		if game_state.has_method("set_meta"):
			game_state.set_meta("force_sleep_pending", false)
		if game_state.has_method("emit_day_changed"):
			game_state.emit_day_changed()
		last_day_hook = DayCycleServiceScript.apply_day_hooks(game_state)
		CommissionServiceScript.new().refresh_daily(game_state)
		last_deficit_result = apply_ap_deficit(game_state, int(last_payment.get("deficit", 0)))
		last_weather_pollution_delta = _apply_weather_pollution(game_state, sleep_weather_id)
		last_total_pollution_delta = int(last_deficit_result.get("pollution_delta", 0)) + last_weather_pollution_delta
		last_dream = dream_for_state(game_state)
		last_visitor = morning_visitor_for_state(game_state)
		if game_state.has_method("refill_ap_to_max"):
			game_state.refill_ap_to_max()
		else:
			game_state.ap = int(game_state.ap_max)
		# 重置：苦修山远途今日已访问 / 黑市每日刷新计数
		game_state.set_meta("ascetic_visited_today", false)
		if game_state.has_method("clear_daily_action_counters"):
			game_state.clear_daily_action_counters()
		else:
			game_state.meditation_count_today = 0
		if game_state.has_method("reset_daily_encounters"):
			game_state.reset_daily_encounters()
		else:
			game_state.set("last_encounter_today", {"global": 0, "districts": {}})
		_reset_daily_shop_counters(game_state)
	var ok: bool = SaveStoreScript.save_auto(game_state, auto_save_path)
	return {
		"ok": true,
		"auto_save_ok": ok,
		"day": int(game_state.day),
		"ap_cost": int(last_payment.get("cost", 0)),
		"ap_paid": int(last_payment.get("paid", 0)),
		"ap_deficit": int(last_payment.get("deficit", 0)),
		"ap_max_penalty": int(last_deficit_result.get("ap_max_penalty", 0)),
		"pollution_delta": last_total_pollution_delta,
		"weather_pollution_delta": last_weather_pollution_delta,
		"weather": last_weather,
		"day_hook": last_day_hook,
		"dream": last_dream,
		"visitor": last_visitor,
	}


static func roll_weather(roll: float = -1.0) -> Dictionary:
	var table := _load_weather_table()
	if table.is_empty():
		return {}
	var value := roll
	if value < 0.0:
		value = randf()
	value = clampf(value, 0.0, 0.999999)
	var running := 0.0
	var fallback: Dictionary = {}
	for entry in table:
		if not entry is Dictionary:
			continue
		fallback = entry
		running += float(entry.get("prob", 0.0))
		if value < running:
			return entry.duplicate(true)
	return fallback.duplicate(true)


static func check_force_sleep(game_state, auto_save_path: String = SaveStoreScript.AUTO_PATH) -> Dictionary:
	if game_state == null:
		return {"ok": false, "forced": false, "reason": "missing_state"}
	if str(game_state.time_of_day) != "night":
		return {"ok": true, "forced": false, "reason": "not_night", "time_of_day": str(game_state.time_of_day)}
	if not bool(game_state.get_meta("force_sleep_pending", false)):
		return {"ok": true, "forced": false, "reason": "night_playable", "time_of_day": str(game_state.time_of_day)}
	var result: Dictionary = sleep_to_next_day(game_state, 1, auto_save_path)
	result["forced"] = true
	result["reason"] = "forced_sleep"
	return result


static func apply_ap_deficit(game_state, deficit: int) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	_ensure_sleep_base_ap_max(game_state)
	var base_ap_max := int(game_state.get_meta("sleep_base_ap_max", DEFAULT_BASE_AP_MAX))
	var clamped_deficit := clampi(deficit, 0, 3)
	var ap_max_penalty := 0
	var pollution_delta := 0
	if clamped_deficit == 1:
		ap_max_penalty = 1
	elif clamped_deficit >= 2:
		ap_max_penalty = 2
		pollution_delta = 3
	if game_state.has_method("set_ap_max"):
		game_state.set_ap_max(maxi(0, base_ap_max - ap_max_penalty))
	else:
		game_state.ap_max = maxi(0, base_ap_max - ap_max_penalty)
	if pollution_delta > 0:
		_apply_pollution_value(game_state, int(game_state.pollution) + pollution_delta, ["sleep_ap_deficit"])
	if game_state.has_method("record_sleep_deficit"):
		game_state.record_sleep_deficit(clamped_deficit)
	else:
		game_state.last_sleep_ap_deficit = clamped_deficit
	return {
		"ok": true,
		"deficit": clamped_deficit,
		"ap_max_penalty": ap_max_penalty,
		"pollution_delta": pollution_delta,
		"ap_max": int(game_state.ap_max),
	}


static func dream_for_state(game_state) -> Dictionary:
	if game_state == null:
		return {}
	var state_stage := _pollution_stage(int(game_state.pollution))
	var stage := clampi(state_stage, 0, 4)
	game_state.pollution_stage = state_stage
	var pool := _load_dream_pool()
	for entry in pool:
		if entry is Dictionary and int(entry.get("pollution_stage", -1)) == stage:
			return _attach_dream_ai_gm(game_state, entry.duplicate(true), stage)
	var fallback := {
		"pollution_stage": stage,
		"title": "静梦",
		"text": "你睡得很沉。醒来时，窗外的声音已经远了。",
	}
	return _attach_dream_ai_gm(game_state, fallback, stage)


static func morning_visitor_for_state(game_state) -> Dictionary:
	if game_state == null:
		return {}
	if int(game_state.pollution) >= 80:
		return {
			"id": "pendulum_message",
			"display_name": "钟摆托人捎信",
			"source_npc_id": "pendulum",
			"time_of_day": str(game_state.time_of_day),
			"text": "钟摆让人带来一张短笺：你必须停下。",
		}
	return {
		"id": "old_li_breakfast",
		"display_name": "老李",
		"time_of_day": "morning",
		"text": "老李把一份温热的早餐放在门口，只说今天别空着肚子出门。",
	}


static func auto_save_only(game_state, auto_save_path: String = SaveStoreScript.AUTO_PATH) -> bool:
	if game_state == null:
		return false
	return SaveStoreScript.save_auto(game_state, auto_save_path)


static func _reset_daily_shop_counters(game_state) -> void:
	for shop_id in game_state.shop_inventories:
		var inv = game_state.shop_inventories[shop_id]
		if inv != null:
			inv.refresh_count_today = 0
			# 标记需要次日重 roll；具体 roll 在打开商店时按 last_refresh_day != day 触发
			inv.last_refresh_day = -1


static func _restore_hub_mana(game_state) -> void:
	if game_state == null:
		return
	var max_value := int(game_state.get("hub_mana_max")) if _has_property(game_state, "hub_mana_max") else 10
	var current := int(game_state.get("hub_mana")) if _has_property(game_state, "hub_mana") else 5
	game_state.set("hub_mana", clampi(current + 3, 0, max_value))


static func _expire_r20_perceptions(game_state) -> void:
	if game_state == null:
		return
	var relations = game_state.get("npc_relations")
	if not relations is Dictionary:
		return
	for npc_id in relations.keys():
		var state = relations[npc_id]
		if state == null or not state.has_method("get"):
			continue
		var expires_at := int(state.get("perception_expires_at"))
		if expires_at > 0 and int(game_state.day) >= expires_at:
			state.set("active_perception", "harvey")
			state.set("perception_expires_at", 0)


static func _has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false
	for entry in obj.get_property_list():
		if str(entry.get("name", "")) == property_name:
			return true
	return false


static func _ensure_sleep_base_ap_max(game_state) -> void:
	if game_state == null or not game_state.has_method("set_meta"):
		return
	var current_max := int(game_state.ap_max)
	var previous := int(game_state.get_meta("sleep_base_ap_max", DEFAULT_BASE_AP_MAX))
	game_state.set_meta("sleep_base_ap_max", maxi(previous, maxi(current_max, DEFAULT_BASE_AP_MAX)))


static func _apply_weather_pollution(game_state, weather_id: String) -> int:
	if game_state == null:
		return 0
	var delta := WeatherEffectsApplierScript.get_global_modifier(weather_id, "pollution")
	delta += WeatherEffectsApplierScript.get_bonus(weather_id, str(game_state.pathway), "pollution")
	if delta == 0:
		return 0
	_apply_pollution_value(game_state, int(game_state.pollution) + delta, ["sleep_weather_%s" % weather_id])
	return delta


static func _attach_dream_ai_gm(game_state, dream: Dictionary, stage: int) -> Dictionary:
	if game_state != null and game_state.has_method("request_dream_ai_gm"):
		dream["ai_gm_text"] = str(game_state.call("request_dream_ai_gm", stage, dream))
	return dream


static func _apply_pollution_value(game_state, value: int, recent_actions: Array = []) -> void:
	if game_state == null:
		return
	var next_value := clampi(value, 0, 100)
	if game_state.has_method("set_pollution"):
		game_state.call("set_pollution", next_value, recent_actions)
	else:
		game_state.pollution = next_value
		game_state.pollution_stage = _pollution_stage(next_value)


static func _apply_weather_forecast_intel(game_state) -> Dictionary:
	if game_state == null:
		return {}
	var active_value: Variant = game_state.get("active_rumors")
	if not active_value is Array:
		return {}
	var active: Array = active_value
	if active.is_empty():
		return {}
	var chosen_index := -1
	var chosen_intel: Dictionary = {}
	for i in range(active.size()):
		var item: Variant = active[i]
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		if bool(intel.get("has_applied", false)):
			continue
		var target: Variant = intel.get("apply_target", {})
		if not target is Dictionary:
			continue
		if str((target as Dictionary).get("kind", "")) != "weather_forecast.next_day":
			continue
		var payload: Dictionary = _dict((target as Dictionary).get("payload", {}))
		var predicted_weather_id := str(payload.get("predicted_weather_id", ""))
		if predicted_weather_id == "":
			continue
		if chosen_index == -1 or int(intel.get("truth_value", 0)) > int(chosen_intel.get("truth_value", 0)):
			chosen_index = i
			chosen_intel = intel.duplicate(true)
	if chosen_index < 0:
		return {}
	var chosen_target: Dictionary = _dict(chosen_intel.get("apply_target", {}))
	var chosen_payload: Dictionary = _dict(chosen_target.get("payload", {}))
	var predicted := str(chosen_payload.get("predicted_weather_id", ""))
	if predicted == "":
		return {}
	chosen_intel["has_applied"] = true
	active[chosen_index] = chosen_intel
	game_state.set("active_rumors", active)
	return {
		"weather_id": predicted,
		"source": "intel_forecast",
		"forecast_intel_id": str(chosen_intel.get("id", "")),
		"truth_value": int(chosen_intel.get("truth_value", 0)),
	}


static func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _load_dream_pool() -> Array:
	if not FileAccess.file_exists(DREAM_FALLBACK_POOL_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DREAM_FALLBACK_POOL_PATH))
	return parsed if parsed is Array else []


static func _load_weather_table() -> Array:
	if not FileAccess.file_exists(WEATHER_TABLE_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(WEATHER_TABLE_PATH))
	return parsed if parsed is Array else []


static func _pollution_stage(value: int) -> int:
	if value >= 100:
		return 5
	if value >= 95:
		return 4
	if value >= 80:
		return 3
	if value >= 50:
		return 2
	if value >= 30:
		return 1
	return 0
