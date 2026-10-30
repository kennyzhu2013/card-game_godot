extends Node

signal battle_log_entry(message: String)

const EnemyAiScript = preload("res://scripts/combat/enemy_ai.gd")
const ElementTableScript = preload("res://scripts/combat/element_table.gd")
const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const EffectEngineScript = preload("res://scripts/combat/effect_engine.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const CardLibraryScript = preload("res://scripts/combat/card_library.gd")
const SequenceExpServiceScript = preload("res://scripts/sequence/sequence_exp_service.gd")
const WeatherEffectsApplierScript = preload("res://scripts/state/weather_effects_applier.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

# Per design/2026-05-24-tower-deck-combat-redesign.md §1.1
# 回合制爬塔卡牌战斗的入口骨架。MVP 阶段仅占位 API；
# 完整实现合入切片 1（cards/active_deck → 抽弃牌堆 → 能量结算 → 回合）。

# 战斗状态
enum Phase { READY, PLAYER_TURN, ENEMY_TURN, RESOLVE, END }

# paper_blade is checked via card.tags; display_name/id fallback is intentionally disallowed.
const CARD_TYPE_TAGS := ["attack", "skill", "status", "temporary", "social", "world"]
const DOT_STATUS_IDS := ["burn", "poison"]
const PRE_DAMAGE_EFFECT_IDS := ["block_break", "execute_bonus_below_hp_pct"]
const PLAYER_ACTION_TICK_STATUS_IDS := [
	"weak", "blind", "confusion", "nightmare", "fear", "obscure_intent", "mp_cost_up",
	"stun", "silence", "bind", "root", "slow", "chill", "delay_intent", "displace",
	"face_mask_redirect",
]
const TURN_START_TICK_STATUS_IDS := [
	"vulnerable", "mark", "def_buff", "atk_boost", "hp_boost", "invulnerable",
	"stealth", "immune_debuff", "cleanse_incoming_debuff", "fatal_damage_convert",
	"consume_on_trigger", "damage_reduction", "absorb_fatal_or_curse",
	"dodge_counter", "counter_spell", "revealed", "intent_revealed", "mind_revealed",
]
const ACTION_BLOCK_STATUS_IDS := ["stun", "bind", "root", "delay_intent", "fear", "slow", "chill", "displace"]
const ENEMY_WEAKNESS_DAMAGE_MULTIPLIER := 1.5
const ENEMY_RESISTANCE_DAMAGE_MULTIPLIER := 0.75
const SEQUENCE_MECHANICS_GATE := {
	9: ["intent_reveal", "draw_filter", "charge_skill", "damage_reduction", "status"],
	8: [
		"intent_reveal", "draw_filter", "charge_skill", "damage_reduction",
		"status", "multi_strike", "multi_target", "dodge_counter", "mind_read", "paper_blade", "block_break",
	],
	7: [
		"intent_reveal", "draw_filter", "charge_skill", "damage_reduction",
		"status", "multi_strike", "multi_target", "dodge_counter", "mind_read", "paper_blade", "block_break",
		"position_shift", "paper_doll", "field_marker", "control", "summon_marker",
		"pierce", "cleanse", "deck_transform", "temporary_card", "cost_mod",
	],
}

var phase: int = Phase.READY
var energy: int = 3
var energy_max: int = 3
var hand_limit: int = 10
var draw_per_turn: int = 5
var battle_sequence: int = 9
var turn_count: int = 0

var draw_pile: Array = []      # Array[Card]
var hand: Array = []           # Array[Card]
var discard_pile: Array = []   # Array[Card]
var exhaust_pile: Array = []   # Array[Card] —— 当层失效卡

var contracted_rules: Array[String] = []  # 当周目玩家选定的扮演契约（3 条）
var rule_satisfaction: Dictionary = {}    # rule -> "satisfied" / "violated" / "unresolved"
var rule_to_source_cards: Dictionary = {} # rule -> Array[card.id] 关联到该规则的 used_card
var used_cards: Dictionary = {}           # card.id -> Card
var disabled_in_floor: Dictionary = {}    # card.id -> true（违反契约后当层失效）

var player = null
var _game_state = null
var enemies: Array = []        # Array[Enemy]
var temp_picked_cards: Array = []  # 塔内拾取的临时卡（≤5）
var current_enemy_intents: Dictionary = {}

var revealed_enemy_intent_details: Dictionary = {}
var field_state: Dictionary = {"flame_markers": 0}
var charged_zone: Array = []
var delayed_card_effects: Array = []
var next_turn_start_card_effects: Array = []
var resolved_charge_payloads: Array = []
var last_effect_results: Array = []
var pending_draw_filter: Dictionary = {}

var _element_table = null
var _ai_gm_service = null
var _last_decisive_card_id: String = ""
var _last_decisive_target_id: String = ""
var _last_decisive_hp_remaining: int = 0


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func setup_battle(
	active_deck: Array,
	picked_cards: Array,
	enemies_in: Array,
	contract: Array[String],
	player_actor = null,
	game_state = null
) -> void:
	player = player_actor
	_game_state = game_state
	battle_sequence = int(game_state.sequence) if game_state != null else 9
	energy_max = energy_for_sequence(battle_sequence)
	draw_pile = active_deck.duplicate()
	temp_picked_cards = picked_cards.duplicate()
	for c in picked_cards:
		draw_pile.append(c)
	_record_battle_witnessed(active_deck)
	_record_battle_witnessed(picked_cards)
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	clear_field_state()
	charged_zone.clear()
	delayed_card_effects.clear()
	next_turn_start_card_effects.clear()
	resolved_charge_payloads.clear()
	last_effect_results.clear()
	pending_draw_filter.clear()
	revealed_enemy_intent_details.clear()
	_last_decisive_card_id = ""
	_last_decisive_target_id = ""
	_last_decisive_hp_remaining = 0
	enemies = enemies_in.duplicate()
	contracted_rules = contract.duplicate()
	rule_satisfaction.clear()
	rule_to_source_cards.clear()
	used_cards.clear()
	disabled_in_floor.clear()
	for r in contracted_rules:
		rule_satisfaction[r] = "unresolved"
		rule_to_source_cards[r] = []
	turn_count = 0
	_element_table = ElementTableScript.new()
	_element_table.load_table()
	current_enemy_intents = preview_enemy_intents()
	phase = Phase.PLAYER_TURN
	_tick_actor_statuses_only(player, PLAYER_ACTION_TICK_STATUS_IDS)
	_start_player_turn()


static func energy_for_sequence(sequence: int) -> int:
	if sequence <= 0:
		return 8
	if sequence <= 1:
		return 7
	if sequence <= 3:
		return 6
	if sequence <= 5:
		return 5
	if sequence <= 7:
		return 4
	return 3


func _start_player_turn() -> void:
	_reset_played_cards_this_turn()
	var nightmare_active := _actor_has_status(player, "nightmare")
	_tick_actor_turn_start(player)
	_tick_charged_effects()
	_tick_delayed_card_effects()
	_tick_next_turn_start_card_effects()
	energy = energy_max
	var draw_count := draw_per_turn
	if nightmare_active or _actor_has_status(player, "nightmare"):
		draw_count = maxi(0, draw_count - 1)
	_draw(draw_count)
	_auto_play_lost_control_turn_if_needed()


func _draw(n: int) -> void:
	for i in n:
		if hand.size() >= hand_limit:
			return
		if draw_pile.is_empty():
			_reshuffle_discard_into_draw()
			if draw_pile.is_empty():
				return
		hand.append(draw_pile.pop_back())


func _reshuffle_discard_into_draw() -> void:
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()


func play_card(card: Card, target = null) -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	if not card in hand:
		return false
	if not can_play_card(card):
		return false
	if not _card_target_selection_valid(card, target):
		return false
	var paid_result := _pay_and_remove_played_card(card)
	if not bool(paid_result.get("ok", false)):
		return false
	var on_play_result := _apply_on_play_brand_effects(card, target, int(paid_result.get("paid_cost", 0)))
	var killed_targets: Array = []
	if not bool(on_play_result.get("delay_card_effect", false)):
		killed_targets = _apply_card_effect(card, target)
	_complete_played_card(card, target, killed_targets)
	return true


func prepare_draw_filter_choice(card: Card, target = null) -> Dictionary:
	var effect := _draw_filter_effect(card)
	if effect.is_empty():
		return {"ok": false, "reason": "missing_draw_filter", "id": "draw_filter"}
	if phase != Phase.PLAYER_TURN:
		return {"ok": false, "reason": "not_player_turn", "id": "draw_filter"}
	if not card in hand:
		return {"ok": false, "reason": "not_in_hand", "id": "draw_filter"}
	if not can_play_card(card):
		return {"ok": false, "reason": _card_play_rule_block_reason(card), "id": "draw_filter"}
	if not _card_target_selection_valid(card, target):
		return {"ok": false, "reason": "invalid_target", "id": "draw_filter"}
	var paid_result := _pay_and_remove_played_card(card)
	if not bool(paid_result.get("ok", false)):
		return {"ok": false, "reason": "energy_short", "id": "draw_filter"}
	var on_play_result := _apply_on_play_brand_effects(card, target, int(paid_result.get("paid_cost", 0)))
	if bool(on_play_result.get("delay_card_effect", false)):
		_complete_played_card(card, target, [])
		return {
			"ok": true,
			"reason": "delayed_card_effect_pending",
			"id": "draw_filter",
			"resolved": true,
			"candidates": [],
			"result": on_play_result,
		}
	var candidates := _take_draw_filter_candidates(effect)
	if candidates.is_empty():
		var empty_result := _resolve_draw_filter_selection(effect, candidates, 0)
		last_effect_results.append(empty_result)
		var killed_targets: Array = _apply_card_effect(card, target, ["draw_filter"])
		_complete_played_card(card, target, killed_targets)
		return {
			"ok": true,
			"reason": "empty_draw_pile",
			"id": "draw_filter",
			"resolved": true,
			"candidates": [],
			"result": empty_result,
		}
	pending_draw_filter = {
		"source_card": card,
		"target_actor": target,
		"effect": effect.duplicate(true),
		"candidates": candidates,
		"peeked": candidates.size(),
	}
	return {
		"ok": true,
		"reason": "draw_filter_pending",
		"id": "draw_filter",
		"resolved": false,
		"candidates": candidates.duplicate(),
		"peeked": candidates.size(),
	}


func resolve_draw_filter_choice(index: int) -> Dictionary:
	if pending_draw_filter.is_empty():
		return {"ok": false, "reason": "no_pending_draw_filter", "id": "draw_filter"}
	var card = pending_draw_filter.get("source_card", null)
	var target = pending_draw_filter.get("target_actor", null)
	var effect: Dictionary = pending_draw_filter.get("effect", {})
	var candidates: Array = pending_draw_filter.get("candidates", [])
	pending_draw_filter.clear()
	if card == null:
		return {"ok": false, "reason": "missing_source_card", "id": "draw_filter"}
	var result := _resolve_draw_filter_selection(effect, candidates, index)
	last_effect_results.append(result)
	var killed_targets: Array = _apply_card_effect(card, target, ["draw_filter"])
	_complete_played_card(card, target, killed_targets)
	return result


func _draw_filter_effect(card: Card) -> Dictionary:
	if card == null:
		return {}
	for effect in card.status_effects:
		if effect is Dictionary and str(effect.get("id", "")) == "draw_filter":
			return (effect as Dictionary).duplicate(true)
	return {}


func _take_draw_filter_candidates(effect: Dictionary) -> Array:
	var choose_count := maxi(1, int(effect.get("choose", 1)))
	var peek_count := maxi(choose_count, int(effect.get("peek", 3)))
	var candidates: Array = []
	while candidates.size() < peek_count:
		if draw_pile.is_empty():
			_reshuffle_discard_into_draw()
		if draw_pile.is_empty():
			break
		candidates.append(draw_pile.pop_front())
	return candidates


func _resolve_draw_filter_selection(effect: Dictionary, candidates: Array, selected_index: int) -> Dictionary:
	var peeked_count := candidates.size()
	if candidates.is_empty():
		return {
			"ok": true,
			"reason": "empty_draw_pile",
			"id": "draw_filter",
			"peeked": 0,
			"selected_count": 0,
			"selected_card_id": "",
			"selected_card_ids": [],
		}
	var remaining := candidates.duplicate()
	var choose_count := maxi(1, int(effect.get("choose", 1)))
	var available_slots := maxi(0, int(hand_limit) - hand.size())
	var actual_choose := mini(choose_count, mini(remaining.size(), available_slots))
	var selected_cards: Array = []
	if actual_choose > 0:
		var clamped_index := clampi(selected_index, 0, remaining.size() - 1)
		selected_cards.append(remaining[clamped_index])
		remaining.remove_at(clamped_index)
	while selected_cards.size() < actual_choose and not remaining.is_empty():
		selected_cards.append(remaining.pop_front())
	for selected in selected_cards:
		hand.append(selected)
	_return_draw_filter_rest(remaining, str(effect.get("rest_policy", "return_top")))
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


func _return_draw_filter_rest(cards: Array, rest_policy: String) -> void:
	match rest_policy:
		"discard":
			for card in cards:
				_discard_card(card, "draw_filter_rest")
		"return_bottom":
			for card in cards:
				draw_pile.append(card)
		_:
			for i in range(cards.size() - 1, -1, -1):
				draw_pile.push_front(cards[i])


func _pay_and_remove_played_card(card: Card) -> Dictionary:
	var next_card_cost_delta_applies: bool = _card_uses_next_card_cost_delta(card) and player != null and player.has_status("next_card_cost_delta")
	var effective_cost := _effective_card_cost(card)
	if effective_cost > energy:
		return {"ok": false, "reason": "energy_short", "paid_cost": 0}
	energy -= effective_cost
	_mark_first_play_brand_cost_overrides_used(card)
	_trigger_counter_intents(card)
	hand.erase(card)
	_mark_card_rules_satisfied(card)
	if next_card_cost_delta_applies and player != null and player.has_method("remove_status"):
		player.remove_status("next_card_cost_delta")
	return {"ok": true, "reason": "paid", "paid_cost": effective_cost}


func can_play_card(card: Card) -> bool:
	return _card_play_rule_block_reason(card) == ""


func card_play_block_reason(card: Card) -> String:
	if phase != Phase.PLAYER_TURN:
		return "not_player_turn"
	var reason := _card_play_rule_block_reason(card)
	if reason != "":
		return reason
	if _effective_card_cost(card) > energy:
		return "energy_short"
	return ""


func _auto_play_lost_control_turn_if_needed() -> void:
	if _game_state == null or not bool(_game_state.is_lost_control):
		return
	if phase != Phase.PLAYER_TURN:
		return
	var seed := _lost_control_auto_seed()
	var result: Dictionary = lost_control_auto_play_turn(seed)
	if bool(result.get("dead", false)):
		phase = Phase.RESOLVE
		return
	if phase == Phase.PLAYER_TURN:
		phase = Phase.ENEMY_TURN


func _lost_control_auto_seed() -> int:
	if _game_state == null:
		return absi(hash("lost_control:0:%d" % int(turn_count)))
	var cycle_value := int(_game_state.cycle) if _game_state.has_method("get") else 0
	var day_value := int(_game_state.day) if _game_state.has_method("get") else 0
	var elapsed := 0
	if _game_state.has_method("get"):
		var state: Variant = _game_state.get("lost_control_state")
		if state is Dictionary:
			elapsed = int((state as Dictionary).get("turns_elapsed", 0))
	return absi(hash("lost_control:%d:%d:%d:%d" % [cycle_value, day_value, int(turn_count), elapsed]))


func _card_play_rule_block_reason(card: Card) -> String:
	if card == null:
		return "missing_card"
	if disabled_in_floor.get(card.id, false):
		return "contract_disabled"
	var unlock_check := card_unlock_check_for_sequence(card, battle_sequence)
	if not bool(unlock_check.get("ok", false)):
		return str(unlock_check.get("reason", "mechanic_locked"))
	if _card_requires_flame_marker(card) and get_field_marker_count("flame_markers") <= 0:
		return "flame_marker_required"
	if _actor_has_status(player, "fear") and _card_has_tag(card, "attack"):
		return "fear"
	return ""


func _complete_played_card(card: Card, target, killed_targets: Array) -> void:
	if card == null:
		return
	_record_decisive_play(card, target, killed_targets)
	_mark_enemy_intents_revealed(card, target)
	_record_paper_blade_kills(card, killed_targets)
	card.record_play()
	_record_played_card_this_turn(card)
	_apply_permanent_transform_brand_effects(card)
	used_cards[card.id] = card
	_trigger_card_brands(card, "after_play", target, killed_targets)
	_schedule_next_turn_start_brand_effects(card, target)
	if not _card_is_charging(card):
		_discard_card(card, "played")
	_record_attack_play_growth(card)


func _apply_permanent_transform_brand_effects(card: Card) -> void:
	if card == null:
		return
	for payload in _card_permanent_transform_brand_payloads(card):
		var result := _apply_permanent_transform_brand_effect(payload, card)
		if not result.is_empty():
			last_effect_results.append(result)


func _card_permanent_transform_brand_payloads(card: Card) -> Array:
	var results: Array = []
	if card == null:
		return results
	var seen_ids := {}
	for brand_id in card.brands:
		var id := str(brand_id)
		if bool(seen_ids.get(id, false)):
			continue
		seen_ids[id] = true
		var brand = BrandCatalogScript.create_brand(id)
		if brand == null or str(brand.effect_type) != "transform":
			continue
		var payload: Dictionary = brand.effect_payload.duplicate(true)
		if int(payload.get("play_count_threshold", 0)) <= 0:
			continue
		payload["source_brand"] = str(brand.id)
		payload["source_brand_effect_type"] = str(brand.effect_type)
		results.append(payload)
	return results


func _apply_permanent_transform_brand_effect(payload: Dictionary, card: Card) -> Dictionary:
	var brand_id := str(payload.get("source_brand", ""))
	if brand_id == "" or card == null:
		return {}
	var threshold := maxi(1, int(payload.get("play_count_threshold", 0)))
	if int(card.play_count) < threshold:
		return {}
	var flags := _card_brand_transform_flags(card)
	if bool(flags.get(brand_id, false)):
		return {}
	var before_damage := int(card.damage)
	var before_slots := int(card.brand_slots)
	var multiplier := float(payload.get("damage_multiplier", 1.0))
	if multiplier > 0.0 and multiplier != 1.0:
		card.damage = maxi(0, int(round(float(card.damage) * multiplier)))
	var bonus_slots := int(payload.get("bonus_brand_slots", 0))
	if bonus_slots > 0:
		card.brand_slots = maxi(0, int(card.brand_slots) + bonus_slots)
	flags[brand_id] = true
	card.brand_transform_flags = flags
	return {
		"ok": true,
		"reason": "brand_permanent_transform_applied",
		"id": brand_id,
		"trigger": "play_count_threshold",
		"threshold": threshold,
		"play_count": int(card.play_count),
		"damage_multiplier": multiplier,
		"damage_before": before_damage,
		"damage_after": int(card.damage),
		"bonus_brand_slots": bonus_slots,
		"brand_slots_before": before_slots,
		"brand_slots_after": int(card.brand_slots),
	}


func _card_brand_transform_flags(card: Card) -> Dictionary:
	if card == null:
		return {}
	var flags: Variant = card.brand_transform_flags
	if flags is Dictionary:
		return (flags as Dictionary).duplicate(true)
	return {}


func _trigger_card_brands(card: Card, trigger_id: String, target = null, killed_targets: Array = []) -> void:
	for payload in _card_trigger_brand_payloads(card, trigger_id):
		var result := _apply_card_brand_trigger(payload, trigger_id, card, target, killed_targets)
		if not result.is_empty():
			last_effect_results.append(result)


func _apply_card_brand_trigger(payload: Dictionary, trigger_id: String, _card: Card, _target = null, _killed_targets: Array = []) -> Dictionary:
	if trigger_id == "after_play" and int(payload.get("block", 0)) > 0:
		return _apply_after_play_block_brand(payload)
	if trigger_id == "after_play" and int(payload.get("draw_cards", 0)) > 0:
		return _apply_after_play_draw_brand(payload)
	if trigger_id == "after_play" and int(payload.get("damage_growth", 0)) > 0:
		return _apply_after_play_damage_growth_brand(payload, _card)
	if trigger_id == "after_play" and str(payload.get("create_card", "")) == "same_cost_random":
		return _apply_after_play_mirror_image_brand(payload, _card)
	return {}


func _apply_on_play_brand_effects(card: Card, target, paid_cost: int) -> Dictionary:
	var summary := {"delay_card_effect": false}
	for payload in _card_trigger_brand_payloads(card, "on_play"):
		if str(payload.get("effect", "")) == "refund_energy_cost":
			var refund_result := _apply_on_play_refund_energy_brand(payload, paid_cost)
			if not refund_result.is_empty():
				last_effect_results.append(refund_result)
		if payload.has("redirect_chance"):
			var face_mask_result := _apply_on_play_face_mask_brand(payload, target)
			if not face_mask_result.is_empty():
				last_effect_results.append(face_mask_result)
		if bool(payload.get("reveal_true_name", false)) or payload.has("next_cost_delta"):
			var truename_result := _apply_on_play_truename_brand(payload)
			if not truename_result.is_empty():
				last_effect_results.append(truename_result)
		if int(payload.get("delay_turns", 0)) > 0:
			var delay_result := _schedule_delayed_card_effect_brand(payload, card, target)
			if not delay_result.is_empty():
				last_effect_results.append(delay_result)
				if bool(delay_result.get("ok", false)):
					summary["delay_card_effect"] = true
	return summary


func _apply_on_play_refund_energy_brand(payload: Dictionary, paid_cost: int) -> Dictionary:
	var chance := clampf(float(payload.get("chance", 0.0)), 0.0, 1.0)
	if chance <= 0.0:
		return {}
	var roll := randf()
	var refunded := false
	if roll < chance and paid_cost > 0:
		energy += paid_cost
		refunded = true
	return {
		"ok": true,
		"reason": "brand_energy_refunded" if refunded else "brand_energy_refund_missed",
		"id": str(payload.get("source_brand", "")),
		"trigger": "on_play",
		"roll": roll,
		"chance": chance,
		"paid_cost": paid_cost,
		"refunded": refunded,
		"energy": energy,
	}


func _apply_on_play_face_mask_brand(payload: Dictionary, target) -> Dictionary:
	var targets := _brand_enemy_targets_from_target(target)
	if targets.is_empty():
		return {
			"ok": false,
			"reason": "brand_face_mask_no_enemy_target",
			"id": str(payload.get("source_brand", "")),
			"trigger": "on_play",
		}
	var chance := clampf(float(payload.get("redirect_chance", 0.0)), 0.0, 1.0)
	if chance <= 0.0:
		return {}
	var duration := maxi(1, int(payload.get("duration_turns", payload.get("duration", 1))))
	for enemy in targets:
		if enemy == null or not enemy.has_method("add_status"):
			continue
		enemy.add_status("face_mask_redirect", {
			"id": "face_mask_redirect",
			"chance": chance,
			"duration": duration,
			"source_brand": str(payload.get("source_brand", "")),
			"source_trigger": "on_play",
		})
	return {
		"ok": true,
		"reason": "brand_face_mask_redirect_applied",
		"id": str(payload.get("source_brand", "")),
		"trigger": "on_play",
		"chance": chance,
		"duration": duration,
		"target_ids": _actor_ids(targets),
	}


func _apply_on_play_truename_brand(payload: Dictionary) -> Dictionary:
	if player == null or not player.has_method("add_status"):
		return {
			"ok": false,
			"reason": "missing_player",
			"id": str(payload.get("source_brand", "")),
			"trigger": "on_play",
		}
	var brand_id := str(payload.get("source_brand", ""))
	var once_per_battle := bool(payload.get("once_per_battle", false))
	var once_bucket := _brand_once_per_battle_bucket()
	if once_per_battle and bool(once_bucket.get(brand_id, false)):
		return {
			"ok": false,
			"reason": "brand_once_per_battle_already_used",
			"id": brand_id,
			"trigger": "on_play",
		}
	if once_per_battle:
		once_bucket[brand_id] = true
	if bool(payload.get("reveal_true_name", false)):
		player.add_status("true_name_revealed", {
			"id": "true_name_revealed",
			"source_brand": brand_id,
			"source_trigger": "on_play",
		})
	var next_delta := int(payload.get("next_cost_delta", 0))
	if next_delta != 0:
		player.add_status("next_card_cost_delta", {
			"id": "next_card_cost_delta",
			"magnitude": next_delta,
			"applies_to": "next_card",
			"source_brand": brand_id,
			"source_trigger": "on_play",
		})
	return {
		"ok": true,
		"reason": "brand_truename_applied",
		"id": brand_id,
		"trigger": "on_play",
		"revealed": bool(payload.get("reveal_true_name", false)),
		"next_cost_delta": next_delta,
		"once_per_battle": once_per_battle,
	}


func _schedule_delayed_card_effect_brand(payload: Dictionary, card: Card, target) -> Dictionary:
	if card == null:
		return {
			"ok": false,
			"reason": "missing_card",
			"id": str(payload.get("source_brand", "")),
			"trigger": "on_play",
		}
	var turns := maxi(1, int(payload.get("delay_turns", 1)))
	var multiplier := maxf(0.0, float(payload.get("damage_multiplier", 1.0)))
	delayed_card_effects.append({
		"source_card": card,
		"target_actor": _delayed_target_snapshot(target),
		"remaining": turns,
		"damage_multiplier": multiplier,
		"source_brand": str(payload.get("source_brand", "")),
	})
	return {
		"ok": true,
		"reason": "brand_delayed_card_effect_scheduled",
		"id": str(payload.get("source_brand", "")),
		"trigger": "on_play",
		"delay_turns": turns,
		"damage_multiplier": multiplier,
	}


func _brand_enemy_targets_from_target(target) -> Array:
	var targets: Array = []
	if target is Array:
		for entry in target:
			_append_brand_enemy_target(targets, entry)
	else:
		_append_brand_enemy_target(targets, target)
	if targets.is_empty():
		_append_brand_enemy_target(targets, _first_living_enemy())
	return targets


func _append_brand_enemy_target(targets: Array, candidate) -> void:
	if candidate == null or not candidate in enemies or _actor_is_dead(candidate):
		return
	if not candidate in targets:
		targets.append(candidate)


func _actor_ids(actors: Array) -> Array[String]:
	var ids: Array[String] = []
	for actor in actors:
		ids.append(_actor_id(actor))
	return ids


func _delayed_target_snapshot(target):
	if target is Array:
		return (target as Array).duplicate()
	return target


func _brand_once_per_battle_bucket() -> Dictionary:
	var bucket: Variant = field_state.get("brand_once_per_battle", {})
	if not bucket is Dictionary:
		bucket = {}
		field_state["brand_once_per_battle"] = bucket
	return bucket


func _brand_first_play_each_battle_bucket() -> Dictionary:
	var bucket: Variant = field_state.get("brand_first_play_each_battle", {})
	if not bucket is Dictionary:
		bucket = {}
		field_state["brand_first_play_each_battle"] = bucket
	return bucket


func _brand_first_play_key(card: Card, brand_id: String) -> String:
	return "%s::%s" % [_card_instance_key(card), brand_id]


func _card_first_play_brand_cost_override(card: Card, current_cost: int) -> int:
	var cost := current_cost
	var bucket := _brand_first_play_each_battle_bucket()
	for payload in _card_trigger_brand_payloads(card, "first_play_each_battle"):
		if not payload.has("cost_override"):
			continue
		var brand_id := str(payload.get("source_brand", ""))
		if bool(bucket.get(_brand_first_play_key(card, brand_id), false)):
			continue
		cost = mini(cost, int(payload.get("cost_override", cost)))
	return cost


func _mark_first_play_brand_cost_overrides_used(card: Card) -> void:
	var bucket := _brand_first_play_each_battle_bucket()
	for payload in _card_trigger_brand_payloads(card, "first_play_each_battle"):
		if not payload.has("cost_override"):
			continue
		var brand_id := str(payload.get("source_brand", ""))
		bucket[_brand_first_play_key(card, brand_id)] = true


func _apply_after_play_block_brand(payload: Dictionary) -> Dictionary:
	if player == null or not player.has_method("add_status"):
		return {
			"ok": false,
			"reason": "missing_player",
			"id": str(payload.get("source_brand", "")),
			"trigger": str(payload.get("trigger", "")),
		}
	var amount := maxi(1, int(payload.get("block", 0)))
	var duration := maxi(1, int(payload.get("duration", 1)))
	player.add_status("def_buff", {
		"id": "def_buff",
		"magnitude": amount,
		"duration": duration,
		"source_brand": str(payload.get("source_brand", "")),
		"source_trigger": str(payload.get("trigger", "")),
	})
	return {
		"ok": true,
		"reason": "brand_def_buff_applied",
		"id": str(payload.get("source_brand", "")),
		"trigger": str(payload.get("trigger", "")),
		"status_id": "def_buff",
		"magnitude": amount,
		"duration": duration,
	}


func _apply_after_play_draw_brand(payload: Dictionary) -> Dictionary:
	if not has_method("_draw"):
		return {
			"ok": false,
			"reason": "missing_draw_method",
			"id": str(payload.get("source_brand", "")),
			"trigger": str(payload.get("trigger", "")),
		}
	var amount := maxi(1, int(payload.get("draw_cards", 0)))
	_draw(amount)
	return {
		"ok": true,
		"reason": "brand_draw_applied",
		"id": str(payload.get("source_brand", "")),
		"trigger": str(payload.get("trigger", "")),
		"draw_cards": amount,
		"hand_size": hand.size(),
	}


func _apply_after_play_damage_growth_brand(payload: Dictionary, card: Card) -> Dictionary:
	var brand_id := str(payload.get("source_brand", ""))
	if card == null:
		return {
			"ok": false,
			"reason": "missing_card",
			"id": brand_id,
			"trigger": str(payload.get("trigger", "")),
		}
	var magnitude := maxi(0, int(payload.get("damage_growth", 0)))
	var cap := maxi(0, int(payload.get("damage_growth_max", payload.get("cap", magnitude))))
	var bucket := _brand_damage_growth_bucket()
	var key := _brand_damage_growth_key(card, brand_id)
	var current := int(bucket.get(key, 0))
	var next_growth := mini(cap, current + magnitude)
	bucket[key] = next_growth
	return {
		"ok": true,
		"reason": "brand_damage_growth_applied",
		"id": brand_id,
		"trigger": str(payload.get("trigger", "")),
		"magnitude": magnitude,
		"cap": cap,
		"growth": next_growth,
	}


func _apply_after_play_mirror_image_brand(payload: Dictionary, card: Card) -> Dictionary:
	var brand_id := str(payload.get("source_brand", ""))
	if card == null:
		return {
			"ok": false,
			"reason": "missing_card",
			"id": brand_id,
			"trigger": str(payload.get("trigger", "")),
		}
	if str(payload.get("destination", "hand")) != "hand":
		return {
			"ok": false,
			"reason": "brand_mirror_unsupported_destination",
			"id": brand_id,
			"trigger": str(payload.get("trigger", "")),
			"destination": str(payload.get("destination", "")),
		}
	if hand.size() >= hand_limit:
		return {
			"ok": false,
			"reason": "brand_mirror_hand_full",
			"id": brand_id,
			"trigger": str(payload.get("trigger", "")),
			"source_card_id": _card_id(card),
			"energy_cost": int(card.energy_cost),
		}
	var candidates := _mirror_image_candidates_for_card(card)
	if candidates.is_empty():
		return {
			"ok": false,
			"reason": "brand_mirror_no_candidate",
			"id": brand_id,
			"trigger": str(payload.get("trigger", "")),
			"source_card_id": _card_id(card),
			"energy_cost": int(card.energy_cost),
		}
	var template: Card = candidates[randi() % candidates.size()]
	var generated := _mirror_image_temporary_card_from_template(template, brand_id)
	if generated == null:
		return {
			"ok": false,
			"reason": "brand_mirror_card_build_failed",
			"id": brand_id,
			"trigger": str(payload.get("trigger", "")),
			"template_id": str(template.template_id),
		}
	hand.append(generated)
	return {
		"ok": true,
		"reason": "brand_mirror_card_created",
		"id": brand_id,
		"trigger": str(payload.get("trigger", "")),
		"source_card_id": _card_id(card),
		"energy_cost": int(card.energy_cost),
		"template_id": str(generated.template_id),
		"card_id": str(generated.id),
		"card_name": generated.get_display_name(),
		"destination": "hand",
		"hand_size": hand.size(),
	}


func _mirror_image_candidates_for_card(card: Card) -> Array:
	var library = CardLibraryScript.new()
	return _mirror_image_candidate_templates(card, library.all_cards())


func _mirror_image_candidate_templates(source_card: Card, templates: Array) -> Array:
	var results: Array = []
	if source_card == null:
		return results
	var source_cost := int(source_card.energy_cost)
	for candidate in templates:
		if candidate == null or not candidate.has_method("to_dict"):
			continue
		var candidate_card: Card = candidate
		if int(candidate_card.energy_cost) != source_cost:
			continue
		if not bool(card_unlock_check_for_sequence(candidate_card, battle_sequence).get("ok", false)):
			continue
		results.append(candidate_card)
	return results


func _mirror_image_temporary_card_from_template(template: Card, recursive_brand_id: String) -> Card:
	if template == null:
		return null
	var generated: Card = CardScript.from_json(template.to_dict())
	if generated == null:
		return null
	generated.id = _unique_mirror_temp_id(generated.template_id)
	if not "temporary" in generated.tags:
		generated.tags.append("temporary")
	_strip_recursive_mirror_brands(generated, recursive_brand_id)
	return generated


func _strip_recursive_mirror_brands(card: Card, recursive_brand_id: String) -> void:
	if card == null:
		return
	var kept: Array[String] = []
	for brand_id in card.brands:
		var id := str(brand_id)
		if id == recursive_brand_id or _brand_payload_is_mirror_image(id):
			continue
		kept.append(id)
	card.brands = kept


func _brand_payload_is_mirror_image(brand_id: String) -> bool:
	if brand_id == "":
		return false
	var brand = BrandCatalogScript.create_brand(brand_id)
	if brand == null:
		return false
	var payload: Dictionary = brand.effect_payload
	return str(payload.get("trigger", "")) == "after_play" and str(payload.get("create_card", "")) == "same_cost_random"


func _unique_mirror_temp_id(template_id: String) -> String:
	var base := template_id if template_id != "" else "mirror_temp"
	return "%s_mirror_%d_%d" % [base, Time.get_ticks_usec(), randi() % 1000000]


func _discard_card(card: Card, reason: String = "discard") -> Dictionary:
	if card == null:
		return {"ok": false, "reason": "missing_card", "discard_reason": reason}
	if not card in discard_pile:
		discard_pile.append(card)
	var trigger_results := _apply_on_discard_brand_effects(card, reason)
	for result in trigger_results:
		if result is Dictionary and not (result as Dictionary).is_empty():
			last_effect_results.append(result)
	return {
		"ok": true,
		"reason": "card_discarded",
		"discard_reason": reason,
		"card_id": _card_id(card),
		"brand_result_count": trigger_results.size(),
	}


func _apply_on_discard_brand_effects(card: Card, discard_reason: String) -> Array:
	var results: Array = []
	for payload in _card_trigger_brand_payloads(card, "on_discard"):
		var destination := str(payload.get("destination", ""))
		if destination != "hand":
			continue
		results.append(_apply_phoenix_return_brand(payload, card, discard_reason))
	return results


func _apply_phoenix_return_brand(payload: Dictionary, card: Card, discard_reason: String) -> Dictionary:
	var brand_id := str(payload.get("source_brand", ""))
	var chance := clampf(float(payload.get("chance", 0.0)), 0.0, 1.0)
	var override: Variant = field_state.get("%s_return_chance_override" % brand_id, null)
	if override == null:
		override = field_state.get("brand_on_discard_chance_override", null)
	if override != null:
		chance = clampf(float(override), 0.0, 1.0)
	var roll := 0.0
	if chance <= 0.0:
		return {
			"ok": true,
			"reason": "brand_discard_return_missed",
			"id": brand_id,
			"trigger": "on_discard",
			"discard_reason": discard_reason,
			"roll": roll,
			"chance": chance,
		}
	if chance < 1.0:
		roll = randf()
		if roll >= chance:
			return {
				"ok": true,
				"reason": "brand_discard_return_missed",
				"id": brand_id,
				"trigger": "on_discard",
				"discard_reason": discard_reason,
				"roll": roll,
				"chance": chance,
			}
	if hand.size() >= hand_limit:
		return {
			"ok": false,
			"reason": "brand_discard_return_hand_full",
			"id": brand_id,
			"trigger": "on_discard",
			"discard_reason": discard_reason,
			"roll": roll,
			"chance": chance,
		}
	discard_pile.erase(card)
	if not card in hand:
		hand.append(card)
	return {
		"ok": true,
		"reason": "brand_discard_returned_to_hand",
		"id": brand_id,
		"trigger": "on_discard",
		"discard_reason": discard_reason,
		"roll": roll,
		"chance": chance,
		"card_id": _card_id(card),
	}


func _schedule_next_turn_start_brand_effects(card: Card, target) -> void:
	for payload in _card_trigger_brand_payloads(card, "next_turn_start"):
		if not bool(payload.get("replay_last_effect", false)):
			continue
		var result := _schedule_next_turn_replay_brand(payload, card, target)
		if not result.is_empty():
			last_effect_results.append(result)


func _schedule_next_turn_replay_brand(payload: Dictionary, card: Card, target) -> Dictionary:
	if card == null:
		return {
			"ok": false,
			"reason": "missing_card",
			"id": str(payload.get("source_brand", "")),
			"trigger": "next_turn_start",
		}
	next_turn_start_card_effects.append({
		"source_card": card,
		"target_actor": _delayed_target_snapshot(target),
		"remaining": 1,
		"source_brand": str(payload.get("source_brand", "")),
		"target_scope": str(payload.get("target_scope", "")),
	})
	return {
		"ok": true,
		"reason": "brand_next_turn_replay_scheduled",
		"id": str(payload.get("source_brand", "")),
		"trigger": "next_turn_start",
		"target_scope": str(payload.get("target_scope", "")),
	}


func _card_trigger_brand_payloads(card: Card, trigger_id: String) -> Array:
	var results: Array = []
	if card == null or trigger_id == "":
		return results
	var seen_ids := {}
	for brand_id in card.brands:
		var id := str(brand_id)
		if bool(seen_ids.get(id, false)):
			continue
		seen_ids[id] = true
		var brand = BrandCatalogScript.create_brand(id)
		if brand == null:
			continue
		var payload: Dictionary = brand.effect_payload.duplicate(true)
		if str(payload.get("trigger", "")) != trigger_id:
			continue
		payload["source_brand"] = str(brand.id)
		payload["source_brand_effect_type"] = str(brand.effect_type)
		results.append(payload)
	return results


func _card_before_damage_amount(card: Card, amount: int) -> int:
	var modified := maxi(0, amount)
	if modified <= 0:
		return 0
	for payload in _card_trigger_brand_payloads(card, "before_damage"):
		var chance := clampf(float(payload.get("crit_chance", 0.0)), 0.0, 1.0)
		var multiplier := float(payload.get("crit_multiplier", 1.0))
		if chance <= 0.0 or multiplier <= 0.0:
			continue
		var roll := randf()
		if roll >= chance:
			continue
		var before := modified
		modified = maxi(1, int(floor(float(modified) * multiplier)))
		last_effect_results.append({
			"ok": true,
			"reason": "brand_crit_applied",
			"id": str(payload.get("source_brand", "")),
			"trigger": "before_damage",
			"roll": roll,
			"chance": chance,
			"multiplier": multiplier,
			"before_damage": before,
			"after_damage": modified,
		})
	return modified


func _apply_after_damage_brand_effects(card: Card, damage_dealt: int) -> void:
	if damage_dealt <= 0:
		return
	for payload in _card_trigger_brand_payloads(card, "after_damage"):
		var ratio := float(payload.get("lifesteal_ratio", 0.0))
		if ratio <= 0.0:
			continue
		var amount := int(floor(float(damage_dealt) * ratio))
		if amount <= 0:
			continue
		var healed := _heal(player, amount)
		last_effect_results.append({
			"ok": true,
			"reason": "brand_lifesteal_applied",
			"id": str(payload.get("source_brand", "")),
			"trigger": "after_damage",
			"damage_dealt": damage_dealt,
			"lifesteal_ratio": ratio,
			"heal_amount": amount,
			"healed": healed,
		})


func _apply_on_hit_brand_effects(card: Card, hit_target, damage_dealt: int) -> void:
	if hit_target == null or damage_dealt <= 0:
		return
	for payload in _card_trigger_brand_payloads(card, "on_hit"):
		if payload.has("enemy_energy_delta_next_turn"):
			var result := _apply_enemy_energy_delta_brand(payload, hit_target)
			if not result.is_empty():
				last_effect_results.append(result)
		if payload.has("forbid_skill_tags"):
			var forbidden_result := _apply_forbidden_skill_tags_brand(payload, hit_target)
			if not forbidden_result.is_empty():
				last_effect_results.append(forbidden_result)


func _apply_enemy_energy_delta_brand(payload: Dictionary, hit_target) -> Dictionary:
	if hit_target == null or not hit_target.has_method("add_status"):
		return {}
	var delta := int(payload.get("enemy_energy_delta_next_turn", 0))
	if delta == 0:
		return {}
	var existing: Dictionary = hit_target.statuses.get("enemy_energy_delta_next_turn", {}) if hit_target.has_method("get") else {}
	var combined_delta := int(existing.get("magnitude", 0)) + delta
	hit_target.add_status("enemy_energy_delta_next_turn", {
		"id": "enemy_energy_delta_next_turn",
		"magnitude": combined_delta,
		"source_brand": str(payload.get("source_brand", "")),
		"source_trigger": "on_hit",
	})
	return {
		"ok": true,
		"reason": "brand_enemy_energy_delta_applied",
		"id": str(payload.get("source_brand", "")),
		"trigger": "on_hit",
		"target_id": _actor_id(hit_target),
		"magnitude": combined_delta,
	}


func _apply_forbidden_skill_tags_brand(payload: Dictionary, hit_target) -> Dictionary:
	if hit_target == null or not hit_target.has_method("add_status"):
		return {}
	var new_tags := _string_values(payload.get("forbid_skill_tags", []))
	if new_tags.is_empty():
		return {}
	var existing: Dictionary = hit_target.statuses.get("forbidden_skill_tags", {}) if hit_target.has_method("get") else {}
	var tags := _string_values(existing.get("tags", []))
	for tag in new_tags:
		if not tag in tags:
			tags.append(tag)
	var status_payload := {
		"id": "forbidden_skill_tags",
		"tags": tags,
		"source_brand": str(payload.get("source_brand", "")),
		"source_trigger": "on_hit",
	}
	var duration_value: Variant = payload.get("duration", "")
	if not (duration_value is String and str(duration_value) == "battle"):
		var duration := int(duration_value)
		if duration > 0:
			status_payload["duration"] = duration
	hit_target.add_status("forbidden_skill_tags", status_payload)
	return {
		"ok": true,
		"reason": "brand_forbidden_skill_tags_applied",
		"id": str(payload.get("source_brand", "")),
		"trigger": "on_hit",
		"target_id": _actor_id(hit_target),
		"tags": tags,
	}


func _apply_on_hit_boss_brand_effects(card: Card, hit_target, damage_dealt: int) -> void:
	if hit_target == null or damage_dealt <= 0:
		return
	var payloads := _card_trigger_brand_payloads(card, "on_hit_boss")
	if payloads.is_empty() or not _enemy_is_boss(hit_target):
		return
	for payload in payloads:
		if not bool(payload.get("cancel_boss_intent", false)):
			continue
		var enemy_id := _actor_id(hit_target)
		var intent: Dictionary = current_enemy_intents.get(enemy_id, EnemyAiScript.decide_action(hit_target, turn_count))
		intent["cancelled_by_brand"] = true
		intent["cancel_brand_id"] = str(payload.get("source_brand", ""))
		intent["action"] = "cancelled"
		intent["intent_type"] = "cancelled"
		current_enemy_intents[enemy_id] = intent
		last_effect_results.append({
			"ok": true,
			"reason": "brand_boss_intent_cancelled",
			"id": str(payload.get("source_brand", "")),
			"trigger": "on_hit_boss",
			"target_id": enemy_id,
		})


func _apply_on_kill_brand_effects(card: Card, killed_target, trigger_damage: int, killed_targets: Array) -> int:
	if trigger_damage <= 0:
		return 0
	var total_damage := 0
	for payload in _card_trigger_brand_payloads(card, "on_kill"):
		var ratio := float(payload.get("chain_damage_ratio", 0.0))
		if ratio <= 0.0 or str(payload.get("target", "")) != "next_enemy":
			continue
		var chain_target = _next_living_enemy_after(killed_target)
		if chain_target == null:
			last_effect_results.append({
				"ok": false,
				"reason": "brand_chain_no_target",
				"id": str(payload.get("source_brand", "")),
				"trigger": "on_kill",
			})
			continue
		var chain_damage := maxi(1, int(floor(float(trigger_damage) * ratio)))
		var was_alive: bool = not _actor_is_dead(chain_target)
		var dealt := _deal_damage(player, chain_target, chain_damage, card.element, [], null)
		total_damage += dealt
		if was_alive and _actor_is_dead(chain_target) and not chain_target in killed_targets:
			killed_targets.append(chain_target)
		last_effect_results.append({
			"ok": true,
			"reason": "brand_chain_damage_applied",
			"id": str(payload.get("source_brand", "")),
			"trigger": "on_kill",
			"source_target_id": _actor_id(killed_target),
			"chain_target_id": _actor_id(chain_target),
			"chain_damage_ratio": ratio,
			"damage": chain_damage,
			"damage_dealt": dealt,
		})
	return total_damage


func _next_living_enemy_after(anchor):
	if enemies.is_empty():
		return null
	var start_index := enemies.find(anchor)
	if start_index >= 0:
		for offset in range(1, enemies.size() + 1):
			var candidate = enemies[(start_index + offset) % enemies.size()]
			if candidate != null and candidate != anchor and not _actor_is_dead(candidate):
				return candidate
	for enemy in enemies:
		if enemy != null and enemy != anchor and not _actor_is_dead(enemy):
			return enemy
	return null


func _string_values(value: Variant) -> Array[String]:
	var results: Array[String] = []
	if value is Array:
		for item in value:
			var text := str(item)
			if text != "" and not text in results:
				results.append(text)
	elif value != null:
		var text := str(value)
		if text != "":
			results.append(text)
	return results


func _enemy_is_boss(enemy) -> bool:
	if enemy == null:
		return false
	if enemy.has_method("get"):
		if enemy.get("is_boss") == true:
			return true
		if int(enemy.get("tier")) >= 3:
			return true
	var id := _actor_id(enemy).to_lower()
	return id.find("boss") != -1 or id.find("horror") != -1 or id.find("captain") != -1 or id.find("conspirator") != -1 or id == "slag_golem" or id == "church_inquisitor"


static func card_unlock_check_for_sequence(card: Card, sequence: int) -> Dictionary:
	if card == null:
		return {"ok": false, "reason": "missing_card"}
	if int(card.sequence) < int(sequence):
		return {
			"ok": false,
			"reason": "sequence_locked",
			"card_sequence": int(card.sequence),
			"current_sequence": int(sequence),
		}
	var allowed: Array = _allowed_mechanics_for_sequence_number(sequence)
	for mechanism in _card_mechanism_tags_for_card(card):
		if not mechanism in allowed:
			return {
				"ok": false,
				"reason": "mechanic_locked",
				"mechanism": str(mechanism),
				"card_sequence": int(card.sequence),
				"current_sequence": int(sequence),
			}
	return {"ok": true, "reason": "ok"}


func end_player_turn() -> void:
	var cards_to_discard := hand.duplicate()
	hand.clear()
	for card in cards_to_discard:
		_discard_card(card, "end_turn")
	if player != null and player.has_method("remove_status"):
		player.remove_status("next_card_cost_delta")
		player.remove_status("reroll_next_target")
	_tick_actor_statuses_only(player, PLAYER_ACTION_TICK_STATUS_IDS)
	phase = Phase.ENEMY_TURN


func run_enemy_turn() -> Dictionary:
	if phase != Phase.ENEMY_TURN:
		return {"phase": phase}
	for enemy in enemies:
		if enemy == null:
			continue
		_tick_actor_turn_start(enemy)
		if enemy.is_dead():
			_tick_actor_statuses_after_action(enemy)
			continue
		if _actor_action_blocked(enemy):
			_tick_actor_statuses_after_action(enemy)
			continue
		var intent: Dictionary = current_enemy_intents.get(enemy.id, EnemyAiScript.decide_action(enemy, turn_count))
		_execute_enemy_intent(enemy, intent)
		_tick_actor_statuses_after_action(enemy)
	turn_count += 1
	if _battle_should_resolve():
		phase = Phase.RESOLVE
	else:
		phase = Phase.PLAYER_TURN
		current_enemy_intents = preview_enemy_intents()
		_start_player_turn()
	return {"phase": phase, "intents": current_enemy_intents.duplicate(true)}


func lost_control_auto_play_turn(seed: int = 0) -> Dictionary:
	if _game_state == null or not bool(_game_state.is_lost_control):
		return {"ok": false, "reason": "not_lost_control"}
	if phase != Phase.PLAYER_TURN:
		return {"ok": false, "reason": "not_player_turn", "phase": phase}
	var playable := _lost_control_playable_cards()
	if playable.is_empty():
		var empty_advance: Dictionary = _game_state.advance_lost_control_turn({"source": "battle_no_play"})
		return {
			"ok": false,
			"reason": "no_playable_card",
			"lost_control": empty_advance,
			"dead": bool(empty_advance.get("dead", false)),
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed)
	var card = playable[rng.randi_range(0, playable.size() - 1)]
	var target = _lost_control_auto_target(card, rng)
	var target_id := _actor_result_id(target)
	var turn_index := int(_game_state.lost_control_state.get("turns_elapsed", 0)) + 1
	var ai_text := ""
	if _game_state.has_method("request_lost_control_narration_ai_gm"):
		ai_text = str(_game_state.call("request_lost_control_narration_ai_gm", {
			"turn_index": turn_index,
			"source": "battle_turn_start",
			"auto_card_id": _card_id(card),
			"target_id": target_id,
	}))
	var played := play_card(card, target)
	if played:
		battle_log_entry.emit("[失控] 自动打出 %s" % _card_log_name(card))
	var advance: Dictionary = _game_state.advance_lost_control_turn({
		"source": "battle_auto_play",
		"auto_card_id": _card_id(card),
		"target_id": target_id,
	})
	return {
		"ok": played,
		"reason": "auto_played" if played else "play_failed",
		"card_id": _card_id(card),
		"target_id": target_id,
		"ai_gm_text": ai_text,
		"lost_control": advance,
		"dead": bool(advance.get("dead", false)),
	}


func _lost_control_playable_cards() -> Array:
	var playable: Array = []
	for card in hand:
		if card == null:
			continue
		if not card is Card:
			continue
		if not can_play_card(card):
			continue
		if _effective_card_cost(card) > energy:
			continue
		playable.append(card)
	playable.sort_custom(Callable(self, "_sort_cards_by_id"))
	return playable


func _lost_control_auto_target(card, rng: RandomNumberGenerator):
	var living := _living_enemies_sorted()
	if living.is_empty():
		return null
	var target_mode := str(card.target) if card != null else "single"
	match target_mode:
		"all_enemies", "random_enemies":
			return living
		"self":
			return player
		_:
			return living[rng.randi_range(0, living.size() - 1)]


func _living_enemies_sorted() -> Array:
	var living: Array = []
	for enemy in enemies:
		if enemy == null:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		living.append(enemy)
	living.sort_custom(Callable(self, "_sort_actors_by_id"))
	return living


func _sort_cards_by_id(a, b) -> bool:
	return _card_id(a) < _card_id(b)


func _sort_actors_by_id(a, b) -> bool:
	return _actor_result_id(a) < _actor_result_id(b)


func enemy_phase_done() -> Dictionary:
	return run_enemy_turn()


func preview_enemy_intents() -> Dictionary:
	var intents := {}
	for enemy in enemies:
		if enemy == null or enemy.is_dead():
			continue
		var enemy_id := _actor_id(enemy)
		var intent: Dictionary = EnemyAiScript.decide_action(enemy, turn_count)
		intents[enemy_id] = _apply_revealed_enemy_intent_detail(enemy_id, intent)
	current_enemy_intents = intents
	return intents


func _apply_revealed_enemy_intent_detail(enemy_id: String, intent: Dictionary) -> Dictionary:
	if enemy_id == "" or not revealed_enemy_intent_details.has(enemy_id):
		return intent
	var detail: Dictionary = revealed_enemy_intent_details.get(enemy_id, {})
	intent["revealed_by_card"] = true
	intent["detail_level"] = maxi(int(intent.get("detail_level", 0)), int(detail.get("detail_level", 1)))
	return intent


func resolve_battle(
	won: bool,
	candidate_cards: Array = [],
	selected_index: int = 0,
	game_state = null,
	victory_drops: Dictionary = {}
) -> Dictionary:
	var contract_result := resolve_contract(game_state)
	if not won:
		var defeat_ai_text := request_combat_resolve_critical_ai_gm(contract_result)
		clear_field_state()
		_clear_battle_scoped_actor_state()
		charged_zone.clear()
		phase = Phase.END
		return {
			"outcome": "defeat",
			"contract": contract_result,
			"ai_gm_text": defeat_ai_text,
		}
	var reward_options := []
	for i in range(min(3, candidate_cards.size())):
		reward_options.append(candidate_cards[i])
	var selected_card = null
	if selected_index >= 0 and selected_index < reward_options.size():
		selected_card = reward_options[selected_index]
		temp_picked_cards.append(selected_card)
		if game_state != null:
			game_state.temp_picked_cards.append(selected_card)
	_grant_acting_exp_by_contract(contract_result)
	var brand_drop = null
	if not victory_drops.is_empty():
		var roll: float = float(victory_drops.get("brand_roll", randf()))
		brand_drop = BrandCatalogScript.resolve_boss_brand_drop(victory_drops, game_state, roll)
	var weather_pollution_delta := _apply_weather_pollution_on_victory(game_state)
	var exp_result: Dictionary = {}
	if game_state != null:
		exp_result = SequenceExpServiceScript.add_exp(game_state, SequenceExpServiceScript.battle_victory_base_exp(enemies), "battle")
	var ai_gm_text := request_combat_resolve_critical_ai_gm(contract_result)
	clear_field_state()
	_clear_battle_scoped_actor_state()
	charged_zone.clear()
	phase = Phase.END
	return {
		"outcome": "victory",
		"reward_options": reward_options,
		"selected_card": selected_card,
		"brand_drop": brand_drop,
		"contract": contract_result,
		"weather_pollution_delta": weather_pollution_delta,
		"base_sequence_exp": int(exp_result.get("base_sequence_exp", 0)),
		"sequence_exp_delta": int(exp_result.get("sequence_exp_delta", 0)),
		"promotion_available": bool(exp_result.get("promotion_available", false)),
		"promotion_gate_id": str(exp_result.get("promotion_gate_id", "")),
		"ai_gm_text": ai_gm_text,
	}


func resolve_contract(game_state = null) -> Dictionary:
	var satisfied := 0
	var violated := 0
	for r in contracted_rules:
		var status: String = str(rule_satisfaction.get(r, "unresolved"))
		if status == "satisfied":
			satisfied += 1
		else:
			# R06 §3.1：战斗结束时未触发=违反（严格契约）
			rule_satisfaction[r] = "violated"
			violated += 1
	var total: int = contracted_rules.size()
	var ratio: float = 0.0 if total == 0 else float(satisfied) / float(total)
	var outcome := "partial"
	if total == 0:
		outcome = "no_contract"
	elif satisfied == total:
		outcome = "full"
	elif violated == total:
		outcome = "broken"
	elif ratio < 0.6:
		outcome = "failed"
	var pollution_delta := _contract_pollution_delta(ratio, total, game_state)
	if game_state != null and pollution_delta != 0:
		_apply_pollution_value(game_state, int(game_state.pollution) + pollution_delta, ["contract_%s" % outcome])
	var acting_check: Dictionary = _acting_check_difficulty(total, game_state)
	var violation_ai_text := ""
	if outcome == "broken":
		violation_ai_text = request_contract_violation_ai_gm({
			"outcome": outcome,
			"ratio": ratio,
			"satisfied": satisfied,
			"violated": violated,
		}, _first_violated_rule(), _first_violated_card_for_rule(_first_violated_rule()))
		_disable_violated_cards()
	return {
		"outcome": outcome,
		"satisfied": satisfied,
		"violated": violated,
		"ratio": ratio,
		"pollution_delta": pollution_delta,
		"acting_check_base_difficulty": int(acting_check.get("base", 0)),
		"acting_check_weather_modifier": int(acting_check.get("weather_modifier", 0)),
		"acting_check_difficulty": int(acting_check.get("difficulty", 0)),
		"violation_ai_gm_text": violation_ai_text,
	}


func _grant_acting_exp_by_contract(contract_result: Dictionary) -> void:
	# R06 §3.1 经验累加触发表
	var ratio: float = float(contract_result.get("ratio", 0.0))
	var total: int = int(contract_result.get("satisfied", 0)) + int(contract_result.get("violated", 0))
	if total == 0:
		return
	if ratio >= 1.0 - 0.0001:
		# 全满足：所有 used_cards 中带守则的卡 +1
		for card in used_cards.values():
			if card != null and card.acting_rules.size() > 0:
				card.grant_acting_exp(1)
	elif ratio >= 0.6:
		# 部分满足：仅满足规则关联的 source_cards +1
		var awarded: Dictionary = {}
		for rule in contracted_rules:
			if str(rule_satisfaction.get(rule, "")) != "satisfied":
				continue
			var sources: Array = rule_to_source_cards.get(rule, [])
			for card_id in sources:
				if awarded.has(card_id):
					continue
				var card = used_cards.get(card_id, null)
				if card != null:
					card.grant_acting_exp(1)
					awarded[card_id] = true


func request_combat_resolve_critical_ai_gm(contract_result: Dictionary) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "combat_resolve_critical"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"decisive_card_id": _last_decisive_card_id,
		"target": _last_decisive_target_id,
		"hp_remaining": _last_decisive_hp_remaining,
		"contract_outcome": str(contract_result.get("outcome", "")),
	}
	ctx.contract_state = _ai_gm_contract_state(contract_result)
	ctx.fallback_template_pool = "COMBAT_RESOLVE_TEMPLATES"
	return _call_ai_gm(ctx)


func request_contract_violation_ai_gm(contract_result: Dictionary, rule_id: String = "", violated_card = null) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "contract_violation"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"rule_id": rule_id,
		"violated_card_id": _card_id(violated_card),
		"satisfaction_ratio": float(contract_result.get("ratio", 0.0)),
	}
	ctx.contract_state = _ai_gm_contract_state(contract_result)
	ctx.fallback_template_pool = "CONTRACT_VIOLATION_TEMPLATES"
	return _call_ai_gm(ctx)


