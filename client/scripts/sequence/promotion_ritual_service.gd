extends RefCounted

const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")
const GATE_DIR := "res://data/sequence/promotion_gates/"
const RITUAL_TOWER_DIR := "res://data/towers/"
const PAPER_BLADE_TOWER_DATA := "res://data/towers/ritual_paper_blade.json"
const DEFAULT_AP_MAX := 12
const RITUAL_FAILURE_COOLDOWN_DAYS := 7


static func can_start_ritual(gate_id: String, game_state) -> bool:
	var gate: SequencePromotionGate = _load_gate(gate_id)
	if gate == null:
		return false
	if not gate.can_promote(_state_dict(game_state)):
		return false
	return _ritual_block_reason(gate_id, game_state) == ""


static func next_gate_id(game_state) -> String:
	var sequence := 9
	if game_state is Dictionary:
		sequence = int(game_state.get("sequence", 9))
	elif game_state != null:
		sequence = int(game_state.get("sequence"))
	match sequence:
		9:
			return "fool_9_to_8"
		8:
			return "fool_8_to_7"
		_:
			return ""


static func start_ritual(gate_id: String, game_state) -> Dictionary:
	var gate: SequencePromotionGate = _load_gate(gate_id)
	if gate == null:
		return {"ok": false, "error": "gate_not_found"}
	if not gate.can_promote(_state_dict(game_state)):
		return {"ok": false, "error": "gate_not_satisfied", "gate": gate}
	var block_reason := _ritual_block_reason(gate_id, game_state)
	if block_reason != "":
		return {"ok": false, "error": block_reason, "gate": gate}
	_snapshot_active_contract(game_state)
	_force_all_contracts(game_state)
	var tower: Tower = _build_tower(gate_id, gate)
	return {"ok": true, "gate": gate, "tower": tower}


static func complete(tower, game_state) -> Dictionary:
	if tower == null or game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var ai_gm_text := request_sequence_promotion_ai_gm(tower, game_state, {
		"contract_ratio": 1.0,
	})
	var target_sequence := int(tower.promotion_to_sequence)
	if target_sequence >= 0:
		game_state.sequence = target_sequence
	game_state.sequence_exp = 0
	if game_state.has_method("set_ap_max"):
		game_state.set_ap_max(maxi(DEFAULT_AP_MAX, int(game_state.ap_max)))
	else:
		game_state.ap_max = maxi(DEFAULT_AP_MAX, int(game_state.ap_max))
	if game_state.has_method("record_sleep_deficit"):
		game_state.record_sleep_deficit(0)
	else:
		game_state.last_sleep_ap_deficit = 0
	if game_state.has_method("clear_promotion_cooldown"):
		game_state.clear_promotion_cooldown(str(tower.promotion_gate_id))
	else:
		game_state.promotion_cooldown_until_day = 0
		game_state.promotion_cooldown_gate_id = ""
	restore_active_contract(game_state)
	_clear_prompt_meta(game_state)
	if ai_gm_text != "" and game_state.has_method("set_meta"):
		game_state.set_meta("sequence_promotion_ai_gm_text", ai_gm_text)
	return {
		"ok": true,
		"sequence": int(game_state.sequence),
		"sequence_exp": int(game_state.sequence_exp),
		"ap_max": int(game_state.ap_max),
		"ai_gm_text": ai_gm_text,
	}


static func fail(tower, game_state) -> Dictionary:
	if tower != null:
		tower.resolution = "collapsed"
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var gate_id := str(tower.promotion_gate_id) if tower != null else next_gate_id(game_state)
	game_state.pollution = clampi(int(game_state.pollution) + 20, 0, 100)
	game_state.pollution_stage = _pollution_stage(int(game_state.pollution))
	if game_state.has_method("set_promotion_cooldown"):
		game_state.set_promotion_cooldown(gate_id, RITUAL_FAILURE_COOLDOWN_DAYS)
	else:
		game_state.promotion_cooldown_gate_id = gate_id
		game_state.promotion_cooldown_until_day = int(game_state.day) + RITUAL_FAILURE_COOLDOWN_DAYS
	restore_active_contract(game_state)
	_clear_prompt_meta(game_state)
	return {
		"ok": true,
		"gate_id": gate_id,
		"pollution": int(game_state.pollution),
		"cooldown_until_day": int(game_state.promotion_cooldown_until_day),
	}


