class_name EncounterRunner
extends PanelContainer

signal encounter_resolved(result)

const EncounterChainStateScript = preload("res://scripts/world/encounter_chain_state.gd")
const ApServiceScript = preload("res://scripts/state/ap_service.gd")
const R20EffectEngineScript = preload("res://scripts/world/r20_effect_engine.gd")
const ChantButtonFactoryScript = preload("res://scripts/world/chant_button_factory.gd")
const IdentityPickerScript = preload("res://scripts/world/identity_picker_dialog.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

var _game_state = null
var _encounter = null
var _title_label: Label = null
var _body_label: Label = null
var _choice_box: VBoxContainer = null
var _last_result: Dictionary = {}
var _ai_gm_service = null
var _last_r20_feedback_text := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 280)
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -280.0
	offset_top = -140.0
	offset_right = 280.0
	offset_bottom = 140.0
	_build_ui()


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func start(encounter, game_state = null) -> Dictionary:
	var ap_cost := ApServiceScript.passive_encounter_cost(_encounter_step_count(encounter))
	var spend: Dictionary = ApServiceScript.try_spend_passive_encounter(game_state, _encounter_step_count(encounter))
	if not bool(spend.get("ok", false)):
		_encounter = null
		_game_state = game_state
		_last_result = {
			"ok": false,
			"reason": str(spend.get("reason", "ap_short")),
			"ap_cost": ap_cost,
			"spend": spend,
		}
		visible = false
		return _last_result.duplicate(true)
	_encounter = encounter
	_game_state = game_state
	_last_r20_feedback_text = ""
	var identity_result := _prepare_encounter_identity(encounter, game_state)
	_move_to_front()
	_last_result = {
		"ok": true,
		"reason": "started",
		"ap_cost": ap_cost,
		"spend": spend,
		"identity_result": identity_result,
	}
	_render()
	visible = true
	return _last_result.duplicate(true)


func resolve_choice(choice_id: String) -> Dictionary:
	var choice := _find_choice(choice_id)
	if choice.is_empty():
		return {"ok": false, "reason": "missing_choice"}
	var outcome: Dictionary = choice.get("outcome", {})
	_apply_outcome(outcome, choice_id)
	_last_result = {
		"ok": true,
		"choice_id": choice_id,
		"outcome": outcome.duplicate(true),
	}
	_last_result["ai_gm_text"] = request_encounter_resolve_ai_gm(choice_id, outcome)
	var ai_gm_text := str(_last_result.get("ai_gm_text", "")).strip_edges()
	if ai_gm_text != "":
		_show_resolution(ai_gm_text)
	else:
		visible = false
	encounter_resolved.emit(_last_result.duplicate(true))
	return _last_result.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func request_encounter_resolve_ai_gm(choice_id: String, outcome: Dictionary = {}) -> String:
	if not _encounter_type_allows_ai_gm():
		return ""
	var ai_gm: Dictionary = outcome.get("ai_gm", {}) if outcome.get("ai_gm", {}) is Dictionary else {}
	if not ai_gm.is_empty() and str(ai_gm.get("scene", "encounter_resolve")) != "encounter_resolve":
		return ""
	var ctx = PromptContextScript.new()
	ctx.scene = "encounter_resolve"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"encounter_id": str(_encounter_value("id", "")),
		"encounter_type": str(_encounter_value("encounter_type", "")),
		"chosen_choice_id": choice_id,
		"tone": str(ai_gm.get("tone", "")),
		"current_pollution_stage": _state_int(_game_state, "pollution_stage", 0),
		"chain_id": str(_encounter_value("chain_id", "")),
		"chain_step": int(_encounter_value("chain_step", 0)),
	}
	ctx.fallback_template_pool = "ENCOUNTER_RESOLVE_TEMPLATES"
	return _call_ai_gm(ctx)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "Root"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(520, 240)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "邂逅"
	root.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.text = ""
	root.add_child(_body_label)

	_choice_box = VBoxContainer.new()
	_choice_box.name = "ChoiceBox"
	_choice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_box.add_theme_constant_override("separation", 6)
	root.add_child(_choice_box)


func _move_to_front() -> void:
	var parent_node := get_parent()
	if parent_node != null:
		parent_node.move_child(self, parent_node.get_child_count() - 1)
	z_index = 1000


func _render() -> void:
	if _title_label == null or _body_label == null or _choice_box == null:
		return
	_clear_choice_box()
	var title := str(_encounter_value("display_name", _encounter_value("id", "邂逅")))
	var text := render_text(_encounter, _game_state)
	_title_label.text = title
	_body_label.text = text
	var choices: Array = _choices()
	if choices.is_empty():
		visible = false
		return
	for choice in choices:
		var button := Button.new()
		button.name = "EncounterChoice_%s" % str(choice.get("id", "choice"))
		button.text = str(choice.get("label", button.name))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_choice_pressed.bind(str(choice.get("id", ""))))
		_choice_box.add_child(button)
	_add_r20_chant_choices()
	_add_r20_feedback_label()


