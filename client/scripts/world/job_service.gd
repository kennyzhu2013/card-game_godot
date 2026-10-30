class_name JobService
extends RefCounted

const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const SequenceExpServiceScript = preload("res://scripts/sequence/sequence_exp_service.gd")
const TimeAdvanceServiceScript = preload("res://scripts/world/time_advance_service.gd")
const HotspotResolverScript = preload("res://scripts/world/hotspot_resolver.gd")
const ChartGeneratorScript = preload("res://scripts/battle/phigros/stage/chart_generator.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")

const JOB_DEFINITION_PATHS := {
	"factory_shift": "res://data/minigames/jobs/factory_shift.json",
	"dock_shift": "res://data/minigames/jobs/dock_shift.json",
	"fishing_shift": "res://data/minigames/jobs/fishing_shift.json",
	"errand_runner": "res://data/minigames/jobs/errand_runner.json",
	"worship_observation": "res://data/minigames/jobs/worship_observation.json",
	"mountain_solitary_walk": "res://data/minigames/jobs/mountain_solitary_walk.json",
}

const JOB_INTEL_REWARDS := {
	"errand_runner": ["intel_errand_shadow_001"],
}


func load_job_definition(job_id: String) -> Dictionary:
	var path := str(JOB_DEFINITION_PATHS.get(job_id, ""))
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed.duplicate(true)
	return {}


