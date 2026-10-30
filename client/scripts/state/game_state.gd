extends Node

# Per design/2026-05-24-tower-deck-combat-redesign.md §1 + R10 §8
# 旧 ATB equipped_skills (4 槽) 保留作迁移过渡期兼容（旧测试 / 旧锻造装备入口）；
# 新增 cards_inventory（永久卡库）+ active_deck（爬塔前构筑，容量按序列联动 R07 §2）。

signal ap_changed(current_ap: int, max_ap: int)
signal day_changed(current_day: int, cycle: int)
signal pollution_stage_changed(from_stage: int, to_stage: int)

const MAX_SLOTS := 4
const MAX_ACTIVE_DECK_LEGACY := 15
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")

# === §8.1 玩家身份与序列 (R10 §8.1) ===
var character_id: String = "harvey_mors"
var pathway: String = "fool"
var sequence: int = 9
var sequence_exp: int = 0
var paper_blade_kill_count: int = 0
var last_paper_blade_kill_day: int = 0
var promotion_cooldown_until_day: int = 0
var promotion_cooldown_gate_id: String = ""

# === 旧 ATB（迁移过渡期保留） ===
var equipped_skills: Array = []
var symbol_instances: Dictionary = {}

# === §8.2 卡牌 (R10 §8.2) ===
# 卡库 cards_inventory 无容量限制 (R01 §3.1 / R07 §2)
var cards_inventory: Array = []          # Array[Card] —— 永久卡库（锻造产出，无容量限制）
var active_deck: Array[String] = []       # 爬塔前构筑的卡 id 列表（≤ get_active_deck_capacity()）
var temp_picked_cards: Array = []         # 塔内临时卡（≤ 5），塔结束清空

# === §8.3 锻造与符号 (R10 §8.3) ===
var forge_materials: Dictionary = {}
var unlocked_symbols: Array[String] = ["shadow", "radiance", "touch", "arrow", "double", "blood"]
var known_reactions: Array[String] = []
var forge_unique_reforge_used: bool = false
var pending_forge_arrangement: Dictionary = {}  # 跨场景锻造数据传递（不持久化）
var pending_reforge: Dictionary = {}  # {card_id, mode} 锻造台 → forge_scene 的重锻意向

# === §8.4 烙印 (R10 §8.4) ===
var brands_inventory: Array = []          # Array[Brand] —— 已获得未挂载烙印

# === §8.5 扮演契约 (R10 §8.5) ===
const DEFAULT_FOOL_RULES: Array[String] = [
	"永远多一个面具",
	"旁观者守则",
	"不承诺真相",
	"第一句永远是问",
	"不直呼神名",
]
var learned_rules: Array[String] = DEFAULT_FOOL_RULES.duplicate()
var active_contract: Array[String] = []   # 本周目契约（3 条，进塔时锁定）

# === §8.6 污染与失控 (R10 §8.6) ===
var pollution: int = 0
var pollution_stage: int = 0
var is_lost_control: bool = false
var lost_control_state: Dictionary = {}

# === §8.7 时间与 AP (R10 §8.7) ===
var cycle: int = 1
var day: int = 1
var time_of_day: String = "morning"       # morning / noon / evening / night
var ap: int = 12
var ap_max: int = 12
var meditation_count_today: int = 0
var last_sleep_ap_deficit: int = 0
var current_weather: String = ""          # 当日抽到的 weather_id (R19 §4.6)
var current_district: String = ""

# === §8.8 货币与材料 (R10 §8.8) ===
var lingstones: int = 10
var dao_pages: int = 0

# === §8.9 NPC 与势力 (R10 §8.9) ===
var npc_relations: Dictionary = {}        # {npc_id: NpcKnowledgeState} (R11 §6.4)
var church_awareness: int = 0             # 全局教会查觉度 0-100 (R20 §5)
var church_awareness_events: Array = []
var hub_mana: int = 5
var hub_mana_max: int = 10
var residual_identities: Array = []
var current_residual_identity: String = "harvey"
var halfmoon_trust: int = 30
var pseudo_god_contract: Dictionary = {}

# === §8.10 委托 (R10 §8.10) ===
var available_commissions: Array = []     # Array[Commission]
var accepted_commissions: Array[String] = []
var completed_commissions: Array[String] = []

# === §8.x 商店库存 (R16 §7.2) ===
# 每店一份 ShopInventory，按 day 自动刷新；序列化时存 Dictionary。
var shop_inventories: Dictionary = {}      # shop_id -> ShopInventory

# === §8.11 道典 (R10 §8.11) ===
var shop_discounts: Dictionary = {}
var activity_modifiers: Dictionary = {}

# === §8.x 邂逅 (R27 §10) ===
var encounter_chains: Dictionary = {}      # chain_id -> EncounterChainState
var last_encounter_today: Dictionary = {"global": 0, "districts": {}}

