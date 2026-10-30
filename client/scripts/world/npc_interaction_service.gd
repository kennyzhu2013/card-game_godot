class_name NpcInteractionService
extends RefCounted

const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const NpcLibraryScript = preload("res://scripts/world/npc_library.gd")
const IdentityPickerScript = preload("res://scripts/world/identity_picker_dialog.gd")
const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const PseudoGodContractServiceScript = preload("res://scripts/world/pseudo_god_contract_service.gd")
const IntelServiceScript = preload("res://scripts/world/intel_service.gd")
const CommissionLibraryScript = preload("res://scripts/world/commission_library.gd")
const CommissionServiceScript = preload("res://scripts/world/commission_service.gd")
const JobServiceScript = preload("res://scripts/world/job_service.gd")
const DrillRunnerScript = preload("res://scripts/world/drill_runner.gd")
const FieldOpportunityServiceScript = preload("res://scripts/world/field_opportunity_service.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

const DEFAULT_NPC_INTEL_LINGSTONES_COST := 20
const RELATION_THRESHOLDS := [
	{"id": "acquainted", "trust": 30},
	{"id": "friend", "trust": 60},
	{"id": "trusted", "trust": 80},
	{"id": "kin", "trust": 95},
]

var _library = null
var _commission_library = null
var _ai_gm_service = null
var _drill_runner_override = null


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func set_drill_runner(runner) -> void:
	_drill_runner_override = runner


func residual_identity_options_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var picker = IdentityPickerScript.new()
	var ids: Array[String] = picker.options_for_npc(npc_id, gs)
	var options: Array = []
	for identity_id in ids:
		if identity_id == "" or identity_id == "harvey":
			continue
		var display_name := _residual_identity_display_name(gs, identity_id)
		options.append({
			"id": identity_id,
			"identity_id": identity_id,
			"display_name": display_name,
			"label": "以 %s 身份接近" % display_name,
		})
	return options


func select_residual_identity_for_npc(npc_id: String, game_state = null, identity_id: String = "") -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state", "identity": identity_id}
	var picker = IdentityPickerScript.new()
	var result: Dictionary = picker.use_identity_for_npc(npc_id, gs, identity_id)
	if bool(result.get("ok", false)):
		var selected := str(result.get("identity", identity_id))
		gs.current_residual_identity = selected if selected != "" else "harvey"
	return result


func open_dialogue(npc_id: String, game_state = null, dialogic_adapter = null) -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state"}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	var pseudo_god := PseudoGodContractServiceScript.new()
	var pseudo_result: Dictionary = pseudo_god.ensure_unlocked_for_state(gs)
	var first_meet := not _npc_has_met(gs, npc_id)
	var state = _ensure_npc_state(gs, npc_id, npc_def)
	var identity_options := residual_identity_options_for_npc(npc_id, gs)
	var picker = IdentityPickerScript.new()
	var identity := picker.choose_identity_for_npc(npc_id, gs, state)
	var identity_result: Dictionary = {}
	if identity != "harvey":
		identity_result = picker.use_identity_for_npc(npc_id, gs, identity)
		if not bool(identity_result.get("ok", false)):
			identity = "harvey"
	gs.current_residual_identity = identity
	var timeline_id := "npc/%s" % str(npc_def.get("dialogue_tree", npc_id))
	var variables := dialogic_variables_for(npc_id, gs)
	state.dialogue_state["last_opened_timeline"] = timeline_id
	state.dialogue_state["active_identity"] = identity
	var started := _start_dialogic(timeline_id, variables, dialogic_adapter)
	var threshold_branch := _apply_church_awareness_dialogue_gate(npc_id, gs, state)
	var pollution_stage_lines := pollution_stage_lines_for_npc(npc_id, gs)
	var preview := _dialogue_preview(timeline_id, npc_def)
	if not pollution_stage_lines.is_empty():
		preview = _append_preview_lines(preview, pollution_stage_lines)
	var result := {
		"ok": true,
		"npc_id": npc_id,
		"npc": npc_def,
		"timeline_id": timeline_id,
		"dialogue_preview": preview,
		"variables": variables,
		"dialogic_started": started,
		"identity": identity,
		"identity_result": identity_result,
		"identity_options": identity_options,
		"pollution_stage_lines": pollution_stage_lines,
		"pseudo_god_unlock": pseudo_result,
	}
	if threshold_branch != "":
		result["church_awareness_branch"] = threshold_branch
	if first_meet:
		result["ai_gm_text"] = request_npc_first_meet_ai_gm(npc_id, gs, state)
	return result


func dialogue_branches_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return []
	var timeline_id := "npc/%s" % str(npc_def.get("dialogue_tree", npc_id))
	return _timeline_branches(timeline_id)


func resolve_dialogue_branch(npc_id: String, game_state = null, branch_id: String = "") -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state", "npc_id": npc_id, "branch_id": branch_id}
	var branch := _find_timeline_branch(npc_id, gs, branch_id)
	if branch.is_empty():
		return {"ok": false, "reason": "unknown_branch", "npc_id": npc_id, "branch_id": branch_id}
	var outcome: Dictionary = branch.get("outcome", {}) if branch.get("outcome", {}) is Dictionary else {}
	if outcome.is_empty():
		outcome = {"dialogue_rounds": 1, "trust_delta": 0}
	var commit: Dictionary = commit_dialogue_outcome(npc_id, outcome, gs)
	var result := {
		"ok": bool(commit.get("ok", false)),
		"reason": str(commit.get("reason", "")),
		"npc_id": npc_id,
		"branch_id": branch_id,
		"branch": branch.duplicate(true),
		"text": str(branch.get("text", "")),
		"label": str(branch.get("label", branch_id)),
		"commit": commit,
	}
	if branch.has("mainline_node_id"):
		result["mainline_node_id"] = str(branch.get("mainline_node_id", ""))
	return result


func commit_dialogue_outcome(npc_id: String, outcome: Dictionary, game_state = null) -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state"}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	var state = _ensure_npc_state(gs, npc_id, npc_def)
	var previous_trust := int(state.trust)
	var projected_trust := clampi(previous_trust + int(outcome.get("trust_delta", 0)), 0, 100)
	var dialogue_rounds := int(outcome.get("dialogue_rounds", outcome.get("round_count", 1)))
	var threshold_changed := _would_cross_relation_threshold(previous_trust, projected_trust)
	var spend: Dictionary = ApServiceScript.try_spend_npc_dialogue(gs, dialogue_rounds, threshold_changed)
	if not bool(spend.get("ok", false)):
		return {
			"ok": false,
			"reason": str(spend.get("reason", "ap_short")),
			"npc_id": npc_id,
			"ap_cost": int(spend.get("cost", 0)),
			"spend": spend,
		}
	state.trust = projected_trust
	state.suspicion = clampi(int(state.suspicion) + int(outcome.get("suspicion_delta", 0)), 0, 100)
	state.dialog_count += 1
	state.last_seen_day = int(gs.day)
	var previous_layer := int(state.layer_revealed)
	var layer_revealed_to := int(outcome.get("layer_revealed_to", state.layer_revealed))
	if layer_revealed_to > int(state.layer_revealed):
		state.layer_revealed = clampi(layer_revealed_to, 0, 2)
	_merge_string_array(state.unlocked_dialogue_branches, outcome.get("unlocked_dialogue_branches", []))
	_merge_array(state.pending_gifts, outcome.get("pending_gifts", []))
	var threshold_result := _check_relation_thresholds(npc_id, state, previous_trust, npc_def)
	var ai_gm_texts := {}
	if not _array(threshold_result.get("triggered_thresholds", [])).is_empty():
		ai_gm_texts["npc_relation_shift"] = request_npc_relation_shift_ai_gm(npc_id, gs, state, previous_trust, projected_trust, threshold_result)
	if int(state.layer_revealed) > previous_layer:
		ai_gm_texts["npc_layer_reveal"] = request_npc_layer_reveal_ai_gm(npc_id, gs, state, previous_layer, int(state.layer_revealed))
	return {
		"ok": true,
		"npc_id": npc_id,
		"previous_trust": previous_trust,
		"trust": state.trust,
		"ap_cost": int(spend.get("cost", 0)),
		"triggered_thresholds": threshold_result.get("triggered_thresholds", []),
		"unlocked_buffs": threshold_result.get("unlocked_buffs", []),
		"ai_gm_texts": ai_gm_texts,
	}


func dialogic_variables_for(npc_id: String, game_state = null) -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {}
	var state = _ensure_npc_state(gs, npc_id, npc_def)
	return {
		"npc_trust": int(state.trust),
		"npc_suspicion": int(state.suspicion),
		"npc_layer": int(state.layer_revealed),
		"npc_perception": str(state.active_perception),
		"npc_dialog_count": int(state.dialog_count),
		"player_sequence": int(gs.sequence),
		"player_pollution": int(gs.pollution),
		"player_pollution_stage": int(gs.pollution_stage),
		"church_awareness": int(gs.church_awareness),
		"halfmoon_trust": int(gs.halfmoon_trust),
		"pseudo_god_unlocked": bool(PseudoGodContractServiceScript.is_unlocked(gs)),
		"pseudo_god_violated": bool(PseudoGodContractServiceScript.is_violated(gs)),
		"current_day": int(gs.day),
		"current_weather": str(gs.current_weather),
		"time_of_day": str(gs.time_of_day),
	}


func available_intels_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return []
	var state = _ensure_npc_state(gs, npc_id, npc_def)
	var result: Array = []
	for intel in npc_def.get("available_intels", []):
		if not intel is Dictionary:
			continue
		if int(state.trust) < int(intel.get("trust", 0)):
			continue
		var entry := (intel as Dictionary).duplicate(true)
		entry["lingstones_cost"] = npc_intel_cost(entry)
		entry["already_known"] = _is_intel_known(gs, _entry_intel_id(entry))
		result.append(entry)
	return result


func available_daily_opportunities_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return []
	var listed_ids := _array(npc_def.get("field_opportunities", []))
	if listed_ids.is_empty():
		return []
	var service = FieldOpportunityServiceScript.new()
	var refresh: Dictionary = service.refresh_daily(gs, _daily_seed(gs))
	if not bool(refresh.get("ok", false)):
		return []
	var result: Array = []
	for entry in service.available_npc_opportunities(npc_id, gs):
		if not entry is Dictionary:
			continue
		if not listed_ids.has(str((entry as Dictionary).get("id", ""))):
			continue
		result.append((entry as Dictionary).duplicate(true))
	return result


func resolve_daily_opportunity(npc_id: String, game_state = null, opportunity_id: String = "") -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state", "npc_id": npc_id}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	var entries := available_daily_opportunities_for_npc(npc_id, gs)
	if opportunity_id == "" and not entries.is_empty():
		opportunity_id = str((entries[0] as Dictionary).get("id", ""))
	if opportunity_id == "":
		return {"ok": false, "reason": "no_available_opportunity", "npc_id": npc_id}
	var listed_ids := _array(npc_def.get("field_opportunities", []))
	if not listed_ids.has(opportunity_id):
		return {"ok": false, "reason": "not_from_npc", "npc_id": npc_id, "opportunity_id": opportunity_id}
	return FieldOpportunityServiceScript.new().resolve_npc_opportunity(gs, npc_id, opportunity_id)


func ask_intel(npc_id: String, game_state = null, intel_id: String = "") -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state"}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	var state = _ensure_npc_state(gs, npc_id, npc_def)
	var entry := _select_intel_entry(npc_def, state, gs, intel_id)
	if entry.is_empty():
		if intel_id != "":
			var requested := _find_intel_entry(npc_def, intel_id)
			if not requested.is_empty():
				return {
					"ok": false,
					"reason": "trust_too_low",
					"npc_id": npc_id,
					"intel_id": intel_id,
					"trust": int(state.trust),
					"required_trust": int(requested.get("trust", 0)),
				}
			return {"ok": false, "reason": "unknown_intel", "npc_id": npc_id, "intel_id": intel_id}
		return {"ok": false, "reason": "no_available_intel", "npc_id": npc_id}
	var resolved_intel_id := _entry_intel_id(entry)
	if _is_intel_known(gs, resolved_intel_id):
		return {"ok": false, "reason": "already_known", "npc_id": npc_id, "intel_id": resolved_intel_id}
	var cost := npc_intel_cost(entry)
	if int(gs.lingstones) < cost:
		return {
			"ok": false,
			"reason": "lingstones_short",
			"npc_id": npc_id,
			"intel_id": resolved_intel_id,
			"lingstones_cost": cost,
			"lingstones": int(gs.lingstones),
		}
	var intel := _intel_from_npc_entry(npc_id, npc_def, entry)
	var grant_result: Dictionary = IntelServiceScript.new().grant(gs, intel)
	if not bool(grant_result.get("ok", false)):
		return {
			"ok": false,
			"reason": str(grant_result.get("reason", "grant_failed")),
			"npc_id": npc_id,
			"intel_id": resolved_intel_id,
			"grant": grant_result,
		}
	gs.lingstones = maxi(0, int(gs.lingstones) - cost)
	var granted_intel: Dictionary = grant_result.get("intel", {}) if grant_result.get("intel", {}) is Dictionary else intel
	var display_text := IntelServiceScript.player_display_text(granted_intel)
	return {
		"ok": true,
		"npc_id": npc_id,
		"intel_id": resolved_intel_id,
		"intel": granted_intel.duplicate(true),
		"lingstones_cost": cost,
		"remaining_lingstones": int(gs.lingstones),
		"display_text": display_text,
	}


func available_commissions_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return []
	var result: Array = []
	for raw_id in _array(npc_def.get("commission_templates", [])):
		var commission_id := str(raw_id)
		if commission_id == "":
			continue
		if _commission_already_active_or_done(gs, commission_id):
			continue
		var commission = _commission_template(commission_id)
		if commission == null or commission.is_empty():
			continue
		if str(commission.issuer_npc) != npc_id:
			continue
		if not _commission_due_for_state(commission, gs):
			continue
		var data: Dictionary = commission.to_dict()
		data["status"] = "available"
		data["source_npc_id"] = npc_id
		result.append(data)
	result.sort_custom(_commission_dict_before)
	return result


func accept_npc_commission(npc_id: String, game_state = null, commission_id: String = "") -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state", "npc_id": npc_id}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	if commission_id == "":
		var available := available_commissions_for_npc(npc_id, gs)
		if available.is_empty():
			return {"ok": false, "reason": "no_available_commission", "npc_id": npc_id}
		commission_id = str((available[0] as Dictionary).get("id", ""))
	if not _npc_lists_commission(npc_def, commission_id):
		return {"ok": false, "reason": "not_from_npc", "npc_id": npc_id, "commission_id": commission_id}
	var commission = _commission_template(commission_id)
	if commission == null or commission.is_empty():
		return {"ok": false, "reason": "unknown_commission", "npc_id": npc_id, "commission_id": commission_id}
	if str(commission.issuer_npc) != npc_id:
		return {"ok": false, "reason": "not_from_npc", "npc_id": npc_id, "commission_id": commission_id}
	if _commission_already_active_or_done(gs, commission_id):
		return {"ok": false, "reason": "already_active_or_done", "npc_id": npc_id, "commission_id": commission_id}
	if not _commission_due_for_state(commission, gs):
		return {"ok": false, "reason": "not_due", "npc_id": npc_id, "commission_id": commission_id}
	var accept_result: Dictionary = CommissionServiceScript.new().accept(gs, commission_id)
	if not bool(accept_result.get("ok", false)):
		accept_result["npc_id"] = npc_id
		return accept_result
	accept_result["npc_id"] = npc_id
	accept_result["commission"] = _commission_available_dict(gs, commission_id, commission)
	return accept_result


func available_jobs_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return []
	var ids := _array(npc_def.get("available_jobs", []))
	var result: Array = []
	for job in JobServiceScript.new().available_jobs(gs, ids):
		if not job is Dictionary:
			continue
		var entry: Dictionary = (job as Dictionary).duplicate(true)
		entry["source_npc_id"] = npc_id
		entry["activity_type"] = "job"
		result.append(entry)
	return result


func available_drills_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return []
	var ids := _array(npc_def.get("available_drills", []))
	var result: Array = []
	for drill in _drill_runner().available_drills(gs, ids):
		if not drill is Dictionary:
			continue
		var entry: Dictionary = (drill as Dictionary).duplicate(true)
		entry["source_npc_id"] = npc_id
		entry["activity_type"] = "drill"
		result.append(entry)
	return result


func start_npc_job(npc_id: String, game_state = null, job_id: String = "", options: Dictionary = {}) -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state", "npc_id": npc_id}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	if job_id == "":
		var available := available_jobs_for_npc(npc_id, gs)
		if available.is_empty():
			return {"ok": false, "reason": "no_available_job", "npc_id": npc_id}
		job_id = str((available[0] as Dictionary).get("id", ""))
	if not _npc_lists_activity(npc_def, "available_jobs", job_id):
		return {"ok": false, "reason": "not_from_npc", "npc_id": npc_id, "job_id": job_id}
	var result: Dictionary = JobServiceScript.new().start_job(gs, job_id, options)
	result["npc_id"] = npc_id
	result["job_id"] = job_id
	return result


func resolve_npc_drill(npc_id: String, game_state = null, drill_id: String = "", options: Dictionary = {}) -> Dictionary:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return {"ok": false, "reason": "missing_game_state", "npc_id": npc_id}
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return {"ok": false, "reason": "unknown_npc", "npc_id": npc_id}
	if drill_id == "":
		var available := available_drills_for_npc(npc_id, gs)
		if available.is_empty():
			return {"ok": false, "reason": "no_available_drill", "npc_id": npc_id}
		drill_id = str((available[0] as Dictionary).get("id", ""))
	if not _npc_lists_activity(npc_def, "available_drills", drill_id):
		return {"ok": false, "reason": "not_from_npc", "npc_id": npc_id, "drill_id": drill_id}
	var result: Dictionary = _drill_runner().resolve_drill(gs, drill_id, options)
	result["npc_id"] = npc_id
	result["drill_id"] = drill_id
	return result


func npc_intel_cost(entry: Dictionary) -> int:
	if entry.has("lingstones_cost"):
		return maxi(0, int(entry.get("lingstones_cost", DEFAULT_NPC_INTEL_LINGSTONES_COST)))
	if entry.has("cost_lingstones"):
		return maxi(0, int(entry.get("cost_lingstones", DEFAULT_NPC_INTEL_LINGSTONES_COST)))
	if entry.has("cost"):
		return maxi(0, int(entry.get("cost", DEFAULT_NPC_INTEL_LINGSTONES_COST)))
	return DEFAULT_NPC_INTEL_LINGSTONES_COST


func pollution_stage_lines_for_npc(npc_id: String, game_state = null) -> Array:
	var gs = _resolve_game_state(game_state)
	if gs == null:
		return []
	var npc_def := _library_get(npc_id)
	if npc_def.is_empty():
		return []
	var stage := int(gs.pollution_stage)
	var result: Array = []
	for raw_line in npc_def.get("pollution_stage_lines", []):
		if not raw_line is Dictionary:
			continue
		var line: Dictionary = raw_line
		var min_stage := int(line.get("min_stage", 0))
		var max_stage := int(line.get("max_stage", 999))
		if stage < min_stage or stage > max_stage:
			continue
		var text := str(line.get("text", "")).strip_edges()
		if text != "":
			result.append(text)
	return result


func request_npc_first_meet_ai_gm(npc_id: String, game_state, state = null) -> String:
	return _request_npc_event_ai_gm("npc_first_meet", "NPC_FIRST_MEET_TEMPLATES", npc_id, game_state, state, {})


func request_npc_relation_shift_ai_gm(npc_id: String, game_state, state = null, previous_trust: int = 0, new_trust: int = 0, threshold_result: Dictionary = {}) -> String:
	return _request_npc_event_ai_gm("npc_relation_shift", "NPC_RELATION_SHIFT_TEMPLATES", npc_id, game_state, state, {
		"previous_trust": previous_trust,
		"new_trust": new_trust,
		"triggered_thresholds": _array(threshold_result.get("triggered_thresholds", [])),
	})


func request_npc_layer_reveal_ai_gm(npc_id: String, game_state, state = null, previous_layer: int = 0, new_layer: int = 0) -> String:
	return _request_npc_event_ai_gm("npc_layer_reveal", "NPC_LAYER_REVEAL_TEMPLATES", npc_id, game_state, state, {
		"previous_layer": previous_layer,
		"new_layer": new_layer,
	})


func request_npc_perception_swap_ai_gm(npc_id: String, game_state, identity_id: String = "", new_perception: String = "") -> String:
	var state = null
	if game_state != null and game_state.npc_relations.has(npc_id):
		state = game_state.npc_relations[npc_id]
		if state is Dictionary:
			state = NpcKnowledgeStateScript.from_dict(state)
			game_state.npc_relations[npc_id] = state
	return _request_npc_event_ai_gm("npc_perception_swap", "NPC_PERCEPTION_SWAP_TEMPLATES", npc_id, game_state, state, {
		"identity_id": identity_id,
		"new_perception": new_perception,
	})


func _request_npc_event_ai_gm(scene_id: String, pool_id: String, npc_id: String, game_state, state = null, extra_payload: Dictionary = {}) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = scene_id
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"npc_id": npc_id,
		"current_district": _state_string(game_state, "current_district", ""),
	}
	for key in extra_payload.keys():
		ctx.scene_payload[str(key)] = extra_payload[key]
	ctx.npc_context = _ai_gm_npc_context(npc_id, state)
	ctx.fallback_template_pool = pool_id
	return _call_ai_gm(ctx)