static func check_after_exp_gain(game_state) -> Dictionary:
	var gate_id := next_gate_id(game_state)
	if gate_id == "":
		_clear_prompt_meta(game_state)
		return {"ok": true, "gate_id": "", "can_promote": false}
	var can_promote := can_start_ritual(gate_id, game_state)
	if game_state != null and not (game_state is Dictionary) and game_state.has_method("set_meta"):
		game_state.set_meta("promotion_prompt_pending", can_promote)
		game_state.set_meta("promotion_prompt_gate_id", gate_id if can_promote else "")
	return {"ok": true, "gate_id": gate_id, "can_promote": can_promote}


static func check_after_meditation(game_state) -> Dictionary:
	return check_after_exp_gain(game_state)


static func request_sequence_promotion_ai_gm(tower, game_state, options: Dictionary = {}, service = null) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "sequence_promotion"
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"from_sequence": _tower_int(tower, "promotion_from_sequence", _state_int(game_state, "sequence", 9)),
		"to_sequence": _tower_int(tower, "promotion_to_sequence", _state_int(game_state, "sequence", 9) - 1),
		"ritual_tower_id": _tower_string(tower, "tower_id", ""),
		"contract_ratio": float(options.get("contract_ratio", 1.0)),
	}
	ctx.fallback_template_pool = "SEQUENCE_PROMOTION_TEMPLATES"
	return _call_ai_gm(ctx, service)


