extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const EffectEngineScript = preload("res://scripts/combat/effect_engine.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")

const SKILLS_DIR := "res://data/skills/"
const EXPECTED_CARDS := [
	"fool_s9_spirit_vision",
	"fool_s9_star_chart_divination",
	"fool_s9_pendulum_query",
	"fool_s9_ritual_chant",
	"fool_s9_arcane_lore",
	"fool_s9_premonition",
	"fool_s8_acrobat_strike",
	"fool_s8_paper_blade_volley",
	"fool_s8_microexpression_read",
	"fool_s8_predator_instinct",
	"fool_s8_strongman_burst",
	"fool_s7_wound_displacement",
	"fool_s7_flame_jump",
	"fool_s7_air_bullet",
	"fool_s7_paper_doll_substitute",
	"fool_s7_flame_command",
	"fool_s7_illusion_weave",
	"fool_s7_water_breath",
	"fool_s7_bone_softening",
	"fool_s7_paper_arsenal",
	"fool_s7_swift_cast",
	"fool_s7_minor_trick",
]

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_sequence_gate_effect_mapping.gd --")
	test_effect_to_mechanism_covers_all_fool_9_7_effect_ids()
	test_sequence_9_rejects_multi_strike_effect_card()
	return {"passed": _passed, "failed": _failed}


func test_effect_to_mechanism_covers_all_fool_9_7_effect_ids() -> void:
	var effect_engine := EffectEngineScript.new()
	assert_true(effect_engine.has_method("mechanism_for_effect_id"), "EffectEngine exposes mechanism lookup")
	if not effect_engine.has_method("mechanism_for_effect_id"):
		return
	for card_id in EXPECTED_CARDS:
		var data := _load_card_data(card_id)
		assert_true(not data.is_empty(), "%s JSON loads" % card_id)
		for effect_id in _collect_effect_ids(data):
			var mechanism := str(effect_engine.call("mechanism_for_effect_id", effect_id))
			assert_true(mechanism != "", "%s effect_id maps to a mechanism tag: %s" % [card_id, effect_id])


func test_sequence_9_rejects_multi_strike_effect_card() -> void:
	var card := CardScript.from_json({
		"id": "sequence_gate_multi_strike",
		"template_id": "sequence_gate_multi_strike",
		"display_name": "sequence_gate_multi_strike",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 1,
		"element": "normal",
		"combat_effect": {
			"damage": 12,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [{"id": "multi_strike", "hits": 3, "damage_each": 4}],
		},
		"tags": ["attack"],
	})
	var battle := TurnBattleScript.new()
	battle.setup_battle([card], [], [], [], null, _game_state(9))
	battle.hand.clear()
	battle.hand.append(card)
	battle.energy = 99
	assert_true(not battle.can_play_card(card), "sequence 9 rejects multi_strike effect even when the card type tag is attack")


func _load_card_data(card_id: String) -> Dictionary:
	var path := "%s%s.json" % [SKILLS_DIR, card_id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _collect_effect_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_collect_effect_ids_from_effects(_card_effects(data), result)
	return result


func _collect_effect_ids_from_effects(effects: Array, result: Array[String]) -> void:
	for effect in effects:
		if not effect is Dictionary:
			continue
		var effect_id := str(effect.get("id", ""))
		if effect_id != "" and not effect_id in result:
			result.append(effect_id)
		var payload = effect.get("payload", [])
		if payload is Array:
			_collect_effect_ids_from_effects(payload, result)
		var options = effect.get("options", [])
		if options is Array:
			for option in options:
				if not option is Dictionary:
					continue
				_collect_effect_ids_from_effects(_card_effects(option), result)


func _card_effects(data: Dictionary) -> Array:
	var combat = data.get("combat_effect", {})
	if combat is Dictionary:
		var effects = combat.get("status_effects", [])
		if effects is Array:
			return effects
	return []


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