func _check_relation_thresholds(npc_id: String, state, previous_trust: int, npc_def: Dictionary) -> Dictionary:
	var triggered: Array = []
	var crossed: Array = _array(state.dialogue_state.get("relation_thresholds_crossed", []))
	for threshold in RELATION_THRESHOLDS:
		var threshold_id := str(threshold.get("id", ""))
		var required := int(threshold.get("trust", 0))
		if previous_trust < required and int(state.trust) >= required:
			triggered.append(threshold_id)
			if not crossed.has(threshold_id):
				crossed.append(threshold_id)
	state.dialogue_state["relation_thresholds_crossed"] = crossed

	var unlocked_buffs: Array = _array(state.dialogue_state.get("unlocked_buffs_on_trust", []))
	var newly_unlocked: Array = []
	for buff in npc_def.get("buff_unlocks_on_trust", []):
		if not buff is Dictionary:
			continue
		var required_trust := int(buff.get("trust", 0))
		if previous_trust < required_trust and int(state.trust) >= required_trust:
			var entry: Dictionary = buff.duplicate(true)
			entry["source_npc_id"] = npc_id
			entry["buff_key"] = _buff_key(npc_id, entry)
			if not _has_buff_key(unlocked_buffs, str(entry.get("buff_key", ""))):
				unlocked_buffs.append(entry)
				newly_unlocked.append(entry)
	state.dialogue_state["unlocked_buffs_on_trust"] = unlocked_buffs
	return {"triggered_thresholds": triggered, "unlocked_buffs": newly_unlocked}


