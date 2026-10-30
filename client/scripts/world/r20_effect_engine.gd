class_name R20EffectEngine
extends RefCounted

const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const ResidualIdentityScript = preload("res://scripts/world/residual_identity.gd")
const R20FieldHookServiceScript = preload("res://scripts/world/r20_field_hook_service.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

const SOCIAL_POLLUTION := {
	"identity_mask": 2,
	"borrow_name": 3,
	"forget_event": 5,
	"read_truth": 3,
	"modify_suspicion": 1,
	"extract_memory": 3,
	"extract_secret": 3,
	"influence_behavior": 3,
}

const SOCIAL_AWARENESS := {
	"identity_mask": 2,
	"borrow_name": 2,
	"forget_event": 2,
	"read_truth": 1,
	"modify_suspicion": 1,
	"extract_memory": 1,
	"extract_secret": 1,
	"influence_behavior": 2,
}

const WORLD_POLLUTION := {
	"alter_drop_table": 3,
	"spawn_event": 4,
	"attract_visitor": 2,
	"modify_node_atmosphere": 3,
	"reveal_hidden_lore": 3,
	"create_residual_identity": 3,
	"alter_npc_state": 4,
	"reveal_npc_relationships": 3,
}

const WORLD_AWARENESS := {
	"alter_drop_table": 3,
	"spawn_event": 3,
	"attract_visitor": 2,
	"modify_node_atmosphere": 2,
	"reveal_hidden_lore": 1,
	"create_residual_identity": 2,
	"alter_npc_state": 3,
	"reveal_npc_relationships": 2,
}

const EFFECT_LABELS := {
	"identity_mask": "\u4f2a\u88c5\u8eab\u4efd",
	"borrow_name": "\u501f\u540d",
	"forget_event": "\u62b9\u9664\u8bb0\u5fc6",
	"read_truth": "\u8bfb\u53d6\u771f\u8bdd",
	"modify_suspicion": "\u8c03\u6574\u6000\u7591",
	"extract_memory": "\u62bd\u53d6\u8bb0\u5fc6",
	"extract_secret": "\u62bd\u53d6\u79d8\u5bc6",
	"influence_behavior": "\u5f71\u54cd\u884c\u4e3a",
	"alter_drop_table": "\u6539\u5199\u6389\u843d",
	"spawn_event": "\u5f15\u51fa\u540e\u7eed\u4e8b\u4ef6",
	"attract_visitor": "\u5438\u5f15\u8bbf\u5ba2",
	"modify_node_atmosphere": "\u6539\u53d8\u5730\u70b9\u6c1b\u56f4",
	"reveal_hidden_lore": "\u63ed\u793a\u9690\u85cf\u7ebf\u7d22",
	"create_residual_identity": "\u6b8b\u7559\u8eab\u4efd",
	"alter_npc_state": "\u6539\u5199 NPC \u72b6\u6001",
	"reveal_npc_relationships": "\u63ed\u793a NPC \u5173\u7cfb",
}

const PERCEPTION_LABELS := {
	"harvey": "\u54c8\u7ef4",
	"stranger": "\u964c\u751f\u4eba",
	"dead_brother": "\u4ea1\u5144\u7684\u5f71\u5b50",
	"shadow_double": "\u66ff\u8eab\u5f71",
	"borrowed_name": "\u501f\u6765\u7684\u540d\u5b57",
	"forgotten": "\u88ab\u62b9\u6389\u7684\u4eba",
}

var _ai_gm_service = null


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func dispatch_card(card, target_npc_id: String, ctx: Dictionary = {}) -> Dictionary:
	var gs = _resolve_game_state(ctx)
	if gs == null:
		return {"success": false, "ok": false, "reason": "missing_game_state"}
	if card == null:
		return {"success": false, "ok": false, "reason": "missing_card"}
	var social := _effect_dict(card.get("social_effect"))
	var world := _effect_dict(card.get("world_effect"))
	if _effect_type(social) == "" and _effect_type(world) == "":
		return {"success": false, "ok": false, "reason": "missing_r20_effect"}
	var cost := maxi(0, int(card.get("energy_cost")))
	if int(gs.get("hub_mana")) < cost:
		return {"success": false, "ok": false, "reason": "hub_mana_short", "cost": cost}
	if target_npc_id == "":
		return {"success": false, "ok": false, "reason": "missing_target_npc"}
	if not _target_exists(gs, target_npc_id):
		return {"success": false, "ok": false, "reason": "unknown_npc", "target_npc_id": target_npc_id}

	var state = _ensure_target_state(gs, target_npc_id)
	var extracted_data: Variant = null
	var social_result: Dictionary = {}
	var world_result: Dictionary = {}

	gs.hub_mana = maxi(0, int(gs.hub_mana) - cost)
	if _effect_type(social) != "":
		social_result = _apply_social(card, social, target_npc_id, gs, state)
		extracted_data = social_result.get("extracted_data", null)
	if _effect_type(world) != "":
		world_result = _apply_world(card, world, target_npc_id, gs, state)

	var pollution_delta := _pollution_delta(social, SOCIAL_POLLUTION) + _pollution_delta(world, WORLD_POLLUTION)
	var awareness_delta := _awareness_delta(social, SOCIAL_AWARENESS) + _awareness_delta(world, WORLD_AWARENESS)
	var pollution_result := _apply_pollution(gs, pollution_delta, card, social, world)
	_adjust_awareness(gs, awareness_delta, "r20:%s" % str(card.get("id")))
	var side_effects_applied := {
		"hub_mana": -cost,
		"pollution": pollution_delta,
		"church_awareness": awareness_delta,
		"suspicion_delta": int(social.get("suspicion_delta", 0)),
	}
	var result := {
		"success": true,
		"ok": true,
		"card_id": str(card.get("id")),
		"target_npc_id": target_npc_id,
		"hub_mana_cost": cost,
		"pollution_delta": pollution_delta,
		"awareness_delta": awareness_delta,
		"pollution_result": pollution_result,
		"side_effects_applied": side_effects_applied,
		"social_result": social_result,
		"world_result": world_result,
		"ai_gm_payload": {
			"scene": "social_resolve",
			"card_id": str(card.get("id")),
			"social_type": _effect_type(social),
			"world_type": _effect_type(world),
			"target_npc_id": target_npc_id,
			"hub_mana_cost": cost,
			"pollution_delta": pollution_delta,
			"awareness_delta": awareness_delta,
			"side_effects_applied": side_effects_applied,
		},
		"extracted_data": extracted_data,
	}
	result["ai_gm_text"] = request_social_resolve_ai_gm(card, target_npc_id, gs, social, world, result, state)
	result["field_hook_result"] = R20FieldHookServiceScript.new().apply(gs, target_npc_id, card, result, ctx)
	return result


func dispatch_social(card, ctx: Dictionary) -> Dictionary:
	return dispatch_card(card, str(ctx.get("target_npc_id", "")), ctx)


func dispatch_world(card, ctx: Dictionary) -> Dictionary:
	return dispatch_card(card, str(ctx.get("target_npc_id", "")), ctx)


func request_social_resolve_ai_gm(card, target_npc_id: String, game_state, social: Dictionary = {}, world: Dictionary = {}, result: Dictionary = {}, state = null) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "social_resolve"
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"card_id": str(card.get("id")) if card != null else "",
		"social_type": _effect_type(social),
		"world_type": _effect_type(world),
		"target_npc_id": target_npc_id,
		"hub_mana_cost": int(result.get("hub_mana_cost", 0)),
		"suspicion_delta": int(social.get("suspicion_delta", 0)),
		"awareness_delta": int(result.get("awareness_delta", 0)),
		"pollution_delta": int(result.get("pollution_delta", 0)),
		"side_effects_applied": result.get("side_effects_applied", {}),
	}
	ctx.npc_context = _ai_gm_npc_context(target_npc_id, state)
	ctx.fallback_template_pool = "SOCIAL_RESOLVE_TEMPLATES"
	return _call_ai_gm(ctx)