func _record_decisive_play(card: Card, target, killed_targets: Array) -> void:
	_last_decisive_card_id = _card_id(card)
	var decisive_target = target
	if decisive_target == null and not killed_targets.is_empty():
		decisive_target = killed_targets[0]
	if decisive_target is Array and not (decisive_target as Array).is_empty():
		decisive_target = (decisive_target as Array)[0]
	_last_decisive_target_id = _actor_result_id(decisive_target)
	if decisive_target != null and decisive_target.has_method("get"):
		_last_decisive_hp_remaining = maxi(0, int(decisive_target.get("hp")))
	else:
		_last_decisive_hp_remaining = 0


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


func _ai_gm_player_state() -> Dictionary:
	var state = _game_state
	if state == null:
		return {}
	return {
		"sequence": int(state.sequence),
		"pollution": int(state.pollution),
		"pollution_stage": int(state.pollution_stage),
		"cycle": int(state.cycle),
		"day": int(state.day),
		"time_of_day": str(state.time_of_day),
	}


func _ai_gm_contract_state(contract_result: Dictionary) -> Dictionary:
	var satisfied_rules: Array = []
	var violated_rules: Array = []
	for rule in contracted_rules:
		match str(rule_satisfaction.get(rule, "unresolved")):
			"satisfied":
				satisfied_rules.append(str(rule))
			"violated":
				violated_rules.append(str(rule))
	return {
		"active_contract": Array(contracted_rules),
		"last_resolve_ratio": float(contract_result.get("ratio", 0.0)),
		"satisfied_rules": satisfied_rules,
		"violated_rules": violated_rules,
	}