# === §8.x 城区小游戏 (R25) ===
var minigame_history: Dictionary = {}      # daily/weekly/cycle limit counters keyed by structured minigame id

# === R26 Intel / rumor state ===
var active_rumors: Array = []              # Array[Dictionary] normalized by IntelService
var heard_rumor_history: Dictionary = {}   # day string -> Array[intel_id]
var gray_crown_daily_state: Dictionary = {} # Slice 4 T10 weekly newspaper state

# === R27 encounter chain endings ===
var story_flags: Dictionary = {}

# === Slice 4 AI GM settings ===
var ai_gm_settings: Dictionary = default_ai_gm_settings()
var _ai_gm_service = null

# === Slice 3.5 field-loop state ===
var daily_field_opportunities: Dictionary = {}
var field_hook_log: Array = []
var commission_modifier_history: Dictionary = {}

var daodian: Dictionary = {
	"discovered_cards": [],
	"discovered_brands": [],
	"unique_artifacts_seen": [],
	"dao_fragments": [],
	"npc_first_met_days": {},
	"npc_milestones": [],
	"inherited_lost_control_rules": [],
}


func _ready() -> void:
	if equipped_skills.size() != MAX_SLOTS:
		equipped_skills.clear()
		for i in MAX_SLOTS:
			equipped_skills.append(null)
	_emit_ap_changed()


# === 旧 ATB API（迁移过渡期保留） ===
func equip_skill(slot: int, skill) -> void:
	if slot < 0 or slot >= MAX_SLOTS:
		return
	if equipped_skills.size() != MAX_SLOTS:
		_ready()
	equipped_skills[slot] = skill


func get_equipped_slot(slot: int):
	if slot < 0 or slot >= MAX_SLOTS:
		return null
	if equipped_skills.size() != MAX_SLOTS:
		return null
	return equipped_skills[slot]


func equipped_count() -> int:
	var n := 0
	for s in equipped_skills:
		if s != null:
			n += 1
	return n


# === 序列联动容量 (R07 §2) ===
func get_active_deck_capacity() -> int:
	match sequence:
		9: return 12
		8: return 13
		7: return 15
		6: return 17
		5: return 20
		4: return 21
		3: return 22
		2: return 23
		1: return 24
		0: return 25
		_: return 12


# === 新卡库 API ===
# 卡库无容量限制 (R01 §3.1 / R07 §2)，玩家可自由攒卡，约束改在 active_deck 容量。
func add_card(card) -> bool:
	if card == null:
		return false
	cards_inventory.append(card)
	return true


func remove_card(card_id: String) -> bool:
	for i in cards_inventory.size():
		if cards_inventory[i].id == card_id:
			cards_inventory.remove_at(i)
			active_deck.erase(card_id)
			return true
	return false


func destroy_card(card_id: String) -> bool:
	# 销毁卡牌 → floor(标准锻造成本 * quality multiplier * 0.5) (R01 §3.1 / R02 §6.1)
	var card = get_card(card_id)
	if card == null:
		return false
	var quality_multiplier := ForgeResultCalculator.material_multiplier_for_quality(int(card.quality))
	if not remove_card(card_id):
		return false
	for material_name in ForgeResultCalculator.FORGE_MATERIAL_COST:
		var base_amount := float(ForgeResultCalculator.FORGE_MATERIAL_COST[material_name])
		var refund_amount := int(floor(base_amount * quality_multiplier * 0.5))
		forge_materials[material_name] = int(forge_materials.get(material_name, 0)) + refund_amount
	return true


func get_card(card_id: String):
	for c in cards_inventory:
		if c.id == card_id:
			return c
	return null


func set_active_deck(card_ids: Array[String]) -> bool:
	if card_ids.size() > get_active_deck_capacity():
		return false
	for cid in card_ids:
		if get_card(cid) == null:
			return false
	active_deck = card_ids.duplicate()
	return true


func active_deck_cards() -> Array:
	var result: Array = []
	for cid in active_deck:
		var c = get_card(cid)
		if c != null:
			result.append(c)
	return result


func can_spend_ap(amount: int) -> bool:
	return amount <= 0 or int(ap) >= amount


