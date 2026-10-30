class_name StatusText
extends RefCounted


static func describe(status_id: String, payload: Dictionary) -> String:
	var clean_id := status_id.strip_edges()
	if clean_id == "":
		return "未知状态（未知效果）"
	var label_text := label(clean_id)
	if _is_known_status(clean_id):
		return _known_description(clean_id, label_text, payload)
	var description := _payload_description(payload)
	if description != "":
		return "%s：%s%s" % [label_text, description, _payload_suffix(payload)]
	return "%s（未知效果）" % _humanize_identifier(clean_id)


static func label(status_id: String) -> String:
	match status_id.strip_edges():
		"flame_wound":
			return "火焰伤口"
		"defense_break", "block_break", "break_block":
			return "破防"
		"ward":
			return "守护"
		"bleed":
			return "流血"
		"chant_charge", "charge":
			return "咏唱蓄力"
		"mirror_seal":
			return "镜封"
		"weak":
			return "虚弱"
		"blind":
			return "致盲"
		"vulnerable":
			return "易伤"
		"burn", "burning":
			return "燃烧"
		"poison":
			return "中毒"
		"confusion", "confuse":
			return "混乱"
		"nightmare":
			return "噩梦"
		"fear":
			return "恐惧"
		"obscure_intent":
			return "遮蔽意图"
		"delay_intent":
			return "延迟意图"
		"damage_reduction":
			return "减伤"
		"dodge_counter":
			return "闪避反击"
		"counter_spell":
			return "反咒"
		"cleanse_incoming_debuff":
			return "净化下次负面"
		"immune_debuff":
			return "免疫负面"
		"fatal_damage_convert":
			return "致命转移"
		"consume_on_trigger":
			return "触发后消耗"
		"absorb_fatal_or_curse":
			return "替死吸收"
		"paper_doll_marker", "paper_doll":
			return "纸人"
		"next_card_cost_delta", "next_fool_skill_cost_delta":
			return "下一张愚者技能费用"
		"reroll_next_target", "reroll_next_damage_target":
			return "改判下次目标"
		"stun":
			return "眩晕"
		"bind":
			return "束缚"
		"root":
			return "定身"
		"revealed":
			return "暴露"
		"intent_revealed":
			return "揭示意图"
		"mind_revealed":
			return "读心揭示"
		"slow":
			return "迟缓"
		"stealth":
			return "潜行"
		"next_attack_damage_delta":
			return "下次攻击变化"
		"mark":
			return "标记"
		"life_steal":
			return "吸血"
		"link":
			return "链接"
		"pierce":
			return "穿透"
		"crit_up":
			return "暴击提升"
		"displace":
			return "错位"
		"silence":
			return "沉默"
		"chill":
			return "寒意"
		_:
			return status_id


