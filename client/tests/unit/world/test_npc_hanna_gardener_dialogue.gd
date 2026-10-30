extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "hanna_gardener",
	"timeline": "hanna_gardener_main",
	"branches": ["first_meet", "garden_rumor", "ask_intel", "commission", "leave"],
	"presence": [{"district": "stone_tower", "time_of_day": "noon"}],
	"districts": ["stone_tower"],
	"day": 8,
	"time_of_day": "noon",
	"sequence": 8,
	"city_path": {"district": "stone_tower", "time_of_day": "noon", "day": 8, "sequence": 8, "hotspot_id": "Hotspot_npc_hanna_gardener"},
}


func run() -> Dictionary:
	print("\n-- test_npc_hanna_gardener_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
