extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "peter_furnace",
	"timeline": "peter_furnace_main",
	"branches": ["first_meet", "small_talk", "ask_intel", "factory_job", "leave"],
	"presence": [{"district": "steelworks", "time_of_day": "noon"}],
	"districts": ["steelworks"],
	"day": 4,
	"time_of_day": "noon",
	"city_path": {"district": "steelworks", "time_of_day": "noon", "day": 4, "sequence": 9, "hotspot_id": "Hotspot_npc_peter_furnace"},
}


func run() -> Dictionary:
	print("\n-- test_npc_peter_furnace_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