func _clear_choice_box() -> void:
	if _choice_box == null:
		return
	for child in _choice_box.get_children():
		_choice_box.remove_child(child)
		child.queue_free()


func _show_resolution(ai_gm_text: String) -> void:
	if _body_label == null or _choice_box == null:
		return
	_clear_choice_box()
	var base_text := render_text(_encounter, _game_state)
	if base_text.strip_edges() != "":
		_body_label.text = "%s\n%s" % [base_text, ai_gm_text]
	else:
		_body_label.text = ai_gm_text
	var close_button := Button.new()
	close_button.name = "EncounterCloseButton"
	close_button.text = "关闭"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(_on_close_pressed)
	_choice_box.add_child(close_button)
	visible = true


func _on_close_pressed() -> void:
	visible = false


func _choices() -> Array:
	if _encounter == null:
		return []
	var payload: Variant = _encounter.get("scene_payload")
	if not payload is Dictionary:
		return []
	var choices = payload.get("choices", [])
	if choices is Array:
		return choices
	return []


func _add_r20_chant_choices() -> void:
	if _choice_box == null or _game_state == null:
		return
	var target_npc_id := _target_npc_id()
	if target_npc_id == "":
		return
	ChantButtonFactoryScript.add_chant_buttons(_choice_box, _game_state, target_npc_id, Callable(self, "_on_r20_chant_pressed"))


func _target_npc_id() -> String:
	if _encounter == null:
		return ""
	var payload = _encounter.get("scene_payload")
	if payload is Dictionary:
		for key in ["target_npc_id", "npc_id"]:
			var value := str((payload as Dictionary).get(key, ""))
			if value != "":
				return value
	var direct: Variant = _encounter_value("target_npc_id", "")
	if str(direct) != "":
		return str(direct)
	return ""


func render_text(encounter, game_state = null) -> String:
	var base_text := _scene_text(encounter)
	var variant := _pollution_variant_for(encounter, game_state if game_state != null else _game_state)
	if variant.has("text"):
		return str(variant.get("text", base_text))
	return base_text