func _would_cross_relation_threshold(previous_trust: int, new_trust: int) -> bool:
	for threshold in RELATION_THRESHOLDS:
		var required := int(threshold.get("trust", 0))
		if int(previous_trust) < required and int(new_trust) >= required:
			return true
	return false


func _apply_church_awareness_dialogue_gate(npc_id: String, game_state, state) -> String:
	if npc_id != "brendan" or game_state == null:
		return ""
	var awareness := int(game_state.church_awareness)
	if awareness < 10:
		return ""
	var threshold_id := "threshold_10"
	var branch := "threshold_10_interrogation"
	if awareness >= 50:
		threshold_id = "threshold_50"
		branch = "threshold_50_purge_warning"
	elif awareness >= 25:
		threshold_id = "threshold_25"
		branch = "threshold_25_victor_investigation"
	state.dialogue_state["church_awareness_interrogation"] = threshold_id
	state.dialogue_state["church_awareness_branch"] = branch
	return branch


func _ensure_npc_state(game_state, npc_id: String, npc_def: Dictionary):
	if not game_state.npc_relations.has(npc_id):
		var state = NpcKnowledgeStateScript.new()
		state.trust = int(npc_def.get("default_trust", 0))
		state.suspicion = int(npc_def.get("default_suspicion", 0))
		state.public_data = _dict(npc_def.get("public", {}))
		state.hidden_data = _dict(npc_def.get("hidden", {}))
		state.truth_data = _dict(npc_def.get("truth", {}))
		if int(game_state.day) > 0:
			state.first_met_day = int(game_state.day)
		game_state.npc_relations[npc_id] = state
	var existing = game_state.npc_relations[npc_id]
	if existing is Dictionary:
		existing = NpcKnowledgeStateScript.from_dict(existing)
		game_state.npc_relations[npc_id] = existing
	if int(existing.first_met_day) < 0 and int(game_state.day) > 0:
		existing.first_met_day = int(game_state.day)
	_record_first_met_day(game_state, npc_id, int(existing.first_met_day))
	return existing


