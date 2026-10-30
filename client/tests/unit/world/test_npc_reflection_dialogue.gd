extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "reflection",
	"timeline": "reflection_main",
	"branches": ["first_meet", "halfmoon_vow", "ask_intel", "romance_line", "leave"],
	"presence": [
		{"district": "shadow_alley", "time_of_day": "evening"},
		{"district": "misty_port", "time_of_day": "night"}
	],
	"districts": ["shadow_alley", "misty_port"],
	"day": 12,
	"time_of_day": "evening",
	"sequence": 8,
	"nodes": ["node_4"],
}


func run() -> Dictionary:
	print("\n-- test_npc_reflection_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
