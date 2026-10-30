class_name Intel
extends RefCounted

var id: String = ""
var category: String = ""
var display_text: String = ""
var source_type: String = ""
var source_district: String = ""
var source_npc: String = ""
var acquired_at_day: int = 0
var acquired_at_time: String = ""
var expires_after: String = "today"
var apply_target: Dictionary = {}
var has_applied: bool = false
var truth_value: int = 100
var verified: bool = false


static func from_dict(data: Dictionary) -> Intel:
	var intel := Intel.new()
	intel.id = str(data.get("id", ""))
	intel.category = str(data.get("category", ""))
	intel.display_text = str(data.get("display_text", ""))
	intel.source_type = str(data.get("source_type", ""))
	intel.source_district = str(data.get("source_district", ""))
	intel.source_npc = str(data.get("source_npc", ""))
	intel.acquired_at_day = int(data.get("acquired_at_day", 0))
	intel.acquired_at_time = str(data.get("acquired_at_time", ""))
	intel.expires_after = str(data.get("expires_after", "today"))
	var target: Variant = data.get("apply_target", {})
	intel.apply_target = target.duplicate(true) if target is Dictionary else {}
	intel.has_applied = bool(data.get("has_applied", false))
	intel.truth_value = int(data.get("truth_value", 100))
	intel.verified = bool(data.get("verified", false))
	return intel


func to_dict() -> Dictionary:
	return {
		"id": id,
		"category": category,
		"display_text": display_text,
		"source_type": source_type,
		"source_district": source_district,
		"source_npc": source_npc,
		"acquired_at_day": acquired_at_day,
		"acquired_at_time": acquired_at_time,
		"expires_after": expires_after,
		"apply_target": apply_target.duplicate(true),
		"has_applied": has_applied,
		"truth_value": truth_value,
		"verified": verified,
	}