func spend_ap(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_spend_ap(amount):
		return false
	ap = max(0, int(ap) - amount)
	_emit_ap_changed()
	return true


func gain_ap(amount: int) -> void:
	if amount <= 0:
		return
	ap = min(int(ap_max), int(ap) + amount)
	_emit_ap_changed()


func refill_ap_to_max() -> void:
	ap = int(ap_max)
	_emit_ap_changed()


func set_ap(value: int) -> void:
	ap = clampi(value, 0, int(ap_max))
	_emit_ap_changed()


func set_ap_max(value: int) -> void:
	ap_max = maxi(0, value)
	if int(ap) > int(ap_max):
		ap = int(ap_max)
	_emit_ap_changed()


func record_sleep_deficit(deficit: int) -> void:
	last_sleep_ap_deficit = maxi(0, deficit)


func clear_daily_action_counters() -> void:
	meditation_count_today = 0


func record_meditation_use() -> void:
	meditation_count_today += 1


func can_meditate() -> bool:
	return meditation_count_today < 3


func record_paper_blade_kill(amount: int = 1) -> void:
	var count := maxi(0, amount)
	if count <= 0:
		return
	paper_blade_kill_count += count
	last_paper_blade_kill_day = int(day)


func has_paper_blade_kill() -> bool:
	return paper_blade_kill_count > 0


func emit_day_changed() -> void:
	day_changed.emit(int(day), int(cycle))


func set_promotion_cooldown(gate_id: String, days: int) -> void:
	promotion_cooldown_gate_id = gate_id
	promotion_cooldown_until_day = int(day) + maxi(0, days)


func clear_promotion_cooldown(gate_id: String = "") -> void:
	if gate_id != "" and promotion_cooldown_gate_id != gate_id:
		return
	promotion_cooldown_gate_id = ""
	promotion_cooldown_until_day = 0


func adjust_church_awareness(delta: int, source: String = "") -> int:
	var previous := int(church_awareness)
	church_awareness = clampi(previous + int(delta), 0, 100)
	for threshold in [10, 25, 50]:
		if previous < threshold and int(church_awareness) >= threshold and not _church_threshold_recorded(threshold):
			var ai_gm_text := request_church_threshold_ai_gm(threshold, source, previous)
			church_awareness_events.append(_church_threshold_event(threshold, source, previous, ai_gm_text))
	return int(church_awareness)


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


func set_pollution(value: int, recent_actions: Array = []) -> Dictionary:
	var previous_stage := int(pollution_stage)
	pollution = clampi(value, 0, 100)
	pollution_stage = _pollution_stage(int(pollution))
	var ai_gm_text := ""
	if int(pollution_stage) != previous_stage:
		ai_gm_text = request_pollution_stage_transition_ai_gm(previous_stage, int(pollution_stage), recent_actions)
		pollution_stage_changed.emit(previous_stage, int(pollution_stage))
	var lost_payload: Dictionary = {}
	if int(pollution) >= 100:
		lost_payload = enter_lost_control(recent_actions)
	var result := {
		"pollution": int(pollution),
		"from_stage": previous_stage,
		"to_stage": int(pollution_stage),
		"ai_gm_text": ai_gm_text,
	}
	if not lost_payload.is_empty():
		result["lost_control"] = lost_payload
	return result


func enter_lost_control(recent_actions: Array = []) -> Dictionary:
	pollution = 100
	pollution_stage = 5
	if not is_lost_control or lost_control_state.is_empty():
		lost_control_state = _default_lost_control_state()
	is_lost_control = true
	lost_control_state["recent_actions"] = _string_array(recent_actions)
	return lost_control_state.duplicate(true)


func request_pollution_stage_transition_ai_gm(from_stage: int, to_stage: int, recent_actions: Array = []) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "pollution_stage_transition"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"from_stage": from_stage,
		"to_stage": to_stage,
		"recent_actions": _string_array(recent_actions),
	}
	ctx.fallback_template_pool = "POLLUTION_STAGE_TEMPLATES"
	return _call_ai_gm(ctx)


func request_church_threshold_ai_gm(threshold: int, source: String = "", previous: int = -1) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "church_threshold_%d" % threshold
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"threshold": threshold,
		"source": source,
		"previous": previous,
		"current": int(church_awareness),
		"current_district": str(current_district),
		"recent_social_actions": _recent_church_sources(),
	}
	ctx.fallback_template_pool = "CHURCH_THRESHOLD_TEMPLATES_%d" % threshold
	return _call_ai_gm(ctx)


func request_dream_ai_gm(dream_stage: int, dream: Dictionary = {}) -> String:
	var ctx = PromptContextScript.new()
	ctx.scene = "dream_pollution_stage"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"pollution_stage": clampi(dream_stage, 0, 4),
		"dream_title": str(dream.get("title", "")),
		"dream_tone": str(dream.get("tone", "")),
		"fallback_text": str(dream.get("text", "")),
		"current_weather": str(current_weather),
	}
	ctx.fallback_template_pool = "DREAM_STAGE_TEMPLATES"
	return _call_ai_gm(ctx)


