extends RefCounted

const BattleScenePath := "res://scenes/combat/battle_scene.tscn"
const CardScript = preload("res://scripts/combat/card.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

const SKILLS_DIR := "res://data/skills/"
const CARDS_DIR := "res://data/cards/"

var _passed := 0
var _failed := 0


func _case_fool_s9_spirit_vision() -> void:
	var card = _load_card("fool_s9_spirit_vision")
	var enemy = _make_enemy("hidden_dummy", 30, 0, 5)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, scene._player)
	_assert_card_used(scene, card.id)
	_assert_intent_revealed_by_card(scene, enemy.id, 1, card.id)
	_assert_intent_reveal_result(scene, card.id, "intent_reveal", 1, 1, [enemy.id])
	_assert_visible_text_contains(scene, card.get_display_name(), "spirit vision summary keeps source card name")
	_assert_visible_text_contains(scene, "揭示意图 1", "spirit vision shows readable intent reveal summary")
	_assert_visible_text_not_contains(scene, "intent_reveal", "spirit vision hides raw intent_reveal id")
	_assert_visible_text_not_contains(scene, "intent_revealed_by_card", "spirit vision hides raw reveal reason")
	await _teardown(scene)


func _case_fool_s9_star_chart_divination() -> void:
	var card = _load_card("fool_s9_star_chart_divination")
	var returned_before = _support_card("star_chart_returned_before", ["skill"])
	var filtered = _support_card("star_chart_filtered", ["skill"])
	var returned_after = _support_card("star_chart_returned_after", ["skill"])
	var untouched = _support_card("star_chart_untouched", ["skill"])
	var scene = await _start_scene([card])
	scene._battle.draw_pile = [returned_before, filtered, returned_after, untouched]
	await _play_direct(scene, card, scene._player)
	_assert_draw_filter_pending(scene, card.id, 3, [returned_before.id, filtered.id, returned_after.id])
	await _choose_draw_filter(scene, 1)
	_assert_card_used(scene, card.id)
	assert_true(_card_in_zone(scene._battle.hand, filtered.id), "star chart divination filters one top draw-pile card into hand")
	_assert_draw_filter_result(scene, filtered.id, 3, 1)
	_assert_zone_card_order(scene._battle.draw_pile, [returned_before.id, returned_after.id, untouched.id], "star chart returns unchosen cards to draw-pile top")
	_assert_visible_text_contains(scene, "抽牌筛选完成", "star chart shows a draw-filter completion summary")
	_assert_visible_text_contains(scene, card.get_display_name(), "star chart completion summary keeps the source card name")
	assert_true(card in scene._battle.discard_pile, "star chart card reaches discard after BattleScene play")
	await _teardown(scene)


func _case_fool_s9_pendulum_query() -> void:
	var card = _load_card("fool_s9_pendulum_query")
	var enemy = _make_enemy("query_target", 30, 0, 6)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	_assert_intent_revealed_by_card(scene, enemy.id, 1, card.id)
	_assert_intent_reveal_result(scene, card.id, "intent_reveal", 1, 1, [enemy.id])
	_assert_visible_text_contains(scene, card.get_display_name(), "pendulum query summary keeps source card name")
	_assert_visible_text_contains(scene, "揭示意图 1", "pendulum query shows readable intent reveal summary")
	_assert_visible_text_not_contains(scene, "intent_reveal", "pendulum query hides raw intent_reveal id")
	_assert_visible_text_not_contains(scene, "intent_revealed_by_card", "pendulum query hides raw reveal reason")
	await _teardown(scene)


func _case_fool_s9_ritual_chant() -> void:
	var card = _load_card("fool_s9_ritual_chant")
	var enemy_a = _make_enemy("ritual_a", 30)
	var enemy_b = _make_enemy("ritual_b", 30)
	var scene = await _start_scene([card], [enemy_a, enemy_b])
	await _play_direct(scene, card, scene._battle.enemies)
	_assert_card_used(scene, card.id)
	assert_eq(scene._battle.charged_zone.size(), 1, "ritual chant enters the independent charge zone")
	assert_true(not card in scene._battle.discard_pile, "ritual chant is not discarded while charging")
	assert_true(_charge_zone_text(scene).contains(card.get_display_name()), "ritual chant is visible in the BattleScene charge zone")
	scene._battle.end_player_turn()
	scene._battle.run_enemy_turn()
	scene._battle.end_player_turn()
	scene._battle.run_enemy_turn()
	assert_true(enemy_a.has_status("weak"), "ritual chant charge payload applies weak to enemy A")
	assert_true(enemy_a.has_status("vulnerable"), "ritual chant charge payload applies vulnerable to enemy A")
	assert_true(enemy_a.has_status("confusion"), "ritual chant charge payload applies confusion to enemy A")
	assert_true(enemy_b.has_status("weak"), "ritual chant charge payload applies weak to enemy B")
	assert_true(enemy_b.has_status("vulnerable"), "ritual chant charge payload applies vulnerable to enemy B")
	assert_true(enemy_b.has_status("confusion"), "ritual chant charge payload applies confusion to enemy B")
	await _teardown(scene)


func _case_fool_s9_arcane_lore() -> void:
	var card = _load_card("fool_s9_arcane_lore")
	var returned_before = _support_card("arcane_lore_returned_before", ["skill"])
	var returned_middle = _support_card("arcane_lore_returned_middle", ["skill"])
	var filtered = _support_card("arcane_lore_filtered", ["skill"])
	var untouched = _support_card("arcane_lore_untouched", ["skill"])
	var scene = await _start_scene([card])
	scene._battle.draw_pile = [returned_before, returned_middle, filtered, untouched]
	await _play_direct(scene, card, scene._player)
	_assert_draw_filter_pending(scene, card.id, 3, [returned_before.id, returned_middle.id, filtered.id])
	await _choose_draw_filter(scene, 2)
	_assert_card_used(scene, card.id)
	assert_true(_card_in_zone(scene._battle.hand, filtered.id), "arcane lore filters one top draw-pile card into hand")
	_assert_draw_filter_result(scene, filtered.id, 3, 1)
	_assert_zone_card_order(scene._battle.draw_pile, [returned_before.id, returned_middle.id, untouched.id], "arcane lore returns unchosen cards to draw-pile top")
	_assert_visible_text_contains(scene, "抽牌筛选完成", "arcane lore shows a draw-filter completion summary")
	_assert_visible_text_contains(scene, card.get_display_name(), "arcane lore completion summary keeps the source card name")
	assert_true(card in scene._battle.discard_pile, "arcane lore can be played through BattleScene")
	await _teardown(scene)


func _case_fool_s9_premonition() -> void:
	var card = _load_card("fool_s9_premonition")
	var player = _make_player(30)
	var enemy = _make_enemy("premonition_attacker", 30, 0, 10)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, scene._player)
	_assert_card_used(scene, card.id)
	assert_true(scene._player.has_status("damage_reduction"), "premonition applies damage_reduction to the player")
	_assert_damage_reduction_status_result(scene, card.id, "player", 1, 0.5)
	_assert_visible_text_contains(scene, card.get_display_name(), "premonition summary keeps source card name")
	_assert_visible_text_contains(scene, "减伤", "premonition shows readable damage-reduction summary")
	_assert_status_detail_contains(scene, "减伤 1", "premonition status detail shows duration")
	_assert_status_detail_contains(scene, "0.5", "premonition status detail shows reduction magnitude")
	_assert_visible_text_not_contains(scene, "damage_reduction", "premonition hides raw damage_reduction id")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 5, "premonition previews the next 10 damage hit as 5")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 25, "premonition halves the next incoming enemy hit")
	assert_true(not player.has_status("damage_reduction"), "premonition consumes damage_reduction after the next incoming hit")
	_assert_damage_reduction_trigger_result(scene, "player", enemy.id, 10, 5, 0.5)
	_assert_visible_text_contains(scene, "减伤 5", "premonition enemy-turn summary shows reduced damage")
	_assert_status_detail_not_contains(scene, "减伤", "premonition status detail clears consumed damage reduction")
	await _teardown(scene)


func _case_fool_s8_acrobat_strike() -> void:
	var card = _load_card("fool_s8_acrobat_strike")
	var enemy = _make_enemy("acrobat_target", 40)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 28, "acrobat strike resolves three 4-damage hits")
	_assert_multi_strike_result(scene, 3, 4)
	assert_true(not enemy.has_status("vulnerable"), "acrobat strike does not apply vulnerable without a prior skill this turn")
	_assert_acrobat_condition_not_met(scene)
	_assert_visible_text_contains(scene, card.get_display_name(), "acrobat strike summary keeps source card name")
	_assert_visible_text_contains(scene, "多段 3×4", "acrobat strike shows readable multi-strike summary")
	_assert_visible_text_not_contains(scene, "multi_strike", "acrobat strike hides raw multi_strike id")
	_assert_visible_text_not_contains(scene, "vulnerable_if_skill_played", "acrobat strike hides raw vulnerable_if_skill_played id")
	await _teardown(scene)

	var skill_setup = _support_skill_card("acrobat_prior_skill", "fool", 0)
	var combo_card = _load_card("fool_s8_acrobat_strike")
	var combo_enemy = _make_enemy("acrobat_combo_target", 40)
	var combo_scene = await _start_scene([skill_setup, combo_card], [combo_enemy])
	await _play_direct(combo_scene, skill_setup, combo_scene._player)
	_assert_card_used(combo_scene, skill_setup.id)
	await _play_direct(combo_scene, combo_card, combo_enemy)
	_assert_card_used(combo_scene, combo_card.id)
	assert_eq(combo_enemy.hp, 28, "acrobat strike combo still deals three 4-damage hits")
	_assert_multi_strike_result(combo_scene, 3, 4)
	_assert_acrobat_vulnerable_result(combo_scene, combo_card.id, combo_enemy.id, 1)
	_assert_status_duration(combo_enemy, "vulnerable", 1, "acrobat strike applies vulnerable after a prior skill this turn")
	_assert_status_detail_contains(combo_scene, "易伤 1", "acrobat strike status detail shows vulnerable duration")
	_assert_visible_text_contains(combo_scene, "附加 易伤", "acrobat strike summary shows readable vulnerable feedback")
	_assert_visible_text_not_contains(combo_scene, "vulnerable_if_skill_played", "acrobat strike combo hides raw conditional id")
	_assert_visible_text_not_contains(combo_scene, "multi_strike", "acrobat strike combo hides raw multi_strike id")
	await _teardown(combo_scene)

	var next_turn_skill = _support_skill_card("acrobat_previous_turn_skill", "fool", 0)
	var next_turn_card = _load_card("fool_s8_acrobat_strike")
	var next_turn_enemy = _make_enemy("acrobat_next_turn_target", 40)
	var next_turn_scene = await _start_scene([next_turn_skill, next_turn_card], [next_turn_enemy])
	await _play_direct(next_turn_scene, next_turn_skill, next_turn_scene._player)
	_assert_card_used(next_turn_scene, next_turn_skill.id)
	next_turn_scene._battle.end_player_turn()
	next_turn_scene._battle.run_enemy_turn()
	await Engine.get_main_loop().process_frame
	await _return_card_to_hand_for_replay(next_turn_scene, next_turn_card)
	await _play_direct(next_turn_scene, next_turn_card, next_turn_enemy)
	assert_eq(next_turn_enemy.hp, 28, "acrobat strike next turn still deals three 4-damage hits")
	assert_true(not next_turn_enemy.has_status("vulnerable"), "acrobat strike prior-skill condition resets on the next player turn")
	_assert_acrobat_condition_not_met(next_turn_scene)
	await _teardown(next_turn_scene)


func _case_fool_s8_paper_blade_volley() -> void:
	var card = _load_card("fool_s8_paper_blade_volley")
	var enemy_a = _make_enemy("blade_a", 80)
	var enemy_b = _make_enemy("blade_b", 80)
	var enemy_c = _make_enemy("blade_c", 80)
	var targets := [enemy_a, enemy_b, enemy_c]
	var scene = await _start_scene([card], targets)
	await _play_via_target_selection(scene, card, [enemy_a])
	_assert_card_used(scene, card.id)
	_assert_target_selection_result(scene, 1, 1, 3)
	assert_eq(enemy_a.hp, 75, "paper blade first play deals base 5 to selected target A")
	assert_eq(enemy_b.hp, 80, "paper blade first play leaves unselected target B untouched")
	assert_eq(enemy_c.hp, 80, "paper blade first play leaves unselected target C untouched")
	_assert_per_use_growth_result(scene, 1, 3)
	_assert_visible_text_contains(scene, card.get_display_name(), "paper blade summary keeps the source card name")
	_assert_visible_text_contains(scene, "blade_a", "paper blade summary includes selected target A")
	_assert_visible_text_contains(scene, "5", "paper blade summary includes first-play damage")
	await _return_card_to_hand_for_replay(scene, card)
	await _play_via_target_selection(scene, card, [enemy_b, enemy_c])
	_assert_target_selection_result(scene, 2, 1, 3)
	assert_eq(enemy_a.hp, 75, "paper blade two-target play leaves unselected target A untouched")
	assert_eq(enemy_b.hp, 76, "paper blade second play applies +1 growth then 2-target attenuation to target B")
	assert_eq(enemy_c.hp, 76, "paper blade second play applies +1 growth then 2-target attenuation to target C")
	_assert_visible_text_contains(scene, "4", "paper blade summary includes attenuated two-target damage")
	await _return_card_to_hand_for_replay(scene, card)
	await _play_via_target_selection(scene, card, targets)
	_assert_target_selection_result(scene, 3, 1, 3)
	assert_eq(enemy_a.hp, 72, "paper blade third play applies +2 growth then 3-target attenuation to target A")
	assert_eq(enemy_b.hp, 73, "paper blade third play applies +2 growth then 3-target attenuation to target B")
	assert_eq(enemy_c.hp, 73, "paper blade third play applies +2 growth then 3-target attenuation to target C")
	await _return_card_to_hand_for_replay(scene, card)
	await _play_via_target_selection(scene, card, [enemy_a])
	assert_eq(enemy_a.hp, 64, "paper blade fourth play reaches +3 growth cap")
	await _return_card_to_hand_for_replay(scene, card)
	await _play_via_target_selection(scene, card, [enemy_a])
	assert_eq(enemy_a.hp, 56, "paper blade fifth play stays capped at +3 growth")
	assert_eq(card.play_count, 5, "paper blade real card records each BattleScene play")
	await _teardown(scene)


func _case_fool_s8_microexpression_read() -> void:
	var card = _load_card("fool_s8_microexpression_read")
	var enemy_a = _make_enemy("micro_a", 30, 0, 4)
	var enemy_b = _make_enemy("micro_b", 30, 0, 7)
	var scene = await _start_scene([card], [enemy_a, enemy_b])
	await _play_direct(scene, card, [enemy_a, enemy_b])
	_assert_card_used(scene, card.id)
	_assert_intent_revealed_by_card(scene, enemy_a.id, 2, card.id)
	_assert_intent_revealed_by_card(scene, enemy_b.id, 2, card.id)
	_assert_intent_reveal_result(scene, card.id, "mind_read", 2, 2, [enemy_a.id, enemy_b.id])
	_assert_visible_text_contains(scene, card.get_display_name(), "microexpression read summary keeps source card name")
	_assert_visible_text_contains(scene, "读心揭示 2", "microexpression read shows readable mind-read summary")
	_assert_visible_text_not_contains(scene, "mind_read", "microexpression read hides raw mind_read id")
	_assert_visible_text_not_contains(scene, "intent_reveal", "microexpression read hides raw intent_reveal id")
	_assert_visible_text_not_contains(scene, "intent_revealed_by_card", "microexpression read hides raw reveal reason")
	await _teardown(scene)


func _case_fool_s8_predator_instinct() -> void:
	var card = _load_card("fool_s8_predator_instinct")
	var player = _make_player(30)
	var enemy = _make_enemy("predator_attacker", 30, 0, 10)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, scene._player)
	_assert_card_used(scene, card.id)
	assert_true(scene._player.has_status("dodge_counter"), "predator instinct applies dodge_counter to the player")
	_assert_dodge_counter_status_result(scene, 3, 1)
	_assert_visible_text_contains(scene, card.get_display_name(), "predator instinct summary keeps source card name")
	_assert_visible_text_contains(scene, "闪避反击", "predator instinct shows readable dodge counter summary")
	_assert_status_detail_contains(scene, "闪避反击 1 强度 3", "predator instinct status detail shows duration and magnitude")
	_assert_visible_text_not_contains(scene, "dodge_counter", "predator instinct hides raw status id")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 0, "predator instinct reveals the next hit as dodged")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 30, "predator instinct dodges the next enemy hit")
	assert_eq(enemy.hp, 27, "predator instinct counter hits the attacker for 3")
	assert_true(not player.has_status("dodge_counter"), "predator instinct consumes dodge_counter after the next incoming hit")
	var trigger_result := _find_effect_result_by_reason_id(scene, "dodge_counter_triggered", "dodge_counter")
	assert_true(not trigger_result.is_empty(), "predator instinct records dodge_counter trigger result")
	if not trigger_result.is_empty():
		assert_eq(int(trigger_result.get("damage", 0)), 3, "predator instinct trigger result counter damage")
		assert_eq(str(trigger_result.get("target_id", "")), "player", "predator instinct trigger result protected target")
		assert_eq(str(trigger_result.get("source_id", "")), str(enemy.get("id")), "predator instinct trigger result source attacker")
	_assert_visible_text_contains(scene, "闪避反击 3", "predator instinct enemy-turn summary explains the counter damage")
	_assert_status_detail_not_contains(scene, "闪避反击", "predator instinct status detail clears consumed dodge counter")
	await _teardown(scene)


func _case_fool_s8_strongman_burst() -> void:
	var card = _load_card("fool_s8_strongman_burst")
	var enemy = _make_enemy("strongman_target", 30, 5)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.def, 2, "strongman burst shreds three defense before damage")
	assert_eq(enemy.hp, 21, "strongman burst keeps its own damage after shredding defense")
	_assert_effect_result_by_reason_id(scene, "defense_shredded", "block_break", 3)
	_assert_visible_text_contains(scene, "破防 3", "strongman burst shows concrete block_break summary")
	await _teardown(scene)


func _case_p0_defense_modifier_cards() -> void:
	await _assert_fixed_pierce_card_visible("arrow_water", 2, 24)
	await _assert_fixed_pierce_card_visible("inquiry_arrow", 2, 24)
	await _assert_fixed_ignore_guard_card_visible("priestess_s8_door_step", 2, 25)
	await _assert_space_fold_visible()
	await _assert_block_break_card_visible("chariot_s8_reef_breaker")


func _case_p0_chariot_storm_pulse() -> void:
	var card = _load_card("chariot_s8_storm_pulse")
	var player = _make_player(30)
	var enemy_a = _make_enemy("storm_pulse_a", 30, 0, 6)
	var enemy_b = _make_enemy("storm_pulse_b", 30, 0, 8)
	var scene = await _start_scene([card], [enemy_a, enemy_b], player)
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_eq(enemy_a.hp, 23, "storm pulse damages every enemy A")
	assert_eq(enemy_b.hp, 23, "storm pulse damages every enemy B")
	assert_true(enemy_a.has_status("displace"), "storm pulse applies displace to enemy A")
	assert_true(enemy_b.has_status("displace"), "storm pulse applies displace to enemy B")
	_assert_visible_text_contains(scene, card.get_display_name(), "storm pulse summary keeps source card name")
	_assert_visible_text_contains(scene, "错位", "storm pulse shows readable displace summary")
	_assert_status_detail_contains(scene, "错位 1 强度 1", "storm pulse status detail shows duration and magnitude")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 30, "storm pulse displace blocks each enemy action once")
	assert_true(not enemy_a.has_status("displace"), "storm pulse displace expires on enemy A after blocked action")
	assert_true(not enemy_b.has_status("displace"), "storm pulse displace expires on enemy B after blocked action")
	_assert_status_detail_not_contains(scene, "错位", "storm pulse status detail clears expired displace")
	await _teardown(scene)


func _case_chariot_s9_sailor_shout() -> void:
	var card = _load_card("chariot_s9_sailor_shout")
	if card == null:
		return
	assert_eq(card.pathway, "chariot", "sailor shout loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "sailor shout sequence")
	assert_eq(card.energy_cost, 1, "sailor shout cost comes from mp_cost")
	assert_eq(card.range, 3, "sailor shout range")
	assert_eq(card.damage, 4, "sailor shout base damage")
	assert_eq(card.target, "all_enemies", "sailor shout target mode is all_enemies")
	assert_eq(card.status_effects.size(), 1, "sailor shout has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "weak", "sailor shout applies weak")
	assert_eq(int(effect.get("duration", 0)), 1, "sailor shout weak duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("4"), "sailor shout card summary includes damage amount")
	assert_true(not summary_text.contains("weak"), "sailor shout card summary hides raw weak id")

	var player = _make_player(50)
	var enemy_a = _make_enemy("sailor_shout_a", 40, 0, 10)
	var enemy_b = _make_enemy("sailor_shout_b", 40, 2, 10)
	var enemy_c = _make_enemy("sailor_shout_c", 40, 20, 10)
	var enemies := [enemy_a, enemy_b, enemy_c]
	var scene = await _start_scene([card], enemies, player, _game_state(9))
	var weak_label := _status_label_from_scene(scene, "weak")
	assert_true(summary_text.contains(weak_label), "sailor shout card summary uses the same readable weak label as BattleScene")
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_eq(enemy_a.hp, 36, "sailor shout deals 4 damage to the zero-defense enemy")
	assert_eq(enemy_b.hp, 38, "sailor shout damage is reduced by normal defense")
	assert_eq(enemy_c.hp, 39, "sailor shout still deals minimum 1 damage to a high-defense enemy")
	for enemy in enemies:
		_assert_status_duration(enemy, "weak", 1, "sailor shout applies weak duration 1 to %s" % enemy.id)
	var enemy_ids := _actor_ids_from(enemies)
	_assert_status_applied_results_for_targets(scene, "weak", enemy_ids, 1, card.id)
	var weak_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "weak"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "sailor shout summary keeps source card name")
	_assert_last_action_message_contains(scene, "4", "sailor shout summary shows source damage amount")
	_assert_last_action_message_contains(scene, weak_result_text, "sailor shout summary shows readable weak feedback")
	for enemy in enemies:
		_assert_status_detail_contains(scene, enemy.id, "sailor shout status detail lists %s" % enemy.id)
	_assert_status_detail_contains(scene, "%s 1" % weak_label, "sailor shout status detail shows weak duration")
	_assert_visible_text_not_contains(scene, "weak", "sailor shout hides raw weak id")
	_assert_visible_text_not_contains(scene, "status_applied", "sailor shout hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "sailor shout hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "sailor shout hides raw dictionary braces")
	for enemy in enemies:
		var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
		assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 7, "sailor shout weak previews %s next 10 damage hit as 7" % enemy.id)
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 29, "sailor shout weak reduces three enemy 10 damage hits to 7 each")
	for enemy in enemies:
		assert_true(not enemy.has_status("weak"), "sailor shout weak expires after %s acts" % enemy.id)
	_assert_status_detail_not_contains(scene, weak_label, "sailor shout status detail clears expired weak")
	await _teardown(scene)


