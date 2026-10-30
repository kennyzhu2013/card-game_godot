extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "eel_fan",
	"timeline": "eel_fan_main",
	"branches": ["first_meet", "small_talk", "ask_intel", "casino_entry", "leave"],
	"presence": [{"district": "misty_port", "time_of_day": "night"}],
	"districts": ["misty_port"],
	"day": 6,
	"time_of_day": "night",
	"city_path": {"district": "misty_port", "time_of_day": "night", "day": 6, "sequence": 9, "hotspot_id": "Hotspot_npc_eel_fan"},
}


func run() -> Dictionary:
	print("\n-- test_npc_eel_fan_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
