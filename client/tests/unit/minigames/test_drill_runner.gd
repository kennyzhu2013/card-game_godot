extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")

const RUNNER_PATH := "res://scripts/world/drill_runner.gd"
const EXPECTED_DRILLS := {
	"street_debate": {"city": "sacred_seven", "ap_cost": 1, "witness": "thomas_priest"},
	"underground_signal": {"city": "shadow_alley", "ap_cost": 1, "witness": "old_li"},
	"smuggle_role": {"city": "misty_port", "ap_cost": 2, "witness": "carl_smuggler"},
	"confess_innocent": {"city": "sacred_seven", "ap_cost": 1, "witness": "thomas_priest"},
	"confession_room": {"city": "sacred_seven", "ap_cost": 1, "witness": "thomas_priest"},
	"mirror_step": {"city": "shadow_alley", "ap_cost": 1, "witness": "drunk_passerby"},
	"foreman_dialogue": {"city": "steelworks", "ap_cost": 1, "witness": "peter_furnace"},
	"tavern_brag": {"city": "misty_port", "ap_cost": 1, "witness": "tavern_sailor"},
	"noble_salon": {"city": "stone_tower", "ap_cost": 2, "witness": "marquis_eng"},
}

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_drill_runner.gd --")
	test_all_drill_definitions_have_three_rules()
	test_perfect_drill_grants_rule_trust_and_acting_exp()
	test_partial_drill_grants_acting_exp_without_full_reward()
	test_failure_penalties_apply_without_acting_exp()
	test_acting_exp_accumulates_to_upgrade_level()
	return {"passed": _passed, "failed": _failed}


func test_all_drill_definitions_have_three_rules() -> void:
	var runner = _runner()
	if runner == null:
		return
	assert_true(runner.has_method("load_drill_definition"), "DrillRunner exposes load_drill_definition")
	if not runner.has_method("load_drill_definition"):
		return
	for drill_id in EXPECTED_DRILLS.keys():
		var definition: Dictionary = runner.call("load_drill_definition", drill_id)
		var spec: Dictionary = EXPECTED_DRILLS[drill_id]
		assert_eq(str(definition.get("id", "")), drill_id, "%s definition loads by structured id" % drill_id)
		assert_eq(str(definition.get("type", "")), "drill", "%s definition type is drill" % drill_id)
		assert_eq(str(definition.get("city", "")), str(spec.get("city", "")), "%s city matches R25 table" % drill_id)
		assert_eq(int(definition.get("ap_cost", -1)), int(spec.get("ap_cost", -1)), "%s AP matches R25 table" % drill_id)
		assert_eq(str(definition.get("witness_npc_id", "")), str(spec.get("witness", "")), "%s witness is structured" % drill_id)
		assert_true(definition.get("rules", []) is Array and (definition.get("rules", []) as Array).size() == 3, "%s has exactly 3 mini-contract rules" % drill_id)


func test_perfect_drill_grants_rule_trust_and_acting_exp() -> void:
	var runner = _runner()
	if runner == null or not runner.has_method("resolve_drill"):
		assert_true(false, "DrillRunner exposes resolve_drill")
		return
	var setup := _state_with_card("thought_street_debate", 0)
	var gs = setup["state"]
	var card = setup["card"]
	gs.ap = 12
	var result: Dictionary = runner.call("resolve_drill", gs, "street_debate", {
		"satisfied_rule_ids": ["no_god_name", "quote_scripture", "avoid_sequence_word"],
		"thought_card_ids": [card.id],
		"rule_card_map": {"no_god_name": card.id, "quote_scripture": card.id, "avoid_sequence_word": card.id},
	})
	assert_true(bool(result.get("ok", false)), "street_debate perfect resolves")
	assert_eq(str(result.get("outcome", "")), "perfect", "street_debate reports perfect outcome")
	assert_eq(int(result.get("satisfied_count", 0)), 3, "street_debate satisfied all three rules")
	assert_true("holy_silence" in gs.learned_rules, "street_debate perfect unlocks holy_silence")
	assert_eq(int(card.acting_exp), 1, "perfect drill grants acting_exp to thought card")
	var relation = gs.npc_relations.get("thomas_priest", null)
	assert_true(relation != null, "perfect drill creates witness relation")
	if relation != null:
		assert_eq(int(relation.trust), 5, "perfect drill adds witness trust +5")
	assert_eq(int(gs.ap), 11, "street_debate spends 1 AP")
	gs.queue_free()


func test_partial_drill_grants_acting_exp_without_full_reward() -> void:
	var runner = _runner()
	if runner == null or not runner.has_method("resolve_drill"):
		assert_true(false, "DrillRunner exposes resolve_drill for partial path")
		return
	var setup := _state_with_card("thought_signal", 0)
	var gs = setup["state"]
	var card = setup["card"]
	gs.ap = 12
	var result: Dictionary = runner.call("resolve_drill", gs, "underground_signal", {
		"satisfied_rule_ids": ["use_correct_knock", "avoid_real_name"],
		"thought_card_ids": [card.id],
		"rule_card_map": {"use_correct_knock": card.id, "avoid_real_name": card.id},
	})
	assert_true(bool(result.get("ok", false)), "underground_signal partial resolves")
	assert_eq(str(result.get("outcome", "")), "partial", "underground_signal reports partial outcome")
	assert_eq(int(card.acting_exp), 1, "partial drill grants acting_exp to satisfied-rule card")
	assert_eq(int(gs.shop_discounts.get("donen_blackmarket", 0)), 5, "partial underground_signal grants half black-market discount")
	gs.queue_free()