func _first_violated_rule() -> String:
	for rule in contracted_rules:
		if str(rule_satisfaction.get(rule, "unresolved")) == "violated":
			return str(rule)
	return ""


func _first_violated_card_for_rule(rule_id: String):
	if rule_id == "":
		return null
	var sources: Array = rule_to_source_cards.get(rule_id, [])
	for card_id in sources:
		var card = used_cards.get(card_id, null)
		if card != null:
			return card
	for card in used_cards.values():
		if card != null:
			return card
	return null


func _contract_pollution_delta(ratio: float, total: int, game_state) -> int:
	return _contract_pollution_delta_v2(ratio, total, game_state)
	if total == 0:
		return 0
	# R06 §6 与污染段联动
	var pollution: int = int(game_state.pollution) if game_state != null else 0
	if ratio >= 1.0 - 0.0001:
		return -2 if pollution >= 30 else -1
	if ratio < 0.6:
		# 全违反或大部分违反：基础 +5；50-80 段翻倍
		var delta := 5
		if pollution >= 50:
			delta *= 2
		return delta
	return 0

func _contract_pollution_delta_v2(ratio: float, total: int, game_state) -> int:
	if total == 0:
		return 0
	var pollution: int = int(game_state.pollution) if game_state != null else 0
	var pollution_stage: int = clampi(_pollution_stage(pollution), 0, 4)
	if ratio >= 1.0 - 0.0001:
		return -2 if pollution_stage == 1 else -1
	if ratio < 0.6:
		match pollution_stage:
			2, 3:
				return 10
			4:
				return 20
			_:
				return 5
	return 0