func _apply_social(card, effect: Dictionary, target_npc_id: String, gs, state) -> Dictionary:
	var effect_type := _effect_type(effect)
	match effect_type:
		"identity_mask":
			state.active_perception = str(effect.get("npc_perception", "stranger"))
			state.perception_expires_at = int(gs.day) + maxi(1, int(effect.get("duration_days", 1)))
			state.suspicion = clampi(int(state.suspicion) + int(effect.get("suspicion_delta", 0)), 0, 100)
		"borrow_name":
			state.active_perception = "borrowed_name"
			state.perception_expires_at = int(gs.day) + maxi(1, int(effect.get("duration_days", 3)))
			state.dialogue_state["borrowed_name_from_card"] = str(card.get("id"))
		"forget_event":
			state.active_perception = "forgotten"
			var duration := int(effect.get("duration_days", 0))
			state.perception_expires_at = int(gs.day) + duration if duration > 0 else 0
			state.dialogue_state["forgotten_by_card"] = str(card.get("id"))
		"read_truth", "extract_memory", "extract_secret":
			state.layer_revealed = clampi(maxi(int(state.layer_revealed), int(effect.get("reveal_layer", 1))), 0, 2)
			var extracted := {
				"npc_id": target_npc_id,
				"type": effect_type,
				"card_id": str(card.get("id")),
				"layer": int(state.layer_revealed),
			}
			state.dialogue_state["last_extracted_data"] = extracted
			_register_social_effect(state, effect_type)
			return {"ok": true, "type": effect_type, "extracted_data": extracted}
		"modify_suspicion":
			state.suspicion = clampi(int(state.suspicion) + int(effect.get("suspicion_delta", 0)), 0, 100)
		"influence_behavior":
			state.dialogue_state["influenced_until_day"] = int(gs.day) + maxi(1, int(effect.get("duration_days", 5)))
		_:
			state.dialogue_state["last_social_effect"] = effect_type
	_register_social_effect(state, effect_type)
	return {
		"ok": true,
		"type": effect_type,
		"active_perception": str(state.active_perception),
		"perception_label": _perception_label(str(state.active_perception)),
		"perception_expires_at": int(state.perception_expires_at),
		"suspicion_delta": int(effect.get("suspicion_delta", 0)),
		"suspicion": int(state.suspicion),
	}


