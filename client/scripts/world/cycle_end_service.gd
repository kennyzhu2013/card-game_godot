class_name CycleEndService
extends RefCounted

const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")


static func complete_cycle(game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var completed_cycle := int(game_state.cycle)
	var summary := _summary_for_cycle(completed_cycle)
	var ai_gm_text := request_cycle_summary_ai_gm(game_state, completed_cycle, {
		"days_played": int(game_state.day),
		"sequence_changes": [],
		"key_events": _completed_mainline_nodes(game_state),
	})
	if game_state.has_method("set_meta"):
		game_state.set_meta("cycle_end_summary", summary)
		game_state.set_meta("cycle_end_ai_gm_text", ai_gm_text)
	if game_state.has_method("reset"):
		game_state.reset()
	else:
		game_state.cycle = completed_cycle + 1
		game_state.day = 1
		game_state.time_of_day = "morning"
	if game_state.has_method("emit_day_changed"):
		game_state.emit_day_changed()
	return {
		"ok": true,
		"completed_cycle": completed_cycle,
		"cycle": int(game_state.cycle),
		"day": int(game_state.day),
		"summary": summary,
		"ai_gm_text": ai_gm_text,
	}


static func request_cycle_summary_ai_gm(game_state, completed_cycle: int, summary_data: Dictionary = {}, service = null) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "cycle_summary"
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"cycle": completed_cycle,
		"days_played": int(summary_data.get("days_played", _state_int(game_state, "day", 14))),
		"sequence_changes": _string_array(summary_data.get("sequence_changes", [])),
		"key_events": _string_array(summary_data.get("key_events", [])),
	}
	ctx.fallback_template_pool = "CYCLE_SUMMARY_TEMPLATES"
	return _call_ai_gm(ctx, service)


static func _call_ai_gm(ctx, service = null) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var resolved_service = service
	if resolved_service == null:
		resolved_service = AIGMServiceScript.new()
	if resolved_service == null or not resolved_service.has_method("call_ai_gm"):
		return ""
	return str(resolved_service.call_ai_gm(ctx))


static func _ai_gm_player_state(game_state) -> Dictionary:
	return {
		"sequence": _state_int(game_state, "sequence", 9),
		"pollution": _state_int(game_state, "pollution", 0),
		"pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"cycle": _state_int(game_state, "cycle", 1),
		"day": _state_int(game_state, "day", 1),
		"time_of_day": _state_string(game_state, "time_of_day", "morning"),
	}


static func _completed_mainline_nodes(game_state) -> Array[String]:
	if game_state == null:
		return []
	var daodian: Variant = game_state.get("daodian")
	if not daodian is Dictionary:
		return []
	return _string_array((daodian as Dictionary).get("completed_main_story_nodes", []))


static func _state_int(game_state, key: String, default_value: int) -> int:
	if game_state == null:
		return default_value
	var value = game_state.get(key)
	if value == null:
		return default_value
	return int(value)


static func _state_string(game_state, key: String, default_value: String) -> String:
	if game_state == null:
		return default_value
	var value = game_state.get(key)
	if value == null:
		return default_value
	return str(value)


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _summary_for_cycle(completed_cycle: int) -> String:
	return "第%d周目结算占位：十四天的记录被道典封存。哈维在锈河城的街巷、塔门、教会目光与半月之约之间留下可回放的灰色回声；本占位文本等待 AI GM 生成约二百字结算，后续会汇总主线节点、污染、教会查觉、NPC关系、委托与卡库继承，并给出下一周目的醒来提示。" % completed_cycle