func _disable_violated_cards() -> void:
	# R06 §3.1：契约全破时，本场用过的卡当层失效（剩余战斗不能再出）
	for card_id in used_cards.keys():
		disabled_in_floor[card_id] = true


func _record_battle_witnessed(cards: Array) -> void:
	for card in cards:
		if card != null and card.has_method("record_battle_witnessed"):
			card.record_battle_witnessed()


static func _allowed_mechanics_for_sequence_number(sequence: int) -> Array:
	if sequence <= 7:
		return SEQUENCE_MECHANICS_GATE[7]
	if sequence <= 8:
		return SEQUENCE_MECHANICS_GATE[8]
	return SEQUENCE_MECHANICS_GATE[9]


static func _card_mechanism_tags_for_card(card: Card) -> Array[String]:
	var mechanisms: Array[String] = []
	if card == null:
		return mechanisms
	for tag in card.tags:
		var tag_name := str(tag)
		if tag_name == "" or tag_name in CARD_TYPE_TAGS:
			continue
		if not tag_name in mechanisms:
			mechanisms.append(tag_name)
	for effect in card.status_effects:
		if not effect is Dictionary:
			continue
		var effect_id := str(effect.get("id", ""))
		var mechanism := EffectEngineScript.mechanism_for_effect_id(effect_id)
		if mechanism == "":
			continue
		if not mechanism in mechanisms:
			mechanisms.append(mechanism)
	return mechanisms


func _allowed_mechanics_for_sequence(sequence: int) -> Array:
	return _allowed_mechanics_for_sequence_number(sequence)


func _card_mechanism_tags(card: Card) -> Array[String]:
	return _card_mechanism_tags_for_card(card)


func clear_field_state() -> void:
	field_state.clear()
	field_state["flame_markers"] = 0
	field_state["adjacent_burn"] = 0
	field_state["attack_play_damage_growth"] = {}
	field_state["brand_damage_growth"] = {}
	field_state["brand_once_per_battle"] = {}
	field_state["brand_first_play_each_battle"] = {}
	field_state["selected_targets"] = []
	field_state["last_counter_result"] = {}
	field_state["played_card_ids_this_turn"] = []
	field_state["played_card_tags_this_turn"] = []


func get_field_marker_count(id: String) -> int:
	return int(field_state.get(id, 0))


func add_field_marker(id: String, amount: int = 1, max_stacks: int = -1) -> int:
	if id == "":
		return 0
	var next_count := get_field_marker_count(id) + maxi(0, amount)
	if max_stacks >= 0:
		next_count = mini(next_count, max_stacks)
	field_state[id] = next_count
	return next_count


func consume_field_marker(id: String, amount: int = 1) -> bool:
	var consume_amount := maxi(1, amount)
	var current := get_field_marker_count(id)
	if current < consume_amount:
		return false
	field_state[id] = current - consume_amount
	return true


func add_charged_effect(source_card, target_actor, rounds: int, payload: Array) -> void:
	charged_zone.append({
		"source_card": source_card,
		"target_actor": target_actor,
		"remaining": maxi(1, rounds),
		"payload": payload.duplicate(true),
	})


func _tick_charged_effects() -> void:
	if charged_zone.is_empty():
		return
	var completed: Array = []
	for entry in charged_zone:
		var remaining := int(entry.get("remaining", 0)) - 1
		entry["remaining"] = remaining
		if remaining <= 0:
			completed.append(entry)
	for entry in completed:
		charged_zone.erase(entry)
		var payload: Array = entry.get("payload", [])
		resolved_charge_payloads.append(payload.duplicate(true))
		var target_set: Array = []
		var stored_target = entry.get("target_actor", null)
		if stored_target is Array:
			target_set = stored_target.duplicate(true)
		elif stored_target != null:
			target_set = [stored_target]
		if target_set.is_empty():
			target_set = [null]
		last_effect_results.append({
			"ok": true,
			"reason": "charge_payload_resolved",
			"id": "charge",
			"target_count": target_set.size(),
			"payload_count": payload.size(),
		})
		for target_actor in target_set:
			for effect in payload:
				if not effect is Dictionary:
					continue
				var result: Dictionary = EffectEngineScript.dispatch(
					effect,
					EffectEngineScript._build_ctx(
						player,
						target_actor,
						entry.get("source_card", null),
						self,
						field_state
					)
				)
				last_effect_results.append(result)