func _prepare_encounter_identity(encounter, game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_game_state"}
	var district_id := _encounter_identity_district(encounter, game_state)
	var picker = IdentityPickerScript.new()
	var identity_id := picker.choose_identity_for_location(district_id, game_state)
	var result: Dictionary = picker.use_identity_for_location(district_id, game_state, identity_id)
	if bool(result.get("ok", false)):
		game_state.set_meta("active_encounter_identity", str(result.get("identity", "harvey")))
	game_state.set_meta("last_encounter_identity_result", result.duplicate(true))
	return result


func _encounter_identity_district(encounter, game_state) -> String:
	var district_id := _state_string(game_state, "current_district", "")
	if district_id != "":
		return district_id
	var districts: Variant = []
	if encounter is Dictionary:
		districts = encounter.get("districts", [])
	elif encounter != null:
		districts = encounter.get("districts")
	if districts is Array and not (districts as Array).is_empty():
		return str((districts as Array)[0])
	return ""


func _scene_text(encounter) -> String:
	if encounter == null:
		return ""
	var payload = encounter.get("scene_payload")
	if not payload is Dictionary:
		return str(_encounter_value("display_name", ""))
	return str(payload.get("text", _encounter_value("display_name", "")))


func _find_choice(choice_id: String) -> Dictionary:
	for choice in _choices():
		if choice is Dictionary and str(choice.get("id", "")) == choice_id:
			return choice
	return {}


func _encounter_step_count(encounter) -> int:
	if encounter == null:
		return 1
	if encounter is Dictionary:
		return int(encounter.get("step_count", 1))
	var value = encounter.get("step_count")
	return 1 if value == null else int(value)


func _pollution_variant_for(encounter, game_state) -> Dictionary:
	if encounter == null or game_state == null:
		return {}
	var variants = encounter.get("pollution_variant")
	if not variants is Dictionary:
		return {}
	var stage_value = game_state.get("pollution_stage")
	var stage_key := str(int(stage_value if stage_value != null else 0))
	var variant = variants.get(stage_key, {})
	if variant is Dictionary:
		return variant.duplicate(true)
	return {}


func _apply_outcome(outcome: Dictionary, choice_id: String) -> void:
	if _game_state == null:
		return
	if outcome.has("lingstones_delta"):
		_game_state.lingstones = int(_game_state.lingstones) + int(outcome.get("lingstones_delta", 0))
	if outcome.has("story_flags"):
		_apply_story_flags(outcome.get("story_flags", {}))
	if outcome.has("church_awareness_delta"):
		_apply_church_awareness_delta(int(outcome.get("church_awareness_delta", 0)))
	if outcome.has("pollution_delta"):
		_apply_pollution_delta(int(outcome.get("pollution_delta", 0)), choice_id)
	if outcome.has("halfmoon_trust_delta"):
		_game_state.halfmoon_trust = clampi(int(_game_state.halfmoon_trust) + int(outcome.get("halfmoon_trust_delta", 0)), -100, 100)
	if outcome.has("unlock_chain_step") or outcome.has("chain_lock"):
		_apply_chain_step(outcome, choice_id)


func _apply_story_flags(value: Variant) -> void:
	if not value is Dictionary:
		return
	var flags: Variant = _game_state.get("story_flags")
	var target: Dictionary = {}
	if not flags is Dictionary:
		_game_state.set("story_flags", target)
	else:
		target = (flags as Dictionary)
	for key in (value as Dictionary).keys():
		target[str(key)] = (value as Dictionary)[key]
	_game_state.set("story_flags", target)


func _apply_church_awareness_delta(delta: int) -> void:
	if delta == 0:
		return
	if _game_state.has_method("adjust_church_awareness"):
		_game_state.adjust_church_awareness(delta, "encounter:%s" % str(_encounter_value("id", "")))
	else:
		_game_state.church_awareness = clampi(int(_game_state.church_awareness) + delta, 0, 100)


func _apply_pollution_delta(delta: int, choice_id: String) -> void:
	if delta == 0:
		return
	var next_value := clampi(int(_game_state.pollution) + delta, 0, 100)
	if _game_state.has_method("set_pollution"):
		_game_state.set_pollution(next_value, ["encounter:%s:%s" % [str(_encounter_value("id", "")), choice_id]])
	else:
		_game_state.pollution = next_value


func _apply_chain_step(outcome: Dictionary, choice_id: String) -> void:
	var chain_id := str(_encounter_value("chain_id", ""))
	if chain_id == "":
		return
	var chains = _game_state.get("encounter_chains")
	if not chains is Dictionary:
		chains = {}
		_game_state.set("encounter_chains", chains)
	var state = chains.get(chain_id, null)
	if state == null:
		state = EncounterChainStateScript.new()
		state.chain_id = chain_id
		chains[chain_id] = state
	if state is Object and state.has_method("record_step"):
		state.record_step(int(_encounter_value("chain_step", 0)), str(_encounter_value("id", "")), choice_id, int(_game_state.day))
		state.current_step = max(int(state.current_step), int(outcome.get("unlock_chain_step", state.current_step)))
		if bool(outcome.get("chain_lock", false)):
			state.locked = true


func _on_choice_pressed(choice_id: String) -> void:
	resolve_choice(choice_id)


func _on_r20_chant_pressed(card_id: String, npc_id: String) -> void:
	if _game_state == null:
		return
	var card = _game_state.get_card(card_id) if _game_state.has_method("get_card") else null
	if card == null:
		return
	var result: Dictionary = R20EffectEngineScript.new().dispatch_card(card, npc_id, {
		"game_state": _game_state,
		"source": "encounter_runner",
	})
	_last_r20_feedback_text = _r20_feedback_text(result)
	_render()


func _add_r20_feedback_label() -> void:
	if _choice_box == null or _last_r20_feedback_text.strip_edges() == "":
		return
	var label := Label.new()
	label.name = "EncounterR20FeedbackLabel"
	label.text = _last_r20_feedback_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.visible = true
	_choice_box.add_child(label)


func _r20_feedback_text(result: Dictionary) -> String:
	var engine = R20EffectEngineScript.new()
	if engine.has_method("player_feedback_text"):
		return engine.call("player_feedback_text", result)
	var field_hook: Dictionary = result.get("field_hook_result", {}) if result.get("field_hook_result", {}) is Dictionary else {}
	var display_text := str(field_hook.get("display_text", "")).strip_edges()
	if display_text != "":
		return display_text
	var hook_text := str(field_hook.get("result_text", "")).strip_edges()
	if hook_text != "":
		return hook_text
	if not field_hook.is_empty():
		var hook_type := str(field_hook.get("hook_type", "")).strip_edges()
		if hook_type != "":
			return "R20 field hook: %s" % hook_type
	if bool(result.get("success", false)):
		return "R20 effect applied."
	return "R20 effect failed: %s" % str(result.get("reason", "unknown"))


func _encounter_value(field_name: String, fallback: Variant = null) -> Variant:
	if _encounter == null:
		return fallback
	if _encounter is Dictionary:
		return _encounter.get(field_name, fallback)
	var value = _encounter.get(field_name)
	return fallback if value == null else value


func _encounter_type_allows_ai_gm() -> bool:
	var encounter_type := str(_encounter_value("encounter_type", ""))
	return ["mystery_seed", "horror", "windfall"].has(encounter_type)


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


func _ai_gm_player_state() -> Dictionary:
	return {
		"sequence": _state_int(_game_state, "sequence", 9),
		"pollution": _state_int(_game_state, "pollution", 0),
		"pollution_stage": _state_int(_game_state, "pollution_stage", 0),
		"cycle": _state_int(_game_state, "cycle", 1),
		"day": _state_int(_game_state, "day", 1),
		"time_of_day": _state_string(_game_state, "time_of_day", "morning"),
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