func request_lost_control_narration_ai_gm(context: Dictionary = {}) -> String:
	_ensure_lost_control_state()
	var ctx = PromptContextScript.new()
	ctx.scene = "lost_control_narration"
	ctx.player_state = _ai_gm_player_state()
	ctx.scene_payload = {
		"lost_control_state": str(lost_control_state.get("state", "fool_lost_control")),
		"pathway": str(lost_control_state.get("pathway", "fool")),
		"turn_index": int(context.get("turn_index", int(lost_control_state.get("turns_elapsed", 0)) + 1)),
		"source": str(context.get("source", "lost_control")),
		"auto_card_id": str(context.get("auto_card_id", "")),
		"visual_motifs": Array(lost_control_state.get("visual_motifs", [])),
		"death_after_turns": int(lost_control_state.get("death_after_turns", 2)),
	}
	ctx.fallback_template_pool = "LOST_CONTROL_TEMPLATES"
	return _call_ai_gm(ctx)


func advance_lost_control_turn(context: Dictionary = {}) -> Dictionary:
	_ensure_lost_control_state()
	var next_turn := int(lost_control_state.get("turns_elapsed", 0)) + 1
	lost_control_state["turns_elapsed"] = next_turn
	var death_after := maxi(1, int(lost_control_state.get("death_after_turns", 2)))
	if next_turn >= death_after:
		return complete_lost_control_death(context)
	return {
		"ok": true,
		"dead": false,
		"turns_elapsed": next_turn,
		"turns_remaining": death_after - next_turn,
		"state": str(lost_control_state.get("state", "fool_lost_control")),
	}


func complete_lost_control_death(context: Dictionary = {}) -> Dictionary:
	var inherited := _lost_control_inherited_rules()
	var completed_cycle := int(cycle)
	reset()
	daodian["inherited_lost_control_rules"] = inherited.duplicate()
	learned_rules.clear()
	for rule in inherited:
		learned_rules.append(str(rule))
	active_contract.clear()
	lost_control_state.clear()
	is_lost_control = false
	return {
		"ok": true,
		"dead": true,
		"outcome": "lost_control_death",
		"completed_cycle": completed_cycle,
		"new_cycle": int(cycle),
		"source": str(context.get("source", "lost_control")),
		"death_screen": {
			"id": "lost_control_death",
			"state": "fool_lost_control",
			"visual_motifs": _lost_control_visual_motifs(),
			"inherited_rules": inherited.duplicate(),
		},
	}


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
		"sequence": int(sequence),
		"pollution": int(pollution),
		"pollution_stage": int(pollution_stage),
		"cycle": int(cycle),
		"day": int(day),
		"time_of_day": str(time_of_day),
	}


func _recent_church_sources() -> Array[String]:
	var result: Array[String] = []
	for event in church_awareness_events:
		if not event is Dictionary:
			continue
		var source := str((event as Dictionary).get("source", ""))
		if source != "":
			result.append(source)
	return result


func _ensure_lost_control_state() -> void:
	if lost_control_state.is_empty():
		lost_control_state = _default_lost_control_state()
	is_lost_control = true
	pollution = 100
	pollution_stage = 5


func _default_lost_control_state() -> Dictionary:
	return {
		"state": "fool_lost_control",
		"pathway": "fool",
		"turns_elapsed": 0,
		"death_after_turns": 2,
		"visual_motifs": _lost_control_visual_motifs(),
	}


func _lost_control_visual_motifs() -> Array[String]:
	return ["shadow_consumes_body", "split_doubles", "open_doors"] as Array[String]


func _lost_control_inherited_rules() -> Array[String]:
	var inherited: Array[String] = []
	for rule in learned_rules:
		var id := str(rule)
		if id == "" or inherited.has(id):
			continue
		inherited.append(id)
		if inherited.size() >= 5:
			return inherited
	for rule in DEFAULT_FOOL_RULES:
		var id := str(rule)
		if id != "" and not inherited.has(id):
			inherited.append(id)
		if inherited.size() >= 5:
			break
	return inherited


func _emit_ap_changed() -> void:
	ap_changed.emit(int(ap), int(ap_max))


# === 临时卡 API ===
func add_temp_card(card) -> bool:
	if temp_picked_cards.size() >= 5:
		return false
	temp_picked_cards.append(card)
	return true


func clear_temp_cards() -> void:
	temp_picked_cards.clear()


# === 通用 ===
func register_symbol_instance(inst) -> void:
	if inst == null:
		return
	symbol_instances[inst.template_id] = inst


func get_symbol_instance(template_id: String):
	return symbol_instances.get(template_id, null)


func record_symbol_use(template_id: String, in_battle: bool) -> void:
	var inst = symbol_instances.get(template_id, null)
	if inst == null:
		return
	inst.record_use(in_battle)


