extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const TurnBattleScript = preload("res://scripts/combat/turn_battle.gd")

var _passed := 0
var _failed := 0


func _result() -> Dictionary:
	return {"passed": _passed, "failed": _failed}


func _make_player(hp: int = 30):
	var player = CombatActorScript.new()
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


func _effect_card(id: String, effects: Array, damage: int = 0):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"element": "normal",
		"combat_effect": {
			"damage": damage,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": effects,
		},
		"tags": [],
	})


func _blank_card(id: String):
	return _effect_card(id, [], 0)


func _start_battle(cards: Array, player, enemy):
	var battle = TurnBattleScript.new()
	battle.setup_battle(cards, [], [enemy], [], player, _game_state())
	battle.hand.clear()
	for card in cards:
		battle.hand.append(card)
	battle.energy = 99
	return battle


func _game_state():
	var gs = GameStateScript.new()
	gs._ready()
	gs.sequence = 7
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
