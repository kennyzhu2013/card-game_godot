extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "carl_smuggler",
	"timeline": "carl_smuggler_main",
	"branches": ["first_meet", "small_talk", "ask_intel", "auction_lead", "leave"],
	"presence": [{"district": "misty_port", "time_of_day": "night"}],
	"districts": ["misty_port"],
	"day": 6,
	"time_of_day": "night",
	"city_path": {"district": "misty_port", "time_of_day": "night", "day": 6, "sequence": 9, "hotspot_id": "Hotspot_npc_carl_smuggler"},
}


func run() -> Dictionary:
	print("\n-- test_npc_carl_smuggler_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