# === 序列化 ===
func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"pathway": pathway,
		"sequence": sequence,
		"sequence_exp": sequence_exp,
		"paper_blade_kill_count": paper_blade_kill_count,
		"last_paper_blade_kill_day": last_paper_blade_kill_day,
		"promotion_cooldown_until_day": promotion_cooldown_until_day,
		"promotion_cooldown_gate_id": promotion_cooldown_gate_id,
		"cards_inventory": _cards_to_dict_array(cards_inventory),
		"active_deck": active_deck.duplicate(),
		"temp_picked_cards": _cards_to_dict_array(temp_picked_cards),
		"forge_materials": forge_materials.duplicate(true),
		"unlocked_symbols": unlocked_symbols.duplicate(),
		"known_reactions": known_reactions.duplicate(),
		"forge_unique_reforge_used": forge_unique_reforge_used,
		"brands_inventory": _brands_to_dict_array(brands_inventory),
		"learned_rules": learned_rules.duplicate(),
		"active_contract": active_contract.duplicate(),
		"pollution": pollution,
		"pollution_stage": pollution_stage,
		"is_lost_control": is_lost_control,
		"lost_control_state": lost_control_state.duplicate(true),
		"cycle": cycle,
		"day": day,
		"time_of_day": time_of_day,
		"ap": ap,
		"ap_max": ap_max,
		"meditation_count_today": meditation_count_today,
		"last_sleep_ap_deficit": last_sleep_ap_deficit,
		"current_weather": current_weather,
		"current_district": current_district,
		"lingstones": lingstones,
		"dao_pages": dao_pages,
		"npc_relations": _npc_relations_to_dict(npc_relations),
		"church_awareness": church_awareness,
		"church_awareness_events": church_awareness_events.duplicate(true),
		"hub_mana": hub_mana,
		"hub_mana_max": hub_mana_max,
		"residual_identities": _residual_identities_to_dict_array(residual_identities),
		"current_residual_identity": current_residual_identity,
		"halfmoon_trust": halfmoon_trust,
		"pseudo_god_contract": pseudo_god_contract.duplicate(true),
		"available_commissions": available_commissions.duplicate(true),
		"accepted_commissions": accepted_commissions.duplicate(),
		"completed_commissions": completed_commissions.duplicate(),
		"daodian": daodian.duplicate(true),
		"symbol_instances": symbol_instances.duplicate(true),
		"shop_inventories": _shop_inventories_to_dict(),
		"shop_discounts": shop_discounts.duplicate(true),
		"activity_modifiers": activity_modifiers.duplicate(true),
		"encounter_chains": _encounter_chains_to_dict(encounter_chains),
		"last_encounter_today": last_encounter_today.duplicate(true),
		"minigame_history": minigame_history.duplicate(true),
		"active_rumors": active_rumors.duplicate(true),
		"heard_rumor_history": heard_rumor_history.duplicate(true),
		"gray_crown_daily_state": gray_crown_daily_state.duplicate(true),
		"story_flags": story_flags.duplicate(true),
		"ai_gm_settings": ai_gm_settings.duplicate(true),
		"daily_field_opportunities": daily_field_opportunities.duplicate(true),
		"field_hook_log": field_hook_log.duplicate(true),
		"commission_modifier_history": commission_modifier_history.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	character_id = d.get("character_id", "harvey_mors")
	pathway = d.get("pathway", "fool")
	sequence = int(d.get("sequence", 9))
	sequence_exp = int(d.get("sequence_exp", 0))
	paper_blade_kill_count = int(d.get("paper_blade_kill_count", 0))
	last_paper_blade_kill_day = int(d.get("last_paper_blade_kill_day", 0))
	promotion_cooldown_until_day = int(d.get("promotion_cooldown_until_day", 0))
	promotion_cooldown_gate_id = str(d.get("promotion_cooldown_gate_id", ""))
	cards_inventory = _cards_from_dict_array(d.get("cards_inventory", []))
	active_deck = _string_array(d.get("active_deck", []))
	temp_picked_cards = _cards_from_dict_array(d.get("temp_picked_cards", []))
	forge_materials = _dict(d.get("forge_materials", {}))
	unlocked_symbols = _string_array(d.get("unlocked_symbols", ["shadow", "radiance", "touch", "arrow", "double", "blood"]))
	known_reactions = _string_array(d.get("known_reactions", []))
	forge_unique_reforge_used = bool(d.get("forge_unique_reforge_used", false))
	brands_inventory = _brands_from_dict_array(d.get("brands_inventory", []))
	learned_rules = _string_array(d.get("learned_rules", DEFAULT_FOOL_RULES))
	active_contract = _string_array(d.get("active_contract", []))
	pollution = int(d.get("pollution", 0))
	pollution_stage = int(d.get("pollution_stage", 0))
	is_lost_control = bool(d.get("is_lost_control", false))
	lost_control_state = _dict(d.get("lost_control_state", {}))
	if is_lost_control and lost_control_state.is_empty():
		lost_control_state = _default_lost_control_state()
	cycle = int(d.get("cycle", 1))
	day = int(d.get("day", 1))
	time_of_day = d.get("time_of_day", "morning")
	ap = int(d.get("ap", 12))
	ap_max = int(d.get("ap_max", 12))
	meditation_count_today = int(d.get("meditation_count_today", 0))
	last_sleep_ap_deficit = int(d.get("last_sleep_ap_deficit", 0))
	current_weather = d.get("current_weather", "")
	current_district = d.get("current_district", "")
	lingstones = int(d.get("lingstones", 10))
	dao_pages = int(d.get("dao_pages", 0))
	npc_relations = _npc_relations_from_dict(d.get("npc_relations", {}))
	church_awareness = int(d.get("church_awareness", 0))
	church_awareness_events = _dict_array(d.get("church_awareness_events", []))
	hub_mana = int(d.get("hub_mana", 5))
	hub_mana_max = int(d.get("hub_mana_max", 10))
	residual_identities = _residual_identities_from_dict_array(d.get("residual_identities", []))
	current_residual_identity = str(d.get("current_residual_identity", "harvey"))
	halfmoon_trust = int(d.get("halfmoon_trust", 30))
	pseudo_god_contract = _dict(d.get("pseudo_god_contract", {}))
	available_commissions = d.get("available_commissions", []).duplicate(true)
	accepted_commissions = _string_array(d.get("accepted_commissions", []))
	completed_commissions = _string_array(d.get("completed_commissions", []))
	daodian = _merge_daodian(d.get("daodian", {}))
	symbol_instances = _dict(d.get("symbol_instances", {}))
	shop_inventories = _shop_inventories_from_dict(d.get("shop_inventories", {}))
	shop_discounts = _dict(d.get("shop_discounts", {}))
	activity_modifiers = _dict(d.get("activity_modifiers", {}))
	encounter_chains = _encounter_chains_from_dict(d.get("encounter_chains", {}))
	last_encounter_today = _daily_encounters_from_dict(d.get("last_encounter_today", {}))
	minigame_history = _dict(d.get("minigame_history", {}))
	active_rumors = _dict_array(d.get("active_rumors", []))
	heard_rumor_history = _dict(d.get("heard_rumor_history", {}))
	gray_crown_daily_state = _dict(d.get("gray_crown_daily_state", {}))
	story_flags = _dict(d.get("story_flags", {}))
	ai_gm_settings = _merge_ai_gm_settings(d.get("ai_gm_settings", {}))
	daily_field_opportunities = _dict(d.get("daily_field_opportunities", {}))
	field_hook_log = _dict_array(d.get("field_hook_log", []))
	commission_modifier_history = _dict(d.get("commission_modifier_history", {}))
	_ready()