func _record_first_met_day(game_state, npc_id: String, first_day: int) -> void:
	if first_day <= 0:
		return
	var daodian: Dictionary = {}
	var raw_daodian = game_state.get("daodian")
	if raw_daodian is Dictionary:
		daodian = raw_daodian
	else:
		game_state.set("daodian", daodian)
	var raw_days: Variant = daodian.get("npc_first_met_days", {})
	if not raw_days is Dictionary:
		raw_days = {}
		daodian["npc_first_met_days"] = raw_days
	var first_met_days: Dictionary = raw_days
	if not first_met_days.has(npc_id):
		first_met_days[npc_id] = first_day


func _npc_has_met(game_state, npc_id: String) -> bool:
	if game_state == null:
		return false
	var existing = game_state.npc_relations.get(npc_id, null)
	if existing != null:
		if existing is Dictionary:
			return int((existing as Dictionary).get("first_met_day", -1)) >= 0
		if existing.has_method("get"):
			return int(existing.get("first_met_day")) >= 0
	var daodian: Variant = game_state.get("daodian")
	if daodian is Dictionary:
		var days: Variant = (daodian as Dictionary).get("npc_first_met_days", {})
		return days is Dictionary and (days as Dictionary).has(npc_id)
	return false


func _library_get(npc_id: String) -> Dictionary:
	if _library == null:
		_library = NpcLibraryScript.new()
		_library.load_all()
	return _library.get_definition(npc_id)


