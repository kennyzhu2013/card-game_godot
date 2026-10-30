class_name EffectEngine
extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")

const HANDLERS := {
	"charge": &"_apply_charge",
	"weak": &"_apply_weak",
	"vulnerable": &"_apply_vulnerable",
	"confusion": &"_apply_confusion",
	"nightmare": &"_apply_nightmare",
	"obscure_intent": &"_apply_obscure_intent",
	"burn": &"_apply_burn",
	"poison": &"_apply_poison",
	"pierce_block": &"_apply_pierce_block",
	"damage_reduction": &"_apply_damage_reduction",
	"dodge_counter": &"_apply_dodge_counter",
	"cleanse_debuff": &"_apply_cleanse_debuff",
	"cleanse_incoming_debuff": &"_apply_cleanse_incoming_debuff",
	"immune_debuff": &"_apply_immune_debuff",
	"fatal_damage_convert": &"_apply_fatal_damage_convert",
	"consume_on_trigger": &"_apply_consume_on_trigger",
	"paper_doll_marker": &"_apply_paper_doll_marker",
	"absorb_fatal_or_curse": &"_apply_absorb_fatal_or_curse",
	"create_or_move_flame_markers": &"_apply_create_or_move_flame_markers",
	"consume_flame_marker": &"_apply_consume_flame_marker",
	"teleport_to_flame": &"_apply_teleport_to_flame",
	"adjacent_burn": &"_apply_adjacent_burn",
	"discard_top_deck": &"_apply_discard_top_deck",
	"bonus_if_attack": &"_apply_bonus_if_attack",
	"vulnerable_if_skill": &"_apply_vulnerable_if_skill",
	"vulnerable_if_skill_played": &"_apply_vulnerable_if_skill_played",
	"weak_if_status": &"_apply_weak_if_status",
	"create_random_temp_card": &"_apply_create_random_temp_card",
	"draw_if_no_cleanse": &"_apply_draw_if_no_cleanse",
	"draw_filter": &"_apply_draw_filter",
	"next_fool_skill_cost_delta": &"_apply_next_fool_skill_cost_delta",
	"attack_play_damage_growth": &"_apply_attack_play_damage_growth",
	"per_use_damage_growth": &"_apply_per_use_damage_growth",
	"cost_zero_if_flame_stream": &"_apply_cost_zero_if_flame_stream",
	"select_targets": &"_apply_select_targets",
	"multi_strike": &"_apply_multi_strike",
	"reroll_next_damage_target": &"_apply_reroll_next_damage_target",
	"avoid_counter_intent": &"_apply_avoid_counter_intent",
	"bind": &"_apply_bind",
	"blind": &"_apply_blind",
	"block_break": &"_apply_block_break",
	"break_block": &"_apply_break_block",
	"burning": &"_apply_burning",
	"chill": &"_apply_chill",
	"confuse": &"_apply_confuse",
	"counter_spell": &"_apply_counter_spell",
	"crit_up": &"_apply_crit_up",
	"delay_intent": &"_apply_delay_intent",
	"displace": &"_apply_displace",
	"execute_bonus_below_hp_pct": &"_apply_execute_bonus_below_hp_pct",
	"fear": &"_apply_fear",
	"ignore_guard": &"_apply_ignore_guard",
	"intent_revealed": &"_apply_intent_revealed",
	"life_steal": &"_apply_life_steal",
	"link": &"_apply_link",
	"mark": &"_apply_mark",
	"mind_revealed": &"_apply_mind_revealed",
	"next_attack_damage_delta": &"_apply_next_attack_damage_delta",
	"pierce": &"_apply_pierce",
	"range_bonus": &"_apply_range_bonus",
	"revealed": &"_apply_revealed",
	"root": &"_apply_root",
	"self_damage": &"_apply_self_damage",
	"silence": &"_apply_silence",
	"slow": &"_apply_slow",
	"stealth": &"_apply_stealth",
	"stun": &"_apply_stun",
}

const EFFECT_TO_MECHANISM := {
	"charge": "charge_skill",
	"damage_reduction": "status",
	"dodge_counter": "dodge_counter",
	"weak": "status",
	"vulnerable": "status",
	"confusion": "status",
	"nightmare": "status",
	"obscure_intent": "status",
	"burn": "status",
	"poison": "status",
	"pierce_block": "status",
	"cleanse_debuff": "status",
	"cleanse_incoming_debuff": "status",
	"immune_debuff": "status",
	"fatal_damage_convert": "status",
	"consume_on_trigger": "status",
	"attack_play_damage_growth": "status",
	"multi_strike": "multi_strike",
	"vulnerable_if_skill_played": "status",
	"select_targets": "multi_target",
	"per_use_damage_growth": "paper_blade",
	"teleport_to_flame": "position_shift",
	"cost_zero_if_flame_stream": "status",
	"paper_doll_marker": "paper_doll",
	"absorb_fatal_or_curse": "paper_doll",
	"create_or_move_flame_markers": "field_marker",
	"adjacent_burn": "field_marker",
	"discard_top_deck": "deck_transform",
	"bonus_if_attack": "deck_transform",
	"vulnerable_if_skill": "deck_transform",
	"weak_if_status": "deck_transform",
	"create_random_temp_card": "temporary_card",
	"draw_if_no_cleanse": "status",
	"draw_filter": "draw_filter",
	"next_fool_skill_cost_delta": "cost_mod",
	"avoid_counter_intent": "status",
	"reroll_next_damage_target": "status",
	"bind": "status",
	"blind": "status",
	"block_break": "block_break",
	"break_block": "status",
	"burning": "status",
	"chill": "status",
	"confuse": "status",
	"counter_spell": "status",
	"crit_up": "status",
	"delay_intent": "status",
	"displace": "status",
	"execute_bonus_below_hp_pct": "status",
	"fear": "status",
	"ignore_guard": "status",
	"intent_revealed": "intent_reveal",
	"life_steal": "status",
	"link": "status",
	"mark": "status",
	"mind_revealed": "mind_read",
	"next_attack_damage_delta": "status",
	"pierce": "status",
	"range_bonus": "status",
	"revealed": "intent_reveal",
	"root": "status",
	"self_damage": "status",
	"silence": "status",
	"slow": "status",
	"stealth": "status",
	"stun": "status",
}