func can_start(game_state, job_id: String, options: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var definition := load_job_definition(job_id)
	if definition.is_empty():
		return {"ok": false, "reason": "missing_definition", "id": job_id}
	if job_id == "worship_observation" and int(game_state.pollution) >= 50:
		return {"ok": false, "reason": "pollution_blocked", "id": job_id}
	var failed_precondition := _failed_precondition(definition, game_state)
	if failed_precondition != "":
		return {"ok": false, "reason": "precondition_failed", "precondition": failed_precondition}
	var ap_cost := _ap_cost_for(definition, options)
	if int(game_state.ap) < ap_cost:
		return {"ok": false, "reason": "ap_short", "cost": ap_cost, "remaining": int(game_state.ap)}
	var daily_limit := _int_value(definition.get("daily_limit", 0))
	if daily_limit > 0 and _count_for_limit(game_state, "daily", job_id) >= daily_limit:
		return {"ok": false, "reason": "daily_limit", "limit": daily_limit}
	var weekly_limit := _int_value(definition.get("weekly_limit", 0))
	if weekly_limit > 0 and _count_for_limit(game_state, "weekly", job_id) >= weekly_limit:
		return {"ok": false, "reason": "weekly_limit", "limit": weekly_limit}
	var cycle_limit := _int_value(definition.get("cycle_limit", 0))
	if cycle_limit > 0 and _count_for_limit(game_state, "cycle", job_id) >= cycle_limit:
		return {"ok": false, "reason": "cycle_limit", "limit": cycle_limit}
	return {"ok": true, "definition": definition, "ap_cost": ap_cost}


func start_job(game_state, job_id: String, options: Dictionary = {}) -> Dictionary:
	var check := can_start(game_state, job_id, options)
	if not bool(check.get("ok", false)):
		return check
	var definition: Dictionary = check.get("definition", {})
	var ap_cost := int(check.get("ap_cost", 0))
	var spend: Dictionary = ApServiceScript.try_spend(game_state, ap_cost, "job:%s" % job_id)
	if not bool(spend.get("ok", false)):
		return spend
	var grade := _grade_for(definition, options)
	var rewards := _rewards_for_grade(definition, grade)
	var reward_result := _apply_rewards(game_state, rewards, job_id)
	_record_use(game_state, job_id)
	var time_result: Dictionary = TimeAdvanceServiceScript.advance_for_action(game_state, "job")
	var result := {
		"ok": true,
		"id": job_id,
		"job_id": job_id,
		"grade": grade,
		"mechanic": str(definition.get("mechanic", "")),
		"ap_cost": ap_cost,
		"rewards": rewards,
		"ap_remaining": int(game_state.ap),
		"time_result": time_result,
	}
	var chart_notes := _chart_note_count(definition)
	if chart_notes > 0:
		result["chart_note_count"] = chart_notes
	for key in reward_result.keys():
		if not result.has(key):
			result[key] = reward_result[key]
	return result


func available_jobs(game_state, job_ids: Array = []) -> Array:
	var ids := job_ids.duplicate()
	if ids.is_empty():
		ids = JOB_DEFINITION_PATHS.keys()
	var result: Array = []
	for raw_id in ids:
		var job_id := str(raw_id)
		var definition := load_job_definition(job_id)
		if definition.is_empty():
			continue
		var check := can_start(game_state, job_id)
		result.append({
			"id": job_id,
			"display_name": str(definition.get("display_name", job_id)),
			"city": str(definition.get("city", "")),
			"ap_cost": int(definition.get("ap_cost", 0)),
			"mechanic": str(definition.get("mechanic", "")),
			"available": bool(check.get("ok", false)),
			"reason": str(check.get("reason", "")),
		})
	return result


func _failed_precondition(definition: Dictionary, game_state) -> String:
	var preconditions: Variant = definition.get("preconditions", [])
	if not preconditions is Array:
		return ""
	for raw_expression in preconditions:
		var expression := str(raw_expression).strip_edges()
		if expression == "":
			continue
		if not HotspotResolverScript.evaluate_visible_when(expression, game_state):
			return expression
	return ""


func _ap_cost_for(definition: Dictionary, options: Dictionary) -> int:
	if str(definition.get("id", "")) == "errand_runner" and bool(options.get("same_district", false)):
		return int(definition.get("same_district_ap_cost", 0))
	return int(definition.get("ap_cost", 0))


func _grade_for(definition: Dictionary, options: Dictionary) -> String:
	var job_id := str(definition.get("id", ""))
	if options.has("grade"):
		return str(options.get("grade", ""))
	match job_id:
		"dock_shift", "fishing_shift":
			if str(options.get("mode", "cargo")) == "fishing":
				var roll := float(options.get("roll", 1.0))
				if roll < 0.05:
					return "fish_page"
				if roll < 0.50:
					return "fish_material"
				return "fish_lingstones"
			return "cargo_success"
		"errand_runner":
			return "same_district" if bool(options.get("same_district", false)) else "complete"
		_:
			return "perfect"


func _rewards_for_grade(definition: Dictionary, grade: String) -> Array:
	var outcome_table: Variant = definition.get("outcome_table", [])
	if not outcome_table is Array:
		return []
	for outcome in outcome_table:
		if not outcome is Dictionary:
			continue
		if str((outcome as Dictionary).get("grade", "")) != grade:
			continue
		var rewards: Variant = (outcome as Dictionary).get("rewards", [])
		return rewards.duplicate(true) if rewards is Array else []
	return []


func _apply_rewards(game_state, rewards: Array, source_id: String) -> Dictionary:
	var applied: Array = []
	var summary := {}
	for reward in rewards:
		if not reward is Dictionary:
			continue
		var entry: Dictionary = reward
		var amount := int(entry.get("amount", 1))
		match str(entry.get("type", "")):
			"lingstones":
				game_state.lingstones += amount
			"material":
				var material_id := str(entry.get("id", ""))
				if material_id != "":
					game_state.forge_materials[material_id] = int(game_state.forge_materials.get(material_id, 0)) + amount
			"pollution":
				game_state.pollution = clampi(int(game_state.pollution) + amount, 0, 100)
			"church_awareness":
				if game_state.has_method("adjust_church_awareness"):
					game_state.adjust_church_awareness(amount, "job:%s" % source_id)
				else:
					game_state.church_awareness = clampi(int(game_state.church_awareness) + amount, 0, 100)
			"dao_pages":
				game_state.dao_pages += amount
			"sequence_exp":
				var exp_result: Dictionary = SequenceExpServiceScript.add_exp(game_state, amount, source_id)
				summary["base_sequence_exp"] = int(exp_result.get("base_sequence_exp", amount))
				summary["sequence_exp_delta"] = int(exp_result.get("sequence_exp_delta", 0))
				summary["sequence_exp_bonus_percent"] = int(exp_result.get("sequence_exp_bonus_percent", 0))
			"intel_stub":
				_merge_granted_intels(summary, _queue_intel_reward(game_state, source_id, amount))
			_:
				continue
		applied.append(entry.duplicate(true))
	summary["applied_rewards"] = applied
	return summary


func _queue_intel_reward(game_state, source_id: String, amount: int) -> Dictionary:
	var daodian: Dictionary = game_state.daodian if game_state.daodian is Dictionary else {}
	var pending: Array = daodian.get("pending_intel_rewards", []) if daodian.get("pending_intel_rewards", []) is Array else []
	for i in range(maxi(1, amount)):
		pending.append({"source": source_id, "type": "city_intel_stub"})
	daodian["pending_intel_rewards"] = pending
	game_state.daodian = daodian
	return _grant_activity_intels(game_state, source_id, amount)


func _grant_activity_intels(game_state, source_id: String, amount: int) -> Dictionary:
	var ids_result: Array[String] = []
	var text_result: Array[String] = []
	var ids: Array = JOB_INTEL_REWARDS.get(source_id, []) if JOB_INTEL_REWARDS.get(source_id, []) is Array else []
	if ids.is_empty():
		return {"granted_intel_ids": ids_result, "granted_intel_texts": text_result}
	var service = IntelServiceScript.new()
	var limit := mini(maxi(1, amount), ids.size())
	for i in range(limit):
		var intel_id := str(ids[i])
		var grant_result: Dictionary = service.grant(game_state, intel_id, {"source_type": source_id})
		if bool(grant_result.get("ok", false)):
			ids_result.append(intel_id)
			var intel: Dictionary = grant_result.get("intel", {}) if grant_result.get("intel", {}) is Dictionary else {}
			var text := IntelServiceScript.player_display_text(intel)
			if text != "":
				text_result.append(text)
	return {"granted_intel_ids": ids_result, "granted_intel_texts": text_result}


func _merge_granted_intels(target: Dictionary, source: Dictionary) -> void:
	var target_ids: Array = target.get("granted_intel_ids", []) if target.get("granted_intel_ids", []) is Array else []
	var target_texts: Array = target.get("granted_intel_texts", []) if target.get("granted_intel_texts", []) is Array else []
	for id in source.get("granted_intel_ids", []):
		target_ids.append(str(id))
	for text in source.get("granted_intel_texts", []):
		target_texts.append(str(text))
	if not target_ids.is_empty():
		target["granted_intel_ids"] = target_ids
	if not target_texts.is_empty():
		target["granted_intel_texts"] = target_texts


func _chart_note_count(definition: Dictionary) -> int:
	if str(definition.get("mechanic", "")) != "phigros_simple":
		return 0
	var params: Dictionary = definition.get("mechanic_params", {}) if definition.get("mechanic_params", {}) is Dictionary else {}
	var chart_params: Dictionary = params.get("chart_params", params) if params.get("chart_params", params) is Dictionary else {}
	var chart_template := str(params.get("chart_template", "T2"))
	var chart = ChartGeneratorScript.new().generate(chart_template, chart_params, 50)
	if chart == null:
		return 0
	return chart.notes.size()


func _record_use(game_state, job_id: String) -> void:
	var history := _history(game_state)
	_increment(history, "daily", _daily_key(game_state, job_id))
	_increment(history, "weekly", _weekly_key(game_state, job_id))
	_increment(history, "cycle", _cycle_key(game_state, job_id))


func _count_for_limit(game_state, bucket: String, job_id: String) -> int:
	var history := _history(game_state)
	var key := ""
	match bucket:
		"daily":
			key = _daily_key(game_state, job_id)
		"weekly":
			key = _weekly_key(game_state, job_id)
		"cycle":
			key = _cycle_key(game_state, job_id)
		_:
			return 0
	var bucket_data: Dictionary = history.get(bucket, {}) if history.get(bucket, {}) is Dictionary else {}
	return int(bucket_data.get(key, 0))


func _history(game_state) -> Dictionary:
	if not game_state.minigame_history is Dictionary:
		game_state.minigame_history = {}
	for bucket in ["daily", "weekly", "cycle"]:
		if not game_state.minigame_history.has(bucket) or not game_state.minigame_history[bucket] is Dictionary:
			game_state.minigame_history[bucket] = {}
	return game_state.minigame_history


func _increment(history: Dictionary, bucket: String, key: String) -> void:
	var bucket_data: Dictionary = history.get(bucket, {}) if history.get(bucket, {}) is Dictionary else {}
	bucket_data[key] = int(bucket_data.get(key, 0)) + 1
	history[bucket] = bucket_data


func _daily_key(game_state, job_id: String) -> String:
	return "%d:%d:%s" % [int(game_state.cycle), int(game_state.day), job_id]


func _weekly_key(game_state, job_id: String) -> String:
	var week_index := int(floor(float(maxi(1, int(game_state.day)) - 1) / 7.0))
	return "%d:%d:%s" % [int(game_state.cycle), week_index, job_id]


func _cycle_key(game_state, job_id: String) -> String:
	return "%d:%s" % [int(game_state.cycle), job_id]


func _int_value(value: Variant) -> int:
	if value == null:
		return 0
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return int(value)
	return 0
