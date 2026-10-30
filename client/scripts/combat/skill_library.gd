extends Node

const SkillScript = preload("res://scripts/combat/skill.gd")
const SKILLS_DIR := "res://data/skills/"

var _skills: Dictionary = {}


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	_skills.clear()
	var dir := DirAccess.open(SKILLS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			_load_file(SKILLS_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("id"):
		var skill = SkillScript.from_json(parsed)
		_skills[skill.id] = skill


func get_skill(id: String):
	return _skills.get(id, null)


func all_skills() -> Array:
	return _skills.values()