func _tick_delayed_card_effects() -> void:
	if delayed_card_effects.is_empty():
		return
	var completed: Array = []
	for entry in delayed_card_effects:
		var remaining := int(entry.get("remaining", 0)) - 1
		entry["remaining"] = remaining
		if remaining <= 0:
			completed.append(entry)
	for entry in completed:
		delayed_card_effects.erase(entry)
		var card: Card = entry.get("source_card", null)
		if card == null:
			continue
		var multiplier := maxf(0.0, float(entry.get("damage_multiplier", 1.0)))
		var previous_multiplier: Variant = field_state.get("active_card_damage_multiplier", null)
		field_state["active_card_damage_multiplier"] = multiplier
		var killed_targets := _apply_card_effect(card, entry.get("target_actor", null))
		if previous_multiplier == null:
			field_state.erase("active_card_damage_multiplier")
		else:
			field_state["active_card_damage_multiplier"] = previous_multiplier
		last_effect_results.append({
			"ok": true,
			"reason": "brand_delayed_card_effect_resolved",
			"id": str(entry.get("source_brand", "")),
			"trigger": "delayed_card_effect",
			"damage_multiplier": multiplier,
			"killed_count": killed_targets.size(),
		})


func _tick_next_turn_start_card_effects() -> void:
	if next_turn_start_card_effects.is_empty():
		return
	var completed: Array = []
	for entry in next_turn_start_card_effects:
		var remaining := int(entry.get("remaining", 0)) - 1
		entry["remaining"] = remaining
		if remaining <= 0:
			completed.append(entry)
	for entry in completed:
		next_turn_start_card_effects.erase(entry)
		var card: Card = entry.get("source_card", null)
		if card == null:
			continue
		var previous_replay_active: Variant = field_state.get("brand_replay_active", null)
		var previous_replay_brand: Variant = field_state.get("active_brand_replay_source", null)
		field_state["brand_replay_active"] = true
		field_state["active_brand_replay_source"] = str(entry.get("source_brand", ""))
		var killed_targets := _apply_card_effect(card, entry.get("target_actor", null))
		if previous_replay_active == null:
			field_state.erase("brand_replay_active")
		else:
			field_state["brand_replay_active"] = previous_replay_active
		if previous_replay_brand == null:
			field_state.erase("active_brand_replay_source")
		else:
			field_state["active_brand_replay_source"] = previous_replay_brand
		last_effect_results.append({
			"ok": true,
			"reason": "brand_next_turn_replay_resolved",
			"id": str(entry.get("source_brand", "")),
			"trigger": "next_turn_start",
			"target_scope": str(entry.get("target_scope", "")),
			"killed_count": killed_targets.size(),
		})


func _tick_actor_turn_start(actor) -> void:
	if actor == null:
		return
	_apply_dot_status(actor, "burn")
	_apply_dot_status(actor, "poison")
	_apply_adjacent_burn(actor)
	_tick_actor_statuses_only(actor, DOT_STATUS_IDS)
	_tick_actor_statuses_only(actor, TURN_START_TICK_STATUS_IDS)


func _apply_dot_status(actor, id: String) -> void:
	if actor == null or not actor.has_method("has_status") or not actor.has_status(id):
		return
	var payload: Dictionary = actor.statuses.get(id, {})
	var amount := maxi(0, int(payload.get("magnitude", 0)))
	if amount <= 0:
		return
	actor.hp = max(0, int(actor.hp) - amount)


func _apply_adjacent_burn(actor) -> void:
	if actor == null or actor == player or not actor in enemies:
		return
	if get_field_marker_count("flame_markers") <= 0:
		return
	var amount := maxi(0, int(field_state.get("adjacent_burn", 0)))
	if amount <= 0:
		return
	actor.hp = max(0, int(actor.hp) - amount)


func _tick_actor_statuses_only(actor, ids: Array) -> void:
	if actor == null or not actor.has_method("remove_status"):
		return
	var statuses = actor.get("statuses") if actor.has_method("get") else {}
	if not statuses is Dictionary:
		return
	var expired: Array[String] = []
	for raw_id in ids:
		var id := str(raw_id)
		if not statuses.has(id):
			continue
		var payload: Dictionary = statuses.get(id, {})
		if not payload.has("duration"):
			continue
		var remaining := int(payload.get("duration", 0)) - 1
		if remaining <= 0:
			expired.append(id)
		else:
			payload["duration"] = remaining
			statuses[id] = payload
	for id in expired:
		actor.remove_status(id)


func _tick_actor_statuses_except(actor, excluded_ids: Array) -> void:
	if actor == null or not actor.has_method("remove_status"):
		return
	var statuses = actor.get("statuses") if actor.has_method("get") else {}
	if not statuses is Dictionary:
		return
	var ids: Array = statuses.keys()
	for raw_id in ids:
		var id := str(raw_id)
		if id in excluded_ids:
			continue
		_tick_actor_statuses_only(actor, [id])


func _tick_actor_statuses_after_action(actor) -> void:
	_tick_actor_statuses_only(actor, PLAYER_ACTION_TICK_STATUS_IDS)


func _actor_action_blocked(actor) -> bool:
	if actor == null:
		return true
	for status_id in ACTION_BLOCK_STATUS_IDS:
		if _actor_has_status(actor, str(status_id)):
			return true
	return false


func _mark_card_rules_satisfied(card: Card) -> void:
	for rule in card.acting_rules:
		if rule_satisfaction.has(rule):
			rule_satisfaction[rule] = "satisfied"
			var sources: Array = rule_to_source_cards.get(rule, [])
			if not card.id in sources:
				sources.append(card.id)
			rule_to_source_cards[rule] = sources


func _apply_card_effect(card: Card, target, excluded_effect_ids: Array = []) -> Array:
	var killed_targets: Array = []
	field_state["last_discarded"] = null
	field_state["last_cleanse_result"] = null
	var damage_bonus := _card_attack_play_damage_growth_bonus(card) + _card_per_use_damage_growth_bonus(card)
	var actual_targets := _preview_card_targets(card, target)
	field_state["selected_targets"] = actual_targets.duplicate()
	var total_damage_dealt := 0
	for effect in card.status_effects:
		if not effect is Dictionary:
			continue
		var effect_id := str(effect.get("id", ""))
		if effect_id in excluded_effect_ids:
			continue
		if effect_id != "discard_top_deck":
			continue
		var discard_result: Dictionary = EffectEngineScript.dispatch(
			effect,
			EffectEngineScript._build_ctx(player, target, card, self, field_state)
		)
		last_effect_results.append(discard_result)
	for effect in card.status_effects:
		if not effect is Dictionary:
			continue
		var effect_id := str(effect.get("id", ""))
		if effect_id in excluded_effect_ids:
			continue
		if effect_id != "bonus_if_attack":
			continue
		var bonus_result: Dictionary = EffectEngineScript.dispatch(
			effect,
			EffectEngineScript._build_ctx(player, target, card, self, field_state)
		)
		last_effect_results.append(bonus_result)
		damage_bonus += int(bonus_result.get("damage_bonus", 0))
	for effect in card.status_effects:
		if not effect is Dictionary:
			continue
		var effect_id := str(effect.get("id", ""))
		if effect_id in excluded_effect_ids:
			continue
		if not (effect_id in PRE_DAMAGE_EFFECT_IDS):
			continue
		_dispatch_card_effect(effect, effect_id, card, target, actual_targets)
	if card.damage > 0:
		var target_count := maxi(1, actual_targets.size())
		var damage_multiplier := _select_targets_damage_multiplier(card, target_count)
		var multi_strike: Dictionary = _multi_strike_config(card)
		for actual_target in actual_targets:
			if actual_target == null:
				continue
			var base_card_damage := _card_damage_after_brand_modifiers(card, damage_bonus)
			var base_damage := maxi(1, int(floor(float(base_card_damage) * damage_multiplier)))
			var hits := int(multi_strike.get("hits", 1))
			var damage_each := int(multi_strike.get("damage_each", 0))
			if damage_each <= 0:
				damage_each = base_damage
			for i in range(hits):
				if _actor_is_dead(actual_target):
					break
				var was_alive: bool = not _actor_is_dead(actual_target)
				var damage_for_hit := _card_before_damage_amount(card, _active_card_damage_amount(damage_each))
				var dealt := _deal_damage(player, actual_target, damage_for_hit, card.element, card.status_effects, card)
				total_damage_dealt += dealt
				if dealt > 0:
					_apply_on_hit_brand_effects(card, actual_target, dealt)
					_apply_on_hit_boss_brand_effects(card, actual_target, dealt)
				if was_alive and _actor_is_dead(actual_target) and not actual_target in killed_targets:
					killed_targets.append(actual_target)
					total_damage_dealt += _apply_on_kill_brand_effects(card, actual_target, dealt, killed_targets)
	if card.heal > 0:
		var heal_target = player if card.damage > 0 else (target if target != null else player)
		_heal(heal_target, _card_heal_after_brand_modifiers(card))
	if _card_has_effect(card, "life_steal") and total_damage_dealt > 0:
		_heal(player, _life_steal_amount(card, total_damage_dealt))
	if total_damage_dealt > 0:
		_apply_after_damage_brand_effects(card, total_damage_dealt)
	for effect in card.status_effects:
		if not effect is Dictionary:
			continue
		var effect_id := str(effect.get("id", ""))
		if effect_id in excluded_effect_ids:
			continue
		if effect_id == "discard_top_deck" or effect_id == "bonus_if_attack" or effect_id in PRE_DAMAGE_EFFECT_IDS:
			continue
		_dispatch_card_effect(effect, effect_id, card, target, actual_targets)
	field_state["selected_targets"] = []
	return killed_targets


func _dispatch_card_effect(effect: Dictionary, effect_id: String, card: Card, target, actual_targets: Array) -> void:
	if effect_id == "charge":
		var charge_target = target
		if not actual_targets.is_empty():
			if actual_targets.size() == 1:
				charge_target = actual_targets[0]
			else:
				charge_target = actual_targets.duplicate(true)
		var charge_result: Dictionary = EffectEngineScript.dispatch(
			effect,
			EffectEngineScript._build_ctx(player, charge_target, card, self, field_state)
		)
		last_effect_results.append(charge_result)
		return
	if _effect_dispatches_per_target(effect_id):
		var effect_targets := actual_targets.duplicate()
		if effect_targets.is_empty() and target != null and not (target is Array):
			effect_targets = [target]
		for actual_target in effect_targets:
			if actual_target == null or _actor_is_dead(actual_target):
				continue
			var per_target_result: Dictionary = EffectEngineScript.dispatch(
				effect,
				EffectEngineScript._build_ctx(player, actual_target, card, self, field_state)
			)
			last_effect_results.append(per_target_result)
			if effect_id == "cleanse_debuff":
				_update_last_cleanse_result(per_target_result)
		return
	var dispatch_target = target
	if dispatch_target == null and actual_targets.size() == 1:
		dispatch_target = actual_targets[0]
	var result: Dictionary = EffectEngineScript.dispatch(
		effect,
		EffectEngineScript._build_ctx(player, dispatch_target, card, self, field_state)
	)
	last_effect_results.append(result)
	if effect_id == "cleanse_debuff":
		_update_last_cleanse_result(result)


func _effect_dispatches_per_target(effect_id: String) -> bool:
	match effect_id:
		"weak", "vulnerable", "confusion", "nightmare", "obscure_intent", "burn", "poison":
			return true
		"damage_reduction", "cleanse_debuff", "cleanse_incoming_debuff", "immune_debuff":
			return true
		"dodge_counter":
			return true
		"fatal_damage_convert", "consume_on_trigger", "paper_doll_marker", "absorb_fatal_or_curse":
			return true
		"teleport_to_flame", "vulnerable_if_skill", "vulnerable_if_skill_played", "weak_if_status":
			return true
		"bind", "blind", "burning", "chill", "confuse", "counter_spell", "delay_intent", "displace", "fear":
			return true
		"intent_revealed", "mark", "mind_revealed", "revealed", "root", "silence", "slow", "stun":
			return true
		"block_break", "break_block", "execute_bonus_below_hp_pct", "next_attack_damage_delta", "stealth":
			return true
		_:
			return false


func _update_last_cleanse_result(result: Dictionary) -> void:
	var previous = field_state.get("last_cleanse_result", {})
	if previous is Dictionary:
		var previous_dict: Dictionary = previous
		if bool(previous_dict.get("cleaned", false)):
			return
	field_state["last_cleanse_result"] = result


func _reset_played_cards_this_turn() -> void:
	field_state["played_card_ids_this_turn"] = []
	field_state["played_card_tags_this_turn"] = []


func _record_played_card_this_turn(card: Card) -> void:
	if card == null:
		return
	var ids: Array = field_state.get("played_card_ids_this_turn", [])
	if not ids is Array:
		ids = []
	if not str(card.id) in ids:
		ids.append(str(card.id))
	field_state["played_card_ids_this_turn"] = ids
	var tags: Array = field_state.get("played_card_tags_this_turn", [])
	if not tags is Array:
		tags = []
	for raw_tag in card.tags:
		var tag := str(raw_tag)
		if tag != "" and not tag in tags:
			tags.append(tag)
	field_state["played_card_tags_this_turn"] = tags


func _card_is_charging(card: Card) -> bool:
	if card == null:
		return false
	for effect in card.status_effects:
		if effect is Dictionary and str(effect.get("id", "")) == "charge":
			return true
	return false


func _card_uses_next_card_cost_delta(card: Card) -> bool:
	if player != null and player.has_status("next_card_cost_delta"):
		var payload: Dictionary = player.statuses.get("next_card_cost_delta", {})
		if str(payload.get("applies_to", "")) == "next_card":
			return true
		var pathway := str(payload.get("pathway", ""))
		if pathway != "" and str(card.pathway) != pathway:
			return false
		var required_tag := str(payload.get("required_tag", ""))
		if required_tag != "" and not _card_has_tag(card, required_tag):
			return false
		if pathway != "" or required_tag != "":
			return true
	return _card_is_fool_skill(card)


func _card_has_effect(card: Card, effect_id: String) -> bool:
	if card == null:
		return false
	for effect in card.status_effects:
		if effect is Dictionary and str(effect.get("id", "")) == effect_id:
			return true
	return false


func _card_has_tag(card: Card, tag: String) -> bool:
	if card == null:
		return false
	for item in card.tags:
		if str(item) == tag:
			return true
	return false


func _card_effects(card: Card, effect_id: String) -> Array:
	var results: Array = []
	if card == null:
		return results
	for effect in card.status_effects:
		if effect is Dictionary and str(effect.get("id", "")) == effect_id:
			results.append(effect)
	return results


func _card_id(card) -> String:
	if card == null or not card.has_method("get"):
		return ""
	var value: Variant = card.get("id")
	return "" if value == null else str(value)


func _card_log_name(card) -> String:
	if card == null:
		return "未知卡牌"
	if card.has_method("get_display_name"):
		var display_name := str(card.get_display_name()).strip_edges()
		if display_name != "":
			return display_name
	var id := _card_id(card)
	return id if id != "" else str(card)


func _card_instance_key(card: Card) -> String:
	if card == null or not card.has_method("get_instance_id"):
		return ""
	return str(card.get_instance_id())


func _all_battle_cards() -> Array:
	var cards: Array = []
	var zones := [draw_pile, hand, discard_pile, exhaust_pile, temp_picked_cards]
	for zone in zones:
		for zone_card in zone:
			if zone_card != null and not zone_card in cards:
				cards.append(zone_card)
	for used_card in used_cards.values():
		if used_card != null and not used_card in cards:
			cards.append(used_card)
	return cards


func _attack_growth_bucket() -> Dictionary:
	var bucket: Variant = field_state.get("attack_play_damage_growth", {})
	if not bucket is Dictionary:
		bucket = {}
		field_state["attack_play_damage_growth"] = bucket
	return bucket


func _brand_damage_growth_bucket() -> Dictionary:
	var bucket: Variant = field_state.get("brand_damage_growth", {})
	if not bucket is Dictionary:
		bucket = {}
		field_state["brand_damage_growth"] = bucket
	return bucket


