class_name CompletionMatcher
extends RefCounted


static func matches(commission, event: Dictionary) -> bool:
	if commission == null or event.is_empty():
		return false
	match str(commission.commission_type):
		"battle":
			return _match_battle(commission, event)
		"gather":
			return _match_gather(commission, event)
		"investigate":
			return _match_investigate(commission, event)
		"perform":
			return _match_perform(commission, event)
		_:
			return false


static func _match_battle(commission, event: Dictionary) -> bool:
	if str(event.get("event", "")) != "tower_complete":
		return false
	var target = commission.dispatch_target
	if str(event.get("district", "")) != str(target.get("district", commission.district)):
		return false
	var target_size = str(target.get("tower_size", ""))
	if target_size != "" and str(event.get("tower_size", "")) != target_size:
		return false
	var target_tower_id = str(target.get("tower_id", ""))
	if target_tower_id != "" and str(event.get("tower_id", "")) != target_tower_id:
		return false
	var boss_id = str(target.get("boss", target.get("boss_defeated_id", "")))
	if boss_id != "" and str(event.get("boss_defeated_id", "")) != boss_id:
		return false
	return bool(event.get("victory", false))


static func _match_gather(commission, event: Dictionary) -> bool:
	if str(event.get("event", "")) != "loot_resolved":
		return false
	var target = commission.dispatch_target
	if str(event.get("district", "")) != str(target.get("district", commission.district)):
		return false
	var expected_time = str(target.get("time", ""))
	if expected_time != "" and str(event.get("time", "")) != expected_time:
		return false
	if str(event.get("item_id", "")) != str(target.get("item_id", "")):
		return false
	var current = int(commission.progress.get("gathered_count", 0))
	current += maxi(0, int(event.get("count_added", 0)))
	commission.progress["gathered_count"] = current
	return current >= int(target.get("count", 1))


static func _match_investigate(commission, event: Dictionary) -> bool:
	if str(event.get("event", "")) != "tower_event_resolved":
		return false
	var target = commission.dispatch_target
	if str(event.get("district", "")) != str(target.get("district", commission.district)):
		return false
	if str(event.get("event_id", "")) != str(target.get("required_event_id", "")):
		return false
	var accepted: Variant = target.get("accepted_choices", [])
	if accepted is Array and not (accepted as Array).is_empty():
		return str(event.get("choice_id", "")) in _string_array(accepted)
	return true


static func _match_perform(commission, event: Dictionary) -> bool:
	if str(event.get("event", "")) != "perform_action":
		return false
	var target = commission.dispatch_target
	if str(event.get("district", "")) != str(target.get("district", commission.district)):
		return false
	if str(event.get("action_id", "")) != str(target.get("action_id", "")):
		return false
	if bool(target.get("witness_check", false)) and int(event.get("witness_count", 0)) != 0:
		return false
	return true


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result
