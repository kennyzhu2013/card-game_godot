class_name ForgeResultCalculator
extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const WeatherEffectsApplierScript = preload("res://scripts/state/weather_effects_applier.gd")

const QUALITY_THRESHOLDS := [
	{"min_perfect_rate": 0.95, "id": 5, "name": "极品", "stars": 5},
	{"min_perfect_rate": 0.85, "id": 4, "name": "良品", "stars": 4},
	{"min_perfect_rate": 0.70, "id": 3, "name": "普品", "stars": 3},
	{"min_perfect_rate": 0.50, "id": 2, "name": "瑕品", "stars": 2},
	{"min_perfect_rate": 0.0,  "id": 1, "name": "废品", "stars": 1},
]
const QUALITY_MULTIPLIER := {5: 1.50, 4: 1.20, 3: 1.00, 2: 0.80, 1: 0.50}
const REACTION_TO_SKILL := {
	"shadow_arrow":   "shadow_arrow",
	"shadow_jester":  "shadow_jester",
	"flame_arrow":    "flame_arrow",
	"water_touch":    "water_touch",
	"inquiry_mirror": "inquiry_mirror",
	"shadow_flame":   "shadow_flame",
	"shadow_water":   "shadow_water",
	"jester_arrow":   "jester_arrow",
	"name_arrow":     "name_arrow",
	"inquiry_arrow":  "inquiry_arrow",
	"mirror_arrow":   "mirror_arrow",
	"fortune_arrow":  "fortune_arrow",
	"thread_arrow":   "thread_arrow",
	"arrow_water":    "arrow_water",
	"flame_water":    "flame_water",
}
const FORGE_MATERIAL_COST := {"愚者残页": 2}
const FORGE_BRAND_IDS := [
	"forge_residue_low",
	"forge_residue_mid",
	"forge_residue_high",
	"forge_residue_unique",
]

static var _next_card_serial := 0


static func evaluate_quality(perfect_rate: float) -> Dictionary:
	for tier in QUALITY_THRESHOLDS:
		if perfect_rate >= tier.min_perfect_rate:
			return tier
	return QUALITY_THRESHOLDS.back()


static func material_multiplier_for_quality(quality: int) -> float:
	return float(QUALITY_MULTIPLIER.get(clampi(quality, 1, 5), 1.0))


static func forge(reaction_id: String, perfect_rate: float, arrangement, skill_library, game_state = null) -> Dictionary:
	var quality = evaluate_quality(perfect_rate)
	var source_symbol_ids := _source_symbol_ids(arrangement)
	var resolved_game_state = _resolve_game_state(game_state)
	_record_symbol_uses(source_symbol_ids, resolved_game_state, false)
	var multiplier: float = material_multiplier_for_quality(quality.id)
	var forge_weather_bonus_percent := _forge_weather_bonus_percent(resolved_game_state)
	var material_outputs := _forge_material_outputs(int(quality.id), forge_weather_bonus_percent)
	var skill_id: String = REACTION_TO_SKILL.get(reaction_id, "")
	var base = skill_library.get_skill(skill_id) if skill_id != "" else null
	var forged_card: Card
	var forged_skill = null

	if base != null:
		forged_skill = Skill.from_json(base.to_dict())
		forged_skill.damage = int(base.damage * multiplier)
		forged_skill.heal = int(base.heal * multiplier)
		forged_skill.tier = quality.id
		forged_skill.source_symbol_ids = source_symbol_ids
		forged_card = build_card_from_skill(skill_id, forged_skill, quality)
	else:
		forged_card = build_card_from_reaction(reaction_id, quality, multiplier, source_symbol_ids)

	return {
		"quality": quality,
		"multiplier": multiplier,
		"base_skill": base,
		"forged_skill": forged_skill,
		"forged_card": forged_card,
		"source_arrangement": arrangement,
		"material_outputs": material_outputs,
		"forge_weather_bonus_percent": forge_weather_bonus_percent,
	}


