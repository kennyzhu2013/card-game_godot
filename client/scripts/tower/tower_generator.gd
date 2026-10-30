class_name TowerGenerator
extends RefCounted

const FloorScript = preload("res://scripts/tower/floor.gd")
const TowerScript = preload("res://scripts/tower/tower.gd")
const SaveStoreScript = preload("res://scripts/state/save_store.gd")
const WeatherEffectsApplierScript = preload("res://scripts/state/weather_effects_applier.gd")

const ENEMY_PACK_DIR := "res://data/combat/enemy_packs/"
const EVENT_DIR := "res://data/events/"
const SHRINE_DIR := "res://data/shrines/"
const BOSS_TABLE_PATH := "res://data/towers/boss_table.json"

const REQUIRED_NODE_TYPES := ["battle", "elite", "event", "merchant", "shrine", "boss"]
const EVENT_WEIGHTS := [
	{"type": "battle", "weight": 50},
	{"type": "elite", "weight": 15},
	{"type": "event", "weight": 15},
	{"type": "shrine", "weight": 10},
	{"type": "merchant", "weight": 5},
	{"type": "unknown", "weight": 5},
]

var last_auto_save_ok: bool = false


func spawn_tower(size: String, district: String, game_state, seed: int = 0, auto_save_path: String = SaveStoreScript.AUTO_PATH):
	last_auto_save_ok = SaveStoreScript.save_auto(game_state, auto_save_path)
	size = _apply_weather_size_modifier(size, game_state, seed)
	return generate_tower(size, district, seed)


func generate_tower(size: String, district: String = "", seed: int = 0):
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_or_default(seed)
	var tower = TowerScript.new()
	tower.size = _normalize_size(size)
	tower.district = district
	tower.floor_count = _floor_count_for_size(tower.size, rng)
	tower.tower_id = "%s_%s_%d" % [tower.size, district, seed]
	tower.tower_name = _tower_name(tower.size, district)
	for i in range(tower.floor_count):
		var event_type := "boss" if i == tower.floor_count - 1 else _roll_event_type(rng)
		tower.floors.append(_make_floor(
			i,
			event_type,
			build_event_data(event_type, i, district),
			_default_narrative(event_type, i)
		))
	return tower


func inject_extra_elite_floor(tower) -> Dictionary:
	if tower == null:
		return {"ok": false, "reason": "missing_tower"}
	var insert_index := _extra_elite_insert_index(tower)
	var district_id := str(tower.district)
	var floor = _make_floor(
		insert_index,
		"elite",
		build_event_data("elite", insert_index, district_id),
		"Extra elite encounter"
	)
	tower.floors.insert(insert_index, floor)
	_reindex_tower_floors(tower)
	tower.theme_modifiers["npc_extra_elite_injected"] = int(tower.theme_modifiers.get("npc_extra_elite_injected", 0)) + 1
	return {"ok": true, "floor_index": insert_index}


func _make_floor(index: int, event_type: String, event_data: Dictionary, narrative: String = ""):
	var floor = FloorScript.new()
	floor.floor_index = index
	floor.event_type = event_type
	floor.event_data = event_data.duplicate(true)
	floor.ai_gm_narrative = narrative
	return floor


func _extra_elite_insert_index(tower) -> int:
	for i in range(tower.floors.size() - 1, -1, -1):
		var floor = tower.floors[i]
		if floor != null and str(floor.event_type) == "boss":
			return i
	return tower.floors.size()


func _reindex_tower_floors(tower) -> void:
	for i in range(tower.floors.size()):
		var floor = tower.floors[i]
		if floor != null:
			floor.floor_index = i
	tower.floor_count = tower.floors.size()


func build_event_data(event_type: String, floor_index: int, district: String = "") -> Dictionary:
	match event_type:
		"battle":
			return _battle_data_from_pack(_pack_id(district, "t1"), false)
		"elite":
			return _battle_data_from_pack(_pack_id(district, "elite_t1"), true)
		"event":
			return _event_template_for(district, floor_index)
		"merchant":
			return {
				"shop_id": "tower_merchant",
				"slot_count": 3,
				"item_pool": "tower_merchant_t1",
				"discount_pct": 15,
			}
		"shrine":
			return _shrine_data("heal")
		"unknown":
			return {
				"outcome_table": [
					{"weight": 40, "type": "trap", "payload": {"pollution": 5, "ap_loss": 1}},
					{"weight": 35, "type": "loot", "payload": {"lingstones": 50, "material_id": "shadow_dust"}},
					{"weight": 15, "type": "old_man", "payload": {"event_id": "old_man_blessing"}},
					{"weight": 10, "type": "skip", "payload": {}},
				],
			}
		"boss":
			return _boss_data(district)
	return {}


func _battle_data_from_pack(pack_id: String, elite: bool) -> Dictionary:
	var pack: Dictionary = _load_json(ENEMY_PACK_DIR + pack_id + ".json")
	if not pack.is_empty():
		return {
			"enemy_pack_id": str(pack.get("id", pack_id)),
			"enemy_ids": _array(pack.get("enemy_ids", [])),
			"candidate_card_pool": str(pack.get("candidate_card_pool", "fool_s9_elite_pool" if elite else "fool_s9_pool")),
			"drop_table": _dict(pack.get("drop_table", {})),
		}
	return {
		"enemy_pack_id": pack_id,
		"enemy_ids": ["inquisitor"] if elite else ["drunkard"],
		"candidate_card_pool": "fool_s9_elite_pool" if elite else "fool_s9_pool",
		"drop_table": {
			"lingstones": [30, 60] if elite else [10, 30],
			"material_chance": 0.85 if elite else 0.6,
			"brand_chance": 0.05 if elite else 0.0,
		},
	}


