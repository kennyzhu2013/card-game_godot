class_name BrandCatalog
extends RefCounted

const BrandScript = preload("res://scripts/combat/brand.gd")

const DEFAULT_PATH := "res://data/brands/mvp_30.json"
const DEFAULT_BOSS_POOL := "boss_default"


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func load_all_brands(path: String = DEFAULT_PATH) -> Array:
	var result: Array = []
	var data: Dictionary = load_data(path)
	var entries: Array = data.get("brands", [])
	for entry in entries:
		if entry is Dictionary:
			result.append(BrandScript.from_dict(entry))
	return result


static func category_counts(path: String = DEFAULT_PATH) -> Dictionary:
	var counts: Dictionary = {}
	var data: Dictionary = load_data(path)
	var entries: Array = data.get("brands", [])
	for entry in entries:
		if not entry is Dictionary:
			continue
		var category: String = str(entry.get("category", ""))
		counts[category] = int(counts.get(category, 0)) + 1
	return counts


static func get_brand_dict(brand_id: String, path: String = DEFAULT_PATH) -> Dictionary:
	var data: Dictionary = load_data(path)
	var entries: Array = data.get("brands", [])
	for entry in entries:
		if entry is Dictionary and str(entry.get("id", "")) == brand_id:
			return entry.duplicate(true)
	return {}


static func create_brand(brand_id: String, path: String = DEFAULT_PATH):
	var data: Dictionary = get_brand_dict(brand_id, path)
	if data.is_empty():
		return null
	return BrandScript.from_dict(data)


static func pool_ids(pool_id: String, path: String = DEFAULT_PATH) -> Array[String]:
	var result: Array[String] = []
	var data: Dictionary = load_data(path)
	var pools: Dictionary = data.get("pools", {})
	var raw_pool: Variant = pools.get(pool_id, [])
	if raw_pool is Array:
		for item in raw_pool:
			result.append(str(item))
	return result


static func resolve_boss_brand_drop(victory_drops: Dictionary, game_state, roll: float = 0.0, path: String = DEFAULT_PATH):
	if not bool(victory_drops.get("brand_guaranteed", false)):
		return null
	var pool_id: String = str(victory_drops.get("brand_pool", DEFAULT_BOSS_POOL))
	var ids: Array[String] = pool_ids(pool_id, path)
	if ids.is_empty():
		ids = pool_ids(DEFAULT_BOSS_POOL, path)
	if ids.is_empty():
		return null
	var clamped_roll: float = clampf(roll, 0.0, 0.999999)
	var index: int = mini(ids.size() - 1, int(floor(clamped_roll * float(ids.size()))))
	return grant_brand_to_state(ids[index], game_state, path)


static func grant_brand_to_state(brand_id: String, game_state, path: String = DEFAULT_PATH):
	var brand = create_brand(brand_id, path)
	if brand == null:
		return null
	if game_state != null:
		game_state.brands_inventory.append(brand)
		var discovered: Array = game_state.daodian.get("discovered_brands", [])
		if not brand.id in discovered:
			discovered.append(brand.id)
		game_state.daodian["discovered_brands"] = discovered
	return brand