static func build_card_from_skill(template_id: String, forged_skill, quality: Dictionary):
	if forged_skill == null:
		return null
	var data: Dictionary = forged_skill.to_dict()
	data["id"] = _unique_card_id(template_id)
	data["template_id"] = template_id
	data["quality"] = int(quality.get("id", 1))
	data["rarity"] = _rarity_for_quality(int(quality.get("id", 1)))
	data["brand_slots"] = int(quality.get("id", 1)) + 1
	return CardScript.from_skill_json(data)


static func build_card_from_reaction(reaction_id: String, quality: Dictionary, multiplier: float, source_symbol_ids: Array) -> Card:
	var c := Card.new()
	c.id = _unique_card_id(reaction_id)
	c.template_id = reaction_id
	c.display_name = reaction_id.replace("_", "+")
	c.quality = quality.id
	c.rarity = _rarity_for_quality(quality.id)
	c.brand_slots = quality.id + 1
	c.pathway = "fool"
	c.energy_cost = clampi(quality.id / 2, 1, 3)
	c.damage = int(10 * multiplier * quality.id)
	c.heal = 0
	c.element = "普通"
	c.target = "single"
	c.description = reaction_id.replace("_", "+") + " 反应锻造"
	return c


static func deduct_forge_materials(game_state, multiplier: float = 1.0) -> void:
	if game_state == null:
		return
	for material_name in FORGE_MATERIAL_COST:
		var amount := int(ceil(float(FORGE_MATERIAL_COST[material_name]) * multiplier))
		game_state.forge_materials[material_name] = max(0, int(game_state.forge_materials.get(material_name, 0)) - amount)


static func reforge_card(old_card, new_card, mode: String, game_state, is_perfect_forge: bool = false) -> Dictionary:
	if old_card == null or new_card == null:
		return {"ok": false, "reason": "missing_card"}
	var multiplier := 1.0
	match mode:
		"default":
			old_card.brands.clear()
			new_card.brands.clear()
		"keep_brands":
			if int(old_card.quality) < 4:
				return {"ok": false, "reason": "requires_four_star"}
			_move_brands(old_card, new_card)
			multiplier = 1.5
		"keep_brands_new_slot":
			if not _can_keep_brands_new_slot(old_card, new_card, is_perfect_forge):
				return {"ok": false, "reason": "requires_five_star_perfect"}
			var unique_free := _card_has_brand(old_card, "forge_residue_unique") and game_state != null and not bool(game_state.forge_unique_reforge_used)
			_move_brands(old_card, new_card)
			new_card.brand_slots = int(new_card.quality) + 1 + int(new_card.upgrade_level)
			if unique_free:
				multiplier = 0.0
				game_state.forge_unique_reforge_used = true
			else:
				multiplier = 2.0
		_:
			return {"ok": false, "reason": "unknown_mode"}
	deduct_forge_materials(game_state, multiplier)
	return {"ok": true, "material_multiplier": multiplier, "new_card": new_card}


static func brand_drop_chance(quality: int) -> float:
	match quality:
		4: return 0.05
		5: return 0.10
		_: return 0.0


static func should_drop_brand(quality: int, roll: float) -> bool:
	return roll < brand_drop_chance(quality)


static func eligible_forge_brand_weights(quality: int, perfect_rate: float, dao_choices: Array, game_state = null) -> Dictionary:
	var weights := {
		"forge_residue_low": 0,
		"forge_residue_mid": 0,
		"forge_residue_high": 0,
		"forge_residue_unique": 0,
	}
	if quality == 4:
		weights["forge_residue_low"] = 100
		return weights
	if quality != 5:
		return weights
	weights["forge_residue_low"] = 60
	if _dao_choices_all_two_star(dao_choices):
		weights["forge_residue_mid"] = 25
	if perfect_rate >= 0.98:
		weights["forge_residue_high"] = 12
	if not _has_unique_forge_brand(game_state):
		weights["forge_residue_unique"] = 3
	return weights


