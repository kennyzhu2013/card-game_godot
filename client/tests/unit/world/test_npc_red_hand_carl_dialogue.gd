extends RefCounted

const Helper = preload("res://tests/unit/world/npc_dialogue_test_helper.gd")
const SPEC := {
	"npc_id": "red_hand_carl",
	"timeline": "red_hand_carl_main",
	"branches": ["first_meet", "red_hand_trial", "ask_intel", "prove_not_church", "leave"],
	"presence": [{"district": "steelworks", "time_of_day": "night", "visible_when": "day % 7 == 2"}],
	"districts": ["steelworks"],
	"day": 9,
	"time_of_day": "night",
}


func run() -> Dictionary:
	print("\n-- test_npc_red_hand_carl_dialogue.gd --")
	return await Helper.new().run_contract(SPEC)