func _case_chariot_s9_tide_cut() -> void:
	var card = _load_card("chariot_s9_tide_cut")
	if card == null:
		return
	assert_eq(card.pathway, "chariot", "tide cut loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "tide cut sequence")
	assert_eq(card.energy_cost, 1, "tide cut cost comes from mp_cost")
	assert_eq(card.range, 2, "tide cut range")
	assert_eq(card.damage, 8, "tide cut base damage")
	assert_eq(card.target, "single", "tide cut target mode is single")
	assert_eq(card.status_effects.size(), 0, "tide cut has no status payload")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("8"), "tide cut card summary includes base damage")
	assert_true(not summary_text.contains("single"), "tide cut card summary hides raw single target id")

	var target = _make_enemy("tide_cut_target", 40, 3, 0)
	var untouched = _make_enemy("tide_cut_untouched", 40, 0, 0)
	var scene = await _start_scene([card], [target, untouched], null, _game_state(9))
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 35, "tide cut deals 8 damage reduced by 3 defense")
	assert_eq(untouched.hp, 40, "tide cut leaves non-target enemies untouched")
	assert_eq(target.def, 3, "tide cut does not shred defense")
	_assert_last_action_message_contains(scene, card.get_display_name(), "tide cut summary keeps source card name")
	_assert_last_action_message_contains(scene, target.id, "tide cut summary names the damaged target")
	_assert_last_action_message_contains(scene, "5", "tide cut summary shows actual defense-adjusted damage")
	_assert_visible_text_not_contains(scene, "single", "tide cut hides raw single target id")
	_assert_visible_text_not_contains(scene, "{", "tide cut hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "tide cut hides raw dictionary braces")
	await _teardown(scene)

	var high_def_card = _load_card("chariot_s9_tide_cut")
	var high_def_target = _make_enemy("tide_cut_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], null, _game_state(9))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "tide cut high-defense target still takes minimum 1 damage")
	assert_eq(high_def_target.def, 20, "tide cut high-defense branch does not mutate defense")
	await _teardown(high_def_scene)


func _case_death_s9_bone_splinter() -> void:
	var card = _load_card("death_s9_bone_splinter")
	if card == null:
		return
	assert_eq(card.pathway, "death", "bone splinter loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "bone splinter sequence")
	assert_eq(card.energy_cost, 1, "bone splinter cost comes from mp_cost")
	assert_eq(card.range, 5, "bone splinter range")
	assert_eq(card.damage, 8, "bone splinter base damage")
	assert_eq(card.target, "single", "bone splinter target mode is single")
	assert_eq(card.status_effects.size(), 0, "bone splinter has no status payload")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("8"), "bone splinter card summary includes base damage")
	assert_true(not summary_text.contains("single"), "bone splinter card summary hides raw single target id")

	var target = _make_enemy("bone_splinter_target", 40, 2, 0)
	var untouched = _make_enemy("bone_splinter_untouched", 40, 0, 0)
	var scene = await _start_scene([card], [target, untouched], null, _game_state(9))
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 34, "bone splinter deals 8 damage reduced by 2 defense")
	assert_eq(untouched.hp, 40, "bone splinter leaves non-target enemies untouched")
	assert_eq(target.def, 2, "bone splinter does not shred defense")
	_assert_last_action_message_contains(scene, card.get_display_name(), "bone splinter summary keeps source card name")
	_assert_last_action_message_contains(scene, target.id, "bone splinter summary names the damaged target")
	_assert_last_action_message_contains(scene, "6", "bone splinter summary shows actual defense-adjusted damage")
	_assert_visible_text_not_contains(scene, "single", "bone splinter hides raw single target id")
	_assert_visible_text_not_contains(scene, "{", "bone splinter hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "bone splinter hides raw dictionary braces")
	await _teardown(scene)

	var high_def_card = _load_card("death_s9_bone_splinter")
	var high_def_target = _make_enemy("bone_splinter_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], null, _game_state(9))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "bone splinter high-defense target still takes minimum 1 damage")
	assert_eq(high_def_target.def, 20, "bone splinter high-defense branch does not mutate defense")
	await _teardown(high_def_scene)


func _case_death_s9_grave_chill() -> void:
	var card = _load_card("death_s9_grave_chill")
	if card == null:
		return
	assert_eq(card.pathway, "death", "grave chill loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "grave chill sequence")
	assert_eq(card.energy_cost, 1, "grave chill cost comes from mp_cost")
	assert_eq(card.range, 4, "grave chill range")
	assert_eq(card.damage, 6, "grave chill base damage")
	assert_eq(card.target, "single", "grave chill target mode is single")
	assert_eq(card.status_effects.size(), 1, "grave chill has one chill payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "chill", "grave chill applies chill")
	assert_eq(int(effect.get("duration", 0)), 1, "grave chill chill duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("6"), "grave chill card summary includes base damage")
	assert_true(not summary_text.contains("chill"), "grave chill card summary hides raw chill id")

	var player = _make_player(50)
	var target = _make_enemy("grave_cold_target", 40, 2, 10)
	var untouched = _make_enemy("grave_cold_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(9))
	var chill_label := _status_label_from_scene(scene, "chill")
	assert_true(summary_text.contains(chill_label), "grave chill card summary uses the same readable chill label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 36, "grave chill deals 6 damage reduced by target defense")
	assert_eq(target.def, 2, "grave chill does not mutate target defense")
	assert_eq(untouched.hp, 40, "grave chill leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "chill", card.id, target.id, 1, 0)
	_assert_status_duration(target, "chill", 1, "grave chill applies chill duration 1")
	assert_true(not untouched.has_status("chill"), "grave chill does not chill the untargeted enemy")
	var chill_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "chill"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "grave chill summary keeps source card name")
	_assert_last_action_message_contains(scene, chill_result_text, "grave chill summary shows readable chill feedback")
	_assert_status_detail_contains(scene, target.id, "grave chill status detail lists the chilled target")
	_assert_status_detail_contains(scene, "%s 1" % chill_label, "grave chill status detail shows chill duration")
	_assert_visible_text_not_contains(scene, "chill", "grave chill hides raw chill id")
	_assert_visible_text_not_contains(scene, "status_applied", "grave chill hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "grave chill hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "grave chill hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "grave chill blocks only the chilled enemy action")
	assert_true(not target.has_status("chill"), "grave chill chill expires after the chilled enemy skips action")
	_assert_status_detail_not_contains(scene, chill_label, "grave chill status detail clears expired chill")
	await _teardown(scene)

	var high_def_card = _load_card("death_s9_grave_chill")
	var high_def_target = _make_enemy("grave_cold_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(9))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "grave chill still deals minimum 1 damage to a high-defense target")
	assert_eq(high_def_target.def, 20, "grave chill does not mutate high-defense target defense")
	_assert_status_duration(high_def_target, "chill", 1, "grave chill chills a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_death_s8_mourning_touch() -> void:
	var card = _load_card("death_s8_mourning_touch")
	if card == null:
		return
	assert_eq(card.pathway, "death", "mourning touch loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "mourning touch sequence")
	assert_eq(card.energy_cost, 1, "mourning touch cost comes from mp_cost")
	assert_eq(card.range, 1, "mourning touch range")
	assert_eq(card.damage, 9, "mourning touch base damage")
	assert_eq(card.target, "single", "mourning touch target mode is single")
	assert_eq(card.status_effects.size(), 1, "mourning touch has one weak payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "weak", "mourning touch applies weak")
	assert_eq(int(effect.get("duration", 0)), 2, "mourning touch weak duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("9"), "mourning touch card summary includes base damage")
	assert_true(not summary_text.contains("weak"), "mourning touch card summary hides raw weak id")

	var player = _make_player(50)
	var target = _make_enemy("mourning_touch_target", 40, 3, 10)
	var untouched = _make_enemy("mourning_touch_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(8))
	var weak_label := _status_label_from_scene(scene, "weak")
	assert_true(summary_text.contains(weak_label), "mourning touch card summary uses the same readable weak label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 34, "mourning touch deals 9 damage reduced by target defense")
	assert_eq(target.def, 3, "mourning touch does not mutate target defense")
	assert_eq(untouched.hp, 40, "mourning touch leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "weak", card.id, target.id, 2, 0)
	_assert_status_duration(target, "weak", 2, "mourning touch applies weak duration 2")
	assert_true(not untouched.has_status("weak"), "mourning touch does not weaken the untargeted enemy")
	var weak_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "weak"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "mourning touch summary keeps source card name")
	_assert_last_action_message_contains(scene, weak_result_text, "mourning touch summary shows readable weak feedback")
	_assert_status_detail_contains(scene, target.id, "mourning touch status detail lists the weakened target")
	_assert_status_detail_contains(scene, "%s 2" % weak_label, "mourning touch status detail shows weak duration")
	_assert_visible_text_not_contains(scene, "weak", "mourning touch hides raw weak id")
	_assert_visible_text_not_contains(scene, "status_applied", "mourning touch hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "mourning touch hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "mourning touch hides raw dictionary braces")
	var target_intent: Dictionary = scene._battle.current_enemy_intents.get(target.id, {})
	var untouched_intent: Dictionary = scene._battle.current_enemy_intents.get(untouched.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(target, target_intent), 7, "mourning touch weak previews the target's next 10 damage hit as 7")
	assert_eq(scene._battle.preview_enemy_intent_damage(untouched, untouched_intent), 10, "mourning touch does not weaken the untargeted enemy intent")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 33, "mourning touch weak reduces only the target enemy's next 10 damage hit to 7")
	_assert_status_duration(target, "weak", 1, "mourning touch weak ticks down after the weakened target acts")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_true(not target.has_status("weak"), "mourning touch weak expires after the second target action")
	_assert_status_detail_not_contains(scene, weak_label, "mourning touch status detail clears expired weak")
	await _teardown(scene)

	var high_def_card = _load_card("death_s8_mourning_touch")
	var high_def_target = _make_enemy("mourning_touch_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(8))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "mourning touch still deals minimum 1 damage to a high-defense target")
	assert_eq(high_def_target.def, 20, "mourning touch does not mutate high-defense target defense")
	_assert_status_duration(high_def_target, "weak", 2, "mourning touch weakens a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_death_s8_wither_breath() -> void:
	var card = _load_card("death_s8_wither_breath")
	if card == null:
		return
	assert_eq(card.pathway, "death", "wither breath loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "wither breath sequence")
	assert_eq(card.energy_cost, 1, "wither breath cost comes from mp_cost")
	assert_eq(card.range, 3, "wither breath range")
	assert_eq(card.damage, 7, "wither breath base damage")
	assert_eq(card.target, "all_enemies", "wither breath target mode is all_enemies")
	assert_eq(card.status_effects.size(), 1, "wither breath has one poison payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "poison", "wither breath applies poison")
	assert_eq(int(effect.get("duration", 0)), 2, "wither breath poison duration")
	assert_eq(int(effect.get("magnitude", 0)), 2, "wither breath poison magnitude")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("7"), "wither breath card summary includes base damage")
	assert_true(not summary_text.contains("poison"), "wither breath card summary hides raw poison id")

	var player = _make_player(80)
	var enemy_a = _make_enemy("wither_breath_a", 40, 0, 10)
	var enemy_b = _make_enemy("wither_breath_b", 40, 3, 10)
	var enemy_c = _make_enemy("wither_breath_c", 40, 20, 10)
	var enemies := [enemy_a, enemy_b, enemy_c]
	var scene = await _start_scene([card], enemies, player, _game_state(8))
	var poison_label := _status_label_from_scene(scene, "poison")
	assert_true(summary_text.contains(poison_label), "wither breath card summary uses the same readable poison label as BattleScene")
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_eq(enemy_a.hp, 33, "wither breath deals 7 damage to the zero-defense enemy")
	assert_eq(enemy_b.hp, 36, "wither breath damage is reduced by normal defense")
	assert_eq(enemy_c.hp, 39, "wither breath still deals minimum 1 damage to a high-defense enemy")
	assert_eq(enemy_c.def, 20, "wither breath does not mutate high-defense enemy defense")
	for enemy in enemies:
		_assert_status_duration(enemy, "poison", 2, "wither breath applies poison duration 2 to %s" % enemy.id)
		assert_eq(int(enemy.statuses.get("poison", {}).get("magnitude", 0)), 2, "wither breath poison status stores magnitude 2 on %s" % enemy.id)
	var enemy_ids := _actor_ids_from(enemies)
	_assert_status_applied_results_for_targets(scene, "poison", enemy_ids, 2, card.id)
	var poison_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "poison"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "wither breath summary keeps source card name")
	_assert_last_action_message_contains(scene, "7", "wither breath summary shows source damage amount")
	_assert_last_action_message_contains(scene, poison_result_text, "wither breath summary shows readable poison feedback")
	for enemy in enemies:
		_assert_status_detail_contains(scene, enemy.id, "wither breath status detail lists %s" % enemy.id)
	_assert_status_detail_contains(scene, "%s 2" % poison_label, "wither breath status detail shows poison duration")
	_assert_status_detail_contains(scene, "2", "wither breath status detail shows poison magnitude")
	_assert_visible_text_not_contains(scene, "poison", "wither breath hides raw poison id")
	_assert_visible_text_not_contains(scene, "status_applied", "wither breath hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "wither breath hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "wither breath hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 50, "wither breath poison does not block three enemy 10 damage hits")
	assert_eq(enemy_a.hp, 31, "wither breath poison deals 2 DOT to zero-defense enemy before action")
	assert_eq(enemy_b.hp, 34, "wither breath poison deals 2 DOT to normal-defense enemy before action")
	assert_eq(enemy_c.hp, 37, "wither breath poison deals 2 DOT to high-defense enemy before action")
	for enemy in enemies:
		_assert_status_duration(enemy, "poison", 1, "wither breath poison ticks down after %s acts" % enemy.id)
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 20, "wither breath poison still does not block the second enemy action round")
	assert_eq(enemy_a.hp, 29, "wither breath poison deals second DOT to zero-defense enemy")
	assert_eq(enemy_b.hp, 32, "wither breath poison deals second DOT to normal-defense enemy")
	assert_eq(enemy_c.hp, 35, "wither breath poison deals second DOT to high-defense enemy")
	for enemy in enemies:
		assert_true(not enemy.has_status("poison"), "wither breath poison expires after %s second action" % enemy.id)
	_assert_status_detail_not_contains(scene, poison_label, "wither breath status detail clears expired poison")
	await _teardown(scene)


func _case_death_s7_reaper_hook() -> void:
	var card = _load_card("death_s7_reaper_hook")
	if card == null:
		return
	assert_eq(card.pathway, "death", "reaper hook loads from the runtime skill catalog")
	assert_eq(card.sequence, 7, "reaper hook sequence")
	assert_eq(card.energy_cost, 2, "reaper hook cost comes from mp_cost")
	assert_eq(card.range, 4, "reaper hook range")
	assert_eq(card.damage, 15, "reaper hook base damage")
	assert_eq(card.target, "single", "reaper hook target mode is single")
	assert_eq(card.status_effects.size(), 1, "reaper hook has one execute payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "execute_bonus_below_hp_pct", "reaper hook uses low-HP execute bonus")
	assert_true(absf(float(effect.get("threshold", 0.0)) - 0.3) < 0.001, "reaper hook execute threshold is 30 percent")
	assert_eq(int(effect.get("bonus_damage", 0)), 8, "reaper hook execute bonus damage")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("15"), "reaper hook card summary includes base damage")
	assert_true(summary_text.contains("8"), "reaper hook card summary includes execute bonus damage")
	assert_true(not summary_text.contains("execute_bonus_below_hp_pct"), "reaper hook card summary hides raw execute id")
	assert_true(not summary_text.contains("threshold"), "reaper hook card summary hides raw threshold key")
	assert_true(not summary_text.contains("bonus_damage"), "reaper hook card summary hides raw bonus_damage key")

	var target = _make_enemy("reaper_hook_target", 40, 3, 10)
	var untouched = _make_enemy("reaper_hook_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], _make_player(50), _game_state(7))
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 28, "reaper hook deals 15 damage reduced by 3 defense when target is above execute threshold")
	assert_eq(target.def, 3, "reaper hook does not mutate normal target defense")
	assert_eq(untouched.hp, 40, "reaper hook leaves the untargeted enemy untouched")
	assert_true(target.statuses.is_empty(), "reaper hook does not leave a persistent status on the normal target")
	_assert_execute_condition_not_met_result(scene, card.id, target.id, 0.3, 1.0)
	_assert_visible_text_contains(scene, card.get_display_name(), "reaper hook summary keeps source card name")
	_assert_visible_text_not_contains(scene, "execute_bonus_below_hp_pct", "reaper hook hides raw execute id")
	_assert_visible_text_not_contains(scene, "status_applied", "reaper hook does not show status_applied for execute")
	_assert_visible_text_not_contains(scene, "{", "reaper hook hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "reaper hook hides raw dictionary braces")
	await _teardown(scene)

	var boundary_card = _load_card("death_s7_reaper_hook")
	var boundary_target = _make_enemy("reaper_hook_boundary_above", 40, 3, 0)
	boundary_target.hp = 13
	var boundary_scene = await _start_scene([boundary_card], [boundary_target], _make_player(50), _game_state(7))
	await _play_direct(boundary_scene, boundary_card, boundary_target)
	_assert_card_used(boundary_scene, boundary_card.id)
	assert_eq(boundary_target.hp, 1, "reaper hook does not execute a 13/40 target above the 30 percent threshold")
	_assert_execute_condition_not_met_result(boundary_scene, boundary_card.id, boundary_target.id, 0.3, 0.325)
	await _teardown(boundary_scene)

	var execute_card = _load_card("death_s7_reaper_hook")
	var execute_target = _make_enemy("reaper_hook_execute_target", 40, 3, 0)
	execute_target.hp = 12
	var execute_scene = await _start_scene([execute_card], [execute_target], _make_player(50), _game_state(7))
	await _play_direct(execute_scene, execute_card, execute_target)
	_assert_card_used(execute_scene, execute_card.id)
	assert_eq(execute_target.hp, 0, "reaper hook adds 8 damage before defense against a 12/40 target at the threshold")
	_assert_execute_bonus_result(execute_scene, execute_card.id, execute_target.id, 8, 0.3, 0.3)
	var execute_result_text := _effect_result_text_from_scene(execute_scene, {"reason": "damage_modifier", "id": "execute_bonus_below_hp_pct", "bonus_damage": 8, "magnitude": 8})
	assert_true(execute_result_text.contains("8"), "reaper hook execute feedback names the bonus damage")
	_assert_last_action_message_contains(execute_scene, execute_result_text, "reaper hook summary shows readable execute feedback")
	_assert_visible_text_not_contains(execute_scene, "execute_bonus_below_hp_pct", "reaper hook execute summary hides raw execute id")
	_assert_visible_text_not_contains(execute_scene, "{", "reaper hook execute summary hides raw dictionary braces")
	_assert_visible_text_not_contains(execute_scene, "}", "reaper hook execute summary hides raw dictionary braces")
	await _teardown(execute_scene)

	var high_def_card = _load_card("death_s7_reaper_hook")
	var high_def_target = _make_enemy("reaper_hook_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(7))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "reaper hook still deals minimum 1 damage to a high-defense target above execute threshold")
	assert_eq(high_def_target.def, 20, "reaper hook does not mutate high-defense target defense")
	_assert_execute_condition_not_met_result(high_def_scene, high_def_card.id, high_def_target.id, 0.3, 1.0)
	await _teardown(high_def_scene)


func _case_chariot_s7_thunder_boarding() -> void:
	var card = _load_card("chariot_s7_thunder_boarding")
	if card == null:
		return
	assert_eq(card.pathway, "chariot", "thunder boarding loads from the runtime skill catalog")
	assert_eq(card.sequence, 7, "thunder boarding sequence")
	assert_eq(card.energy_cost, 2, "thunder boarding cost comes from mp_cost")
	assert_eq(card.range, 5, "thunder boarding range")
	assert_eq(card.damage, 15, "thunder boarding base damage")
	assert_eq(card.target, "single", "thunder boarding target mode is single")
	assert_eq(card.status_effects.size(), 1, "thunder boarding has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "stun", "thunder boarding applies stun")
	assert_eq(int(effect.get("duration", 0)), 1, "thunder boarding stun duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("15"), "thunder boarding card summary includes base damage")
	assert_true(not summary_text.contains("stun"), "thunder boarding card summary hides raw stun id")

	var player = _make_player(50)
	var target = _make_enemy("thunder_boarding_target", 40, 4, 10)
	var untouched = _make_enemy("thunder_boarding_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(7))
	var stun_label := _status_label_from_scene(scene, "stun")
	assert_true(summary_text.contains(stun_label), "thunder boarding card summary uses the same readable stun label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 29, "thunder boarding deals 15 damage reduced by target defense")
	assert_eq(untouched.hp, 40, "thunder boarding leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "stun", card.id, target.id, 1, 0)
	_assert_status_duration(target, "stun", 1, "thunder boarding applies stun duration 1")
	assert_true(not untouched.has_status("stun"), "thunder boarding does not stun the untargeted enemy")
	var stun_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "stun"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "thunder boarding summary keeps source card name")
	_assert_last_action_message_contains(scene, stun_result_text, "thunder boarding summary shows readable stun feedback")
	_assert_status_detail_contains(scene, target.id, "thunder boarding status detail lists the stunned target")
	_assert_status_detail_contains(scene, "%s 1" % stun_label, "thunder boarding status detail shows stun duration")
	_assert_visible_text_not_contains(scene, "stun", "thunder boarding hides raw stun id")
	_assert_visible_text_not_contains(scene, "status_applied", "thunder boarding hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "thunder boarding hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "thunder boarding hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "thunder boarding blocks only the stunned enemy action")
	assert_true(not target.has_status("stun"), "thunder boarding stun expires after the stunned enemy skips action")
	_assert_status_detail_not_contains(scene, stun_label, "thunder boarding status detail clears expired stun")
	await _teardown(scene)

	var high_def_card = _load_card("chariot_s7_thunder_boarding")
	var high_def_target = _make_enemy("thunder_boarding_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(7))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "thunder boarding still deals minimum 1 damage to a high-defense target")
	assert_eq(high_def_target.def, 20, "thunder boarding does not mutate defense")
	_assert_status_duration(high_def_target, "stun", 1, "thunder boarding stuns a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_hermit_s9_glyph_spark() -> void:
	var card = _load_card("hermit_s9_glyph_spark")
	if card == null:
		return
	assert_eq(card.pathway, "hermit", "glyph spark loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "glyph spark sequence")
	assert_eq(card.energy_cost, 1, "glyph spark cost comes from mp_cost")
	assert_eq(card.range, 4, "glyph spark range")
	assert_eq(card.damage, 7, "glyph spark base damage")
	assert_eq(card.target, "single", "glyph spark target mode is single")
	assert_eq(card.status_effects.size(), 1, "glyph spark has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "burn", "glyph spark applies the real burn status")
	assert_eq(int(effect.get("duration", 0)), 1, "glyph spark burn duration")
	assert_eq(int(effect.get("magnitude", 0)), 2, "glyph spark burn magnitude")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("7"), "glyph spark card summary includes base damage")
	assert_true(not summary_text.contains("burn"), "glyph spark card summary hides raw burn id")

	var player = _make_player(50)
	var target = _make_enemy("glyph_spark_target", 40, 3, 0)
	var untouched = _make_enemy("glyph_spark_untouched", 40, 0, 0)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(9))
	var burn_label := _status_label_from_scene(scene, "burn")
	assert_true(summary_text.contains(burn_label), "glyph spark card summary uses the same readable burn label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 36, "glyph spark deals 7 damage reduced by target defense")
	assert_eq(untouched.hp, 40, "glyph spark leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "burn", card.id, target.id, 1, 2)
	_assert_status_duration(target, "burn", 1, "glyph spark applies burn duration 1")
	assert_eq(int(target.statuses.get("burn", {}).get("magnitude", 0)), 2, "glyph spark burn status stores magnitude 2")
	assert_true(not untouched.has_status("burn"), "glyph spark does not burn the untargeted enemy")
	var burn_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "burn"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "glyph spark summary keeps source card name")
	_assert_last_action_message_contains(scene, burn_result_text, "glyph spark summary shows readable burn feedback")
	_assert_status_detail_contains(scene, target.id, "glyph spark status detail lists the burned target")
	_assert_status_detail_contains(scene, "%s 1" % burn_label, "glyph spark status detail shows burn duration")
	_assert_status_detail_contains(scene, "2", "glyph spark status detail shows burn magnitude")
	_assert_visible_text_not_contains(scene, "burn", "glyph spark hides raw burn id")
	_assert_visible_text_not_contains(scene, "status_applied", "glyph spark hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "glyph spark hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "glyph spark hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(target.hp, 34, "glyph spark burn deals 2 turn-start DOT")
	assert_true(not target.has_status("burn"), "glyph spark burn duration 1 expires after DOT")
	_assert_status_detail_not_contains(scene, burn_label, "glyph spark status detail clears expired burn")
	await _teardown(scene)

	var high_def_card = _load_card("hermit_s9_glyph_spark")
	var high_def_target = _make_enemy("glyph_spark_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(9))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "glyph spark still deals minimum 1 damage to a high-defense target")
	assert_eq(high_def_target.def, 20, "glyph spark does not mutate defense")
	_assert_status_duration(high_def_target, "burn", 1, "glyph spark burns a high-defense target after minimum damage")
	assert_eq(int(high_def_target.statuses.get("burn", {}).get("magnitude", 0)), 2, "glyph spark high-defense burn stores magnitude 2")
	await _teardown(high_def_scene)


func _case_hermit_s9_hidden_eye() -> void:
	var card = _load_card("hermit_s9_hidden_eye")
	if card == null:
		return
	assert_eq(card.pathway, "hermit", "hidden eye loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "hidden eye sequence")
	assert_eq(card.energy_cost, 0, "hidden eye cost comes from mp_cost")
	assert_eq(card.range, 5, "hidden eye range")
	assert_eq(card.damage, 0, "hidden eye has no direct damage")
	assert_eq(card.target, "single", "hidden eye target mode is single")
	assert_eq(card.status_effects.size(), 1, "hidden eye has one reveal payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "intent_revealed", "hidden eye uses the intent_revealed payload")
	assert_eq(int(effect.get("duration", 0)), 1, "hidden eye reveal duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("揭示意图"), "hidden eye card summary names the reveal effect")
	assert_true(not summary_text.contains("intent_revealed"), "hidden eye card summary hides raw intent_revealed id")

	var target = _make_enemy("hidden_eye_target", 40, 4, 9)
	var untouched = _make_enemy("hidden_eye_untouched", 40, 0, 7)
	var scene = await _start_scene([card], [target, untouched], _make_player(50), _game_state(9))
	var reveal_label := _status_label_from_scene(scene, "intent_revealed")
	assert_eq(reveal_label, "揭示意图", "hidden eye BattleScene label names intent_revealed")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 40, "hidden eye does not damage the selected target")
	assert_eq(untouched.hp, 40, "hidden eye leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "intent_revealed", card.id, target.id, 1, 0)
	_assert_status_duration(target, "intent_revealed", 1, "hidden eye applies reveal marker to the selected target")
	assert_true(not untouched.has_status("intent_revealed"), "hidden eye does not apply reveal marker to the untargeted enemy")
	_assert_intent_revealed_by_card(scene, target.id, 1, card.id)
	_assert_intent_not_revealed_by_card(scene, untouched.id, card.id)
	_assert_intent_reveal_result(scene, card.id, "intent_reveal", 1, 1, [target.id])
	var reveal_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "intent_revealed"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "hidden eye summary keeps source card name")
	_assert_last_action_message_contains(scene, "揭示意图 1", "hidden eye summary reports one revealed target")
	_assert_last_action_message_contains(scene, reveal_result_text, "hidden eye summary shows readable reveal marker feedback")
	_assert_status_detail_contains(scene, target.id, "hidden eye status detail lists the selected target")
	_assert_status_detail_contains(scene, "%s 1" % reveal_label, "hidden eye status detail shows reveal duration")
	_assert_visible_text_not_contains(scene, "intent_revealed", "hidden eye hides raw intent_revealed id")
	_assert_visible_text_not_contains(scene, "intent_reveal", "hidden eye hides raw intent_reveal id")
	_assert_visible_text_not_contains(scene, "intent_revealed_by_card", "hidden eye hides raw reveal reason")
	_assert_visible_text_not_contains(scene, "status_applied", "hidden eye hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "hidden eye hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "hidden eye hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_true(not target.has_status("intent_revealed"), "hidden eye reveal marker expires after the selected enemy turn")
	_assert_status_detail_not_contains(scene, reveal_label, "hidden eye status detail clears expired reveal marker")
	await _teardown(scene)


func _case_hermit_s8_archive_flame() -> void:
	var card = _load_card("hermit_s8_archive_flame")
	if card == null:
		return
	assert_eq(card.pathway, "hermit", "archive flame loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "archive flame sequence")
	assert_eq(card.energy_cost, 1, "archive flame cost comes from mp_cost")
	assert_eq(card.range, 5, "archive flame range")
	assert_eq(card.damage, 10, "archive flame base damage")
	assert_eq(card.target, "single", "archive flame target mode is single")
	assert_eq(card.status_effects.size(), 1, "archive flame has one exposed/revealed payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "revealed", "archive flame uses the revealed payload")
	assert_eq(int(effect.get("duration", 0)), 2, "archive flame revealed duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("10"), "archive flame card summary includes base damage")
	assert_true(not summary_text.contains("revealed"), "archive flame card summary hides raw revealed id")

	var player = _make_player(50)
	var target = _make_enemy("archive_flame_target", 40, 3, 9)
	var untouched = _make_enemy("archive_flame_untouched", 40, 0, 7)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(8))
	var revealed_label := _status_label_from_scene(scene, "revealed")
	assert_true(summary_text.contains(revealed_label), "archive flame card summary uses the same readable revealed label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 33, "archive flame deals 10 damage reduced by target defense")
	assert_eq(target.def, 3, "archive flame does not mutate target defense")
	assert_eq(untouched.hp, 40, "archive flame leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "revealed", card.id, target.id, 2, 0)
	_assert_status_duration(target, "revealed", 2, "archive flame applies revealed duration 2 to the selected target")
	assert_true(not untouched.has_status("revealed"), "archive flame does not apply revealed to the untargeted enemy")
	_assert_intent_revealed_by_card(scene, target.id, 1, card.id)
	_assert_intent_not_revealed_by_card(scene, untouched.id, card.id)
	_assert_intent_reveal_result(scene, card.id, "intent_reveal", 1, 1, [target.id])
	var revealed_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "revealed"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "archive flame summary keeps source card name")
	_assert_last_action_message_contains(scene, revealed_result_text, "archive flame summary shows readable revealed feedback")
	_assert_status_detail_contains(scene, target.id, "archive flame status detail lists the selected target")
	_assert_status_detail_contains(scene, "%s 2" % revealed_label, "archive flame status detail shows revealed duration")
	_assert_visible_text_not_contains(scene, "revealed", "archive flame hides raw revealed id")
	_assert_visible_text_not_contains(scene, "intent_reveal", "archive flame hides raw intent_reveal id")
	_assert_visible_text_not_contains(scene, "intent_revealed_by_card", "archive flame hides raw reveal reason")
	_assert_visible_text_not_contains(scene, "status_applied", "archive flame hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "archive flame hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "archive flame hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	_assert_status_duration(target, "revealed", 1, "archive flame revealed ticks after the selected enemy turn")
	_assert_status_detail_contains(scene, "%s 1" % revealed_label, "archive flame status detail shows revealed after first tick")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_true(not target.has_status("revealed"), "archive flame revealed expires after two selected enemy turns")
	_assert_status_detail_not_contains(scene, revealed_label, "archive flame status detail clears expired revealed")
	await _teardown(scene)

	var high_def_card = _load_card("hermit_s8_archive_flame")
	var high_def_target = _make_enemy("archive_flame_high_def", 40, 20, 8)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(8))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "archive flame still deals minimum 1 damage to a high-defense target")
	assert_eq(high_def_target.def, 20, "archive flame does not mutate high-defense target defense")
	_assert_status_duration(high_def_target, "revealed", 2, "archive flame reveals a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_hermit_s8_rune_cage() -> void:
	var card = _load_card("hermit_s8_rune_cage")
	if card == null:
		return
	assert_eq(card.pathway, "hermit", "rune cage loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "rune cage sequence")
	assert_eq(card.energy_cost, 1, "rune cage cost comes from mp_cost")
	assert_eq(card.range, 4, "rune cage range")
	assert_eq(card.damage, 5, "rune cage base damage")
	assert_eq(card.target, "single", "rune cage target mode is single")
	assert_eq(card.status_effects.size(), 1, "rune cage has one root payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "root", "rune cage applies root")
	assert_eq(int(effect.get("duration", 0)), 1, "rune cage root duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("5"), "rune cage card summary includes base damage")
	assert_true(not summary_text.contains("root"), "rune cage card summary hides raw root id")

	var player = _make_player(50)
	var target = _make_enemy("rune_cage_target", 40, 2, 10)
	var untouched = _make_enemy("rune_cage_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(8))
	var root_label := _status_label_from_scene(scene, "root")
	assert_true(summary_text.contains(root_label), "rune cage card summary uses the same readable root label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 37, "rune cage deals 5 damage reduced by target defense")
	assert_eq(target.def, 2, "rune cage does not mutate target defense")
	assert_eq(untouched.hp, 40, "rune cage leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "root", card.id, target.id, 1, 0)
	_assert_status_duration(target, "root", 1, "rune cage applies root duration 1")
	assert_true(not untouched.has_status("root"), "rune cage does not root the untargeted enemy")
	var root_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "root"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "rune cage summary keeps source card name")
	_assert_last_action_message_contains(scene, root_result_text, "rune cage summary shows readable root feedback")
	_assert_status_detail_contains(scene, target.id, "rune cage status detail lists the rooted target")
	_assert_status_detail_contains(scene, "%s 1" % root_label, "rune cage status detail shows root duration")
	_assert_visible_text_not_contains(scene, "root", "rune cage hides raw root id")
	_assert_visible_text_not_contains(scene, "status_applied", "rune cage hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "rune cage hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "rune cage hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "rune cage root blocks only the rooted enemy action")
	assert_true(not target.has_status("root"), "rune cage root expires after the rooted enemy skips action")
	_assert_status_detail_not_contains(scene, root_label, "rune cage status detail clears expired root")
	await _teardown(scene)

	var high_def_card = _load_card("hermit_s8_rune_cage")
	var high_def_target = _make_enemy("rune_cage_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(8))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "rune cage still deals minimum 1 damage to a high-defense target")
	assert_eq(high_def_target.def, 20, "rune cage does not mutate high-defense target defense")
	_assert_status_duration(high_def_target, "root", 1, "rune cage roots a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _assert_fixed_pierce_card_visible(card_id: String, expected_magnitude: int, expected_hp: int) -> void:
	var card = _load_card(card_id)
	var enemy = _make_enemy("%s_target" % card_id, 30, 6)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.def, 6, "%s does not mutate defense while piercing" % card_id)
	assert_eq(enemy.hp, expected_hp, "%s applies fixed pierce_block damage" % card_id)
	_assert_effect_result_by_reason_id(scene, "damage_modifier", "pierce_block", expected_magnitude)
	_assert_visible_text_contains(scene, "穿透防御 %d" % expected_magnitude, "%s shows concrete pierce_block summary" % card_id)
	_assert_visible_text_contains(scene, card.get_display_name(), "%s summary keeps source card name" % card_id)
	await _teardown(scene)


func _assert_fixed_ignore_guard_card_visible(card_id: String, expected_magnitude: int, expected_hp: int) -> void:
	var card = _load_card(card_id)
	var enemy = _make_enemy("%s_target" % card_id, 30, 6)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.def, 6, "%s does not mutate defense while ignoring fixed defense" % card_id)
	assert_eq(enemy.hp, expected_hp, "%s applies fixed ignore_guard damage" % card_id)
	_assert_effect_result_by_reason_id(scene, "damage_modifier", "ignore_guard", expected_magnitude)
	_assert_visible_text_contains(scene, "固定忽略防御 %d" % expected_magnitude, "%s shows concrete ignore_guard summary" % card_id)
	_assert_visible_text_contains(scene, card.get_display_name(), "%s summary keeps source card name" % card_id)
	await _teardown(scene)


func _assert_space_fold_visible() -> void:
	var card = _load_card("priestess_s7_space_fold")
	var enemy = _make_enemy("space_fold_visible_target", 30, 6)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.def, 6, "space fold does not mutate defense while piercing")
	assert_eq(enemy.hp, 16, "space fold adds range damage and applies fixed pierce")
	_assert_effect_result_by_reason_id(scene, "damage_modifier", "range_bonus", 3)
	_assert_effect_result_by_reason_id(scene, "damage_modifier", "pierce_block", 3)
	_assert_visible_text_contains(scene, "距离加伤 +3", "space fold shows concrete range_bonus summary")
	_assert_visible_text_contains(scene, "穿透防御 3", "space fold shows concrete pierce_block summary")
	_assert_visible_text_contains(scene, card.get_display_name(), "space fold summary keeps source card name")
	await _teardown(scene)


func _assert_block_break_card_visible(card_id: String) -> void:
	var card = _load_card(card_id)
	var enemy = _make_enemy("%s_target" % card_id, 30, 5)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.def, 2, "%s shreds three defense before damage" % card_id)
	assert_eq(enemy.hp, 21, "%s deals damage after shredding defense" % card_id)
	_assert_effect_result_by_reason_id(scene, "defense_shredded", "block_break", 3)
	_assert_visible_text_contains(scene, "破防 3", "%s shows concrete block_break summary" % card_id)
	_assert_visible_text_contains(scene, "防御 2", "%s exposes remaining defense on HP row" % card_id)
	_assert_visible_text_contains(scene, card.get_display_name(), "%s summary keeps source card name" % card_id)
	await _teardown(scene)


func _case_fool_s7_wound_displacement() -> void:
	var card = _load_card("fool_s7_wound_displacement")
	var player = _make_player(40)
	var enemy = _make_enemy_with_status_skill("wound_debuffer", [{"id": "weak", "duration": 2, "magnitude": 1}])
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, player)
	_assert_card_used(scene, card.id)
	assert_true(player.has_status("fatal_damage_convert"), "wound displacement registers fatal damage conversion")
	assert_true(player.has_status("cleanse_incoming_debuff"), "wound displacement registers next-debuff cleanse")
	_assert_visible_text_contains(scene, "致命转移", "wound displacement shows fatal conversion status")
	_assert_visible_text_contains(scene, "净化下次负面", "wound displacement shows next-debuff cleanse status")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "wound displacement cleanse test enemy does not deal damage")
	assert_true(not player.has_status("weak"), "wound displacement blocks the next incoming debuff")
	assert_true(not player.has_status("cleanse_incoming_debuff"), "wound displacement consumes next-debuff cleanse after blocking")
	_assert_status_detail_not_contains(scene, "净化下次负面", "wound displacement status detail clears consumed next-debuff cleanse")
	scene._battle._deal_raw_damage(player, 100)
	assert_eq(player.hp, 20, "wound displacement converts lethal damage into 50 percent current HP damage")
	await _teardown(scene)


func _case_fool_s7_flame_jump() -> void:
	var card = _load_card("fool_s7_flame_jump")
	var support = _support_card("flame_stream_support", ["skill", "flame_stream"])
	var enemy = _make_enemy("flame_jump_target", 30)
	var scene = await _start_scene([card, support], [enemy])
	scene._battle.add_field_marker("flame_markers", 2)
	scene._battle.energy = 0
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	assert_eq(int(scene._battle.effective_card_cost(card)), 0, "flame jump costs zero while another flame_stream card is in hand")
	assert_true(scene._battle.can_play_card(card), "flame jump can be played when flame markers exist")
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(scene._battle.energy, 0, "flame jump spends no energy with flame_stream support")
	assert_eq(scene._battle.get_field_marker_count("flame_markers"), 1, "flame jump consumes exactly one flame marker")
	assert_eq(enemy.hp, 24, "flame jump deals 6 direct damage")
	_assert_flame_jump_result(scene, 6, 1, 1)
	_assert_effect_result_by_reason_id(scene, "cost_modifier_registered", "cost_zero_if_flame_stream", 0)
	_assert_visible_text_contains(scene, "火焰跳跃 6", "flame jump shows readable teleport damage summary")
	_assert_visible_text_contains(scene, "消耗火焰标记", "flame jump summary shows marker consumption")
	_assert_visible_text_contains(scene, "火焰标记 1", "flame jump field label shows the remaining marker")
	_assert_visible_text_contains(scene, card.get_display_name(), "flame jump summary keeps source card name")
	_assert_visible_text_not_contains(scene, "teleport_to_flame", "flame jump hides raw effect id")
	await _teardown(scene)

	var blocked_card = _load_card("fool_s7_flame_jump")
	var blocked_enemy = _make_enemy("flame_jump_blocked_target", 30)
	var blocked_scene = await _start_scene([blocked_card], [blocked_enemy])
	assert_eq(blocked_scene._battle.card_play_block_reason(blocked_card), "flame_marker_required", "flame jump is blocked without a flame marker")
	assert_true(not blocked_scene._battle.can_play_card(blocked_card), "flame jump cannot be played without a flame marker")
	_assert_hand_card_text_contains(blocked_scene, "需要先制造火焰标记", "flame jump button explains missing flame marker")
	await _play_direct(blocked_scene, blocked_card, blocked_enemy)
	assert_eq(blocked_enemy.hp, 30, "blocked flame jump does not damage the enemy")
	assert_true(not blocked_scene._battle.used_cards.has(blocked_card.id), "blocked flame jump is not recorded as used")
	_assert_visible_text_contains(blocked_scene, "出牌失败", "blocked flame jump reports failed play")
	await _teardown(blocked_scene)


func _case_fool_s7_air_bullet() -> void:
	var card = _load_card("fool_s7_air_bullet")
	var primer_a = _support_card("air_bullet_primer_a", ["attack"])
	var primer_b = _support_card("air_bullet_primer_b", ["attack"])
	var enemy = _make_enemy("air_target", 30, 5)
	var scene = await _start_scene([card, primer_a, primer_b], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.def, 5, "air bullet does not mutate defense while piercing")
	assert_eq(enemy.hp, 24, "air bullet first play ignores 3 defense before applying 8 damage")
	_assert_effect_result_by_reason_id(scene, "damage_modifier", "pierce_block", 3)
	_assert_attack_play_growth_result(scene, 2, 6)
	_assert_visible_text_contains(scene, "穿透防御 3", "air bullet shows concrete pierce_block summary")
	_assert_visible_text_contains(scene, "攻击成长 +2", "air bullet shows attack-play growth registration")
	_assert_visible_text_contains(scene, "防御 5", "air bullet keeps remaining defense visible on HP row")
	_assert_visible_text_contains(scene, card.get_display_name(), "air bullet summary keeps source card name")
	_assert_visible_text_not_contains(scene, "pierce_block", "air bullet hides raw pierce_block id")
	_assert_visible_text_not_contains(scene, "attack_play_damage_growth", "air bullet hides raw attack growth id")

	await _return_card_to_hand_for_replay(scene, card)
	await _play_direct(scene, primer_a, scene._player)
	await _play_direct(scene, primer_b, scene._player)
	assert_eq(int(scene._battle._card_attack_play_damage_growth_bonus(card)), 6, "air bullet reaches +6 attack-play growth cap after three attack-card plays")
	await _return_card_to_hand_for_replay(scene, card)
	await _play_direct(scene, card, enemy)
	assert_eq(enemy.def, 5, "air bullet replay still does not mutate defense while piercing")
	assert_eq(enemy.hp, 12, "air bullet replay applies capped +6 growth before fixed defense pierce")
	_assert_attack_play_growth_result(scene, 2, 6)
	_assert_visible_text_contains(scene, "12", "air bullet replay summary includes capped grown damage")
	_assert_visible_text_contains(scene, "攻击成长 +2", "air bullet replay still shows growth registration")
	await _teardown(scene)


func _case_emperor_s7_verdict_crush() -> void:
	var card = _load_card("emperor_s7_verdict_crush")
	var enemy = _make_enemy("verdict_crush_target", 40, 10)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.def, 10, "verdict crush does not mutate defense while piercing")
	assert_eq(enemy.hp, 30, "verdict crush applies fixed pierce_block 4 instead of full defense ignore")
	_assert_effect_result_by_reason_id(scene, "damage_modifier", "pierce_block", 4)
	_assert_visible_text_contains(scene, "穿透防御 4", "verdict crush shows concrete pierce_block summary")
	_assert_visible_text_contains(scene, "防御 10", "verdict crush keeps remaining defense visible on HP row")
	_assert_visible_text_contains(scene, card.get_display_name(), "verdict crush summary keeps source card name")
	_assert_visible_text_not_contains(scene, "pierce_block", "verdict crush hides raw pierce_block id")
	await _teardown(scene)


func _case_fool_s7_paper_doll_substitute() -> void:
	var card = _load_card("fool_s7_paper_doll_substitute")
	var player = _make_player(30)
	var enemy = _make_enemy("paper_doll_attacker", 30, 0, 999)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, player)
	_assert_card_used(scene, card.id)
	assert_eq(player.get_marker_count("paper_doll"), 1, "paper doll substitute places one paper_doll marker")
	assert_true(player.has_status("absorb_fatal_or_curse"), "paper doll substitute stores the fatal absorb trigger flag")
	_assert_paper_doll_marker_result(scene, 1, 1, 3)
	_assert_absorb_fatal_status_result(scene)
	_assert_visible_text_contains(scene, card.get_display_name(), "paper doll summary keeps source card name")
	_assert_visible_text_contains(scene, "纸人 +1", "paper doll summary shows readable marker gain")
	_assert_visible_text_contains(scene, "替死吸收", "paper doll summary shows readable fatal absorb status")
	_assert_status_detail_contains(scene, "纸人 1", "paper doll status detail shows active marker count")
	_assert_status_detail_contains(scene, "替死吸收", "paper doll status detail shows active fatal absorb trigger")
	_assert_visible_text_not_contains(scene, "paper_doll_marker", "paper doll hides raw marker effect id")
	_assert_visible_text_not_contains(scene, "absorb_fatal_or_curse", "paper doll hides raw absorb effect id")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 0, "paper doll previews the next lethal hit as absorbed")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 30, "paper doll marker absorbs lethal damage")
	assert_eq(player.get_marker_count("paper_doll"), 0, "paper doll marker is consumed after lethal absorb")
	assert_true(not player.has_status("absorb_fatal_or_curse"), "paper doll fatal absorb trigger flag clears after marker is consumed")
	var trigger_result := _find_effect_result_by_reason_id(scene, "paper_doll_absorbed_fatal", "paper_doll_marker")
	assert_true(not trigger_result.is_empty(), "paper doll records a lethal absorb trigger result")
	if not trigger_result.is_empty():
		assert_eq(int(trigger_result.get("incoming_damage", 0)), 999, "paper doll trigger result records incoming damage")
		assert_eq(str(trigger_result.get("target_id", "")), "player", "paper doll trigger result records protected player")
		assert_eq(str(trigger_result.get("source_id", "")), str(enemy.get("id")), "paper doll trigger result records source attacker")
		assert_eq(int(trigger_result.get("remaining_markers", -1)), 0, "paper doll trigger result records remaining markers")
	_assert_visible_text_contains(scene, "纸人吸收致命伤", "paper doll enemy-turn summary explains lethal absorption")
	_assert_status_detail_not_contains(scene, "纸人 1", "paper doll status detail clears consumed marker")
	_assert_status_detail_not_contains(scene, "替死吸收", "paper doll status detail clears consumed fatal absorb trigger")
	await _teardown(scene)


func _case_fool_s7_flame_command() -> void:
	var card = _load_card("fool_s7_flame_command")
	var enemy = _make_enemy("flame_command_dummy", 30)
	var scene = await _start_scene([card], [enemy])
	scene._battle.add_field_marker("flame_markers", 1)
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_eq(scene._battle.get_field_marker_count("flame_markers"), 3, "flame command adds two markers to the existing marker")
	assert_eq(int(scene._battle.field_state.get("adjacent_burn", 0)), 3, "flame command sets adjacent burn magnitude")
	_assert_flame_marker_result(scene, 2, 3)
	_assert_effect_result_by_reason_id(scene, "adjacent_burn_set", "adjacent_burn", 3)
	_assert_visible_text_contains(scene, "火焰标记 +2", "flame command summary shows added marker count instead of total as a delta")
	_assert_visible_text_contains(scene, "火焰标记 3", "flame command field label shows total marker count")
	_assert_visible_text_contains(scene, "相邻燃烧 3", "flame command field label shows adjacent burn magnitude")
	_assert_visible_text_contains(scene, card.get_display_name(), "flame command summary keeps source card name")
	_assert_visible_text_not_contains(scene, "create_or_move_flame_markers", "flame command hides raw marker effect id")
	scene._battle.end_player_turn()
	scene._battle.run_enemy_turn()
	assert_eq(enemy.hp, 27, "flame command adjacent_burn damages enemy at enemy turn start while markers exist")
	await _teardown(scene)


func _case_fool_s7_illusion_weave() -> void:
	var card = _load_card("fool_s7_illusion_weave")
	var player = _make_player(30)
	var followup = _attack_card("illusion_followup_strike", 10)
	var enemy_a = _make_enemy("illusion_attacker_a", 40, 0, 8)
	var enemy_b = _make_enemy("illusion_decoy_b", 40, 0, 8)
	var enemy_c = _make_enemy("illusion_decoy_c", 40, 0, 8)
	var enemies := [enemy_a, enemy_b, enemy_c]
	var scene = await _start_scene([card, followup], enemies, player)
	seed(71003)
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	var confused := _actors_with_status(enemies, "confusion")
	assert_true(confused.size() >= 1 and confused.size() <= 2, "illusion weave applies confusion to random 1-2 living enemies")
	_assert_status_applied_results_for_targets(scene, "confusion", _actor_ids_from(confused), 2)
	assert_true(player.has_status("reroll_next_target"), "illusion weave registers reroll_next_target on player")
	_assert_reroll_next_target_status(player)
	_assert_reroll_next_target_result(scene, card.id)
	_assert_visible_text_contains(scene, card.get_display_name(), "illusion weave summary keeps source card name")
	_assert_visible_text_contains(scene, "混乱", "illusion weave shows readable confusion feedback")
	_assert_visible_text_contains(scene, "重定下次目标", "illusion weave shows readable reroll setup feedback")
	_assert_status_detail_contains(scene, "改判下次目标", "illusion weave status detail shows reroll_next_target")
	_assert_visible_text_not_contains(scene, "confusion", "illusion weave hides raw confusion id")
	_assert_visible_text_not_contains(scene, "reroll_next_damage_target", "illusion weave hides raw reroll effect id")
	await _play_direct(scene, followup, enemy_a)
	assert_eq(enemy_a.hp, 40, "illusion weave rerolls the next damage away from the chosen target")
	assert_eq(enemy_b.hp, 30, "illusion weave reroll sends the next damage to the next living enemy")
	assert_true(not player.has_status("reroll_next_target"), "illusion weave reroll status is consumed by the next damage event")
	_assert_reroll_next_target_consumed_result(scene, enemy_a.id, enemy_b.id)
	_assert_status_detail_not_contains(scene, "改判下次目标", "illusion weave status detail clears consumed reroll status")
	var confused_attacker = confused[0]
	var redirect_target = _first_other_actor(enemies, confused_attacker)
	scene._battle.field_state["confusion_redirect_chance_override"] = 1.0
	scene._battle.enemies = [confused_attacker, redirect_target]
	scene._battle.current_enemy_intents.clear()
	scene._battle.current_enemy_intents[confused_attacker.id] = {"action": "use_skill", "skill": "hit"}
	scene._battle.current_enemy_intents[redirect_target.id] = {"action": "defend"}
	var player_hp_before := int(player.hp)
	var redirect_hp_before := int(redirect_target.hp)
	scene._battle.end_player_turn()
	scene._battle.run_enemy_turn()
	assert_eq(int(player.hp), player_hp_before, "forced confusion redirect prevents enemy damage to the player")
	assert_eq(int(redirect_target.hp), redirect_hp_before - 8, "forced confusion redirect sends the confused attack into another enemy")
	await _teardown(scene)


func _case_fool_s7_water_breath() -> void:
	var card = _load_card("fool_s7_water_breath")
	var player = _make_player(30)
	var enemy = _make_enemy_with_status_skill("water_silencer", [{"id": "silence", "duration": 2}])
	var scene = await _start_scene([card], [enemy], player)
	player.add_status("poison", {"id": "poison", "duration": 2, "magnitude": 1})
	player.add_status("weak", {"id": "weak", "duration": 2, "magnitude": 1})
	await _play_direct(scene, card, player)
	_assert_card_used(scene, card.id)
	assert_true(not player.has_status("poison"), "water breath cleanses poison")
	assert_true(player.has_status("weak"), "water breath does not cleanse non-matching weak")
	assert_true(player.has_status("immune_debuff"), "water breath grants immune_debuff")
	assert_true(player.has_status("consume_on_trigger"), "water breath registers consume_on_trigger")
	_assert_cleanse_debuff_result(scene, ["poison"], ["suffocate", "poison", "silence"], card.id, "player")
	_assert_guard_status_result(scene, "immune_debuff", card.id, "player", 3, ["suffocate", "poison", "silence"])
	_assert_guard_status_result(scene, "consume_on_trigger", card.id, "player", 0, [])
	_assert_visible_text_contains(scene, card.get_display_name(), "water breath summary keeps source card name")
	_assert_visible_text_contains(scene, "净化减益", "water breath shows readable cleanse feedback")
	_assert_visible_text_contains(scene, "免疫负面", "water breath shows readable immune feedback")
	_assert_visible_text_contains(scene, "触发后消耗", "water breath shows readable consume trigger feedback")
	_assert_status_detail_contains(scene, "免疫负面 3", "water breath status detail shows immune duration")
	_assert_status_detail_contains(scene, "触发后消耗", "water breath status detail shows consume-on-trigger")
	_assert_visible_text_not_contains(scene, "immune_debuff", "water breath hides raw immune_debuff id")
	_assert_visible_text_not_contains(scene, "consume_on_trigger", "water breath hides raw consume_on_trigger id")
	scene._battle._apply_enemy_skill_status_effects(enemy, player, {"target": "single", "status_effects": [{"id": "blind", "duration": 2}]})
	assert_true(player.has_status("blind"), "water breath does not block non-matching incoming blind")
	assert_true(player.has_status("immune_debuff"), "water breath keeps immune_debuff after non-matching debuff")
	assert_true(player.has_status("consume_on_trigger"), "water breath keeps consume_on_trigger after non-matching debuff")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_true(not player.has_status("silence"), "water breath immune_debuff blocks matching incoming silence")
	assert_true(not player.has_status("immune_debuff"), "water breath consumes immune_debuff after the matching debuff is blocked")
	assert_true(not player.has_status("consume_on_trigger"), "water breath consumes consume_on_trigger after the matching debuff is blocked")
	_assert_incoming_debuff_blocked_result(scene, "immune_debuff", "silence", "player", enemy.id)
	_assert_status_detail_not_contains(scene, "免疫负面", "water breath status detail clears consumed immune_debuff")
	_assert_status_detail_not_contains(scene, "触发后消耗", "water breath status detail clears consumed consume_on_trigger")
	await _teardown(scene)


func _case_fool_s7_bone_softening() -> void:
	var card = _load_card("fool_s7_bone_softening")
	await _assert_bone_softening_cleanse_branch(card)
	await _assert_bone_softening_draw_branch(card)


func _assert_bone_softening_cleanse_branch(card) -> void:
	var not_drawn = _support_card("bone_softening_should_not_draw", ["skill"])
	var player = _make_player(30)
	var scene = await _start_scene([card], [_make_enemy("bone_cleanse_dummy", 30)], player)
	player.add_status("bind", {"id": "bind", "duration": 2, "magnitude": 1})
	player.add_status("weak", {"id": "weak", "duration": 2, "magnitude": 1})
	scene._battle.draw_pile = [not_drawn]
	await _play_direct(scene, card, player)
	_assert_card_used(scene, card.id)
	assert_true(not player.has_status("bind"), "bone softening cleanses matching bind")
	assert_true(player.has_status("weak"), "bone softening keeps non-matching weak")
	assert_true(not _card_in_zone(scene._battle.hand, not_drawn.id), "bone softening does not draw when a matching debuff was cleansed")
	_assert_cleanse_debuff_result_exact(scene, ["bind"], ["bind", "root", "paralyze"], card.id, "player", "bone softening cleanse branch")
	_assert_draw_if_no_cleanse_skipped_result(scene, card.id, "player")
	_assert_visible_text_contains(scene, card.get_display_name(), "bone softening cleanse branch keeps source card name")
	_assert_visible_text_contains(scene, "净化减益", "bone softening cleanse branch shows readable cleanse feedback")
	_assert_visible_text_contains(scene, "已净化，不抽牌", "bone softening cleanse branch explains why draw did not fire")
	_assert_visible_text_not_contains(scene, "draw_if_no_cleanse", "bone softening cleanse branch hides raw draw_if_no_cleanse id")
	_assert_visible_text_not_contains(scene, "cleanse_debuff", "bone softening cleanse branch hides raw cleanse_debuff id")
	await _teardown(scene)


func _assert_bone_softening_draw_branch(card) -> void:
	var drawn = _support_card("bone_softening_draw", ["skill"])
	var player = _make_player(30)
	var scene = await _start_scene([card], [_make_enemy("bone_draw_dummy", 30)], player)
	player.add_status("weak", {"id": "weak", "duration": 2, "magnitude": 1})
	scene._battle.draw_pile = [drawn]
	await _play_direct(scene, card, player)
	_assert_card_used(scene, card.id)
	assert_true(player.has_status("weak"), "bone softening draw branch keeps non-matching weak")
	assert_true(_card_in_zone(scene._battle.hand, drawn.id), "bone softening draws one card when no matching debuff is cleansed")
	_assert_cleanse_debuff_result_exact(scene, [], ["bind", "root", "paralyze"], card.id, "player", "bone softening draw branch")
	_assert_draw_if_no_cleanse_drew_result(scene, 1, card.id, "player")
	_assert_visible_text_contains(scene, card.get_display_name(), "bone softening draw branch keeps source card name")
	_assert_visible_text_contains(scene, "未净化，抽牌 +1", "bone softening draw branch shows readable no-cleanse draw feedback")
	_assert_visible_text_not_contains(scene, "draw_if_no_cleanse", "bone softening draw branch hides raw draw_if_no_cleanse id")
	_assert_visible_text_not_contains(scene, "cleanse_debuff", "bone softening draw branch hides raw cleanse_debuff id")
	await _teardown(scene)


func _case_fool_s7_paper_arsenal() -> void:
	var card = _load_card("fool_s7_paper_arsenal")
	await _assert_paper_arsenal_attack_branch(card)
	await _assert_paper_arsenal_skill_branch(card)
	await _assert_paper_arsenal_status_branch(card)
	await _assert_paper_arsenal_neutral_branch(card)


func _assert_paper_arsenal_attack_branch(card) -> void:
	var top_attack = _support_card("paper_arsenal_attack_top", ["attack"])
	var enemy = _make_enemy("arsenal_attack_target", 30)
	var scene = await _start_scene([card], [enemy])
	scene._battle.draw_pile = [top_attack]
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	_assert_paper_arsenal_discard(scene, top_attack.id, "attack branch")
	_assert_paper_arsenal_attack_bonus_result(scene, 6)
	_assert_paper_arsenal_condition_not_met(scene, "vulnerable_if_skill")
	_assert_paper_arsenal_condition_not_met(scene, "weak_if_status")
	assert_eq(enemy.hp, 19, "paper arsenal attack branch adds +6 to base 5 damage")
	assert_true(not enemy.has_status("vulnerable"), "paper arsenal attack branch does not apply vulnerable")
	assert_true(not enemy.has_status("weak"), "paper arsenal attack branch does not apply weak")
	_assert_paper_arsenal_visible_feedback(scene, card, ["弃置牌库顶牌", "本次伤害 +6"], "attack branch")
	await _teardown(scene)


func _assert_paper_arsenal_skill_branch(card) -> void:
	var top_skill = _support_card("paper_arsenal_skill_top", ["skill"])
	var enemy = _make_enemy("arsenal_skill_target", 30)
	var scene = await _start_scene([card], [enemy])
	scene._battle.draw_pile = [top_skill]
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	_assert_paper_arsenal_discard(scene, top_skill.id, "skill branch")
	_assert_paper_arsenal_condition_not_met(scene, "bonus_if_attack")
	_assert_paper_arsenal_status_result(scene, "vulnerable_if_skill", "vulnerable", 2)
	_assert_paper_arsenal_condition_not_met(scene, "weak_if_status")
	assert_eq(enemy.hp, 25, "paper arsenal skill branch deals only base 5 damage")
	_assert_status_duration(enemy, "vulnerable", 2, "paper arsenal skill branch applies vulnerable for 2 turns")
	assert_true(not enemy.has_status("weak"), "paper arsenal skill branch does not apply weak")
	_assert_status_detail_contains(scene, "易伤 2", "paper arsenal skill branch shows vulnerable duration in status detail")
	_assert_paper_arsenal_visible_feedback(scene, card, ["弃置牌库顶牌", "易伤", "条件未满足"], "skill branch")
	await _teardown(scene)


func _assert_paper_arsenal_status_branch(card) -> void:
	var top_status = _support_card("paper_arsenal_status_top", ["status"])
	var enemy = _make_enemy("arsenal_status_target", 30)
	var scene = await _start_scene([card], [enemy])
	scene._battle.draw_pile = [top_status]
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	_assert_paper_arsenal_discard(scene, top_status.id, "status branch")
	_assert_paper_arsenal_condition_not_met(scene, "bonus_if_attack")
	_assert_paper_arsenal_condition_not_met(scene, "vulnerable_if_skill")
	_assert_paper_arsenal_status_result(scene, "weak_if_status", "weak", 2)
	assert_eq(enemy.hp, 25, "paper arsenal status branch deals only base 5 damage")
	assert_true(not enemy.has_status("vulnerable"), "paper arsenal status branch does not apply vulnerable")
	_assert_status_duration(enemy, "weak", 2, "paper arsenal status branch applies weak for 2 turns")
	_assert_status_detail_contains(scene, "虚弱 2", "paper arsenal status branch shows weak duration in status detail")
	_assert_paper_arsenal_visible_feedback(scene, card, ["弃置牌库顶牌", "虚弱", "条件未满足"], "status branch")
	await _teardown(scene)


func _assert_paper_arsenal_neutral_branch(card) -> void:
	var top_neutral = _support_card("paper_arsenal_neutral_top", ["utility"])
	var enemy = _make_enemy("arsenal_neutral_target", 30)
	var scene = await _start_scene([card], [enemy])
	scene._battle.draw_pile = [top_neutral]
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	_assert_paper_arsenal_discard(scene, top_neutral.id, "neutral branch")
	_assert_paper_arsenal_condition_not_met(scene, "bonus_if_attack")
	_assert_paper_arsenal_condition_not_met(scene, "vulnerable_if_skill")
	_assert_paper_arsenal_condition_not_met(scene, "weak_if_status")
	assert_eq(enemy.hp, 25, "paper arsenal neutral branch deals only base 5 damage")
	assert_true(not enemy.has_status("vulnerable"), "paper arsenal neutral branch does not apply vulnerable")
	assert_true(not enemy.has_status("weak"), "paper arsenal neutral branch does not apply weak")
	_assert_paper_arsenal_visible_feedback(scene, card, ["弃置牌库顶牌", "条件未满足"], "neutral branch")
	await _teardown(scene)


func _assert_paper_arsenal_discard(scene, expected_card_id: String, branch_name: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "discarded_top_deck", "discard_top_deck")
	assert_true(not result.is_empty(), "paper arsenal %s records top-deck discard result" % branch_name)
	if not result.is_empty():
		assert_eq(str(result.get("discarded_card_id", "")), expected_card_id, "paper arsenal %s result names discarded card" % branch_name)
	assert_true(_card_in_zone(scene._battle.discard_pile, expected_card_id), "paper arsenal %s moves top card to discard pile" % branch_name)
	assert_true(not _card_in_zone(scene._battle.draw_pile, expected_card_id), "paper arsenal %s removes top card from draw pile" % branch_name)


func _assert_paper_arsenal_attack_bonus_result(scene, expected_bonus: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "attack_bonus_applied", "bonus_if_attack")
	assert_true(not result.is_empty(), "paper arsenal attack branch records attack bonus result")
	if result.is_empty():
		return
	assert_eq(int(result.get("damage_bonus", 0)), expected_bonus, "paper arsenal attack branch result damage bonus")


func _assert_paper_arsenal_status_result(scene, effect_id: String, expected_status: String, expected_duration: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "conditional_status_applied", effect_id)
	assert_true(not result.is_empty(), "paper arsenal %s records conditional status result" % effect_id)
	if result.is_empty():
		return
	assert_eq(str(result.get("applied_status", "")), expected_status, "paper arsenal %s result applied status" % effect_id)
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(int(payload.get("duration", 0)), expected_duration, "paper arsenal %s result duration" % effect_id)


func _assert_paper_arsenal_condition_not_met(scene, effect_id: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "condition_not_met", effect_id)
	assert_true(not result.is_empty(), "paper arsenal records condition_not_met for %s" % effect_id)


func _assert_paper_arsenal_visible_feedback(scene, card, expected_fragments: Array, branch_name: String) -> void:
	var text := _collect_label_text(scene) if scene != null else ""
	assert_true(text.contains(card.get_display_name()), "paper arsenal %s shows source card name" % branch_name)
	for fragment in expected_fragments:
		assert_true(text.contains(str(fragment)), "paper arsenal %s visible feedback includes %s" % [branch_name, str(fragment)])
	assert_true(not text.contains("bonus_if_attack"), "paper arsenal %s hides raw bonus_if_attack id" % branch_name)
	assert_true(not text.contains("vulnerable_if_skill"), "paper arsenal %s hides raw vulnerable_if_skill id" % branch_name)
	assert_true(not text.contains("weak_if_status"), "paper arsenal %s hides raw weak_if_status id" % branch_name)


func _assert_status_duration(actor, status_id: String, expected_duration: int, message: String) -> void:
	assert_true(actor.has_status(status_id), message)
	if not actor.has_status(status_id):
		return
	var payload: Dictionary = actor.statuses.get(status_id, {})
	assert_eq(int(payload.get("duration", 0)), expected_duration, "%s duration" % message)


func _case_fool_s7_swift_cast() -> void:
	var card = _load_card("fool_s7_swift_cast")
	var first_fool_skill = _support_skill_card("swift_first_fool_skill", "fool", 1)
	var second_fool_skill = _support_skill_card("swift_second_fool_skill", "fool", 1)
	var other_path_skill = _support_skill_card("swift_other_path_skill", "priestess", 1)
	var player = _make_player(30)
	var enemy = _make_enemy("counter_enemy", 30)
	var scene = await _start_scene([card, first_fool_skill, second_fool_skill, other_path_skill], [enemy], player)
	scene._battle.energy = 0
	scene._battle.current_enemy_intents[enemy.id] = {"type": "counter", "damage": 7}
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	await _play_direct(scene, card, player)
	_assert_card_used(scene, card.id)
	assert_true(player.has_status("next_card_cost_delta"), "swift cast registers next Fool skill cost delta")
	_assert_next_card_cost_delta_status(player, -1, "fool", "skill")
	_assert_next_card_cost_delta_result(scene, -1, "fool", "skill")
	var counter_result: Dictionary = scene._battle.field_state.get("last_counter_result", {})
	assert_true(enemy.id in counter_result.get("skipped", []), "swift cast skips counter intent")
	_assert_counter_intent_avoided_result(scene, [enemy.id])
	assert_eq(player.hp, 30, "swift cast avoids counter damage")
	_assert_visible_text_contains(scene, card.get_display_name(), "swift cast summary keeps source card name")
	_assert_visible_text_contains(scene, "下一张愚者技能费用", "swift cast shows readable next-Fool-skill cost summary")
	_assert_visible_text_contains(scene, "规避反制意图", "swift cast shows readable counter-intent avoidance")
	_assert_status_detail_contains(scene, "下一张愚者技能费用", "swift cast status detail shows next Fool skill cost delta")
	_assert_status_detail_contains(scene, "-1", "swift cast status detail shows cost delta magnitude")
	_assert_hand_button_text_contains(scene, first_fool_skill, "费用 0", "swift cast visibly discounts the next Fool skill in hand")
	_assert_hand_button_text_contains(scene, other_path_skill, "费用 1", "swift cast does not discount another pathway skill")
	_assert_visible_text_not_contains(scene, "next_fool_skill_cost_delta", "swift cast hides raw next_fool_skill_cost_delta id")
	_assert_visible_text_not_contains(scene, "avoid_counter_intent", "swift cast hides raw avoid_counter_intent id")
	_assert_visible_text_not_contains(scene, "next_card_cost_delta", "swift cast hides raw transient cost status id")
	scene._battle.current_enemy_intents[enemy.id] = {"type": "counter", "damage": 7}
	await _play_direct(scene, first_fool_skill, player)
	_assert_card_used(scene, first_fool_skill.id)
	assert_true(not player.has_status("next_card_cost_delta"), "swift cast consumes the cost delta on the next Fool skill")
	assert_eq(player.hp, 23, "swift cast counter avoidance does not persist to the next card")
	assert_eq(scene._battle.effective_card_cost(second_fool_skill), 1, "swift cast discounts only one Fool skill")
	_assert_hand_button_text_contains(scene, second_fool_skill, "费用 1", "swift cast hand UI returns later Fool skills to full cost")
	await _teardown(scene)


func _case_fool_s7_minor_trick() -> void:
	var card = _load_card("fool_s7_minor_trick")
	var existing_card = _support_card("minor_trick_existing_draw_top", ["skill"])
	var scene = await _start_scene([card], [_make_enemy("minor_dummy", 30)])
	scene._battle.draw_pile = [existing_card]
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_true(card in scene._battle.discard_pile, "minor trick source card reaches discard after BattleScene play")
	assert_eq(scene._battle.draw_pile.size(), 2, "minor trick inserts one temp card into draw pile")
	if scene._battle.draw_pile.size() > 0:
		var generated_card = scene._battle.draw_pile[0]
		var generated_id := str(generated_card.id) if generated_card != null else ""
		assert_true(generated_id in _minor_trick_option_ids(card), "minor trick temp card id comes from its structured options")
		assert_true("temporary" in generated_card.tags, "minor trick generated card keeps temporary tag")
		_assert_minor_trick_temp_card_result(scene, generated_card)
		_assert_visible_text_contains(scene, generated_card.get_display_name(), "minor trick summary shows generated temp card name")
		var destination_text := str(scene.call("_generated_card_destination_text", "draw_pile_top"))
		assert_true(destination_text != "", "minor trick has readable draw-pile-top destination label")
		_assert_visible_text_contains(scene, destination_text, "minor trick summary shows draw-pile-top destination")
	if scene._battle.draw_pile.size() > 1:
		assert_eq(str(scene._battle.draw_pile[1].id), existing_card.id, "minor trick preserves previous draw pile order under generated card")
	else:
		assert_true(false, "minor trick preserves previous draw pile order under generated card")
	_assert_visible_text_contains(scene, card.get_display_name(), "minor trick summary keeps source card name")
	_assert_visible_text_not_contains(scene, "create_random_temp_card", "minor trick hides raw create_random_temp_card id")
	_assert_visible_text_not_contains(scene, "temp_card_created", "minor trick hides raw temp_card_created reason")
	_assert_visible_text_not_contains(scene, "minor_trick_temp_", "minor trick hides raw generated temp-card ids")
	_assert_visible_text_not_contains(scene, "{", "minor trick hides raw Dictionary opening brace")
	_assert_visible_text_not_contains(scene, "}", "minor trick hides raw Dictionary closing brace")
	await _teardown(scene)


func _case_hermit_s7_spell_backlash() -> void:
	var card = _load_card("hermit_s7_spell_backlash")
	var player = _make_player(30)
	var enemy = _make_enemy_with_status_skill("spell_backlash_caster", [], 9)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 18, "spell backlash deals its base damage before the delayed counter")
	assert_true(enemy.has_status("silence"), "spell backlash applies silence")
	assert_true(enemy.has_status("counter_spell"), "spell backlash applies counter_spell")
	_assert_status_applied_result(scene, "silence", card.id, enemy.id, 1, 0)
	_assert_status_applied_result(scene, "counter_spell", card.id, enemy.id, 0, 6)
	_assert_visible_text_contains(scene, card.get_display_name(), "spell backlash summary keeps source card name")
	_assert_visible_text_contains(scene, "沉默", "spell backlash shows readable silence feedback")
	_assert_visible_text_contains(scene, "反咒", "spell backlash shows readable counter-spell feedback")
	_assert_status_detail_contains(scene, "沉默 1", "spell backlash status detail shows silence duration")
	_assert_status_detail_contains(scene, "反咒 强度 6", "spell backlash status detail shows counter-spell magnitude")
	_assert_visible_text_not_contains(scene, "silence", "spell backlash hides raw silence id")
	_assert_visible_text_not_contains(scene, "counter_spell", "spell backlash hides raw counter_spell id")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 30, "spell backlash silence prevents the enemy skill damage")
	assert_eq(enemy.hp, 12, "spell backlash counter_spell damages the caster when a spell is attempted")
	assert_true(not enemy.has_status("counter_spell"), "spell backlash consumes counter_spell after the spell attempt")
	var trigger_result := _find_effect_result_by_reason_id(scene, "counter_spell_triggered", "counter_spell")
	assert_true(not trigger_result.is_empty(), "spell backlash records counter_spell trigger result")
	if not trigger_result.is_empty():
		assert_eq(int(trigger_result.get("damage", 0)), 6, "spell backlash trigger result damage")
		assert_eq(str(trigger_result.get("target_id", "")), enemy.id, "spell backlash trigger result target caster")
		assert_eq(str(trigger_result.get("source_id", "")), "player", "spell backlash trigger result source player")
	_assert_visible_text_contains(scene, "反咒 6", "spell backlash enemy-turn summary shows readable counter-spell trigger")
	_assert_visible_text_not_contains(scene, "counter_spell_triggered", "spell backlash hides raw trigger reason")
	await _teardown(scene)


func _case_fortune_thread() -> void:
	var card = _load_card("fortune_thread")
	if card == null:
		return
	var follow_up = _attack_card("fortune_thread_follow_up", 10)
	var enemy = _make_enemy("fortune_thread_target", 40, 3)
	var scene = await _start_scene([card, follow_up], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 33, "fortune thread deals 10 damage reduced by 3 defense before vulnerable is applied")
	_assert_status_applied_result(scene, "vulnerable", card.id, enemy.id, 3, 0)
	_assert_status_duration(enemy, "vulnerable", 3, "fortune thread applies vulnerable duration 3")
	var vulnerable_label := _status_label_from_scene(scene, "vulnerable")
	var vulnerable_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "vulnerable"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "fortune thread summary keeps source card name")
	_assert_last_action_message_contains(scene, vulnerable_result_text, "fortune thread summary shows readable vulnerable feedback")
	_assert_status_detail_contains(scene, "%s 3" % vulnerable_label, "fortune thread status detail shows vulnerable duration")
	_assert_visible_text_not_contains(scene, "vulnerable", "fortune thread hides raw vulnerable id")
	_assert_visible_text_not_contains(scene, "status_applied", "fortune thread hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "fortune thread hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "fortune thread hides raw dictionary braces")
	await _play_direct(scene, follow_up, enemy)
	_assert_card_used(scene, follow_up.id)
	assert_eq(enemy.hp, 23, "fortune thread vulnerable amplifies the next 10 damage hit after defense from 7 to 10")
	await _teardown(scene)


func _case_fortune_arrow() -> void:
	var card = _load_card("fortune_arrow")
	if card == null:
		return
	assert_eq(card.pathway, "common", "fortune arrow loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "fortune arrow sequence")
	assert_eq(card.energy_cost, 10, "fortune arrow cost comes from mp_cost")
	assert_eq(card.range, 5, "fortune arrow range")
	assert_eq(card.damage, 22, "fortune arrow base damage")
	assert_eq(card.target, "single", "fortune arrow target mode is single")
	assert_eq(card.status_effects.size(), 1, "fortune arrow has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "crit_up", "fortune arrow uses crit_up payload")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("crit_up"), "fortune arrow card summary hides raw crit_up id")

	var enemy = _make_enemy("fortune_arrow_target", 50, 5, 0)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 22, "fortune arrow applies crit_up as current-hit 1.5x before subtracting defense")
	assert_true(not enemy.has_status("crit_up"), "fortune arrow does not leave crit_up as a persistent enemy status")
	assert_true(not scene._player.has_status("crit_up"), "fortune arrow does not leave crit_up as a persistent player status")
	var crit_result := _find_effect_result_by_reason_id(scene, "damage_modifier", "crit_up")
	assert_true(not crit_result.is_empty(), "fortune arrow records crit_up as a damage modifier result")
	var crit_result_text := _effect_result_text_from_scene(scene, crit_result)
	_assert_last_action_message_contains(scene, card.get_display_name(), "fortune arrow summary keeps source card name")
	_assert_last_action_message_contains(scene, crit_result_text, "fortune arrow summary includes crit_up result text")
	assert_true(crit_result_text.contains("1.5"), "fortune arrow damage-modifier text explains the 1.5x crit multiplier")
	_assert_visible_text_not_contains(scene, "crit_up", "fortune arrow hides raw crit_up id")
	_assert_visible_text_not_contains(scene, "damage_modifier", "fortune arrow hides raw damage_modifier reason")
	_assert_visible_text_not_contains(scene, "{", "fortune arrow hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "fortune arrow hides raw dictionary braces")
	await _teardown(scene)


func _case_jester_arrow() -> void:
	var card = _load_card("jester_arrow")
	if card == null:
		return
	assert_eq(card.pathway, "common", "jester arrow loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "jester arrow sequence")
	assert_eq(card.energy_cost, 8, "jester arrow cost comes from mp_cost")
	assert_eq(card.range, 4, "jester arrow range")
	assert_eq(card.damage, 14, "jester arrow base damage")
	assert_eq(card.target, "random", "jester arrow target mode is random")
	assert_eq(card.status_effects.size(), 1, "jester arrow has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "confusion", "jester arrow applies confusion")
	assert_eq(int(effect.get("duration", 0)), 1, "jester arrow confusion duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("confusion"), "jester arrow card summary hides raw confusion id")

	var enemy_no_def = _make_enemy("jester_arrow_no_def", 40, 0, 0)
	var enemy_mid_def = _make_enemy("jester_arrow_mid_def", 40, 4, 0)
	var enemy_high_def = _make_enemy("jester_arrow_high_def", 40, 8, 0)
	var enemies := [enemy_no_def, enemy_mid_def, enemy_high_def]
	var expected_hp_by_id := {
		enemy_no_def.id: 26,
		enemy_mid_def.id: 30,
		enemy_high_def.id: 34,
	}
	var scene = await _start_scene([card], enemies)
	seed(73031)
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	var damaged := []
	for enemy in enemies:
		if int(enemy.hp) < 40:
			damaged.append(enemy)
	assert_eq(damaged.size(), 1, "jester arrow randomly damages exactly one living enemy")
	if damaged.size() != 1:
		await _teardown(scene)
		return
	var selected = damaged[0]
	assert_eq(int(selected.hp), int(expected_hp_by_id.get(selected.id, -1)), "jester arrow damage uses selected target defense")
	for enemy in enemies:
		if enemy == selected:
			continue
		assert_eq(int(enemy.hp), 40, "jester arrow leaves unselected enemy %s HP unchanged" % str(enemy.id))
		assert_true(not enemy.has_status("confusion"), "jester arrow leaves unselected enemy %s unconfused" % str(enemy.id))
	_assert_status_applied_result(scene, "confusion", card.id, selected.id, 1, 0)
	_assert_status_duration(selected, "confusion", 1, "jester arrow applies confusion only to the selected random target")
	var confused := _actors_with_status(enemies, "confusion")
	assert_eq(confused.size(), 1, "jester arrow confuses exactly one living enemy")
	if confused.size() == 1:
		assert_eq(str(confused[0].id), str(selected.id), "jester arrow confusion target matches the damaged target")
	var confusion_label := _status_label_from_scene(scene, "confusion")
	var confusion_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "confusion"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "jester arrow summary keeps source card name")
	_assert_last_action_message_contains(scene, confusion_result_text, "jester arrow summary shows readable confusion feedback")
	_assert_status_detail_contains(scene, "%s 1" % confusion_label, "jester arrow status detail shows confusion duration")
	_assert_visible_text_not_contains(scene, "confusion", "jester arrow hides raw confusion id")
	_assert_visible_text_not_contains(scene, "status_applied", "jester arrow hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "jester arrow hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "jester arrow hides raw dictionary braces")
	await _teardown(scene)


func _case_name_arrow() -> void:
	var card = _load_card("name_arrow")
	if card == null:
		return
	assert_eq(card.pathway, "common", "name arrow loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "name arrow sequence")
	assert_eq(card.energy_cost, 12, "name arrow cost comes from mp_cost")
	assert_eq(card.range, 6, "name arrow range")
	assert_eq(card.damage, 16, "name arrow base damage")
	assert_eq(card.target, "single", "name arrow target mode is single")
	assert_eq(card.status_effects.size(), 1, "name arrow has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "mark", "name arrow applies mark")
	assert_eq(int(effect.get("magnitude", 0)), 2, "name arrow mark magnitude")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("mark"), "name arrow card summary hides raw mark id")

	var follow_up = _attack_card("name_arrow_follow_up", 10)
	var enemy = _make_enemy("name_arrow_target", 50, 4, 0)
	var scene = await _start_scene([card, follow_up], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 38, "name arrow deals 16 damage reduced by 4 defense before mark applies to later hits")
	_assert_status_applied_result(scene, "mark", card.id, enemy.id, 0, 2)
	assert_true(enemy.has_status("mark"), "name arrow leaves a mark status on the target")
	assert_eq(int(enemy.statuses.get("mark", {}).get("magnitude", 0)), 2, "name arrow mark status stores magnitude 2")
	assert_true(not enemy.statuses.get("mark", {}).has("duration"), "name arrow mark has no duration and is not a countdown status")
	var mark_label := _status_label_from_scene(scene, "mark")
	var mark_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "mark"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "name arrow summary keeps source card name")
	_assert_last_action_message_contains(scene, mark_result_text, "name arrow summary shows readable mark feedback")
	_assert_status_detail_contains(scene, mark_label, "name arrow status detail shows readable mark")
	_assert_status_detail_contains(scene, "2", "name arrow status detail shows mark magnitude")
	_assert_visible_text_not_contains(scene, "mark", "name arrow hides raw mark id")
	_assert_visible_text_not_contains(scene, "status_applied", "name arrow hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "name arrow hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "name arrow hides raw dictionary braces")
	await _play_direct(scene, follow_up, enemy)
	_assert_card_used(scene, follow_up.id)
	assert_eq(enemy.hp, 30, "name arrow mark adds 2 damage to the later 10 damage hit after defense")
	assert_true(enemy.has_status("mark"), "name arrow mark persists after increasing a later hit")
	await _teardown(scene)


func _case_inquiry_fortune() -> void:
	var card = _load_card("inquiry_fortune")
	if card == null:
		return
	var enemy = _make_enemy("inquiry_fortune_target", 40, 2, 9)
	var scene = await _start_scene([card], [enemy])
	var before_intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_true(not before_intent.is_empty(), "inquiry fortune starts with visible enemy intent data")
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 36, "inquiry fortune deals 6 damage reduced by 2 defense")
	_assert_status_applied_result(scene, "obscure_intent", card.id, enemy.id, 99, 0)
	_assert_status_duration(enemy, "obscure_intent", 99, "inquiry fortune applies long intent-obscuring duration")
	var obscure_label := _status_label_from_scene(scene, "obscure_intent")
	var obscure_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "obscure_intent"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "inquiry fortune summary keeps source card name")
	_assert_last_action_message_contains(scene, obscure_result_text, "inquiry fortune summary shows readable intent-obscuring feedback")
	_assert_status_detail_contains(scene, "%s 99" % obscure_label, "inquiry fortune status detail shows obscure-intent duration")
	_assert_visible_text_contains(scene, "被遮蔽", "inquiry fortune hides the target intent row after status application")
	_assert_visible_text_not_contains(scene, "obscure_intent", "inquiry fortune hides raw obscure_intent id")
	_assert_visible_text_not_contains(scene, "status_applied", "inquiry fortune hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "inquiry fortune hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "inquiry fortune hides raw dictionary braces")
	await _teardown(scene)


func _case_inquiry_mirror() -> void:
	var card = _load_card("inquiry_mirror")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "inquiry mirror loads the runtime data/cards override pathway")
	assert_eq(card.sequence, 8, "inquiry mirror loads the runtime data/cards override sequence")
	assert_eq(card.energy_cost, 2, "inquiry mirror loads the runtime data/cards override cost")
	assert_eq(card.range, 1, "inquiry mirror loads the runtime data/cards override range")
	var enemy = _make_enemy("inquiry_mirror_target", 40, 3, 9)
	var scene = await _start_scene([card], [enemy])
	var before_intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_true(not before_intent.is_empty(), "inquiry mirror starts with visible enemy intent data")
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 35, "inquiry mirror deals 8 damage reduced by 3 defense")
	_assert_status_applied_result(scene, "obscure_intent", card.id, enemy.id, 1, 0)
	_assert_status_duration(enemy, "obscure_intent", 1, "inquiry mirror applies short intent-obscuring duration")
	var obscure_label := _status_label_from_scene(scene, "obscure_intent")
	var obscure_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "obscure_intent"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "inquiry mirror summary keeps source card name")
	_assert_last_action_message_contains(scene, obscure_result_text, "inquiry mirror summary shows readable intent-obscuring feedback")
	_assert_status_detail_contains(scene, "%s 1" % obscure_label, "inquiry mirror status detail shows obscure-intent duration")
	_assert_visible_text_contains(scene, "被遮蔽", "inquiry mirror hides the target intent row after status application")
	_assert_visible_text_not_contains(scene, "obscure_intent", "inquiry mirror hides raw obscure_intent id")
	_assert_visible_text_not_contains(scene, "status_applied", "inquiry mirror hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "inquiry mirror hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "inquiry mirror hides raw dictionary braces")
	await _teardown(scene)


func _case_inquiry_name() -> void:
	var card = _load_card("inquiry_name")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "inquiry name loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "inquiry name catalog card sequence")
	assert_eq(card.energy_cost, 2, "inquiry name catalog card cost")
	assert_eq(card.range, 1, "inquiry name catalog card range")
	var enemy = _make_enemy("inquiry_name_target", 40, 4, 9)
	var scene = await _start_scene([card], [enemy])
	var before_intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_true(not before_intent.is_empty(), "inquiry name starts with visible enemy intent data")
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 36, "inquiry name deals 8 damage reduced by 4 defense")
	_assert_status_applied_result(scene, "obscure_intent", card.id, enemy.id, 1, 0)
	_assert_status_duration(enemy, "obscure_intent", 1, "inquiry name applies short intent-obscuring duration")
	var obscure_label := _status_label_from_scene(scene, "obscure_intent")
	var obscure_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "obscure_intent"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "inquiry name summary keeps source card name")
	_assert_last_action_message_contains(scene, obscure_result_text, "inquiry name summary shows readable intent-obscuring feedback")
	_assert_status_detail_contains(scene, "%s 1" % obscure_label, "inquiry name status detail shows obscure-intent duration")
	_assert_visible_text_contains(scene, "被遮蔽", "inquiry name hides the target intent row after status application")
	_assert_visible_text_not_contains(scene, "obscure_intent", "inquiry name hides raw obscure_intent id")
	_assert_visible_text_not_contains(scene, "status_applied", "inquiry name hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "inquiry name hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "inquiry name hides raw dictionary braces")
	await _teardown(scene)


func _case_jester_face() -> void:
	var card = _load_card("jester_face")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "jester face loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "jester face catalog card sequence")
	assert_eq(card.energy_cost, 1, "jester face catalog card cost")
	assert_eq(card.range, 1, "jester face catalog card range")
	var enemy = _make_enemy("jester_face_target", 40, 1, 9)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 37, "jester face deals 4 damage reduced by 1 defense")
	_assert_status_applied_result(scene, "confusion", card.id, enemy.id, 1, 0)
	_assert_status_duration(enemy, "confusion", 1, "jester face applies short confusion duration")
	var confusion_label := _status_label_from_scene(scene, "confusion")
	var confusion_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "confusion"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "jester face summary keeps source card name")
	_assert_last_action_message_contains(scene, confusion_result_text, "jester face summary shows readable confusion feedback")
	_assert_status_detail_contains(scene, "%s 1" % confusion_label, "jester face status detail shows confusion duration")
	_assert_visible_text_not_contains(scene, "confusion", "jester face hides raw confusion id")
	_assert_visible_text_not_contains(scene, "status_applied", "jester face hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "jester face hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "jester face hides raw dictionary braces")
	await _teardown(scene)


func _case_jester_fortune() -> void:
	var card = _load_card("jester_fortune")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "jester fortune loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "jester fortune catalog card sequence")
	assert_eq(card.energy_cost, 1, "jester fortune catalog card cost")
	assert_eq(card.range, 1, "jester fortune catalog card range")
	var follow_up = _attack_card("jester_fortune_follow_up", 10)
	var enemy = _make_enemy("jester_fortune_target", 40, 2, 9)
	var scene = await _start_scene([card, follow_up], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 36, "jester fortune deals 6 damage reduced by 2 defense")
	_assert_status_applied_result(scene, "vulnerable", card.id, enemy.id, 3, 0)
	_assert_status_duration(enemy, "vulnerable", 3, "jester fortune applies vulnerable duration 3")
	var vulnerable_label := _status_label_from_scene(scene, "vulnerable")
	var vulnerable_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "vulnerable"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "jester fortune summary keeps source card name")
	_assert_last_action_message_contains(scene, vulnerable_result_text, "jester fortune summary shows readable vulnerable feedback")
	_assert_status_detail_contains(scene, "%s 3" % vulnerable_label, "jester fortune status detail shows vulnerable duration")
	_assert_visible_text_not_contains(scene, "vulnerable", "jester fortune hides raw vulnerable id")
	_assert_visible_text_not_contains(scene, "status_applied", "jester fortune hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "jester fortune hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "jester fortune hides raw dictionary braces")
	await _play_direct(scene, follow_up, enemy)
	_assert_card_used(scene, follow_up.id)
	assert_eq(enemy.hp, 24, "jester fortune vulnerable amplifies the next 10 damage hit after defense from 8 to 12")
	await _teardown(scene)


func _case_jester_name() -> void:
	var card = _load_card("jester_name")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "jester name loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "jester name catalog card sequence")
	assert_eq(card.energy_cost, 3, "jester name catalog card cost")
	assert_eq(card.range, 1, "jester name catalog card range")
	var enemy = _make_enemy("jester_name_target", 40, 5, 9)
	var scene = await _start_scene([card], [enemy])
	var before_intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_true(not before_intent.is_empty(), "jester name starts with visible enemy intent data")
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 37, "jester name deals 8 damage reduced by 5 defense")
	_assert_status_applied_result(scene, "obscure_intent", card.id, enemy.id, 1, 0)
	_assert_status_duration(enemy, "obscure_intent", 1, "jester name applies short intent-obscuring duration")
	var obscure_label := _status_label_from_scene(scene, "obscure_intent")
	var obscure_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "obscure_intent"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "jester name summary keeps source card name")
	_assert_last_action_message_contains(scene, obscure_result_text, "jester name summary shows readable intent-obscuring feedback")
	_assert_status_detail_contains(scene, "%s 1" % obscure_label, "jester name status detail shows obscure-intent duration")
	_assert_visible_text_contains(scene, "被遮蔽", "jester name hides the target intent row after status application")
	_assert_visible_text_not_contains(scene, "obscure_intent", "jester name hides raw obscure_intent id")
	_assert_visible_text_not_contains(scene, "status_applied", "jester name hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "jester name hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "jester name hides raw dictionary braces")
	await _teardown(scene)


func _case_mirror_face() -> void:
	var card = _load_card("mirror_face")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "mirror face loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "mirror face catalog card sequence")
	assert_eq(card.energy_cost, 3, "mirror face catalog card cost")
	assert_eq(card.range, 0, "mirror face catalog card range")
	var player = _make_player(30)
	var enemy = _make_enemy("mirror_face_attacker", 30, 0, 10)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, scene._player)
	_assert_card_used(scene, card.id)
	assert_eq(player.hp, 24, "mirror face self-target damage resolves before its new damage reduction")
	assert_true(scene._player.has_status("damage_reduction"), "mirror face applies damage_reduction to the player")
	_assert_damage_reduction_status_result(scene, card.id, "player", 3, 3.0)
	var damage_reduction_label := _status_label_from_scene(scene, "damage_reduction")
	var damage_reduction_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "damage_reduction"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "mirror face summary keeps source card name")
	_assert_last_action_message_contains(scene, damage_reduction_result_text, "mirror face summary shows readable damage-reduction feedback")
	_assert_status_detail_contains(scene, "%s 3" % damage_reduction_label, "mirror face status detail shows damage-reduction duration")
	_assert_status_detail_contains(scene, "3", "mirror face status detail shows fixed reduction magnitude")
	_assert_visible_text_not_contains(scene, "damage_reduction", "mirror face hides raw damage_reduction id")
	_assert_visible_text_not_contains(scene, "status_applied", "mirror face hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "mirror face hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "mirror face hides raw dictionary braces")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 7, "mirror face previews the next 10 damage hit as fixed reduction to 7")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 17, "mirror face reduces the next incoming enemy hit by 3")
	assert_true(not player.has_status("damage_reduction"), "mirror face consumes damage_reduction after the next incoming hit")
	_assert_damage_reduction_trigger_result(scene, "player", enemy.id, 10, 7, 3.0)
	_assert_visible_text_contains(scene, damage_reduction_label, "mirror face enemy-turn summary shows readable damage-reduction trigger")
	_assert_status_detail_not_contains(scene, damage_reduction_label, "mirror face status detail clears consumed damage reduction")
	await _teardown(scene)


func _case_mirror_shadow() -> void:
	var card = _load_card("mirror_shadow")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "mirror shadow loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "mirror shadow catalog card sequence")
	assert_eq(card.energy_cost, 2, "mirror shadow catalog card cost")
	assert_eq(card.range, 0, "mirror shadow catalog card range")
	var player = _make_player(30)
	var enemy = _make_enemy("mirror_shadow_attacker", 30, 0, 10)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, scene._player)
	_assert_card_used(scene, card.id)
	assert_eq(player.hp, 24, "mirror shadow self-target damage resolves before its new damage reduction")
	assert_true(scene._player.has_status("damage_reduction"), "mirror shadow applies damage_reduction to the player")
	_assert_damage_reduction_status_result(scene, card.id, "player", 3, 2.0)
	var damage_reduction_label := _status_label_from_scene(scene, "damage_reduction")
	var damage_reduction_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "damage_reduction"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "mirror shadow summary keeps source card name")
	_assert_last_action_message_contains(scene, damage_reduction_result_text, "mirror shadow summary shows readable damage-reduction feedback")
	_assert_status_detail_contains(scene, "%s 3" % damage_reduction_label, "mirror shadow status detail shows damage-reduction duration")
	_assert_status_detail_contains(scene, "2", "mirror shadow status detail shows fixed reduction magnitude")
	_assert_visible_text_not_contains(scene, "damage_reduction", "mirror shadow hides raw damage_reduction id")
	_assert_visible_text_not_contains(scene, "status_applied", "mirror shadow hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "mirror shadow hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "mirror shadow hides raw dictionary braces")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 8, "mirror shadow previews the next 10 damage hit as fixed reduction to 8")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 16, "mirror shadow reduces the next incoming enemy hit by 2")
	assert_true(not player.has_status("damage_reduction"), "mirror shadow consumes damage_reduction after the next incoming hit")
	_assert_damage_reduction_trigger_result(scene, "player", enemy.id, 10, 8, 2.0, 2)
	_assert_visible_text_contains(scene, damage_reduction_label, "mirror shadow enemy-turn summary shows readable damage-reduction trigger")
	_assert_status_detail_not_contains(scene, damage_reduction_label, "mirror shadow status detail clears consumed damage reduction")
	await _teardown(scene)


func _case_shadow_jester() -> void:
	var card = _load_card("shadow_jester")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "shadow jester loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "shadow jester catalog card sequence")
	assert_eq(card.energy_cost, 2, "shadow jester catalog card cost")
	assert_eq(card.range, 1, "shadow jester catalog card range")
	var enemy = _make_enemy("shadow_jester_target", 40, 4, 9)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 32, "shadow jester deals 12 damage reduced by 4 defense")
	_assert_status_applied_result(scene, "confusion", card.id, enemy.id, 1, 0)
	_assert_status_duration(enemy, "confusion", 1, "shadow jester applies short confusion duration")
	var confusion_label := _status_label_from_scene(scene, "confusion")
	var confusion_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "confusion"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "shadow jester summary keeps source card name")
	_assert_last_action_message_contains(scene, confusion_result_text, "shadow jester summary shows readable confusion feedback")
	_assert_status_detail_contains(scene, "%s 1" % confusion_label, "shadow jester status detail shows confusion duration")
	_assert_visible_text_not_contains(scene, "confusion", "shadow jester hides raw confusion id")
	_assert_visible_text_not_contains(scene, "status_applied", "shadow jester hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "shadow jester hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "shadow jester hides raw dictionary braces")
	await _teardown(scene)


func _case_shadow_name() -> void:
	var card = _load_card("shadow_name")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "shadow name loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "shadow name catalog card sequence")
	assert_eq(card.energy_cost, 3, "shadow name catalog card cost")
	assert_eq(card.range, 1, "shadow name catalog card range")
	var player = _make_player(30)
	var enemy = _make_enemy("shadow_name_target", 40, 6, 10)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 32, "shadow name deals 14 damage reduced by 6 defense")
	_assert_status_applied_result(scene, "weak", card.id, enemy.id, 2, 0)
	_assert_status_duration(enemy, "weak", 2, "shadow name applies weak duration 2")
	var weak_label := _status_label_from_scene(scene, "weak")
	var weak_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "weak"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "shadow name summary keeps source card name")
	_assert_last_action_message_contains(scene, weak_result_text, "shadow name summary shows readable weak feedback")
	_assert_status_detail_contains(scene, "%s 2" % weak_label, "shadow name status detail shows weak duration")
	_assert_visible_text_not_contains(scene, "weak", "shadow name hides raw weak id")
	_assert_visible_text_not_contains(scene, "status_applied", "shadow name hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "shadow name hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "shadow name hides raw dictionary braces")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 7, "shadow name weak previews the next 10 enemy damage hit as 7")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 23, "shadow name weak reduces the enemy's next 10 damage hit to 7")
	await _teardown(scene)


func _case_shadow_thread() -> void:
	var card = _load_card("shadow_thread")
	if card == null:
		return
	assert_eq(card.pathway, "fool", "shadow thread loads from the runtime data/cards catalog")
	assert_eq(card.sequence, 8, "shadow thread catalog card sequence")
	assert_eq(card.energy_cost, 2, "shadow thread catalog card cost")
	assert_eq(card.range, 1, "shadow thread catalog card range")
	var player = _make_player(30)
	var enemy = _make_enemy("shadow_thread_target", 40, 3, 10)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 33, "shadow thread deals 10 damage reduced by 3 defense")
	_assert_status_applied_result(scene, "weak", card.id, enemy.id, 5, 0)
	_assert_status_duration(enemy, "weak", 5, "shadow thread applies weak duration 5")
	var weak_label := _status_label_from_scene(scene, "weak")
	var weak_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "weak"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "shadow thread summary keeps source card name")
	_assert_last_action_message_contains(scene, weak_result_text, "shadow thread summary shows readable weak feedback")
	_assert_status_detail_contains(scene, "%s 5" % weak_label, "shadow thread status detail shows weak duration")
	_assert_visible_text_not_contains(scene, "weak", "shadow thread hides raw weak id")
	_assert_visible_text_not_contains(scene, "status_applied", "shadow thread hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "shadow thread hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "shadow thread hides raw dictionary braces")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 7, "shadow thread weak previews the next 10 enemy damage hit as 7")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 23, "shadow thread weak reduces the enemy's next 10 damage hit to 7")
	await _teardown(scene)


func _case_flame_arrow() -> void:
	var base_card = _load_card("flame_arrow")
	if base_card == null:
		return
	assert_eq(base_card.pathway, "common", "flame arrow loads from the runtime skill catalog")
	assert_eq(base_card.sequence, 9, "flame arrow sequence")
	assert_eq(base_card.energy_cost, 12, "flame arrow cost comes from mp_cost")
	assert_eq(base_card.range, 5, "flame arrow range")
	assert_eq(base_card.damage, 16, "flame arrow base damage")
	assert_eq(base_card.target, "single", "flame arrow target mode")
	assert_eq(base_card.status_effects.size(), 1, "flame arrow has one status payload")
	var effect: Dictionary = base_card.status_effects[0] if base_card.status_effects.size() > 0 and base_card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "burning", "flame arrow uses the burning alias payload")
	assert_true(absf(float(effect.get("chance", 0.0)) - 0.3) < 0.001, "flame arrow burn chance is 30 percent")
	assert_eq(int(effect.get("duration", 0)), 3, "flame arrow burn duration")
	assert_eq(int(effect.get("magnitude", 0)), 5, "flame arrow burn magnitude")
	var summary_text := str(base_card.effect_summary_text())
	assert_true(summary_text.contains("燃烧"), "flame arrow card summary localizes burning as burn")
	assert_true(not summary_text.contains("burning"), "flame arrow card summary hides raw burning alias")

	var saw_burn_hit := false
	var saw_burn_miss := false
	for i in range(160):
		var card = _load_card("flame_arrow")
		var enemy = _make_enemy("flame_arrow_target_%d" % i, 40, 4, 0)
		var scene = await _start_scene([card], [enemy])
		seed(42000 + i)
		await _play_direct(scene, card, enemy)
		_assert_card_used(scene, card.id)
		assert_eq(enemy.hp, 28, "flame arrow direct damage is reduced by defense")

		if enemy.has_status("burn"):
			saw_burn_hit = true
			_assert_flame_arrow_burn_hit(scene, card, enemy)
			scene.call("_on_end_turn_pressed")
			await Engine.get_main_loop().process_frame
			assert_eq(enemy.hp, 23, "flame arrow burn deals 5 turn-start DOT")
			_assert_status_duration(enemy, "burn", 2, "flame arrow burn duration ticks after DOT")
		else:
			var miss_result := _find_effect_result_by_reason_id(scene, "chance_missed", "burning")
			if not miss_result.is_empty():
				saw_burn_miss = true
				_assert_flame_arrow_burn_miss(scene, card)
		await _teardown(scene)
		if saw_burn_hit and saw_burn_miss:
			break

	assert_true(saw_burn_hit, "flame arrow real 30 percent chance can apply burn")
	assert_true(saw_burn_miss, "flame arrow real 30 percent chance can miss burn")


func _case_shadow_flame() -> void:
	var card = _load_card("shadow_flame")
	if card == null:
		return
	assert_eq(card.pathway, "common", "shadow flame loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "shadow flame sequence")
	assert_eq(card.energy_cost, 15, "shadow flame cost comes from mp_cost")
	assert_eq(card.range, 4, "shadow flame range")
	assert_eq(card.damage, 18, "shadow flame base damage")
	assert_eq(card.target, "single", "shadow flame target mode")
	assert_eq(card.status_effects.size(), 1, "shadow flame has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "burn", "shadow flame applies the real burn status")
	assert_eq(int(effect.get("duration", 0)), 1, "shadow flame burn duration")
	assert_eq(int(effect.get("magnitude", 0)), 5, "shadow flame burn magnitude")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("burn"), "shadow flame card summary hides raw burn id")

	var enemy = _make_enemy("shadow_flame_target", 50, 6, 0)
	var scene = await _start_scene([card], [enemy])
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 38, "shadow flame deals 18 damage reduced by 6 defense")
	_assert_status_applied_result(scene, "burn", card.id, enemy.id, 1, 5)
	_assert_status_duration(enemy, "burn", 1, "shadow flame applies burn duration 1")
	assert_eq(int(enemy.statuses.get("burn", {}).get("magnitude", 0)), 5, "shadow flame burn status stores magnitude 5")
	var burn_label := _status_label_from_scene(scene, "burn")
	var burn_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "burn"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "shadow flame summary keeps source card name")
	_assert_last_action_message_contains(scene, burn_result_text, "shadow flame summary shows readable burn feedback")
	_assert_status_detail_contains(scene, "%s 1" % burn_label, "shadow flame status detail shows burn duration")
	_assert_status_detail_contains(scene, "5", "shadow flame status detail shows burn magnitude")
	_assert_visible_text_not_contains(scene, "burn", "shadow flame hides raw burn id")
	_assert_visible_text_not_contains(scene, "status_applied", "shadow flame hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "shadow flame hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "shadow flame hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(enemy.hp, 33, "shadow flame burn deals 5 turn-start DOT")
	assert_true(not enemy.has_status("burn"), "shadow flame burn duration 1 expires after DOT")
	await _teardown(scene)


func _case_shadow_water() -> void:
	var card = _load_card("shadow_water")
	if card == null:
		return
	assert_eq(card.pathway, "priestess", "shadow water loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "shadow water sequence")
	assert_eq(card.energy_cost, 12, "shadow water cost comes from mp_cost")
	assert_eq(card.range, 2, "shadow water range")
	assert_eq(card.damage, 10, "shadow water base damage")
	assert_eq(card.target, "aoe", "shadow water target mode is aoe")
	assert_eq(card.status_effects.size(), 1, "shadow water has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "fear", "shadow water applies fear")
	assert_eq(int(effect.get("duration", 0)), 1, "shadow water fear duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("fear"), "shadow water card summary hides raw fear id")

	var player = _make_player(50)
	var enemy_low_def = _make_enemy("shadow_water_low_def", 40, 0, 10)
	var enemy_mid_def = _make_enemy("shadow_water_mid_def", 40, 4, 10)
	var enemy_high_def = _make_enemy("shadow_water_high_def", 40, 20, 10)
	var scene = await _start_scene([card], [enemy_low_def, enemy_mid_def, enemy_high_def], player)
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_eq(enemy_low_def.hp, 30, "shadow water hits the first enemy for 10 damage")
	assert_eq(enemy_mid_def.hp, 34, "shadow water hits the second enemy for 10 damage reduced by 4 defense")
	assert_eq(enemy_high_def.hp, 39, "shadow water high-defense target still takes minimum 1 damage")
	for enemy in [enemy_low_def, enemy_mid_def, enemy_high_def]:
		_assert_status_duration(enemy, "fear", 1, "shadow water applies fear duration 1 to %s" % enemy.id)
	_assert_status_applied_results_for_targets(
		scene,
		"fear",
		[enemy_low_def.id, enemy_mid_def.id, enemy_high_def.id],
		1
	)
	var fear_label := _status_label_from_scene(scene, "fear")
	var fear_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "fear"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "shadow water summary keeps source card name")
	_assert_last_action_message_contains(scene, fear_result_text, "shadow water summary shows readable fear feedback")
	for enemy in [enemy_low_def, enemy_mid_def, enemy_high_def]:
		_assert_status_detail_contains(scene, enemy.id, "shadow water status detail lists %s" % enemy.id)
	_assert_status_detail_contains(scene, "%s 1" % fear_label, "shadow water status detail shows fear duration")
	_assert_visible_text_not_contains(scene, "fear", "shadow water hides raw fear id")
	_assert_visible_text_not_contains(scene, "status_applied", "shadow water hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "shadow water hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "shadow water hides raw dictionary braces")

	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 50, "shadow water fear blocks all three enemy actions on the next enemy turn")
	for enemy in [enemy_low_def, enemy_mid_def, enemy_high_def]:
		assert_true(not enemy.has_status("fear"), "shadow water fear expires after blocking %s action" % enemy.id)
	_assert_status_detail_not_contains(scene, fear_label, "shadow water status detail clears expired fear")
	await _teardown(scene)


func _case_mirror_arrow() -> void:
	var card = _load_card("mirror_arrow")
	if card == null:
		return
	assert_eq(card.pathway, "common", "mirror arrow loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "mirror arrow sequence")
	assert_eq(card.energy_cost, 15, "mirror arrow cost comes from mp_cost")
	assert_eq(card.range, 4, "mirror arrow range")
	assert_eq(card.damage, 20, "mirror arrow base damage")
	assert_eq(card.target, "dual", "mirror arrow target mode is dual")
	assert_eq(card.status_effects.size(), 0, "mirror arrow has no status payload")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("20"), "mirror arrow card summary includes base damage")
	assert_true(not summary_text.contains("dual"), "mirror arrow card summary hides raw dual target id")

	var primary = _make_enemy("mirror_arrow_primary", 40, 5, 0)
	var secondary_mid = _make_enemy("mirror_arrow_secondary_mid", 40, 2, 0)
	var secondary_open = _make_enemy("mirror_arrow_secondary_open", 40, 0, 0)
	var scene = await _start_scene([card], [primary, secondary_mid, secondary_open])
	seed(5100)
	await _play_direct(scene, card, primary)
	_assert_card_used(scene, card.id)
	assert_eq(primary.hp, 25, "mirror arrow explicit primary takes 20 damage reduced by 5 defense")
	var explicit_damaged_others := []
	for enemy in [secondary_mid, secondary_open]:
		if int(enemy.hp) < 40:
			explicit_damaged_others.append(enemy)
	assert_eq(explicit_damaged_others.size(), 1, "mirror arrow explicit target also damages exactly one other living enemy")
	if explicit_damaged_others.size() == 1:
		var selected_other = explicit_damaged_others[0]
		if selected_other == secondary_mid:
			assert_eq(secondary_mid.hp, 22, "mirror arrow second target damage is reduced by 2 defense")
			assert_eq(secondary_open.hp, 40, "mirror arrow leaves the unselected third enemy untouched")
		else:
			assert_eq(secondary_open.hp, 20, "mirror arrow second target with 0 defense takes full 20 damage")
			assert_eq(secondary_mid.hp, 40, "mirror arrow leaves the unselected third enemy untouched")
	_assert_last_action_message_contains(scene, card.get_display_name(), "mirror arrow summary keeps source card name")
	_assert_last_action_message_contains(scene, primary.id, "mirror arrow summary names the explicit primary target")
	if explicit_damaged_others.size() == 1:
		_assert_last_action_message_contains(scene, explicit_damaged_others[0].id, "mirror arrow summary names the random second target")
	_assert_visible_text_not_contains(scene, "dual", "mirror arrow hides raw dual target id")
	_assert_visible_text_not_contains(scene, "{", "mirror arrow hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "mirror arrow hides raw dictionary braces")
	await _teardown(scene)

	var fallback_card = _load_card("mirror_arrow")
	var fallback_a = _make_enemy("mirror_arrow_fallback_a", 40, 0, 0)
	var fallback_b = _make_enemy("mirror_arrow_fallback_b", 40, 0, 0)
	var fallback_c = _make_enemy("mirror_arrow_fallback_c", 40, 0, 0)
	var fallback_scene = await _start_scene([fallback_card], [fallback_a, fallback_b, fallback_c])
	seed(5200)
	await _play_direct(fallback_scene, fallback_card, null)
	_assert_card_used(fallback_scene, fallback_card.id)
	var fallback_damaged := 0
	var fallback_untouched := 0
	for enemy in [fallback_a, fallback_b, fallback_c]:
		if int(enemy.hp) == 20:
			fallback_damaged += 1
		elif int(enemy.hp) == 40:
			fallback_untouched += 1
		else:
			assert_true(false, "mirror arrow no-target fallback only produces 20 damage or no damage for %s" % enemy.id)
	assert_eq(fallback_damaged, 2, "mirror arrow no-target fallback damages exactly two living enemies")
	assert_eq(fallback_untouched, 1, "mirror arrow no-target fallback leaves exactly one living enemy untouched")
	await _teardown(fallback_scene)


func _case_shadow_arrow() -> void:
	var card = _load_card("shadow_arrow")
	if card == null:
		return
	assert_eq(card.pathway, "common", "shadow arrow loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "shadow arrow sequence")
	assert_eq(card.energy_cost, 10, "shadow arrow cost comes from mp_cost")
	assert_eq(card.range, 5, "shadow arrow range")
	assert_eq(card.damage, 12, "shadow arrow base damage")
	assert_eq(card.target, "single", "shadow arrow target mode is single")
	assert_eq(card.status_effects.size(), 0, "shadow arrow has no status payload")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("12"), "shadow arrow card summary includes base damage")
	assert_true(not summary_text.contains("single"), "shadow arrow card summary hides raw single target id")

	var target = _make_enemy("shadow_arrow_target", 40, 3, 0)
	var untouched = _make_enemy("shadow_arrow_untouched", 40, 0, 0)
	var scene = await _start_scene([card], [target, untouched])
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 31, "shadow arrow deals 12 damage reduced by 3 defense")
	assert_eq(untouched.hp, 40, "shadow arrow leaves non-target enemies untouched")
	_assert_last_action_message_contains(scene, card.get_display_name(), "shadow arrow summary keeps source card name")
	_assert_last_action_message_contains(scene, target.id, "shadow arrow summary names the damaged target")
	_assert_visible_text_not_contains(scene, "single", "shadow arrow hides raw single target id")
	_assert_visible_text_not_contains(scene, "{", "shadow arrow hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "shadow arrow hides raw dictionary braces")
	await _teardown(scene)

	var high_def_card = _load_card("shadow_arrow")
	var high_def_target = _make_enemy("shadow_arrow_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target])
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "shadow arrow high-defense target still takes minimum 1 damage")
	await _teardown(high_def_scene)


func _case_water_touch() -> void:
	var card = _load_card("water_touch")
	if card == null:
		return
	assert_eq(card.pathway, "common", "water touch loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "water touch sequence")
	assert_eq(card.energy_cost, 6, "water touch cost comes from mp_cost")
	assert_eq(card.range, 1, "water touch range")
	assert_eq(card.damage, 0, "water touch has no damage")
	assert_eq(card.heal, 12, "water touch heal amount")
	assert_eq(card.target, "self", "water touch target mode is self")
	assert_eq(card.status_effects.size(), 0, "water touch has no status payload")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("12"), "water touch card summary includes heal amount")
	assert_true(not summary_text.contains("self"), "water touch card summary hides raw self target id")

	var player = _make_player(20)
	player.max_hp = 50
	var enemy = _make_enemy("water_touch_enemy", 40, 0, 0)
	var scene = await _start_scene([card], [enemy], player)
	await _play_direct(scene, card, scene._player)
	_assert_card_used(scene, card.id)
	assert_eq(player.hp, 32, "water touch heals the player by 12 through the self-target BattleScene path")
	assert_eq(enemy.hp, 40, "water touch does not damage or heal enemies")
	_assert_last_action_message_contains(scene, card.get_display_name(), "water touch summary keeps source card name")
	_assert_last_action_message_contains(scene, "12", "water touch summary shows the healed amount")
	_assert_visible_text_not_contains(scene, "self", "water touch hides raw self target id")
	_assert_visible_text_not_contains(scene, "{", "water touch hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "water touch hides raw dictionary braces")
	await _teardown(scene)

	var capped_card = _load_card("water_touch")
	var capped_player = _make_player(45)
	capped_player.max_hp = 50
	var capped_enemy = _make_enemy("water_touch_cap_enemy", 40, 0, 0)
	var capped_scene = await _start_scene([capped_card], [capped_enemy], capped_player)
	await _play_direct(capped_scene, capped_card, capped_scene._player)
	_assert_card_used(capped_scene, capped_card.id)
	assert_eq(capped_player.hp, 50, "water touch healing is capped at player max hp")
	assert_eq(capped_enemy.hp, 40, "water touch cap branch still leaves enemies untouched")
	_assert_last_action_message_contains(capped_scene, "5", "water touch cap branch summary shows actual healed amount")
	await _teardown(capped_scene)


func _case_tower_s9_night_pebble() -> void:
	var card = _load_card("tower_s9_night_pebble")
	if card == null:
		return
	assert_eq(card.pathway, "tower", "night pebble loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "night pebble sequence")
	assert_eq(card.energy_cost, 1, "night pebble cost comes from mp_cost")
	assert_eq(card.range, 4, "night pebble range")
	assert_eq(card.damage, 7, "night pebble base damage")
	assert_eq(card.target, "single", "night pebble target mode")
	assert_eq(card.status_effects.size(), 1, "night pebble has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "blind", "night pebble applies blind")
	assert_eq(int(effect.get("duration", 0)), 1, "night pebble blind duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("7"), "night pebble card summary includes base damage")
	assert_true(not summary_text.contains("blind"), "night pebble card summary hides raw blind id")

	var player = _make_player(30)
	var enemy = _make_enemy("night_pebble_target", 40, 0, 10)
	var scene = await _start_scene([card], [enemy], player, _game_state(9))
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 33, "night pebble deals 7 damage to a zero-defense enemy")
	_assert_status_applied_result(scene, "blind", card.id, enemy.id, 1, 0)
	_assert_status_duration(enemy, "blind", 1, "night pebble applies blind duration 1")
	var blind_label := _status_label_from_scene(scene, "blind")
	var blind_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "blind"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "night pebble summary keeps source card name")
	_assert_last_action_message_contains(scene, blind_result_text, "night pebble summary shows readable blind feedback")
	_assert_status_detail_contains(scene, "%s 1" % blind_label, "night pebble status detail shows blind duration")
	_assert_visible_text_not_contains(scene, "blind", "night pebble hides raw blind id")
	_assert_visible_text_not_contains(scene, "status_applied", "night pebble hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "night pebble hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "night pebble hides raw dictionary braces")
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 5, "night pebble blind previews the next 10 enemy damage hit as 5")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 25, "night pebble blind halves the enemy's next 10 damage hit")
	assert_true(not enemy.has_status("blind"), "night pebble blind expires after the affected enemy acts")
	_assert_status_detail_not_contains(scene, blind_label, "night pebble status detail clears expired blind")
	await _teardown(scene)


func _case_tower_s9_quiet_step() -> void:
	var card = _load_card("tower_s9_quiet_step")
	if card == null:
		return
	assert_eq(card.pathway, "tower", "quiet step loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "quiet step sequence")
	assert_eq(card.energy_cost, 0, "quiet step cost comes from mp_cost")
	assert_eq(card.range, 0, "quiet step range")
	assert_eq(card.damage, 0, "quiet step base damage")
	assert_eq(card.target, "self", "quiet step target mode")
	assert_eq(card.status_effects.size(), 2, "quiet step has two status payloads")
	var ids := []
	for raw_effect in card.status_effects:
		if raw_effect is Dictionary:
			ids.append(str((raw_effect as Dictionary).get("id", "")))
	assert_true("stealth" in ids, "quiet step applies stealth")
	assert_true("next_attack_damage_delta" in ids, "quiet step applies next attack damage delta")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("stealth"), "quiet step card summary hides raw stealth id")
	assert_true(not summary_text.contains("next_attack_damage_delta"), "quiet step card summary hides raw next-attack id")

	var player = _make_player(30)
	var enemy = _make_enemy("quiet_step_attacker", 40, 2, 10)
	var follow_up = _attack_card("quiet_step_followup_attack", 10)
	follow_up.sequence = 9
	var scene = await _start_scene([card, follow_up], [enemy], player, _game_state(9))
	await _play_direct(scene, card, scene._player)
	_assert_card_used(scene, card.id)
	assert_true(card in scene._battle.discard_pile, "quiet step reaches discard after BattleScene play")
	_assert_status_applied_result(scene, "stealth", card.id, "player", 1, 0)
	_assert_status_duration(player, "stealth", 1, "quiet step applies stealth duration 1")
	_assert_next_attack_damage_delta_status(player, 3, 1)
	_assert_next_attack_damage_delta_result(scene, card.id, "player", 3, 1)
	var stealth_label := _status_label_from_scene(scene, "stealth")
	var delta_label := _status_label_from_scene(scene, "next_attack_damage_delta")
	var delta_result := _find_effect_result_by_reason_id(scene, "next_attack_damage_delta_applied", "next_attack_damage_delta")
	var delta_result_text := _effect_result_text_from_scene(scene, delta_result)
	_assert_last_action_message_contains(scene, card.get_display_name(), "quiet step summary keeps source card name")
	_assert_last_action_message_contains(scene, stealth_label, "quiet step summary shows readable stealth feedback")
	_assert_last_action_message_contains(scene, delta_result_text, "quiet step summary shows readable next-attack feedback")
	_assert_status_detail_contains(scene, "%s 1" % stealth_label, "quiet step status detail shows stealth duration")
	_assert_status_detail_contains(scene, "%s 1" % delta_label, "quiet step status detail shows next-attack duration")
	_assert_status_detail_contains(scene, "3", "quiet step status detail shows next-attack magnitude")
	_assert_visible_text_not_contains(scene, "stealth", "quiet step hides raw stealth id")
	_assert_visible_text_not_contains(scene, "next_attack_damage_delta", "quiet step hides raw next_attack_damage_delta id")
	_assert_visible_text_not_contains(scene, "next_attack_damage_delta_applied", "quiet step hides raw next_attack_damage_delta_applied reason")
	_assert_visible_text_not_contains(scene, "{", "quiet step hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "quiet step hides raw dictionary braces")

	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
	assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 0, "quiet step stealth previews the next 10 enemy damage hit as 0")
	await _play_direct(scene, follow_up, enemy)
	_assert_card_used(scene, follow_up.id)
	assert_eq(enemy.hp, 29, "quiet step next-attack delta makes 10 damage hit deal 11 after 2 defense")
	assert_true(not player.has_status("next_attack_damage_delta"), "quiet step consumes next-attack delta after the next outgoing hit")
	assert_true(player.has_status("stealth"), "quiet step keeps stealth until the next incoming hit")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 30, "quiet step stealth prevents the next enemy hit")
	assert_true(not player.has_status("stealth"), "quiet step stealth expires after blocking the next incoming hit")
	_assert_status_detail_not_contains(scene, stealth_label, "quiet step status detail clears consumed stealth")
	_assert_status_detail_not_contains(scene, delta_label, "quiet step status detail clears consumed next-attack delta")
	await _teardown(scene)


func _case_tower_s8_moonless_field() -> void:
	var card = _load_card("tower_s8_moonless_field")
	if card == null:
		return
	assert_eq(card.pathway, "tower", "moonless field loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "moonless field sequence")
	assert_eq(card.energy_cost, 1, "moonless field cost comes from mp_cost")
	assert_eq(card.range, 5, "moonless field range")
	assert_eq(card.damage, 0, "moonless field has no direct damage")
	assert_eq(card.target, "all_enemies", "moonless field target mode is all_enemies")
	assert_eq(card.status_effects.size(), 2, "moonless field has two status payloads")
	var ids := []
	for raw_effect in card.status_effects:
		if raw_effect is Dictionary:
			var effect: Dictionary = raw_effect
			ids.append(str(effect.get("id", "")))
			if str(effect.get("id", "")) == "obscure_intent":
				assert_eq(int(effect.get("duration", 0)), 1, "moonless field obscure_intent duration")
			if str(effect.get("id", "")) == "weak":
				assert_eq(int(effect.get("duration", 0)), 1, "moonless field weak duration")
	assert_true("obscure_intent" in ids, "moonless field applies obscure_intent")
	assert_true("weak" in ids, "moonless field applies weak")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("obscure_intent"), "moonless field card summary hides raw obscure_intent id")
	assert_true(not summary_text.contains("weak"), "moonless field card summary hides raw weak id")

	var player = _make_player(50)
	var enemy_a = _make_enemy("moonless_field_a", 40, 0, 10)
	var enemy_b = _make_enemy("moonless_field_b", 40, 4, 10)
	var enemy_c = _make_enemy("moonless_field_c", 40, 20, 10)
	var enemies := [enemy_a, enemy_b, enemy_c]
	var scene = await _start_scene([card], enemies, player, _game_state(8))
	for enemy in enemies:
		var before_intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
		assert_true(not before_intent.is_empty(), "moonless field starts with intent data for %s" % enemy.id)
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	for enemy in enemies:
		assert_eq(enemy.hp, 40, "moonless field does not directly damage %s" % enemy.id)
		_assert_status_duration(enemy, "obscure_intent", 1, "moonless field applies obscure_intent duration 1 to %s" % enemy.id)
		_assert_status_duration(enemy, "weak", 1, "moonless field applies weak duration 1 to %s" % enemy.id)
	var enemy_ids := _actor_ids_from(enemies)
	_assert_status_applied_results_for_targets(scene, "obscure_intent", enemy_ids, 1)
	_assert_status_applied_results_for_targets(scene, "weak", enemy_ids, 1)
	var obscure_label := _status_label_from_scene(scene, "obscure_intent")
	var weak_label := _status_label_from_scene(scene, "weak")
	var obscure_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "obscure_intent"})
	var weak_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "weak"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "moonless field summary keeps source card name")
	_assert_last_action_message_contains(scene, obscure_result_text, "moonless field summary shows readable obscure-intent feedback")
	_assert_last_action_message_contains(scene, weak_result_text, "moonless field summary shows readable weak feedback")
	for enemy in enemies:
		_assert_status_detail_contains(scene, enemy.id, "moonless field status detail lists %s" % enemy.id)
	_assert_status_detail_contains(scene, "%s 1" % obscure_label, "moonless field status detail shows obscure-intent duration")
	_assert_status_detail_contains(scene, "%s 1" % weak_label, "moonless field status detail shows weak duration")
	var visible_text := _collect_label_text(scene)
	assert_eq(visible_text.count("被遮蔽"), 3, "moonless field masks all three enemy intent rows")
	_assert_visible_text_not_contains(scene, "obscure_intent", "moonless field hides raw obscure_intent id")
	_assert_visible_text_not_contains(scene, "weak", "moonless field hides raw weak id")
	_assert_visible_text_not_contains(scene, "status_applied", "moonless field hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "moonless field hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "moonless field hides raw dictionary braces")
	for enemy in enemies:
		var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
		assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 7, "moonless field weak previews %s next 10 damage hit as 7" % enemy.id)
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 29, "moonless field weak reduces three enemy 10 damage hits to 7 each")
	for enemy in enemies:
		assert_true(not enemy.has_status("weak"), "moonless field weak expires after %s acts" % enemy.id)
		assert_true(not enemy.has_status("obscure_intent"), "moonless field obscure_intent expires after %s acts" % enemy.id)
	_assert_status_detail_not_contains(scene, weak_label, "moonless field status detail clears expired weak")
	_assert_status_detail_not_contains(scene, obscure_label, "moonless field status detail clears expired obscure_intent")
	await _teardown(scene)


