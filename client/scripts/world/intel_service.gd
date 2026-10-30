class_name IntelService
extends RefCounted

const RumorPoolLoaderScript = preload("res://scripts/world/rumor_pool_loader.gd")
const ShopServiceScript = preload("res://scripts/shop/shop_service.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const AIGMServiceScript = preload("res://scripts/ai_gm/ai_gm_service.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const GRAY_CROWN_DAILY_PATH := "res://data/rumors/gray_crown_daily.json"
const GRAY_CROWN_HEADLINE_COUNT := 3
const GRAY_CROWN_FAKE_POLLUTION_THRESHOLD := 50
const GRAY_CROWN_FAKE_CHANCE := 50
const DISTRICT_NAMES := {
	"shadow_alley": "影巷区",
	"steelworks": "铸钢区",
	"misty_port": "雾港区",
	"sacred_seven": "七圣广场",
	"stone_tower": "石塔区",
	"ascetic_mountain": "苦修山",
}
const SHOP_LABELS := {
	"donen_blackmarket": "唐恩黑市",
	"tower_merchant": "塔中商人",
}
const SHOP_FILTER_LABELS := {
	"any": "全部商品",
	"temporary_card": "临时卡",
	"material": "材料",
	"brand": "烙印",
}
const WEATHER_LABELS := {
	"sunny": "晴朗",
	"fog": "雾天",
	"storm": "暴风雨",
	"rain": "雨天",
}
const TOKEN_LABELS := {
	"alley_horror": "巷中怪影",
	"smuggler_captain": "走私船长",
	"furnace_foreman": "炉厂工头",
	"inquisitor": "审判官",
	"marquis_shade": "侯爵残影",
	"ascetic_shade": "苦修残影",
	"pendulum_boss": "钟摆首领",
	"lantern": "灯光",
	"salt": "盐",
	"paper": "纸符",
	"silence": "寂静",
	"stillness": "静止",
	"broken_rhythm": "断裂节奏",
	"cold_ash": "冷灰",
	"mirror_title": "镜中称号",
	"red_lever": "红色拉杆",
	"follow_cat": "跟随瘦猫",
	"low_tide": "退潮",
	"sealed_crate": "封缄木箱",
	"humble_exit": "谦卑离场",
	"leave_with_grace": "体面离场",
	"stop_counting": "停止计数",
	"silence_over_speed": "静默先于速度",
	"steel_factory_event": "炉厂岔路",
	"shadow_event_01": "影巷岔路",
	"tide_event": "潮汐岔路",
	"dock_crate_event": "码头木箱",
	"confession_event": "忏悔室",
	"salon_event": "贵族沙龙",
	"pendulum_event": "钟摆岔路",
	"mountain_choice": "山中岔路",
	"peter_furnace": "彼得",
	"eel_fan": "鳗鱼·凡",
	"hanna_gardener": "汉娜",
	"thomas_priest": "托马斯神父",
	"xuming_recluse": "许明",
	"shift_terms": "换班规矩",
	"named_loss": "有名有姓的败局",
	"garden_route": "花园小径",
	"plain_story": "朴素故事",
	"old_route": "旧路",
}


var daily_ai_gm_calls: Dictionary = {}
var _ai_gm_service = null


func set_ai_gm_service(service) -> void:
	_ai_gm_service = service


static func player_display_text(intel: Dictionary) -> String:
	var raw_text := str(intel.get("display_text", ""))
	var district := str(intel.get("source_district", ""))
	var district_text := str(DISTRICT_NAMES.get(district, district if district != "" else ""))
	var context_text := _intel_context_text(raw_text, district_text)
	var target: Variant = intel.get("apply_target", {})
	if target is Dictionary:
		var target_dict: Dictionary = target
		var payload: Dictionary = {}
		var raw_payload: Variant = target_dict.get("payload", {})
		if raw_payload is Dictionary:
			payload = raw_payload
		var structured := _structured_intel_text(context_text, str(target_dict.get("kind", "")), payload)
		if structured != "":
			return structured
	if _has_cjk(raw_text):
		return raw_text
	var category := str(intel.get("category", ""))
	match category:
		"tower_hint":
			return "%s有人递来一张折过三次的塔内便条。" % _district_prefix(district_text)
		"shop_offer":
			return "%s纸角写着一枚能压低黑市报价的暗码。" % _district_prefix(district_text)
		"main_story":
			return "%s有人提到一扇还没露面的门。" % _district_prefix(district_text)
		"false":
			return "%s这句话太顺了，顺得像专门留给你听。" % _district_prefix(district_text)
		_:
			return "%s你听见一段被压低的传闻。" % _district_prefix(district_text)


static func _structured_intel_text(district_text: String, kind: String, payload: Dictionary) -> String:
	var prefix := _district_prefix(district_text)
	match kind:
		"tower_intel.enemy_intent_reveal":
			return "%s进塔后第 %s 层，敌人意图会先露出一点破绽。" % [prefix, _floor_range_text(payload)]
		"tower_intel.shrine_location":
			return "%s第 %d 层有盏不该熄灭的神龛灯。" % [prefix, int(payload.get("floor_index", 0)) + 1]
		"tower_intel.event_choice_correct":
			var event_text := _token_label(str(payload.get("event_id", "事件")))
			var choice_text := _token_label(str(payload.get("correct_choice_id", "正确选项")))
			return "%s%s里，记得偏向“%s”。" % [prefix, event_text, choice_text]
		"tower_intel.boss_weakness":
			var boss_text := _token_label(str(payload.get("boss_id", "BOSS")))
			var weakness_text := _token_label(str(payload.get("weakness_tag", "弱点")))
			return "%s%s听不得“%s”这个暗号。" % [prefix, boss_text, weakness_text]
		"shop_discount.one_time":
			var shop_text := str(SHOP_LABELS.get(str(payload.get("shop_id", "")), "商店"))
			var filter_text := str(SHOP_FILTER_LABELS.get(str(payload.get("sku_filter", "any")), "指定商品"))
			return "%s拿着这张角票去%s，%s能便宜 %d%%。" % [prefix, shop_text, filter_text, int(payload.get("pct", 0))]
		"main_story_unlock.branch":
			return "%s有人漏出一条岔路，睡前或进塔前会有人再提起它。" % prefix
		"weather_forecast.next_day":
			var weather_text := str(WEATHER_LABELS.get(str(payload.get("predicted_weather_id", "")), str(payload.get("predicted_weather_id", "未知天气"))))
			return "%s烟线和潮味都指向明日：%s会先到。" % [prefix, weather_text]
		"npc_relation_boost.gift_topic":
			var npc_text := _token_label(str(payload.get("npc_id", "NPC")))
			var topic_text := _token_label(str(payload.get("topic_id", "话题")))
			return "%s跟%s开口前，先把话题绕到“%s”。" % [prefix, npc_text, topic_text]
		"false_lead.cost":
			var lingstone_cost := int(payload.get("lingstone", payload.get("lingstones_lost", 0)))
			var ap_cost := int(payload.get("ap", 0))
			var suspicion_cost := int(payload.get("suspicion", payload.get("suspicion_delta", 0)))
			return "%s这句话像饵；若照做，可能丢掉 %d 灵石、%d AP，还会多出 %d 点怀疑。" % [prefix, lingstone_cost, ap_cost, suspicion_cost]
		_:
			return ""


static func _intel_context_text(raw_text: String, district_text: String) -> String:
	if _has_cjk(raw_text):
		var subject := _cjk_subject_prefix(raw_text)
		if subject != "":
			return subject
	return district_text


static func _cjk_subject_prefix(value: String) -> String:
	var first := -1
	var stop := value.length()
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if first < 0 and _is_cjk_code(code):
			first = i
		if first >= 0 and (code == 0x7B2C or code == 0xFF0C or code == 0x002C or code == 0x3002):
			stop = i
			break
	if first < 0 or stop <= first:
		return ""
	var candidate := value.substr(first, stop - first).strip_edges()
	if candidate.length() > 18:
		return ""
	return candidate


static func _district_prefix(district_text: String) -> String:
	return "%s那边说，" % district_text if district_text != "" else ""


static func _floor_range_text(payload: Dictionary) -> String:
	var min_floor := int(payload.get("floor_index_min", payload.get("floor_index", 0))) + 1
	var max_floor := int(payload.get("floor_index_max", payload.get("floor_index", min_floor - 1))) + 1
	if min_floor == max_floor:
		return "%d" % min_floor
	return "%d-%d" % [min_floor, max_floor]


static func _token_label(token: String) -> String:
	if token == "":
		return ""
	if TOKEN_LABELS.has(token):
		return str(TOKEN_LABELS[token])
	return "相关线索"


func grant(game_state, intel_id_or_dict: Variant, overrides: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var intel := _resolve_intel(intel_id_or_dict)
	if intel.is_empty():
		return {"ok": false, "reason": "unknown_intel", "id": str(intel_id_or_dict)}
	for key in overrides.keys():
		intel[str(key)] = overrides[key]
	_normalize_intel(intel, game_state)
	var active: Array = _active_rumors(game_state)
	active.append(intel)
	game_state.set("active_rumors", active)
	_record_history(game_state, str(intel.get("id", "")))
	var result := {"ok": true, "intel": intel.duplicate(true), "active_count": active.size()}
	result["ai_gm_text"] = request_rumor_generated_ai_gm(game_state, intel)
	return result


func cleanup_expired(game_state) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var current_day := int(game_state.get("day"))
	var keep: Array = []
	var expired: Array = []
	for item in _active_rumors(game_state):
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		if _intel_still_valid(intel, current_day):
			keep.append(intel.duplicate(true))
		else:
			expired.append(str(intel.get("id", "")))
	game_state.set("active_rumors", keep)
	return {"ok": true, "expired": expired, "remaining": keep.size()}


func apply(game_state, kind: String, context: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	if kind == "shop_discount.one_time":
		return _apply_shop_discount(game_state, context)
	if kind == "tower_intel" or kind.begins_with("tower_intel."):
		return _apply_tower_intels(game_state, context, "" if kind == "tower_intel" else kind)
	if kind == "false_lead.cost":
		return apply_false_lead_cost(game_state, _dict(context.get("intel", {})), context)
	return {"ok": false, "reason": "unsupported_kind", "kind": kind}


func load_gray_crown_daily() -> Dictionary:
	if not FileAccess.file_exists(GRAY_CROWN_DAILY_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GRAY_CROWN_DAILY_PATH))
	return parsed.duplicate(true) if parsed is Dictionary else {}


func gray_crown_week_index(game_state) -> int:
	var day_value := maxi(1, _state_int(game_state, "day", 1))
	return int(floor(float(day_value - 1) / 7.0))


func current_gray_crown_daily(game_state, seed: int = 0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "headlines": []}
	var data := load_gray_crown_daily()
	if data.is_empty():
		return {"ok": false, "reason": "missing_data", "headlines": []}
	var week_index := gray_crown_week_index(game_state)
	var edition := _gray_crown_edition_for_week(data, week_index)
	if edition.is_empty():
		return {"ok": false, "reason": "missing_edition", "headlines": [], "week_index": week_index}
	var normal_headlines := _gray_crown_headline_list(_variant_array(edition.get("headlines", [])), week_index, false)
	var fake_headlines := _gray_crown_headline_list(_variant_array(edition.get("fake_headlines", [])), week_index, true)
	var is_fake := _gray_crown_should_use_fake_edition(game_state, seed, fake_headlines)
	var selected: Array = []
	if is_fake and not fake_headlines.is_empty():
		for i in range(mini(GRAY_CROWN_HEADLINE_COUNT - 1, normal_headlines.size())):
			selected.append((normal_headlines[i] as Dictionary).duplicate(true))
		selected.append(_gray_crown_pick_fake_headline(fake_headlines, seed))
	else:
		for i in range(mini(GRAY_CROWN_HEADLINE_COUNT, normal_headlines.size())):
			selected.append((normal_headlines[i] as Dictionary).duplicate(true))
	var fill_index := 0
	while selected.size() < GRAY_CROWN_HEADLINE_COUNT and fill_index < normal_headlines.size():
		var candidate: Dictionary = (normal_headlines[fill_index] as Dictionary).duplicate(true)
		if not _gray_crown_has_headline(selected, str(candidate.get("id", ""))):
			selected.append(candidate)
		fill_index += 1
	return {
		"ok": selected.size() == GRAY_CROWN_HEADLINE_COUNT,
		"reason": "" if selected.size() == GRAY_CROWN_HEADLINE_COUNT else "not_enough_headlines",
		"publication": str(data.get("publication", "灰冠日报")),
		"source_type": "newspaper",
		"source_district": str(data.get("source_district", "shadow_alley")),
		"week_index": week_index,
		"edition_id": str(edition.get("edition_id", "gray_crown_daily_week_%d" % week_index)),
		"is_fake_edition": is_fake,
		"edition_marker": str(data.get("fake_marker", "伪刊")) if is_fake else "",
		"church_marker": str(data.get("church_marker", "教会改写 / 污染走版")) if is_fake else "",
		"headlines": selected.duplicate(true),
	}


func claim_gray_crown_daily(game_state, seed: int = 0, source: String = "manual") -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "granted_intels": []}
	var current := current_gray_crown_daily(game_state, seed)
	if not bool(current.get("ok", false)):
		current["granted_intels"] = []
		current["granted_intel_ids"] = []
		return current
	var state := _gray_crown_state(game_state)
	var claimed_weeks := _dict(state.get("claimed_weeks", {}))
	var week_key := str(int(current.get("week_index", 0)))
	var already_claimed := bool(claimed_weeks.get(week_key, false))
	var granted_intels: Array = []
	var granted_ids: Array[String] = []
	if not already_claimed:
		for headline in _variant_array(current.get("headlines", [])):
			if not headline is Dictionary:
				continue
			var intel: Dictionary = (headline as Dictionary).duplicate(true)
			var intel_id := str(intel.get("id", ""))
			if _active_rumor_has_id(game_state, intel_id):
				var existing := _active_rumor_by_id(game_state, intel_id)
				if not existing.is_empty():
					granted_intels.append(existing)
					granted_ids.append(intel_id)
				continue
			var grant_result: Dictionary = grant(game_state, intel, {
				"source_type": "newspaper",
				"claim_source": source,
			})
			if bool(grant_result.get("ok", false)):
				var granted := _dict(grant_result.get("intel", {}))
				granted_intels.append(granted)
				granted_ids.append(str(granted.get("id", intel_id)))
		claimed_weeks[week_key] = true
	state["claimed_weeks"] = claimed_weeks
	state["last_week_index"] = int(current.get("week_index", 0))
	state["last_edition"] = current.duplicate(true)
	game_state.set("gray_crown_daily_state", state)
	current["already_claimed"] = already_claimed
	current["granted_intels"] = granted_intels.duplicate(true)
	current["granted_intel_ids"] = granted_ids
	return current


func auto_push_gray_crown_daily_if_due(game_state, seed: int = 0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "pushed": false, "reason": "missing_state"}
	var day_value := maxi(1, _state_int(game_state, "day", 1))
	if ((day_value - 1) % 7) != 0:
		return {"ok": true, "pushed": false, "reason": "not_monday", "week_index": gray_crown_week_index(game_state)}
	var state := _gray_crown_state(game_state)
	var auto_weeks := _dict(state.get("auto_pushed_weeks", {}))
	var week_key := str(gray_crown_week_index(game_state))
	if bool(auto_weeks.get(week_key, false)):
		return {"ok": true, "pushed": false, "reason": "already_pushed", "week_index": int(week_key)}
	var claim := claim_gray_crown_daily(game_state, seed, "auto_push")
	auto_weeks[week_key] = true
	state = _gray_crown_state(game_state)
	state["auto_pushed_weeks"] = auto_weeks
	game_state.set("gray_crown_daily_state", state)
	claim["pushed"] = bool(claim.get("ok", false))
	claim["reason"] = "" if bool(claim.get("ok", false)) else str(claim.get("reason", "claim_failed"))
	return claim


func draw_streettalker_rumor(game_state, pool_id: String, count: int = 1, seed: int = 0) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state", "intels": []}
	if _state_int(game_state, "church_awareness", 0) >= 75:
		return {
			"ok": false,
			"reason": "streettalker_hidden",
			"intels": [],
			"granted_intels": [],
			"granted_intel_ids": [],
			"granted_intel_texts": [],
			"ai_gm_texts": [],
		}
	var candidates := _streettalker_candidates(pool_id, game_state)
	if candidates.is_empty() or count <= 0:
		return {
			"ok": false,
			"reason": "no_intel_available",
			"intels": [],
			"granted_intels": [],
			"granted_intel_ids": [],
			"granted_intel_texts": [],
			"ai_gm_texts": [],
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)
	var picked := _pick_streettalker_intels(candidates, _state_int(game_state, "church_awareness", 0), maxi(1, count), rng)
	var granted_intels: Array = []
	var granted_ids: Array[String] = []
	var granted_texts: Array[String] = []
	var ai_texts: Array[String] = []
	for item in picked:
		if not item is Dictionary:
			continue
		var intel: Dictionary = (item as Dictionary).duplicate(true)
		var grant_result: Dictionary = grant(game_state, intel, {"source_type": "rumor_streettalker"})
		if not bool(grant_result.get("ok", false)):
			continue
		var granted: Dictionary = _dict(grant_result.get("intel", {}))
		granted_intels.append(granted)
		granted_ids.append(str(granted.get("id", "")))
		granted_texts.append(player_display_text(granted))
		var ai_text := str(grant_result.get("ai_gm_text", ""))
		if ai_text != "":
			ai_texts.append(ai_text)
	return {
		"ok": not granted_intels.is_empty(),
		"reason": "" if not granted_intels.is_empty() else "no_intel_granted",
		"pool_id": pool_id,
		"intels": granted_intels.duplicate(true),
		"granted_intels": granted_intels.duplicate(true),
		"granted_intel_ids": granted_ids,
		"granted_intel_texts": granted_texts,
		"ai_gm_texts": ai_texts,
	}


func apply_false_lead_cost(game_state, intel: Dictionary, context: Dictionary = {}) -> Dictionary:
	if game_state == null:
		return {"ok": false, "reason": "missing_state"}
	var cost := _false_lead_cost(intel)
	if cost.is_empty():
		return {"ok": false, "reason": "missing_false_lead_cost"}
	var lingstone_cost := maxi(0, int(cost.get("lingstone", cost.get("lingstones_lost", 0))))
	var ap_cost := maxi(0, int(cost.get("ap", 0)))
	var suspicion_delta := int(cost.get("suspicion", cost.get("suspicion_delta", 0)))
	var before_lingstones := _state_int(game_state, "lingstones", 0)
	var before_ap := _state_int(game_state, "ap", 0)
	game_state.set("lingstones", maxi(0, before_lingstones - lingstone_cost))
	if ap_cost > 0 and game_state.has_method("spend_ap"):
		game_state.call("spend_ap", ap_cost)
	else:
		game_state.set("ap", maxi(0, before_ap - ap_cost))
	var target_npc_id := str(context.get("target_npc_id", intel.get("target_npc_id", "")))
	if target_npc_id == "":
		target_npc_id = str(_dict(intel.get("false_lead", {})).get("target_npc_id", ""))
	if target_npc_id != "" and suspicion_delta != 0:
		_apply_target_suspicion(game_state, target_npc_id, suspicion_delta)
	var actual_lingstones := before_lingstones - _state_int(game_state, "lingstones", 0)
	var actual_ap := before_ap - _state_int(game_state, "ap", 0)
	_mark_intel_applied(game_state, str(intel.get("id", "")))
	return {
		"ok": true,
		"intel_id": str(intel.get("id", "")),
		"side_effects_applied": {
			"lingstone": -actual_lingstones,
			"ap": -actual_ap,
			"suspicion": suspicion_delta,
		},
		"target_npc_id": target_npc_id,
	}


func request_rumor_generated_ai_gm(game_state, intel: Dictionary) -> String:
	if str(intel.get("source_type", "")) != "rumor_streettalker":
		return ""
	var day_key := str(_state_int(game_state, "day", 1))
	if bool(daily_ai_gm_calls.get(day_key, false)):
		return ""
	daily_ai_gm_calls[day_key] = true
	var ctx = PromptContextScript.new()
	ctx.scene = "rumor_generated"
	ctx.player_state = _ai_gm_player_state(game_state)
	ctx.scene_payload = {
		"district": str(intel.get("source_district", _state_string(game_state, "current_district", ""))),
		"rumor_category": str(intel.get("category", "")),
		"truth_value": int(intel.get("truth_value", 100)),
		"current_pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"intel_id": str(intel.get("id", "")),
	}
	ctx.fallback_template_pool = "RUMOR_TEMPLATES"
	return _call_ai_gm(ctx)


func matching_tower_intel_texts(game_state, tower, include_applied: bool = true) -> Array[String]:
	var result: Array[String] = []
	if game_state == null or tower == null:
		return result
	var tower_template := _tower_template_id(tower)
	for item in _active_rumors(game_state):
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		if bool(intel.get("has_applied", false)) and not include_applied:
			continue
		var target := _dict(intel.get("apply_target", {}))
		var kind := str(target.get("kind", ""))
		if not kind.begins_with("tower_intel."):
			continue
		var payload := _dict(target.get("payload", {}))
		if not _payload_matches_tower(payload, tower, tower_template):
			continue
		var text := str(intel.get("display_text", intel.get("id", "")))
		text = player_display_text(intel)
		if text != "":
			result.append(text)
	return result


func _gray_crown_state(game_state) -> Dictionary:
	var state := _dict(game_state.get("gray_crown_daily_state"))
	if not state.get("claimed_weeks", {}) is Dictionary:
		state["claimed_weeks"] = {}
	if not state.get("auto_pushed_weeks", {}) is Dictionary:
		state["auto_pushed_weeks"] = {}
	game_state.set("gray_crown_daily_state", state)
	return state


func _gray_crown_edition_for_week(data: Dictionary, week_index: int) -> Dictionary:
	var editions := _variant_array(data.get("editions", []))
	if editions.is_empty():
		return {}
	for edition in editions:
		if edition is Dictionary and int((edition as Dictionary).get("week", -1)) == week_index:
			return (edition as Dictionary).duplicate(true)
	var wrapped_index := posmod(week_index, editions.size())
	return (editions[wrapped_index] as Dictionary).duplicate(true) if editions[wrapped_index] is Dictionary else {}


func _gray_crown_headline_list(raw_headlines: Array, week_index: int, fake: bool) -> Array:
	var result: Array = []
	var index := 0
	for item in raw_headlines:
		if not item is Dictionary:
			continue
		result.append(_gray_crown_normalize_headline(item as Dictionary, week_index, index, fake))
		index += 1
	return result


func _gray_crown_normalize_headline(headline: Dictionary, week_index: int, index: int, fake: bool) -> Dictionary:
	var result := headline.duplicate(true)
	var id_suffix := str(result.get("id", "headline_%d" % index))
	if not id_suffix.begins_with("gray_crown_daily_w%d_" % week_index):
		id_suffix = "gray_crown_daily_w%d_%s" % [week_index, id_suffix.replace("gray_crown_daily_", "")]
	result["id"] = id_suffix
	result["source_type"] = "newspaper"
	if not result.has("source_district"):
		result["source_district"] = "shadow_alley"
	result["expires_after"] = "permanent"
	if not result.has("truth_value"):
		result["truth_value"] = 0 if fake else 100
	result["is_fake_headline"] = fake
	if fake:
		result["category"] = "false"
		if not result.get("apply_target", {}) is Dictionary:
			result["apply_target"] = {"kind": "false_lead.cost", "payload": {"lingstone": 80, "ap": 1, "suspicion": 8}}
		if not result.get("false_lead", {}) is Dictionary:
			var target := _dict(result.get("apply_target", {}))
			result["false_lead"] = {"cost": _dict(target.get("payload", {}))}
	return result


func _gray_crown_should_use_fake_edition(game_state, seed: int, fake_headlines: Array) -> bool:
	if fake_headlines.is_empty():
		return false
	if _state_int(game_state, "pollution", 0) < GRAY_CROWN_FAKE_POLLUTION_THRESHOLD:
		return false
	return posmod(int(seed), 100) < GRAY_CROWN_FAKE_CHANCE


func _gray_crown_pick_fake_headline(fake_headlines: Array, seed: int) -> Dictionary:
	if fake_headlines.is_empty():
		return {}
	var index := posmod(int(seed), fake_headlines.size())
	return (fake_headlines[index] as Dictionary).duplicate(true) if fake_headlines[index] is Dictionary else {}


func _gray_crown_has_headline(headlines: Array, headline_id: String) -> bool:
	for item in headlines:
		if item is Dictionary and str((item as Dictionary).get("id", "")) == headline_id:
			return true
	return false


func _active_rumor_has_id(game_state, intel_id: String) -> bool:
	return not _active_rumor_by_id(game_state, intel_id).is_empty()


func _active_rumor_by_id(game_state, intel_id: String) -> Dictionary:
	if intel_id == "":
		return {}
	for item in _active_rumors(game_state):
		if item is Dictionary and str((item as Dictionary).get("id", "")) == intel_id:
			return (item as Dictionary).duplicate(true)
	return {}


func _streettalker_candidates(pool_id: String, game_state) -> Array:
	var pool := RumorPoolLoaderScript.new().load_pool(pool_id)
	if pool.is_empty():
		return []
	var candidates: Array = []
	for entry in _pool_entries(pool):
		if not entry is Dictionary:
			continue
		var entry_dict: Dictionary = entry
		if not _passes_rumor_filters(_dict(entry_dict.get("filters", {})), game_state):
			continue
		var intel := _intel_from_pool_entry(entry_dict)
		if not intel.is_empty():
			candidates.append(intel)
	return candidates


func _pool_entries(pool: Dictionary) -> Array:
	var value: Variant = pool.get("entries", [])
	return value.duplicate(true) if value is Array else []


func _intel_from_pool_entry(entry: Dictionary) -> Dictionary:
	var intel := entry.duplicate(true)
	intel.erase("filters")
	if str(intel.get("id", "")) == "":
		return {}
	if not intel.get("apply_target", {}) is Dictionary:
		return {}
	if not intel.has("expires_after"):
		intel["expires_after"] = "today"
	if not intel.has("truth_value"):
		intel["truth_value"] = 100
	if not intel.has("has_applied"):
		intel["has_applied"] = false
	return intel


func _passes_rumor_filters(filters: Dictionary, game_state) -> bool:
	if filters.is_empty() or game_state == null:
		return true
	if filters.has("day_min") and _state_int(game_state, "day", 1) < int(filters.get("day_min", 1)):
		return false
	if filters.has("day_max") and _state_int(game_state, "day", 1) > int(filters.get("day_max", 999)):
		return false
	if filters.has("sequence_min") and _state_int(game_state, "sequence", 9) < int(filters.get("sequence_min", 9)):
		return false
	if filters.has("sequence_max") and _state_int(game_state, "sequence", 9) > int(filters.get("sequence_max", 9)):
		return false
	if filters.has("pollution_min") and _state_int(game_state, "pollution", 0) < int(filters.get("pollution_min", 0)):
		return false
	if filters.has("pollution_max") and _state_int(game_state, "pollution", 0) > int(filters.get("pollution_max", 100)):
		return false
	if filters.has("time_of_day"):
		var allowed: Variant = filters.get("time_of_day")
		var current := _state_string(game_state, "time_of_day", "morning")
		if allowed is Array:
			var matched := false
			for item in allowed:
				if str(item) == current:
					matched = true
					break
			if not matched:
				return false
		elif str(allowed) != current:
			return false
	return true


func _pick_streettalker_intels(candidates: Array, awareness: int, count: int, rng: RandomNumberGenerator) -> Array:
	var available := _bucketed_by_truth(candidates)
	var result: Array = []
	while result.size() < count and _candidate_count(available) > 0:
		var band := _choose_truth_band(awareness, available, rng)
		if band == "":
			break
		var picked := _weighted_pick(available.get(band, []), rng)
		if picked.is_empty():
			break
		result.append(picked.duplicate(true))
		_remove_candidate(available[band], str(picked.get("id", "")))
	return result


func _bucketed_by_truth(candidates: Array) -> Dictionary:
	var buckets := {"true": [], "partial": [], "false": []}
	for item in candidates:
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		var band := _truth_band(intel)
		var bucket: Array = buckets.get(band, [])
		bucket.append(intel.duplicate(true))
		buckets[band] = bucket
	return buckets


func _choose_truth_band(awareness: int, available: Dictionary, rng: RandomNumberGenerator) -> String:
	var weights := _truth_band_weights(awareness)
	var total := 0
	for band in weights.keys():
		var bucket: Array = available.get(str(band), [])
		if bucket.is_empty():
			continue
		total += int(weights[band])
	if total <= 0:
		return ""
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for band in ["true", "partial", "false"]:
		var bucket: Array = available.get(band, [])
		if bucket.is_empty():
			continue
		cursor += int(weights.get(band, 0))
		if roll <= cursor:
			return band
	return ""


func _truth_band_weights(awareness: int) -> Dictionary:
	if awareness < 25:
		return {"true": 100, "partial": 0, "false": 0}
	if awareness < 50:
		return {"true": 50, "partial": 30, "false": 20}
	if awareness < 75:
		return {"true": 30, "partial": 30, "false": 40}
	return {}


func _weighted_pick(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for item in candidates:
		if item is Dictionary:
			total += maxi(1, int((item as Dictionary).get("weight", 1)))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for item in candidates:
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		cursor += maxi(1, int(intel.get("weight", 1)))
		if roll <= cursor:
			return intel.duplicate(true)
	return {}


func _remove_candidate(candidates: Array, intel_id: String) -> void:
	for i in range(candidates.size()):
		if str((candidates[i] as Dictionary).get("id", "")) == intel_id:
			candidates.remove_at(i)
			return


func _candidate_count(available: Dictionary) -> int:
	var total := 0
	for band in ["true", "partial", "false"]:
		var bucket: Array = available.get(band, [])
		total += bucket.size()
	return total


func _truth_band(intel: Dictionary) -> String:
	var target := _dict(intel.get("apply_target", {}))
	if str(intel.get("category", "")) == "false" or str(target.get("kind", "")) == "false_lead.cost":
		return "false"
	var truth := int(intel.get("truth_value", 100))
	if truth >= 100:
		return "true"
	if truth <= 49:
		return "false"
	return "partial"


func _false_lead_cost(intel: Dictionary) -> Dictionary:
	var false_lead := _dict(intel.get("false_lead", {}))
	var cost := _dict(false_lead.get("cost", {}))
	if not cost.is_empty():
		return cost
	var target := _dict(intel.get("apply_target", {}))
	if str(target.get("kind", "")) != "false_lead.cost":
		return {}
	var payload := _dict(target.get("payload", {}))
	if payload.is_empty():
		return {}
	return {
		"lingstone": int(payload.get("lingstone", payload.get("lingstones_lost", 0))),
		"ap": int(payload.get("ap", 0)),
		"suspicion": int(payload.get("suspicion", payload.get("suspicion_delta", 0))),
	}


func _apply_target_suspicion(game_state, npc_id: String, delta: int) -> void:
	if npc_id == "" or game_state == null:
		return
	var relations: Variant = game_state.get("npc_relations")
	if not relations is Dictionary:
		relations = {}
	var state = (relations as Dictionary).get(npc_id, null)
	if state == null:
		state = NpcKnowledgeStateScript.new()
	if state is Dictionary:
		var next_value := clampi(int((state as Dictionary).get("suspicion", 0)) + delta, 0, 100)
		(state as Dictionary)["suspicion"] = next_value
	elif state is Object:
		state.set("suspicion", clampi(int(state.get("suspicion")) + delta, 0, 100))
	(relations as Dictionary)[npc_id] = state
	game_state.set("npc_relations", relations)


func _mark_intel_applied(game_state, intel_id: String) -> void:
	if intel_id == "" or game_state == null:
		return
	var active := _active_rumors(game_state)
	for item in active:
		if item is Dictionary and str((item as Dictionary).get("id", "")) == intel_id:
			(item as Dictionary)["has_applied"] = true
	game_state.set("active_rumors", active)


func _resolve_intel(intel_id_or_dict: Variant) -> Dictionary:
	if intel_id_or_dict is Dictionary:
		return (intel_id_or_dict as Dictionary).duplicate(true)
	var intel_id := str(intel_id_or_dict)
	if intel_id == "":
		return {}
	return RumorPoolLoaderScript.new().intel_by_id(intel_id)


func _normalize_intel(intel: Dictionary, game_state) -> void:
	if not intel.has("acquired_at_day"):
		intel["acquired_at_day"] = int(game_state.get("day"))
	if not intel.has("acquired_at_time"):
		intel["acquired_at_time"] = str(game_state.get("time_of_day"))
	if not intel.has("expires_after"):
		intel["expires_after"] = "today"
	if not intel.has("has_applied"):
		intel["has_applied"] = false
	if not intel.has("truth_value"):
		intel["truth_value"] = 100
	if not intel.has("verified"):
		intel["verified"] = false


func _record_history(game_state, intel_id: String) -> void:
	if intel_id == "":
		return
	var history: Dictionary = game_state.get("heard_rumor_history")
	if not history is Dictionary:
		history = {}
	var day_key := str(int(game_state.get("day")))
	var ids: Array = history.get(day_key, []) if history.get(day_key, []) is Array else []
	if not ids.has(intel_id):
		ids.append(intel_id)
	history[day_key] = ids
	game_state.set("heard_rumor_history", history)


func _intel_still_valid(intel: Dictionary, current_day: int) -> bool:
	var acquired_day := int(intel.get("acquired_at_day", current_day))
	match str(intel.get("expires_after", "today")):
		"permanent":
			return true
		"today":
			return acquired_day >= current_day
		"next_morning":
			return acquired_day >= current_day
		"until_sleep":
			return false
		_:
			return acquired_day >= current_day


func _apply_shop_discount(game_state, context: Dictionary) -> Dictionary:
	var shop_id := str(context.get("shop_id", ""))
	var applied: Array = []
	for item in _active_rumors(game_state):
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		if bool(intel.get("has_applied", false)):
			continue
		var target := _dict(intel.get("apply_target", {}))
		if str(target.get("kind", "")) != "shop_discount.one_time":
			continue
		var payload := _dict(target.get("payload", {}))
		if shop_id != "" and str(payload.get("shop_id", "")) != shop_id:
			continue
		var result: Dictionary = ShopServiceScript.apply_discount(game_state, str(payload.get("shop_id", "")), int(payload.get("pct", 0)))
		if not bool(result.get("ok", false)):
			continue
		intel["has_applied"] = true
		applied.append(str(intel.get("id", "")))
	return {"ok": not applied.is_empty(), "applied": applied}


func _apply_tower_intels(game_state, context: Dictionary, only_kind: String = "") -> Dictionary:
	var tower = context.get("tower", null)
	if tower == null:
		return {"ok": false, "reason": "missing_tower"}
	var tower_template := _tower_template_id(tower)
	var applied: Array = []
	for item in _active_rumors(game_state):
		if not item is Dictionary:
			continue
		var intel: Dictionary = item
		if bool(intel.get("has_applied", false)):
			continue
		var target := _dict(intel.get("apply_target", {}))
		var kind := str(target.get("kind", ""))
		if not kind.begins_with("tower_intel."):
			continue
		if only_kind != "" and kind != only_kind:
			continue
		var payload := _dict(target.get("payload", {}))
		if not _payload_matches_tower(payload, tower, tower_template):
			continue
		if _apply_one_tower_intel(kind, payload, tower):
			intel["has_applied"] = true
			applied.append(str(intel.get("id", "")))
	return {"ok": not applied.is_empty(), "applied": applied}


func _apply_one_tower_intel(kind: String, payload: Dictionary, tower) -> bool:
	match kind:
		"tower_intel.enemy_intent_reveal":
			return _apply_enemy_intent(payload, tower)
		"tower_intel.shrine_location":
			return _apply_shrine_location(payload, tower)
		"tower_intel.event_choice_correct":
			return _apply_event_choice(payload, tower)
		"tower_intel.boss_weakness":
			return _apply_boss_weakness(payload, tower)
		_:
			return false


func _apply_enemy_intent(payload: Dictionary, tower) -> bool:
	var min_index := int(payload.get("floor_index_min", payload.get("floor_index", 0)))
	var max_index := int(payload.get("floor_index_max", min_index))
	var did_apply := false
	for floor in _floors(tower):
		var index := int(floor.get("floor_index"))
		if index < min_index or index > max_index:
			continue
		var data: Dictionary = floor.event_data if floor.event_data is Dictionary else {}
		data["intel_hint"] = "preview_enemies"
		floor.event_data = data
		did_apply = true
	return did_apply


func _apply_shrine_location(payload: Dictionary, tower) -> bool:
	var floor_index := int(payload.get("floor_index", -1))
	for floor in _floors(tower):
		if int(floor.get("floor_index")) != floor_index:
			continue
		floor.event_type = "shrine"
		var data: Dictionary = floor.event_data if floor.event_data is Dictionary else {}
		data["intel_hint"] = "known_shrine"
		floor.event_data = data
		return true
	return false


func _apply_event_choice(payload: Dictionary, tower) -> bool:
	var event_id := str(payload.get("event_id", ""))
	if event_id == "":
		return false
	for floor in _floors(tower):
		var data: Dictionary = floor.event_data if floor.event_data is Dictionary else {}
		if str(data.get("event_id", "")) != event_id:
			continue
		data["correct_choice_id"] = str(payload.get("correct_choice_id", ""))
		floor.event_data = data
		return true
	return false


func _apply_boss_weakness(payload: Dictionary, tower) -> bool:
	var boss_id := str(payload.get("boss_id", ""))
	for floor in _floors(tower):
		var data: Dictionary = floor.event_data if floor.event_data is Dictionary else {}
		if boss_id != "" and str(data.get("boss_id", "")) != boss_id:
			continue
		if str(floor.event_type) != "boss" and boss_id == "":
			continue
		data["weakness_revealed"] = str(payload.get("weakness_tag", ""))
		floor.event_data = data
		return true
	return false


func _payload_matches_tower(payload: Dictionary, tower, tower_template: String) -> bool:
	var expected := str(payload.get("tower_template", ""))
	if expected == "":
		return true
	return expected == tower_template or expected == str(tower.get("tower_id"))


func _tower_template_id(tower) -> String:
	if tower == null:
		return ""
	var modifiers: Variant = tower.get("theme_modifiers")
	if modifiers is Dictionary and str((modifiers as Dictionary).get("tower_template", "")) != "":
		return str((modifiers as Dictionary).get("tower_template", ""))
	return str(tower.get("tower_id"))


func _floors(tower) -> Array:
	if tower == null:
		return []
	var value: Variant = tower.get("floors")
	return value if value is Array else []


func _active_rumors(game_state) -> Array:
	var value: Variant = game_state.get("active_rumors")
	return value if value is Array else []


static func _dict(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _variant_array(value: Variant) -> Array:
	return value if value is Array else []


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


func _ai_gm_player_state(game_state) -> Dictionary:
	return {
		"sequence": _state_int(game_state, "sequence", 9),
		"pollution": _state_int(game_state, "pollution", 0),
		"pollution_stage": _state_int(game_state, "pollution_stage", 0),
		"cycle": _state_int(game_state, "cycle", 1),
		"day": _state_int(game_state, "day", 1),
		"time_of_day": _state_string(game_state, "time_of_day", "morning"),
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


static func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		if _is_cjk_code(value.unicode_at(i)):
			return true
	return false


static func _is_cjk_code(code: int) -> bool:
	return code >= 0x4E00 and code <= 0x9FFF
