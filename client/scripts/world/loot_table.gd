class_name LootTable
extends RefCounted

# R16 §6 / R18 §4 采集结算
# loot_table: 给定 table_id（与城区 events 中的 loot_table 字段对应），按权重抽 1-3 项产出。
# 当前 MVP 不分 table_id，统一走默认池；未来可扩展为 data/loot/<table_id>.json。

const DEFAULT_TABLE := [
	{"weight": 40, "type": "lingstones", "min": 10, "max": 30},
	{"weight": 30, "type": "material", "material_id": "影尘", "amount": 1},
	{"weight": 15, "type": "dao_page_fragment", "amount": 1},
	{"weight": 10, "type": "trap", "pollution": 3},
	{"weight": 5, "type": "skip"},
]


static func resolve(table_id: String, game_state, seed: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_or_random(seed)
	var picks_count := rng.randi_range(1, 3)
	var rewards: Array = []
	var pollution_delta := 0
	var lingstones_added := 0
	var materials: Dictionary = {}
	var pages_added := 0
	var drop_modifier := _active_r20_drop_modifier(table_id, game_state)
	for i in range(picks_count):
		var entry: Dictionary = _weighted_pick(rng)
		if entry.is_empty():
			continue
		match str(entry.get("type", "")):
			"lingstones":
				var amount: int = rng.randi_range(int(entry.get("min", 10)), int(entry.get("max", 30)))
				lingstones_added += amount
				rewards.append({"type": "lingstones", "amount": amount})
			"material":
				var mat_id: String = str(entry.get("material_id", "影尘"))
				var amt: int = int(entry.get("amount", 1))
				materials[mat_id] = int(materials.get(mat_id, 0)) + amt
				rewards.append({"type": "material", "material_id": mat_id, "amount": amt})
			"dao_page_fragment":
				pages_added += int(entry.get("amount", 1))
				rewards.append({"type": "dao_page_fragment", "amount": int(entry.get("amount", 1))})
			"trap":
				pollution_delta += int(entry.get("pollution", 3))
				rewards.append({"type": "trap", "pollution": int(entry.get("pollution", 3))})
			"skip":
				rewards.append({"type": "skip"})
	var drop_modifier_applied := not drop_modifier.is_empty()
	var drop_modifier_text := ""
	if drop_modifier_applied:
		drop_modifier_text = _drop_modifier_text(drop_modifier)
		var lingstone_multiplier := float(drop_modifier.get("lingstones_multiplier", drop_modifier.get("multiplier", 1.0)))
		if lingstone_multiplier > 0.0 and not is_equal_approx(lingstone_multiplier, 1.0) and lingstones_added > 0:
			var adjusted_lingstones := maxi(0, int(round(float(lingstones_added) * lingstone_multiplier)))
			var delta_lingstones := adjusted_lingstones - lingstones_added
			lingstones_added = adjusted_lingstones
			if delta_lingstones != 0:
				rewards.append({"type": "lingstones", "amount": delta_lingstones, "source": "r20_drop_modifier"})
		var bonus_material_id := str(drop_modifier.get("bonus_material_id", drop_modifier.get("material_id", ""))).strip_edges()
		var bonus_material_amount := int(drop_modifier.get("bonus_material_amount", drop_modifier.get("amount", 0)))
		if bonus_material_id != "" and bonus_material_amount > 0:
			materials[bonus_material_id] = int(materials.get(bonus_material_id, 0)) + bonus_material_amount
			rewards.append({
				"type": "material",
				"material_id": bonus_material_id,
				"amount": bonus_material_amount,
				"source": "r20_drop_modifier",
			})
	if game_state != null:
		game_state.lingstones += lingstones_added
		for mat_id in materials:
			game_state.forge_materials[mat_id] = int(game_state.forge_materials.get(mat_id, 0)) + int(materials[mat_id])
		if pages_added > 0:
			# 残页碎片直接折算为完整页（MVP 简化：每 3 碎片 = 1 页向上取整）
			var pages_int: int = int(ceil(float(pages_added) / 3.0))
			game_state.dao_pages = int(game_state.dao_pages) + pages_int
		if pollution_delta > 0:
			game_state.pollution = clampi(int(game_state.pollution) + pollution_delta, 0, 100)
	return {
		"rewards": rewards,
		"lingstones_added": lingstones_added,
		"materials": materials,
		"pages_added": pages_added,
		"pollution_delta": pollution_delta,
		"r20_drop_modifier_applied": drop_modifier_applied,
		"drop_modifier_text": drop_modifier_text,
	}


static func _weighted_pick(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for entry in DEFAULT_TABLE:
		total += int(entry.get("weight", 1))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	var running := 0
	for entry in DEFAULT_TABLE:
		running += int(entry.get("weight", 1))
		if roll <= running:
			return entry
	return DEFAULT_TABLE[-1]


static func _seed_or_random(seed: int) -> int:
	if seed != 0:
		return seed
	return int(Time.get_ticks_usec())


static func _active_r20_drop_modifier(table_id: String, game_state) -> Dictionary:
	if game_state == null:
		return {}
	var modifiers: Variant = game_state.get("activity_modifiers")
	if not modifiers is Dictionary:
		return {}
	var modifier: Variant = (modifiers as Dictionary).get("r20_alter_drop_table", {})
	if not modifier is Dictionary:
		return {}
	var data: Dictionary = (modifier as Dictionary).duplicate(true)
	var modifier_table := str(data.get("table_id", data.get("loot_table", ""))).strip_edges()
	if modifier_table != "" and table_id != "" and modifier_table != table_id:
		return {}
	var modifier_district := str(data.get("district", "")).strip_edges()
	var current_district := str(game_state.current_district).strip_edges()
	if modifier_district != "" and current_district != "" and modifier_district != current_district:
		return {}
	var expires_at := int(data.get("expires_at_day", 0))
	if expires_at > 0 and int(game_state.day) > expires_at:
		return {}
	return data


static func _drop_modifier_text(modifier: Dictionary) -> String:
	var text := str(modifier.get("display_text", "")).strip_edges()
	if text != "":
		return text
	var district := str(modifier.get("district", "")).strip_edges()
	if district != "":
		return "\u6389\u843d\u5df2\u6539\u5199\uff1a%s" % district
	return "\u6389\u843d\u5df2\u6539\u5199"
