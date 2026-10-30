class_name AIGMBudget
extends RefCounted

var daily_call_cap: int = 120
var daily_cost_cap: float = 0.02
var calls_today: int = 0
var cost_today: float = 0.0
var day_key: String = ""


func reset_if_new_day(current_day_key: String = "") -> void:
	var key := current_day_key
	if key == "":
		key = Time.get_date_string_from_system()
	if day_key == "":
		day_key = key
	if day_key != key:
		day_key = key
		calls_today = 0
		cost_today = 0.0


func can_call(provider = null) -> bool:
	reset_if_new_day()
	if provider == null and calls_today >= daily_call_cap:
		return false
	if provider != null and provider.has_method("is_sonnet") and provider.is_sonnet() and calls_today >= daily_call_cap:
		return false
	var estimated := 0.0
	if provider != null and provider.get("estimated_cost") != null:
		estimated = float(provider.estimated_cost)
	return cost_today + estimated <= daily_cost_cap


func provider_for_budget(requested_provider, haiku_provider):
	if requested_provider == null:
		return haiku_provider
	reset_if_new_day()
	if requested_provider.has_method("is_sonnet") and requested_provider.is_sonnet():
		if calls_today >= daily_call_cap or cost_today >= daily_cost_cap:
			return haiku_provider
	return requested_provider


func record_call(provider, cost_override: float = -1.0) -> void:
	reset_if_new_day()
	calls_today += 1
	if cost_override >= 0.0:
		cost_today += cost_override
	elif provider != null and provider.get("estimated_cost") != null:
		cost_today += float(provider.estimated_cost)
