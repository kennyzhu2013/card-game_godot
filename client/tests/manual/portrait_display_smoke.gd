extends SceneTree

const EnemyScript = preload("res://scripts/combat/enemy.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyStandeeScript = preload("res://scripts/ui/battle/enemy_standee.gd")
const PlayerStandeeScript = preload("res://scripts/ui/battle/player_standee.gd")


func _init() -> void:
	print("=== SMOKE portrait_display ===")
	await process_frame

	var results: Array[String] = []

	# Test enemy standee with drunkard portrait
	var drunkard_enemy = EnemyScript.from_json({
		"id": "drunkard",
		"display_name": "Drunkard",
		"actor_id": "drunkard",
		"stats": {"hp": 50, "max_hp": 50, "atk": 8, "def": 3, "spd": 6},
	})
	var enemy_standee = EnemyStandeeScript.new()
	enemy_standee._ensure_ui()
	enemy_standee.bind_enemy(drunkard_enemy, "攻击 8", "", false, true, false, {}, false, false)
	var enemy_loaded := enemy_standee._portrait_slot.texture != null
	results.append("enemy=drunkard loaded=%s" % str(enemy_loaded).to_lower())

	# Test player standee with player portrait (or harvey_mors)
	var player_actor = CombatActorScript.new()
	player_actor.display_name = "Player"
	player_actor.actor_id = "player"
	player_actor.hp = 100
	player_actor.max_hp = 100
	player_actor.def = 5
	var player_standee = PlayerStandeeScript.new()
	player_standee._ensure_ui()
	player_standee.bind_player(player_actor, "", "")
	var player_loaded := player_standee._portrait_slot.texture != null
	results.append("player=player loaded=%s" % str(player_loaded).to_lower())

	var output := "SMOKE portrait_display %s" % " ".join(results)
	print(output)

	_write_smoke_log(output)

	quit(0)


func _write_smoke_log(output: String) -> void:
	var dir_path := ProjectSettings.globalize_path("user://qa/portrait_display")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open("%s/portrait_display_smoke.log" % dir_path, FileAccess.WRITE)
	if file != null:
		file.store_string(output + "\n")
		file.close()