func reset() -> void:
	var previous_active_contract: Array[String] = active_contract.duplicate()
	# === 账号级 (从 account.json 重新加载，不动) ===
	var account := AccountStore.load()
	daodian = _merge_daodian(account.get("daodian", {}))
	completed_commissions = _string_array(account.get("completed_commissions", []))

	# 神性卡 / 真名卡 (R10 §8.13.2) — MVP 阶段 account.json 无此字段，空数组
	var divinity_cards_raw: Array = account.get("divinity_cards", [])

	# === 角色级 (跨周目保留，不动) ===
	# character_id / pathway / sequence 不重置

	# === 周目级 (清零重建) ===
	cycle += 1
	day = 1
	time_of_day = "morning"
	ap = 12
	ap_max = 12
	meditation_count_today = 0
	last_sleep_ap_deficit = 0
	current_weather = ""
	current_district = ""
	sequence_exp = 0
	paper_blade_kill_count = 0
	last_paper_blade_kill_day = 0
	promotion_cooldown_until_day = 0
	promotion_cooldown_gate_id = ""
	pollution = 0
	pollution_stage = 0
	is_lost_control = false
	lost_control_state.clear()
	lingstones = 10
	dao_pages = 0
	church_awareness = 0
	church_awareness_events.clear()
	hub_mana = 5
	hub_mana_max = 10
	residual_identities.clear()
	current_residual_identity = "harvey"
	halfmoon_trust = 30

	# 卡牌 — 清空后合并神性卡
	cards_inventory.clear()
	for dc in divinity_cards_raw:
		if dc is Dictionary:
			cards_inventory.append(Card.from_json(dc))
	active_deck.clear()
	temp_picked_cards.clear()

	# 锻造
	forge_materials.clear()
	unlocked_symbols = ["shadow", "radiance", "touch", "arrow", "double", "blood"]
	known_reactions.clear()
	forge_unique_reforge_used = false

	# 烙印
	brands_inventory.clear()

	# 契约
	learned_rules = DEFAULT_FOOL_RULES.duplicate()
	active_contract.clear()
	for rule in previous_active_contract:
		active_contract.append(str(rule))

	# NPC & 势力
	npc_relations.clear()
	pseudo_god_contract.clear()

	# 委托 — completed_commissions 已在账号级加载
	available_commissions.clear()
	accepted_commissions.clear()

	# 商店
	shop_inventories.clear()
	shop_discounts.clear()
	activity_modifiers.clear()
	encounter_chains.clear()
	reset_daily_encounters()
	minigame_history.clear()
	active_rumors.clear()
	heard_rumor_history.clear()
	gray_crown_daily_state.clear()
	story_flags.clear()
	daily_field_opportunities.clear()
	field_hook_log.clear()
	commission_modifier_history.clear()

	# 旧 ATB
	equipped_skills.clear()
	for i in MAX_SLOTS:
		equipped_skills.append(null)
	symbol_instances.clear()