func _apply_world(card, effect: Dictionary, target_npc_id: String, gs, state) -> Dictionary:
	var effect_type := _effect_type(effect)
	match effect_type:
		"create_residual_identity":
			var identity_id := str(effect.get("identity_id", ""))
			if identity_id == "":
				identity_id = "%s_%s_identity" % [str(card.get("id")), target_npc_id]
			var duration := maxi(1, int(effect.get("duration_days", 3)))
			var identity = ResidualIdentityScript.from_dict({
				"id": identity_id,
				"name": str(effect.get("name", card.get("display_name"))),
				"source_npc": target_npc_id,
				"source_persona": state.public_data.duplicate(true) if state != null else {},
				"created_at_day": int(gs.day),
				"expires_at_day": int(gs.day) + duration,
				"allowed_locations": _string_array(effect.get("allowed_locations", [target_npc_id])),
				"uses_remaining": int(effect.get("uses_remaining", 3)),
			})
			gs.residual_identities.append(identity)
			return {
				"ok": true,
				"type": effect_type,
				"identity_id": identity_id,
				"identity_name": str(identity.name),
				"expires_at_day": int(identity.expires_at_day),
				"uses_remaining": int(identity.uses_remaining),
				"allowed_locations": identity.allowed_locations.duplicate(),
			}
		"reveal_hidden_lore":
			var lore_entry := str(effect.get("lore_entry", "%s:%s" % [str(card.get("id")), target_npc_id]))
			_append_daodian_array(gs, "dao_fragments", lore_entry)
			state.layer_revealed = clampi(maxi(int(state.layer_revealed), int(effect.get("reveal_layer", 1))), 0, 2)
		"alter_npc_state":
			state.active_perception = str(effect.get("npc_remembers_you_as", "forgotten"))
			state.dialogue_state["altered_by_card"] = str(card.get("id"))
		"spawn_event":
			var events := _meta_array(gs, "r20_pending_events")
			events.append({
				"card_id": str(card.get("id")),
				"target_npc_id": target_npc_id,
				"event": effect.get("event", "r20_spawn_event"),
				"created_at_day": int(gs.day),
			})
			gs.set_meta("r20_pending_events", events)
		"reveal_npc_relationships":
			var graph: Dictionary = gs.daodian.get("npc_relationship_graph", {}) if gs.daodian is Dictionary else {}
			graph[target_npc_id] = effect.get("unlocks", [target_npc_id])
			gs.daodian["npc_relationship_graph"] = graph
		"attract_visitor":
			var visitors := _meta_array(gs, "r20_pending_visitors")
			var npc_id := str(effect.get("npc_id", target_npc_id)).strip_edges()
			if npc_id == "":
				npc_id = target_npc_id
			var arrives_at_day := int(gs.day) + maxi(0, int(effect.get("delay_days", 1)))
			var display_name := _npc_label(npc_id, str(effect.get("display_name", "")))
			var message := str(effect.get("message", effect.get("text", ""))).strip_edges()
			if message == "":
				message = "\u4e00\u4f4d\u8bbf\u5ba2\u88ab\u5492\u5ff5\u5f15\u5230\u6d1e\u5e9c\u95e8\u524d\u3002"
			var visitor := {
				"npc_id": npc_id,
				"arrives_at_day": arrives_at_day,
				"display_name": display_name,
				"message": message,
				"source_card_id": str(card.get("id")),
			}
			visitors.append(visitor)
			gs.set_meta("r20_pending_visitors", visitors)
			return {
				"ok": true,
				"type": effect_type,
				"npc_id": npc_id,
				"arrives_at_day": arrives_at_day,
				"display_name": display_name,
				"message": message,
				"display_text": "\u8bbf\u5ba2\u5c06\u81f3\uff1a%s\uff08\u7b2c %d \u5929\uff09" % [display_name, arrives_at_day],
			}
		"modify_node_atmosphere":
			var atmosphere_district := _effect_district(effect, gs)
			var atmosphere_id := str(effect.get("atmosphere", _effect_dict(effect.get("parameters", {})).get("atmosphere", ""))).strip_edges()
			var atmosphere_label := _atmosphere_label(atmosphere_id)
			var atmosphere_modifiers: Dictionary = gs.activity_modifiers if gs.activity_modifiers is Dictionary else {}
			var atmosphere_stored := effect.duplicate(true)
			atmosphere_stored["district"] = atmosphere_district
			atmosphere_stored["atmosphere"] = atmosphere_id
			atmosphere_stored["display_text"] = "\u6c1b\u56f4\u6539\u53d8\uff1a%s \u51fa\u73b0%s" % [_location_label(atmosphere_district), atmosphere_label]
			var atmosphere_duration := int(effect.get("duration_days", 0))
			if atmosphere_duration > 0:
				atmosphere_stored["expires_at_day"] = int(gs.day) + atmosphere_duration
			atmosphere_modifiers["r20_%s" % effect_type] = atmosphere_stored
			gs.activity_modifiers = atmosphere_modifiers
			return {
				"ok": true,
				"type": effect_type,
				"district": atmosphere_district,
				"atmosphere": atmosphere_id,
				"atmosphere_label": atmosphere_label,
				"display_text": str(atmosphere_stored.get("display_text", "")),
				"expires_at_day": int(atmosphere_stored.get("expires_at_day", 0)),
			}
		"alter_drop_table":
			var drop_district := _effect_district(effect, gs)
			var table_id := str(effect.get("table_id", effect.get("loot_table", ""))).strip_edges()
			var drop_modifiers: Dictionary = gs.activity_modifiers if gs.activity_modifiers is Dictionary else {}
			var drop_stored := effect.duplicate(true)
			drop_stored["district"] = drop_district
			drop_stored["table_id"] = table_id
			drop_stored["display_text"] = "\u6389\u843d\u5df2\u6539\u5199\uff1a%s" % _location_label(drop_district)
			var drop_duration := int(effect.get("duration_days", 0))
			if drop_duration > 0:
				drop_stored["expires_at_day"] = int(gs.day) + drop_duration
			drop_modifiers["r20_%s" % effect_type] = drop_stored
			gs.activity_modifiers = drop_modifiers
			return {
				"ok": true,
				"type": effect_type,
				"district": drop_district,
				"table_id": table_id,
				"display_text": str(drop_stored.get("display_text", "")),
				"expires_at_day": int(drop_stored.get("expires_at_day", 0)),
			}
		_:
			state.dialogue_state["last_world_effect"] = effect_type
	return {"ok": true, "type": effect_type}


