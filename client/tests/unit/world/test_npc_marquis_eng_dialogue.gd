extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "marquis_eng",
	"timeline": "marquis_eng_main",
	"branches": ["first_meet", "noble_plot", "ask_intel", "sequence_8_hint", "leave"],
	"presence": [{"district": "stone_tower", "time_of_day": "noon"}],
	"districts": ["stone_tower"],
	"day": 8,
	"time_of_day": "noon",
	"sequence": 8,
	"city_path": {"district": "stone_tower", "time_of_day": "noon", "day": 8, "sequence": 8, "hotspot_id": "Hotspot_npc_marquis_eng"},
}


func run() -> Dictionary:
	print("\n-- test_npc_marquis_eng_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