static func _load_gate(gate_id: String) -> SequencePromotionGate:
	if gate_id == "":
		return null
	var path := "%s%s.json" % [GATE_DIR, gate_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	return SequencePromotionGate.from_json(parsed)


static func _state_dict(game_state) -> Dictionary:
	if game_state == null:
		return {}
	if game_state is Dictionary:
		return game_state.duplicate(true)
	if game_state.has_method("to_dict"):
		return game_state.to_dict()
	return {}


static func _force_all_contracts(game_state) -> void:
	if game_state == null or game_state is Dictionary:
		return
	var learned_rules: Array = game_state.get("learned_rules")
	game_state.active_contract.clear()
	for rule in learned_rules:
		game_state.active_contract.append(str(rule))


static func _snapshot_active_contract(game_state) -> void:
	if game_state == null or game_state is Dictionary or not game_state.has_method("set_meta"):
		return
	if game_state.has_meta("ritual_pre_active_contract"):
		return
	game_state.set_meta("ritual_pre_active_contract", game_state.active_contract.duplicate())


static func restore_active_contract(game_state) -> void:
	if game_state == null or game_state is Dictionary:
		return
	if not game_state.has_method("has_meta") or not game_state.has_meta("ritual_pre_active_contract"):
		return
	var snapshot: Variant = game_state.get_meta("ritual_pre_active_contract", [])
	if snapshot is Array:
		game_state.active_contract.clear()
		for rule in snapshot:
			game_state.active_contract.append(str(rule))
	if game_state.has_method("remove_meta"):
		game_state.remove_meta("ritual_pre_active_contract")
	elif game_state.has_method("set_meta"):
		game_state.set_meta("ritual_pre_active_contract", null)


static func _clear_prompt_meta(game_state) -> void:
	if game_state != null and not (game_state is Dictionary) and game_state.has_method("set_meta"):
		game_state.set_meta("promotion_prompt_pending", false)
		game_state.set_meta("promotion_prompt_gate_id", "")


static func _build_tower(gate_id: String, gate: SequencePromotionGate) -> Tower:
	var data: Dictionary = _ritual_tower_data(gate_id, gate.ritual_tower_id)
	if not data.is_empty():
		return _build_tower_from_data(gate_id, gate, data)
	var tower := Tower.new()
	tower.tower_id = gate.ritual_tower_id if gate.ritual_tower_id != "" else "ritual_tower_introspection_3f"
	tower.tower_name = _tower_name(gate_id)
	tower.size = "small"
	tower.district = "ritual"
	tower.is_ritual_tower = true
	tower.promotion_gate_id = gate_id
	tower.promotion_from_sequence = gate.from_sequence
	tower.promotion_to_sequence = gate.to_sequence
	tower.floors = _build_floors(gate)
	tower.floor_count = tower.floors.size()
	return tower


static func _build_tower_from_data(gate_id: String, gate: SequencePromotionGate, data: Dictionary) -> Tower:
	var tower := Tower.new()
	tower.tower_id = str(data.get("tower_id", gate.ritual_tower_id))
	tower.tower_name = str(data.get("tower_name", _tower_name(gate_id)))
	tower.size = str(data.get("size", "small"))
	tower.district = str(data.get("district", "ritual"))
	tower.is_ritual_tower = true
	tower.promotion_gate_id = gate_id
	tower.promotion_from_sequence = gate.from_sequence
	tower.promotion_to_sequence = gate.to_sequence
	var floors: Variant = data.get("floors", [])
	if floors is Array:
		for i in range(floors.size()):
			var floor_data = floors[i]
			if floor_data is Dictionary:
				tower.floors.append(_floor_from_data(floor_data, i))
	tower.floor_count = tower.floors.size()
	return tower


static func _floor_from_data(data: Dictionary, fallback_index: int) -> Floor:
	var floor := Floor.new()
	floor.floor_index = int(data.get("floor_index", fallback_index))
	floor.event_type = str(data.get("event_type", "event"))
	floor.event_data = _dict(data.get("event_data", {}))
	floor.ai_gm_narrative = str(data.get("ai_gm_narrative", data.get("narrative", "")))
	return floor


static func _build_floors(gate: SequencePromotionGate) -> Array:
	if gate.from_sequence == 8 and gate.to_sequence == 7:
		return [
			_make_event_floor(1, "纸刃回声", "你在旧纸页边缘看见最近一次击杀的折痕。"),
			_make_battle_floor(2, ["vagrant"], "纸屑在风里立起，逼你重演那次出手。"),
			_make_battle_floor(3, ["shadow_wraith"], "暗影模仿你的动作，等待你承认命运的线。"),
			_make_boss_floor(4, "alley_horror", "最终的纸刃指向你自己，塔门在身后闭合。"),
		]
	return [
		_make_event_floor(1, "微表情记录", "内省塔要求你复盘七日内记录的三处习惯动作。"),
		_make_battle_floor(2, ["shadow_wraith"], "影子戴上你的神情，逼你旁观自己的恐惧。"),
		_make_boss_floor(3, "alley_horror", "塔顶的替身没有脸，只重复你没有说出口的名字。"),
	]


static func _make_event_floor(index: int, title: String, narrative: String) -> Floor:
	return _make_floor(index, "event", {
		"title": title,
		"narrative_template": narrative,
		"choices": [
			{"id": "observe", "text": "记录并继续", "outcome": {}},
		],
	}, narrative)


static func _make_battle_floor(index: int, enemy_ids: Array, narrative: String) -> Floor:
	return _make_floor(index, "battle", {
		"enemy_pack_id": "ritual_floor_%d" % index,
		"enemy_ids": enemy_ids,
		"victory_drops": {},
	}, narrative)


static func _make_boss_floor(index: int, boss_id: String, narrative: String) -> Floor:
	return _make_floor(index, "boss", {
		"boss_id": boss_id,
		"boss_pack": [],
		"victory_drops": {"sequence_promotion": true},
	}, narrative)


static func _make_floor(index: int, event_type: String, event_data: Dictionary, narrative: String) -> Floor:
	var floor := Floor.new()
	floor.floor_index = index
	floor.event_type = event_type
	floor.event_data = event_data
	floor.ai_gm_narrative = narrative
	return floor


static func _ritual_tower_data(gate_id: String, ritual_tower_id: String) -> Dictionary:
	var candidates: Array[String] = []
	if gate_id == "fool_8_to_7":
		candidates.append(PAPER_BLADE_TOWER_DATA)
	if ritual_tower_id != "":
		candidates.append("%s%s.json" % [RITUAL_TOWER_DIR, ritual_tower_id])
	for path in candidates:
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				return parsed
	return {}


static func _ritual_block_reason(gate_id: String, game_state) -> String:
	if _in_cooldown(gate_id, game_state):
		return "promotion_cooldown"
	if gate_id == "fool_8_to_7" and _paper_blade_kill_count(game_state) <= 0:
		return "paper_blade_kill_required"
	return ""


static func _in_cooldown(gate_id: String, game_state) -> bool:
	var until_day := _state_int(game_state, "promotion_cooldown_until_day", 0)
	if until_day <= 0:
		return false
	var cooldown_gate := _state_string(game_state, "promotion_cooldown_gate_id", "")
	if cooldown_gate != "" and cooldown_gate != gate_id:
		return false
	return _state_int(game_state, "day", 1) < until_day


static func _paper_blade_kill_count(game_state) -> int:
	if game_state == null:
		return 0
	if not (game_state is Dictionary) and game_state.has_method("has_paper_blade_kill"):
		return 1 if game_state.has_paper_blade_kill() else 0
	return _state_int(game_state, "paper_blade_kill_count", 0)


static func _state_int(game_state, key: String, default_value: int) -> int:
	if game_state == null:
		return default_value
	if game_state is Dictionary:
		return int(game_state.get(key, default_value))
	var value = game_state.get(key)
	if value == null:
		return default_value
	return int(value)


static func _state_string(game_state, key: String, default_value: String) -> String:
	if game_state == null:
		return default_value
	if game_state is Dictionary:
		return str(game_state.get(key, default_value))
	var value = game_state.get(key)
	if value == null:
		return default_value
	return str(value)


static func _tower_int(tower, key: String, default_value: int) -> int:
	if tower == null:
		return default_value
	var value = tower.get(key)
	if value == null:
		return default_value
	return int(value)


static func _tower_string(tower, key: String, default_value: String) -> String:
	if tower == null:
		return default_value
	var value = tower.get(key)
	if value == null:
		return default_value
	return str(value)


static func _call_ai_gm(ctx, service = null) -> String:
	if not bool(ctx.validate().get("valid", false)):
		return ""
	var resolved_service = service
	if resolved_service == null:
		resolved_service = AIGMServiceScript.new()
	if resolved_service == null or not resolved_service.has_method("call_ai_gm"):
		return ""
	return str(resolved_service.call_ai_gm(ctx))


static func _ai_gm_player_state(game_state) -> Dictionary:
	return {
		"sequence": _state_int(game_state, "sequence", 9),
		"pollution": _state_int(game_state, "pollution", 0),
		"pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"cycle": _state_int(game_state, "cycle", 1),
		"day": _state_int(game_state, "day", 1),
		"time_of_day": _state_string(game_state, "time_of_day", "morning"),
	}


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _pollution_stage(value: int) -> int:
	if value >= 100:
		return 5
	if value >= 95:
		return 4
	if value >= 80:
		return 3
	if value >= 50:
		return 2
	if value >= 30:
		return 1
	return 0


static func _tower_name(gate_id: String) -> String:
	match gate_id:
		"fool_8_to_7":
			return "纸刃仪式塔"
		_:
			return "内省塔"
