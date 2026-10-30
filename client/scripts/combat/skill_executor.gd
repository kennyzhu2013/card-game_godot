class_name SkillExecutor
extends RefCounted


static func calculate_damage(skill, attacker, defender, qte_mult: float, element_table) -> int:
	var base: int = int(skill.damage)
	var elem_mult: float = float(element_table.multiplier(skill.element, _defender_element(defender)))
	var crit_roll: float = randf()
	var crit_mult: float = 1.5 if crit_roll < attacker.crit_rate else 1.0
	var final: float = (base * elem_mult * qte_mult * crit_mult) - defender.def
	return max(1, int(final))


static func _defender_element(defender) -> String:
	var value: Variant = defender.get("element")
	if value != null:
		return str(value)
	return "普通"