func _get_commission_library():
	if _commission_library == null:
		_commission_library = CommissionLibraryScript.new()
	return _commission_library


func _commission_template(commission_id: String):
	if commission_id == "":
		return null
	return _get_commission_library().get_template(commission_id)


func _commission_due_for_state(commission, game_state) -> bool:
	if commission == null or game_state == null:
		return false
	var day := int(game_state.day)
	if day < int(commission.min_day) or day > int(commission.max_day):
		return false
	return int(game_state.sequence) >= int(commission.min_sequence)


func _commission_already_active_or_done(game_state, commission_id: String) -> bool:
	if game_state == null or commission_id == "":
		return true
	if commission_id in game_state.accepted_commissions or commission_id in game_state.completed_commissions:
		return true
	var available: Variant = game_state.get("available_commissions")
	if available is Array:
		for item in available:
			if not item is Dictionary:
				continue
			var data: Dictionary = item
			if str(data.get("id", "")) != commission_id:
				continue
			var status := str(data.get("status", "available"))
			if ["accepted", "in_progress", "completed", "claimed", "expired"].has(status):
				return true
	return false


func _commission_available_dict(game_state, commission_id: String, fallback) -> Dictionary:
	var available: Variant = game_state.get("available_commissions") if game_state != null else []
	if available is Array:
		for item in available:
			if item is Dictionary and str((item as Dictionary).get("id", "")) == commission_id:
				return (item as Dictionary).duplicate(true)
	if fallback != null and fallback.has_method("to_dict"):
		return fallback.to_dict()
	return {}


