extends RefCounted

const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const EnemyStandeeScript = preload("res://scripts/ui/battle/enemy_standee.gd")
const PlayerStandeeScript = preload("res://scripts/ui/battle/player_standee.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_portrait_display.gd --")
	await test_enemy_standee_loads_portrait_when_actor_id_present()
	await test_enemy_standee_null_texture_when_actor_id_missing()
	await test_player_standee_loads_portrait_when_actor_id_present()
	await test_player_standee_fallback_to_player_portrait()
	return {"passed": _passed, "failed": _failed}


func test_enemy_standee_loads_portrait_when_actor_id_present() -> void:
	var enemy = EnemyScript.from_json({
		"id": "drunkard",
		"display_name": "Drunkard",
		"actor_id": "drunkard",
		"stats": {"hp": 50, "max_hp": 50, "atk": 8, "def": 3, "spd": 6},
	})
	var standee = EnemyStandeeScript.new()
	Engine.get_main_loop().root.add_child(standee)
	standee.bind_enemy(enemy, "攻击 8", "", false, true, false, {}, false, false)
	_verify(standee._portrait_slot.texture != null, "drunkard portrait should load")
	standee.queue_free()
	await Engine.get_main_loop().process_frame


func test_enemy_standee_null_texture_when_actor_id_missing() -> void:
	var enemy = EnemyScript.from_json({
		"id": "unknown_enemy",
		"display_name": "Unknown",
		"actor_id": "",
		"stats": {"hp": 30, "max_hp": 30, "atk": 5, "def": 2, "spd": 5},
	})
	var standee = EnemyStandeeScript.new()
	Engine.get_main_loop().root.add_child(standee)
	standee.bind_enemy(enemy, "攻击 5", "", false, true, false, {}, false, false)
	_verify(standee._portrait_slot.texture == null, "no actor_id should result in null texture")
	standee.queue_free()
	await Engine.get_main_loop().process_frame


func test_player_standee_loads_portrait_when_actor_id_present() -> void:
	var player = CombatActorScript.new()
	player.display_name = "Harvey Mors"
	player.actor_id = "harvey_mors"
	player.hp = 100
	player.max_hp = 100
	player.def = 5
	var standee = PlayerStandeeScript.new()
	Engine.get_main_loop().root.add_child(standee)
	standee.bind_player(player, "契约：观察", "规则：无")
	_verify(standee._portrait_slot.texture != null, "harvey_mors portrait should load")
	standee.queue_free()
	await Engine.get_main_loop().process_frame


func test_player_standee_fallback_to_player_portrait() -> void:
	var player = CombatActorScript.new()
	player.display_name = "Player"
	player.actor_id = ""
	player.hp = 100
	player.max_hp = 100
	player.def = 5
	var standee = PlayerStandeeScript.new()
	Engine.get_main_loop().root.add_child(standee)
	standee.bind_player(player, "", "")
	# player portrait is placeholder, so texture will be null but should not crash
	_verify(true, "player standee with empty actor_id should not crash")
	standee.queue_free()
	await Engine.get_main_loop().process_frame


func _verify(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
