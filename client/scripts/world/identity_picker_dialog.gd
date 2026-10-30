class_name IdentityPickerDialog
extends RefCounted

const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const ResidualIdentityScript = preload("res://scripts/world/residual_identity.gd")


func choose_identity_for_npc(npc_id: String, source: Variant = null, _state: Variant = null) -> String:
	if not _is_game_state(source):
		return "harvey"
	prune_expired_identities(source)
	var selected := str(source.get_meta("selected_identity_id", "")) if source.has_meta("selected_identity_id") else ""
	if selected != "" and options_for_npc(npc_id, source).has(selected):
		return selected
	return "harvey"


func choose_identity_for_location(location_id: String, source: Variant = null, _state: Variant = null) -> String:
	if not _is_game_state(source):
		return "harvey"
	prune_expired_identities(source)
	var selected := str(source.get_meta("selected_identity_id", "")) if source.has_meta("selected_identity_id") else ""
	if selected != "" and options_for_location(location_id, source).has(selected):
		return selected
	return "harvey"


func options_for_npc(npc_id: String, source: Variant = null) -> Array[String]:
	var options: Array[String] = ["harvey"]
	if not _is_game_state(source):
		return options
	var identities = source.get("residual_identities")
	if not identities is Array:
		return options
	for raw_identity in identities:
		var identity = _identity_from_variant(raw_identity)
		if identity == null:
			continue
		if identity.can_use_for(npc_id, int(source.day)):
			options.append(str(identity.id))
	return options


func use_identity_for_npc(npc_id: String, game_state, identity_id: String) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_game_state"}
	if identity_id == "" or identity_id == "harvey":
		var state = _ensure_state(game_state, npc_id)
		state.dialogue_state["active_identity"] = "harvey"
		return {"ok": true, "identity": "harvey"}
	var identity = _find_identity(game_state, identity_id)
	if identity == null:
		return {"ok": false, "reason": "identity_not_found", "identity": identity_id}
	var npc_state = _ensure_state(game_state, npc_id)
	var result: Dictionary = identity.consume_for(npc_id, int(game_state.day), game_state, npc_state)
	if bool(result.get("ok", false)):
		npc_state.dialogue_state["active_identity"] = identity_id
		if game_state.has_meta("selected_identity_id"):
			game_state.remove_meta("selected_identity_id")
		if int(identity.uses_remaining) <= 0:
			result = _merge_expire_result(result, expire_identity(game_state, identity_id, "uses_exhausted"))
	elif str(result.get("reason", "")) == "identity_expired":
		result = _merge_expire_result(result, expire_identity(game_state, identity_id, "time_expired"))
	return result


func options_for_location(location_id: String, game_state) -> Array[String]:
	var options: Array[String] = ["harvey"]
	if not _is_game_state(game_state):
		return options
	var identities = game_state.get("residual_identities")
	if not identities is Array:
		return options
	for raw_identity in identities:
		var identity = _identity_from_variant(raw_identity)
		if identity != null and identity.can_use_for(location_id, int(game_state.day)):
			options.append(str(identity.id))
	return options


func use_identity_for_location(location_id: String, game_state, identity_id: String) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_game_state"}
	if identity_id == "" or identity_id == "harvey":
		game_state.set_meta("active_location_identity", "harvey")
		return {"ok": true, "identity": "harvey"}
	var identity = _find_identity(game_state, identity_id)
	if identity == null:
		return {"ok": false, "reason": "identity_not_found", "identity": identity_id}
	var result: Dictionary = identity.consume_for(location_id, int(game_state.day), game_state, null)
	if bool(result.get("ok", false)):
		game_state.set_meta("active_location_identity", identity_id)
		if game_state.has_meta("selected_identity_id"):
			game_state.remove_meta("selected_identity_id")
		if int(identity.uses_remaining) <= 0:
			result = _merge_expire_result(result, expire_identity(game_state, identity_id, "uses_exhausted"))
	elif str(result.get("reason", "")) == "identity_expired":
		result = _merge_expire_result(result, expire_identity(game_state, identity_id, "time_expired"))
	return result