func reset_daily_encounters() -> void:
	last_encounter_today = {"global": 0, "districts": {}}


static func _default_daodian() -> Dictionary:
	return {
		"discovered_cards": [],
		"discovered_brands": [],
		"unique_artifacts_seen": [],
		"dao_fragments": [],
		"npc_first_met_days": {},
		"npc_milestones": [],
		"completed_main_story_nodes": [],
		"inherited_lost_control_rules": [],
	}


static func default_ai_gm_settings() -> Dictionary:
	return {
		"provider": "claude_haiku",
		"offline_mode": true,
		"network_enabled": false,
		"daily_call_cap": 120,
		"daily_cost_cap": 0.02,
	}


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


static func _merge_daodian(value: Variant) -> Dictionary:
	var result := _default_daodian()
	if value is Dictionary:
		for key in value.keys():
			result[key] = value[key]
	return result


static func _merge_ai_gm_settings(value: Variant) -> Dictionary:
	var result := default_ai_gm_settings()
	if value is Dictionary:
		for key in value.keys():
			if str(key) == "api_key":
				continue
			result[key] = value[key]
	result["provider"] = str(result.get("provider", "claude_haiku"))
	result["offline_mode"] = bool(result.get("offline_mode", true))
	result["network_enabled"] = bool(result.get("network_enabled", false)) and not bool(result["offline_mode"])
	result["daily_call_cap"] = maxi(0, int(result.get("daily_call_cap", 120)))
	result["daily_cost_cap"] = maxf(0.0, float(result.get("daily_cost_cap", 0.02)))
	return result


# === 序列化辅助 ===
static func _npc_relations_to_dict(relations: Dictionary) -> Dictionary:
	var result := {}
	for npc_id in relations:
		var state = relations[npc_id]
		if state != null and state.has_method("to_dict"):
			result[npc_id] = state.to_dict()
	return result


static func _npc_relations_from_dict(data: Dictionary) -> Dictionary:
	var result := {}
	for npc_id in data:
		var entry = data[npc_id]
		if entry is Dictionary:
			result[npc_id] = NpcKnowledgeState.from_dict(entry)
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