static func roll_forge_brand_id(quality: int, perfect_rate: float, dao_choices: Array, game_state, roll: float) -> String:
	var weights := eligible_forge_brand_weights(quality, perfect_rate, dao_choices, game_state)
	var total := 0
	for brand_id in FORGE_BRAND_IDS:
		total += int(weights.get(brand_id, 0))
	if total <= 0:
		return ""
	var threshold := clampf(roll, 0.0, 0.999999) * float(total)
	var running := 0
	for brand_id in FORGE_BRAND_IDS:
		running += int(weights.get(brand_id, 0))
		if threshold < float(running):
			return brand_id
	return ""


static func resolve_forge_brand_drop(
	quality: int,
	perfect_rate: float,
	dao_choices: Array,
	game_state,
	chance_roll: float,
	pool_roll: float
):
	if game_state == null or not should_drop_brand(quality, chance_roll):
		return null
	var brand_id := roll_forge_brand_id(quality, perfect_rate, dao_choices, game_state, pool_roll)
	if brand_id == "":
		return null
	var brand = create_forge_brand(brand_id)
	if brand == null:
		return null
	game_state.brands_inventory.append(brand)
	var discovered_brands: Array = game_state.daodian.get("discovered_brands", [])
	if not brand_id in discovered_brands:
		discovered_brands.append(brand_id)
	game_state.daodian["discovered_brands"] = discovered_brands
	return brand


static func create_forge_brand(brand_id: String):
	return BrandCatalogScript.create_brand(brand_id)


static func _unique_card_id(template_id: String) -> String:
	_next_card_serial += 1
	return "%s_%d_%d" % [template_id, Time.get_ticks_usec(), _next_card_serial]


static func _rarity_for_quality(quality_id: int) -> String:
	match quality_id:
		5: return "legendary"
		4: return "epic"
		3: return "rare"
		2: return "common"
		_: return "common"


static func _dao_choices_all_two_star(dao_choices: Array) -> bool:
	if dao_choices.is_empty():
		return false
	for choice in dao_choices:
		if str(choice) != "★★":
			return false
	return true


static func _has_unique_forge_brand(game_state) -> bool:
	if game_state == null:
		return false
	for brand in game_state.brands_inventory:
		if brand != null and str(brand.id) == "forge_residue_unique":
			return true
	for card in game_state.cards_inventory:
		if card != null and "forge_residue_unique" in card.brands:
			return true
	return false


static func _move_brands(old_card, new_card) -> void:
	new_card.brands = old_card.brands.duplicate()
	old_card.brands.clear()


static func _can_keep_brands_new_slot(old_card, new_card, is_perfect_forge: bool) -> bool:
	return int(old_card.quality) >= 5 and int(new_card.quality) >= 5 and is_perfect_forge


static func _card_has_brand(card, brand_id: String) -> bool:
	if card == null:
		return false
	return brand_id in card.brands


static func _source_symbol_ids(arrangement) -> Array[String]:
	var ids: Array[String] = []
	for i in range(arrangement.capacity):
		var symbol_id := String(arrangement.get_at(i))
		if symbol_id != "":
			ids.append(symbol_id)
	return ids


static func _record_symbol_uses(symbol_ids: Array[String], game_state, in_battle: bool) -> void:
	if game_state == null:
		return
	for symbol_id in symbol_ids:
		game_state.record_symbol_use(symbol_id, in_battle)


static func _forge_weather_bonus_percent(game_state) -> int:
	if game_state == null:
		return 0
	return WeatherEffectsApplierScript.get_bonus(str(game_state.current_weather), str(game_state.pathway), "forge")


static func _forge_material_outputs(quality_id: int, bonus_percent: int) -> Dictionary:
	var result: Dictionary = {}
	for material_name in FORGE_MATERIAL_COST:
		var base_count := maxi(0, quality_id)
		var modified_count := int(round(float(base_count) * (1.0 + float(bonus_percent) / 100.0)))
		result[material_name] = modified_count
	return result


static func _resolve_game_state(game_state):
	if game_state != null:
		return game_state
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	return loop.root.get_node_or_null("GameState")
