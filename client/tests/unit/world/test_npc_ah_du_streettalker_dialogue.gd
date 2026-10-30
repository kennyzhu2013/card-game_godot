extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "ah_du_streettalker",
	"timeline": "ah_du_streettalker_main",
	"branches": ["first_meet", "street_rumor", "ask_intel", "rumor_source", "leave"],
	"presence": [
		{"district": "shadow_alley", "time_of_day": "morning"},
		{"district": "shadow_alley", "time_of_day": "evening"}
	],
	"districts": ["shadow_alley"],
	"day": 5,
	"time_of_day": "evening",
}


func run() -> Dictionary:
	print("\n-- test_npc_ah_du_streettalker_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