func _npc_lists_commission(npc_def: Dictionary, commission_id: String) -> bool:
	for raw_id in _array(npc_def.get("commission_templates", [])):
		if str(raw_id) == commission_id:
			return true
	return false


func _npc_lists_activity(npc_def: Dictionary, key: String, activity_id: String) -> bool:
	if activity_id == "":
		return false
	for raw_id in _array(npc_def.get(key, [])):
		if str(raw_id) == activity_id:
			return true
	return false


static func _commission_dict_before(a: Dictionary, b: Dictionary) -> bool:
	var a_priority := int(a.get("refresh_priority", 1000))
	var b_priority := int(b.get("refresh_priority", 1000))
	if a_priority != b_priority:
		return a_priority < b_priority
	return str(a.get("id", "")) < str(b.get("id", ""))


func _start_dialogic(timeline_id: String, variables: Dictionary, dialogic_adapter = null) -> bool:
	var adapter = dialogic_adapter if dialogic_adapter != null else _find_dialogic_adapter()
	if adapter == null:
		return false
	if adapter.has_method("start"):
		adapter.call("start", timeline_id)
	for key in variables.keys():
		if adapter.has_method("set_variable"):
			adapter.call("set_variable", str(key), variables[key])
		elif adapter.has_method("set"):
			adapter.call("set", StringName(str(key)), variables[key])
	return true


func _find_timeline_branch(npc_id: String, game_state, branch_id: String) -> Dictionary:
	if branch_id == "":
		return {}
	for branch in dialogue_branches_for_npc(npc_id, game_state):
		if branch is Dictionary and str((branch as Dictionary).get("id", "")) == branch_id:
			return (branch as Dictionary).duplicate(true)
	return {}


func _timeline_branches(timeline_id: String) -> Array:
	var timeline_path := "res://dialogic/%s.dtl" % timeline_id
	if not FileAccess.file_exists(timeline_path):
		return []
	var content := FileAccess.get_file_as_string(timeline_path)
	var branches: Array = []
	var current: Dictionary = {}
	for raw_line in content.split("\n"):
		var line := str(raw_line).strip_edges()
		if line == "":
			continue
		if line.begins_with("# branch:"):
			_append_timeline_branch(branches, current)
			var branch_id := line.substr("# branch:".length()).strip_edges()
			current = {
				"id": branch_id,
				"label": _dialogue_branch_label(branch_id),
				"lines": [],
				"outcome": {},
			}
			continue
		if current.is_empty():
			continue
		var outcome_index := line.find("# outcome:")
		if outcome_index >= 0:
			var before := line.substr(0, outcome_index).strip_edges()
			if before != "" and _has_cjk(before):
				(current["lines"] as Array).append(before)
			current["outcome"] = _parse_dialogue_outcome(line.substr(outcome_index + "# outcome:".length()).strip_edges())
			continue
		if line.begins_with("# mainline."):
			current["mainline_node_id"] = line.substr("# mainline.".length()).strip_edges()
			continue
		if line.begins_with("# intel:"):
			current["intel_id"] = line.substr("# intel:".length()).split(" ", false)[0]
			continue
		if line.begins_with("#"):
			continue
		if _has_cjk(line):
			(current["lines"] as Array).append(line)
	_append_timeline_branch(branches, current)
	return branches


