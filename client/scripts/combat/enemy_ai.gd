class_name EnemyAi
extends RefCounted


static func decide_action(enemy, turn: int) -> Dictionary:
	for rule in enemy.ai_pattern:
		if _eval_condition(rule.get("condition", ""), enemy, turn):
			return _intent_from_rule(enemy, rule)
	return {
		"action": "defend",
		"intent_type": "defend",
		"intent_text": str(enemy.intent_text),
	}


static func _intent_from_rule(enemy, rule: Dictionary) -> Dictionary:
	var action := str(rule.get("action", "use_skill"))
	var skill_id := str(rule.get("skill", ""))
	var skill := _find_skill(enemy, skill_id)
	var intent := {
		"action": action,
		"skill": skill_id,
		"params": rule.get("params", {}),
		"intent_text": str(rule.get("intent_text", enemy.intent_text)),
		"intent_type": action,
	}
	if skill.is_empty():
		return intent
	var status_effects: Array = skill.get("status_effects", []) if skill.get("status_effects", []) is Array else []
	intent["skill_name"] = str(skill.get("name", skill.get("display_name", skill_id)))
	intent["damage"] = int(skill.get("damage", 0))
	intent["heal"] = int(skill.get("heal", 0))
	intent["target"] = str(skill.get("target", "single"))
	intent["status_effects"] = status_effects.duplicate(true)
	intent["element"] = str(skill.get("element", "normal"))
	if skill.has("pierce_defense"):
		intent["pierce_defense"] = maxi(0, int(skill.get("pierce_defense", 0)))
	if skill.has("ignore_defense"):
		intent["ignore_defense"] = skill.get("ignore_defense", false)
	intent["intent_type"] = _skill_intent_type(action, skill, status_effects)
	return intent


static func _find_skill(enemy, skill_id: String) -> Dictionary:
	if enemy == null:
		return {}
	for skill in enemy.skills:
		if skill is Dictionary and str((skill as Dictionary).get("id", "")) == skill_id:
			return (skill as Dictionary).duplicate(true)
	return {}


static func _skill_intent_type(action: String, skill: Dictionary, status_effects: Array) -> String:
	if action != "use_skill":
		return action
	if str(skill.get("target", "")) == "self":
		if not status_effects.is_empty():
			return "self_buff"
		if int(skill.get("heal", 0)) > 0:
			return "self_heal"
	if int(skill.get("damage", 0)) > 0 and not status_effects.is_empty():
		return "attack_debuff"
	if int(skill.get("damage", 0)) > 0:
		return "attack"
	if int(skill.get("heal", 0)) > 0:
		return "heal"
	if not status_effects.is_empty():
		return "status"
	return "use_skill"


static func _eval_condition(cond: String, enemy, turn: int) -> bool:
	if cond.find(" or ") != -1:
		for part in cond.split(" or "):
			if _eval_condition(part.strip_edges(), enemy, turn):
				return true
		return false
	if cond.find(" and ") != -1:
		for part in cond.split(" and "):
			if not _eval_condition(part.strip_edges(), enemy, turn):
				return false
		return true
	if cond.begins_with("not "):
		return not _eval_condition(cond.substr(4).strip_edges(), enemy, turn)
	if cond == "default":
		return true
	if cond == "hp_below_30_percent":
		return enemy.hp < enemy.max_hp * 0.3
	if cond == "hp_below_50_percent":
		return enemy.hp < enemy.max_hp * 0.5
	if cond == "transformed":
		return enemy.get("transformed") == true
	if cond.begins_with("turn % "):
		var parts := cond.split(" ")
		var n := int(parts[2])
		var m := int(parts[4])
		return turn % n == m
	if cond.begins_with("turn == "):
		return turn == int(cond.substr(8))
	return false
