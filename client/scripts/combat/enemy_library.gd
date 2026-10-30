extends Node

const EnemyScript = preload("res://scripts/combat/enemy.gd")
const ENEMIES_DIR := "res://data/combat/enemies/"

var _enemies: Dictionary = {}


func load_enemy(id: String):
	var path := ENEMIES_DIR + id + ".json"
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("id"):
		var enemy = EnemyScript.from_json(parsed)
		_enemies[enemy.id] = enemy
		return enemy
	return null


func get_enemy(id: String):
	return _enemies.get(id, null)


func clear() -> void:
	_enemies.clear()
