extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "widow_isa",
	"timeline": "widow_isa_main",
	"branches": ["first_meet", "haunting", "ask_intel", "pollution_echo", "leave"],
	"presence": [{"district": "shadow_alley", "time_of_day": "night"}],
	"districts": ["shadow_alley"],
	"day": 10,
	"time_of_day": "night",
}


func run() -> Dictionary:
	print("\n-- test_npc_widow_isa_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
