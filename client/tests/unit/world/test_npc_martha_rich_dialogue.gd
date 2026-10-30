extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "martha_rich",
	"timeline": "martha_rich_main",
	"branches": ["first_meet", "small_talk", "ask_intel", "commission", "leave"],
	"presence": [{"district": "steelworks", "time_of_day": "morning"}],
	"districts": ["steelworks"],
	"day": 4,
	"time_of_day": "morning",
	"city_path": {"district": "steelworks", "time_of_day": "morning", "day": 4, "sequence": 9, "hotspot_id": "Hotspot_npc_martha"},
}


func run() -> Dictionary:
	print("\n-- test_npc_martha_rich_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
