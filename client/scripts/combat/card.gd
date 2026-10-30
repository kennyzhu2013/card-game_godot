class_name Card
extends RefCounted

const BrandCatalogScript = preload("res://scripts/combat/brand_catalog.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

# Per design/2026-05-24-tower-deck-combat-redesign.md §1.2
# 卡牌数据结构。锻造系统产出 Card 入永久卡库。

# 来源标识
var id: String = ""
var template_id: String = ""
var display_name: String = ""              # 中文显示名（来源 JSON display_name 字段）
var quality: int = 1                       # 1-5（来自锻造时 Phigros perfect_rate）
var pathway: String = "fool"               # 7 主流大道 + DLC 23 条
var sequence: int = 9                      # 9-0
var rarity: String = "common"              # common / rare / epic / legendary / unique

# 卡牌效果
var energy_cost: int = 1                   # 0-3
var damage: int = 0
var heal: int = 0
var element: String = "普通"
var target: String = "single"
var range: int = 1
var status_effects: Array = []
var description: String = ""
var social_effect: Dictionary = {}
var world_effect: Dictionary = {}

# 扮演守则系统（design §3）
var acting_rules: Array[String] = []       # 0-3 条守则文本（仅 sequence ≤ 5 生效）
var rule_violation_penalty: Dictionary = {}

# 烙印挂载点（design §4）
var brand_slots: int = 0                   # = quality + 1
var brands: Array[String] = []             # 已挂载的烙印 id

# 跨周目状态
var play_count: int = 0
var brand_transform_flags: Dictionary = {}
var battles_witnessed: int = 0
var cultivation_level: int = 0             # 满 10 次出牌 +1
var acting_exp: int = 0                    # 扮演经验 (R06 §3 满足契约 +1，满 10 → upgrade_level +1)
var upgrade_level: int = 0                 # 永久升级阶 (满 10 acting_exp 累加，影响 damage / brand_slots)
var tags: Array[String] = []               # 机制范式 tag (R04 §9: intent_reveal / multi_strike / ...)
var _ai_gm_service = null


static func from_json(d: Dictionary) -> Card:
	var c := Card.new()
	c.id = d.get("id", "")
	c.template_id = d.get("template_id", c.id)
	c.display_name = d.get("display_name", "")
	c.quality = int(d.get("quality", 1))
	c.pathway = d.get("pathway", "fool")
	c.sequence = int(d.get("sequence", 9))
	c.rarity = d.get("rarity", "common")
	c.energy_cost = int(d.get("energy_cost", d.get("mp_cost", 1)))
	c.element = d.get("element", "普通")
	c.description = d.get("description", "")
	var combat: Dictionary = d.get("combat_effect", {})
	c.damage = int(combat.get("damage", d.get("damage", 0)))
	c.heal = int(combat.get("heal", d.get("heal", 0)))
	c.target = combat.get("target", d.get("target", "single"))
	c.range = int(combat.get("range", d.get("range", 1)))
	c.status_effects = _effect_array(combat.get("status_effects", []))
	c.social_effect = _dict(d.get("social_effect", {}))
	c.world_effect = _dict(d.get("world_effect", {}))
	c.acting_rules = _string_array(d.get("acting_rules", []))
	c.rule_violation_penalty = _dict(d.get("rule_violation_penalty", {}))
	c.brand_slots = int(d.get("brand_slots", c.quality + 1))
	c.brands = _string_array(d.get("brands", []))
	c.brand_transform_flags = _dict(d.get("brand_transform_flags", {}))
	c.play_count = int(d.get("play_count", 0))
	c.battles_witnessed = int(d.get("battles_witnessed", 0))
	c.cultivation_level = int(d.get("cultivation_level", 0))
	c.acting_exp = int(d.get("acting_exp", 0))
	c.upgrade_level = int(d.get("upgrade_level", 0))
	c.tags = _string_array(d.get("tags", []))
	# brand_slots default must account for upgrade_level (R01 §2.3)
	if not d.has("brand_slots"):
		c.brand_slots = c.quality + 1 + c.upgrade_level
	return c


# 从旧 Skill JSON 加载（兼容 data/skills/*.json）
static func from_skill_json(d: Dictionary) -> Card:
	var c := from_json(d)
	if c.brand_slots == 0:
		c.brand_slots = c.quality + 1
	# acting_rules 字段在 MVP 阶段可能为空，运行时按途径默认守则池补齐
	return c


func to_dict() -> Dictionary:
	return {
		"id": id,
		"template_id": template_id,
		"display_name": display_name,
		"quality": quality,
		"pathway": pathway,
		"sequence": sequence,
		"rarity": rarity,
		"energy_cost": energy_cost,
		"element": element,
		"description": description,
		"combat_effect": {
			"damage": damage,
			"heal": heal,
			"target": target,
			"range": range,
			"status_effects": status_effects.duplicate(true),
		},
		"social_effect": social_effect.duplicate(true),
		"world_effect": world_effect.duplicate(true),
		"acting_rules": Array(acting_rules),
		"rule_violation_penalty": rule_violation_penalty.duplicate(true),
		"brand_slots": brand_slots,
		"brands": Array(brands),
		"brand_transform_flags": brand_transform_flags.duplicate(true),
		"play_count": play_count,
		"battles_witnessed": battles_witnessed,
		"cultivation_level": cultivation_level,
		"acting_exp": acting_exp,
		"upgrade_level": upgrade_level,
		"tags": Array(tags),
	}


func get_display_name() -> String:
	if display_name != "":
		return display_name
	return template_id if template_id != "" else id


func record_play() -> void:
	play_count += 1
	if play_count > 0 and play_count % 10 == 0:
		cultivation_level += 1


func record_battle_witnessed() -> void:
	battles_witnessed += 1


func grant_acting_exp(amount: int = 1) -> bool:
	if upgrade_level >= 5:
		return false
	acting_exp += amount
	if acting_exp >= 10:
		acting_exp = 0
		upgrade_level += 1
		brand_slots = quality + 1 + upgrade_level
		request_card_upgrade_ai_gm()
		return true
	return false


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func request_card_upgrade_ai_gm() -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "card_upgrade"
	ctx.scene_payload = {
		"card_template_id": template_id if template_id != "" else id,
		"new_upgrade_level": int(upgrade_level),
		"primary_acting_rule": acting_rules[0] if not acting_rules.is_empty() else "",
	}
	ctx.fallback_template_pool = "CARD_UPGRADE_TEMPLATES"
	return _call_ai_gm(ctx)


func _call_ai_gm(ctx) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var service = _resolve_ai_gm_service()
	if service == null or not service.has_method("call_ai_gm"):
		return ""
	return str(service.call_ai_gm(ctx))


func _resolve_ai_gm_service():
	if _ai_gm_service != null:
		return _ai_gm_service
	_ai_gm_service = AIGMServiceScript.new()
	return _ai_gm_service


func get_effective_damage() -> int:
	return int(round(damage * (1.0 + 0.20 * upgrade_level)))


func can_use_socially() -> bool:
	return social_effect is Dictionary and str(social_effect.get("type", "")) != ""


func has_world_effect() -> bool:
	return world_effect is Dictionary and str(world_effect.get("type", "")) != ""


func rarity_label() -> String:
	return _rarity_label(rarity)


func target_label() -> String:
	return _target_label(target)


func status_effects_text() -> String:
	return _status_effects_text(status_effects)


func acting_rules_text() -> String:
	return " / ".join(acting_rules)


func rule_violation_penalty_text() -> String:
	return _dictionary_effect_text(rule_violation_penalty)


func brands_text() -> String:
	if brand_slots <= 0:
		return "未启用"
	var text := "已挂载 %d/%d" % [brands.size(), brand_slots]
	var details := brand_effects_text()
	if details != "":
		text += "：%s" % details
	return text


func brand_effects_text() -> String:
	return _brand_effects_text(brands)


func effect_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	var desc := str(description).strip_edges()
	if desc != "":
		lines.append(desc)
	lines.append("费用：%d" % int(energy_cost))
	lines.append("目标：%s；范围：%d" % [target_label(), int(range)])
	var combat := _combat_summary_text()
	if combat != "":
		lines.append("战斗：%s" % combat)
	var social := _structured_effect_summary_text(social_effect)
	if social != "":
		lines.append("场外·社交：%s" % social)
	var world := _structured_effect_summary_text(world_effect)
	if world != "":
		lines.append("场外·世界：%s" % world)
	var brand_effects := brand_effects_text()
	if brand_effects != "":
		lines.append("烙印：%s" % brand_effects)
	if not acting_rules.is_empty():
		lines.append("守则：%s" % acting_rules_text())
	return lines


func effect_summary_text() -> String:
	return "\n".join(effect_summary_lines())


func _combat_summary_text() -> String:
	var parts: Array[String] = []
	if int(damage) > 0:
		var damage_text := "造成 %d 伤害" % int(damage)
		var effective_damage := get_effective_damage()
		if effective_damage != int(damage):
			damage_text += "（升级后 %d）" % effective_damage
		parts.append(damage_text)
	if int(heal) > 0:
		parts.append("治疗 %d" % int(heal))
	var status_text := _status_effects_text(status_effects)
	if status_text != "":
		parts.append("附加 %s" % status_text)
	if parts.is_empty() and not tags.is_empty():
		var tag_text := _tags_text(tags)
		if tag_text != "":
			parts.append("机制：%s" % tag_text)
	return "；".join(parts)


static func _status_effects_text(effects: Array) -> String:
	var parts: Array[String] = []
	for effect in effects:
		var text := _status_effect_text(effect)
		if text != "":
			parts.append(text)
	return "、".join(parts)


static func _structured_effect_summary_text(effect: Dictionary) -> String:
	if not effect is Dictionary:
		return ""
	var effect_type := str(effect.get("type", ""))
	if effect_type == "":
		return ""
	return _effect_type_text(effect_type, effect)


static func _brand_effects_text(brand_ids: Array[String]) -> String:
	var parts: Array[String] = []
	for raw_id in brand_ids:
		var text := _brand_effect_text(str(raw_id))
		if text != "":
			parts.append(text)
	return "；".join(parts)


static func _brand_effect_text(brand_id: String) -> String:
	if brand_id.strip_edges() == "":
		return ""
	var brand = BrandCatalogScript.create_brand(brand_id)
	if brand == null:
		return "未知烙印"
	var name := _clean_optional_text(brand.display_name)
	if name == "":
		name = "未命名烙印"
	var detail := _clean_optional_text(brand.description)
	if detail == "":
		detail = _brand_payload_summary_text(str(brand.effect_type), brand.effect_payload)
	if detail == "":
		return name
	return "%s：%s" % [name, detail]


static func _brand_payload_summary_text(effect_type: String, payload: Dictionary) -> String:
	var parts: Array[String] = []
	match effect_type:
		"stat":
			parts.append(_brand_stat_payload_text(payload))
		"trigger":
			parts.append(_brand_trigger_payload_text(payload))
		"transform":
			parts.append(_brand_transform_payload_text(payload))
		_:
			parts.append("特殊烙印效果")
	var clean: Array[String] = []
	for part in parts:
		var text := str(part).strip_edges()
		if text != "":
			clean.append(text)
	return "；".join(clean)


static func _brand_stat_payload_text(payload: Dictionary) -> String:
	var stat_target := str(payload.get("stat_target", ""))
	var operation := str(payload.get("operation", "add"))
	var value: Variant = payload.get("value", 0)
	match stat_target:
		"damage":
			if operation == "multiply":
				return "该卡伤害提升%d%%" % int(round((float(value) - 1.0) * 100.0))
			return "该卡伤害 %s" % _signed_number_text(value)
		"heal":
			return "该卡治疗 %s" % _signed_number_text(value)
		"energy_cost":
			return "该卡费用 %s" % _signed_number_text(value)
		"pierce":
			return "该卡忽视%s点防御" % _value_text(value)
		_:
			if payload.has("target_mode") and str(payload.get("target_mode", "")) == "two_targets":
				var ratio := float(payload.get("damage_multiplier", 1.0))
				return "单体卡改为2目标，各目标承受%d%%伤害" % int(round(ratio * 100.0))
	return "属性修饰"


static func _brand_trigger_payload_text(payload: Dictionary) -> String:
	var trigger := str(payload.get("trigger", ""))
	if trigger == "after_play" and int(payload.get("draw_cards", 0)) > 0:
		return "打出后抽%d张牌" % int(payload.get("draw_cards", 0))
	if trigger == "after_play" and int(payload.get("block", 0)) > 0:
		return "打出后获得%d点防御" % int(payload.get("block", 0))
	if trigger == "before_damage" and payload.has("crit_chance"):
		return "%s概率暴击，造成%s倍伤害" % [_percent_text(payload.get("crit_chance", 0.0)), _value_text(payload.get("crit_multiplier", 1.0))]
	if trigger == "after_damage" and payload.has("lifesteal_ratio"):
		return "造成伤害的%s转化为治疗" % _percent_text(payload.get("lifesteal_ratio", 0.0))
	if trigger == "on_play" and payload.has("chance") and str(payload.get("effect", "")) == "refund_energy_cost":
		return "出牌时%s概率返还费用" % _percent_text(payload.get("chance", 0.0))
	if trigger == "on_hit" and int(payload.get("enemy_energy_delta_next_turn", 0)) != 0:
		return "命中后敌人下回合能量 %s" % _signed_number_text(payload.get("enemy_energy_delta_next_turn", 0))
	if trigger == "fatal_damage":
		return "受到致命伤害时%s概率由替身承受" % _percent_text(payload.get("chance", 0.0))
	if trigger == "on_kill":
		return "击杀后向下一个敌人弹射%s伤害" % _percent_text(payload.get("chain_damage_ratio", 0.0))
	return _trigger_label(trigger)


static func _brand_transform_payload_text(payload: Dictionary) -> String:
	if payload.has("play_count_threshold"):
		return "使用%d次后永久强化" % int(payload.get("play_count_threshold", 0))
	if payload.has("create_card"):
		return "打出后生成一张临时卡"
	if payload.has("damage_growth"):
		return "每次打出后下次伤害 +%s" % _value_text(payload.get("damage_growth", 0))
	if bool(payload.get("replay_last_effect", false)):
		return "下回合开始时再次触发本卡效果"
	if bool(payload.get("reforge_keep_brands_new_slot_free", false)):
		return "重铸时可免费保留烙印并开新槽"
	return "形态修饰"


static func _trigger_label(trigger_id: String) -> String:
	match trigger_id:
		"on_play":
			return "打出时触发"
		"after_play":
			return "打出后触发"
		"on_hit":
			return "命中时触发"
		"before_damage":
			return "造成伤害前触发"
		"after_damage":
			return "造成伤害后触发"
		"on_kill":
			return "击杀时触发"
		"on_discard":
			return "进入弃牌堆时触发"
		"next_turn_start":
			return "下回合开始触发"
		"first_play_each_battle":
			return "每场首次打出时触发"
		"fatal_damage":
			return "受到致命伤害时触发"
		_:
			return "触发效果"


static func _effect_type_label(effect_type: String) -> String:
	match effect_type:
		"identity_mask":
			return "伪装身份"
		"borrow_name":
			return "借名"
		"forget_event":
			return "抹除记忆"
		"read_truth":
			return "读取真话"
		"modify_suspicion":
			return "调整怀疑度"
		"extract_memory":
			return "抽取记忆"
		"extract_secret":
			return "抽取秘密"
		"influence_behavior":
			return "影响行为"
		"create_residual_identity":
			return "创造残留身份"
		"reveal_hidden_lore":
			return "揭示隐藏知识"
		"spawn_event":
			return "生成事件"
		"alter_npc_state":
			return "改写 NPC 状态"
		"reveal_npc_relationships":
			return "揭示 NPC 关系"
		"modify_node_atmosphere":
			return "改变地点氛围"
		"alter_drop_table":
			return "改变掉落"
		"attract_visitor":
			return "吸引访客"
		_:
			return "特殊效果"


static func _status_label(status_id: String) -> String:
	match status_id:
		"weak":
			return "虚弱"
		"vulnerable":
			return "易伤"
		"confusion":
			return "混乱"
		"nightmare":
			return "梦魇"
		"obscure_intent":
			return "遮蔽意图"
		"delay_intent":
			return "延迟意图"
		"burn", "burning":
			return "燃烧"
		"poison":
			return "中毒"
		"paper_doll_marker":
			return "纸人替身"
		"absorb_fatal_or_curse":
			return "抵挡致命伤或诅咒"
		"mind_revealed":
			return "揭示意图"
		"damage_reduction":
			return "伤害减免"
		"dodge_counter":
			return "闪避反击"
		"select_targets":
			return "选择目标"
		"per_use_damage_growth":
			return "伤害成长"
		"charge":
			return "充能"
		"multi_strike":
			return "多段攻击"
		"pierce_block":
			return "穿透格挡"
		"range_bonus":
			return "距离加伤"
		"attack_play_damage_growth":
			return "攻击牌增伤"
		"cleanse_debuff":
			return "净化减益"
		"immune_debuff":
			return "免疫减益"
		"fatal_damage_convert":
			return "致命伤转化"
		"cleanse_incoming_debuff":
			return "净化即将附加的减益"
		"consume_on_trigger":
			return "触发后消耗"
		"discard_top_deck":
			return "弃置牌库顶牌"
		"draw_if_no_cleanse":
			return "净化失败时抽牌"
		"draw_filter":
			return "抽牌筛选"
		"create_random_temp_card":
			return "生成临时卡牌"
		"bonus_if_attack":
			return "攻击牌加成"
		"vulnerable_if_skill":
			return "技能牌附加易伤"
		"weak_if_status":
			return "状态牌附加虚弱"
		"cost_zero_if_flame_stream":
			return "火流时费用归零"
		"reroll_next_damage_target":
			return "重选伤害目标"
		"teleport_to_flame":
			return "移动至火焰标记"
		"create_or_move_flame_markers":
			return "生成或移动火焰标记"
		"adjacent_burn":
			return "相邻目标燃烧"
		"next_fool_skill_cost_delta":
			return "下一张愚者技能费用变化"
		"avoid_counter_intent":
			return "规避反制意图"
		"stun":
			return "眩晕"
		"bind":
			return "束缚"
		"root":
			return "定身"
		"block_break":
			return "破防"
		"break_block":
			return "破防"
		"revealed":
			return "暴露"
		"intent_revealed":
			return "揭示意图"
		"slow":
			return "迟缓"
		"blind":
			return "致盲"
		"stealth":
			return "潜行"
		"next_attack_damage_delta":
			return "下次攻击伤害变化"
		"fear":
			return "恐惧"
		"mark":
			return "标记"
		"life_steal":
			return "吸血"
		"link":
			return "连结"
		"pierce":
			return "穿透"
		"crit_up":
			return "暴击提升"
		"confuse":
			return "混乱"
		"self_damage":
			return "自损"
		_:
			return "特殊状态"


static func _target_label(target_id: String) -> String:
	match target_id:
		"single":
			return "单体"
		"self":
			return "自身"
		"all_enemies":
			return "全体敌人"
		"multi":
			return "多目标"
		"random_enemies":
			return "随机敌人"
		"random":
			return "随机敌人"
		"dual":
			return "双目标"
		"chain":
			return "串联目标"
		"deck":
			return "牌库"
		"field":
			return "场地"
		"aoe":
			return "范围"
		_:
			return "目标"


static func _rarity_label(rarity_id: String) -> String:
	match rarity_id:
		"common":
			return "普通"
		"rare":
			return "稀有"
		"epic":
			return "史诗"
		"legendary":
			return "传说"
		"unique":
			return "唯一"
		_:
			return "普通"


static func _status_effect_text(effect: Variant) -> String:
	if effect is String:
		return _status_label(str(effect))
	if not effect is Dictionary:
		return ""
	var effect_dict: Dictionary = effect
	var status_id := str(effect_dict.get("id", ""))
	if status_id == "":
		return ""
	match status_id:
		"paper_doll_marker":
			var text := _status_label(status_id)
			var max_stacks := int(effect_dict.get("max_stacks", effect_dict.get("max", 0)))
			if max_stacks > 0:
				text += "（最多%d层）" % max_stacks
			return text
		"absorb_fatal_or_curse":
			return _status_label(status_id)
		"damage_reduction":
			var raw_reduction: Variant = effect_dict.get("magnitude", effect_dict.get("amount", effect_dict.get("value", 0)))
			var reduction := _value_text(raw_reduction)
			if (raw_reduction is int or raw_reduction is float) and float(raw_reduction) > 0.0 and float(raw_reduction) < 1.0:
				reduction = "%d%%" % int(round(float(raw_reduction) * 100.0))
			return "%s %s" % [_status_label(status_id), reduction]
		"select_targets":
			var min_targets := int(effect_dict.get("min", effect_dict.get("min_targets", 1)))
			var max_targets := int(effect_dict.get("max", effect_dict.get("max_targets", min_targets)))
			var targets: Variant = effect_dict.get("targets", [])
			if targets is Array and not (targets as Array).is_empty():
				var target_values: Array = targets
				if min_targets <= 0:
					min_targets = int(target_values[0])
				if max_targets <= 0:
					max_targets = int(target_values[target_values.size() - 1])
			return "选择%d-%d个目标" % [min_targets, max_targets]
		"per_use_damage_growth":
			var growth := _signed_number_text(effect_dict.get("magnitude", effect_dict.get("bonus", 1)))
			var cap: Variant = effect_dict.get("cap", effect_dict.get("max_bonus", effect_dict.get("limit", null)))
			if cap == null or str(cap) == "":
				return "本场每次使用伤害 %s" % growth
			return "本场每次使用伤害 %s，最多 +%s" % [growth, _value_text(cap)]
		"charge":
			var turns := int(effect_dict.get("turns", effect_dict.get("duration", effect_dict.get("magnitude", 0))))
			var payload_text := ""
			var payload: Variant = effect_dict.get("payload", [])
			if payload is Array:
				payload_text = _status_effects_text(payload)
			var text := "充能"
			if turns > 0:
				text += " %d 回合后触发" % turns
			else:
				text += "后触发"
			if payload_text != "":
				text += "：%s" % payload_text
			return text
		"multi_strike":
			var hits := int(effect_dict.get("hits", effect_dict.get("magnitude", 0)))
			var damage_each := int(effect_dict.get("damage_each", 0))
			if hits > 0 and damage_each > 0:
				return "多段攻击 %d×%d" % [hits, damage_each]
			if hits > 0:
				return "多段攻击 %d 段" % hits
			return _status_label(status_id)
		"pierce_block":
			return "%s %s" % [_status_label(status_id), _value_text(effect_dict.get("magnitude", 0))]
		"range_bonus":
			return "%s %s" % [_status_label(status_id), _signed_number_text(effect_dict.get("magnitude", 0))]
		"execute_bonus_below_hp_pct":
			var threshold_text := _percent_text(effect_dict.get("threshold", 0.0))
			var bonus_text := _signed_number_text(effect_dict.get("bonus_damage", effect_dict.get("magnitude", 0)))
			return "%s %s %s" % [_status_label(status_id), threshold_text, bonus_text]
		"attack_play_damage_growth":
			var growth_text := _signed_number_text(effect_dict.get("magnitude", 1))
			var cap_text: Variant = effect_dict.get("cap", effect_dict.get("max_bonus", null))
			if cap_text == null or str(cap_text) == "":
				return "%s %s" % [_status_label(status_id), growth_text]
			return "%s %s，最多 +%s" % [_status_label(status_id), growth_text, _value_text(cap_text)]
		"cleanse_debuff":
			var cleanse_text := _status_label(status_id)
			var types_text := _status_type_list_text(effect_dict.get("types", []))
			if types_text != "":
				cleanse_text += "：%s" % types_text
			return cleanse_text
		"immune_debuff":
			var immune_text := _status_label(status_id)
			var immune_types := _status_type_list_text(effect_dict.get("types", []))
			if immune_types != "":
				immune_text += "：%s" % immune_types
			var immune_duration := int(effect_dict.get("duration", 0))
			if immune_duration > 0:
				immune_text += "（%d回合）" % immune_duration
			return immune_text
		"fatal_damage_convert":
			var ratio := _value_text(effect_dict.get("magnitude", 0))
			var uses := int(effect_dict.get("uses_per_battle", 0))
			var fatal_text := "致命伤转化为%s倍伤害" % ratio
			if uses > 0:
				fatal_text += "，每场最多%d次" % uses
			return fatal_text
		"bonus_if_attack":
			return "%s %s" % [_status_label(status_id), _signed_number_text(effect_dict.get("magnitude", 0))]
		"create_or_move_flame_markers":
			var marker_text := _status_label(status_id)
			var marker_count := int(effect_dict.get("magnitude", 0))
			if marker_count > 0:
				marker_text += " %d 个" % marker_count
			return marker_text
		"adjacent_burn":
			var burn_text := _status_label(status_id)
			var burn_count := int(effect_dict.get("magnitude", 0))
			if burn_count > 0:
				burn_text += " %d" % burn_count
			return burn_text
		"next_fool_skill_cost_delta":
			return "%s %s" % [_status_label(status_id), _signed_number_text(effect_dict.get("magnitude", 0))]
		_:
			var fallback := _status_label(status_id)
			var extra := _generic_status_details(effect_dict)
			if extra != "":
				fallback += "（%s）" % extra
			return fallback


static func _effect_type_text(effect_type: String, effect: Dictionary) -> String:
	var parts: Array[String] = []
	match effect_type:
		"identity_mask":
			parts.append("伪装身份")
			var perception := _perception_label(_effect_value_string(effect, "npc_perception"))
			if perception != "":
				parts.append("目标认知：%s" % perception)
			var identity_days := int(effect.get("duration_days", 0))
			if identity_days > 0:
				parts.append("持续%d天" % identity_days)
		"borrow_name":
			parts.append("借名")
			var borrow_days := int(effect.get("duration_days", 0))
			if borrow_days > 0:
				parts.append("持续%d天" % borrow_days)
		"forget_event":
			parts.append("抹除记忆")
			var forget_days := int(effect.get("duration_days", 0))
			if forget_days > 0:
				parts.append("持续%d天" % forget_days)
		"read_truth":
			parts.append("读取真话")
			var extracts := _string_or_dict_text(effect, ["extracts", "notes", "risk", "risk_note"])
			if extracts != "":
				parts.append(extracts)
		"modify_suspicion":
			parts.append("调整怀疑度")
		"extract_memory":
			parts.append("抽取记忆")
			var memory_text := _string_or_dict_text(effect, ["extracts", "notes", "risk"])
			if memory_text != "":
				parts.append(memory_text)
		"extract_secret":
			parts.append("抽取秘密")
			if _effect_value_string(effect, "secret_kind") == "true_name":
				parts.append("真名")
		"influence_behavior":
			parts.append("影响行为")
		"create_residual_identity":
			parts.append("创造残留身份")
			var identity_text := _world_identity_text(effect)
			if identity_text != "":
				parts.append(identity_text)
		"reveal_hidden_lore":
			parts.append("揭示隐藏知识")
			if int(effect.get("reveal_layer", 0)) > 0:
				parts.append("第%d层" % int(effect.get("reveal_layer", 0)))
		"spawn_event":
			parts.append("生成后续事件")
		"alter_npc_state":
			parts.append("改写 NPC 状态")
		"reveal_npc_relationships":
			parts.append("揭示 NPC 关系")
		"modify_node_atmosphere":
			parts.append("改变地点氛围")
		"alter_drop_table":
			parts.append("改变掉落")
		"attract_visitor":
			parts.append("吸引访客")
		_:
			parts.append(_effect_type_label(effect_type))
	if effect_type not in ["identity_mask", "borrow_name", "forget_event", "create_residual_identity"] and effect.has("duration_days") and int(effect.get("duration_days", 0)) > 0:
		parts.append("持续%d天" % int(effect.get("duration_days", 0)))
	var church_delta := int(effect.get("church_awareness_delta", 0))
	if church_delta != 0:
		parts.append("教会查觉 %s" % _signed_number_text(church_delta))
	var suspicion_delta := int(effect.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("怀疑%s" % _signed_number_text(suspicion_delta))
	var pollution_delta := int(effect.get("pollution_delta", 0))
	if pollution_delta != 0:
		parts.append("污染 %s" % _signed_number_text(pollution_delta))
	var hub_mana_delta := int(effect.get("hub_mana_delta", 0))
	if hub_mana_delta != 0:
		parts.append("咒念能量 %s" % _signed_number_text(hub_mana_delta))
	var generic := _string_or_dict_text(effect, ["notes", "risk", "risk_note"])
	if generic != "":
		parts.append(generic)
	return "；".join(parts)


static func _status_type_list_text(types_value: Variant) -> String:
	if not types_value is Array:
		return ""
	var types: Array = types_value
	if types.is_empty():
		return ""
	var labels: Array[String] = []
	for raw_type in types:
		var type_name := _status_label(str(raw_type))
		if type_name != "":
			labels.append(type_name)
	return "、".join(labels)


static func _world_identity_text(effect: Dictionary) -> String:
	var parts: Array[String] = []
	var allowed_locations: Variant = effect.get("allowed_locations", [])
	if not allowed_locations is Array:
		var params := _parameters_dict(effect)
		allowed_locations = params.get("allowed_locations", [])
	if allowed_locations is Array and not (allowed_locations as Array).is_empty():
		parts.append("仅在%s可用" % _location_list_text(allowed_locations))
	var uses_remaining := int(effect.get("uses_remaining", 0))
	if uses_remaining > 0:
		parts.append("可使用%d次" % uses_remaining)
	var duration_days := int(effect.get("duration_days", 0))
	if duration_days > 0:
		parts.append("持续%d天" % duration_days)
	return "，".join(parts)


static func _location_list_text(locations: Variant) -> String:
	if not locations is Array:
		return "指定城区"
	var labels: Array[String] = []
	for raw_location in locations:
		var label := _location_label(str(raw_location))
		if label != "":
			labels.append(label)
	if labels.is_empty():
		return "指定城区"
	return "、".join(labels)


static func _location_label(location_id: String) -> String:
	match location_id:
		"shadow_alley":
			return "影巷区"
		"stone_tower":
			return "石塔区"
		"misty_port":
			return "雾港区"
		"steelworks":
			return "铸钢区"
		"sacred_seven":
			return "七圣广场"
		"ascetic_mountain":
			return "苦修山"
		_:
			return "指定城区"


static func _perception_label(perception_id: String) -> String:
	match perception_id:
		"stranger":
			return "陌生人"
		"shadow_double":
			return "影子替身"
		"dead_brother":
			return "亡兄"
		"borrowed_face":
			return "借来之脸"
		_:
			return ""


static func _generic_status_details(effect: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["duration", "duration_days", "magnitude", "max_stacks", "hits", "damage_each", "cap", "max_bonus", "turns", "uses_per_battle", "threshold"]:
		if not effect.has(key):
			continue
		var value_text := _value_text(effect.get(key, ""))
		if value_text != "":
			parts.append("%s%s" % [_key_label(str(key)), value_text])
	return "，".join(parts)


static func _dictionary_effect_text(value: Dictionary) -> String:
	if value.is_empty():
		return ""
	var parts: Array[String] = []
	var pollution_delta := int(value.get("pollution_delta", 0))
	if pollution_delta != 0:
		parts.append("污染 %s" % _signed_number_text(pollution_delta))
	var suspicion_delta := int(value.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		parts.append("怀疑%s" % _signed_number_text(suspicion_delta))
	var church_delta := int(value.get("church_awareness_delta", 0))
	if church_delta != 0:
		parts.append("教会查觉 %s" % _signed_number_text(church_delta))
	var hub_mana_delta := int(value.get("hub_mana_delta", 0))
	if hub_mana_delta != 0:
		parts.append("咒念能量 %s" % _signed_number_text(hub_mana_delta))
	var damage_delta := int(value.get("damage_delta", 0))
	if damage_delta != 0:
		parts.append("伤害 %s" % _signed_number_text(damage_delta))
	return "；".join(parts)


static func _string_or_dict_text(effect: Dictionary, keys: Array[String]) -> String:
	var sources: Array[Dictionary] = [effect]
	var params := _parameters_dict(effect)
	if not params.is_empty():
		sources.append(params)
	for source in sources:
		for key in keys:
			if not source.has(key):
				continue
			var text := _clean_optional_text(source.get(key, ""))
			if text != "":
				return text
	return ""


static func _effect_value_string(effect: Dictionary, key: String) -> String:
	if effect.has(key):
		return str(effect.get(key, ""))
	var params := _parameters_dict(effect)
	return str(params.get(key, ""))


static func _parameters_dict(effect: Dictionary) -> Dictionary:
	var raw_params: Variant = effect.get("parameters", {})
	if raw_params is Dictionary:
		return raw_params
	return {}


static func _clean_optional_text(value: Variant) -> String:
	var text := str(value).strip_edges()
	if text == "" or text.contains("_") or text.contains("{") or text.contains("}") or text.contains("[") or text.contains("]"):
		return ""
	return text


static func _signed_number_text(value: Variant) -> String:
	var text := _value_text(value)
	if text == "":
		return "0"
	if value is int or value is float:
		if float(value) > 0.0:
			return "+%s" % text
	return text


static func _percent_text(value: Variant) -> String:
	if value is int or value is float:
		return "%d%%" % int(round(float(value) * 100.0))
	return str(value)


static func _value_text(value: Variant) -> String:
	if value == null:
		return ""
	match typeof(value):
		TYPE_INT:
			return "%d" % int(value)
		TYPE_FLOAT:
			var numeric := float(value)
			if numeric == floor(numeric):
				return "%d" % int(numeric)
			return str(numeric)
		TYPE_STRING:
			return str(value)
		_:
			return str(value)


static func _key_label(key: String) -> String:
	match key:
		"duration":
			return "持续"
		"duration_days":
			return "持续"
		"magnitude":
			return ""
		"max_stacks":
			return "最多"
		"hits":
			return "段数"
		"damage_each":
			return "每段"
		"cap":
			return "上限"
		"max_bonus":
			return "上限"
		"turns":
			return "回合"
		"uses_per_battle":
			return "每场"
		"threshold":
			return "阈值"
		_:
			return ""


static func _tags_text(tags_value: Array[String]) -> String:
	var labels: Array[String] = []
	for raw_tag in tags_value:
		var label := _tag_label(str(raw_tag))
		if label != "":
			labels.append(label)
	return "、".join(labels)


static func _tag_label(tag_id: String) -> String:
	match tag_id:
		"attack":
			return "攻击"
		"skill":
			return "技能"
		"status":
			return "状态"
		"social":
			return "社交"
		"world":
			return "世界"
		"summon_marker":
			return "召唤标记"
		"intent_reveal":
			return "揭示意图"
		"multi_strike":
			return "多段攻击"
		"mind_read":
			return "读心"
		"temporary":
			return "临时"
		"charge":
			return "充能"
		"deck":
			return "牌库"
		"field":
			return "场地"
		"summon":
			return "召唤"
		"move":
			return "移动"
		"pierce":
			return "穿透"
		"burn", "burning":
			return "燃烧"
		"self_damage":
			return "自损"
		"crit_up":
			return "暴击提升"
		"execute_bonus_below_hp_pct":
			return "低血斩杀加伤"
		"confuse":
			return "混乱"
		"mark":
			return "标记"
		"link":
			return "连结"
		_:
			return "机制"


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _effect_array(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for item in value:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
		elif item is String:
			var id := str(item).strip_edges()
			if id != "":
				result.append({"id": id})
	return result


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