func prune_expired_identities(game_state, reason: String = "time_expired") -> Dictionary:
	if not _is_game_state(game_state):
		return {"ok": false, "reason": "missing_game_state", "expired_identity_ids": []}
	var identities = game_state.get("residual_identities")
	if not identities is Array:
		return {"ok": true, "expired_identity_ids": []}
	var current_day := int(game_state.day)
	var targets: Array[Dictionary] = []
	for raw_identity in identities:
		var identity = _identity_from_variant(raw_identity)
		if identity == null:
			continue
		var expire_reason := ""
		if identity.is_expired(current_day):
			expire_reason = reason
		elif int(identity.uses_remaining) <= 0:
			expire_reason = "uses_exhausted"
		if expire_reason != "":
			targets.append({"id": str(identity.id), "reason": expire_reason})
	var result := {"ok": true, "expired_identity_ids": []}
	for target in targets:
		result = _merge_expire_result(result, expire_identity(game_state, str(target.get("id", "")), str(target.get("reason", reason))))
	return result


func expire_identity(game_state, identity_id: String, reason: String = "time_expired") -> Dictionary:
	if not _is_game_state(game_state):
		return {"ok": false, "reason": "missing_game_state", "identity": identity_id, "expired_identity_ids": []}
	var identities = game_state.get("residual_identities")
	if not identities is Array:
		return {"ok": false, "reason": "missing_residual_identities", "identity": identity_id, "expired_identity_ids": []}
	for i in range(identities.size() - 1, -1, -1):
		var identity = _identity_from_variant(identities[i])
		if identity == null or str(identity.id) != identity_id:
			continue
		identities.remove_at(i)
		var ai_gm_text := str(identity.request_residual_identity_expire_ai_gm(game_state))
		return {
			"ok": true,
			"identity": identity_id,
			"expire_reason": reason,
			"expired_identity_ids": [identity_id],
			"ai_gm_text": ai_gm_text,
			"expire_results": [{
				"identity": identity_id,
				"reason": reason,
				"ai_gm_text": ai_gm_text,
			}],
		}
	return {"ok": false, "reason": "identity_not_found", "identity": identity_id, "expired_identity_ids": []}


func _find_identity(game_state, identity_id: String):
	var identities = game_state.get("residual_identities")
	if not identities is Array:
		return null
	for i in identities.size():
		var identity = _identity_from_variant(identities[i])
		if identity == null:
			continue
		if str(identity.id) == identity_id:
			if identities[i] is Dictionary:
				identities[i] = identity
			return identity
	return null


func _identity_from_variant(value):
	if value == null:
		return null
	if value is Dictionary:
		return ResidualIdentityScript.from_dict(value)
	if value is Object and value.has_method("can_use_for") and value.has_method("consume_for"):
		return value
	return null


func _ensure_state(game_state, npc_id: String):
	if not game_state.npc_relations.has(npc_id):
		game_state.npc_relations[npc_id] = NpcKnowledgeStateScript.new()
	var state = game_state.npc_relations[npc_id]
	if state is Dictionary:
		state = NpcKnowledgeStateScript.from_dict(state)
		game_state.npc_relations[npc_id] = state
	return state


func _is_game_state(value) -> bool:
	return value != null and value is Object and value.has_method("get") and _has_property(value, "residual_identities")


func _has_property(obj, property_name: String) -> bool:
	for entry in obj.get_property_list():
		if str(entry.get("name", "")) == property_name:
			return true
	return false


func _merge_expire_result(base: Dictionary, expiry: Dictionary) -> Dictionary:
	if expiry.is_empty() or not bool(expiry.get("ok", false)):
		return base
	var result := base.duplicate(true)
	var ids: Array[String] = _string_array(result.get("expired_identity_ids", []))
	for id in _string_array(expiry.get("expired_identity_ids", [])):
		if id != "" and not ids.has(id):
			ids.append(id)
	result["expired_identity_ids"] = ids
	if not result.has("expire_reason") and expiry.has("expire_reason"):
		result["expire_reason"] = str(expiry.get("expire_reason", ""))
	var text := str(expiry.get("ai_gm_text", ""))
	if text != "":
		if str(result.get("ai_gm_text", "")) == "":
			result["ai_gm_text"] = text
		else:
			result["ai_gm_text"] = "%s\n%s" % [str(result.get("ai_gm_text", "")), text]
	var expire_results: Array = result.get("expire_results", []) if result.get("expire_results", []) is Array else []
	var extra_results: Array = expiry.get("expire_results", []) if expiry.get("expire_results", []) is Array else []
	for entry in extra_results:
		expire_results.append(entry)
	result["expire_results"] = expire_results
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