func _case_tower_s8_shadow_claw() -> void:
	var card = _load_card("tower_s8_shadow_claw")
	if card == null:
		return
	assert_eq(card.pathway, "tower", "shadow claw loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "shadow claw sequence")
	assert_eq(card.energy_cost, 1, "shadow claw cost comes from mp_cost")
	assert_eq(card.range, 3, "shadow claw range")
	assert_eq(card.damage, 10, "shadow claw base damage")
	assert_eq(card.target, "single", "shadow claw target mode is single")
	assert_eq(card.status_effects.size(), 1, "shadow claw has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "root", "shadow claw applies root")
	assert_eq(int(effect.get("duration", 0)), 1, "shadow claw root duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("10"), "shadow claw card summary includes base damage")
	assert_true(not summary_text.contains("root"), "shadow claw card summary hides raw root id")

	var player = _make_player(50)
	var target = _make_enemy("shadow_claw_target", 40, 4, 10)
	var untouched = _make_enemy("shadow_claw_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(8))
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 34, "shadow claw deals 10 damage reduced by target defense")
	assert_eq(untouched.hp, 40, "shadow claw leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "root", card.id, target.id, 1, 0)
	_assert_status_duration(target, "root", 1, "shadow claw applies root duration 1")
	assert_true(not untouched.has_status("root"), "shadow claw does not root the untargeted enemy")
	var root_label := _status_label_from_scene(scene, "root")
	var root_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "root"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "shadow claw summary keeps source card name")
	_assert_last_action_message_contains(scene, root_result_text, "shadow claw summary shows readable root feedback")
	_assert_status_detail_contains(scene, target.id, "shadow claw status detail lists the rooted target")
	_assert_status_detail_contains(scene, "%s 1" % root_label, "shadow claw status detail shows root duration")
	_assert_visible_text_not_contains(scene, "root", "shadow claw hides raw root id")
	_assert_visible_text_not_contains(scene, "status_applied", "shadow claw hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "shadow claw hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "shadow claw hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "shadow claw root blocks only the rooted enemy action")
	assert_true(not target.has_status("root"), "shadow claw root expires after the rooted enemy skips action")
	_assert_status_detail_not_contains(scene, root_label, "shadow claw status detail clears expired root")
	await _teardown(scene)

	var high_def_card = _load_card("tower_s8_shadow_claw")
	var high_def_target = _make_enemy("shadow_claw_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(8))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "shadow claw still deals minimum 1 damage to a high-defense target")
	_assert_status_duration(high_def_target, "root", 1, "shadow claw roots a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_tower_s7_dream_eclipse() -> void:
	var card = _load_card("tower_s7_dream_eclipse")
	if card == null:
		return
	assert_eq(card.pathway, "tower", "dream eclipse loads from the runtime skill catalog")
	assert_eq(card.sequence, 7, "dream eclipse sequence")
	assert_eq(card.energy_cost, 2, "dream eclipse cost comes from mp_cost")
	assert_eq(card.range, 5, "dream eclipse range")
	assert_eq(card.damage, 13, "dream eclipse base damage")
	assert_eq(card.target, "all_enemies", "dream eclipse target mode is all_enemies")
	assert_eq(card.status_effects.size(), 2, "dream eclipse has two status payloads")
	var effect_ids := []
	for raw_effect in card.status_effects:
		if not raw_effect is Dictionary:
			continue
		var effect: Dictionary = raw_effect
		var effect_id := str(effect.get("id", ""))
		effect_ids.append(effect_id)
		if effect_id == "confusion":
			assert_eq(int(effect.get("duration", 0)), 1, "dream eclipse confusion duration")
		if effect_id == "nightmare":
			assert_eq(int(effect.get("duration", 0)), 2, "dream eclipse nightmare duration")
	assert_true("confusion" in effect_ids, "dream eclipse applies confusion")
	assert_true("nightmare" in effect_ids, "dream eclipse applies nightmare")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("13"), "dream eclipse card summary includes base damage")
	assert_true(not summary_text.contains("confusion"), "dream eclipse card summary hides raw confusion id")
	assert_true(not summary_text.contains("nightmare"), "dream eclipse card summary hides raw nightmare id")

	var player = _make_player(50)
	var enemy_a = _make_enemy("dream_eclipse_a", 40, 0, 8)
	var enemy_b = _make_enemy("dream_eclipse_b", 40, 4, 0)
	var enemy_c = _make_enemy("dream_eclipse_c", 40, 20, 0)
	var enemies := [enemy_a, enemy_b, enemy_c]
	var scene = await _start_scene([card], enemies, player, _game_state(7))
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_eq(enemy_a.hp, 27, "dream eclipse deals full 13 damage to 0 DEF enemy")
	assert_eq(enemy_b.hp, 31, "dream eclipse damage is reduced by target defense")
	assert_eq(enemy_c.hp, 39, "dream eclipse still deals minimum 1 damage to high DEF enemy")
	for enemy in enemies:
		_assert_status_duration(enemy, "confusion", 1, "dream eclipse applies confusion duration 1 to %s" % enemy.id)
		_assert_status_duration(enemy, "nightmare", 2, "dream eclipse applies nightmare duration 2 to %s" % enemy.id)
		_assert_status_duration(enemy, "vulnerable", 2, "dream eclipse nightmare also applies vulnerable duration 2 to %s" % enemy.id)
		var vulnerable_payload: Dictionary = enemy.statuses.get("vulnerable", {}) if enemy.statuses.get("vulnerable", {}) is Dictionary else {}
		assert_eq(str(vulnerable_payload.get("id", "")), "vulnerable", "dream eclipse vulnerable payload id is explicit for %s" % enemy.id)
	var enemy_ids := _actor_ids_from(enemies)
	_assert_status_applied_results_for_targets(scene, "confusion", enemy_ids, 1)
	_assert_status_applied_results_for_targets(scene, "nightmare", enemy_ids, 2)
	var confusion_label := _status_label_from_scene(scene, "confusion")
	var nightmare_label := _status_label_from_scene(scene, "nightmare")
	var vulnerable_label := _status_label_from_scene(scene, "vulnerable")
	var confusion_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "confusion"})
	var nightmare_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "nightmare"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "dream eclipse summary keeps source card name")
	_assert_last_action_message_contains(scene, confusion_result_text, "dream eclipse summary shows readable confusion feedback")
	_assert_last_action_message_contains(scene, nightmare_result_text, "dream eclipse summary shows readable nightmare feedback")
	for enemy in enemies:
		_assert_status_detail_contains(scene, enemy.id, "dream eclipse status detail lists %s" % enemy.id)
	_assert_status_detail_contains(scene, "%s 1" % confusion_label, "dream eclipse status detail shows confusion duration")
	_assert_status_detail_contains(scene, "%s 2" % nightmare_label, "dream eclipse status detail shows nightmare duration")
	_assert_status_detail_contains(scene, "%s 2" % vulnerable_label, "dream eclipse status detail shows vulnerable from nightmare")
	_assert_visible_text_not_contains(scene, "confusion", "dream eclipse hides raw confusion id")
	_assert_visible_text_not_contains(scene, "nightmare", "dream eclipse hides raw nightmare id")
	_assert_visible_text_not_contains(scene, "status_applied", "dream eclipse hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "dream eclipse hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "dream eclipse hides raw dictionary braces")

	scene._battle.field_state["confusion_redirect_chance_override"] = 1.0
	scene._battle.current_enemy_intents.clear()
	scene._battle.current_enemy_intents[enemy_a.id] = {"action": "use_skill", "skill": "hit"}
	scene._battle.current_enemy_intents[enemy_b.id] = {"action": "defend"}
	scene._battle.current_enemy_intents[enemy_c.id] = {"action": "defend"}
	var player_hp_before := int(player.hp)
	var redirect_b_hp_before := int(enemy_b.hp)
	var redirect_c_hp_before := int(enemy_c.hp)
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(int(player.hp), player_hp_before, "dream eclipse forced confusion redirect prevents enemy damage to the player")
	var redirected_to_b := int(enemy_b.hp) == redirect_b_hp_before - 6 and int(enemy_c.hp) == redirect_c_hp_before
	var redirected_to_c := int(enemy_c.hp) == redirect_c_hp_before - 1 and int(enemy_b.hp) == redirect_b_hp_before
	assert_true(redirected_to_b or redirected_to_c, "dream eclipse redirected hit damages one other living enemy and respects that target's DEF/vulnerable math")
	for enemy in enemies:
		assert_true(not enemy.has_status("confusion"), "dream eclipse confusion expires after %s acts or skips" % enemy.id)
		_assert_status_duration(enemy, "nightmare", 1, "dream eclipse nightmare ticks after first affected enemy turn for %s" % enemy.id)
		_assert_status_duration(enemy, "vulnerable", 1, "dream eclipse vulnerable ticks with nightmare for %s" % enemy.id)
	_assert_status_detail_not_contains(scene, confusion_label, "dream eclipse status detail clears expired confusion")
	_assert_status_detail_contains(scene, "%s 1" % nightmare_label, "dream eclipse status detail shows nightmare after first tick")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	for enemy in enemies:
		assert_true(not enemy.has_status("nightmare"), "dream eclipse nightmare expires after the second affected enemy turn for %s" % enemy.id)
		assert_true(not enemy.has_status("vulnerable"), "dream eclipse vulnerable from nightmare expires with nightmare for %s" % enemy.id)
	_assert_status_detail_not_contains(scene, nightmare_label, "dream eclipse status detail clears expired nightmare")
	_assert_status_detail_not_contains(scene, vulnerable_label, "dream eclipse status detail clears expired vulnerable")
	await _teardown(scene)


func _case_priestess_s9_key_turn() -> void:
	var card = _load_card("priestess_s9_key_turn")
	if card == null:
		return
	assert_eq(card.pathway, "priestess", "key turn loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "key turn sequence")
	assert_eq(card.energy_cost, 1, "key turn cost comes from mp_cost")
	assert_eq(card.range, 4, "key turn range")
	assert_eq(card.damage, 5, "key turn base damage")
	assert_eq(card.target, "single", "key turn target mode is single")
	assert_eq(card.status_effects.size(), 1, "key turn has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "delay_intent", "key turn applies delay_intent")
	assert_eq(int(effect.get("duration", 0)), 1, "key turn delay_intent duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("5"), "key turn card summary includes base damage")
	assert_true(summary_text.contains("延迟意图"), "key turn card summary localizes delay_intent")
	assert_true(not summary_text.contains("delay_intent"), "key turn card summary hides raw delay_intent id")

	var player = _make_player(50)
	var target = _make_enemy("key_turn_target", 40, 2, 10)
	var untouched = _make_enemy("key_turn_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(9))
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 37, "key turn deals 5 damage reduced by target defense")
	assert_eq(untouched.hp, 40, "key turn leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "delay_intent", card.id, target.id, 1, 0)
	_assert_status_duration(target, "delay_intent", 1, "key turn applies delay_intent duration 1")
	assert_true(not untouched.has_status("delay_intent"), "key turn does not delay the untargeted enemy")
	var delay_label := _status_label_from_scene(scene, "delay_intent")
	var delay_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "delay_intent"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "key turn summary keeps source card name")
	_assert_last_action_message_contains(scene, delay_result_text, "key turn summary shows readable delay-intent feedback")
	_assert_status_detail_contains(scene, target.id, "key turn status detail lists the delayed target")
	_assert_status_detail_contains(scene, "%s 1" % delay_label, "key turn status detail shows delay_intent duration")
	_assert_visible_text_not_contains(scene, "delay_intent", "key turn hides raw delay_intent id")
	_assert_visible_text_not_contains(scene, "status_applied", "key turn hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "key turn hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "key turn hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "key turn blocks only the delayed enemy action")
	assert_true(not target.has_status("delay_intent"), "key turn delay_intent expires after the delayed enemy skips action")
	_assert_status_detail_not_contains(scene, delay_label, "key turn status detail clears expired delay_intent")
	await _teardown(scene)

	var high_def_card = _load_card("priestess_s9_key_turn")
	var high_def_target = _make_enemy("key_turn_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(9))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "key turn still deals minimum 1 damage to a high-defense target")
	_assert_status_duration(high_def_target, "delay_intent", 1, "key turn delays a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_priestess_s9_mist_bolt() -> void:
	var card = _load_card("priestess_s9_mist_bolt")
	if card == null:
		return
	assert_eq(card.pathway, "priestess", "mist bolt loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "mist bolt sequence")
	assert_eq(card.energy_cost, 1, "mist bolt cost comes from mp_cost")
	assert_eq(card.range, 5, "mist bolt range")
	assert_eq(card.damage, 7, "mist bolt base damage")
	assert_eq(card.target, "single", "mist bolt target mode is single")
	assert_eq(card.status_effects.size(), 1, "mist bolt has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "slow", "mist bolt applies slow")
	assert_eq(int(effect.get("duration", 0)), 1, "mist bolt slow duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("7"), "mist bolt card summary includes base damage")
	assert_true(not summary_text.contains("slow"), "mist bolt card summary hides raw slow id")

	var player = _make_player(50)
	var target = _make_enemy("mist_bolt_target", 40, 3, 10)
	var untouched = _make_enemy("mist_bolt_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(9))
	var slow_label := _status_label_from_scene(scene, "slow")
	assert_true(summary_text.contains(slow_label), "mist bolt card summary uses the same readable slow label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 36, "mist bolt deals 7 damage reduced by target defense")
	assert_eq(untouched.hp, 40, "mist bolt leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "slow", card.id, target.id, 1, 0)
	_assert_status_duration(target, "slow", 1, "mist bolt applies slow duration 1")
	assert_true(not untouched.has_status("slow"), "mist bolt does not slow the untargeted enemy")
	var slow_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "slow"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "mist bolt summary keeps source card name")
	_assert_last_action_message_contains(scene, slow_result_text, "mist bolt summary shows readable slow feedback")
	_assert_status_detail_contains(scene, target.id, "mist bolt status detail lists the slowed target")
	_assert_status_detail_contains(scene, "%s 1" % slow_label, "mist bolt status detail shows slow duration")
	_assert_visible_text_not_contains(scene, "slow", "mist bolt hides raw slow id")
	_assert_visible_text_not_contains(scene, "status_applied", "mist bolt hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "mist bolt hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "mist bolt hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "mist bolt blocks only the slowed enemy action")
	assert_true(not target.has_status("slow"), "mist bolt slow expires after the slowed enemy skips action")
	_assert_status_detail_not_contains(scene, slow_label, "mist bolt status detail clears expired slow")
	await _teardown(scene)

	var high_def_card = _load_card("priestess_s9_mist_bolt")
	var high_def_target = _make_enemy("mist_bolt_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(9))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "mist bolt still deals minimum 1 damage to a high-defense target")
	_assert_status_duration(high_def_target, "slow", 1, "mist bolt slows a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_emperor_s9_contract_bind() -> void:
	var card = _load_card("emperor_s9_contract_bind")
	if card == null:
		return
	assert_eq(card.pathway, "emperor", "contract bind loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "contract bind sequence")
	assert_eq(card.energy_cost, 1, "contract bind cost comes from mp_cost")
	assert_eq(card.range, 4, "contract bind range")
	assert_eq(card.damage, 6, "contract bind base damage")
	assert_eq(card.target, "single", "contract bind target mode is single")
	assert_eq(card.status_effects.size(), 1, "contract bind has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "bind", "contract bind applies bind")
	assert_eq(int(effect.get("duration", 0)), 1, "contract bind bind duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("6"), "contract bind card summary includes base damage")
	assert_true(not summary_text.contains("bind"), "contract bind card summary hides raw bind id")

	var player = _make_player(50)
	var target = _make_enemy("contract_target", 40, 2, 10)
	var untouched = _make_enemy("contract_untouched", 40, 0, 10)
	var scene = await _start_scene([card], [target, untouched], player, _game_state(9))
	var bind_label := _status_label_from_scene(scene, "bind")
	assert_true(summary_text.contains(bind_label), "contract bind card summary uses the same readable bind label as BattleScene")
	await _play_direct(scene, card, target)
	_assert_card_used(scene, card.id)
	assert_eq(target.hp, 36, "contract bind deals 6 damage reduced by target defense")
	assert_eq(untouched.hp, 40, "contract bind leaves the untargeted enemy untouched")
	_assert_status_applied_result(scene, "bind", card.id, target.id, 1, 0)
	_assert_status_duration(target, "bind", 1, "contract bind applies bind duration 1")
	assert_true(not untouched.has_status("bind"), "contract bind does not bind the untargeted enemy")
	var bind_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "bind"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "contract bind summary keeps source card name")
	_assert_last_action_message_contains(scene, bind_result_text, "contract bind summary shows readable bind feedback")
	_assert_status_detail_contains(scene, target.id, "contract bind status detail lists the bound target")
	_assert_status_detail_contains(scene, "%s 1" % bind_label, "contract bind status detail shows bind duration")
	_assert_visible_text_not_contains(scene, "bind", "contract bind hides raw bind id")
	_assert_visible_text_not_contains(scene, "status_applied", "contract bind hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "contract bind hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "contract bind hides raw dictionary braces")
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 40, "contract bind blocks only the bound enemy action")
	assert_true(not target.has_status("bind"), "contract bind expires after the bound enemy skips action")
	_assert_status_detail_not_contains(scene, bind_label, "contract bind status detail clears expired bind")
	await _teardown(scene)

	var high_def_card = _load_card("emperor_s9_contract_bind")
	var high_def_target = _make_enemy("contract_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(9))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "contract bind still deals minimum 1 damage to a high-defense target")
	_assert_status_duration(high_def_target, "bind", 1, "contract bind binds a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_emperor_s9_legal_notice() -> void:
	var card = _load_card("emperor_s9_legal_notice")
	if card == null:
		return
	assert_eq(card.pathway, "emperor", "legal notice loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "legal notice sequence")
	assert_eq(card.energy_cost, 1, "legal notice cost comes from mp_cost")
	assert_eq(card.range, 5, "legal notice range")
	assert_eq(card.damage, 0, "legal notice has no direct damage")
	assert_eq(card.target, "all_enemies", "legal notice target mode is all_enemies")
	assert_eq(card.status_effects.size(), 1, "legal notice has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "weak", "legal notice applies weak")
	assert_eq(int(effect.get("duration", 0)), 1, "legal notice weak duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("weak"), "legal notice card summary hides raw weak id")

	var player = _make_player(50)
	var enemy_a = _make_enemy("legal_notice_a", 40, 0, 10)
	var enemy_b = _make_enemy("legal_notice_b", 40, 4, 10)
	var enemy_c = _make_enemy("legal_notice_c", 40, 20, 10)
	var enemies := [enemy_a, enemy_b, enemy_c]
	var scene = await _start_scene([card], enemies, player, _game_state(9))
	var weak_label := _status_label_from_scene(scene, "weak")
	assert_true(summary_text.contains(weak_label), "legal notice card summary uses the same readable weak label as BattleScene")
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	for enemy in enemies:
		assert_eq(enemy.hp, 40, "legal notice does not directly damage %s" % enemy.id)
		_assert_status_duration(enemy, "weak", 1, "legal notice applies weak duration 1 to %s" % enemy.id)
	var enemy_ids := _actor_ids_from(enemies)
	_assert_status_applied_results_for_targets(scene, "weak", enemy_ids, 1)
	var weak_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "weak"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "legal notice summary keeps source card name")
	_assert_last_action_message_contains(scene, weak_result_text, "legal notice summary shows readable weak feedback")
	for enemy in enemies:
		_assert_status_detail_contains(scene, enemy.id, "legal notice status detail lists %s" % enemy.id)
	_assert_status_detail_contains(scene, "%s 1" % weak_label, "legal notice status detail shows weak duration")
	_assert_visible_text_not_contains(scene, "weak", "legal notice hides raw weak id")
	_assert_visible_text_not_contains(scene, "status_applied", "legal notice hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "legal notice hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "legal notice hides raw dictionary braces")
	for enemy in enemies:
		var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy.id, {})
		assert_eq(scene._battle.preview_enemy_intent_damage(enemy, intent), 7, "legal notice weak previews %s next 10 damage hit as 7" % enemy.id)
	scene.call("_on_end_turn_pressed")
	await Engine.get_main_loop().process_frame
	assert_eq(player.hp, 29, "legal notice weak reduces three enemy 10 damage hits to 7 each")
	for enemy in enemies:
		assert_true(not enemy.has_status("weak"), "legal notice weak expires after %s acts" % enemy.id)
	_assert_status_detail_not_contains(scene, weak_label, "legal notice status detail clears expired weak")
	await _teardown(scene)


func _case_emperor_s8_debt_mark() -> void:
	var card = _load_card("emperor_s8_debt_mark")
	if card == null:
		return
	assert_eq(card.pathway, "emperor", "debt mark loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "debt mark sequence")
	assert_eq(card.energy_cost, 1, "debt mark cost comes from mp_cost")
	assert_eq(card.range, 4, "debt mark range")
	assert_eq(card.damage, 8, "debt mark base damage")
	assert_eq(card.target, "single", "debt mark target mode is single")
	assert_eq(card.status_effects.size(), 1, "debt mark has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "vulnerable", "debt mark applies vulnerable")
	assert_eq(int(effect.get("duration", 0)), 1, "debt mark vulnerable duration")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("vulnerable"), "debt mark card summary hides raw vulnerable id")

	var follow_up = _attack_card("debt_mark_follow_up", 10, 8)
	var enemy = _make_enemy("debt_mark_target", 40, 3, 0)
	var scene = await _start_scene([card, follow_up], [enemy], _make_player(50), _game_state(8))
	var vulnerable_label := _status_label_from_scene(scene, "vulnerable")
	assert_true(summary_text.contains(vulnerable_label), "debt mark card summary uses the same readable vulnerable label as BattleScene")
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 35, "debt mark deals 8 damage reduced by 3 defense before vulnerable is applied")
	_assert_status_applied_result(scene, "vulnerable", card.id, enemy.id, 1, 0)
	_assert_status_duration(enemy, "vulnerable", 1, "debt mark applies vulnerable duration 1")
	var vulnerable_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "vulnerable"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "debt mark summary keeps source card name")
	_assert_last_action_message_contains(scene, vulnerable_result_text, "debt mark summary shows readable vulnerable feedback")
	_assert_status_detail_contains(scene, "%s 1" % vulnerable_label, "debt mark status detail shows vulnerable duration")
	_assert_visible_text_not_contains(scene, "vulnerable", "debt mark hides raw vulnerable id")
	_assert_visible_text_not_contains(scene, "status_applied", "debt mark hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "debt mark hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "debt mark hides raw dictionary braces")
	await _play_direct(scene, follow_up, enemy)
	_assert_card_used(scene, follow_up.id)
	assert_eq(enemy.hp, 25, "debt mark vulnerable amplifies the next 10 damage hit after defense from 7 to 10")
	await _teardown(scene)

	var high_def_card = _load_card("emperor_s8_debt_mark")
	var high_def_target = _make_enemy("debt_mark_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], _make_player(50), _game_state(8))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "debt mark still deals minimum 1 damage to a high-defense target")
	_assert_status_duration(high_def_target, "vulnerable", 1, "debt mark applies vulnerable to a high-defense target after minimum damage")
	await _teardown(high_def_scene)


func _case_emperor_s8_tax_blood() -> void:
	var card = _load_card("emperor_s8_tax_blood")
	if card == null:
		return
	assert_eq(card.pathway, "emperor", "tax blood loads from the runtime skill catalog")
	assert_eq(card.sequence, 8, "tax blood sequence")
	assert_eq(card.energy_cost, 1, "tax blood cost comes from mp_cost")
	assert_eq(card.range, 3, "tax blood range")
	assert_eq(card.damage, 10, "tax blood base damage")
	assert_eq(card.heal, 2, "tax blood fixed heal amount")
	assert_eq(card.target, "single", "tax blood target mode is single")
	assert_eq(card.status_effects.size(), 1, "tax blood has one effect payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "life_steal", "tax blood registers life_steal")
	assert_true(absf(float(effect.get("magnitude", 0.0)) - 0.2) < 0.001, "tax blood life_steal magnitude is 20 percent")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("10"), "tax blood card summary includes damage amount")
	assert_true(summary_text.contains("2"), "tax blood card summary includes fixed heal amount")
	assert_true(not summary_text.contains("life_steal"), "tax blood card summary hides raw life_steal id")

	var player = _make_player(12)
	player.max_hp = 20
	var enemy = _make_enemy("tax_blood_target", 30, 0, 0)
	var scene = await _start_scene([card], [enemy], player, _game_state(8))
	var life_steal_text := _effect_result_text_from_scene(scene, {"reason": "life_steal_registered", "id": "life_steal"})
	assert_true(life_steal_text != "", "tax blood has readable BattleScene life_steal text")
	assert_eq(_status_label_from_scene(scene, "life_steal"), life_steal_text, "tax blood BattleScene status label maps life_steal consistently")
	assert_true(summary_text.contains(life_steal_text), "tax blood card summary uses the same readable life_steal label as BattleScene")
	await _play_direct(scene, card, enemy)
	_assert_card_used(scene, card.id)
	assert_eq(enemy.hp, 20, "tax blood deals 10 damage to a zero-defense target")
	assert_eq(player.hp, 16, "tax blood heals player by fixed 2 plus floor(10 * 0.2) life steal")
	var life_steal_result := _find_effect_result_by_reason_id(scene, "life_steal_registered", "life_steal")
	assert_true(not life_steal_result.is_empty(), "tax blood records life_steal registration result")
	_assert_last_action_message_contains(scene, card.get_display_name(), "tax blood summary keeps source card name")
	_assert_last_action_message_contains(scene, "10", "tax blood summary shows dealt damage")
	_assert_last_action_message_contains(scene, "4", "tax blood summary shows total actual healing")
	_assert_last_action_message_contains(scene, life_steal_text, "tax blood summary shows readable life_steal feedback")
	_assert_status_detail_not_contains(scene, life_steal_text, "tax blood life_steal is not a persistent status")
	_assert_visible_text_not_contains(scene, "life_steal", "tax blood hides raw life_steal id")
	_assert_visible_text_not_contains(scene, "life_steal_registered", "tax blood hides raw life_steal reason")
	_assert_visible_text_not_contains(scene, "{", "tax blood hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "tax blood hides raw dictionary braces")
	await _teardown(scene)

	var high_def_card = _load_card("emperor_s8_tax_blood")
	var high_def_player = _make_player(12)
	high_def_player.max_hp = 20
	var high_def_target = _make_enemy("tax_blood_high_def", 40, 20, 0)
	var high_def_scene = await _start_scene([high_def_card], [high_def_target], high_def_player, _game_state(8))
	await _play_direct(high_def_scene, high_def_card, high_def_target)
	_assert_card_used(high_def_scene, high_def_card.id)
	assert_eq(high_def_target.hp, 39, "tax blood still deals minimum 1 damage to a high-defense target")
	assert_eq(high_def_player.hp, 14, "tax blood high-defense branch only heals fixed 2 when 20 percent life steal floors to zero")
	_assert_last_action_message_contains(high_def_scene, "2", "tax blood high-defense branch summary shows actual fixed healing")
	await _teardown(high_def_scene)

	var capped_card = _load_card("emperor_s8_tax_blood")
	var capped_player = _make_player(19)
	capped_player.max_hp = 20
	var capped_enemy = _make_enemy("tax_blood_cap_target", 30, 0, 0)
	var capped_scene = await _start_scene([capped_card], [capped_enemy], capped_player, _game_state(8))
	await _play_direct(capped_scene, capped_card, capped_enemy)
	_assert_card_used(capped_scene, capped_card.id)
	assert_eq(capped_enemy.hp, 20, "tax blood cap branch still damages the target")
	assert_eq(capped_player.hp, 20, "tax blood healing is capped at player max hp")
	_assert_last_action_message_contains(capped_scene, "1", "tax blood cap branch summary shows actual capped healing")
	await _teardown(capped_scene)


func _case_thread_arrow() -> void:
	var card = _load_card("thread_arrow")
	if card == null:
		return
	assert_eq(card.pathway, "common", "thread arrow loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "thread arrow sequence")
	assert_eq(card.energy_cost, 12, "thread arrow cost comes from mp_cost")
	assert_eq(card.range, 4, "thread arrow range")
	assert_eq(card.damage, 8, "thread arrow base damage")
	assert_eq(card.target, "chain", "thread arrow target mode is chain")
	assert_eq(card.status_effects.size(), 1, "thread arrow has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "link", "thread arrow uses link splash payload")
	var summary_text := str(card.effect_summary_text())
	assert_true(not summary_text.contains("link"), "thread arrow card summary hides raw link id")

	var primary = _make_enemy("thread_arrow_primary", 40, 2, 0)
	var splash_mid = _make_enemy("thread_arrow_splash_mid", 40, 1, 0)
	var splash_high = _make_enemy("thread_arrow_splash_high", 40, 10, 0)
	var scene = await _start_scene([card], [primary, splash_mid, splash_high])
	await _play_direct(scene, card, primary)
	_assert_card_used(scene, card.id)
	assert_eq(primary.hp, 34, "thread arrow primary hit deals 8 damage reduced by 2 defense")
	assert_eq(splash_mid.hp, 37, "thread arrow link deals 4 splash damage reduced by 1 defense")
	assert_eq(splash_high.hp, 39, "thread arrow link high-defense splash target still takes minimum 1 damage")
	_assert_link_result(scene, card.id, primary.id, [splash_mid.id, splash_high.id], 4)
	var link_result := _find_effect_result_by_reason_id(scene, "linked_damage", "link")
	var link_text := _effect_result_text_from_scene(scene, link_result)
	_assert_last_action_message_contains(scene, card.get_display_name(), "thread arrow summary keeps source card name")
	_assert_last_action_message_contains(scene, link_text, "thread arrow summary shows readable link feedback")
	_assert_last_action_message_contains(scene, "thread_arrow_primary", "thread arrow summary names the primary target")
	_assert_last_action_message_contains(scene, "thread_arrow_splash_mid", "thread arrow summary names the first splash target")
	_assert_last_action_message_contains(scene, "thread_arrow_splash_high", "thread arrow summary names the second splash target")
	_assert_visible_text_not_contains(scene, "link", "thread arrow hides raw link id")
	_assert_visible_text_not_contains(scene, "linked_damage", "thread arrow hides raw linked_damage reason")
	_assert_visible_text_not_contains(scene, "{", "thread arrow hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "thread arrow hides raw dictionary braces")
	await _teardown(scene)

	var fallback_card = _load_card("thread_arrow")
	var fallback_primary = _make_enemy("thread_arrow_fallback_primary", 40, 0, 0)
	var fallback_splash_a = _make_enemy("thread_arrow_fallback_splash_a", 40, 0, 0)
	var fallback_splash_b = _make_enemy("thread_arrow_fallback_splash_b", 40, 0, 0)
	var fallback_scene = await _start_scene([fallback_card], [fallback_primary, fallback_splash_a, fallback_splash_b])
	await _play_direct(fallback_scene, fallback_card, null)
	_assert_card_used(fallback_scene, fallback_card.id)
	assert_eq(fallback_primary.hp, 32, "thread arrow chain mode resolves the first living enemy as primary when no target is selected")
	assert_eq(fallback_splash_a.hp, 36, "thread arrow no-target chain mode splashes to the second enemy")
	assert_eq(fallback_splash_b.hp, 36, "thread arrow no-target chain mode splashes to the third enemy")
	_assert_link_result(
		fallback_scene,
		fallback_card.id,
		fallback_primary.id,
		[fallback_splash_a.id, fallback_splash_b.id],
		4
	)
	await _teardown(fallback_scene)


func _case_flame_water() -> void:
	var card = _load_card("flame_water")
	if card == null:
		return
	assert_eq(card.pathway, "common", "flame water loads from the runtime skill catalog")
	assert_eq(card.sequence, 9, "flame water sequence")
	assert_eq(card.energy_cost, 18, "flame water cost comes from mp_cost")
	assert_eq(card.range, 2, "flame water range")
	assert_eq(card.damage, 25, "flame water base damage")
	assert_eq(card.target, "aoe", "flame water target mode is aoe")
	assert_eq(card.status_effects.size(), 1, "flame water has one status payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "self_damage", "flame water uses self_damage payload")
	assert_eq(int(effect.get("magnitude", 0)), 7, "flame water self damage magnitude")
	var summary_text := str(card.effect_summary_text())
	assert_true(summary_text.contains("自损"), "flame water card summary localizes self damage")
	assert_true(not summary_text.contains("self_damage"), "flame water card summary hides raw self_damage id")

	var player = _make_player(50)
	var enemy_low_def = _make_enemy("flame_water_low_def", 40, 0, 0)
	var enemy_mid_def = _make_enemy("flame_water_mid_def", 40, 5, 0)
	var enemy_high_def = _make_enemy("flame_water_high_def", 40, 30, 0)
	var scene = await _start_scene([card], [enemy_low_def, enemy_mid_def, enemy_high_def], player)
	await _play_direct(scene, card, null)
	_assert_card_used(scene, card.id)
	assert_eq(enemy_low_def.hp, 15, "flame water hits the first enemy for 25 damage")
	assert_eq(enemy_mid_def.hp, 20, "flame water hits the second enemy for 25 damage reduced by 5 defense")
	assert_eq(enemy_high_def.hp, 39, "flame water high-defense target still takes minimum 1 damage")
	assert_eq(player.hp, 43, "flame water self damage applies once for 7 after the aoe damage")
	_assert_self_damage_result(scene, 7, 1, "flame water records exactly one self-damage effect result")
	var self_damage_text := _effect_result_text_from_scene(scene, {"reason": "self_damage_applied", "id": "self_damage", "damage": 7})
	_assert_last_action_message_contains(scene, card.get_display_name(), "flame water summary keeps source card name")
	_assert_last_action_message_contains(scene, self_damage_text, "flame water summary shows readable self-damage feedback")
	_assert_visible_text_not_contains(scene, "self_damage", "flame water hides raw self_damage id")
	_assert_visible_text_not_contains(scene, "self_damage_applied", "flame water hides raw self_damage_applied reason")
	_assert_visible_text_not_contains(scene, "{", "flame water hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "flame water hides raw dictionary braces")
	await _teardown(scene)


func _load_card(card_id: String):
	var path := "%s%s.json" % [SKILLS_DIR, card_id]
	var skill_card = null
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			assert_true(false, "%s JSON parses" % card_id)
			return null
		skill_card = CardScript.from_json(parsed)
	var catalog_card = _load_card_from_catalogs(card_id)
	if catalog_card != null:
		return catalog_card
	if skill_card != null:
		return skill_card
	if catalog_card == null:
		assert_true(false, "%s JSON exists" % card_id)
	return null


func _load_card_from_catalogs(card_id: String):
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		return null
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var card = _load_card_from_catalog_file(CARDS_DIR + fname, card_id)
			if card != null:
				dir.list_dir_end()
				return card
		fname = dir.get_next()
	dir.list_dir_end()
	return null


func _load_card_from_catalog_file(path: String, card_id: String):
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return _load_card_from_catalog_entries(parsed, card_id)
	if parsed is Dictionary:
		if str(parsed.get("id", "")) == card_id:
			return CardScript.from_json(parsed)
		var entries = parsed.get("cards", [])
		if entries is Array:
			return _load_card_from_catalog_entries(entries, card_id)
	return null


func _load_card_from_catalog_entries(entries: Array, card_id: String):
	for entry in entries:
		if entry is Dictionary and str(entry.get("id", "")) == card_id:
			return CardScript.from_json(entry)
	return null


func _start_scene(cards: Array, enemies: Array = [], player = null, game_state = null):
	var packed = load(BattleScenePath)
	if packed == null or not packed.can_instantiate():
		assert_true(false, "battle_scene.tscn is instantiable for card e2e")
		return null
	var scene = packed.instantiate()
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	var active_player = player if player != null else _make_player(50)
	var active_state = game_state if game_state != null else _game_state(7)
	var active_enemies := enemies.duplicate()
	if active_enemies.is_empty():
		active_enemies.append(_make_enemy("dummy", 40))
	var contract: Array[String] = []
	scene.start_battle(cards, [], active_enemies, contract, active_player, active_state)
	await Engine.get_main_loop().process_frame
	scene._battle.hand.clear()
	for card in cards:
		scene._battle.hand.append(card)
	scene._battle.draw_pile.clear()
	scene._battle.discard_pile.clear()
	scene._battle.energy = 99
	scene.call("_render")
	await Engine.get_main_loop().process_frame
	return scene


func _play_direct(scene, card, target = null) -> void:
	if scene == null or card == null:
		assert_true(false, "BattleScene and card exist before direct card play")
		return
	scene._selected_card = card
	scene.call("_play_selected", target)
	await Engine.get_main_loop().process_frame


func _play_via_target_selection(scene, card, targets: Array) -> void:
	if scene == null or card == null:
		assert_true(false, "BattleScene and card exist before target selection play")
		return
	scene.call("_on_card_pressed", card)
	await Engine.get_main_loop().process_frame
	var panel = scene.find_child("TargetSelectionPanel", true, false)
	assert_true(panel != null and panel.visible, "paper blade opens TargetSelectionPanel")
	var confirm = scene.find_child("TargetSelectionConfirmButton", true, false)
	assert_true(confirm is Button and (confirm as Button).disabled, "paper blade confirm is disabled before minimum target count")
	var panel_text := _collect_label_text(panel) if panel != null else ""
	assert_true(panel_text.contains("0/3"), "paper blade panel shows 0/3 before selecting targets")
	for target in targets:
		scene.call("_on_target_pressed", target)
	await Engine.get_main_loop().process_frame
	assert_eq(scene._target_selection_targets.size(), targets.size(), "paper blade stores selected target count before confirmation")
	panel_text = _collect_label_text(panel) if panel != null else ""
	assert_true(panel_text.contains("%d/3" % targets.size()), "paper blade panel shows selected target count")
	confirm = scene.find_child("TargetSelectionConfirmButton", true, false)
	assert_true(confirm is Button and not (confirm as Button).disabled, "paper blade confirm enables after valid selection")
	if confirm is Button:
		(confirm as Button).pressed.emit()
	await Engine.get_main_loop().process_frame
	assert_true(panel != null and not panel.visible, "paper blade closes TargetSelectionPanel after confirmation")


func _return_card_to_hand_for_replay(scene, card) -> void:
	if scene == null or card == null:
		assert_true(false, "BattleScene and card exist before replay setup")
		return
	scene._battle.hand.erase(card)
	scene._battle.discard_pile.erase(card)
	scene._battle.exhaust_pile.erase(card)
	scene._battle.hand.append(card)
	scene._battle.energy = 99
	scene.call("_render")
	await Engine.get_main_loop().process_frame


func _choose_draw_filter(scene, index: int) -> void:
	if scene == null:
		assert_true(false, "BattleScene exists before draw_filter choice")
		return
	var panel = scene.find_child("DrawFilterPanel", true, false)
	assert_true(panel != null and panel.visible, "draw_filter opens a BattleScene choice panel")
	if panel == null or not panel.visible:
		return
	scene.call("_on_draw_filter_choice_pressed", index)
	await Engine.get_main_loop().process_frame


func _teardown(scene) -> void:
	if scene != null:
		scene.queue_free()
	await Engine.get_main_loop().process_frame


func _make_player(hp: int = 50):
	var player = CombatActorScript.new()
	player.display_name = "player"
	player.hp = hp
	player.max_hp = hp
	player.def = 0
	player.atk = 0
	player.spd = 1
	return player


func _make_enemy(id: String, hp: int = 30, defense: int = 0, attack_damage: int = 0):
	var skills := []
	var ai_pattern := [{"condition": "default", "action": "defend"}]
	if attack_damage > 0:
		skills = [{"id": "hit", "damage": attack_damage, "target": "single", "element": "normal"}]
		ai_pattern = [{"condition": "default", "action": "use_skill", "skill": "hit"}]
	return EnemyScript.from_json({
		"id": id,
		"display_name": id,
		"element": "normal",
		"stats": {"hp": hp, "max_hp": hp, "atk": attack_damage, "def": defense, "spd": 1},
		"skills": skills,
		"ai_pattern": ai_pattern,
	})


func _make_enemy_with_status_skill(id: String, status_effects: Array, damage: int = 0):
	return EnemyScript.from_json({
		"id": id,
		"display_name": id,
		"element": "normal",
		"stats": {"hp": 30, "max_hp": 30, "atk": damage, "def": 0, "spd": 1},
		"skills": [{"id": "status_hit", "damage": damage, "target": "single", "element": "normal", "status_effects": status_effects}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "status_hit"}],
	})


func _support_card(id: String, tags: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "self",
			"range": 0,
			"status_effects": [],
		},
		"tags": tags,
	})


func _attack_card(id: String, damage: int, sequence: int = 7):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": sequence,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": damage,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})


func _support_skill_card(id: String, pathway: String, energy_cost: int):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": pathway,
		"sequence": 7,
		"energy_cost": energy_cost,
		"element": "normal",
		"combat_effect": {
			"damage": 0,
			"heal": 0,
			"target": "self",
			"range": 0,
			"status_effects": [],
		},
		"tags": ["skill"],
	})


func _game_state(sequence: int = 7):
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = sequence
	return gs


func _assert_card_used(scene, card_id: String) -> void:
	assert_true(scene != null and scene._battle.used_cards.has(card_id), "%s is recorded in used_cards after BattleScene play" % card_id)
	assert_true(scene != null and not _card_in_zone(scene._battle.hand, card_id), "%s leaves hand after BattleScene play" % card_id)


func _assert_intent_revealed_by_card(scene, enemy_id: String, expected_detail_level: int, source_card_id: String) -> void:
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy_id, {}) if scene != null else {}
	assert_true(not intent.is_empty(), "%s has intent data after %s" % [enemy_id, source_card_id])
	if intent.is_empty():
		return
	assert_true(bool(intent.get("revealed_by_card", false)), "%s intent is marked as card-revealed by %s" % [enemy_id, source_card_id])
	assert_eq(int(intent.get("detail_level", 0)), expected_detail_level, "%s intent detail level after %s" % [enemy_id, source_card_id])


func _assert_intent_not_revealed_by_card(scene, enemy_id: String, source_card_id: String) -> void:
	var intent: Dictionary = scene._battle.current_enemy_intents.get(enemy_id, {}) if scene != null else {}
	assert_true(not intent.is_empty(), "%s still has intent data after %s" % [enemy_id, source_card_id])
	if intent.is_empty():
		return
	assert_true(not bool(intent.get("revealed_by_card", false)), "%s intent remains unrevealed by %s" % [enemy_id, source_card_id])
	assert_eq(int(intent.get("detail_level", 0)), 0, "%s intent detail level remains hidden after %s" % [enemy_id, source_card_id])


func _assert_intent_reveal_result(
	scene,
	source_card_id: String,
	expected_result_id: String,
	expected_detail_level: int,
	expected_target_count: int,
	expected_target_ids: Array
) -> void:
	var result := _find_intent_reveal_result(scene, source_card_id)
	assert_true(not result.is_empty(), "%s records an intent-reveal effect result" % source_card_id)
	if result.is_empty():
		return
	assert_eq(str(result.get("reason", "")), "intent_revealed_by_card", "%s result reason" % source_card_id)
	assert_eq(str(result.get("id", "")), expected_result_id, "%s result id" % source_card_id)
	assert_eq(str(result.get("source_card_id", "")), source_card_id, "%s result source card id" % source_card_id)
	assert_eq(int(result.get("detail_level", 0)), expected_detail_level, "%s result detail level" % source_card_id)
	assert_eq(int(result.get("target_count", 0)), expected_target_count, "%s result target count" % source_card_id)
	var actual_ids := _result_target_ids(result)
	assert_eq(actual_ids.size(), expected_target_count, "%s result target id count" % source_card_id)
	for expected_id in expected_target_ids:
		assert_true(str(expected_id) in actual_ids, "%s result includes target %s" % [source_card_id, str(expected_id)])


func _find_intent_reveal_result(scene, source_card_id: String) -> Dictionary:
	if scene == null:
		return {}
	var found: Dictionary = {}
	for raw_result in scene._battle.last_effect_results:
		if not raw_result is Dictionary:
			continue
		var result: Dictionary = raw_result
		if str(result.get("reason", "")) != "intent_revealed_by_card":
			continue
		if str(result.get("source_card_id", "")) != source_card_id:
			continue
		found = result
	return found


func _result_target_ids(result: Dictionary) -> Array:
	var ids := []
	var raw_ids: Variant = result.get("target_ids", [])
	if not raw_ids is Array:
		return ids
	for raw_id in raw_ids:
		ids.append(str(raw_id))
	return ids


func _assert_draw_filter_pending(scene, source_card_id: String, expected_peeked: int, expected_candidate_ids: Array) -> void:
	var pending: Dictionary = scene._battle.pending_draw_filter if scene != null else {}
	assert_true(not pending.is_empty(), "%s opens a pending draw_filter choice" % source_card_id)
	if pending.is_empty():
		return
	var source_card = pending.get("source_card", null)
	assert_true(source_card != null and str(source_card.id) == source_card_id, "%s is the pending draw_filter source card" % source_card_id)
	assert_eq(int(pending.get("peeked", 0)), expected_peeked, "%s pending draw_filter peek count" % source_card_id)
	var effect: Dictionary = pending.get("effect", {})
	assert_eq(str(effect.get("id", "")), "draw_filter", "%s pending effect id" % source_card_id)
	assert_eq(int(effect.get("choose", 0)), 1, "%s pending choose count" % source_card_id)
	assert_eq(str(effect.get("rest_policy", "")), "return_top", "%s pending rest policy" % source_card_id)
	var candidates: Array = pending.get("candidates", [])
	_assert_zone_card_order(candidates, expected_candidate_ids, "%s pending draw_filter candidates" % source_card_id)


func _assert_draw_filter_result(scene, selected_card_id: String, expected_peeked: int, expected_selected_count: int) -> void:
	var result := _find_effect_result(scene, "draw_filter_applied")
	assert_true(not result.is_empty(), "draw_filter records an applied result")
	if result.is_empty():
		return
	assert_eq(str(result.get("id", "")), "draw_filter", "draw_filter result id")
	assert_eq(int(result.get("peeked", 0)), expected_peeked, "draw_filter result peek count")
	assert_eq(int(result.get("selected_count", 0)), expected_selected_count, "draw_filter result selected count")
	assert_eq(str(result.get("selected_card_id", "")), selected_card_id, "draw_filter result selected card id")
	var selected_ids := _result_selected_card_ids(result)
	assert_eq(selected_ids.size(), expected_selected_count, "draw_filter selected id count")
	assert_true(selected_card_id in selected_ids, "draw_filter selected ids include chosen card")
	assert_true(scene._battle.pending_draw_filter.is_empty(), "draw_filter clears pending choice after resolution")
	var panel = scene.find_child("DrawFilterPanel", true, false) if scene != null else null
	assert_true(panel != null and not panel.visible, "draw_filter panel closes after resolution")


func _assert_multi_strike_result(scene, expected_hits: int, expected_damage_each: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "multi_strike_registered", "multi_strike")
	assert_true(not result.is_empty(), "multi_strike records a result")
	if result.is_empty():
		return
	assert_eq(int(result.get("hits", 0)), expected_hits, "multi_strike result hits")
	assert_eq(int(result.get("damage_each", 0)), expected_damage_each, "multi_strike result damage_each")


func _assert_acrobat_condition_not_met(scene) -> void:
	var result := _find_effect_result_by_reason_id(scene, "condition_not_met", "vulnerable_if_skill_played")
	assert_true(not result.is_empty(), "acrobat strike records condition_not_met when no prior skill was played this turn")


func _assert_acrobat_vulnerable_result(scene, expected_source_card_id: String, expected_target_id: String, expected_duration: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "conditional_status_applied", "vulnerable_if_skill_played")
	assert_true(not result.is_empty(), "acrobat strike records vulnerable_if_skill_played result after a prior skill")
	if result.is_empty():
		return
	assert_eq(str(result.get("applied_status", "")), "vulnerable", "acrobat strike conditional result applied status")
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "acrobat strike conditional result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "acrobat strike conditional result target id")
	assert_eq(str(result.get("trigger", "")), "prior_skill_this_turn", "acrobat strike conditional result trigger")
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(str(payload.get("id", "")), "vulnerable", "acrobat strike vulnerable payload id")
	assert_eq(int(payload.get("duration", 0)), expected_duration, "acrobat strike vulnerable payload duration")


func _minor_trick_option_ids(card) -> Array:
	var ids := []
	if card == null:
		return ids
	for raw_effect in card.status_effects:
		if not raw_effect is Dictionary:
			continue
		var effect: Dictionary = raw_effect
		if str(effect.get("id", "")) != "create_random_temp_card":
			continue
		var options: Variant = effect.get("options", [])
		if not options is Array:
			continue
		for raw_option in options:
			if raw_option is Dictionary:
				ids.append(str((raw_option as Dictionary).get("id", "")))
	return ids


func _assert_minor_trick_temp_card_result(scene, generated_card) -> void:
	var result := _find_effect_result_by_reason_id(scene, "temp_card_created", "create_random_temp_card")
	assert_true(not result.is_empty(), "minor trick records temp-card creation result")
	if result.is_empty() or generated_card == null:
		return
	assert_eq(str(result.get("card_id", "")), str(generated_card.id), "minor trick result records generated card id")
	assert_eq(str(result.get("card_name", "")), generated_card.get_display_name(), "minor trick result records generated card name")
	assert_eq(str(result.get("destination", "")), "draw_pile_top", "minor trick result records draw-pile-top destination")


func _find_effect_result(scene, reason: String) -> Dictionary:
	if scene == null:
		return {}
	var found: Dictionary = {}
	for raw_result in scene._battle.last_effect_results:
		if not raw_result is Dictionary:
			continue
		var result: Dictionary = raw_result
		if str(result.get("reason", "")) == reason:
			found = result
	return found


func _find_effect_result_by_reason_id(scene, reason: String, id: String) -> Dictionary:
	if scene == null:
		return {}
	var found: Dictionary = {}
	for raw_result in scene._battle.last_effect_results:
		if not raw_result is Dictionary:
			continue
		var result: Dictionary = raw_result
		if str(result.get("reason", "")) == reason and str(result.get("id", "")) == id:
			found = result
	return found


func _assert_effect_result_by_reason_id(scene, reason: String, id: String, expected_magnitude: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, reason, id)
	assert_true(not result.is_empty(), "%s records %s result" % [id, reason])
	if result.is_empty():
		return
	assert_eq(int(result.get("magnitude", 0)), expected_magnitude, "%s result magnitude" % id)


func _assert_dodge_counter_status_result(scene, expected_magnitude: int, expected_duration: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "status_applied", "dodge_counter")
	assert_true(not result.is_empty(), "predator instinct records dodge_counter status result")
	if result.is_empty():
		return
	assert_eq(int(result.get("magnitude", 0)), expected_magnitude, "dodge_counter result magnitude")
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(int(payload.get("duration", 0)), expected_duration, "dodge_counter result duration")
	assert_eq(int(payload.get("magnitude", 0)), expected_magnitude, "dodge_counter result payload magnitude")


func _assert_damage_reduction_status_result(scene, expected_source_card_id: String, expected_target_id: String, expected_duration: int, expected_magnitude: float) -> void:
	var result := _find_effect_result_by_reason_id(scene, "status_applied", "damage_reduction")
	assert_true(not result.is_empty(), "damage_reduction status result is recorded")
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "damage_reduction status result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "damage_reduction status result target id")
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(str(payload.get("id", "")), "damage_reduction", "damage_reduction status result payload id")
	assert_eq(int(payload.get("duration", 0)), expected_duration, "damage_reduction status result duration")
	assert_eq(float(payload.get("magnitude", 0.0)), expected_magnitude, "damage_reduction status result magnitude")


func _assert_damage_reduction_trigger_result(scene, expected_target_id: String, expected_source_id: String, expected_incoming_damage: int, expected_reduced_damage: int, expected_magnitude: float, expected_prevented_damage: int = -1) -> void:
	var result := _find_effect_result_by_reason_id(scene, "damage_reduction_triggered", "damage_reduction")
	assert_true(not result.is_empty(), "damage_reduction trigger result is recorded")
	if result.is_empty():
		return
	assert_eq(str(result.get("target_id", "")), expected_target_id, "damage_reduction trigger result target id")
	assert_eq(str(result.get("source_id", "")), expected_source_id, "damage_reduction trigger result source id")
	assert_eq(int(result.get("incoming_damage", 0)), expected_incoming_damage, "damage_reduction trigger result incoming damage")
	assert_eq(int(result.get("reduced_damage", 0)), expected_reduced_damage, "damage_reduction trigger result reduced damage")
	assert_eq(float(result.get("magnitude", 0.0)), expected_magnitude, "damage_reduction trigger result magnitude")
	if expected_prevented_damage >= 0:
		assert_eq(int(result.get("prevented_damage", -1)), expected_prevented_damage, "damage_reduction trigger result prevented damage")


func _assert_paper_doll_marker_result(scene, expected_added: int, expected_count: int, expected_max_stacks: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "marker_added", "paper_doll_marker")
	assert_true(not result.is_empty(), "paper doll substitute records marker_added result")
	if result.is_empty():
		return
	assert_eq(int(result.get("added", 0)), expected_added, "paper doll marker result added count")
	assert_eq(int(result.get("count", 0)), expected_count, "paper doll marker result total count")
	assert_eq(int(result.get("max_stacks", 0)), expected_max_stacks, "paper doll marker result max stacks")


func _assert_absorb_fatal_status_result(scene) -> void:
	var result := _find_effect_result_by_reason_id(scene, "status_applied", "absorb_fatal_or_curse")
	assert_true(not result.is_empty(), "paper doll substitute records absorb_fatal_or_curse status result")
	if result.is_empty():
		return
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(str(payload.get("id", "")), "absorb_fatal_or_curse", "paper doll absorb status result payload id")


func _assert_flame_marker_result(scene, expected_added: int, expected_count: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "field_marker_added", "create_or_move_flame_markers")
	assert_true(not result.is_empty(), "flame command records a field marker result")
	if result.is_empty():
		return
	assert_eq(int(result.get("added", 0)), expected_added, "flame command result added marker count")
	assert_eq(int(result.get("count", 0)), expected_count, "flame command result total marker count")


func _assert_flame_jump_result(scene, expected_damage: int, expected_consumed: int, expected_remaining: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "teleported_to_flame", "teleport_to_flame")
	assert_true(not result.is_empty(), "flame jump records a teleport result")
	if result.is_empty():
		return
	assert_eq(int(result.get("damage", 0)), expected_damage, "flame jump result damage")
	assert_eq(int(result.get("consumed_markers", 0)), expected_consumed, "flame jump result consumed marker count")
	assert_eq(int(result.get("remaining_markers", -1)), expected_remaining, "flame jump result remaining marker count")


func _assert_target_selection_result(scene, expected_selected_count: int, expected_min: int, expected_max: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "target_selection_registered", "select_targets")
	assert_true(not result.is_empty(), "select_targets records target-selection result")
	if result.is_empty():
		return
	assert_eq(int(result.get("selected_count", 0)), expected_selected_count, "select_targets result selected count")
	assert_eq(int(result.get("min", 0)), expected_min, "select_targets result minimum target count")
	assert_eq(int(result.get("max", 0)), expected_max, "select_targets result maximum target count")


func _assert_per_use_growth_result(scene, expected_magnitude: int, expected_cap: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "per_use_damage_growth_registered", "per_use_damage_growth")
	assert_true(not result.is_empty(), "per_use_damage_growth records growth registration")
	if result.is_empty():
		return
	assert_eq(int(result.get("magnitude", 0)), expected_magnitude, "per_use_damage_growth result magnitude")
	assert_eq(int(result.get("cap", 0)), expected_cap, "per_use_damage_growth result cap")


func _assert_attack_play_growth_result(scene, expected_magnitude: int, expected_cap: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "attack_play_damage_growth_registered", "attack_play_damage_growth")
	assert_true(not result.is_empty(), "attack_play_damage_growth records growth registration")
	if result.is_empty():
		return
	assert_eq(int(result.get("magnitude", 0)), expected_magnitude, "attack_play_damage_growth result magnitude")
	assert_eq(int(result.get("cap", 0)), expected_cap, "attack_play_damage_growth result cap")


func _assert_status_applied_result(scene, status_id: String, expected_source_card_id: String, expected_target_id: String, expected_duration: int, expected_magnitude: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "status_applied", status_id)
	assert_true(not result.is_empty(), "%s records status_applied result" % status_id)
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "%s result source card id" % status_id)
	assert_eq(str(result.get("target_id", "")), expected_target_id, "%s result target id" % status_id)
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(str(payload.get("id", "")), status_id, "%s result payload id" % status_id)
	if expected_duration > 0:
		assert_eq(int(payload.get("duration", 0)), expected_duration, "%s result payload duration" % status_id)
	if expected_magnitude != 0:
		assert_eq(int(result.get("magnitude", 0)), expected_magnitude, "%s result magnitude" % status_id)
		assert_eq(int(payload.get("magnitude", 0)), expected_magnitude, "%s result payload magnitude" % status_id)


func _assert_next_attack_damage_delta_status(actor, expected_magnitude: int, expected_duration: int) -> void:
	assert_true(actor.has_status("next_attack_damage_delta"), "next-attack damage delta status exists")
	if not actor.has_status("next_attack_damage_delta"):
		return
	var payload: Dictionary = actor.statuses.get("next_attack_damage_delta", {})
	assert_eq(str(payload.get("id", "")), "next_attack_damage_delta", "next-attack damage delta status payload id")
	assert_eq(int(payload.get("magnitude", 0)), expected_magnitude, "next-attack damage delta status magnitude")
	assert_eq(int(payload.get("duration", 0)), expected_duration, "next-attack damage delta status duration")


func _assert_next_attack_damage_delta_result(scene, expected_source_card_id: String, expected_target_id: String, expected_magnitude: int, expected_duration: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "next_attack_damage_delta_applied", "next_attack_damage_delta")
	assert_true(not result.is_empty(), "quiet step records next_attack_damage_delta result")
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "next-attack damage delta result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "next-attack damage delta result target id")
	assert_eq(int(result.get("magnitude", 0)), expected_magnitude, "next-attack damage delta result magnitude")
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(str(payload.get("id", "")), "next_attack_damage_delta", "next-attack damage delta result payload id")
	assert_eq(int(payload.get("magnitude", 0)), expected_magnitude, "next-attack damage delta result payload magnitude")
	assert_eq(int(payload.get("duration", 0)), expected_duration, "next-attack damage delta result payload duration")


func _assert_flame_arrow_burn_hit(scene, card, enemy) -> void:
	_assert_status_applied_result(scene, "burn", card.id, enemy.id, 3, 5)
	_assert_status_duration(enemy, "burn", 3, "flame arrow applies burn duration 3")
	assert_eq(int(enemy.statuses.get("burn", {}).get("magnitude", 0)), 5, "flame arrow burn status stores magnitude 5")
	var burn_label := _status_label_from_scene(scene, "burn")
	var burn_result_text := _effect_result_text_from_scene(scene, {"reason": "status_applied", "id": "burn"})
	_assert_last_action_message_contains(scene, card.get_display_name(), "flame arrow hit summary keeps source card name")
	_assert_last_action_message_contains(scene, burn_result_text, "flame arrow hit summary shows readable burn feedback")
	_assert_status_detail_contains(scene, "%s 3" % burn_label, "flame arrow status detail shows burn duration")
	_assert_status_detail_contains(scene, "5", "flame arrow status detail shows burn magnitude")
	_assert_visible_text_not_contains(scene, "burning", "flame arrow hit hides raw burning alias")
	_assert_visible_text_not_contains(scene, "status_applied", "flame arrow hit hides raw status_applied reason")
	_assert_visible_text_not_contains(scene, "{", "flame arrow hit hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "flame arrow hit hides raw dictionary braces")


func _assert_flame_arrow_burn_miss(scene, card) -> void:
	var miss_result := _find_effect_result_by_reason_id(scene, "chance_missed", "burning")
	assert_true(not miss_result.is_empty(), "flame arrow records chance_missed for burning")
	if miss_result.is_empty():
		return
	assert_true(absf(float(miss_result.get("chance", 0.0)) - 0.3) < 0.001, "flame arrow miss result keeps 30 percent chance")
	var miss_result_text := _effect_result_text_from_scene(scene, miss_result)
	_assert_last_action_message_contains(scene, card.get_display_name(), "flame arrow miss summary keeps source card name")
	_assert_last_action_message_contains(scene, miss_result_text, "flame arrow miss summary shows readable miss feedback")
	_assert_status_detail_not_contains(scene, _status_label_from_scene(scene, "burn"), "flame arrow miss leaves no burn status detail")
	_assert_visible_text_not_contains(scene, "burning", "flame arrow miss hides raw burning alias")
	_assert_visible_text_not_contains(scene, "chance_missed", "flame arrow miss hides raw chance_missed reason")
	_assert_visible_text_not_contains(scene, "{", "flame arrow miss hides raw dictionary braces")
	_assert_visible_text_not_contains(scene, "}", "flame arrow miss hides raw dictionary braces")


func _assert_self_damage_result(scene, expected_damage: int, expected_count: int, message: String) -> void:
	var results := _find_effect_results_by_reason_id(scene, "self_damage_applied", "self_damage")
	assert_eq(results.size(), expected_count, message)
	if results.is_empty():
		return
	var total_damage := 0
	for result in results:
		if result is Dictionary:
			total_damage += int((result as Dictionary).get("damage", 0))
	assert_eq(total_damage, expected_damage * expected_count, "%s total damage" % message)
	assert_eq(int((results[0] as Dictionary).get("damage", 0)), expected_damage, "%s damage value" % message)


func _assert_link_result(scene, expected_source_card_id: String, expected_primary_id: String, expected_target_ids: Array, expected_damage: int) -> void:
	var result := _find_effect_result_by_reason_id(scene, "linked_damage", "link")
	assert_true(not result.is_empty(), "thread arrow records linked_damage result")
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "thread arrow link result source card id")
	assert_eq(str(result.get("primary_target_id", "")), expected_primary_id, "thread arrow link result primary target id")
	assert_eq(int(result.get("damage", 0)), expected_damage, "thread arrow link result splash damage")
	var actual_ids := _result_string_array(result, "targets")
	assert_eq(actual_ids.size(), expected_target_ids.size(), "thread arrow link result target count")
	for expected_id in expected_target_ids:
		assert_true(str(expected_id) in actual_ids, "thread arrow link result includes %s" % str(expected_id))


func _assert_next_card_cost_delta_status(actor, expected_magnitude: int, expected_pathway: String, expected_required_tag: String) -> void:
	assert_true(actor.has_status("next_card_cost_delta"), "next-card cost delta status exists")
	if not actor.has_status("next_card_cost_delta"):
		return
	var payload: Dictionary = actor.statuses.get("next_card_cost_delta", {})
	assert_eq(int(payload.get("magnitude", 0)), expected_magnitude, "next-card cost delta status magnitude")
	assert_eq(str(payload.get("pathway", "")), expected_pathway, "next-card cost delta status pathway")
	assert_eq(str(payload.get("required_tag", "")), expected_required_tag, "next-card cost delta status required tag")
	assert_eq(int(payload.get("duration", 0)), 1, "next-card cost delta status duration")


func _assert_next_card_cost_delta_result(scene, expected_magnitude: int, expected_pathway: String, expected_required_tag: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "next_card_cost_delta_applied", "next_fool_skill_cost_delta")
	assert_true(not result.is_empty(), "swift cast records next-card cost delta result")
	if result.is_empty():
		return
	assert_eq(int(result.get("magnitude", 0)), expected_magnitude, "next-card cost delta result magnitude")
	assert_eq(str(result.get("pathway", "")), expected_pathway, "next-card cost delta result pathway")
	assert_eq(str(result.get("required_tag", "")), expected_required_tag, "next-card cost delta result required tag")
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(int(payload.get("magnitude", 0)), expected_magnitude, "next-card cost delta result payload magnitude")
	assert_eq(str(payload.get("pathway", "")), expected_pathway, "next-card cost delta result payload pathway")
	assert_eq(str(payload.get("required_tag", "")), expected_required_tag, "next-card cost delta result payload required tag")


func _assert_counter_intent_avoided_result(scene, expected_skipped_ids: Array) -> void:
	var result := _find_effect_result_by_reason_id(scene, "counter_intent_avoided", "avoid_counter_intent")
	assert_true(not result.is_empty(), "swift cast records counter-intent avoidance result")
	if result.is_empty():
		return
	var skipped_ids := _result_skipped_ids(result)
	assert_eq(skipped_ids.size(), expected_skipped_ids.size(), "counter-intent avoidance skipped id count")
	for expected_id in expected_skipped_ids:
		assert_true(str(expected_id) in skipped_ids, "counter-intent avoidance result includes skipped enemy %s" % str(expected_id))


func _assert_status_applied_results_for_targets(
	scene,
	status_id: String,
	expected_target_ids: Array,
	expected_duration: int,
	expected_source_card_id: String = ""
) -> void:
	var results := _find_effect_results_by_reason_id(scene, "status_applied", status_id)
	assert_eq(results.size(), expected_target_ids.size(), "%s status result count matches affected targets" % status_id)
	var actual_ids := []
	for result in results:
		if expected_source_card_id != "":
			assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "%s result source card id" % status_id)
		var target_id := str(result.get("target_id", ""))
		if target_id != "":
			actual_ids.append(target_id)
		var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
		assert_eq(str(payload.get("id", "")), status_id, "%s result payload id" % status_id)
		assert_eq(int(payload.get("duration", 0)), expected_duration, "%s result payload duration" % status_id)
	for expected_id in expected_target_ids:
		assert_true(str(expected_id) in actual_ids, "%s status result includes target %s" % [status_id, str(expected_id)])


func _assert_execute_bonus_result(
	scene,
	expected_source_card_id: String,
	expected_target_id: String,
	expected_bonus_damage: int,
	expected_threshold: float,
	expected_target_hp_pct: float
) -> void:
	var result := _find_effect_result_by_reason_id(scene, "damage_modifier", "execute_bonus_below_hp_pct")
	assert_true(not result.is_empty(), "reaper hook records execute damage_modifier result")
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "reaper hook execute result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "reaper hook execute result target id")
	assert_eq(int(result.get("bonus_damage", result.get("magnitude", 0))), expected_bonus_damage, "reaper hook execute result bonus damage")
	assert_true(absf(float(result.get("threshold", -1.0)) - expected_threshold) < 0.001, "reaper hook execute result threshold")
	assert_true(absf(float(result.get("target_hp_pct", -1.0)) - expected_target_hp_pct) < 0.001, "reaper hook execute result target HP percent")
	assert_true(bool(result.get("triggered", false)), "reaper hook execute result marks trigger")


func _assert_execute_condition_not_met_result(
	scene,
	expected_source_card_id: String,
	expected_target_id: String,
	expected_threshold: float,
	expected_target_hp_pct: float
) -> void:
	var result := _find_effect_result_by_reason_id(scene, "condition_not_met", "execute_bonus_below_hp_pct")
	assert_true(not result.is_empty(), "reaper hook records execute condition_not_met result")
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "reaper hook non-execute result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "reaper hook non-execute result target id")
	assert_eq(int(result.get("bonus_damage", -1)), 0, "reaper hook non-execute result bonus damage")
	assert_true(absf(float(result.get("threshold", -1.0)) - expected_threshold) < 0.001, "reaper hook non-execute result threshold")
	assert_true(absf(float(result.get("target_hp_pct", -1.0)) - expected_target_hp_pct) < 0.001, "reaper hook non-execute result target HP percent")
	assert_true(not bool(result.get("triggered", true)), "reaper hook non-execute result marks not triggered")


func _assert_reroll_next_target_status(actor) -> void:
	assert_true(actor.has_status("reroll_next_target"), "reroll_next_target status exists")
	if not actor.has_status("reroll_next_target"):
		return
	var payload: Dictionary = actor.statuses.get("reroll_next_target", {}) if actor.statuses.get("reroll_next_target", {}) is Dictionary else {}
	assert_eq(int(payload.get("duration", 0)), 1, "reroll_next_target status duration")
	assert_eq(str(payload.get("id", "")), "reroll_next_target", "reroll_next_target status payload id")


func _assert_reroll_next_target_result(scene, source_card_id: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "reroll_next_target_applied", "reroll_next_damage_target")
	assert_true(not result.is_empty(), "illusion weave records reroll setup result")
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), source_card_id, "reroll setup result source card id")
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(str(payload.get("id", "")), "reroll_next_target", "reroll setup result payload id")
	assert_eq(int(payload.get("duration", 0)), 1, "reroll setup result payload duration")


func _assert_reroll_next_target_consumed_result(scene, expected_original_target_id: String, expected_target_id: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "reroll_next_target_consumed", "reroll_next_target")
	assert_true(not result.is_empty(), "illusion weave records reroll consumption result")
	if result.is_empty():
		return
	assert_eq(str(result.get("original_target_id", "")), expected_original_target_id, "reroll consumption original target id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "reroll consumption final target id")


func _assert_cleanse_debuff_result(scene, expected_removed: Array, expected_types: Array, expected_source_card_id: String, expected_target_id: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "cleanse_applied", "cleanse_debuff")
	assert_true(not result.is_empty(), "water breath records cleanse_debuff result")
	if result.is_empty():
		return
	var removed := _result_string_array(result, "removed")
	for expected_id in expected_removed:
		assert_true(str(expected_id) in removed, "water breath cleanse result includes removed %s" % str(expected_id))
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "water breath cleanse result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "water breath cleanse result target id")
	var types := _result_string_array(result, "types")
	for expected_type in expected_types:
		assert_true(str(expected_type) in types, "water breath cleanse result includes type %s" % str(expected_type))


func _assert_cleanse_debuff_result_exact(scene, expected_removed: Array, expected_types: Array, expected_source_card_id: String, expected_target_id: String, context: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "cleanse_applied", "cleanse_debuff")
	assert_true(not result.is_empty(), "%s records cleanse_debuff result" % context)
	if result.is_empty():
		return
	var removed := _result_string_array(result, "removed")
	assert_eq(removed.size(), expected_removed.size(), "%s cleanse removed count" % context)
	for expected_id in expected_removed:
		assert_true(str(expected_id) in removed, "%s cleanse result includes removed %s" % [context, str(expected_id)])
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "%s cleanse result source card id" % context)
	assert_eq(str(result.get("target_id", "")), expected_target_id, "%s cleanse result target id" % context)
	var types := _result_string_array(result, "types")
	assert_eq(types.size(), expected_types.size(), "%s cleanse type count" % context)
	for expected_type in expected_types:
		assert_true(str(expected_type) in types, "%s cleanse result includes type %s" % [context, str(expected_type)])


func _assert_draw_if_no_cleanse_skipped_result(scene, expected_source_card_id: String, expected_target_id: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "draw_skipped_after_cleanse", "draw_if_no_cleanse")
	assert_true(not result.is_empty(), "bone softening records draw_if_no_cleanse skip result")
	if result.is_empty():
		return
	assert_eq(int(result.get("drawn", -1)), 0, "bone softening skip result draws zero cards")
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "bone softening skip result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "bone softening skip result target id")
	var cleaned_ids := _result_string_array(result, "cleaned_ids")
	assert_true("bind" in cleaned_ids, "bone softening skip result records cleaned status id")


func _assert_draw_if_no_cleanse_drew_result(scene, expected_drawn: int, expected_source_card_id: String, expected_target_id: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "drew_cards", "draw_if_no_cleanse")
	assert_true(not result.is_empty(), "bone softening records draw_if_no_cleanse draw result")
	if result.is_empty():
		return
	assert_eq(int(result.get("drawn", 0)), expected_drawn, "bone softening draw result count")
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "bone softening draw result source card id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "bone softening draw result target id")
	assert_eq(bool(result.get("cleaned", true)), false, "bone softening draw result records no cleanse")


func _assert_guard_status_result(scene, status_id: String, expected_source_card_id: String, expected_target_id: String, expected_duration: int, expected_types: Array) -> void:
	var result := _find_effect_result_by_reason_id(scene, "status_applied", status_id)
	assert_true(not result.is_empty(), "water breath records %s status result" % status_id)
	if result.is_empty():
		return
	assert_eq(str(result.get("source_card_id", "")), expected_source_card_id, "water breath %s result source card id" % status_id)
	assert_eq(str(result.get("target_id", "")), expected_target_id, "water breath %s result target id" % status_id)
	var payload: Dictionary = result.get("payload", {}) if result.get("payload", {}) is Dictionary else {}
	assert_eq(str(payload.get("id", "")), status_id, "water breath %s result payload id" % status_id)
	if expected_duration > 0:
		assert_eq(int(payload.get("duration", 0)), expected_duration, "water breath %s result duration" % status_id)
	var types := _result_string_array(payload, "types")
	for expected_type in expected_types:
		assert_true(str(expected_type) in types, "water breath %s result includes type %s" % [status_id, str(expected_type)])


func _assert_incoming_debuff_blocked_result(scene, guard_id: String, blocked_status_id: String, expected_target_id: String, expected_source_id: String) -> void:
	var result := _find_effect_result_by_reason_id(scene, "immune_debuff", guard_id)
	assert_true(not result.is_empty(), "water breath records incoming debuff block result")
	if result.is_empty():
		return
	assert_eq(str(result.get("blocked_status_id", "")), blocked_status_id, "water breath block result status id")
	assert_eq(str(result.get("target_id", "")), expected_target_id, "water breath block result target id")
	assert_eq(str(result.get("source_id", "")), expected_source_id, "water breath block result source id")
	assert_true(bool(result.get("consume_on_trigger_consumed", false)), "water breath block result records consume_on_trigger consumption")
	assert_true(bool(result.get("guard_consumed", false)), "water breath block result records immune guard consumption")


func _find_effect_results_by_reason_id(scene, reason: String, id: String) -> Array:
	var found := []
	if scene == null:
		return found
	for raw_result in scene._battle.last_effect_results:
		if not raw_result is Dictionary:
			continue
		var result: Dictionary = raw_result
		if str(result.get("reason", "")) == reason and str(result.get("id", "")) == id:
			found.append(result)
	return found


func _result_skipped_ids(result: Dictionary) -> Array:
	var ids := []
	var raw_ids: Variant = result.get("skipped_ids", result.get("skipped", []))
	if not raw_ids is Array:
		return ids
	for raw_id in raw_ids:
		ids.append(str(raw_id))
	return ids


func _result_string_array(source: Dictionary, key: String) -> Array:
	var ids := []
	var raw_ids: Variant = source.get(key, [])
	if not raw_ids is Array:
		return ids
	for raw_id in raw_ids:
		ids.append(str(raw_id))
	return ids


func _actors_with_status(actors: Array, status_id: String) -> Array:
	var found := []
	for actor in actors:
		if actor != null and actor.has_method("has_status") and actor.has_status(status_id):
			found.append(actor)
	return found


func _actor_ids_from(actors: Array) -> Array:
	var ids := []
	for actor in actors:
		if actor != null and actor.has_method("get"):
			ids.append(str(actor.get("id")))
	return ids


func _first_other_actor(actors: Array, actor):
	for candidate in actors:
		if candidate != null and candidate != actor:
			return candidate
	return null


func _result_selected_card_ids(result: Dictionary) -> Array:
	var ids := []
	var raw_ids: Variant = result.get("selected_card_ids", [])
	if not raw_ids is Array:
		return ids
	for raw_id in raw_ids:
		ids.append(str(raw_id))
	return ids


func _assert_zone_card_order(zone: Array, expected_ids: Array, message: String) -> void:
	assert_eq(zone.size(), expected_ids.size(), "%s size" % message)
	if zone.size() != expected_ids.size():
		return
	for i in range(expected_ids.size()):
		var card = zone[i]
		assert_eq(str(card.id) if card != null else "", str(expected_ids[i]), "%s [%d]" % [message, i])


func _assert_visible_text_contains(scene, expected_text: String, message: String) -> void:
	var text := _collect_label_text(scene) if scene != null else ""
	assert_true(text.contains(expected_text), message)


func _assert_visible_text_not_contains(scene, unexpected_text: String, message: String) -> void:
	var text := _collect_label_text(scene) if scene != null else ""
	assert_true(not text.contains(unexpected_text), message)


func _assert_hand_card_text_contains(scene, expected_text: String, message: String) -> void:
	var text := _collect_hand_card_text(scene)
	assert_true(text.contains(expected_text), message)


func _assert_last_action_message_contains(scene, expected_text: String, message: String) -> void:
	var text := str(scene._last_action_message) if scene != null else ""
	assert_true(expected_text != "" and text.contains(expected_text), message)


func _assert_hand_button_text_contains(scene, card, expected_text: String, message: String) -> void:
	var text := _hand_button_text_for_card(scene, card)
	assert_true(text.contains(expected_text), message)


func _hand_button_text_for_card(scene, card) -> String:
	if scene == null or scene._hand_box == null or card == null:
		return ""
	var name_text: String = card.get_display_name() if card.has_method("get_display_name") else str(card.get("id"))
	for child in scene._hand_box.get_children():
		if child is Button:
			var button: Button = child
			if button.text.contains(name_text) or button.tooltip_text.contains(name_text):
				return button.text + "\n" + button.tooltip_text
	return ""


func _collect_hand_card_text(scene) -> String:
	if scene == null or scene._hand_box == null:
		return ""
	var text := ""
	for child in scene._hand_box.get_children():
		if child is Button:
			var button: Button = child
			text += button.text + "\n" + button.tooltip_text + "\n"
	return text


func _assert_status_detail_contains(scene, expected_text: String, message: String) -> void:
	var text := _status_detail_label_text(scene)
	assert_true(text.contains(expected_text), message)


func _assert_status_detail_not_contains(scene, unexpected_text: String, message: String) -> void:
	var text := _status_detail_label_text(scene)
	assert_true(not text.contains(unexpected_text), message)


func _status_detail_label_text(scene) -> String:
	var label = scene.find_child("StatusDetailLabel", true, false) if scene != null else null
	if label is Label:
		return label.text
	return ""


func _status_label_from_scene(scene, status_id: String) -> String:
	if scene != null and scene.has_method("_safe_status_label_text"):
		return str(scene.call("_safe_status_label_text", status_id))
	return status_id


func _effect_result_text_from_scene(scene, result: Dictionary) -> String:
	if scene != null and scene.has_method("_effect_result_text"):
		return str(scene.call("_effect_result_text", result))
	return ""


func _card_in_zone(zone: Array, card_id: String) -> bool:
	for card in zone:
		if card != null and str(card.id) == card_id:
			return true
	return false


func _charge_zone_text(scene) -> String:
	var charge_zone = scene.find_child("ChargeZone", true, false) if scene != null else null
	if charge_zone == null:
		return ""
	return _collect_label_text(charge_zone)


func _collect_label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


func _result() -> Dictionary:
	return {"passed": _passed, "failed": _failed}


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
