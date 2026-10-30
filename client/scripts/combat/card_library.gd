extends Node

# Per design/2026-05-24-tower-deck-combat-redesign.md §5
# 卡库管理：从 data/cards/*.json 加载（优先），data/skills/*.json 兼容（旧迁移期）。
# Singleton autoload 候选：CardLibrary

const CardScript = preload("res://scripts/combat/card.gd")
const CARDS_DIR := "res://data/cards/"
const SKILLS_DIR := "res://data/skills/"

var _cards: Dictionary = {}
var _card_pools: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	_cards.clear()
	_card_pools.clear()
	# Load legacy skill cards first, then let data/cards override matching ids.
	_load_dir(SKILLS_DIR, true)
	_load_dir(CARDS_DIR, false)


func _load_dir(path: String, as_skill: bool) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			_load_file(path + fname, as_skill)
		fname = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String, as_skill: bool) -> void:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary:
				_register_card(entry, as_skill)
		return
	if parsed is Dictionary and parsed.has("cards"):
		var entries = parsed.get("cards", [])
		if entries is Array:
			for entry in entries:
				if entry is Dictionary:
					_register_card(entry, as_skill)
		return
	if parsed is Dictionary and parsed.has("id"):
		_register_card(parsed, as_skill)


func _register_card(data: Dictionary, as_skill: bool) -> void:
	var card: Card = CardScript.from_skill_json(data) if as_skill else CardScript.from_json(data)
	if card == null or str(card.id) == "":
		return
	_cards[card.id] = card
	_card_pools[card.id] = str(data.get("card_pool", ""))


func get_card(id: String) -> Card:
	return _cards.get(id, null)


func all_cards() -> Array:
	_ensure_loaded()
	return _cards.values()


func roll_from_pool(pool_id: String, seed: int = 0) -> Card:
	_ensure_loaded()
	var candidates: Array = _cards_for_pool(pool_id)
	if candidates.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	var template: Card = candidates[rng.randi_range(0, candidates.size() - 1)]
	var card := CardScript.from_json(template.to_dict())
	card.id = _unique_temp_id(card.template_id)
	return card


func cards_by_pathway(pathway: String) -> Array:
	var result: Array = []
	for c in _cards.values():
		if c.pathway == pathway:
			result.append(c)
	return result


func cards_by_sequence(pathway: String, sequence: int) -> Array:
	var result: Array = []
	for c in _cards.values():
		if c.pathway == pathway and c.sequence == sequence:
			result.append(c)
	return result


func _ensure_loaded() -> void:
	if _cards.is_empty():
		load_all()


func _cards_for_pool(pool_id: String) -> Array:
	var result: Array = []
	for card_id in _cards:
		var card: Card = _cards[card_id]
		if _card_matches_pool(str(card_id), card, pool_id):
			result.append(card)
	return result


func _card_matches_pool(card_id: String, card: Card, pool_id: String) -> bool:
	var explicit_pool := str(_card_pools.get(card_id, ""))
	if explicit_pool == pool_id:
		return true
	match pool_id:
		"shadow_alley_low", "fool_s9_pool", "fool_s9_elite_pool":
			return explicit_pool == "fool_pathway" and card.pathway == "fool" and int(card.sequence) == 9
		"fool_s8_pool":
			return explicit_pool == "fool_pathway" and card.pathway == "fool" and int(card.sequence) == 8
		"fool_s7_pool":
			return explicit_pool == "fool_pathway" and card.pathway == "fool" and int(card.sequence) == 7
	return false


func _unique_temp_id(template_id: String) -> String:
	var base := template_id if template_id != "" else "temp_card"
	return "%s_temp_%d_%d" % [base, Time.get_ticks_usec(), randi() % 1000000]
