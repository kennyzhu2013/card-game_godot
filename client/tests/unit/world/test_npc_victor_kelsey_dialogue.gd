extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "victor_kelsey",
	"timeline": "victor_kelsey_main",
	"branches": ["first_meet", "public_sermon", "distant_pressure", "ask_intel", "leave"],
	"presence": [{"district": "sacred_seven", "time_of_day": "morning", "visible_when": "day % 7 == 0"}],
	"districts": ["sacred_seven"],
	"day": 7,
	"time_of_day": "morning",
}


func run() -> Dictionary:
	print("\n-- test_npc_victor_kelsey_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
