extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "thomas_priest",
	"timeline": "thomas_priest_main",
	"branches": ["first_meet", "confession", "ask_intel", "drill", "leave"],
	"presence": [{"district": "sacred_seven", "time_of_day": "morning", "visible_when": "day % 7 == 0"}],
	"districts": ["sacred_seven"],
	"day": 7,
	"time_of_day": "morning",
	"city_path": {"district": "sacred_seven", "time_of_day": "morning", "day": 7, "sequence": 9, "hotspot_id": "Hotspot_npc_thomas_priest"},
}


func run() -> Dictionary:
	print("\n-- test_npc_thomas_priest_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