func _brand_damage_growth_key(card: Card, brand_id: String) -> String:
	return "%s::%s" % [_card_instance_key(card), brand_id]


func _card_attack_play_damage_growth_bonus(card: Card) -> int:
	var bonus := 0
	var bucket := _attack_growth_bucket()
	var key := _card_instance_key(card)
	for effect in _card_effects(card, "attack_play_damage_growth"):
		var current := int(bucket.get(key, 0))
		var cap := maxi(0, int(effect.get("cap", current)))
		bonus += mini(current, cap)
	bonus += _card_brand_damage_growth_bonus(card)
	return bonus


func _card_brand_damage_growth_bonus(card: Card) -> int:
	var bonus := 0
	var bucket := _brand_damage_growth_bucket()
	for payload in _card_after_play_damage_growth_brand_payloads(card):
		var brand_id := str(payload.get("source_brand", ""))
		var key := _brand_damage_growth_key(card, brand_id)
		var current := int(bucket.get(key, 0))
		var cap := maxi(0, int(payload.get("damage_growth_max", payload.get("cap", current))))
		bonus += mini(current, cap)
	return bonus


func _card_after_play_damage_growth_brand_payloads(card: Card) -> Array:
	var results: Array = []
	if card == null:
		return results
	var seen_ids := {}
	for brand_id in card.brands:
		var id := str(brand_id)
		if bool(seen_ids.get(id, false)):
			continue
		seen_ids[id] = true
		var brand = BrandCatalogScript.create_brand(id)
		if brand == null:
			continue
		var payload: Dictionary = brand.effect_payload.duplicate(true)
		if str(payload.get("trigger", "")) != "after_play":
			continue
		if int(payload.get("damage_growth", 0)) <= 0:
			continue
		payload["source_brand"] = str(brand.id)
		results.append(payload)
	return results


func _card_damage_after_brand_modifiers(card: Card, extra_bonus: int = 0) -> int:
	if card == null:
		return 0
	var damage := int(card.get_effective_damage()) + extra_bonus + _card_brand_damage_add(card)
	damage = int(floor(float(damage) * _card_brand_damage_multiplier(card)))
	return maxi(0, damage)


func _active_card_damage_amount(amount: int) -> int:
	var damage := maxi(0, amount)
	var multiplier := float(field_state.get("active_card_damage_multiplier", 1.0))
	if multiplier <= 0.0:
		return damage
	if multiplier == 1.0:
		return damage
	return maxi(1, int(floor(float(damage) * multiplier)))


func _card_heal_after_brand_modifiers(card: Card) -> int:
	if card == null:
		return 0
	return maxi(0, int(card.heal) + _card_brand_heal_bonus(card))


func _card_brand_damage_add(card: Card) -> int:
	var amount := 0
	for payload in _card_stat_brand_payloads(card):
		if not _brand_stat_payload_applies(payload, card):
			continue
		if str(payload.get("stat_target", "")) == "damage" and str(payload.get("operation", "add")) == "add":
			amount += int(payload.get("value", 0))
	return amount


func _card_brand_damage_multiplier(card: Card) -> float:
	var multiplier := 1.0
	for payload in _card_stat_brand_payloads(card):
		if not _brand_stat_payload_applies(payload, card):
			continue
		if str(payload.get("stat_target", "")) == "damage" and str(payload.get("operation", "")) == "multiply":
			var value := float(payload.get("value", 1.0))
			if value > 0.0:
				multiplier *= value
	return multiplier


func _card_brand_energy_cost_delta(card: Card) -> int:
	var delta := 0
	for payload in _card_stat_brand_payloads(card):
		if not _brand_stat_payload_applies(payload, card):
			continue
		if payload.has("energy_cost_delta"):
			delta += int(payload.get("energy_cost_delta", 0))
		if str(payload.get("stat_target", "")) == "energy_cost" and str(payload.get("operation", "add")) == "add":
			delta += int(payload.get("value", 0))
	return delta


func _card_brand_heal_bonus(card: Card) -> int:
	var amount := 0
	for payload in _card_stat_brand_payloads(card):
		if not _brand_stat_payload_applies(payload, card):
			continue
		if str(payload.get("stat_target", "")) == "heal" and str(payload.get("operation", "add")) == "add":
			amount += int(payload.get("value", 0))
	return amount


func _card_brand_pierce_block(card: Card) -> int:
	var amount := 0
	for payload in _card_stat_brand_payloads(card):
		if not _brand_stat_payload_applies(payload, card):
			continue
		if str(payload.get("stat_target", "")) == "pierce" and str(payload.get("operation", "add")) == "add":
			amount += maxi(0, int(payload.get("value", 0)))
	return amount


func _card_stat_brand_payloads(card: Card) -> Array:
	var results: Array = []
	var locked_results: Array = []
	if card == null:
		return results
	var seen_ids := {}
	for brand_id in card.brands:
		var id := str(brand_id)
		if bool(seen_ids.get(id, false)):
			continue
		seen_ids[id] = true
		var brand = BrandCatalogScript.create_brand(id)
		if brand == null or str(brand.effect_type) != "stat":
			continue
		var payload: Dictionary = brand.effect_payload.duplicate(true)
		payload["source_brand"] = str(brand.id)
		if bool(payload.get("locks_other_brands", false)):
			locked_results.append(payload)
		else:
			results.append(payload)
	return locked_results if not locked_results.is_empty() else results


func _brand_stat_payload_applies(payload: Dictionary, card: Card) -> bool:
	var scope := str(payload.get("scope", ""))
	match scope:
		"element_match":
			return card != null and str(payload.get("element", "")) == str(card.element)
		_:
			return true


func _card_per_use_damage_growth_bonus(card: Card) -> int:
	var bonus := 0
	for effect in _card_effects(card, "per_use_damage_growth"):
		var magnitude := maxi(0, int(effect.get("magnitude", 0)))
		var cap := maxi(0, int(effect.get("cap", magnitude)))
		var current_uses := maxi(0, int(card.play_count))
		bonus += mini(cap, current_uses * magnitude)
	return bonus


func _record_attack_play_growth(card: Card) -> void:
	if not _card_has_tag(card, "attack"):
		return
	var bucket := _attack_growth_bucket()
	for battle_card in _all_battle_cards():
		if battle_card == null:
			continue
		for effect in _card_effects(battle_card, "attack_play_damage_growth"):
			var key := _card_instance_key(battle_card)
			var current := int(bucket.get(key, 0))
			var magnitude := maxi(0, int(effect.get("magnitude", 0)))
			var cap := maxi(0, int(effect.get("cap", magnitude)))
			bucket[key] = mini(cap, current + magnitude)


func _has_hand_card_with_tag(tag: String, excluded_card: Card = null) -> bool:
	for hand_card in hand:
		if hand_card == null or hand_card == excluded_card:
			continue
		if _card_has_tag(hand_card, tag):
			return true
	return false


func _card_target_selection_valid(card: Card, target) -> bool:
	if not _card_has_effect(card, "select_targets"):
		return true
	var selected := _preview_card_targets(card, target)
	if selected.is_empty():
		return false
	var effect: Dictionary = _card_effects(card, "select_targets")[0]
	var min_targets := maxi(1, int(effect.get("min", 1)))
	var max_targets := maxi(min_targets, int(effect.get("max", min_targets)))
	return selected.size() >= min_targets and selected.size() <= max_targets


func _preview_card_targets(card: Card, target) -> Array:
	var selected: Array = []
	var mode := str(card.target) if card != null else ""
	if target is Array:
		selected = target.duplicate(true)
	elif _card_targets_all_enemies(card):
		selected = _living_enemy_targets()
	elif mode == "random":
		selected = _random_living_enemy_targets(1, 1)
	elif mode == "random_enemies":
		var range := _random_enemy_count_range_for_card(card)
		selected = _random_living_enemy_targets(int(range[0]), int(range[1]))
	elif mode == "dual":
		selected = _dual_enemy_targets(target)
	elif card != null and mode == "self":
		selected = [player] if player != null else []
	elif _card_has_effect(card, "select_targets"):
		var field_targets: Variant = field_state.get("selected_targets", [])
		if field_targets is Array:
			selected = field_targets.duplicate(true)
	elif target != null:
		selected = [target]
	if selected.is_empty():
		var fallback = player if card != null and str(card.target) == "self" else (target if target != null and not (target is Array) else _first_living_enemy())
		if fallback != null and not (fallback is Array):
			selected = [fallback]
	selected = _apply_brand_target_rewrites(card, selected)
	return _clean_target_selection(selected)


func _apply_brand_target_rewrites(card: Card, selected: Array) -> Array:
	var results := _clean_target_selection(selected)
	if not _card_uses_multi_target_brand(card):
		return results
	if str(card.target) != "single":
		return results
	if results.size() != 1:
		return results
	for enemy in _living_enemy_targets():
		if enemy in results:
			continue
		results.append(enemy)
		break
	return results


func _random_enemy_count_range_for_card(card: Card) -> Array[int]:
	var min_targets := 1
	var max_targets := 1
	if card != null:
		for effect in card.status_effects:
			if not effect is Dictionary:
				continue
			var raw_targets: Variant = (effect as Dictionary).get("targets", [])
			if raw_targets is Array and not (raw_targets as Array).is_empty():
				var target_values: Array = raw_targets
				min_targets = maxi(1, int(target_values[0]))
				max_targets = maxi(min_targets, int(target_values[target_values.size() - 1]))
				break
	return [min_targets, max_targets]


func _random_living_enemy_targets(min_count: int, max_count: int) -> Array:
	var candidates := _living_enemy_targets()
	if candidates.is_empty():
		return []
	var lower := clampi(min_count, 1, candidates.size())
	var upper := clampi(maxi(lower, max_count), lower, candidates.size())
	var count := lower
	if upper > lower:
		count = lower + int(randi() % (upper - lower + 1))
	var selected: Array = []
	var pool := candidates.duplicate()
	while selected.size() < count and not pool.is_empty():
		var index := int(randi() % pool.size())
		selected.append(pool[index])
		pool.remove_at(index)
	return selected


func _dual_enemy_targets(target) -> Array:
	var selected: Array = []
	if target != null and not (target is Array) and not _actor_is_dead(target):
		selected.append(target)
	var candidates := _living_enemy_targets()
	for existing in selected:
		candidates.erase(existing)
	while selected.size() < 2 and not candidates.is_empty():
		var index := int(randi() % candidates.size())
		selected.append(candidates[index])
		candidates.remove_at(index)
	return selected


func _resolve_card_targets(card: Card, target) -> Array:
	var selected := _preview_card_targets(card, target)
	field_state["selected_targets"] = []
	return selected


func _clean_target_selection(targets: Array) -> Array:
	var results: Array = []
	for entry in targets:
		if entry == null or _actor_is_dead(entry):
			continue
		if not entry in results:
			results.append(entry)
	return results


func _card_targets_all_enemies(card: Card) -> bool:
	if card == null:
		return false
	var mode := str(card.target)
	return mode == "all_enemies" or mode == "aoe"


func _living_enemy_targets() -> Array:
	var results: Array = []
	for enemy in enemies:
		if enemy != null and not _actor_is_dead(enemy):
			results.append(enemy)
	return results


func _select_targets_damage_multiplier(card: Card, target_count: int) -> float:
	var brand_multiplier := _card_multi_target_damage_multiplier(card)
	if brand_multiplier != 1.0:
		return brand_multiplier
	if not _card_has_effect(card, "select_targets"):
		return 1.0
	if target_count >= 3:
		return 0.5
	if target_count == 2:
		return 0.7
	return 1.0


func _card_uses_multi_target_brand(card: Card) -> bool:
	return not _card_multi_target_brand_payloads(card).is_empty()


func _card_multi_target_damage_multiplier(card: Card) -> float:
	if card == null:
		return 1.0
	if str(card.target) != "single":
		return 1.0
	for payload in _card_multi_target_brand_payloads(card):
		var multiplier := float(payload.get("damage_multiplier", 1.0))
		if multiplier > 0.0:
			return multiplier
	return 1.0


func _card_multi_target_brand_payloads(card: Card) -> Array:
	var results: Array = []
	for payload in _card_stat_brand_payloads(card):
		if str(payload.get("target_mode", "")) == "two_targets":
			results.append(payload)
	return results


func _multi_strike_config(card: Card) -> Dictionary:
	for effect in _card_effects(card, "multi_strike"):
		var hits := maxi(1, int(effect.get("hits", effect.get("magnitude", 1))))
		var damage_each := int(effect.get("damage_each", effect.get("magnitude", 0)))
		return {
			"enabled": true,
			"hits": hits,
			"damage_each": damage_each,
		}
	return {"enabled": false, "hits": 1, "damage_each": 0}


func _counter_intent_ids() -> Array:
	var ids: Array = []
	for enemy in enemies:
		if enemy != null and _is_counter_intent(current_enemy_intents.get(enemy.id, {})):
			ids.append(enemy.id)
	return ids


func _is_counter_intent(intent: Dictionary) -> bool:
	return str(intent.get("type", intent.get("action", ""))) == "counter"


func _counter_intent_damage(intent: Dictionary) -> int:
	var params_variant = intent.get("params", {})
	var params: Dictionary = params_variant if params_variant is Dictionary else {}
	if intent.has("damage"):
		return maxi(0, int(intent.get("damage", 0)))
	return maxi(0, int(params.get("damage", 0)))


func _trigger_counter_intents(card: Card) -> void:
	if _card_has_effect(card, "avoid_counter_intent"):
		field_state["last_counter_result"] = {"triggered": [], "skipped": _counter_intent_ids()}
		return
	var triggered: Array = []
	for enemy in enemies:
		if enemy == null:
			continue
		var intent: Dictionary = current_enemy_intents.get(enemy.id, {})
		if not _is_counter_intent(intent):
			continue
		var damage := _counter_intent_damage(intent)
		if damage > 0 and player != null:
			_deal_raw_damage(player, damage, enemy)
		triggered.append(enemy.id)
	field_state["last_counter_result"] = {"triggered": triggered, "skipped": []}


func _mark_enemy_intents_revealed(card: Card, target) -> void:
	if card == null:
		return
	var detail_level := 0
	if _card_has_tag(card, "intent_reveal") or _card_has_effect(card, "intent_revealed") or _card_has_effect(card, "revealed"):
		detail_level = 1
	if _card_has_tag(card, "mind_read") or _card_has_effect(card, "mind_revealed"):
		detail_level = maxi(detail_level, 2)
	if detail_level <= 0:
		return
	var targets: Array = []
	if target == null or str(card.target) == "self":
		targets = _living_enemy_targets()
	else:
		targets = _preview_card_targets(card, target)
	if targets.is_empty():
		targets = _living_enemy_targets()
	var revealed_ids: Array[String] = []
	for enemy in targets:
		if enemy == null or _actor_is_dead(enemy):
			continue
		var enemy_id := _actor_id(enemy)
		if enemy_id == "":
			continue
		var intent: Dictionary = current_enemy_intents.get(enemy_id, EnemyAiScript.decide_action(enemy, turn_count))
		intent["revealed_by_card"] = true
		intent["detail_level"] = maxi(int(intent.get("detail_level", 0)), detail_level)
		current_enemy_intents[enemy_id] = intent
		revealed_enemy_intent_details[enemy_id] = {"detail_level": int(intent.get("detail_level", detail_level))}
		if not enemy_id in revealed_ids:
			revealed_ids.append(enemy_id)
	if not revealed_ids.is_empty():
		last_effect_results.append({
			"ok": true,
			"reason": "intent_revealed_by_card",
			"id": "mind_read" if detail_level >= 2 else "intent_reveal",
			"source_card_id": str(card.id),
			"detail_level": detail_level,
			"target_count": revealed_ids.size(),
			"target_ids": revealed_ids,
		})


func _effective_card_cost(card: Card) -> int:
	if card == null:
		return 0
	var cost := int(card.energy_cost)
	cost += _card_brand_energy_cost_delta(card)
	if player != null and player.has_status("next_card_cost_delta") and _card_uses_next_card_cost_delta(card):
		var payload: Dictionary = player.statuses.get("next_card_cost_delta", {})
		cost = maxi(0, cost + int(payload.get("magnitude", 0)))
	if player != null and player.has_status("mp_cost_up"):
		var mp_payload: Dictionary = player.statuses.get("mp_cost_up", {})
		var multiplier := 1.0 + maxf(0.0, float(mp_payload.get("magnitude", 0.0)))
		cost = maxi(0, int(ceil(float(cost) * multiplier)))
	if _card_has_effect(card, "cost_zero_if_flame_stream") and _has_hand_card_with_tag("flame_stream", card):
		cost = 0
	cost = _card_first_play_brand_cost_override(card, cost)
	return maxi(0, cost)


