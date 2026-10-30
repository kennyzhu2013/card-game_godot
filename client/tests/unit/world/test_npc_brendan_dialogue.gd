extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "brendan",
	"timeline": "brendan_main",
	"branches": ["first_meet", "small_talk", "ask_intel", "church_awareness_10", "leave"],
	"presence": [
		{"district": "sacred_seven", "time_of_day": "morning"},
		{"district": "sacred_seven", "time_of_day": "noon"},
		{"district": "sacred_seven", "time_of_day": "evening"},
		{"district": "sacred_seven", "time_of_day": "night"}
	],
	"districts": ["sacred_seven"],
	"day": 7,
	"time_of_day": "morning",
	"brendan_awareness": true,
	"city_path": {"district": "sacred_seven", "time_of_day": "morning", "day": 7, "sequence": 9, "hotspot_id": "Hotspot_npc_brendan"},
}


func run() -> Dictionary:
	print("\n-- test_npc_brendan_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