static func dispatch(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var id := str(effect.get("id", ""))
	if not HANDLERS.has(id):
		push_error("[EffectEngine] unknown effect_id: %s" % id)
		return {"ok": false, "reason": "unknown_effect_id", "id": id}
	var chance_result := _chance_gate(effect, id)
	if not bool(chance_result.get("passed", true)):
		return chance_result
	var handler_name: StringName = HANDLERS[id]
	return _dispatch_registered(handler_name, effect, ctx)


static func _dispatch_registered(handler_name: StringName, effect: Dictionary, _ctx: Dictionary) -> Dictionary:
	match handler_name:
		&"_apply_charge":
			return _apply_charge(effect, _ctx)
		&"_apply_weak":
			return _apply_status_debuff("weak", effect, _ctx)
		&"_apply_vulnerable":
			return _apply_status_debuff("vulnerable", effect, _ctx)
		&"_apply_confusion":
			return _apply_status_debuff("confusion", effect, _ctx)
		&"_apply_nightmare":
			return _apply_nightmare(effect, _ctx)
		&"_apply_obscure_intent":
			return _apply_status_debuff("obscure_intent", effect, _ctx)
		&"_apply_burn":
			return _apply_status_debuff("burn", effect, _ctx)
		&"_apply_poison":
			return _apply_status_debuff("poison", effect, _ctx)
		&"_apply_pierce_block":
			return {"ok": true, "reason": "damage_modifier", "id": str(effect.get("id", "pierce_block")), "magnitude": maxi(0, int(effect.get("magnitude", 0)))}
		&"_apply_damage_reduction":
			return _apply_status("damage_reduction", effect, _ctx)
		&"_apply_dodge_counter":
			return _apply_status("dodge_counter", effect, _ctx)
		&"_apply_cleanse_debuff":
			return _apply_cleanse_debuff(effect, _ctx)
		&"_apply_cleanse_incoming_debuff":
			return _apply_status("cleanse_incoming_debuff", effect, _ctx)
		&"_apply_immune_debuff":
			return _apply_status("immune_debuff", effect, _ctx)
		&"_apply_fatal_damage_convert":
			return _apply_status("fatal_damage_convert", effect, _ctx)
		&"_apply_consume_on_trigger":
			return _apply_status("consume_on_trigger", effect, _ctx)
		&"_apply_paper_doll_marker":
			return _apply_paper_doll_marker(effect, _ctx)
		&"_apply_absorb_fatal_or_curse":
			return _apply_status("absorb_fatal_or_curse", effect, _ctx)
		&"_apply_create_or_move_flame_markers":
			return _apply_create_or_move_flame_markers(effect, _ctx)
		&"_apply_consume_flame_marker":
			return _apply_consume_flame_marker(effect, _ctx)
		&"_apply_teleport_to_flame":
			return _apply_teleport_to_flame(effect, _ctx)
		&"_apply_adjacent_burn":
			return _apply_adjacent_burn(effect, _ctx)
		&"_apply_discard_top_deck":
			return _apply_discard_top_deck(effect, _ctx)
		&"_apply_bonus_if_attack":
			return _apply_bonus_if_attack(effect, _ctx)
		&"_apply_vulnerable_if_skill":
			return _apply_vulnerable_if_skill(effect, _ctx)
		&"_apply_vulnerable_if_skill_played":
			return _apply_vulnerable_if_skill_played(effect, _ctx)
		&"_apply_weak_if_status":
			return _apply_weak_if_status(effect, _ctx)
		&"_apply_create_random_temp_card":
			return _apply_create_random_temp_card(effect, _ctx)
		&"_apply_draw_if_no_cleanse":
			return _apply_draw_if_no_cleanse(effect, _ctx)
		&"_apply_draw_filter":
			return _apply_draw_filter(effect, _ctx)
		&"_apply_next_fool_skill_cost_delta":
			return _apply_next_fool_skill_cost_delta(effect, _ctx)
		&"_apply_attack_play_damage_growth":
			return _apply_attack_play_damage_growth(effect, _ctx)
		&"_apply_per_use_damage_growth":
			return _apply_per_use_damage_growth(effect, _ctx)
		&"_apply_cost_zero_if_flame_stream":
			return _apply_cost_zero_if_flame_stream(effect, _ctx)
		&"_apply_select_targets":
			return _apply_select_targets(effect, _ctx)
		&"_apply_multi_strike":
			return _apply_multi_strike(effect, _ctx)
		&"_apply_reroll_next_damage_target":
			return _apply_reroll_next_damage_target(effect, _ctx)
		&"_apply_avoid_counter_intent":
			return _apply_avoid_counter_intent(effect, _ctx)
		&"_apply_bind":
			return _apply_status_debuff("bind", effect, _ctx)
		&"_apply_blind":
			return _apply_status_debuff("blind", effect, _ctx)
		&"_apply_block_break":
			return _apply_block_break(effect, _ctx)
		&"_apply_break_block":
			return _apply_break_block(effect, _ctx)
		&"_apply_burning":
			return _apply_status_debuff("burn", _with_default(effect, "magnitude", 5), _ctx)
		&"_apply_chill":
			return _apply_status_debuff("chill", effect, _ctx)
		&"_apply_confuse":
			return _apply_status_debuff("confusion", effect, _ctx)
		&"_apply_counter_spell":
			return _apply_status_debuff("counter_spell", _with_default(effect, "magnitude", 6), _ctx)
		&"_apply_crit_up":
			return {"ok": true, "reason": "damage_modifier", "id": str(effect.get("id", "crit_up"))}
		&"_apply_delay_intent":
			return _apply_status_debuff("delay_intent", effect, _ctx)
		&"_apply_displace":
			return _apply_status_debuff("displace", effect, _ctx)
		&"_apply_execute_bonus_below_hp_pct":
			return _apply_execute_bonus_below_hp_pct(effect, _ctx)
		&"_apply_fear":
			return _apply_status_debuff("fear", effect, _ctx)
		&"_apply_ignore_guard":
			return {"ok": true, "reason": "damage_modifier", "id": str(effect.get("id", "ignore_guard")), "magnitude": maxi(0, int(effect.get("magnitude", 0)))}
		&"_apply_intent_revealed":
			return _apply_status_debuff("intent_revealed", effect, _ctx)
		&"_apply_life_steal":
			return {"ok": true, "reason": "life_steal_registered", "id": str(effect.get("id", "life_steal"))}
		&"_apply_link":
			return _apply_link(effect, _ctx)
		&"_apply_mark":
			return _apply_status_debuff("mark", effect, _ctx)
		&"_apply_mind_revealed":
			return _apply_status_debuff("mind_revealed", effect, _ctx)
		&"_apply_next_attack_damage_delta":
			return _apply_next_attack_damage_delta(effect, _ctx)
		&"_apply_pierce":
			return {"ok": true, "reason": "damage_modifier", "id": str(effect.get("id", "pierce")), "magnitude": maxi(0, int(effect.get("magnitude", 0)))}
		&"_apply_range_bonus":
			return {"ok": true, "reason": "damage_modifier", "id": str(effect.get("id", "range_bonus")), "magnitude": maxi(0, int(effect.get("magnitude", 0)))}
		&"_apply_revealed":
			return _apply_status_debuff("revealed", effect, _ctx)
		&"_apply_root":
			return _apply_status_debuff("root", effect, _ctx)
		&"_apply_self_damage":
			return _apply_self_damage(effect, _ctx)
		&"_apply_silence":
			return _apply_status_debuff("silence", effect, _ctx)
		&"_apply_slow":
			return _apply_status_debuff("slow", effect, _ctx)
		&"_apply_stealth":
			return _apply_status("stealth", effect, _ctx)
		&"_apply_stun":
			return _apply_status_debuff("stun", effect, _ctx)
	push_error("[EffectEngine] handler not implemented: %s" % str(handler_name))
	return {"ok": false, "reason": "handler_not_implemented", "id": str(effect.get("id", ""))}


static func _chance_gate(effect: Dictionary, id: String) -> Dictionary:
	if not effect.has("chance"):
		return {"passed": true}
	var chance := clampf(float(effect.get("chance", 1.0)), 0.0, 1.0)
	if chance <= 0.0:
		return {"ok": true, "passed": false, "reason": "chance_missed", "id": id, "chance": chance}
	if chance >= 1.0:
		return {"passed": true}
	var roll := randf()
	if roll >= chance:
		return {
			"ok": true,
			"passed": false,
			"reason": "chance_missed",
			"id": id,
			"chance": chance,
			"roll": roll,
		}
	return {"passed": true}


static func mechanism_for_effect_id(effect_id: String) -> String:
	return str(EFFECT_TO_MECHANISM.get(effect_id, ""))


static func _apply_charge(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	if battle == null or not battle.has_method("add_charged_effect"):
		return {"ok": false, "reason": "missing_charge_battle", "id": str(effect.get("id", ""))}
	var payload: Array = effect.get("payload", [])
	if not payload is Array:
		payload = []
	battle.add_charged_effect(
		ctx.get("source_card", null),
		ctx.get("target_actor", null),
		int(effect.get("magnitude", effect.get("duration", 1))),
		payload
	)
	return {"ok": true, "reason": "charged", "id": str(effect.get("id", ""))}


static func _apply_status(id: String, effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("add_status"):
		return {"ok": false, "reason": "missing_target", "id": id}
	var payload := _status_payload(id, effect)
	target.add_status(id, payload)
	return {
		"ok": true,
		"reason": "status_applied",
		"id": id,
		"magnitude": int(payload.get("magnitude", 0)),
		"payload": payload.duplicate(true),
		"target_id": _target_id(ctx, target),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}


static func _apply_status_debuff(id: String, effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("add_status"):
		return {"ok": false, "reason": "missing_target", "id": id}
	var block_result := _consume_incoming_debuff_block(target, id)
	if bool(block_result.get("blocked", false)):
		return {
			"ok": true,
			"reason": str(block_result.get("reason", "blocked_incoming_debuff")),
			"id": id,
			"blocked": true,
		}
	var payload := _status_payload(id, effect)
	target.add_status(id, payload)
	return {
		"ok": true,
		"reason": "status_applied",
		"id": id,
		"magnitude": int(payload.get("magnitude", 0)),
		"payload": payload.duplicate(true),
		"target_id": _target_id(ctx, target),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}


static func _apply_nightmare(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("add_status"):
		return {"ok": false, "reason": "missing_target", "id": "nightmare"}
	var block_result := _consume_incoming_debuff_block(target, "nightmare")
	if bool(block_result.get("blocked", false)):
		return {
			"ok": true,
			"reason": str(block_result.get("reason", "blocked_incoming_debuff")),
			"id": "nightmare",
			"blocked": true,
		}
	var payload := _status_payload("nightmare", effect)
	target.add_status("nightmare", payload)
	if not _incoming_debuff_blocked(target, "vulnerable"):
		var vulnerable_payload := _status_payload("vulnerable", effect)
		target.add_status("vulnerable", vulnerable_payload)
	return {
		"ok": true,
		"reason": "status_applied",
		"id": "nightmare",
		"magnitude": int(payload.get("magnitude", 0)),
		"payload": payload.duplicate(true),
		"target_id": _target_id(ctx, target),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}


static func _apply_cleanse_debuff(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("remove_status"):
		return {"ok": false, "reason": "missing_target", "id": "cleanse_debuff"}
	var types := _effect_types(effect)
	var removed: Array[String] = []
	var statuses = target.get("statuses")
	if statuses is Dictionary:
		for status_id in statuses.keys():
			if _matches_type(str(status_id), types):
				target.remove_status(str(status_id))
				removed.append(str(status_id))
	return {
		"ok": true,
		"reason": "cleanse_applied",
		"id": "cleanse_debuff",
		"removed": removed,
		"cleaned": not removed.is_empty(),
		"types": types,
		"target_id": _target_id(ctx, target),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}


static func _apply_paper_doll_marker(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = _target_or_source(ctx)
	if target == null or not target.has_method("add_marker"):
		return {"ok": false, "reason": "missing_marker_target", "id": "paper_doll_marker"}
	var amount := maxi(1, int(effect.get("magnitude", 1)))
	var max_stacks := int(effect.get("max_stacks", 3))
	var before := 0
	if target.has_method("get_marker_count"):
		before = int(target.get_marker_count("paper_doll"))
	var count: int = target.add_marker("paper_doll", amount, max_stacks)
	var added := maxi(0, count - before)
	return {
		"ok": true,
		"reason": "marker_added",
		"id": "paper_doll_marker",
		"count": count,
		"added": added,
		"magnitude": added,
		"max_stacks": max_stacks,
	}


static func _apply_create_or_move_flame_markers(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	if battle == null or not battle.has_method("add_field_marker"):
		return {"ok": false, "reason": "missing_field", "id": "create_or_move_flame_markers"}
	var amount := maxi(1, int(effect.get("magnitude", 1)))
	var max_stacks := int(effect.get("max_stacks", -1))
	var before := 0
	if battle.has_method("get_field_marker_count"):
		before = int(battle.get_field_marker_count("flame_markers"))
	var count: int = battle.add_field_marker("flame_markers", amount, max_stacks)
	var added := maxi(0, count - before)
	return {
		"ok": true,
		"reason": "field_marker_added",
		"id": "create_or_move_flame_markers",
		"count": count,
		"added": added,
		"magnitude": added,
	}


static func _apply_consume_flame_marker(_effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	if battle == null or not battle.has_method("consume_field_marker"):
		return {"ok": false, "reason": "missing_field", "id": "consume_flame_marker"}
	if not battle.consume_field_marker("flame_markers", 1):
		return {"ok": false, "reason": "missing_flame_marker", "id": "consume_flame_marker"}
	return {"ok": true, "reason": "field_marker_consumed", "id": "consume_flame_marker"}


static func _apply_teleport_to_flame(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	var target = ctx.get("target_actor", null)
	if battle == null or not battle.has_method("consume_field_marker") or target == null:
		return {"ok": false, "reason": "missing_flame_jump_context", "id": "teleport_to_flame"}
	if not battle.consume_field_marker("flame_markers", 1):
		return {"ok": false, "reason": "missing_flame_marker", "id": "teleport_to_flame"}
	var damage := int(effect.get("magnitude", 6))
	if battle.has_method("_deal_raw_damage"):
		battle._deal_raw_damage(target, damage)
	else:
		target.hp = max(0, int(target.hp) - damage)
	var remaining := 0
	if battle.has_method("get_field_marker_count"):
		remaining = int(battle.get_field_marker_count("flame_markers"))
	return {
		"ok": true,
		"reason": "teleported_to_flame",
		"id": "teleport_to_flame",
		"damage": damage,
		"consumed_markers": 1,
		"remaining_markers": remaining,
	}


static func _apply_adjacent_burn(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var field: Dictionary = ctx.get("field", {})
	var amount := maxi(1, int(effect.get("magnitude", 3)))
	field["adjacent_burn"] = amount
	return {"ok": true, "reason": "adjacent_burn_set", "id": "adjacent_burn", "magnitude": amount}


static func _apply_discard_top_deck(_effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	var field: Dictionary = ctx.get("field", {})
	if battle == null or not battle.has_method("_reshuffle_discard_into_draw"):
		return {"ok": false, "reason": "missing_battle", "id": "discard_top_deck"}
	field["last_discarded"] = null
	if battle.draw_pile.is_empty():
		battle._reshuffle_discard_into_draw()
	if battle.draw_pile.is_empty():
		return {"ok": false, "reason": "empty_draw_pile", "id": "discard_top_deck"}
	var discarded = battle.draw_pile.pop_front()
	if battle.has_method("_discard_card"):
		battle._discard_card(discarded, "discard_top_deck")
	else:
		battle.discard_pile.append(discarded)
	field["last_discarded"] = discarded
	return {
		"ok": true,
		"reason": "discarded_top_deck",
		"id": "discard_top_deck",
		"discarded_card_id": str(discarded.get("id")) if discarded != null and discarded.has_method("get") else "",
	}


static func _apply_bonus_if_attack(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var discarded = _field_last_discarded(ctx)
	if not _card_has_tag(discarded, "attack"):
		return {"ok": true, "reason": "condition_not_met", "id": "bonus_if_attack", "damage_bonus": 0}
	var bonus := int(effect.get("magnitude", 0))
	return {
		"ok": true,
		"reason": "attack_bonus_applied",
		"id": "bonus_if_attack",
		"damage_bonus": bonus,
	}


static func _apply_vulnerable_if_skill(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	return _apply_conditional_discard_status(
		"skill",
		"vulnerable",
		effect,
		ctx,
		str(effect.get("id", "vulnerable_if_skill"))
	)


static func _apply_vulnerable_if_skill_played(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	return _apply_conditional_played_tag_status(
		"skill",
		"vulnerable",
		effect,
		ctx,
		str(effect.get("id", "vulnerable_if_skill_played"))
	)


static func _apply_weak_if_status(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	return _apply_conditional_discard_status("status", "weak", effect, ctx, "weak_if_status")


static func _apply_create_random_temp_card(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	if battle == null or not battle.has_method("get"):
		return {"ok": false, "reason": "missing_battle", "id": "create_random_temp_card"}
	var options = effect.get("options", [])
	if not options is Array or options.is_empty():
		return {"ok": false, "reason": "missing_options", "id": "create_random_temp_card"}
	var selected = options[randi() % options.size()]
	if not selected is Dictionary:
		return {"ok": false, "reason": "invalid_option", "id": "create_random_temp_card"}
	var temp_card = CardScript.from_json(selected)
	if temp_card == null:
		return {"ok": false, "reason": "card_build_failed", "id": "create_random_temp_card"}
	battle.draw_pile.push_front(temp_card)
	return {
		"ok": true,
		"reason": "temp_card_created",
		"id": "create_random_temp_card",
		"card_id": str(temp_card.get("id")),
		"card_name": temp_card.get_display_name(),
		"destination": "draw_pile_top",
	}


static func _apply_draw_if_no_cleanse(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	if battle == null or not battle.has_method("_draw"):
		return {"ok": false, "reason": "missing_battle", "id": "draw_if_no_cleanse"}
	var draw_count := maxi(1, int(effect.get("magnitude", 1)))
	var field: Dictionary = ctx.get("field", {})
	var cleanse_result = field.get("last_cleanse_result", {}) if field is Dictionary else {}
	if cleanse_result is Dictionary and str(cleanse_result.get("id", "")) == "cleanse_debuff" and bool(cleanse_result.get("cleaned", false)):
		return {
			"ok": true,
			"reason": "draw_skipped_after_cleanse",
			"id": "draw_if_no_cleanse",
			"drawn": 0,
			"cleaned": true,
			"cleaned_ids": cleanse_result.get("removed", []),
			"target_id": str(cleanse_result.get("target_id", _target_id(ctx, ctx.get("target_actor", null)))),
			"source_card_id": _card_id(ctx.get("source_card", null)),
		}
	battle._draw(draw_count)
	return {
		"ok": true,
		"reason": "drew_cards",
		"id": "draw_if_no_cleanse",
		"drawn": draw_count,
		"cleaned": false,
		"target_id": _target_id(ctx, ctx.get("target_actor", null)),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}


static func _apply_draw_filter(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	if battle == null or not battle.has_method("_reshuffle_discard_into_draw"):
		return {"ok": false, "reason": "missing_battle", "id": "draw_filter"}
	var choose_count := maxi(1, int(effect.get("choose", 1)))
	var peek_count := maxi(choose_count, int(effect.get("peek", 3)))
	var peeked: Array = []
	while peeked.size() < peek_count:
		if battle.draw_pile.is_empty():
			battle._reshuffle_discard_into_draw()
		if battle.draw_pile.is_empty():
			break
		peeked.append(battle.draw_pile.pop_front())
	var peeked_count := peeked.size()
	if peeked.is_empty():
		return {
			"ok": true,
			"reason": "empty_draw_pile",
			"id": "draw_filter",
			"peeked": 0,
			"selected_count": 0,
			"selected_card_id": "",
			"selected_card_ids": [],
		}
	var available_slots := maxi(0, int(battle.hand_limit) - battle.hand.size())
	var actual_choose := mini(choose_count, mini(peeked.size(), available_slots))
	var selected_cards: Array = []
	for i in range(actual_choose):
		selected_cards.append(peeked.pop_front())
	for selected in selected_cards:
		battle.hand.append(selected)
	_return_draw_filter_rest(peeked, battle, str(effect.get("rest_policy", "return_top")))
	var selected_ids: Array[String] = []
	for selected in selected_cards:
		selected_ids.append(_card_id(selected))
	return {
		"ok": true,
		"reason": "draw_filter_applied",
		"id": "draw_filter",
		"peeked": peeked_count,
		"selected_count": selected_cards.size(),
		"selected_card_id": selected_ids[0] if not selected_ids.is_empty() else "",
		"selected_card_ids": selected_ids,
	}


static func _return_draw_filter_rest(cards: Array, battle, rest_policy: String) -> void:
	match rest_policy:
		"discard":
			for card in cards:
				if battle.has_method("_discard_card"):
					battle._discard_card(card, "draw_filter_rest")
				else:
					battle.discard_pile.append(card)
		"return_bottom":
			for card in cards:
				battle.draw_pile.append(card)
		_:
			for i in range(cards.size() - 1, -1, -1):
				battle.draw_pile.push_front(cards[i])


static func _card_id(card) -> String:
	if card == null or not card.has_method("get"):
		return ""
	var value: Variant = card.get("id")
	return "" if value == null else str(value)


static func _apply_execute_bonus_below_hp_pct(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = ctx.get("target_actor", null)
	var threshold := float(effect.get("threshold", 0.0))
	var bonus_damage := maxi(0, int(effect.get("bonus_damage", effect.get("magnitude", 0))))
	var target_hp_pct := 0.0
	if target != null and target.has_method("get"):
		var max_hp := maxi(1, int(target.get("max_hp")))
		target_hp_pct = float(int(target.get("hp"))) / float(max_hp)
	var result := {
		"ok": true,
		"reason": "condition_not_met",
		"id": str(effect.get("id", "execute_bonus_below_hp_pct")),
		"triggered": false,
		"bonus_damage": 0,
		"threshold": threshold,
		"target_hp_pct": target_hp_pct,
		"target_id": _target_id(ctx, target),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}
	if target != null and threshold > 0.0 and bonus_damage > 0 and target_hp_pct <= threshold:
		result["reason"] = "damage_modifier"
		result["triggered"] = true
		result["bonus_damage"] = bonus_damage
		result["magnitude"] = bonus_damage
	return result


static func _apply_next_fool_skill_cost_delta(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var source = ctx.get("source_actor", null)
	if source == null or not source.has_method("add_status"):
		return {"ok": false, "reason": "missing_source", "id": "next_fool_skill_cost_delta"}
	var payload := _status_payload("next_card_cost_delta", effect)
	payload["duration"] = 1
	payload["pathway"] = "fool"
	payload["required_tag"] = "skill"
	source.add_status("next_card_cost_delta", payload)
	return {
		"ok": true,
		"reason": "next_card_cost_delta_applied",
		"id": "next_fool_skill_cost_delta",
		"magnitude": int(payload.get("magnitude", 0)),
		"pathway": str(payload.get("pathway", "")),
		"required_tag": str(payload.get("required_tag", "")),
		"payload": payload.duplicate(true),
	}


static func _apply_attack_play_damage_growth(effect: Dictionary, _ctx: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"reason": "attack_play_damage_growth_registered",
		"id": str(effect.get("id", "attack_play_damage_growth")),
		"magnitude": int(effect.get("magnitude", 0)),
		"cap": int(effect.get("cap", 0)),
	}


static func _apply_per_use_damage_growth(effect: Dictionary, _ctx: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"reason": "per_use_damage_growth_registered",
		"id": str(effect.get("id", "per_use_damage_growth")),
		"magnitude": int(effect.get("magnitude", 0)),
		"cap": int(effect.get("cap", 0)),
	}


static func _apply_cost_zero_if_flame_stream(effect: Dictionary, _ctx: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"reason": "cost_modifier_registered",
		"id": str(effect.get("id", "cost_zero_if_flame_stream")),
	}


static func _apply_select_targets(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"reason": "target_selection_registered",
		"id": str(effect.get("id", "select_targets")),
		"selected_count": _selected_target_count(ctx),
		"min": int(effect.get("min", 1)),
		"max": int(effect.get("max", 1)),
	}


static func _apply_multi_strike(effect: Dictionary, _ctx: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"reason": "multi_strike_registered",
		"id": str(effect.get("id", "multi_strike")),
		"hits": maxi(1, int(effect.get("hits", effect.get("magnitude", 1)))),
		"damage_each": int(effect.get("damage_each", effect.get("magnitude", 0))),
	}


static func _apply_reroll_next_damage_target(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var source = ctx.get("source_actor", null)
	if source == null or not source.has_method("add_status"):
		return {"ok": false, "reason": "missing_source", "id": "reroll_next_damage_target"}
	var payload := _status_payload("reroll_next_target", effect)
	payload["duration"] = 1
	source.add_status("reroll_next_target", payload)
	return {
		"ok": true,
		"reason": "reroll_next_target_applied",
		"id": "reroll_next_damage_target",
		"payload": payload.duplicate(true),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}


static func _apply_avoid_counter_intent(effect: Dictionary, _ctx: Dictionary) -> Dictionary:
	var field_state: Dictionary = _ctx.get("field", {}) if _ctx.get("field", {}) is Dictionary else {}
	var counter_result: Dictionary = field_state.get("last_counter_result", {}) if field_state.get("last_counter_result", {}) is Dictionary else {}
	var skipped_ids: Array = []
	var raw_skipped: Variant = counter_result.get("skipped", [])
	if raw_skipped is Array:
		for raw_id in raw_skipped:
			skipped_ids.append(str(raw_id))
	return {
		"ok": true,
		"reason": "counter_intent_avoided",
		"id": str(effect.get("id", "avoid_counter_intent")),
		"skipped_ids": skipped_ids,
		"skipped_count": skipped_ids.size(),
	}


static func _apply_break_block(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("get"):
		return {"ok": false, "reason": "missing_target", "id": "break_block"}
	var amount := maxi(1, int(effect.get("magnitude", 3)))
	var current_def := int(target.get("def"))
	target.set("def", maxi(0, current_def - amount))
	if target.has_method("add_status"):
		var payload := _status_payload("break_block", effect)
		payload["magnitude"] = amount
		target.add_status("break_block", payload)
	return {"ok": true, "reason": "defense_broken", "id": "break_block", "magnitude": amount}


static func _apply_block_break(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("get"):
		return {"ok": false, "reason": "missing_target", "id": "block_break"}
	var amount := maxi(1, int(effect.get("magnitude", 3)))
	var current_def := int(target.get("def"))
	var next_def := maxi(0, current_def - amount)
	target.set("def", next_def)
	return {
		"ok": true,
		"reason": "defense_shredded",
		"id": "block_break",
		"magnitude": amount,
		"def_before": current_def,
		"def_after": next_def,
	}


static func _apply_link(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	var target = ctx.get("target_actor", null)
	var source = ctx.get("source_actor", null)
	var source_card = ctx.get("source_card", null)
	if battle == null or target == null or not battle.has_method("_deal_raw_damage"):
		return {"ok": false, "reason": "missing_link_context", "id": "link"}
	var base_damage := 0
	if source_card != null and source_card.has_method("get"):
		base_damage = int(source_card.get("damage"))
	var splash := maxi(1, int(effect.get("magnitude", ceili(float(base_damage) * 0.5))))
	var hit: Array[String] = []
	for enemy in battle.enemies:
		if enemy == null or enemy == target or enemy.is_dead():
			continue
		battle._deal_raw_damage(enemy, splash, source)
		hit.append(str(enemy.id))
	return {
		"ok": true,
		"reason": "linked_damage",
		"id": "link",
		"damage": splash,
		"targets": hit,
		"primary_target_id": _target_id(ctx, target),
		"source_card_id": _card_id(source_card),
	}


static func _apply_next_attack_damage_delta(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var source = ctx.get("source_actor", null)
	if source == null or not source.has_method("add_status"):
		return {"ok": false, "reason": "missing_source", "id": "next_attack_damage_delta"}
	var payload := _status_payload("next_attack_damage_delta", effect)
	payload["duration"] = int(payload.get("duration", 1))
	source.add_status("next_attack_damage_delta", payload)
	return {
		"ok": true,
		"reason": "next_attack_damage_delta_applied",
		"id": "next_attack_damage_delta",
		"magnitude": int(payload.get("magnitude", 0)),
		"payload": payload.duplicate(true),
		"target_id": _target_id(ctx, source),
		"source_card_id": _card_id(ctx.get("source_card", null)),
	}


static func _apply_self_damage(effect: Dictionary, ctx: Dictionary) -> Dictionary:
	var battle = ctx.get("battle", null)
	var source = ctx.get("source_actor", null)
	var source_card = ctx.get("source_card", null)
	if battle == null or source == null or not battle.has_method("_deal_raw_damage"):
		return {"ok": false, "reason": "missing_self_damage_context", "id": "self_damage"}
	var base_damage := 0
	if source_card != null and source_card.has_method("get"):
		base_damage = int(source_card.get("damage"))
	var amount := maxi(1, int(effect.get("magnitude", ceili(float(base_damage) * 0.25))))
	battle._deal_raw_damage(source, amount, null)
	return {"ok": true, "reason": "self_damage_applied", "id": "self_damage", "damage": amount}


static func _with_default(effect: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := effect.duplicate(true)
	if not copy.has(key):
		copy[key] = value
	return copy


static func _status_payload(id: String, effect: Dictionary) -> Dictionary:
	var payload := effect.duplicate(true)
	payload["id"] = id
	return payload


static func _selected_target_count(ctx: Dictionary) -> int:
	var field: Dictionary = ctx.get("field", {})
	var selected = field.get("selected_targets", []) if field is Dictionary else []
	if selected is Array:
		return selected.size()
	return 0


static func _apply_conditional_discard_status(required_tag: String, status_id: String, effect: Dictionary, ctx: Dictionary, effect_id: String) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("add_status"):
		return {"ok": false, "reason": "missing_target", "id": effect_id}
	var discarded = _field_last_discarded(ctx)
	if not _card_has_tag(discarded, required_tag):
		return {"ok": true, "reason": "condition_not_met", "id": effect_id}
	var block_result := _consume_incoming_debuff_block(target, status_id)
	if bool(block_result.get("blocked", false)):
		return {
			"ok": true,
			"reason": str(block_result.get("reason", "blocked_incoming_debuff")),
			"id": effect_id,
			"blocked": true,
		}
	var payload := _status_payload(status_id, effect)
	if not payload.has("duration") and payload.has("magnitude"):
		payload["duration"] = int(payload.get("magnitude", 0))
	payload["source_effect_id"] = effect_id
	target.add_status(status_id, payload)
	return {
		"ok": true,
		"reason": "conditional_status_applied",
		"id": effect_id,
		"applied_status": status_id,
		"payload": payload.duplicate(true),
	}


static func _apply_conditional_played_tag_status(required_tag: String, status_id: String, effect: Dictionary, ctx: Dictionary, effect_id: String) -> Dictionary:
	var target = ctx.get("target_actor", null)
	if target == null or not target.has_method("add_status"):
		return {"ok": false, "reason": "missing_target", "id": effect_id}
	if not _played_tag_this_turn(ctx, required_tag):
		return {"ok": true, "reason": "condition_not_met", "id": effect_id, "trigger": "prior_%s_this_turn" % required_tag}
	var block_result := _consume_incoming_debuff_block(target, status_id)
	if bool(block_result.get("blocked", false)):
		return {
			"ok": true,
			"reason": str(block_result.get("reason", "blocked_incoming_debuff")),
			"id": effect_id,
			"blocked": true,
		}
	var payload := _status_payload(status_id, effect)
	if not payload.has("duration") and payload.has("magnitude"):
		payload["duration"] = int(payload.get("magnitude", 0))
	payload["source_effect_id"] = effect_id
	target.add_status(status_id, payload)
	return {
		"ok": true,
		"reason": "conditional_status_applied",
		"id": effect_id,
		"applied_status": status_id,
		"payload": payload.duplicate(true),
		"source_card_id": _card_id(ctx.get("source_card", null)),
		"target_id": _target_id(ctx, target),
		"trigger": "prior_%s_this_turn" % required_tag,
	}


static func _consume_incoming_debuff_block(target, status_id: String) -> Dictionary:
	if _status_matches(target, "cleanse_incoming_debuff", status_id):
		if target.has_method("remove_status"):
			target.remove_status("cleanse_incoming_debuff")
		return {"blocked": true, "reason": "cleanse_incoming_debuff"}
	if _status_matches(target, "immune_debuff", status_id):
		return {"blocked": true, "reason": "immune_debuff"}
	return {"blocked": false}


static func _incoming_debuff_blocked(target, status_id: String) -> bool:
	return bool(_consume_incoming_debuff_block(target, status_id).get("blocked", false))


static func _status_matches(target, guard_id: String, status_id: String) -> bool:
	if target == null or not target.has_method("has_status") or not target.has_status(guard_id):
		return false
	var statuses = target.get("statuses")
	var payload: Dictionary = statuses.get(guard_id, {}) if statuses is Dictionary else {}
	return _matches_type(status_id, _effect_types(payload))


static func _matches_type(status_id: String, types: Array[String]) -> bool:
	if types.is_empty():
		return true
	return status_id in types


static func _effect_types(effect: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw_types = effect.get("types", [])
	if raw_types is Array:
		for item in raw_types:
			result.append(str(item))
	return result


static func _target_or_source(ctx: Dictionary):
	var target = ctx.get("target_actor", null)
	if target != null:
		return target
	return ctx.get("source_actor", null)


static func _field_last_discarded(ctx: Dictionary):
	var field: Dictionary = ctx.get("field", {})
	if field is Dictionary:
		return field.get("last_discarded", null)
	return null


static func _played_tag_this_turn(ctx: Dictionary, tag: String) -> bool:
	var field: Dictionary = ctx.get("field", {})
	if not field is Dictionary:
		return false
	var raw_tags: Variant = field.get("played_card_tags_this_turn", [])
	if not raw_tags is Array:
		return false
	for raw_tag in raw_tags:
		if str(raw_tag) == tag:
			return true
	return false


static func _card_has_tag(card, tag: String) -> bool:
	if card == null or not card.has_method("get"):
		return false
	var tags = card.get("tags") if card.has_method("get") else []
	if not tags is Array:
		return false
	for item in tags:
		if str(item) == tag:
			return true
	return false


static func _actor_id(actor) -> String:
	if actor == null or not actor.has_method("get"):
		return ""
	var value: Variant = actor.get("id")
	return "" if value == null else str(value)


static func _target_id(ctx: Dictionary, target) -> String:
	var id := _actor_id(target)
	if id == "" and target != null and target == ctx.get("source_actor", null):
		return "player"
	return id


static func _build_ctx(
	source_actor = null,
	target_actor = null,
	source_card = null,
	battle = null,
	field = null
) -> Dictionary:
	return {
		"source_actor": source_actor,
		"target_actor": target_actor,
		"source_card": source_card,
		"battle": battle,
		"field": field if field != null else {},
	}
