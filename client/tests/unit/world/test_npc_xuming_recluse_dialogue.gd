extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "xuming_recluse",
	"timeline": "xuming_recluse_main",
	"branches": ["first_meet", "hidden_path", "ask_intel", "ascetic_trade", "leave"],
	"presence": [{"district": "ascetic_mountain", "time_of_day": "evening"}],
	"districts": ["ascetic_mountain"],
	"day": 12,
	"time_of_day": "evening",
	"sequence": 8,
	"nodes": ["node_4"],
	"city_path": {"district": "ascetic_mountain", "time_of_day": "evening", "day": 12, "sequence": 8, "nodes": ["node_4"], "hotspot_id": "Hotspot_npc_xuming_recluse"},
}


func run() -> Dictionary:
	print("\n-- test_npc_xuming_recluse_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