static func _dict_array(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for item in value:
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


static func _encounter_chains_to_dict(chains: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for chain_id in chains:
		var state = chains[chain_id]
		if state != null and state.has_method("to_dict"):
			result[chain_id] = state.to_dict()
	return result


static func _encounter_chains_from_dict(data: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not data is Dictionary:
		return result
	var EncounterChainStateClass = load("res://scripts/world/encounter_chain_state.gd")
	for chain_id in data:
		var entry = data[chain_id]
		if entry is Dictionary:
			result[chain_id] = EncounterChainStateClass.new().from_dict(entry)
	return result


static func _daily_encounters_from_dict(data: Variant) -> Dictionary:
	var result := {"global": 0, "districts": {}}
	if not data is Dictionary:
		return result
	result["global"] = int(data.get("global", 0))
	var districts = data.get("districts", {})
	if districts is Dictionary:
		result["districts"] = districts.duplicate(true)
	return result


static func _cards_to_dict_array(cards: Array) -> Array:
	var result: Array = []
	for c in cards:
		if c != null and c.has_method("to_dict"):
			result.append(c.to_dict())
	return result


static func _cards_from_dict_array(data: Array) -> Array:
	var CardClass = load("res://scripts/combat/card.gd")
	var result: Array = []
	for item in data:
		if item is Dictionary:
			result.append(CardClass.from_json(item))
	return result


func _church_threshold_recorded(threshold: int) -> bool:
	for event in church_awareness_events:
		if event is Dictionary and int((event as Dictionary).get("threshold", -1)) == threshold:
			return true
	return false


func _church_threshold_event(threshold: int, source: String, previous: int, ai_gm_text: String) -> Dictionary:
	var event := {
		"threshold": threshold,
		"event_id": _church_threshold_event_id(threshold),
		"source": source,
		"day": int(day),
		"previous": previous,
		"current": int(church_awareness),
		"ai_gm_text": ai_gm_text,
	}
	match threshold:
		10:
			_mark_church_story_flag("church_threshold_10_event", "church_investigator_visit")
			if has_method("set_meta"):
				set_meta("church_investigator_visit_pending", true)
		25:
			_record_church_mainline_node("node_4_early_church_investigation")
			_mark_church_story_flag("church_threshold_25_event", "mainline_node_4_early")
			_mark_church_story_flag("church_threshold_25_source", source)
			if has_method("set_meta"):
				set_meta("church_threshold_25_mainline_pending", true)
				set_meta("church_threshold_25_mainline_node_id", "node_4")
			event["mainline_node_id"] = "node_4"
			event["mainline_node_trigger"] = "node_4_early_church_investigation"
			event["pollution_result"] = _apply_church_threshold_pollution(source)
		50:
			_mark_church_story_flag("church_threshold_50_event", "church_purge_boss_eve")
			_mark_church_story_flag("church_threshold_50_source", source)
			if has_method("set_meta"):
				set_meta("church_boss_eve_pending", true)
				set_meta("church_boss_event_id", "church_purge_boss_eve")
			event["boss_event_id"] = "church_purge_boss_eve"
	return event


func _church_threshold_event_id(threshold: int) -> String:
	match threshold:
		10:
			return "church_investigator_visit"
		25:
			return "bishop_victor_direct_investigation"
		50:
			return "church_purge_boss_eve"
		_:
			return "church_threshold_%d" % threshold


func _apply_church_threshold_pollution(source: String) -> Dictionary:
	var next_pollution := clampi(int(pollution) + 30, 0, 100)
	if has_method("set_pollution"):
		return set_pollution(next_pollution, ["church_threshold_25", source])
	pollution = next_pollution
	pollution_stage = _pollution_stage(int(pollution))
	return {"pollution": int(pollution), "to_stage": int(pollution_stage)}


func _record_church_mainline_node(node_id: String) -> void:
	if node_id == "":
		return
	var completed: Array = []
	var raw: Variant = daodian.get("completed_main_story_nodes", [])
	if raw is Array:
		for item in raw:
			completed.append(str(item))
	for value in _church_mainline_aliases(node_id):
		if value != "" and not value in completed:
			completed.append(value)
	daodian["completed_main_story_nodes"] = completed


func _church_mainline_aliases(node_id: String) -> Array[String]:
	var result: Array[String] = [node_id]
	var parts := node_id.split("_", false)
	if parts.size() >= 2 and str(parts[0]) == "node":
		var generic_id := "%s_%s" % [str(parts[0]), str(parts[1])]
		if not generic_id in result:
			result.append(generic_id)
	return result


func _mark_church_story_flag(key: String, value: Variant) -> void:
	var flags := story_flags.duplicate(true)
	flags[key] = value
	story_flags = flags


static func _residual_identities_to_dict_array(identities: Array) -> Array:
	var result: Array = []
	for identity in identities:
		if identity != null and identity.has_method("to_dict"):
			result.append(identity.to_dict())
		elif identity is Dictionary:
			result.append((identity as Dictionary).duplicate(true))
	return result


static func _residual_identities_from_dict_array(data: Variant) -> Array:
	var result: Array = []
	if not data is Array:
		return result
	var ResidualIdentityClass = load("res://scripts/world/residual_identity.gd")
	for item in data:
		if item is Dictionary:
			result.append(ResidualIdentityClass.from_dict(item))
	return result


static func _brands_to_dict_array(brands: Array) -> Array:
	var result: Array = []
	for b in brands:
		if b != null and b.has_method("to_dict"):
			result.append(b.to_dict())
	return result


static func _brands_from_dict_array(data: Array) -> Array:
	var BrandClass = load("res://scripts/combat/brand.gd")
	var result: Array = []
	for item in data:
		if item is Dictionary:
			result.append(BrandClass.from_dict(item))
	return result


func _shop_inventories_to_dict() -> Dictionary:
	var result: Dictionary = {}
	for shop_id in shop_inventories:
		var inv = shop_inventories[shop_id]
		if inv != null and inv.has_method("to_dict"):
			result[shop_id] = inv.to_dict()
	return result


static func _shop_inventories_from_dict(data) -> Dictionary:
	var result: Dictionary = {}
	if not data is Dictionary:
		return result
	var ShopInventoryClass = load("res://scripts/shop/shop_inventory.gd")
	for shop_id in data:
		var entry = data[shop_id]
		if entry is Dictionary:
			result[shop_id] = ShopInventoryClass.from_dict(entry)
	return result