static func _known_description(status_id: String, label_text: String, payload: Dictionary) -> String:
	match status_id:
		"flame_wound":
			return _line(label_text, payload, "回合开始时受到%s点伤害" % _value(payload, "magnitude", "0"))
		"defense_break", "block_break", "break_block":
			return _line(label_text, payload, "防御降低%s" % _value(payload, "magnitude", "0"))
		"ward":
			return _line(label_text, payload, "抵挡下一次伤害，护盾%s层" % _value(payload, "stacks", _value(payload, "magnitude", "1")))
		"bleed":
			return _line(label_text, payload, "行动时失去%s点生命" % _value(payload, "magnitude", "0"))
		"chant_charge", "charge":
			return _line(label_text, payload, "储存%s层蓄力" % _value(payload, "stacks", _value(payload, "magnitude", "1")))
		"mirror_seal":
			return _line(label_text, payload, "偏转%s次负面效果" % _value(payload, "magnitude", "1"))
		"weak":
			return _line(label_text, payload, "造成的攻击伤害降低")
		"blind":
			return _line(label_text, payload, "下一次攻击更容易失手")
		"vulnerable":
			return _line(label_text, payload, "受到的伤害提高")
		"burn", "burning":
			return _line(label_text, payload, "回合开始时受到%s点燃烧伤害" % _value(payload, "magnitude", "0"))
		"poison":
			return _line(label_text, payload, "持续受到%s点毒性伤害" % _value(payload, "magnitude", "0"))
		"confusion", "confuse":
			return _line(label_text, payload, "行动可能选错目标")
		"nightmare":
			return _line(label_text, payload, "恐惧会放大受到的伤害")
		"fear":
			return _line(label_text, payload, "下一次行动可能被阻断")
		"obscure_intent":
			return _line(label_text, payload, "隐藏下一次意图")
		"delay_intent":
			return _line(label_text, payload, "延后意图结算")
		"damage_reduction":
			return _line(label_text, payload, "受到的伤害减少%s" % _value(payload, "magnitude", "0"))
		"dodge_counter":
			return _line(label_text, payload, "闪避并反击%s点伤害" % _value(payload, "magnitude", "0"))
		"counter_spell":
			return _line(label_text, payload, "反制下一次法术并造成%s点伤害" % _value(payload, "magnitude", "0"))
		"cleanse_incoming_debuff":
			return _line(label_text, payload, "抵消下一次负面状态")
		"immune_debuff":
			return _line(label_text, payload, "免疫负面状态")
		"fatal_damage_convert":
			return _line(label_text, payload, "将致命伤害转化为较低伤害")
		"consume_on_trigger":
			return _line(label_text, payload, "触发后立即消耗")
		"absorb_fatal_or_curse":
			return _line(label_text, payload, "吸收一次致命伤害或诅咒")
		"paper_doll_marker", "paper_doll":
			return _line(label_text, payload, "拥有%s层纸人标记" % _value(payload, "stacks", "1"))
		"next_card_cost_delta", "next_fool_skill_cost_delta":
			return _line(label_text, payload, "下一张愚者技能费用变化%s" % _signed_value(payload, "magnitude", "0"))
		"reroll_next_target", "reroll_next_damage_target":
			return _line(label_text, payload, "重选下一次目标")
		"stun":
			return _line(label_text, payload, "跳过下一次行动")
		"bind":
			return _line(label_text, payload, "无法重新选择目标")
		"root":
			return _line(label_text, payload, "无法移动或换位")
		"revealed", "intent_revealed", "mind_revealed":
			return _line(label_text, payload, "显示当前意图")
		"slow":
			return _line(label_text, payload, "行动延后")
		"stealth":
			return _line(label_text, payload, "更难被选为目标")
		"next_attack_damage_delta":
			return _line(label_text, payload, "下一次攻击伤害变化%s" % _signed_value(payload, "magnitude", "0"))
		"mark":
			return _line(label_text, payload, "后续攻击追加%s点伤害" % _value(payload, "magnitude", "0"))
		"life_steal":
			return _line(label_text, payload, "根据造成的伤害回复生命")
		"link":
			return _line(label_text, payload, "与另一个目标共享部分效果")
		"pierce":
			return _line(label_text, payload, "伤害可穿透防御")
		"crit_up":
			return _line(label_text, payload, "暴击概率提高")
		"displace":
			return _line(label_text, payload, "位置被改变")
		"silence":
			return _line(label_text, payload, "无法使用技能")
		"chill":
			return _line(label_text, payload, "伤害和速度降低")
		_:
			return "%s（未知效果）" % _humanize_identifier(status_id)


static func _line(label_text: String, payload: Dictionary, detail: String) -> String:
	return "%s：%s" % [_compact_prefix(label_text, payload), detail]


static func _compact_prefix(label_text: String, payload: Dictionary) -> String:
	var parts: Array[String] = [label_text]
	if payload.has("duration"):
		parts.append(str(int(payload.get("duration", 0))))
	if payload.has("magnitude"):
		parts.append("强度 %s" % _value(payload, "magnitude", "0"))
	if payload.has("stacks"):
		parts.append("%s层" % _value(payload, "stacks", "0"))
	return " ".join(parts)


static func _is_known_status(status_id: String) -> bool:
	return label(status_id) != status_id


static func _payload_description(payload: Dictionary) -> String:
	for key in ["description", "detail", "tooltip", "text"]:
		var value := str(payload.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


static func _payload_suffix(payload: Dictionary) -> String:
	var parts: Array[String] = []
	if payload.has("duration"):
		parts.append("%d回合" % int(payload.get("duration", 0)))
	if payload.has("magnitude"):
		parts.append("强度 %s" % _value(payload, "magnitude", "0"))
	if payload.has("stacks"):
		parts.append("%s层" % _value(payload, "stacks", "0"))
	if parts.is_empty():
		return ""
	return "（%s）" % "，".join(parts)


static func _value(payload: Dictionary, key: String, fallback: String) -> String:
	if not payload.has(key):
		return fallback
	return str(payload.get(key, fallback)).strip_edges()


static func _signed_value(payload: Dictionary, key: String, fallback: String) -> String:
	var text := _value(payload, key, fallback)
	if float(text) > 0.0:
		return "+%s" % text
	return text


static func _humanize_identifier(identifier: String) -> String:
	var clean := identifier.strip_edges()
	if clean == "":
		return "未知状态"
	var mapped: Array[String] = []
	for part in clean.split("_", false):
		var token := str(part).strip_edges()
		if token == "":
			continue
		mapped.append(_identifier_token_label(token))
	if mapped.is_empty():
		return "未知状态"
	return "".join(mapped)


static func _identifier_token_label(token: String) -> String:
	match token:
		"unknown":
			return "未知"
		"status":
			return "状态"
		"probe":
			return "探针"
		"shadow":
			return "影子"
		"silence":
			return "沉默"
		"flame":
			return "火焰"
		"wound":
			return "伤口"
		"blood":
			return "血"
		"mark":
			return "标记"
		"mirror":
			return "镜"
		"seal":
			return "封印"
		_:
			return token.capitalize()