func _append_timeline_branch(branches: Array, branch: Dictionary) -> void:
	if branch.is_empty():
		return
	var lines: Array = branch.get("lines", []) if branch.get("lines", []) is Array else []
	var clean_lines: Array[String] = []
	for line in lines:
		var text := str(line).strip_edges()
		if text != "":
			clean_lines.append(text)
	branch["text"] = "\n".join(clean_lines)
	branches.append(branch.duplicate(true))


func _parse_dialogue_outcome(payload: String) -> Dictionary:
	var outcome: Dictionary = {}
	for key in ["trust_delta", "suspicion_delta", "layer_revealed_to", "dialogue_rounds", "round_count"]:
		var value = _extract_int_assignment(payload, key)
		if value != null:
			outcome[key] = int(value)
	var unlocked := _extract_string_array_assignment(payload, "unlocked_dialogue_branches")
	if not unlocked.is_empty():
		outcome["unlocked_dialogue_branches"] = unlocked
	return outcome


func _extract_int_assignment(payload: String, key: String):
	var marker := "%s=" % key
	var index := payload.find(marker)
	if index < 0:
		return null
	var start := index + marker.length()
	var end := start
	while end < payload.length():
		var ch := payload.substr(end, 1)
		if (ch >= "0" and ch <= "9") or ch == "-":
			end += 1
		else:
			break
	if end <= start:
		return null
	return int(payload.substr(start, end - start))


func _extract_string_array_assignment(payload: String, key: String) -> Array[String]:
	var result: Array[String] = []
	var marker := "%s=" % key
	var index := payload.find(marker)
	if index < 0:
		return result
	var open := payload.find("[", index + marker.length())
	var close := payload.find("]", open)
	if open < 0 or close < 0 or close <= open:
		return result
	var body := payload.substr(open + 1, close - open - 1)
	for raw_item in body.split(",", false):
		var item := str(raw_item).strip_edges().replace("\"", "").replace("'", "")
		if item != "":
			result.append(item)
	return result


func _dialogue_branch_label(branch_id: String) -> String:
	match branch_id:
		"first_meet":
			return "\u521d\u6b21\u4ea4\u8c08"
		"small_talk":
			return "\u95f2\u804a"
		"ask_intel":
			return "\u8be2\u95ee\u60c5\u62a5"
		"ask_well":
			return "\u8be2\u95ee\u4e95\u53e3"
		"node_4_anchor":
			return "\u4e3b\u7ebf\u7ebf\u7d22"
		"commission_placeholder":
			return "\u59d4\u6258\u7ebf\u7d22"
		"leave":
			return "\u79bb\u5f00"
		_:
			return branch_id.replace("_", " ")


func _dialogue_preview(timeline_id: String, npc_def: Dictionary) -> String:
	var timeline_path := "res://dialogic/%s.dtl" % timeline_id
	var lines: Array[String] = []
	if FileAccess.file_exists(timeline_path):
		var content := FileAccess.get_file_as_string(timeline_path)
		for raw_line in content.split("\n"):
			var line := str(raw_line).strip_edges()
			if line == "" or line.begins_with("#"):
				continue
			if line.find(":") < 0:
				continue
			if not _has_cjk(line):
				continue
			lines.append(line)
			if lines.size() >= 3:
				break
	if not lines.is_empty():
		return "\n".join(lines)
	var display_name := str(npc_def.get("display_name", "对方"))
	var public: Dictionary = npc_def.get("public", {}) if npc_def.get("public", {}) is Dictionary else {}
	var role := str(public.get("role", ""))
	if role != "":
		return "%s：你靠近%s，准备开口。" % [display_name, role]
	return "%s：你靠近对方，准备开口。" % display_name


func _append_preview_lines(preview: String, lines: Array) -> String:
	var result := str(preview)
	for line in lines:
		var text := str(line).strip_edges()
		if text == "":
			continue
		if result == "":
			result = text
		else:
			result += "\n%s" % text
	return result


func _find_dialogic_adapter():
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("Dialogic")
	return null


func _resolve_game_state(game_state):
	if game_state != null:
		return game_state
	var loop := Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		return loop.root.get_node_or_null("GameState")
	return null


func _residual_identity_display_name(game_state, identity_id: String) -> String:
	if game_state == null:
		return identity_id
	var identities = game_state.get("residual_identities") if game_state.has_method("get") else []
	if not identities is Array:
		return identity_id
	for raw_identity in identities:
		var raw_id := ""
		var raw_name := ""
		if raw_identity is Dictionary:
			var data: Dictionary = raw_identity
			raw_id = str(data.get("id", ""))
			raw_name = str(data.get("name", data.get("display_name", "")))
		elif raw_identity is Object and raw_identity.has_method("get"):
			raw_id = str(raw_identity.get("id"))
			raw_name = str(raw_identity.get("name"))
			if raw_name == "":
				raw_name = str(raw_identity.get("display_name"))
		if raw_id == identity_id:
			return raw_name if raw_name.strip_edges() != "" else identity_id
	return identity_id


