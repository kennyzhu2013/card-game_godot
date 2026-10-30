class_name MomentumQteDirector
extends RefCounted

signal qte_finished(branch: String, payload: Dictionary)

var current_phase: String = "idle"


func branch_for_choice(primary: String, secondary: String) -> String:
	if primary == "DUEL":
		return "DUEL"
	if primary == "EXECUTE":
		if secondary == "EXECUTE_B":
			return "EXECUTE_B"
		return "EXECUTE_A"
	return "DUEL"


func run(scene_context, momentum_sign: int) -> Signal:
	current_phase = "choosing_primary"
	var ui = scene_context.make_qte_choice_ui()
	if momentum_sign < 0:
		ui.set_execute_allowed(false)
	var primary: String = await ui.prompt_primary()
	var secondary := ""
	if primary == "EXECUTE":
		current_phase = "choosing_secondary"
		secondary = await ui.prompt_secondary()
	var branch := branch_for_choice(primary, secondary)
	current_phase = "running_" + branch
	var payload: Dictionary = {}
	match branch:
		"DUEL":
			payload = await scene_context.play_duel(scene_context.get_tree())
		"EXECUTE_A":
			payload = await scene_context.play_execute_punish(scene_context.get_tree())
		"EXECUTE_B":
			payload = await scene_context.play_execute_challenge(scene_context.get_tree())
	current_phase = "idle"
	qte_finished.emit(branch, payload)
	return qte_finished