func player_feedback_text(result: Dictionary) -> String:
	return "\n".join(player_feedback_lines(result))


func player_feedback_lines(result: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if not bool(result.get("success", result.get("ok", false))):
		lines.append("\u6ca1\u6709\u751f\u6548\uff1a%s" % _reason_label(str(result.get("reason", "unknown"))))
		return lines
	var cost := int(result.get("hub_mana_cost", 0))
	if cost > 0:
		lines.append("\u6d1e\u5e9c\u80fd\u91cf -%d" % cost)
	var social: Dictionary = _effect_dict(result.get("social_result", {}))
	var social_type := _effect_type(social)
	if social_type == "identity_mask":
		var perception := str(social.get("perception_label", _perception_label(str(social.get("active_perception", "")))))
		var expires := int(social.get("perception_expires_at", 0))
		var suffix := "\uff0c\u6301\u7eed\u5230\u7b2c %d \u5929" % expires if expires > 0 else ""
		lines.append("\u4f2a\u88c5\u8eab\u4efd\uff1a%s%s" % [perception, suffix])
	elif social_type != "":
		lines.append("\u793e\u4ea4\u5f71\u54cd\uff1a%s" % _effect_label(social_type))
	if social.has("suspicion_delta") and int(social.get("suspicion_delta", 0)) != 0:
		lines.append("\u6000\u7591 %s\uff0c\u5f53\u524d %d" % [_signed_number_text(int(social.get("suspicion_delta", 0))), int(social.get("suspicion", 0))])
	var world: Dictionary = _effect_dict(result.get("world_result", {}))
	var world_type := _effect_type(world)
	if world_type == "create_residual_identity":
		var identity_name := str(world.get("identity_name", world.get("identity_id", ""))).strip_edges()
		if identity_name == "":
			identity_name = "\u672a\u547d\u540d\u8eab\u4efd"
		var details: Array[String] = []
		var uses := int(world.get("uses_remaining", 0))
		if uses > 0:
			details.append("\u53ef\u7528 %d \u6b21" % uses)
		var expires_day := int(world.get("expires_at_day", 0))
		if expires_day > 0:
			details.append("\u5230\u7b2c %d \u5929" % expires_day)
		var locations := _location_labels(_string_array(world.get("allowed_locations", [])))
		if locations != "":
			details.append("\u53ef\u7528\u4e8e %s" % locations)
		var suffix := "\uff08%s\uff09" % "\uff0c".join(details) if not details.is_empty() else ""
		lines.append("\u6b8b\u7559\u8eab\u4efd\uff1a%s%s" % [identity_name, suffix])
	elif world_type != "":
		var display_text := str(world.get("display_text", "")).strip_edges()
		if display_text != "":
			lines.append("\u4e16\u754c\u5f71\u54cd\uff1a%s" % display_text)
		else:
			lines.append("\u4e16\u754c\u5f71\u54cd\uff1a%s" % _effect_label(world_type))
	var side_effects: Dictionary = _effect_dict(result.get("side_effects_applied", {}))
	var pollution_delta := int(side_effects.get("pollution", result.get("pollution_delta", 0)))
	var awareness_delta := int(side_effects.get("church_awareness", result.get("awareness_delta", 0)))
	if pollution_delta != 0 or awareness_delta != 0:
		lines.append("\u6c61\u67d3 %s\uff1b\u6559\u4f1a\u8b66\u89c9 %s" % [_signed_number_text(pollution_delta), _signed_number_text(awareness_delta)])
	var field_hook: Dictionary = _effect_dict(result.get("field_hook_result", {}))
	var hook_line := _field_hook_feedback_line(field_hook)
	if hook_line != "":
		lines.append(hook_line)
	var ai_text := str(result.get("ai_gm_text", "")).strip_edges()
	if ai_text != "":
		lines.append(ai_text)
	if lines.is_empty():
		lines.append("\u5492\u5ff5\u5df2\u751f\u6548\u3002")
	return lines


func _target_exists(gs, target_npc_id: String) -> bool:
	if gs.npc_relations.has(target_npc_id):
		return true
	var library = NpcLibraryScript.new()
	return bool(library.has_definition(target_npc_id))


func _ensure_target_state(gs, target_npc_id: String):
	if not gs.npc_relations.has(target_npc_id):
		gs.npc_relations[target_npc_id] = NpcKnowledgeStateScript.new()
	var state = gs.npc_relations[target_npc_id]
	if state is Dictionary:
		state = NpcKnowledgeStateScript.from_dict(state)
		gs.npc_relations[target_npc_id] = state
	return state


func _register_social_effect(state, effect_type: String) -> void:
	if effect_type == "":
		return
	if not state.social_effects_active.has(effect_type):
		state.social_effects_active.append(effect_type)


func _resolve_game_state(ctx: Dictionary):
	var gs = ctx.get("game_state", null)
	if gs != null:
		return gs
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("GameState")
	return null


func _adjust_awareness(gs, delta: int, source: String) -> void:
	if delta == 0:
		return
	if gs.has_method("adjust_church_awareness"):
		gs.adjust_church_awareness(delta, source)
	else:
		gs.church_awareness = clampi(int(gs.church_awareness) + delta, 0, 100)


func _apply_pollution(gs, delta: int, card, social: Dictionary, world: Dictionary) -> Dictionary:
	if delta == 0:
		return {"pollution": int(gs.pollution)}
	var next_pollution := clampi(int(gs.pollution) + delta, 0, 100)
	if gs.has_method("set_pollution"):
		return gs.set_pollution(next_pollution, _pollution_recent_actions(card, social, world))
	gs.pollution = next_pollution
	return {"pollution": int(gs.pollution)}


func _pollution_recent_actions(card, social: Dictionary, world: Dictionary) -> Array:
	var result: Array = []
	var card_id := str(card.get("id")) if card != null else ""
	if card_id != "":
		result.append("r20:%s" % card_id)
	var social_type := _effect_type(social)
	if social_type != "":
		result.append("social:%s" % social_type)
	var world_type := _effect_type(world)
	if world_type != "":
		result.append("world:%s" % world_type)
	return result


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
	if game_state == null:
		return {}
	return {
		"sequence": int(game_state.sequence),
		"pollution": int(game_state.pollution),
		"pollution_stage": int(game_state.pollution_stage),
		"cycle": int(game_state.cycle),
		"day": int(game_state.day),
		"time_of_day": str(game_state.time_of_day),
	}


func _ai_gm_npc_context(target_npc_id: String, state) -> Dictionary:
	return {
		"target_npc_id": target_npc_id,
		"active_perception": str(state.active_perception) if state != null else "",
		"trust": int(state.trust) if state != null else 0,
		"suspicion": int(state.suspicion) if state != null else 0,
		"layer_revealed": int(state.layer_revealed) if state != null else 0,
	}


func _pollution_delta(effect: Dictionary, defaults: Dictionary) -> int:
	if _effect_type(effect) == "":
		return 0
	return int(effect.get("pollution_delta", defaults.get(_effect_type(effect), 0)))


func _awareness_delta(effect: Dictionary, defaults: Dictionary) -> int:
	if _effect_type(effect) == "":
		return 0
	return int(effect.get("church_awareness_delta", defaults.get(_effect_type(effect), 0)))


func _effect_type(effect: Dictionary) -> String:
	return str(effect.get("type", ""))


func _effect_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _effect_label(effect_type: String) -> String:
	return str(EFFECT_LABELS.get(effect_type, effect_type))


func _effect_district(effect: Dictionary, gs) -> String:
	var district_id := str(effect.get("district", "")).strip_edges()
	if district_id == "":
		var params: Dictionary = _effect_dict(effect.get("parameters", {}))
		district_id = str(params.get("district", "")).strip_edges()
	if district_id == "" and gs != null:
		district_id = str(gs.current_district).strip_edges()
	if district_id == "":
		district_id = "shadow_alley"
	return district_id


func _atmosphere_label(atmosphere_id: String) -> String:
	match atmosphere_id:
		"ritual_echo":
			return "\u4eea\u5f0f\u56de\u54cd"
		"fog", "mist":
			return "\u8584\u96fe"
		"church_pressure":
			return "\u6559\u4f1a\u538b\u529b"
		"market_noise":
			return "\u5e02\u96c6\u55a7\u54d7"
		_:
			if atmosphere_id.strip_edges() == "":
				return "\u5f02\u6837\u7684\u6c14\u606f"
			return atmosphere_id


func _npc_label(npc_id: String, fallback: String = "") -> String:
	var clean_fallback := str(fallback).strip_edges()
	if clean_fallback != "":
		return clean_fallback
	var library = NpcLibraryScript.new()
	var definition := library.get_definition(npc_id)
	var display_name := str(definition.get("display_name", definition.get("name", ""))).strip_edges()
	if display_name != "":
		return display_name
	return npc_id if npc_id != "" else "\u8bbf\u5ba2"


func _perception_label(perception_id: String) -> String:
	if perception_id == "":
		return "\u672a\u77e5\u8eab\u4efd"
	return str(PERCEPTION_LABELS.get(perception_id, perception_id))


func _signed_number_text(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)


func _reason_label(reason: String) -> String:
	match reason:
		"hub_mana_short":
			return "\u6d1e\u5e9c\u80fd\u91cf\u4e0d\u8db3"
		"missing_game_state", "missing_state":
			return "\u72b6\u6001\u4e0d\u53ef\u7528"
		"missing_card":
			return "\u5361\u724c\u4e0d\u53ef\u7528"
		"unknown_npc":
			return "\u627e\u4e0d\u5230\u76ee\u6807 NPC"
		_:
			return reason


func _field_hook_feedback_line(field_hook: Dictionary) -> String:
	if field_hook.is_empty():
		return ""
	var hook_type := str(field_hook.get("hook_type", "")).strip_edges()
	if not bool(field_hook.get("ok", true)):
		return "\u573a\u5916\u8054\u52a8\uff1a%s\u672a\u751f\u6548" % _effect_label(hook_type)
	match hook_type:
		"identity_mask":
			return "\u573a\u5916\u8054\u52a8\uff1a\u5f53\u524d NPC \u6000\u7591 %s\uff0c\u73b0\u5728 %d" % [
				_signed_number_text(int(field_hook.get("suspicion_delta", 0))),
				int(field_hook.get("suspicion", 0)),
			]
		"read_truth":
			var display_text := str(field_hook.get("display_text", "")).strip_edges()
			if display_text == "":
				display_text = "\u5df2\u8bb0\u5f55\u4e00\u6761\u5173\u7cfb\u95e8\u69db\u60c5\u62a5"
			return "\u573a\u5916\u8054\u52a8\uff1a%s" % display_text
		"premonition":
			var entry: Dictionary = _effect_dict(field_hook.get("entry", {}))
			var title := str(entry.get("display_name", entry.get("id", ""))).strip_edges()
			if title == "":
				title = "\u4e00\u4e2a\u9690\u85cf\u57ce\u533a\u673a\u4f1a"
			return "\u573a\u5916\u8054\u52a8\uff1a\u9884\u793a\u4e86 %s" % title
		"spawn_event":
			var display_text := str(field_hook.get("display_text", "")).strip_edges()
			if display_text == "":
				var entry: Dictionary = _effect_dict(field_hook.get("entry", {}))
				display_text = str(entry.get("display_name", "")).strip_edges()
			if display_text == "":
				display_text = "\u4e00\u4e2a\u9690\u85cf\u57ce\u533a\u673a\u4f1a"
			return "\u573a\u5916\u8054\u52a8\uff1a\u5f15\u51fa\u4e86 %s" % display_text
		"influence_behavior":
			return "\u573a\u5916\u8054\u52a8\uff1a\u5df2\u91cd\u7f6e\u8be5 NPC \u4eca\u65e5\u673a\u4f1a"
		_:
			if hook_type != "":
				return "\u573a\u5916\u8054\u52a8\uff1a%s" % _effect_label(hook_type)
	return ""


func _location_labels(ids: Array[String]) -> String:
	var labels: Array[String] = []
	for id in ids:
		var label := _location_label(id)
		if label != "" and not labels.has(label):
			labels.append(label)
	return "\uff0c".join(labels)


func _location_label(id: String) -> String:
	match id:
		"old_li":
			return "\u8001\u674e"
		"shadow_alley":
			return "\u5f71\u5df7"
		"misty_port":
			return "\u96fe\u6e2f"
		"steelworks":
			return "\u94f8\u94a2\u533a"
		"sacred_seven":
			return "\u4e03\u5723\u5e7f\u573a"
		"stone_tower":
			return "\u77f3\u5854\u533a"
		"ascetic_mountain":
			return "\u82e6\u4fee\u5c71"
		_:
			return id


func _append_daodian_array(gs, key: String, value: Variant) -> void:
	if not gs.daodian is Dictionary:
		gs.daodian = {}
	var items: Array = gs.daodian.get(key, []) if gs.daodian.get(key, []) is Array else []
	if not items.has(value):
		items.append(value)
	gs.daodian[key] = items


func _meta_array(gs, key: String) -> Array:
	if gs != null and gs.has_meta(key):
		var value = gs.get_meta(key)
		if value is Array:
			return value.duplicate(true)
	return []


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