func effective_card_cost(card: Card) -> int:
	return _effective_card_cost(card)


func _card_is_fool_skill(card: Card) -> bool:
	if card == null:
		return false
	return str(card.pathway) == "fool" and "skill" in card.tags


func _card_requires_flame_marker(card: Card) -> bool:
	if card == null:
		return false
	for effect in card.status_effects:
		if not effect is Dictionary:
			continue
		var id := str(effect.get("id", ""))
		if id == "consume_flame_marker" or id == "teleport_to_flame":
			return true
	return false


func _record_paper_blade_kills(card: Card, killed_targets: Array) -> void:
	if _game_state == null or killed_targets.is_empty() or not _is_paper_blade_card(card):
		return
	if _game_state.has_method("record_paper_blade_kill"):
		_game_state.record_paper_blade_kill(killed_targets.size())
	elif _game_state.has_method("set_meta"):
		var current := int(_game_state.get_meta("paper_blade_kill_count", 0))
		_game_state.set_meta("paper_blade_kill_count", current + killed_targets.size())


func _is_paper_blade_card(card: Card) -> bool:
	if card == null:
		return false
	return "paper_blade" in card.tags


func _acting_check_difficulty(total_rules: int, game_state) -> Dictionary:
	var base := maxi(0, total_rules)
	var weather_modifier := 0
	if game_state != null:
		var bonus := WeatherEffectsApplierScript.get_bonus(str(game_state.current_weather), str(game_state.pathway), "acting_check")
		weather_modifier = -bonus
	return {
		"base": base,
		"weather_modifier": weather_modifier,
		"difficulty": maxi(0, base + weather_modifier),
	}


func _apply_weather_pollution_on_victory(game_state) -> int:
	if game_state == null:
		return 0
	var weather_id := str(game_state.current_weather)
	var pathway := str(game_state.pathway)
	var delta := WeatherEffectsApplierScript.get_global_modifier(weather_id, "pollution")
	delta += WeatherEffectsApplierScript.get_bonus(weather_id, pathway, "pollution")
	if delta == 0:
		return 0
	_apply_pollution_value(game_state, int(game_state.pollution) + delta, ["combat_weather_%s" % weather_id])
	return delta


func _apply_pollution_value(game_state, value: int, recent_actions: Array = []) -> void:
	if game_state == null:
		return
	var next_value := clampi(value, 0, 100)
	if game_state.has_method("set_pollution"):
		game_state.call("set_pollution", next_value, recent_actions)
	else:
		game_state.pollution = next_value
		game_state.pollution_stage = _pollution_stage(next_value)


func _pollution_stage(value: int) -> int:
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


func _actor_is_dead(actor) -> bool:
	if actor == null:
		return true
	if actor.has_method("is_dead"):
		return actor.is_dead()
	return int(actor.hp) <= 0


func _actor_has_status(actor, id: String) -> bool:
	return actor != null and actor.has_method("has_status") and actor.has_status(id)


func _actor_id(actor) -> String:
	if actor == null or not actor.has_method("get"):
		return ""
	var value: Variant = actor.get("id")
	return "" if value == null else str(value)


func _status_magnitude(actor, id: String) -> int:
	if actor == null or not actor.has_method("has_status") or not actor.has_status(id):
		return 0
	var statuses = actor.get("statuses") if actor.has_method("get") else {}
	if not statuses is Dictionary:
		return 0
	var payload: Variant = (statuses as Dictionary).get(id, {})
	if payload is Dictionary:
		return int((payload as Dictionary).get("magnitude", 0))
	return 0


func _modified_outgoing_damage(source, amount: int) -> int:
	var result := maxi(0, amount)
	if _actor_has_status(source, "weak"):
		result = int(floor(float(result) * 0.75))
	if _actor_has_status(source, "blind"):
		result = int(floor(float(result) * 0.5))
	if _actor_has_status(source, "atk_boost"):
		result += maxi(0, _status_magnitude(source, "atk_boost"))
	if _actor_has_status(source, "next_attack_damage_delta"):
		result += maxi(0, _status_magnitude(source, "next_attack_damage_delta"))
		source.remove_status("next_attack_damage_delta")
	return result


func _preview_modified_outgoing_damage(source, amount: int) -> int:
	var result := maxi(0, amount)
	if _actor_has_status(source, "weak"):
		result = int(floor(float(result) * 0.75))
	if _actor_has_status(source, "blind"):
		result = int(floor(float(result) * 0.5))
	if _actor_has_status(source, "atk_boost"):
		result += maxi(0, _status_magnitude(source, "atk_boost"))
	if _actor_has_status(source, "next_attack_damage_delta"):
		result += maxi(0, _status_magnitude(source, "next_attack_damage_delta"))
	return result


func _deal_damage(source, target, base_damage: int, element: String, effect_modifiers: Array = [], source_card: Card = null) -> int:
	if target == null or base_damage <= 0:
		return 0
	target = _reroll_damage_target(source, target)
	if target == null:
		return 0
	var defender_element := str(target.get("element")) if target.has_method("get") else "普通"
	if defender_element == "":
		defender_element = "普通"
	var defense := int(target.get("def")) if target.has_method("get") else 0
	defense = maxi(0, defense - _defense_ignore_amount(effect_modifiers, defense, source_card))
	var element_mult := 1.0
	if _element_table != null:
		element_mult = _element_table.multiplier(element, defender_element)
	var attack_damage := _modified_outgoing_damage(source, base_damage)
	attack_damage += _effect_bonus_damage(effect_modifiers, target, attack_damage)
	attack_damage = int(floor(float(attack_damage) * _effect_damage_multiplier(effect_modifiers)))
	var scaled_damage := int(floor(float(attack_damage) * element_mult))
	scaled_damage = int(floor(float(scaled_damage) * _enemy_affinity_damage_multiplier(target, element)))
	var raw_damage: int = scaled_damage - defense
	var final_damage: int = maxi(1, raw_damage)
	return _apply_incoming_damage(target, final_damage, source)


func _enemy_affinity_damage_multiplier(target, element: String) -> float:
	if target == null or element == "":
		return 1.0
	var weaknesses := _string_values(target.get("weakness") if target.has_method("get") else [])
	if element in weaknesses:
		var resistances_for_conflict := _string_values(target.get("resistance") if target.has_method("get") else [])
		if element in resistances_for_conflict:
			last_effect_results.append({
				"ok": false,
				"reason": "enemy_affinity_conflict",
				"issue": "data_configuration",
				"target_id": _actor_id(target),
				"element": element,
				"resolution": "weakness_priority",
			})
		return ENEMY_WEAKNESS_DAMAGE_MULTIPLIER
	var resistances := _string_values(target.get("resistance") if target.has_method("get") else [])
	if element in resistances:
		return ENEMY_RESISTANCE_DAMAGE_MULTIPLIER
	return 1.0


func _reroll_damage_target(source, target):
	if source == null or not _actor_has_status(source, "reroll_next_target"):
		return target
	var original_target = target
	if source.has_method("remove_status"):
		source.remove_status("reroll_next_target")
	var living_enemies: Array = []
	for enemy in enemies:
		if enemy != null and not enemy.is_dead():
			living_enemies.append(enemy)
	if living_enemies.is_empty():
		_record_reroll_next_target_consumed(source, original_target, target)
		return target
	var rerolled_target = target
	for enemy in living_enemies:
		if enemy != target:
			rerolled_target = enemy
			break
	if rerolled_target == null:
		rerolled_target = living_enemies[0]
	_record_reroll_next_target_consumed(source, original_target, rerolled_target)
	return rerolled_target


func _record_reroll_next_target_consumed(source, original_target, rerolled_target) -> void:
	last_effect_results.append({
		"ok": true,
		"reason": "reroll_next_target_consumed",
		"id": "reroll_next_target",
		"source_id": "player" if source == player else _actor_id(source),
		"original_target_id": _actor_id(original_target),
		"target_id": _actor_id(rerolled_target),
	})


func _effect_magnitude(effects: Array, id: String) -> int:
	for effect in effects:
		if effect is Dictionary and str(effect.get("id", "")) == id:
			return int(effect.get("magnitude", 0))
	return 0


func _effect_present(effects: Array, id: String) -> bool:
	for effect in effects:
		if effect is Dictionary and str(effect.get("id", "")) == id:
			return true
	return false


func _defense_ignore_amount(effects: Array, defense: int, source_card: Card = null) -> int:
	var amount := _effect_magnitude(effects, "pierce_block")
	amount += _effect_magnitude(effects, "ignore_guard")
	amount += _card_brand_pierce_block(source_card)
	if _effect_present(effects, "pierce") or _effect_present(effects, "break_block"):
		amount = maxi(amount, defense)
	return amount


func _effect_bonus_damage(effects: Array, target, current_damage: int) -> int:
	var bonus := 0
	for effect in effects:
		if not effect is Dictionary:
			continue
		var effect_id := str(effect.get("id", ""))
		match effect_id:
			"execute_bonus_below_hp_pct":
				if target != null:
					var max_hp := maxi(1, int(target.max_hp))
					var threshold := float(effect.get("threshold", 0.0))
					if threshold > 0.0 and float(target.hp) / float(max_hp) <= threshold:
						bonus += int(effect.get("bonus_damage", effect.get("magnitude", 0)))
			"range_bonus":
				bonus += maxi(0, int(effect.get("magnitude", 0)))
	return bonus


func _effect_damage_multiplier(effects: Array) -> float:
	var multiplier := 1.0
	if _effect_present(effects, "crit_up"):
		multiplier *= 1.5
	return multiplier


func _life_steal_amount(card: Card, damage_dealt: int) -> int:
	var amount := 0
	for effect in _card_effects(card, "life_steal"):
		var magnitude := float(effect.get("magnitude", 0.0))
		if magnitude > 0.0 and magnitude < 1.0:
			amount += int(floor(float(damage_dealt) * magnitude))
		else:
			amount += int(magnitude)
	return maxi(0, amount)


func _apply_incoming_damage(target, amount: int, source = null) -> int:
	if target == null or amount <= 0:
		return 0
	var final_damage := amount
	if _actor_has_status(target, "stealth"):
		target.remove_status("stealth")
		return 0
	if _actor_has_status(target, "invulnerable"):
		return 0
	if _actor_has_status(target, "dodge_counter"):
		_consume_dodge_counter(target, source)
		return 0
	if _actor_has_status(target, "mark"):
		var mark_bonus := _status_magnitude(target, "mark")
		final_damage += 2 if mark_bonus <= 0 else mark_bonus
	if _actor_has_status(target, "vulnerable"):
		final_damage = int(floor(float(final_damage) * 1.5))
	if _actor_has_status(target, "def_buff"):
		final_damage = maxi(0, final_damage - _status_magnitude(target, "def_buff"))
	if _actor_has_status(target, "damage_reduction"):
		var reduction_payload: Dictionary = target.statuses.get("damage_reduction", {})
		var incoming_before_reduction := final_damage
		final_damage = _damage_after_reduction(final_damage, reduction_payload)
		target.remove_status("damage_reduction")
		_consume_on_trigger_if_present(target)
		last_effect_results.append({
			"ok": true,
			"reason": "damage_reduction_triggered",
			"id": "damage_reduction",
			"incoming_damage": incoming_before_reduction,
			"reduced_damage": final_damage,
			"prevented_damage": maxi(0, incoming_before_reduction - final_damage),
			"magnitude": float(reduction_payload.get("magnitude", 0.0)),
			"target_id": _actor_result_id(target),
			"source_id": _actor_result_id(source),
		})
	if final_damage >= int(target.hp) and _consume_paper_doll_if_available(target, final_damage, source):
		return 0
	if final_damage >= int(target.hp) and _consume_fatal_damage_substitute_brand(target, final_damage, source):
		return 0
	if _actor_has_status(target, "fatal_damage_convert") and final_damage >= int(target.hp):
		var convert_payload: Dictionary = target.statuses.get("fatal_damage_convert", {})
		var ratio := float(convert_payload.get("magnitude", 1.0))
		final_damage = maxi(0, int(floor(float(target.hp) * ratio)))
		var uses_left := int(convert_payload.get("uses_per_battle", 1)) - 1
		if uses_left <= 0:
			target.remove_status("fatal_damage_convert")
		else:
			convert_payload["uses_per_battle"] = uses_left
			target.statuses["fatal_damage_convert"] = convert_payload
		_consume_on_trigger_if_present(target)
	target.hp = max(0, int(target.hp) - final_damage)
	return final_damage


func _preview_incoming_damage(target, amount: int) -> int:
	if target == null or amount <= 0:
		return 0
	var final_damage := amount
	if _actor_has_status(target, "stealth"):
		return 0
	if _actor_has_status(target, "invulnerable"):
		return 0
	if _actor_has_status(target, "dodge_counter"):
		return 0
	if _actor_has_status(target, "mark"):
		var mark_bonus := _status_magnitude(target, "mark")
		final_damage += 2 if mark_bonus <= 0 else mark_bonus
	if _actor_has_status(target, "vulnerable"):
		final_damage = int(floor(float(final_damage) * 1.5))
	if _actor_has_status(target, "def_buff"):
		final_damage = maxi(0, final_damage - _status_magnitude(target, "def_buff"))
	if _actor_has_status(target, "damage_reduction"):
		var reduction_payload: Dictionary = target.statuses.get("damage_reduction", {})
		final_damage = _damage_after_reduction(final_damage, reduction_payload)
	if final_damage >= int(target.hp) and _actor_has_paper_doll_marker(target):
		return 0
	return final_damage


func _damage_after_actor_defense(target, amount: int) -> int:
	return _damage_after_actor_defense_with_skill_options(target, amount, {})


func _damage_after_actor_defense_with_skill_options(target, amount: int, skill: Dictionary) -> int:
	if target == null or amount <= 0:
		return 0
	var defense := int(target.get("def")) if target.has_method("get") else 0
	defense = _effective_defense_after_enemy_skill_options(defense, skill)
	return maxi(1, amount - maxi(0, defense))


func _effective_defense_after_enemy_skill_options(defense: int, skill: Dictionary) -> int:
	var base_defense := maxi(0, defense)
	if skill.is_empty():
		return base_defense
	if _enemy_skill_ignores_defense(skill):
		return 0
	var pierce := maxi(0, int(skill.get("pierce_defense", 0)))
	return maxi(0, base_defense - pierce)


func _enemy_skill_ignores_defense(skill: Dictionary) -> bool:
	var value: Variant = skill.get("ignore_defense", false)
	if value is bool:
		return bool(value)
	var text := str(value).to_lower()
	return text == "true" or text == "1" or text == "yes"


func _damage_after_reduction(amount: int, payload: Dictionary) -> int:
	var magnitude := float(payload.get("magnitude", 0.0))
	if magnitude > 0.0 and magnitude < 1.0:
		return maxi(0, int(floor(float(amount) * (1.0 - magnitude))))
	return maxi(0, amount - int(magnitude))


func _consume_dodge_counter(target, source) -> void:
	var payload: Dictionary = target.statuses.get("dodge_counter", {}) if target != null and target.has_method("get") else {}
	if target != null and target.has_method("remove_status"):
		target.remove_status("dodge_counter")
	_consume_on_trigger_if_present(target)
	var counter_damage := maxi(0, int(payload.get("magnitude", 0)))
	var target_id := _actor_id(target)
	if target_id == "" and target == player:
		target_id = "player"
	var result := {
		"ok": true,
		"reason": "dodge_counter_triggered",
		"id": "dodge_counter",
		"damage": 0,
		"target_id": target_id,
		"source_id": _actor_id(source),
	}
	if counter_damage <= 0 or source == null:
		last_effect_results.append(result)
		return
	source.hp = max(0, int(source.hp) - counter_damage)
	result["damage"] = counter_damage
	last_effect_results.append(result)


func _apply_enemy_skill_status_effects(enemy, target, skill: Dictionary) -> void:
	var effects: Variant = skill.get("status_effects", [])
	if not effects is Array:
		return
	var status_target = enemy if str(skill.get("target", "single")) == "self" else target
	for raw_effect in effects:
		if not raw_effect is Dictionary:
			continue
		var effect: Dictionary = raw_effect
		var status_id := str(effect.get("id", ""))
		if status_id == "" or status_target == null or not status_target.has_method("add_status"):
			continue
		var chance := float(effect.get("chance", 1.0))
		if chance < 1.0 and randf() >= chance:
			continue
		if _incoming_status_blocked(status_target, status_id, enemy):
			continue
		_apply_actor_status(status_target, status_id, effect)


