class_name WeatherEffectsApplier
extends RefCounted

# 天气加成静态查询 (R19 §4.6)
# 天气表从 data/weather/weather_table.json 加载，缓存为静态 Dictionary。

static var _table: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open("res://data/weather/weather_table.json", FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.get_data()
	if data is Array:
		for entry in data:
			if entry is Dictionary and entry.has("weather_id"):
				_table[str(entry["weather_id"])] = entry


static func get_bonus(weather_id: String, pathway: String, key: String) -> int:
	_ensure_loaded()
	var entry: Dictionary = _table.get(weather_id, {})
	if entry.is_empty():
		return 0
	var pathway_bonus: Dictionary = entry.get("pathway_bonus", {}).get(pathway, {})
	return int(pathway_bonus.get(key, 0))


static func get_forge_modifier(weather_id: String, pathway: String) -> int:
	return get_bonus(weather_id, pathway, "forge")


static func get_pollution_modifier(weather_id: String, pathway: String) -> int:
	return get_bonus(weather_id, pathway, "pollution")


static func get_global_modifier(weather_id: String, key: String) -> int:
	_ensure_loaded()
	var entry: Dictionary = _table.get(weather_id, {})
	if entry.is_empty():
		return 0
	var modifiers = entry.get("global_modifiers", {})
	if not modifiers is Dictionary:
		return 0
	return int(modifiers.get(key, 0))


static func reset_cache() -> void:
	# 仅测试用：清空缓存以便重新加载
	_table.clear()
	_loaded = false
