class_name ResidualIdentity
extends RefCounted

const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

var id: String = ""
var name: String = ""
var source_npc: String = ""
var source_persona: Dictionary = {}
var created_at_day: int = 0
var expires_at_day: int = 0
var allowed_locations: Array[String] = []
var uses_remaining: int = 1
var used_targets: Array[String] = []
var _ai_gm_service = null


static func from_dict(data: Dictionary):
	var script = load("res://scripts/world/residual_identity.gd")
	var identity = script.new()
	identity.id = str(data.get("id", ""))
	identity.name = str(data.get("name", data.get("display_name", "")))
	identity.source_npc = str(data.get("source_npc", ""))
	identity.source_persona = _dict(data.get("source_persona", {}))
	identity.created_at_day = int(data.get("created_at_day", 0))
	identity.expires_at_day = int(data.get("expires_at_day", 0))
	identity.allowed_locations = _string_array(data.get("allowed_locations", []))
	identity.uses_remaining = int(data.get("uses_remaining", 1))
	identity.used_targets = _string_array(data.get("used_targets", []))
	return identity


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"source_npc": source_npc,
		"source_persona": source_persona.duplicate(true),
		"created_at_day": created_at_day,
		"expires_at_day": expires_at_day,
		"allowed_locations": Array(allowed_locations),
		"uses_remaining": uses_remaining,
		"used_targets": Array(used_targets),
	}


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func request_residual_identity_create_ai_gm(game_state) -> String:
	return _request_residual_identity_ai_gm("residual_identity_create", game_state)


func request_residual_identity_expire_ai_gm(game_state) -> String:
	return _request_residual_identity_ai_gm("residual_identity_expire", game_state)


func _request_residual_identity_ai_gm(scene_id: String, game_state) -> String:
	var days_remaining := maxi(0, int(expires_at_day) - _state_int(game_state, "day", int(expires_at_day)))
	if scene_id == "residual_identity_expire":
		days_remaining = 0
	var ctx = PromptContextScript.new()
	ctx.scene = scene_id
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"identity_id": id,
		"name": name,
		"source_npc": source_npc,
		"created_at_day": int(created_at_day),
		"expires_at_day": int(expires_at_day),
		"uses_remaining": int(uses_remaining),
		"days_remaining": days_remaining,
	}
	ctx.fallback_template_pool = "RESIDUAL_IDENTITY_TEMPLATES"
	return _call_ai_gm(ctx)


func is_expired(current_day: int) -> bool:
	return expires_at_day > 0 and int(current_day) > expires_at_day


func can_use_for(target_id: String, current_day: int) -> bool:
	if uses_remaining <= 0:
		return false
	if is_expired(current_day):
		return false
	return allowed_locations.is_empty() or allowed_locations.has(target_id)


func consume_for(target_id: String, current_day: int, game_state = null, npc_state = null) -> Dictionary:
	if is_expired(current_day):
		_adjust_awareness(game_state, 5, "residual_identity_expired:%s" % id)
		return {
			"ok": false,
			"reason": "identity_expired",
			"identity": id,
			"acting_check_required": true,
		}
	if not can_use_for(target_id, current_day):
		return {"ok": false, "reason": "identity_unavailable", "identity": id}
	var repeated := used_targets.has(target_id)
	uses_remaining = maxi(0, uses_remaining - 1)
	if not repeated:
		used_targets.append(target_id)
		return {"ok": true, "identity": id}
	_adjust_awareness(game_state, 2, "residual_identity_repeat:%s" % id)
	if npc_state != null and npc_state.has_method("get"):
		npc_state.suspicion = clampi(int(npc_state.suspicion) + 30, 0, 100)
	return {"ok": true, "identity": id, "risk": "repeat_target"}


static func _adjust_awareness(game_state, delta: int, source: String) -> void:
	if game_state == null:
		return
	if game_state.has_method("adjust_church_awareness"):
		game_state.adjust_church_awareness(delta, source)
	else:
		game_state.church_awareness = clampi(int(game_state.church_awareness) + delta, 0, 100)


func _call_ai_gm(ctx) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var service = _resolve_ai_gm_service()
	if service == null or not service.has_method("call_ai_gm"):
		return ""
	return str(service.call_ai_gm(ctx))


func _resolve_ai_gm_service():
	if _ai_gm_service != null:
		return _ai_gm_service
	_ai_gm_service = AIGMServiceScript.new()
	return _ai_gm_service


func _ai_gm_player_state(game_state) -> Dictionary:
	return {
		"sequence": _state_int(game_state, "sequence", 9),
		"pollution": _state_int(game_state, "pollution", 0),
		"pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"cycle": _state_int(game_state, "cycle", 1),
		"day": _state_int(game_state, "day", 1),
		"time_of_day": _state_string(game_state, "time_of_day", "morning"),
	}


static func _state_int(game_state, field_name: String, fallback: int) -> int:
	if game_state == null:
		return fallback
	var value = game_state.get(field_name)
	return fallback if value == null else int(value)


static func _state_string(game_state, field_name: String, fallback: String) -> String:
	if game_state == null:
		return fallback
	var value = game_state.get(field_name)
	return fallback if value == null else str(value)


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