func _event_template_for(district: String, floor_index: int) -> Dictionary:
	var selected: Array = []
	var district_id: String = _district_or_default(district)
	var content_district_id: String = _content_district_id(district)
	for path in _json_files(EVENT_DIR):
		var data: Dictionary = _load_json(path)
		if str(data.get("district", "")) == content_district_id:
			selected.append(data)
	if selected.is_empty():
		return {
			"event_id": "%s_event_%02d" % [district_id, floor_index],
			"title": "塔层异兆",
			"narrative_template": "你在塔层尽头看见一枚倒悬的影子。",
			"choices": [
				{"id": "inspect", "text": "靠近观察", "outcome": {"pollution": 5}},
				{"id": "leave", "text": "绕开", "outcome": {}},
			],
		}
	var index: int = floor_index % selected.size()
	var template: Dictionary = selected[index].duplicate(true)
	template["event_id"] = str(template.get("id", template.get("event_id", "")))
	template.erase("id")
	template.erase("district")
	return template


func _shrine_data(shrine_id: String) -> Dictionary:
	var data: Dictionary = _load_json(SHRINE_DIR + shrine_id + ".json")
	if not data.is_empty():
		return {
			"shrine_type": str(data.get("shrine_type", data.get("id", shrine_id))),
			"title": str(data.get("title", "")),
			"service_payload": _dict(data.get("service_payload", {})),
			"description": str(data.get("description", "")),
		}
	return {
		"shrine_type": "heal",
		"service_payload": {"heal_amount": 20},
	}


func _boss_data(district: String) -> Dictionary:
	var table: Dictionary = _load_json(BOSS_TABLE_PATH)
	var bosses: Dictionary = _dict(table.get("bosses", {}))
	var district_id: String = _district_or_default(district)
	var current_district_id: String = _current_district_id(district)
	var content_district_id: String = _content_district_id(district)
	var data: Dictionary = _dict(bosses.get(current_district_id, bosses.get(district_id, bosses.get(content_district_id, bosses.get("shadow_alley", {})))))
	if not data.is_empty():
		return {
			"boss_id": str(data.get("boss_id", _boss_id(district_id))),
			"boss_pack": _array(data.get("boss_pack", [])),
			"victory_drops": _dict(data.get("victory_drops", {})),
			"defeat_penalty": _dict(data.get("defeat_penalty", {"pollution": 20, "tower_collapse": true})),
		}
	return {
		"boss_id": _boss_id(district_id),
		"boss_pack": [],
		"victory_drops": {
			"brand_guaranteed": true,
			"brand_pool": "fool_low_tier_brands",
			"lingstones": [80, 150],
			"dao_page_chance": 0.05,
		},
		"defeat_penalty": {
			"pollution": 20,
			"tower_collapse": true,
		},
	}


func _json_files(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			result.append(path + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


func _floor_count_for_size(size: String, rng: RandomNumberGenerator) -> int:
	match size:
		"medium":
			return rng.randi_range(6, 8)
		"large":
			return rng.randi_range(10, 15)
		_:
			return rng.randi_range(3, 4)


func _roll_event_type(rng: RandomNumberGenerator) -> String:
	var total := 0
	for entry in EVENT_WEIGHTS:
		total += int(entry.weight)
	var roll := rng.randi_range(1, total)
	var running := 0
	for entry in EVENT_WEIGHTS:
		running += int(entry.weight)
		if roll <= running:
			return str(entry.type)
	return "battle"


func _normalize_size(size: String) -> String:
	return size if size in ["small", "medium", "large"] else "small"


func _apply_weather_size_modifier(size: String, game_state, seed: int) -> String:
	var normalized := _normalize_size(size)
	if game_state == null:
		return normalized
	var weather_id := str(game_state.current_weather)
	if weather_id == "":
		return normalized
	var bonus := WeatherEffectsApplierScript.get_global_modifier(weather_id, "tower_size_up")
	if bonus <= 0:
		return normalized
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_or_default(seed)
	if bonus < 100 and rng.randi_range(1, 100) > bonus:
		return normalized
	match normalized:
		"small":
			return "medium"
		"medium":
			return "large"
		_:
			return normalized


func _seed_or_default(seed: int) -> int:
	return seed if seed != 0 else int(Time.get_unix_time_from_system())


func _pack_id(district: String, tier: String) -> String:
	return "%s_%s" % [_content_district_id(district), tier]


func _district_or_default(district: String) -> String:
	return district if district != "" else "shadow_alley"


func _content_district_id(district: String) -> String:
	match _district_or_default(district):
		"steelworks":
			return "steel_district"
		"misty_port":
			return "mist_harbor"
		"sacred_seven":
			return "seven_saints"
		_:
			return _district_or_default(district)


func _current_district_id(district: String) -> String:
	match _district_or_default(district):
		"steel_district":
			return "steelworks"
		"mist_harbor":
			return "misty_port"
		"seven_saints":
			return "sacred_seven"
		_:
			return _district_or_default(district)


func _boss_id(district: String) -> String:
	match district:
		"misty_port", "mist_harbor":
			return "smuggler_captain"
		"steelworks", "steel_district":
			return "slag_golem"
		"stone_tower":
			return "noble_conspirator"
		"sacred_seven", "seven_saints":
			return "church_inquisitor"
		_:
			return "alley_horror"


func _tower_name(size: String, district: String) -> String:
	return "%s tower: %s" % [size.capitalize(), _district_or_default(district)]


func _default_narrative(event_type: String, floor_index: int) -> String:
	return "第%d层：%s" % [floor_index + 1, event_type]
