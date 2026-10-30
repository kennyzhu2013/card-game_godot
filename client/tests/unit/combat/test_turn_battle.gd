extends RefCounted

const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")
const BattleSceneScript = preload("res://scripts/ui/battle_scene.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const EnemyLibraryScript = preload("res://scripts/combat/enemy_library.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_turn_battle.gd --")
	test_setup_draws_five_resets_energy_and_records_witnessed()
	test_play_card_requires_hand_energy_and_applies_damage()
	test_player_card_damage_reads_enemy_weakness_before_defense()
	test_player_card_damage_reads_enemy_resistance_before_defense()
	test_enemy_weakness_takes_priority_over_resistance_for_player_card_damage()
	test_enemy_intents_cover_five_mvp_enemies()
	test_enemy_intents_include_actionable_payload()
	test_enemy_turn_executes_previewed_intent_and_returns_to_player()
	test_enemy_skill_damage_is_reduced_by_player_defense()
	test_enemy_intent_preview_uses_player_defense()
	test_enemy_skill_damage_has_minimum_one_after_player_defense()
	test_enemy_skill_pierce_defense_reduces_player_defense_for_damage_and_preview()
	test_enemy_skill_ignore_defense_bypasses_player_defense_for_damage_and_preview()
	test_enemy_skill_ignore_defense_takes_priority_over_pierce_defense()
	test_inquisitor_holy_strike_pierces_player_defense_in_intent_and_preview()
	test_inquisitor_silver_bullet_ignores_player_defense_in_intent_and_preview()
	test_enemy_turn_applies_status_buffs_and_debuffs()
	test_resolve_victory_offers_three_and_adds_selected_temp_card()
	test_resolve_boss_victory_grants_guaranteed_brand()
	test_barrier_brand_after_play_grants_player_def_buff()
	test_draw_on_play_brand_after_play_draws_one_card_into_hand()
	test_bloom_brand_after_play_grows_card_damage_for_future_plays()
	test_mirror_image_brand_creates_same_cost_temporary_card_in_hand()
	test_mirror_image_candidate_pool_filters_cost_and_locked_sequence()
	test_mirror_image_temp_copy_removes_recursive_mirror_brand()
	test_fool_jester_mark_transforms_after_fifth_play_and_buffs_future_damage()
	test_fool_jester_mark_transform_is_idempotent_for_pretransformed_card()
	test_fool_jester_mark_transform_state_roundtrips_through_card_dict()
	test_damage_stat_brand_adds_to_card_damage()
	test_cost_minus_brand_reduces_effective_card_cost()
	test_heal_plus_brand_increases_card_heal()
	test_pierce_brand_ignores_only_its_value_of_defense()
	test_forge_residue_mid_adds_damage_and_cost_delta()
	test_forge_residue_high_makes_first_play_each_battle_free()
	test_multi_target_brand_turns_single_hit_into_two_scaled_targets()
	test_pathwise_brand_locks_other_damage_brands()
	test_fool_shadow_seal_only_buffs_matching_element_damage()
	test_crit_brand_can_multiply_damage_before_hit()
	test_vampire_brand_lifesteals_after_damage()
	test_chain_brand_splashes_damage_on_kill()
	test_silence_brand_cancels_next_enemy_skill_action()
	test_forbidden_word_filters_enemy_skill_tags()
	test_voidcrown_brand_cancels_boss_current_intent()
	test_fate_thread_can_refund_actual_paid_cost_on_play()
	test_truename_brand_reveals_and_discounts_next_card_once_per_battle()
	test_fool_face_mask_redirects_next_enemy_single_target_skill()
	test_fool_substitute_mark_can_absorb_player_fatal_damage()
	test_delay_brand_defers_card_damage_until_next_player_turn()
	test_phoenix_brand_can_return_played_card_from_discard_to_hand()
	test_echo_brand_replays_card_effect_once_at_next_player_turn_start()
	test_resolve_victory_grants_acting_exp_to_distinct_used_cards()
	test_partial_contract_only_rewards_satisfied_source_cards()
	test_broken_contract_disables_violated_cards_and_pollutes()
	test_full_contract_reduces_pollution_more_when_polluted()
	test_contract_boundary_values()
	test_sequence_mechanics_gate_blocks_locked_tags()
	test_fog_fool_contract_acting_check_difficulty_is_one_lower()
	test_storm_battle_victory_adds_weather_pollution()
	test_all_enemies_card_hits_and_applies_status_to_all_living_enemies()
	test_random_target_mode_can_choose_non_first_living_enemy()
	test_random_enemies_target_mode_selects_random_one_or_two_targets()
	test_dual_target_mode_selects_two_living_enemies()
	test_chain_target_mode_uses_resolved_primary_for_link_when_no_target_selected()
	test_enemy_defend_intent_applies_damage_reduction_to_next_hit()
	test_enemy_shadow_transformation_marks_transformed_once()
	test_block_break_shreds_defense_before_damage_without_full_pierce()
	test_chariot_reef_breaker_uses_pure_block_break()
	test_chariot_storm_pulse_displace_blocks_once_then_expires()
	test_intent_reveal_card_marks_enemy_intents_revealed()
	test_lost_control_auto_play_surfaces_battle_scene_log()
	return {"passed": _passed, "failed": _failed}


func test_setup_draws_five_resets_energy_and_records_witnessed() -> void:
	var battle = TurnBattleScript.new()
	var deck := _cards(7)
	var gs = _game_state(9)
	battle.setup_battle(deck, [], [_enemy("dummy", 20, 0)], [], null, gs)
	assert_eq(battle.phase, battle.Phase.PLAYER_TURN, "setup enters PLAYER_TURN")
	assert_eq(battle.energy, 3, "sequence 9 starts with 3 energy")
	assert_eq(battle.hand.size(), 5, "setup draws 5 cards")
	assert_eq(deck[0].battles_witnessed, 1, "setup records battle witnessed on deck cards")


func test_play_card_requires_hand_energy_and_applies_damage() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("target", 30, 2)
	var card = _card("strike", 2, 10)
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	var foreign_card = _card("not_in_hand", 1, 99)
	assert_true(not battle.play_card(foreign_card, target), "cannot play card that is not in hand")
	assert_true(battle.play_card(card, target), "play card from hand succeeds")
	assert_eq(battle.energy, 1, "playing cost-2 card leaves 1 energy")
	assert_eq(target.hp, 22, "card damage applies after enemy defense")
	assert_eq(card.play_count, 1, "play_card calls record_play")
	assert_true(card in battle.discard_pile, "played card enters discard pile")


func test_player_card_damage_reads_enemy_weakness_before_defense() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy_from_data({
		"id": "weakness_target",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 2, "spd": 1},
		"element": "normal",
		"weakness": ["test_shadow"],
		"resistance": [],
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = _brand_card("weakness_probe", 1, 10, 0, [], ["attack"], "single", 9, "test_shadow")
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	assert_true(battle.play_card(card, target), "weakness probe card can be played")
	assert_eq(int(target.hp), 27, "enemy weakness multiplies incoming card damage by 1.5 before defense")


func test_player_card_damage_reads_enemy_resistance_before_defense() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy_from_data({
		"id": "resistance_target",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 2, "spd": 1},
		"element": "normal",
		"weakness": [],
		"resistance": ["test_shadow"],
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = _brand_card("resistance_probe", 1, 10, 0, [], ["attack"], "single", 9, "test_shadow")
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	assert_true(battle.play_card(card, target), "resistance probe card can be played")
	assert_eq(int(target.hp), 35, "enemy resistance multiplies incoming card damage by 0.75 before defense")


func test_enemy_weakness_takes_priority_over_resistance_for_player_card_damage() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy_from_data({
		"id": "conflicting_affinity_target",
		"stats": {"hp": 40, "max_hp": 40, "atk": 1, "def": 2, "spd": 1},
		"element": "normal",
		"weakness": ["test_shadow"],
		"resistance": ["test_shadow"],
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})
	var card = _brand_card("conflicting_affinity_probe", 1, 10, 0, [], ["attack"], "single", 9, "test_shadow")
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	assert_true(battle.play_card(card, target), "conflicting affinity probe card can be played")
	assert_eq(int(target.hp), 27, "enemy weakness wins when weakness and resistance both list the card element")
	var saw_config_issue := false
	for result in battle.last_effect_results:
		if result is Dictionary and str(result.get("reason", "")) == "enemy_affinity_conflict":
			saw_config_issue = true
			assert_eq(str(result.get("element", "")), "test_shadow", "enemy affinity conflict records the card element")
	assert_true(saw_config_issue, "enemy affinity conflict is recorded as a data configuration issue")


func test_enemy_intents_cover_five_mvp_enemies() -> void:
	var battle = TurnBattleScript.new()
	var enemies := _load_mvp_enemies()
	battle.setup_battle(_cards(5), [], enemies, [], null, _game_state(9))
	var intents: Dictionary = battle.preview_enemy_intents()
	var intent_texts := {}
	for enemy in enemies:
		assert_true(intents.has(enemy.id), "%s intent exists" % enemy.id)
		assert_true(str(intents[enemy.id].get("action", "")) != "", "%s intent has action" % enemy.id)
		var intent_text := str(intents[enemy.id].get("intent_text", ""))
		assert_true(intent_text != "", "%s intent_text exists" % enemy.id)
		assert_true(not intent_texts.has(intent_text), "%s intent_text is unique" % enemy.id)
		intent_texts[intent_text] = true
	assert_eq(intent_texts.size(), 5, "five MVP enemies have five unique intent_text values")


func test_enemy_intents_include_actionable_payload() -> void:
	var battle = TurnBattleScript.new()
	var enemy = _enemy_from_data({
		"id": "actionable_intent_enemy",
		"display_name": "行动意图样本",
		"stats": {"hp": 30, "max_hp": 30, "atk": 5, "def": 1, "spd": 1},
		"skills": [{
			"id": "fear_claw",
			"name": "恐惧爪",
			"damage": 12,
			"target": "single",
			"status_effects": [{"id": "fear", "chance": 1.0, "duration": 1}],
		}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "fear_claw"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], null, _game_state(9))
	var intent: Dictionary = battle.preview_enemy_intents().get("actionable_intent_enemy", {})
	assert_eq(str(intent.get("skill", "")), "fear_claw", "enemy intent keeps selected skill id")
	assert_eq(str(intent.get("skill_name", "")), "恐惧爪", "enemy intent exposes skill display name")
	assert_eq(int(intent.get("damage", 0)), 12, "enemy intent exposes damage value")
	assert_eq(str(intent.get("target", "")), "single", "enemy intent exposes target kind")
	assert_true(intent.get("status_effects", []) is Array and (intent.get("status_effects", []) as Array).size() == 1, "enemy intent exposes status effect payload")
	assert_true(str(intent.get("intent_type", "")) != "", "enemy intent exposes actionable intent type")


func test_enemy_turn_executes_previewed_intent_and_returns_to_player() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 0
	var enemy = _enemy_from_data({
		"id": "attacker",
		"stats": {"hp": 20, "max_hp": 20, "atk": 5, "def": 0, "spd": 1},
		"skills": [{"id": "hit", "damage": 8, "target": "single"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "hit"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	battle.end_player_turn()
	var result: Dictionary = battle.run_enemy_turn()
	assert_eq(result.get("phase", -1), battle.Phase.PLAYER_TURN, "enemy turn returns to PLAYER_TURN when battle continues")
	assert_eq(player.hp, 42, "enemy previewed skill damages player")
	assert_true(battle.preview_enemy_intents().has("attacker"), "next enemy intent is previewed")


func test_enemy_skill_damage_is_reduced_by_player_defense() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 3
	var enemy = _enemy_from_data({
		"id": "defense_attacker",
		"stats": {"hp": 20, "max_hp": 20, "atk": 5, "def": 0, "spd": 1},
		"skills": [{"id": "hit", "damage": 8, "target": "single"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "hit"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 45, "enemy skill damage is reduced by player defense")


func test_enemy_intent_preview_uses_player_defense() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 3
	var enemy = _enemy_from_data({
		"id": "defense_preview_attacker",
		"stats": {"hp": 20, "max_hp": 20, "atk": 5, "def": 0, "spd": 1},
		"skills": [{"id": "hit", "damage": 8, "target": "single"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "hit"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	var intent: Dictionary = battle.current_enemy_intents.get("defense_preview_attacker", {})
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 5, "enemy intent preview reflects player defense")


func test_enemy_skill_damage_has_minimum_one_after_player_defense() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 99
	var enemy = _enemy_from_data({
		"id": "minimum_damage_attacker",
		"stats": {"hp": 20, "max_hp": 20, "atk": 5, "def": 0, "spd": 1},
		"skills": [{"id": "scratch", "damage": 2, "target": "single"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "scratch"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 49, "positive enemy skill damage still deals minimum one after defense")


func test_enemy_skill_pierce_defense_reduces_player_defense_for_damage_and_preview() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 5
	var enemy = _enemy_from_data({
		"id": "pierce_defense_attacker",
		"stats": {"hp": 20, "max_hp": 20, "atk": 5, "def": 0, "spd": 1},
		"skills": [{"id": "pierce_hit", "damage": 20, "target": "single", "pierce_defense": 2}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "pierce_hit"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	var intent: Dictionary = battle.current_enemy_intents.get("pierce_defense_attacker", {})
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 17, "enemy pierce_defense preview subtracts only remaining player defense")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 33, "enemy pierce_defense actual damage subtracts only remaining player defense")


func test_enemy_skill_ignore_defense_bypasses_player_defense_for_damage_and_preview() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 20
	var enemy = _enemy_from_data({
		"id": "ignore_defense_attacker",
		"stats": {"hp": 20, "max_hp": 20, "atk": 5, "def": 0, "spd": 1},
		"skills": [{"id": "true_hit", "damage": 20, "target": "single", "ignore_defense": true}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "true_hit"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	var intent: Dictionary = battle.current_enemy_intents.get("ignore_defense_attacker", {})
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 20, "enemy ignore_defense preview bypasses player defense")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 30, "enemy ignore_defense actual damage bypasses player defense")


func test_enemy_skill_ignore_defense_takes_priority_over_pierce_defense() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 20
	var enemy = _enemy_from_data({
		"id": "ignore_over_pierce_attacker",
		"stats": {"hp": 20, "max_hp": 20, "atk": 5, "def": 0, "spd": 1},
		"skills": [{"id": "true_pierce_hit", "damage": 20, "target": "single", "ignore_defense": true, "pierce_defense": 2}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "true_pierce_hit"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	var intent: Dictionary = battle.current_enemy_intents.get("ignore_over_pierce_attacker", {})
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 20, "enemy ignore_defense preview takes priority over pierce_defense")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 30, "enemy ignore_defense actual damage takes priority over pierce_defense")


func test_inquisitor_holy_strike_pierces_player_defense_in_intent_and_preview() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 5
	var lib = EnemyLibraryScript.new()
	var enemy = lib.load_enemy("inquisitor")
	assert_true(enemy != null, "inquisitor enemy data loads")
	if enemy == null:
		return
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	var intent: Dictionary = battle.current_enemy_intents.get("inquisitor", {})
	assert_eq(str(intent.get("skill", "")), "holy_strike", "inquisitor opens with holy_strike as the default attack")
	assert_eq(int(intent.get("pierce_defense", 0)), 2, "holy_strike intent exposes fixed defense penetration")
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 15, "holy_strike preview applies pierce_defense against player defense")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 35, "holy_strike actual damage applies pierce_defense against player defense")


func test_inquisitor_silver_bullet_ignores_player_defense_in_intent_and_preview() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 20
	var lib = EnemyLibraryScript.new()
	var enemy = lib.load_enemy("inquisitor")
	assert_true(enemy != null, "inquisitor enemy data loads for low-health silver bullet")
	if enemy == null:
		return
	enemy.hp = 12
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	var intent: Dictionary = battle.current_enemy_intents.get("inquisitor", {})
	assert_eq(str(intent.get("skill", "")), "silver_bullet", "low-health inquisitor selects silver_bullet")
	assert_true(bool(intent.get("ignore_defense", false)), "silver_bullet intent exposes full defense ignore")
	assert_eq(battle.preview_enemy_intent_damage(enemy, intent), 22, "silver_bullet preview ignores player defense")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 28, "silver_bullet actual damage ignores player defense")


func test_enemy_turn_applies_status_buffs_and_debuffs() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	var enemy = _enemy_from_data({
		"id": "status_enemy",
		"display_name": "状态样本",
		"stats": {"hp": 30, "max_hp": 30, "atk": 5, "def": 0, "spd": 1},
		"skills": [{
			"id": "fear_strike",
			"name": "惊惧抓击",
			"damage": 4,
			"target": "single",
			"status_effects": [{"id": "fear", "chance": 1.0, "duration": 2}],
		}, {
			"id": "guard_chant",
			"name": "护身祷告",
			"damage": 0,
			"target": "self",
			"status_effects": [{"id": "def_buff", "chance": 1.0, "duration": 2, "magnitude": 5}],
		}],
		"ai_pattern": [{"condition": "turn == 0", "action": "use_skill", "skill": "guard_chant"}, {"condition": "default", "action": "use_skill", "skill": "fear_strike"}],
	})
	battle.setup_battle(_cards(5), [], [enemy], [], player, _game_state(9))
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_true(enemy.has_status("def_buff"), "enemy self-buff status is applied")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_true(player.has_status("fear"), "enemy debuff status is applied to player")
	var attack_card = _card("fear_blocked_attack", 1, 5, ["attack"], 9)
	assert_true(not battle.can_play_card(attack_card), "fear debuff blocks attack cards")
	var before_hp := int(enemy.hp)
	var damage := battle._deal_damage(player, enemy, 8, "normal")
	assert_eq(damage, 3, "def_buff reduces incoming damage by its magnitude")
	assert_eq(int(enemy.hp), before_hp - 3, "def_buff changes the enemy hp loss")


func test_resolve_victory_offers_three_and_adds_selected_temp_card() -> void:
	var battle = TurnBattleScript.new()
	var gs = _game_state(9)
	battle.setup_battle(_cards(5), [], [_enemy("dummy", 10, 0)], [], null, gs)
	var rewards := [_card("r0"), _card("r1"), _card("r2"), _card("r3")]
	var result: Dictionary = battle.resolve_battle(true, rewards, 1, gs)
	assert_eq(result.get("outcome", ""), "victory", "resolve_battle victory outcome")
	assert_eq(result.get("reward_options", []).size(), 3, "victory exposes 3 reward options")
	assert_eq(gs.temp_picked_cards.size(), 1, "selected reward added to GameState temp picks")
	assert_eq(gs.temp_picked_cards[0].id, "r1", "selected reward index is respected")
	assert_eq(battle.phase, battle.Phase.END, "resolve_battle ends combat")


func test_resolve_boss_victory_grants_guaranteed_brand() -> void:
	var battle = TurnBattleScript.new()
	var gs = _game_state(7)
	battle.setup_battle(_cards(5), [], [_enemy("boss", 10, 0)], [], null, gs)
	var drops := {"brand_guaranteed": true, "brand_pool": "fool_low_tier_brands", "brand_roll": 0.0}
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs, drops)
	assert_true(result.get("brand_drop", null) != null, "boss victory returns brand_drop")
	assert_eq(gs.brands_inventory.size(), 1, "boss victory stores guaranteed brand")
	assert_true(gs.brands_inventory[0].id in gs.daodian["discovered_brands"], "boss victory discovers brand")


func test_barrier_brand_after_play_grants_player_def_buff() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	var target = _enemy("barrier_brand_target", 20, 0)
	var card = CardScript.from_json({
		"id": "barrier_brand_probe",
		"template_id": "barrier_brand_probe",
		"energy_cost": 1,
		"quality": 3,
		"sequence": 9,
		"combat_effect": {
			"damage": 1,
			"target": "single",
			"status_effects": [],
		},
		"tags": ["attack"],
		"brands": ["barrier_brand"],
	})
	battle.setup_battle([card], [], [target], [], player, _game_state(9))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	assert_true(battle.play_card(card, target), "card with barrier_brand can be played")
	assert_true(player.has_status("def_buff"), "barrier_brand grants player def_buff after play")
	var payload: Dictionary = player.statuses.get("def_buff", {})
	assert_eq(int(payload.get("magnitude", 0)), 5, "barrier_brand maps block 5 to def_buff magnitude")
	assert_eq(int(payload.get("duration", 0)), 1, "barrier_brand protection lasts through the enemy turn")


func test_draw_on_play_brand_after_play_draws_one_card_into_hand() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	var target = _enemy("draw_on_play_target", 20, 0)
	var card = CardScript.from_json({
		"id": "draw_on_play_probe",
		"template_id": "draw_on_play_probe",
		"energy_cost": 1,
		"quality": 3,
		"sequence": 9,
		"combat_effect": {
			"damage": 1,
			"target": "single",
			"status_effects": [],
		},
		"tags": ["attack"],
		"brands": ["draw_on_play"],
	})
	var drawn_card = _card("draw_on_play_drawn", 1, 7)
	battle.setup_battle([card, drawn_card], [], [target], [], player, _game_state(9))
	battle.hand.clear()
	battle.hand.append(card)
	battle.draw_pile.clear()
	battle.draw_pile.append(drawn_card)
	battle.energy = 99
	assert_true(battle.play_card(card, target), "card with draw_on_play can be played")
	assert_eq(battle.hand.size(), 1, "draw_on_play draws one replacement card after play")
	assert_eq(battle.hand[0].id, "draw_on_play_drawn", "draw_on_play adds the top card to hand")


func test_bloom_brand_after_play_grows_card_damage_for_future_plays() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	var target = _enemy("bloom_target", 100, 0)
	var card = CardScript.from_json({
		"id": "bloom_probe",
		"template_id": "bloom_probe",
		"energy_cost": 1,
		"quality": 3,
		"sequence": 9,
		"combat_effect": {
			"damage": 5,
			"target": "single",
			"status_effects": [],
		},
		"tags": ["attack"],
		"brands": ["bloom"],
	})
	battle.setup_battle([card], [], [target], [], player, _game_state(9))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	assert_true(battle.play_card(card, target), "card with bloom can be played")
	assert_eq(int(target.hp), 95, "bloom does not change the first hit")
	assert_eq(int(battle._card_attack_play_damage_growth_bonus(card)), 2, "bloom records +2 growth for the card after play")
	battle.discard_pile.erase(card)
	battle.hand.append(card)
	assert_true(battle.play_card(card, target), "card with bloom can be played again")
	assert_eq(int(target.hp), 88, "bloom adds the stored growth on the next play")
	assert_eq(int(battle._card_attack_play_damage_growth_bonus(card)), 4, "bloom records +2 again after the second play")
	assert_eq(int(card.play_count), 2, "bloom still records normal play count progression")
	for _i in range(4):
		battle.discard_pile.erase(card)
		battle.hand.append(card)
		assert_true(battle.play_card(card, target), "bloom card can keep being replayed for cap coverage")
	assert_eq(int(target.hp), 40, "bloom applies +4, +6, +8, then capped +10 on later plays")
	assert_eq(int(battle._card_attack_play_damage_growth_bonus(card)), 10, "bloom caps stored growth at damage_growth_max")
	assert_eq(int(card.play_count), 6, "bloom cap coverage preserves normal play count progression")


func test_mirror_image_brand_creates_same_cost_temporary_card_in_hand() -> void:
	seed(12001)
	var battle = TurnBattleScript.new()
	var target = _enemy("mirror_image_target", 40, 0)
	var card = _brand_card("mirror_image_probe", 1, 4, 0, ["mirror_image"], ["attack"], "single", 9)
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99

	assert_true(battle.play_card(card, target), "mirror_image card can be played")
	assert_eq(int(target.hp), 36, "mirror_image does not suppress the source card damage")
	assert_eq(battle.hand.size(), 1, "mirror_image adds exactly one replacement card to hand")
	var generated = battle.hand[0] if not battle.hand.is_empty() else null
	assert_true(generated != null and generated != card, "mirror_image creates a distinct card instance")
	if generated != null:
		assert_eq(int(generated.energy_cost), int(card.energy_cost), "mirror_image replacement keeps the same printed energy cost")
		assert_true("temporary" in generated.tags, "mirror_image replacement is marked as a temporary card")
		assert_true(not "mirror_image" in generated.brands, "mirror_image replacement cannot recursively carry mirror_image")
		assert_true(str(generated.template_id) != "", "mirror_image replacement keeps its source template id")
	var saw_result := false
	for result in battle.last_effect_results:
		if result is Dictionary and str(result.get("reason", "")) == "brand_mirror_card_created":
			saw_result = true
	assert_true(saw_result, "mirror_image records the generated card result")


func test_mirror_image_candidate_pool_filters_cost_and_locked_sequence() -> void:
	var battle = TurnBattleScript.new()
	battle.battle_sequence = 9
	var source = _brand_card("mirror_filter_source", 1, 1, 0, ["mirror_image"], ["attack"], "single", 9)
	var playable_same_cost = _card("mirror_playable_same_cost", 1, 1, ["attack"], 9)
	var wrong_cost = _card("mirror_wrong_cost", 2, 1, ["attack"], 9)
	var sequence_locked = _card("mirror_sequence_locked", 1, 1, ["attack"], 8)

	assert_true(battle.has_method("_mirror_image_candidate_templates"), "mirror_image exposes a candidate filter module")
	if not battle.has_method("_mirror_image_candidate_templates"):
		return
	var candidates: Array = battle._mirror_image_candidate_templates(source, [playable_same_cost, wrong_cost, sequence_locked])
	assert_eq(candidates.size(), 1, "mirror_image candidate filter keeps only same-cost playable templates")
	assert_eq(str(candidates[0].id), "mirror_playable_same_cost", "mirror_image candidate filter rejects wrong-cost and locked templates")


func test_mirror_image_temp_copy_removes_recursive_mirror_brand() -> void:
	var battle = TurnBattleScript.new()
	var template = _brand_card("mirror_recursive_template", 1, 3, 0, ["mirror_image", "damage_plus_low"], ["attack"], "single", 9)

	assert_true(battle.has_method("_mirror_image_temporary_card_from_template"), "mirror_image exposes a temporary-card copy module")
	if not battle.has_method("_mirror_image_temporary_card_from_template"):
		return
	var generated = battle._mirror_image_temporary_card_from_template(template, "mirror_image")
	assert_true(generated != null and generated != template, "mirror_image temp copy creates a distinct card")
	if generated != null:
		assert_true("temporary" in generated.tags, "mirror_image temp copy adds the temporary tag")
		assert_true(not "mirror_image" in generated.brands, "mirror_image temp copy strips recursive mirror brands")
		assert_true("damage_plus_low" in generated.brands, "mirror_image temp copy preserves non-recursive brands")


func test_fool_jester_mark_transforms_after_fifth_play_and_buffs_future_damage() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("jester_transform_target", 100, 0)
	var card = _brand_card("jester_transform_probe", 0, 10, 0, ["fool_jester_mark"], ["attack"], "single", 7)
	card.play_count = 4
	card.brand_slots = 4
	battle.setup_battle([card], [], [target], [], null, _game_state(7))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99

	assert_true(battle.play_card(card, target), "fool_jester_mark card can play the threshold use")
	assert_eq(int(target.hp), 90, "jester threshold play itself still uses pre-transform damage")
	assert_eq(int(card.play_count), 5, "jester threshold records the fifth play")
	assert_eq(int(card.damage), 13, "jester transform permanently multiplies base damage by 1.3")
	assert_eq(int(card.brand_slots), 5, "jester transform permanently opens one extra brand slot")
	var flags: Variant = card.get("brand_transform_flags")
	assert_true(flags is Dictionary and bool((flags as Dictionary).get("fool_jester_mark", false)), "jester transform records a persistent applied flag")

	battle.discard_pile.erase(card)
	battle.hand.append(card)
	assert_true(battle.play_card(card, target), "transformed jester card can be replayed")
	assert_eq(int(target.hp), 77, "jester transformed damage applies on later plays")
	assert_eq(int(card.damage), 13, "jester transform does not multiply damage again")
	assert_eq(int(card.brand_slots), 5, "jester transform does not add repeated brand slots")


func test_fool_jester_mark_transform_is_idempotent_for_pretransformed_card() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("jester_idempotent_target", 100, 0)
	var card = CardScript.from_json({
		"id": "jester_idempotent_probe",
		"template_id": "jester_idempotent_probe",
		"energy_cost": 0,
		"quality": 3,
		"sequence": 7,
		"brand_slots": 5,
		"play_count": 5,
		"brand_transform_flags": {"fool_jester_mark": true},
		"combat_effect": {
			"damage": 13,
			"target": "single",
			"status_effects": [],
		},
		"tags": ["attack"],
		"brands": ["fool_jester_mark"],
	})
	battle.setup_battle([card], [], [target], [], null, _game_state(7))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99

	assert_true(battle.play_card(card, target), "pretransformed jester card can be played")
	assert_eq(int(target.hp), 87, "pretransformed jester card uses its stored damage once")
	assert_eq(int(card.damage), 13, "pretransformed jester card does not multiply again")
	assert_eq(int(card.brand_slots), 5, "pretransformed jester card does not gain another slot")


func test_fool_jester_mark_transform_state_roundtrips_through_card_dict() -> void:
	var card = CardScript.from_json({
		"id": "jester_roundtrip_probe",
		"template_id": "jester_roundtrip_probe",
		"quality": 3,
		"sequence": 7,
		"damage": 13,
		"brand_slots": 5,
		"brands": ["fool_jester_mark"],
		"brand_transform_flags": {"fool_jester_mark": true},
	})
	var copy = CardScript.from_json(card.to_dict())
	var flags: Variant = copy.get("brand_transform_flags")
	assert_true(flags is Dictionary and bool((flags as Dictionary).get("fool_jester_mark", false)), "jester transform flag survives card serialization")
	assert_eq(int(copy.damage), 13, "jester transformed damage survives card serialization")
	assert_eq(int(copy.brand_slots), 5, "jester transformed slot count survives card serialization")


func test_damage_stat_brand_adds_to_card_damage() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("damage_brand_target", 100, 0)
	var card = _brand_card("damage_brand_probe", 1, 5, 0, ["damage_plus_low"], ["attack"])
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, target), "damage_plus_low card can be played")
	assert_eq(int(target.hp), 92, "damage_plus_low adds +3 damage to the hit")


func test_cost_minus_brand_reduces_effective_card_cost() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("cost_brand_target", 20, 0)
	var card = _brand_card("cost_brand_probe", 2, 1, 0, ["cost_minus"], ["attack"])
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	battle.energy = 1
	assert_eq(int(battle.effective_card_cost(card)), 1, "cost_minus lowers effective cost by one")
	assert_true(battle.play_card(card, target), "cost_minus lets a cost-2 card play with one energy")
	assert_eq(int(battle.energy), 0, "cost_minus spends the reduced cost")


func test_heal_plus_brand_increases_card_heal() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 10
	player.max_hp = 50
	var card = _brand_card("heal_brand_probe", 1, 0, 5, ["heal_plus"], ["skill"], "self")
	battle.setup_battle([card], [], [_enemy("heal_dummy", 20, 0)], [], player, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, player), "heal_plus card can be played")
	assert_eq(int(player.hp), 20, "heal_plus adds +5 to card healing")


func test_pierce_brand_ignores_only_its_value_of_defense() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("pierce_brand_target", 30, 5)
	var card = _brand_card("pierce_brand_probe", 1, 8, 0, ["pierce"], ["attack"])
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, target), "pierce brand card can be played")
	assert_eq(int(target.hp), 24, "pierce brand ignores three defense but does not become full pierce")


func test_forge_residue_mid_adds_damage_and_cost_delta() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("forge_mid_brand_target", 100, 0)
	var card = _brand_card("forge_mid_brand_probe", 1, 5, 0, ["forge_residue_mid"], ["attack"])
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	battle.energy = 1
	assert_eq(int(battle.effective_card_cost(card)), 2, "forge_residue_mid adds one energy cost")
	assert_true(not battle.play_card(card, target), "forge_residue_mid blocks play when the added cost is missing")
	battle.energy = 2
	assert_true(battle.play_card(card, target), "forge_residue_mid can play when the added cost is paid")
	assert_eq(int(target.hp), 91, "forge_residue_mid adds +4 damage")


func test_forge_residue_high_makes_first_play_each_battle_free() -> void:
	var battle = TurnBattleScript.new()
	var first_target = _enemy("forge_high_first_target", 40, 0)
	var card = _brand_card("forge_high_brand_probe", 3, 6, 0, ["forge_residue_high"], ["attack"])
	battle.setup_battle([card], [], [first_target], [], null, _game_state(9))

	battle.energy = 0
	assert_eq(int(battle.effective_card_cost(card)), 0, "forge_residue_high overrides the first battle play cost to zero")
	assert_true(battle.play_card(card, first_target), "forge_residue_high can play once with no energy")
	assert_eq(int(battle.energy), 0, "free first play does not spend energy")
	assert_eq(int(first_target.hp), 34, "free first play still resolves damage")

	var second_target = _enemy("forge_high_second_target", 40, 0)
	battle.enemies = [second_target]
	battle.current_enemy_intents = battle.preview_enemy_intents()
	battle.hand.append(card)
	battle.energy = 2
	assert_eq(int(battle.effective_card_cost(card)), 3, "forge_residue_high only overrides the first play of this card in the battle")
	assert_true(not battle.play_card(card, second_target), "second play requires the printed cost again")
	battle.energy = 3
	assert_true(battle.play_card(card, second_target), "second play succeeds once enough energy is available")


func test_multi_target_brand_turns_single_hit_into_two_scaled_targets() -> void:
	var battle = TurnBattleScript.new()
	var first = _enemy("multi_brand_first", 40, 0)
	var second = _enemy("multi_brand_second", 40, 0)
	var third = _enemy("multi_brand_third", 40, 0)
	var card = _brand_card("multi_target_brand_probe", 1, 10, 0, ["multi_target"], ["attack"])
	battle.setup_battle([card], [], [first, second, third], [], null, _game_state(8))

	assert_true(battle.play_card(card, first), "multi_target brand card can be played")
	assert_eq(int(first.hp), 33, "multi_target brand scales selected target damage to 70 percent")
	assert_eq(int(second.hp), 33, "multi_target brand adds one extra living target at 70 percent damage")
	assert_eq(int(third.hp), 40, "multi_target brand only rewrites single-target cards to two targets")


func test_pathwise_brand_locks_other_damage_brands() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("pathwise_brand_target", 100, 0)
	var card = _brand_card("pathwise_brand_probe", 1, 10, 0, ["pathwise", "damage_plus_low"], ["attack"])
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, target), "pathwise card can be played")
	assert_eq(int(target.hp), 85, "pathwise applies x1.5 damage and locks other damage brands")


func test_fool_shadow_seal_only_buffs_matching_element_damage() -> void:
	var matching_battle = TurnBattleScript.new()
	var matching_target = _enemy("shadow_seal_matching_target", 100, 0)
	var matching_card = _brand_card("shadow_seal_matching_probe", 1, 10, 0, ["fool_shadow_seal"], ["attack"], "single", 7, "影")
	matching_battle.setup_battle([matching_card], [], [matching_target], [], null, _game_state(7))
	matching_battle.energy = 99
	assert_true(matching_battle.play_card(matching_card, matching_target), "matching shadow seal card can be played")
	assert_eq(int(matching_target.hp), 88, "fool_shadow_seal multiplies matching shadow damage by 1.2")
	var mismatch_battle = TurnBattleScript.new()
	var mismatch_target = _enemy("shadow_seal_mismatch_target", 100, 0)
	var mismatch_card = _brand_card("shadow_seal_mismatch_probe", 1, 10, 0, ["fool_shadow_seal"], ["attack"], "single", 7, "normal")
	mismatch_battle.setup_battle([mismatch_card], [], [mismatch_target], [], null, _game_state(7))
	mismatch_battle.energy = 99
	assert_true(mismatch_battle.play_card(mismatch_card, mismatch_target), "mismatched shadow seal card can be played")
	assert_eq(int(mismatch_target.hp), 90, "fool_shadow_seal does not buff non-matching element damage")


func test_crit_brand_can_multiply_damage_before_hit() -> void:
	var saw_crit := false
	var saw_normal := false
	for i in range(128):
		seed(7000 + i)
		var battle = TurnBattleScript.new()
		var target = _enemy("crit_brand_target_%d" % i, 100, 0)
		var card = _brand_card("crit_brand_probe_%d" % i, 1, 10, 0, ["crit_brand"], ["attack"])
		battle.setup_battle([card], [], [target], [], null, _game_state(9))
		battle.energy = 99
		assert_true(battle.play_card(card, target), "crit_brand card can be played")
		var hp_after := int(target.hp)
		if hp_after == 85:
			saw_crit = true
		if hp_after == 90:
			saw_normal = true
	assert_true(saw_crit, "crit_brand can trigger a 1.5x damage hit")
	assert_true(saw_normal, "crit_brand still leaves non-critical hits possible")


func test_vampire_brand_lifesteals_after_damage() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 10
	player.max_hp = 50
	var target = _enemy("vampire_brand_target", 100, 0)
	var card = _brand_card("vampire_brand_probe", 1, 10, 0, ["vampire"], ["attack"])
	battle.setup_battle([card], [], [target], [], player, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, target), "vampire brand card can be played")
	assert_eq(int(target.hp), 90, "vampire brand still deals normal damage")
	assert_eq(int(player.hp), 13, "vampire brand heals 30 percent of damage dealt")


func test_chain_brand_splashes_damage_on_kill() -> void:
	var battle = TurnBattleScript.new()
	var first = _enemy("chain_brand_first", 5, 0)
	var second = _enemy("chain_brand_second", 30, 0)
	var card = _brand_card("chain_brand_probe", 1, 10, 0, ["chain_brand"], ["attack"], "single", 8)
	battle.setup_battle([card], [], [first, second], [], null, _game_state(8))
	battle.energy = 99
	assert_true(battle.play_card(card, first), "chain_brand card can be played")
	assert_eq(int(first.hp), 0, "chain_brand source hit kills the first target")
	assert_eq(int(second.hp), 25, "chain_brand splashes half damage to the next living enemy")


func test_silence_brand_cancels_next_enemy_skill_action() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 40
	player.max_hp = 40
	player.def = 0
	var enemy = _enemy_from_data({
		"id": "silence_brand_caster",
		"display_name": "silence_brand_caster",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [{"id": "blast", "name": "blast", "damage": 12, "target": "single", "element": "normal"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "blast"}],
	})
	var card = _brand_card("silence_brand_probe", 1, 1, 0, ["silence_brand"], ["attack"])
	battle.setup_battle([card], [], [enemy], [], player, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, enemy), "silence_brand card can be played")
	assert_true(enemy.has_status("enemy_energy_delta_next_turn"), "silence_brand records a next-enemy-action energy penalty")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(int(player.hp), 40, "silence_brand cancels the next enemy skill action")
	assert_true(not enemy.has_status("enemy_energy_delta_next_turn"), "silence_brand energy penalty is consumed by the cancelled action")


func test_forbidden_word_filters_enemy_skill_tags() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 40
	player.max_hp = 40
	player.def = 0
	var enemy = _enemy_from_data({
		"id": "forbidden_word_caster",
		"display_name": "forbidden_word_caster",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [
			{"id": "spell_nuke", "name": "spell_nuke", "damage": 12, "target": "single", "element": "normal", "tags": ["spell"]},
			{"id": "knife", "name": "knife", "damage": 7, "target": "single", "element": "normal", "tags": ["weapon"]},
		],
		"ai_pattern": [
			{"condition": "default", "action": "use_skill", "skill": "spell_nuke"},
			{"condition": "default", "action": "use_skill", "skill": "knife"},
		],
	})
	var card = _brand_card("forbidden_word_probe", 1, 1, 0, ["forbidden_word"], ["attack"])
	battle.setup_battle([card], [], [enemy], [], player, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, enemy), "forbidden_word card can be played")
	assert_true(enemy.has_status("forbidden_skill_tags"), "forbidden_word records forbidden enemy skill tags")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(int(player.hp), 33, "forbidden_word blocks the spell-tagged skill and lets the enemy fall back to an allowed skill")


func test_voidcrown_brand_cancels_boss_current_intent() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 40
	player.max_hp = 40
	player.def = 0
	var boss = _enemy_from_data({
		"id": "voidcrown_boss",
		"display_name": "voidcrown_boss",
		"tier": 3,
		"stats": {"hp": 60, "max_hp": 60, "atk": 1, "def": 0, "spd": 1},
		"skills": [{"id": "boss_smite", "name": "boss_smite", "damage": 20, "target": "single", "element": "normal"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "boss_smite"}],
	})
	var card = _brand_card("voidcrown_probe", 1, 1, 0, ["voidcrown_brand"], ["attack"])
	battle.setup_battle([card], [], [boss], [], player, _game_state(9))
	battle.energy = 99
	assert_true(battle.play_card(card, boss), "voidcrown brand card can be played")
	var intent: Dictionary = battle.current_enemy_intents.get("voidcrown_boss", {})
	assert_true(bool(intent.get("cancelled_by_brand", false)), "voidcrown marks the current boss intent cancelled")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(int(player.hp), 40, "voidcrown prevents the cancelled boss intent from damaging the player")


func test_fate_thread_can_refund_actual_paid_cost_on_play() -> void:
	var saw_refund := false
	var saw_paid := false
	for i in range(128):
		seed(8100 + i)
		var battle = TurnBattleScript.new()
		var target = _enemy("fate_thread_target_%d" % i, 20, 0)
		var card = _brand_card("fate_thread_probe_%d" % i, 2, 1, 0, ["fate_thread"], ["attack"])
		battle.setup_battle([card], [], [target], [], null, _game_state(9))
		battle.energy = 10
		assert_true(battle.play_card(card, target), "fate_thread card can be played")
		if int(battle.energy) == 10:
			saw_refund = true
		if int(battle.energy) == 8:
			saw_paid = true
	assert_true(saw_refund, "fate_thread can refund the exact paid energy cost")
	assert_true(saw_paid, "fate_thread still leaves non-refunded plays possible")


func test_truename_brand_reveals_and_discounts_next_card_once_per_battle() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 40
	player.max_hp = 40
	var target = _enemy("truename_target", 30, 0)
	var truename_card = _brand_card("truename_probe", 1, 1, 0, ["truename_brand"], ["attack"])
	var next_card = _brand_card("truename_next_common_attack", 2, 1, 0, [], ["attack"])
	battle.setup_battle([truename_card, next_card], [], [target], [], player, _game_state(3))
	battle.hand.clear()
	battle.hand.append(truename_card)
	battle.hand.append(next_card)
	battle.energy = 10

	assert_true(battle.play_card(truename_card, target), "truename card can be played")
	assert_true(player.has_status("true_name_revealed"), "truename brand records that the true name was revealed")
	assert_true(player.has_status("next_card_cost_delta"), "truename brand applies a next-card cost delta")
	assert_true(battle.play_card(next_card, target), "truename discount applies to the next card, not only Fool skills")
	assert_eq(int(battle.energy), 8, "next common card spends one less energy after truename")
	assert_true(not player.has_status("next_card_cost_delta"), "truename discount is consumed by the next card")

	battle.discard_pile.erase(truename_card)
	battle.hand.append(truename_card)
	assert_true(battle.play_card(truename_card, target), "truename card can be replayed")
	assert_true(not player.has_status("next_card_cost_delta"), "truename once_per_battle prevents a second discount")


func test_fool_face_mask_redirects_next_enemy_single_target_skill() -> void:
	seed(9201)
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	player.def = 0
	var caster = _enemy_from_data({
		"id": "face_mask_caster",
		"display_name": "face_mask_caster",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [{"id": "stab", "name": "stab", "damage": 10, "target": "single", "element": "normal"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "stab"}],
	})
	var bystander = _enemy("face_mask_bystander", 40, 0)
	var card = _brand_card("face_mask_probe", 1, 1, 0, ["fool_face_mask_mark"], ["attack"], "single", 7)
	battle.setup_battle([card], [], [caster, bystander], [], player, _game_state(7))
	battle.field_state["face_mask_redirect_chance_override"] = 1.0
	battle.energy = 99

	assert_true(battle.play_card(card, caster), "face mask card can be played")
	assert_true(caster.has_status("face_mask_redirect"), "face mask marks the target enemy's next action")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(int(player.hp), 50, "face mask redirects the next enemy single-target skill away from the player")
	assert_eq(int(bystander.hp), 30, "face mask redirects enemy damage to another living enemy")
	assert_true(not caster.has_status("face_mask_redirect"), "face mask redirect is consumed by the enemy action")


func test_fool_substitute_mark_can_absorb_player_fatal_damage() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 20
	player.max_hp = 20
	player.def = 0
	var lethal_enemy = _enemy_from_data({
		"id": "substitute_lethal_attacker",
		"display_name": "substitute_lethal_attacker",
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [{"id": "lethal_hit", "name": "lethal_hit", "damage": 30, "target": "single", "element": "normal"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "lethal_hit"}],
	})
	var card = _brand_card("substitute_mark_probe", 1, 1, 0, ["fool_substitute_mark"], ["attack"], "single", 9)
	battle.setup_battle([card], [], [lethal_enemy], [], player, _game_state(9))
	battle.field_state["fool_substitute_mark_fatal_damage_chance_override"] = 1.0

	battle.end_player_turn()
	battle.run_enemy_turn()

	assert_eq(int(player.hp), 20, "fool_substitute_mark can absorb one lethal incoming hit")
	var saw_substitute := false
	for result in battle.last_effect_results:
		if result is Dictionary and str(result.get("reason", "")) == "brand_fatal_substitute_triggered":
			saw_substitute = true
	assert_true(saw_substitute, "fool_substitute_mark records the fatal substitute trigger")


func test_delay_brand_defers_card_damage_until_next_player_turn() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	var target = _enemy("delay_brand_target", 40, 0)
	var card = _brand_card("delay_brand_probe", 1, 10, 0, ["delay_brand"], ["attack"], "single", 8)
	battle.setup_battle([card], [], [target], [], player, _game_state(8))
	battle.energy = 99

	assert_true(battle.play_card(card, target), "delay brand card can be played")
	assert_eq(int(target.hp), 40, "delay_brand prevents immediate card damage")
	var scheduled_effects = battle.get("delayed_card_effects")
	var scheduled_count: int = 0
	if scheduled_effects is Array:
		scheduled_count = scheduled_effects.size()
	assert_eq(scheduled_count, 1, "delay_brand schedules one delayed card effect")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(int(target.hp), 25, "delay_brand resolves the card damage at 1.5x on the next player turn")
	var remaining_effects = battle.get("delayed_card_effects")
	var remaining_count: int = 0
	if remaining_effects is Array:
		remaining_count = remaining_effects.size()
	assert_eq(remaining_count, 0, "delay_brand consumes the delayed effect after resolution")


func test_phoenix_brand_can_return_played_card_from_discard_to_hand() -> void:
	var battle = TurnBattleScript.new()
	var target = _enemy("phoenix_brand_target", 40, 0)
	var card = _brand_card("phoenix_brand_probe", 1, 4, 0, ["phoenix"], ["attack"])
	battle.setup_battle([card], [], [target], [], null, _game_state(9))
	battle.field_state["phoenix_return_chance_override"] = 1.0
	battle.energy = 99

	assert_true(battle.play_card(card, target), "phoenix brand card can be played")
	assert_eq(int(target.hp), 36, "phoenix brand does not suppress the played card damage")
	assert_true(card in battle.hand, "phoenix brand can return the discarded played card to hand")
	assert_true(not card in battle.discard_pile, "phoenix returned card is removed from discard pile")


func test_echo_brand_replays_card_effect_once_at_next_player_turn_start() -> void:
	var battle = TurnBattleScript.new()
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	var target = _enemy("echo_brand_target", 50, 0)
	var card = _brand_card("echo_brand_probe", 1, 10, 0, ["echo"], ["attack"])
	battle.setup_battle([card], [], [target], [], player, _game_state(9))
	battle.energy = 99

	assert_true(battle.play_card(card, target), "echo brand card can be played")
	assert_eq(int(target.hp), 40, "echo brand source card deals its normal immediate damage")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(int(target.hp), 30, "echo brand replays the card effect at the next player-turn start")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(int(target.hp), 30, "echo brand replay is consumed once and does not loop")


func test_resolve_victory_grants_acting_exp_to_distinct_used_cards() -> void:
	var battle = TurnBattleScript.new()
	var card = CardScript.from_json({
		"id": "actor",
		"template_id": "actor",
		"energy_cost": 1,
		"damage": 4,
		"quality": 3,
		"sequence": 9,
		"acting_rules": ["旁观者守则"],
	})
	var target = _enemy("dummy", 20, 0)
	battle.setup_battle([card], [], [target], ["旁观者守则"] as Array[String], null, _game_state(9))
	assert_true(battle.play_card(card, target), "card is played before resolve")
	battle.resolve_battle(true, [], 0, null)
	assert_eq(card.play_count, 1, "resolve does not duplicate record_play")
	assert_eq(card.acting_exp, 1, "full-contract resolve grants acting_exp to source card")


func test_partial_contract_only_rewards_satisfied_source_cards() -> void:
	var battle = TurnBattleScript.new()
	var gs = _game_state(9)
	var rule_a := "影替师之名"
	var rule_b := "旁观者守则"
	var rule_c := "不直呼神名"
	var contract: Array[String] = [rule_a, rule_b, rule_c]
	var actor_a := CardScript.from_json({"id": "ca", "template_id": "ca", "damage": 3, "sequence": 9, "acting_rules": [rule_a]})
	var actor_b := CardScript.from_json({"id": "cb", "template_id": "cb", "damage": 3, "sequence": 9, "acting_rules": [rule_b]})
	var bystander := CardScript.from_json({"id": "cc", "template_id": "cc", "damage": 3, "sequence": 9, "acting_rules": []})
	var target = _enemy("dummy", 100, 0)
	battle.setup_battle([actor_a, actor_b, bystander], [], [target], contract, null, gs)
	battle.play_card(actor_a, target)
	battle.play_card(actor_b, target)
	battle.play_card(bystander, target)
	battle.resolve_battle(true, [], 0, gs)
	assert_eq(int(actor_a.acting_exp), 1, "partial contract rewards card associated with satisfied rule a")
	assert_eq(int(actor_b.acting_exp), 1, "partial contract rewards card associated with satisfied rule b")
	assert_eq(int(bystander.acting_exp), 0, "partial contract does not reward unrelated card")


func test_broken_contract_disables_violated_cards_and_pollutes() -> void:
	var battle = TurnBattleScript.new()
	var gs = _game_state(9)
	gs.pollution = 60
	var rule := "旁观者守则"
	var card := CardScript.from_json({"id": "violator", "template_id": "violator", "damage": 3, "sequence": 9, "acting_rules": []})
	var target = _enemy("dummy", 100, 0)
	battle.setup_battle([card], [], [target], [rule] as Array[String], null, gs)
	battle.play_card(card, target)
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)
	var contract: Dictionary = result.get("contract", {})
	assert_eq(str(contract.get("outcome", "")), "broken", "contract outcome is broken when no rule satisfied")
	assert_eq(int(contract.get("pollution_delta", 0)), 10, "pollution >=50 doubles broken contract pollution to 10")
	assert_eq(int(gs.pollution), 70, "pollution applied to game state")
	assert_true(bool(battle.disabled_in_floor.get("violator", false)), "broken contract disables associated cards")
	assert_true(not battle.can_play_card(card), "disabled card cannot be played again this floor")


func test_full_contract_reduces_pollution_more_when_polluted() -> void:
	var battle = TurnBattleScript.new()
	var gs = _game_state(9)
	gs.pollution = 35
	var rule := "旁观者守则"
	var card := CardScript.from_json({"id": "satisfier", "template_id": "satisfier", "damage": 3, "sequence": 9, "acting_rules": [rule]})
	var target = _enemy("dummy", 50, 0)
	battle.setup_battle([card], [], [target], [rule] as Array[String], null, gs)
	battle.play_card(card, target)
	var result: Dictionary = battle.resolve_battle(true, [], 0, gs)
	var contract: Dictionary = result.get("contract", {})
	assert_eq(int(contract.get("pollution_delta", 0)), -2, "30+ pollution full contract → -2")
	assert_eq(int(gs.pollution), 33, "pollution decremented")


func test_contract_boundary_values() -> void:
	var doubled_battle = TurnBattleScript.new()
	var doubled_gs = _game_state(9)
	doubled_gs.pollution = 50
	var doubled_card = _card_with_rules("pollution_50_fail", [])
	doubled_battle.setup_battle([doubled_card], [], [_enemy("dummy_a", 100, 0)], ["rule_a"] as Array[String], null, doubled_gs)
	doubled_battle.play_card(doubled_card, doubled_battle.enemies[0])
	var doubled_result: Dictionary = doubled_battle.resolve_battle(true, [], 0, doubled_gs)
	var doubled_contract: Dictionary = doubled_result.get("contract", {})
	assert_eq(int(doubled_contract.get("pollution_delta", 0)), 10, "pollution 50 boundary doubles broken penalty")
	assert_eq(int(doubled_gs.pollution), 60, "pollution 50 boundary applies +10")

	var partial_battle = TurnBattleScript.new()
	var partial_gs = _game_state(9)
	var boundary_rules: Array[String] = ["rule_a", "rule_b", "rule_c", "rule_d", "rule_e"]
	var partial_cards := [
		_card_with_rules("partial_a", ["rule_a"]),
		_card_with_rules("partial_b", ["rule_b"]),
		_card_with_rules("partial_c", ["rule_c"]),
		_card_with_rules("partial_d", []),
		_card_with_rules("partial_e", []),
	]
	partial_battle.setup_battle(partial_cards, [], [_enemy("dummy_b", 100, 0)], boundary_rules, null, partial_gs)
	for card in partial_cards:
		partial_battle.play_card(card, partial_battle.enemies[0])
	var partial_result: Dictionary = partial_battle.resolve_battle(true, [], 0, partial_gs)
	var partial_contract: Dictionary = partial_result.get("contract", {})
	assert_true(abs(float(partial_contract.get("ratio", 0.0)) - 0.6) < 0.0001, "satisfaction ratio is exactly 0.6")
	assert_eq(str(partial_contract.get("outcome", "")), "partial", "ratio 0.6 stays partial")
	assert_eq(int(partial_contract.get("pollution_delta", 0)), 0, "ratio 0.6 does not add pollution")

	var broken_battle = TurnBattleScript.new()
	var broken_gs = _game_state(9)
	var broken_card_a = _card_with_rules("broken_a", [])
	var broken_card_b = _card_with_rules("broken_b", [])
	broken_battle.setup_battle([broken_card_a, broken_card_b], [], [_enemy("dummy_c", 100, 0)], ["broken_rule_a", "broken_rule_b"] as Array[String], null, broken_gs)
	broken_battle.play_card(broken_card_a, broken_battle.enemies[0])
	broken_battle.play_card(broken_card_b, broken_battle.enemies[0])
	var broken_result: Dictionary = broken_battle.resolve_battle(true, [], 0, broken_gs)
	var broken_contract: Dictionary = broken_result.get("contract", {})
	assert_eq(float(broken_contract.get("ratio", -1.0)), 0.0, "all-violated ratio is 0")
	assert_true(bool(broken_battle.disabled_in_floor.get("broken_a", false)), "all-violated used card A disabled")
	assert_true(bool(broken_battle.disabled_in_floor.get("broken_b", false)), "all-violated used card B disabled")

	var full_battle = TurnBattleScript.new()
	var full_gs = _game_state(9)
	full_gs.pollution = 30
	var full_card = _card_with_rules("pollution_30_full", ["full_rule"])
	full_battle.setup_battle([full_card], [], [_enemy("dummy_d", 100, 0)], ["full_rule"] as Array[String], null, full_gs)
	full_battle.play_card(full_card, full_battle.enemies[0])
	var full_result: Dictionary = full_battle.resolve_battle(true, [], 0, full_gs)
	var full_contract: Dictionary = full_result.get("contract", {})
	assert_eq(int(full_contract.get("pollution_delta", 0)), -2, "pollution 30 boundary full contract gives -2")
	assert_eq(int(full_gs.pollution), 28, "pollution 30 boundary applies -2")


func test_sequence_mechanics_gate_blocks_locked_tags() -> void:
	var locked = _card("locked_multi", 1, 5, ["multi_strike"], 9)
	var target = _enemy("dummy", 20, 0)
	var battle_s9 = TurnBattleScript.new()
	battle_s9.setup_battle([locked], [], [target], [], null, _game_state(9))
	assert_true(not battle_s9.play_card(locked, target), "sequence 9 cannot play sequence 8 mechanic tag")
	var unlocked = _card("unlocked_multi", 1, 5, ["multi_strike"], 8)
	var battle_s8 = TurnBattleScript.new()
	battle_s8.setup_battle([unlocked], [], [_enemy("dummy2", 20, 0)], [], null, _game_state(8))
	assert_true(battle_s8.play_card(unlocked, battle_s8.enemies[0]), "sequence 8 can play multi_strike tag")


func test_fog_fool_contract_acting_check_difficulty_is_one_lower() -> void:
	var sunny_gs = _game_state(9)
	sunny_gs.current_weather = "sunny"
	sunny_gs.pathway = "fool"
	var fog_gs = _game_state(9)
	fog_gs.current_weather = "fog"
	fog_gs.pathway = "fool"
	var rules: Array[String] = ["rule_a", "rule_b", "rule_c"]
	var sunny_battle = TurnBattleScript.new()
	sunny_battle.setup_battle([_card_with_rules("sunny_card", [])], [], [_enemy("sunny_dummy", 100, 0)], rules, null, sunny_gs)
	var sunny_result: Dictionary = sunny_battle.resolve_battle(true, [], 0, sunny_gs)
	var fog_battle = TurnBattleScript.new()
	fog_battle.setup_battle([_card_with_rules("fog_card", [])], [], [_enemy("fog_dummy", 100, 0)], rules, null, fog_gs)
	var fog_result: Dictionary = fog_battle.resolve_battle(true, [], 0, fog_gs)
	var sunny_contract: Dictionary = sunny_result.get("contract", {})
	var fog_contract: Dictionary = fog_result.get("contract", {})
	assert_eq(int(sunny_contract.get("acting_check_base_difficulty", 0)), 3, "sunny acting_check base difficulty follows 3 active rules")
	assert_eq(int(fog_contract.get("acting_check_weather_modifier", 0)), -1, "fog fool acting_check applies -1 difficulty modifier")
	assert_eq(
		int(fog_contract.get("acting_check_difficulty", 0)),
		int(sunny_contract.get("acting_check_difficulty", 0)) - 1,
		"fog fool acting_check difficulty is one lower than sunny"
	)


func test_storm_battle_victory_adds_weather_pollution() -> void:
	var sunny_gs = _game_state(9)
	sunny_gs.current_weather = "sunny"
	sunny_gs.pollution = 10
	var sunny_battle = TurnBattleScript.new()
	sunny_battle.setup_battle([_card("sunny")], [], [_enemy("sunny_enemy", 10, 0)], [], null, sunny_gs)
	var sunny_result: Dictionary = sunny_battle.resolve_battle(true, [], 0, sunny_gs)
	var storm_gs = _game_state(9)
	storm_gs.current_weather = "storm"
	storm_gs.pollution = 10
	var storm_battle = TurnBattleScript.new()
	storm_battle.setup_battle([_card("storm")], [], [_enemy("storm_enemy", 10, 0)], [], null, storm_gs)
	var storm_result: Dictionary = storm_battle.resolve_battle(true, [], 0, storm_gs)
	assert_eq(int(storm_result.get("weather_pollution_delta", 0)), 2, "storm battle result reports +2 weather pollution")
	assert_eq(int(sunny_result.get("weather_pollution_delta", 0)), 0, "sunny battle result reports no weather pollution")
	assert_eq(int(storm_gs.pollution), int(sunny_gs.pollution) + 2, "storm battle victory leaves GameState pollution two higher than sunny")


func test_all_enemies_card_hits_and_applies_status_to_all_living_enemies() -> void:
	var battle = TurnBattleScript.new()
	var enemy_a = _enemy("aoe_a", 30, 0)
	var enemy_b = _enemy("aoe_b", 30, 0)
	var dead_enemy = _enemy("aoe_dead", 30, 0)
	dead_enemy.hp = 0
	var card = _effect_card(
		"all_enemy_weak_probe",
		1,
		4,
		"all_enemies",
		[{"id": "weak", "duration": 2}],
		["attack"]
	)
	battle.setup_battle([card], [], [enemy_a, enemy_b, dead_enemy], [], null, _game_state(9))
	assert_true(battle.play_card(card, null), "all-enemies card can be played without selecting a single target")
	assert_eq(int(enemy_a.hp), 26, "all-enemies damage hits first living enemy")
	assert_eq(int(enemy_b.hp), 26, "all-enemies damage hits second living enemy")
	assert_eq(int(dead_enemy.hp), 0, "all-enemies damage skips dead enemy")
	assert_true(enemy_a.has_status("weak"), "all-enemies status applies weak to first living enemy")
	assert_true(enemy_b.has_status("weak"), "all-enemies status applies weak to second living enemy")
	assert_true(not dead_enemy.has_status("weak"), "all-enemies status skips dead enemy")


func test_random_target_mode_can_choose_non_first_living_enemy() -> void:
	var saw_non_first_target := false
	var every_play_succeeded := true
	for i in range(64):
		var battle = TurnBattleScript.new()
		var enemy_a = _enemy("random_a_%d" % i, 30, 0)
		var enemy_b = _enemy("random_b_%d" % i, 30, 0)
		var card = _effect_card(
			"random_target_probe_%d" % i,
			0,
			5,
			"random",
			[],
			["attack"],
			9
		)
		battle.setup_battle([card], [], [enemy_a, enemy_b], [], null, _game_state(9))
		battle.hand.clear()
		battle.hand.append(card)
		battle.energy = 99
		seed(1000 + i)
		every_play_succeeded = battle.play_card(card, null) and every_play_succeeded
		if int(enemy_b.hp) < 30:
			saw_non_first_target = true
	assert_true(every_play_succeeded, "random target cards can be played without explicit enemy selection")
	assert_true(saw_non_first_target, "random target mode can choose a non-first living enemy")


func test_random_enemies_target_mode_selects_random_one_or_two_targets() -> void:
	var saw_non_first_target := false
	var every_play_succeeded := true
	var every_count_valid := true
	for i in range(64):
		var battle = TurnBattleScript.new()
		var enemy_a = _enemy("random_enemies_a_%d" % i, 30, 0)
		var enemy_b = _enemy("random_enemies_b_%d" % i, 30, 0)
		var enemy_c = _enemy("random_enemies_c_%d" % i, 30, 0)
		var card = _effect_card(
			"random_enemies_probe_%d" % i,
			0,
			0,
			"random_enemies",
			[{"id": "confusion", "duration": 1, "targets": [1, 2]}],
			["skill", "control"],
			7
		)
		battle.setup_battle([card], [], [enemy_a, enemy_b, enemy_c], [], null, _game_state(7))
		battle.hand.clear()
		battle.hand.append(card)
		battle.energy = 99
		seed(2000 + i)
		every_play_succeeded = battle.play_card(card, null) and every_play_succeeded
		var affected := 0
		for enemy in [enemy_a, enemy_b, enemy_c]:
			if enemy.has_status("confusion"):
				affected += 1
		if affected < 1 or affected > 2:
			every_count_valid = false
		if enemy_b.has_status("confusion") or enemy_c.has_status("confusion"):
			saw_non_first_target = true
	assert_true(every_play_succeeded, "random_enemies card can be played without explicit enemy selection")
	assert_true(every_count_valid, "random_enemies respects targets [1, 2]")
	assert_true(saw_non_first_target, "random_enemies can choose non-first living enemies")


func test_dual_target_mode_selects_two_living_enemies() -> void:
	var saw_non_first_target := false
	var every_play_succeeded := true
	var every_count_valid := true
	for i in range(64):
		var battle = TurnBattleScript.new()
		var enemy_a = _enemy("dual_a_%d" % i, 30, 0)
		var enemy_b = _enemy("dual_b_%d" % i, 30, 0)
		var enemy_c = _enemy("dual_c_%d" % i, 30, 0)
		var card = _effect_card(
			"dual_target_probe_%d" % i,
			0,
			6,
			"dual",
			[],
			["attack"],
			9
		)
		battle.setup_battle([card], [], [enemy_a, enemy_b, enemy_c], [], null, _game_state(9))
		battle.hand.clear()
		battle.hand.append(card)
		battle.energy = 99
		seed(3000 + i)
		every_play_succeeded = battle.play_card(card, null) and every_play_succeeded
		var damaged := 0
		for enemy in [enemy_a, enemy_b, enemy_c]:
			if int(enemy.hp) < 30:
				damaged += 1
		if damaged != 2:
			every_count_valid = false
		if int(enemy_b.hp) < 30 or int(enemy_c.hp) < 30:
			saw_non_first_target = true
	assert_true(every_play_succeeded, "dual target cards can be played without explicit enemy selection")
	assert_true(every_count_valid, "dual target mode hits two living enemies")
	assert_true(saw_non_first_target, "dual target mode can choose non-first living enemies")


func test_chain_target_mode_uses_resolved_primary_for_link_when_no_target_selected() -> void:
	var battle = TurnBattleScript.new()
	var enemy_a = _enemy("chain_a", 30, 0)
	var enemy_b = _enemy("chain_b", 30, 0)
	var enemy_c = _enemy("chain_c", 30, 0)
	var card = _effect_card(
		"chain_target_probe",
		0,
		8,
		"chain",
		[{"id": "link"}],
		["attack"],
		9
	)
	battle.setup_battle([card], [], [enemy_a, enemy_b, enemy_c], [], null, _game_state(9))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	assert_true(battle.play_card(card, null), "chain target card can resolve a primary target without explicit selection")
	assert_eq(enemy_a.hp, 22, "chain target mode damages the resolved primary target")
	assert_eq(enemy_b.hp, 26, "link effect splashes from the resolved primary to enemy B")
	assert_eq(enemy_c.hp, 26, "link effect splashes from the resolved primary to enemy C")


func test_enemy_defend_intent_applies_damage_reduction_to_next_hit() -> void:
	var battle = TurnBattleScript.new()
	var defender = _enemy_from_data({
		"id": "defending_enemy",
		"display_name": "defending_enemy",
		"stats": {"hp": 40, "max_hp": 40, "atk": 0, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend", "params": {"damage_reduction": 0.5}}],
	})
	var strike = _card("strike_into_defend", 1, 10, ["attack"], 9)
	battle.setup_battle([strike], [], [defender], [], null, _game_state(9))
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_true(defender.has_status("damage_reduction"), "enemy defend intent applies damage_reduction status")
	battle.hand.clear()
	battle.hand.append(strike)
	battle.energy = 99
	assert_true(battle.play_card(strike, defender), "player can attack after enemy defend")
	assert_eq(defender.hp, 35, "defend damage_reduction halves the next incoming hit")
	assert_true(not defender.has_status("damage_reduction"), "defend damage_reduction is consumed by the hit")


func test_enemy_shadow_transformation_marks_transformed_once() -> void:
	var battle = TurnBattleScript.new()
	var lib = EnemyLibraryScript.new()
	var horror = lib.load_enemy("alley_horror")
	assert_true(horror != null, "alley_horror enemy data loads")
	horror.hp = 39
	battle.setup_battle(_cards(5), [], [horror], [], null, _game_state(9))
	battle.turn_count = 1
	var first_intents: Dictionary = battle.preview_enemy_intents()
	assert_eq(str(first_intents.get("alley_horror", {}).get("skill", "")), "shadow_transformation", "half-health alley horror chooses transformation before transformed flag")
	battle.phase = battle.Phase.ENEMY_TURN
	battle.run_enemy_turn()
	assert_eq(str(horror.get("transformed")), "true", "shadow transformation marks the enemy transformed")
	battle.turn_count = 2
	var next_intents: Dictionary = battle.preview_enemy_intents()
	assert_eq(str(next_intents.get("alley_horror", {}).get("skill", "")), "phantom_swipe", "transformed alley horror returns to default skill instead of transforming again")


func test_block_break_shreds_defense_before_damage_without_full_pierce() -> void:
	var battle = TurnBattleScript.new()
	var enemy = _enemy("block_break_target", 30, 5)
	var card = _effect_card(
		"block_break_probe",
		1,
		11,
		"single",
		[{"id": "block_break", "magnitude": 3}],
		["attack", "block_break"],
		8
	)
	battle.setup_battle([card], [], [enemy], [], null, _game_state(8))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	assert_true(battle.play_card(card, enemy), "block_break card can be played")
	assert_eq(enemy.def, 2, "block_break removes three defense before damage is calculated")
	assert_eq(enemy.hp, 21, "block_break does not become full pierce on the same hit")


func test_chariot_reef_breaker_uses_pure_block_break() -> void:
	var card = CardScript.from_json(_json("res://data/skills/chariot_s8_reef_breaker.json"))
	assert_true(card.status_effects.size() > 0 and card.status_effects[0] is Dictionary, "reef breaker has structured effect payload")
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(str(effect.get("id", "")), "block_break", "reef breaker uses pure block_break instead of legacy break_block")
	assert_eq(int(effect.get("magnitude", 0)), 3, "reef breaker declares explicit defense shred magnitude")
	var battle = TurnBattleScript.new()
	var enemy = _enemy("reef_breaker_target", 30, 5)
	battle.setup_battle([card], [], [enemy], [], null, _game_state(8))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	assert_true(battle.play_card(card, enemy), "reef breaker card can be played")
	assert_eq(enemy.def, 2, "reef breaker shreds three defense")
	assert_eq(enemy.hp, 21, "reef breaker does not get same-hit full pierce")


func test_chariot_storm_pulse_displace_blocks_once_then_expires() -> void:
	var card = CardScript.from_json(_json("res://data/skills/chariot_s8_storm_pulse.json"))
	var effect: Dictionary = card.status_effects[0] if card.status_effects.size() > 0 and card.status_effects[0] is Dictionary else {}
	assert_eq(int(effect.get("duration", 0)), 1, "storm pulse declares displace duration")
	var player = CombatActorScript.new()
	player.hp = 30
	player.max_hp = 30
	var enemy = _enemy_from_data({
		"id": "storm_pulse_attacker",
		"display_name": "storm_pulse_attacker",
		"stats": {"hp": 30, "max_hp": 30, "atk": 9, "def": 0, "spd": 1},
		"skills": [{"id": "hit", "name": "hit", "damage": 9, "target": "single", "element": "normal"}],
		"ai_pattern": [{"condition": "default", "action": "use_skill", "skill": "hit"}],
	})
	var battle = TurnBattleScript.new()
	battle.setup_battle([card], [], [enemy], [], player, _game_state(8))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	assert_true(battle.play_card(card, null), "storm pulse can be played without selecting one enemy")
	assert_true(enemy.has_status("displace"), "storm pulse applies displace before enemy action")
	battle.end_player_turn()
	battle.run_enemy_turn()
	assert_eq(player.hp, 30, "displace blocks the next enemy action")
	assert_true(not enemy.has_status("displace"), "displace expires after blocking one action")


func test_intent_reveal_card_marks_enemy_intents_revealed() -> void:
	var battle = TurnBattleScript.new()
	var enemy = _enemy("reveal_target", 30, 0)
	var player = CombatActorScript.new()
	player.hp = 50
	player.max_hp = 50
	var reveal_card = _card(
		"intent_reveal_probe",
		0,
		0,
		["skill", "intent_reveal", "mind_read"],
		8
	)
	battle.setup_battle([reveal_card], [], [enemy], [], player, _game_state(8))
	assert_true(battle.play_card(reveal_card, null), "intent reveal card can be played")
	var intent: Dictionary = battle.current_enemy_intents.get("reveal_target", {})
	assert_true(bool(intent.get("revealed_by_card", false)), "intent reveal card marks the current enemy intent as revealed")
	assert_true(int(intent.get("detail_level", 0)) >= 2, "mind_read intent reveal card upgrades detail level")


func test_lost_control_auto_play_surfaces_battle_scene_log() -> void:
	var scene = BattleSceneScript.new()
	scene.call("_build_ui")
	var gs = _game_state(9)
	gs.is_lost_control = true
	var auto_card = _card("lost_control_auto_probe", 0, 3)
	var enemy = _enemy("lost_control_target", 20, 0)
	scene.start_battle([auto_card], [], [enemy], [], null, gs)
	var entries: Array = scene._battle_log_entries
	var found := false
	for entry in entries:
		var text := str(entry)
		if text.contains("失控") or text.contains("自动"):
			found = true
	assert_true(found, "lost-control auto play is shown in BattleScene battle log")
	scene.queue_free()


func _cards(count: int) -> Array:
	var result := []
	for i in range(count):
		result.append(_card("c%d" % i, 1, 3))
	return result


func _card(id: String, cost: int = 1, damage: int = 0, tags: Array[String] = [], sequence: int = 9):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"energy_cost": cost,
		"damage": damage,
		"quality": 3,
		"sequence": sequence,
		"tags": tags,
	})


func _effect_card(id: String, cost: int, damage: int, target: String, effects: Array, tags: Array[String] = [], sequence: int = 9):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"energy_cost": cost,
		"quality": 3,
		"sequence": sequence,
		"combat_effect": {
			"damage": damage,
			"heal": 0,
			"target": target,
			"range": 5,
			"status_effects": effects,
		},
		"tags": tags,
	})


func _brand_card(id: String, cost: int, damage: int, heal: int, brands: Array[String], tags: Array[String] = [], target: String = "single", sequence: int = 9, element: String = "normal"):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"energy_cost": cost,
		"quality": 3,
		"sequence": sequence,
		"element": element,
		"combat_effect": {
			"damage": damage,
			"heal": heal,
			"target": target,
			"range": 5,
			"status_effects": [],
		},
		"tags": tags,
		"brands": brands,
	})


func _card_with_rules(id: String, rules: Array):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"energy_cost": 0,
		"damage": 0,
		"quality": 3,
		"sequence": 9,
		"acting_rules": rules,
	})


func _enemy(id: String, hp: int, defense: int):
	return _enemy_from_data({
		"id": id,
		"display_name": id,
		"stats": {"hp": hp, "max_hp": hp, "atk": 1, "def": defense, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func _enemy_from_data(data: Dictionary):
	return EnemyScript.from_json(data)


func _load_mvp_enemies() -> Array:
	var lib = EnemyLibraryScript.new()
	var result := []
	for id in ["drunkard", "vagrant", "inquisitor", "shadow_wraith", "alley_horror"]:
		result.append(lib.load_enemy(id))
	return result


func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _game_state(sequence: int):
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = sequence
	return gs


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
