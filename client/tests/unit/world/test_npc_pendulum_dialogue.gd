extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "pendulum",
	"timeline": "pendulum_main",
	"branches": ["first_meet", "halfmoon_vow", "ask_intel", "true_name_rite", "leave"],
	"presence": [
		{"district": "ascetic_mountain", "time_of_day": "evening"},
		{"district": "shadow_alley", "time_of_day": "night"}
	],
	"districts": ["ascetic_mountain", "shadow_alley"],
	"day": 12,
	"time_of_day": "evening",
	"sequence": 8,
	"nodes": ["node_4"],
	"city_path": {"district": "ascetic_mountain", "time_of_day": "evening", "day": 12, "sequence": 8, "nodes": ["node_4"], "hotspot_id": "Hotspot_npc_pendulum"},
}


func run() -> Dictionary:
	print("\n-- test_npc_pendulum_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