func _call_ai_gm(ctx) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var service = _resolve_ai_gm_service()
	if service == null or not service.has_method("call_ai_gm"):
		return ""
	return str(service.call_ai_gm(ctx))


func _resolve_ai_gm_service():
	if _ai_gm_service != null:
		return _ai_gm_service
	_ai_gm_service = AIGMServiceScript.new()
	return _ai_gm_service


func _drill_runner():
	if _drill_runner_override != null:
		return _drill_runner_override
	var runner = DrillRunnerScript.new()
	if _ai_gm_service != null and runner.has_method("set_ai_gm_service"):
		runner.set_ai_gm_service(_ai_gm_service)
	return runner


func _ai_gm_player_state(game_state) -> Dictionary:
	return {
		"sequence": _state_int(game_state, "sequence", 9),
		"pollution": _state_int(game_state, "pollution", 0),
		"pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"cycle": _state_int(game_state, "cycle", 1),
		"day": _state_int(game_state, "day", 1),
		"time_of_day": _state_string(game_state, "time_of_day", "morning"),
	}


func _ai_gm_npc_context(npc_id: String, state) -> Dictionary:
	return {
		"target_npc_id": npc_id,
		"active_perception": str(state.active_perception) if state != null else "",
		"trust": int(state.trust) if state != null else 0,
		"suspicion": int(state.suspicion) if state != null else 0,
		"layer_revealed": int(state.layer_revealed) if state != null else 0,
	}


func _state_int(game_state, field_name: String, fallback: int) -> int:
	if game_state == null:
		return fallback
	var value = game_state.get(field_name)
	return fallback if value == null else int(value)


func _state_string(game_state, field_name: String, fallback: String) -> String:
	if game_state == null:
		return fallback
	var value = game_state.get(field_name)
	return fallback if value == null else str(value)


func _daily_seed(game_state) -> int:
	if game_state == null:
		return 0
	return int(game_state.day) * 10000 + int(game_state.sequence) * 100 + (abs(str(game_state.time_of_day).hash()) % 100)


func _merge_string_array(target: Array[String], values: Variant) -> void:
	if not values is Array:
		return
	for value in values:
		var id := str(value)
		if id != "" and not target.has(id):
			target.append(id)


func _merge_array(target: Array, values: Variant) -> void:
	if not values is Array:
		return
	for value in values:
		target.append(value)


func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _select_intel_entry(npc_def: Dictionary, state, game_state, intel_id: String = "") -> Dictionary:
	if intel_id != "":
		var requested := _find_intel_entry(npc_def, intel_id)
		if requested.is_empty() or int(state.trust) < int(requested.get("trust", 0)):
			return {}
		return requested
	for intel in npc_def.get("available_intels", []):
		if not intel is Dictionary:
			continue
		var entry: Dictionary = intel
		if int(state.trust) < int(entry.get("trust", 0)):
			continue
		if _is_intel_known(game_state, _entry_intel_id(entry)):
			continue
		return entry.duplicate(true)
	return {}


func _find_intel_entry(npc_def: Dictionary, intel_id: String) -> Dictionary:
	if intel_id == "":
		return {}
	for intel in npc_def.get("available_intels", []):
		if not intel is Dictionary:
			continue
		var entry: Dictionary = intel
		if _entry_intel_id(entry) == intel_id:
			return entry.duplicate(true)
	return {}


func _intel_from_npc_entry(npc_id: String, npc_def: Dictionary, entry: Dictionary) -> Dictionary:
	var target: Dictionary = {}
	var raw_target: Variant = entry.get("apply_target", {})
	if raw_target is Dictionary:
		target = raw_target.duplicate(true)
	else:
		target = {
			"kind": "npc_chat.note",
			"payload": {
				"npc_id": npc_id,
				"topic_id": str(entry.get("topic", "")),
			},
		}
	return {
		"id": _entry_intel_id(entry),
		"category": str(entry.get("category", "npc")),
		"display_text": str(entry.get("display_text", entry.get("summary", _entry_intel_id(entry)))),
		"source_type": str(entry.get("source_type", "npc_chat")),
		"source_district": str(entry.get("source_district", npc_def.get("default_district", ""))),
		"source_npc": npc_id,
		"expires_after": str(entry.get("expires_after", "permanent")),
		"apply_target": target,
		"truth_value": int(entry.get("truth_value", 100)),
	}


func _entry_intel_id(entry: Dictionary) -> String:
	return str(entry.get("intel_id", entry.get("id", "")))


func _is_intel_known(game_state, intel_id: String) -> bool:
	if game_state == null or intel_id == "":
		return false
	var active: Variant = game_state.get("active_rumors")
	if active is Array:
		for item in active:
			if item is Dictionary and str((item as Dictionary).get("id", "")) == intel_id:
				return true
	var history: Variant = game_state.get("heard_rumor_history")
	if history is Dictionary:
		var ids: Variant = (history as Dictionary).get(str(int(game_state.get("day"))), [])
		if ids is Array and (ids as Array).has(intel_id):
			return true
	return false


func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _buff_key(npc_id: String, buff: Dictionary) -> String:
	return "%s:%d:%s" % [npc_id, int(buff.get("trust", 0)), str(buff.get("type", ""))]


func _has_buff_key(entries: Array, key: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("buff_key", "")) == key:
			return true
	return false