func test_failure_penalties_apply_without_acting_exp() -> void:
	var runner = _runner()
	if runner == null or not runner.has_method("resolve_drill"):
		assert_true(false, "DrillRunner exposes resolve_drill for failure path")
		return
	var setup := _state_with_card("thought_smuggle", 0)
	var gs = setup["state"]
	var card = setup["card"]
	gs.ap = 12
	var result: Dictionary = runner.call("resolve_drill", gs, "smuggle_role", {
		"satisfied_rule_ids": [],
		"thought_card_ids": [card.id],
	})
	assert_true(bool(result.get("ok", false)), "smuggle_role failure still resolves")
	assert_eq(str(result.get("outcome", "")), "fail", "smuggle_role reports fail outcome")
	assert_eq(int(card.acting_exp), 0, "failed drill grants no acting_exp")
	var carl = gs.npc_relations.get("carl_smuggler", null)
	assert_true(carl != null, "failed smuggle_role creates Carl relation")
	if carl != null:
		assert_eq(int(carl.trust), -20, "failed smuggle_role applies Carl trust -20")
	assert_eq(int(gs.church_awareness), 5, "failed smuggle_role raises church awareness +5")
	gs.queue_free()

	var noble_setup := _state_with_card("thought_noble", 0)
	var noble_gs = noble_setup["state"]
	noble_gs.ap = 12
	noble_gs.day = 8
	noble_gs.church_awareness = 24
	noble_gs.set_ai_gm_service(FakeThresholdAIGMService.new())
	var noble_fail: Dictionary = runner.call("resolve_drill", noble_gs, "noble_salon", {
		"satisfied_rule_ids": [],
		"thought_card_ids": [noble_setup["card"].id],
	})
	assert_true(bool(noble_fail.get("ok", false)), "noble_salon failure resolves")
	assert_eq(int(noble_gs.church_awareness), 34, "failed noble_salon raises church awareness +10")
	assert_true(_has_threshold(noble_gs, 25), "failed noble_salon crossing 25 records church threshold event")
	assert_true(_threshold_ai_text(noble_gs, 25) != "", "failed noble_salon threshold event stores AI GM text")
	var modifiers := _activity_modifiers(noble_gs)
	assert_eq(int(modifiers.get("stone_tower_blocked_until_day", 0)), 15, "failed noble_salon blocks stone_tower for one week")
	noble_gs.queue_free()


func test_acting_exp_accumulates_to_upgrade_level() -> void:
	var runner = _runner()
	if runner == null or not runner.has_method("resolve_drill"):
		assert_true(false, "DrillRunner exposes resolve_drill for upgrade accumulation")
		return
	var setup := _state_with_card("thought_confession", 9)
	var gs = setup["state"]
	var card = setup["card"]
	gs.ap = 12
	var result: Dictionary = runner.call("resolve_drill", gs, "confess_innocent", {
		"satisfied_rule_ids": ["plain_story", "no_occult_word", "humble_exit"],
		"thought_card_ids": [card.id],
		"rule_card_map": {"plain_story": card.id, "no_occult_word": card.id, "humble_exit": card.id},
	})
	assert_true(bool(result.get("ok", false)), "confess_innocent perfect resolves")
	assert_eq(int(card.upgrade_level), 1, "acting_exp 9 + success triggers upgrade_level +1")
	assert_eq(int(card.acting_exp), 0, "acting_exp resets after upgrade")
	assert_eq(int(card.brand_slots), int(card.quality) + 1 + int(card.upgrade_level), "brand slots refresh after acting upgrade")
	gs.queue_free()

	var room_setup := _state_with_card("thought_confession_room", 0)
	var room_gs = room_setup["state"]
	room_gs.ap = 12
	var room_card = room_setup["card"]
	var room_result: Dictionary = runner.call("resolve_drill", room_gs, "confession_room", {
		"satisfied_rule_ids": ["plain_story", "no_occult_word", "humble_exit"],
		"thought_card_ids": [room_card.id],
		"rule_card_map": {"plain_story": room_card.id, "no_occult_word": room_card.id, "humble_exit": room_card.id},
	})
	assert_true(bool(room_result.get("ok", false)), "confession_room resolves as a real NPC drill module")
	assert_eq(str(room_result.get("outcome", "")), "perfect", "confession_room can resolve perfect")
	assert_eq(int(room_gs.ap), 11, "confession_room spends 1 AP")
	room_gs.queue_free()


func _runner():
	var script = load(RUNNER_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "DrillRunner script loads and can instantiate")
		return null
	return script.new()


func _state_with_card(card_id: String, acting_exp: int) -> Dictionary:
	var gs = GameStateScript.new()
	gs._ready()
	var card = CardScript.from_json({
		"id": card_id,
		"template_id": card_id,
		"display_name": card_id,
		"pathway": "fool",
		"sequence": 9,
		"rarity": "common",
		"quality": 1,
		"energy_cost": 1,
		"combat_effect": {"damage": 3, "target": "single"},
		"acting_rules": ["practice_rule"],
		"acting_exp": acting_exp,
	})
	gs.add_card(card)
	return {"state": gs, "card": card}


func _activity_modifiers(game_state) -> Dictionary:
	var value = game_state.get("activity_modifiers")
	if value is Dictionary:
		return value
	assert_true(false, "GameState exposes activity_modifiers for T7 drill penalties")
	return {}


func _has_threshold(gs, threshold: int) -> bool:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return true
	return false


func _threshold_ai_text(gs, threshold: int) -> String:
	for event in gs.church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return str((event as Dictionary).get("ai_gm_text", "")).strip_edges()
	return ""


class FakeThresholdAIGMService:
	extends RefCounted

	func call_ai_gm(_ctx) -> String:
		return "church threshold test text"


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