func _apply_actor_status(actor, status_id: String, effect: Dictionary) -> void:
	var payload := effect.duplicate(true)
	payload["id"] = status_id
	if status_id == "hp_boost" and actor != null and not actor.has_status("hp_boost"):
		var amount := maxi(0, int(payload.get("magnitude", 0)))
		if amount > 0:
			actor.max_hp = int(actor.max_hp) + amount
			actor.hp = int(actor.hp) + amount
	actor.add_status(status_id, payload)


func _incoming_status_blocked(actor, status_id: String, source = null) -> bool:
	if actor == null or not _status_is_debuff(status_id):
		return false
	if _status_guard_matches(actor, "cleanse_incoming_debuff", status_id):
		actor.remove_status("cleanse_incoming_debuff")
		last_effect_results.append({
			"ok": true,
			"reason": "cleanse_incoming_debuff",
			"id": "cleanse_incoming_debuff",
			"blocked_status_id": status_id,
			"target_id": _actor_result_id(actor),
			"source_id": _actor_result_id(source),
			"guard_consumed": true,
		})
		return true
	if _status_guard_matches(actor, "immune_debuff", status_id):
		var consume_triggered := _actor_has_status(actor, "consume_on_trigger")
		if consume_triggered:
			actor.remove_status("consume_on_trigger")
			actor.remove_status("immune_debuff")
		last_effect_results.append({
			"ok": true,
			"reason": "immune_debuff",
			"id": "immune_debuff",
			"blocked_status_id": status_id,
			"target_id": _actor_result_id(actor),
			"source_id": _actor_result_id(source),
			"consume_on_trigger_consumed": consume_triggered,
			"guard_consumed": consume_triggered,
		})
		return true
	return false


func _status_guard_matches(actor, guard_id: String, status_id: String) -> bool:
	if not _actor_has_status(actor, guard_id):
		return false
	var statuses = actor.get("statuses") if actor.has_method("get") else {}
	var payload: Dictionary = statuses.get(guard_id, {}) if statuses is Dictionary else {}
	var types := _status_guard_types(payload)
	if types.is_empty():
		return true
	return status_id in types


func _status_guard_types(payload: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw_types: Variant = payload.get("types", [])
	if not raw_types is Array:
		return result
	for raw_type in raw_types:
		result.append(str(raw_type))
	return result


func _actor_result_id(actor) -> String:
	var id := _actor_id(actor)
	if id == "" and actor == player:
		return "player"
	return id


func _status_is_debuff(status_id: String) -> bool:
	return status_id in [
		"weak",
		"vulnerable",
		"confusion",
		"nightmare",
		"obscure_intent",
		"burn",
		"poison",
		"fear",
		"mp_cost_up",
		"resistance_lost",
		"stun",
		"silence",
		"bind",
		"root",
		"paralyze",
		"suffocate",
		"slow",
		"blind",
		"chill",
		"revealed",
		"bind",
		"root",
		"delay_intent",
		"displace",
		"counter_spell",
		"mark",
		"mind_revealed",
		"intent_revealed",
	]


func _consume_on_trigger_if_present(target) -> void:
	if _actor_has_status(target, "consume_on_trigger"):
		target.remove_status("consume_on_trigger")


func _actor_has_paper_doll_marker(target) -> bool:
	return target != null and target.has_method("get_marker_count") and int(target.get_marker_count("paper_doll")) > 0


func _consume_paper_doll_if_available(target, incoming_damage: int = 0, source = null) -> bool:
	if target == null or not target.has_method("get_marker_count") or not target.has_method("consume_marker"):
		return false
	if int(target.get_marker_count("paper_doll")) <= 0:
		return false
	target.consume_marker("paper_doll", 1)
	var remaining := int(target.get_marker_count("paper_doll"))
	if int(target.get_marker_count("paper_doll")) <= 0 and _actor_has_status(target, "absorb_fatal_or_curse"):
		target.remove_status("absorb_fatal_or_curse")
	var target_id := _actor_id(target)
	if target_id == "" and target == player:
		target_id = "player"
	last_effect_results.append({
		"ok": true,
		"reason": "paper_doll_absorbed_fatal",
		"id": "paper_doll_marker",
		"incoming_damage": maxi(0, incoming_damage),
		"target_id": target_id,
		"source_id": _actor_id(source),
		"remaining_markers": remaining,
	})
	return true


func _consume_fatal_damage_substitute_brand(target, incoming_damage: int, source = null) -> bool:
	if target == null or target != player or incoming_damage <= 0:
		return false
	for payload in _active_battle_trigger_brand_payloads("fatal_damage"):
		if str(payload.get("effect", "")) != "substitute_death":
			continue
		var chance := _fatal_damage_brand_chance(payload)
		var roll := 1.0
		var triggered := false
		if chance >= 1.0:
			roll = 0.0
			triggered = true
		elif chance > 0.0:
			roll = randf()
			triggered = roll < chance
		last_effect_results.append({
			"ok": true,
			"reason": "brand_fatal_substitute_triggered" if triggered else "brand_fatal_substitute_missed",
			"id": str(payload.get("source_brand", "")),
			"trigger": "fatal_damage",
			"source_card_id": str(payload.get("source_card_id", "")),
			"source_card_instance": str(payload.get("source_card_instance", "")),
			"source_actor_id": _actor_id(source),
			"target_id": _actor_id(target),
			"incoming_damage": incoming_damage,
			"target_hp": int(target.hp),
			"roll": roll,
			"chance": chance,
		})
		if triggered:
			return true
	return false


func _fatal_damage_brand_chance(payload: Dictionary) -> float:
	var chance := clampf(float(payload.get("chance", 0.0)), 0.0, 1.0)
	var brand_id := str(payload.get("source_brand", ""))
	var override: Variant = field_state.get("%s_fatal_damage_chance_override" % brand_id, null)
	if override == null:
		override = field_state.get("brand_fatal_damage_chance_override", null)
	if override != null:
		chance = clampf(float(override), 0.0, 1.0)
	return chance


func _active_battle_trigger_brand_payloads(trigger_id: String) -> Array:
	var payloads: Array = []
	for card in _all_battle_cards():
		if card == null:
			continue
		for payload in _card_trigger_brand_payloads(card, trigger_id):
			var entry: Dictionary = payload.duplicate(true)
			entry["source_card_id"] = str(card.id)
			entry["source_card_instance"] = _card_instance_key(card)
			payloads.append(entry)
	return payloads


func _clear_battle_scoped_actor_state() -> void:
	var actors := []
	if player != null:
		actors.append(player)
	for enemy in enemies:
		if enemy != null:
			actors.append(enemy)
	for actor in actors:
		var statuses = actor.get("statuses") if actor.has_method("get") else {}
		if statuses is Dictionary:
			statuses.clear()
		var markers = actor.get("markers")
		if markers is Dictionary:
			markers.erase("paper_doll")


func _heal(target, amount: int) -> int:
	if target == null or amount <= 0:
		return 0
	var before := int(target.hp)
	var maximum: int = int(target.max_hp)
	target.hp = min(maximum, before + amount)
	return int(target.hp) - before


func _execute_enemy_intent(enemy, intent: Dictionary) -> void:
	if _enemy_intent_cancelled_by_brand(enemy, intent):
		return
	match str(intent.get("action", "defend")):
		"use_skill":
			_trigger_counter_spell_on_skill_attempt(enemy)
			if enemy != null and enemy.has_method("is_dead") and enemy.is_dead():
				return
			if _actor_has_status(enemy, "silence"):
				return
			if _enemy_energy_delta_cancels_skill_action(enemy, intent):
				return
			var skill := _find_enemy_skill(enemy, str(intent.get("skill", "")))
			if skill.is_empty():
				return
			if _enemy_skill_blocked_by_forbidden_tags(enemy, skill):
				var fallback_skill := _first_allowed_enemy_skill(enemy, str(skill.get("id", "")))
				last_effect_results.append({
					"ok": true,
					"reason": "enemy_skill_blocked_by_forbidden_tags",
					"enemy_id": _actor_id(enemy),
					"blocked_skill_id": str(skill.get("id", "")),
					"fallback_skill_id": str(fallback_skill.get("id", "")),
				})
				if fallback_skill.is_empty():
					return
				skill = fallback_skill
			var target = enemy if str(skill.get("target", "single")) == "self" else player
			if target == player:
				target = _face_mask_redirect_target(enemy, target)
			if int(skill.get("damage", 0)) > 0:
				target = _confusion_redirect_target(enemy, target)
				_deal_enemy_skill_damage(target, int(skill.get("damage", 0)), enemy, skill)
			if int(skill.get("heal", 0)) > 0:
				_heal(target, int(skill.get("heal", 0)))
			_apply_enemy_skill_status_effects(enemy, target, skill)
			_mark_enemy_one_time_skill_resolved(enemy, skill)
		"defend":
			var params_variant: Variant = intent.get("params", {})
			var params: Dictionary = params_variant if params_variant is Dictionary else {}
			var magnitude := float(params.get("damage_reduction", params.get("magnitude", 0.0)))
			if magnitude > 0.0 and enemy != null and enemy.has_method("add_status"):
				enemy.add_status("damage_reduction", {
					"id": "damage_reduction",
					"magnitude": magnitude,
					"duration": maxi(1, int(params.get("duration", 1))),
				})
			return


func _mark_enemy_one_time_skill_resolved(enemy, skill: Dictionary) -> void:
	if enemy == null or skill.get("one_time_only", false) != true:
		return
	if str(skill.get("id", "")) == "shadow_transformation":
		enemy.set("transformed", true)


func _enemy_intent_cancelled_by_brand(enemy, intent: Dictionary) -> bool:
	if enemy == null or intent.is_empty():
		return false
	if not bool(intent.get("cancelled_by_brand", false)) and str(intent.get("action", "")) != "cancelled":
		return false
	last_effect_results.append({
		"ok": true,
		"reason": "enemy_intent_cancelled_by_brand",
		"enemy_id": _actor_id(enemy),
		"id": str(intent.get("cancel_brand_id", "")),
	})
	return true


func _trigger_counter_spell_on_skill_attempt(enemy) -> void:
	if not _actor_has_status(enemy, "counter_spell"):
		return
	var counter_payload: Dictionary = enemy.statuses.get("counter_spell", {})
	var damage := maxi(1, int(counter_payload.get("magnitude", 6)))
	var dealt := _deal_raw_damage(enemy, damage, player)
	enemy.remove_status("counter_spell")
	last_effect_results.append({
		"ok": true,
		"reason": "counter_spell_triggered",
		"id": "counter_spell",
		"damage": dealt,
		"target_id": _actor_result_id(enemy),
		"source_id": _actor_result_id(player),
	})


func _enemy_energy_delta_cancels_skill_action(enemy, intent: Dictionary) -> bool:
	if enemy == null or not _actor_has_status(enemy, "enemy_energy_delta_next_turn"):
		return false
	if str(intent.get("action", "")) != "use_skill":
		return false
	var payload: Dictionary = enemy.statuses.get("enemy_energy_delta_next_turn", {})
	var magnitude := int(payload.get("magnitude", 0))
	if magnitude >= 0:
		return false
	magnitude += 1
	if magnitude < 0:
		payload["magnitude"] = magnitude
		enemy.statuses["enemy_energy_delta_next_turn"] = payload
	else:
		enemy.remove_status("enemy_energy_delta_next_turn")
	last_effect_results.append({
		"ok": true,
		"reason": "enemy_skill_cancelled_by_energy_delta",
		"enemy_id": _actor_id(enemy),
		"id": str(payload.get("source_brand", "")),
		"remaining_magnitude": magnitude,
	})
	return true


func _enemy_skill_blocked_by_forbidden_tags(enemy, skill: Dictionary) -> bool:
	if enemy == null or skill.is_empty() or not _actor_has_status(enemy, "forbidden_skill_tags"):
		return false
	var payload: Dictionary = enemy.statuses.get("forbidden_skill_tags", {})
	var forbidden_tags := _string_values(payload.get("tags", []))
	if forbidden_tags.is_empty():
		return false
	for tag in _enemy_skill_tags(skill):
		if tag in forbidden_tags:
			return true
	return false


func _enemy_skill_tags(skill: Dictionary) -> Array[String]:
	var tags := _string_values(skill.get("tags", []))
	for tag in _string_values(skill.get("skill_tags", [])):
		if not tag in tags:
			tags.append(tag)
	return tags


func _first_allowed_enemy_skill(enemy, blocked_skill_id: String = "") -> Dictionary:
	if enemy == null:
		return {}
	for skill in enemy.skills:
		if not skill is Dictionary:
			continue
		var candidate: Dictionary = skill
		if str(candidate.get("id", "")) == blocked_skill_id:
			continue
		if _enemy_skill_blocked_by_forbidden_tags(enemy, candidate):
			continue
		return candidate
	return {}


func _face_mask_redirect_target(enemy, default_target):
	if enemy == null or default_target != player or not _actor_has_status(enemy, "face_mask_redirect"):
		return default_target
	var payload: Dictionary = enemy.statuses.get("face_mask_redirect", {})
	if enemy.has_method("remove_status"):
		enemy.remove_status("face_mask_redirect")
	var chance := clampf(float(payload.get("chance", 0.0)), 0.0, 1.0)
	var override: Variant = field_state.get("face_mask_redirect_chance_override", null)
	if override != null:
		chance = clampf(float(override), 0.0, 1.0)
	var roll := randf()
	if chance <= 0.0 or roll >= chance:
		last_effect_results.append({
			"ok": true,
			"reason": "brand_face_mask_redirect_missed",
			"id": str(payload.get("source_brand", "")),
			"enemy_id": _actor_id(enemy),
			"roll": roll,
			"chance": chance,
		})
		return default_target
	var alternatives: Array = []
	for other in enemies:
		if other == null or other == enemy or _actor_is_dead(other):
			continue
		alternatives.append(other)
	var redirected_target = enemy if alternatives.is_empty() else alternatives[randi() % alternatives.size()]
	last_effect_results.append({
		"ok": true,
		"reason": "brand_face_mask_redirect_triggered",
		"id": str(payload.get("source_brand", "")),
		"enemy_id": _actor_id(enemy),
		"target_id": _actor_id(redirected_target),
		"roll": roll,
		"chance": chance,
	})
	return redirected_target


func _confusion_redirect_target(enemy, default_target):
	if enemy == null or not _actor_has_status(enemy, "confusion"):
		return default_target
	var chance := _confusion_redirect_chance()
	var override: Variant = field_state.get("confusion_redirect_chance_override", null)
	if override != null:
		chance = clampf(float(override), 0.0, 1.0)
	if chance <= 0.0 or randf() > chance:
		return default_target
	var alternatives: Array = []
	for other in enemies:
		if other == null or other == enemy or _actor_is_dead(other):
			continue
		alternatives.append(other)
	if alternatives.is_empty():
		return enemy
	return alternatives[randi() % alternatives.size()]


func _confusion_redirect_chance() -> float:
	return 0.25


func preview_enemy_intent_damage(enemy, intent: Dictionary) -> int:
	if enemy == null or intent.is_empty():
		return 0
	if str(intent.get("action", "")) != "use_skill":
		return 0
	var skill := _find_enemy_skill(enemy, str(intent.get("skill", "")))
	if skill.is_empty():
		return maxi(0, int(intent.get("damage", 0)))
	var base_damage := maxi(0, int(skill.get("damage", intent.get("damage", 0))))
	if base_damage <= 0:
		return 0
	var source_damage := _preview_modified_outgoing_damage(enemy, base_damage)
	var target: Variant = enemy if str(skill.get("target", "single")) == "self" else player
	return _preview_incoming_damage(target, _damage_after_actor_defense_with_skill_options(target, source_damage, skill))


func _deal_raw_damage(target, amount: int, source = null) -> int:
	if target == null or amount <= 0:
		return 0
	var final_amount := _damage_after_actor_defense(target, _modified_outgoing_damage(source, amount))
	return _apply_incoming_damage(target, final_amount, source)


func _deal_enemy_skill_damage(target, amount: int, source = null, skill: Dictionary = {}) -> int:
	if target == null or amount <= 0:
		return 0
	var final_amount := _damage_after_actor_defense_with_skill_options(target, _modified_outgoing_damage(source, amount), skill)
	return _apply_incoming_damage(target, final_amount, source)


func _find_enemy_skill(enemy, skill_id: String) -> Dictionary:
	for skill in enemy.skills:
		if str(skill.get("id", "")) == skill_id:
			return skill
	return {}


func _first_living_enemy():
	for enemy in enemies:
		if enemy != null and not enemy.is_dead():
			return enemy
	return null


func _battle_should_resolve() -> bool:
	if player != null and player.has_method("is_dead") and player.is_dead():
		return true
	for enemy in enemies:
		if enemy != null and not enemy.is_dead():
			return false
	return true
