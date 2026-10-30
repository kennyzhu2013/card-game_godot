class_name Encounter
extends RefCounted

const DISTRICT_LABELS := {
	"shadow_alley": "影巷区",
	"steelworks": "铸钢区",
	"misty_port": "雾港区",
	"sacred_seven": "七圣广场",
	"stone_tower": "石塔区",
	"ascetic_mountain": "苦修山",
}

const TYPE_LABELS := {
	"flavor": "街角异闻",
	"resource": "遗落物",
	"encounter_npc": "擦肩而过",
	"npc": "擦肩而过",
	"mystery_seed": "隐线线索",
	"horror": "异兆",
	"windfall": "意外收获",
}

const LOCALIZED_COPY := {
	"enc_alley_cat": {"title": "巷尾瘦猫", "text": "巷尾一只瘦猫追着纸屑，在排水口前回头看你一眼。"},
	"enc_shadow_alley_needle_lamp": {"title": "针铺灯响", "text": "针线铺门上的小灯无风自响，像有人在暗处敲了两下。"},
	"enc_shadow_alley_rag_picker": {"title": "拾荒人的布包", "text": "拾荒人把一只扎紧的破布包留在沟边，像是故意等你看见。"},
	"enc_shadow_alley_old_li_relay": {"title": "老李的转信", "text": "一个街童替老李带来口信，只说今晚别在同一条巷子里回头。"},
	"enc_shadow_alley_morning_whistle": {"title": "清晨空哨", "text": "清晨的巡哨声从空屋顶上传来，街面却没有一个巡夜人。"},
	"enc_shadow_alley_errand_echo": {"title": "跑腿后的回声", "text": "跑腿刚结束，另一个人沿着你刚才的路线又走了一遍，步子分毫不差。"},
	"enc_steelworks_slag_buzz": {"title": "炉渣噼响", "text": "滚烫炉渣在水沟里细细作响，像被困住的虫群。"},
	"enc_steelworks_iron_shard": {"title": "冷却的铁片", "text": "一枚缺口铁片在电车轨旁冷却，边缘还带着刚出炉的暗红。"},
	"enc_steelworks_peter_furnace": {"title": "炉前的彼得", "text": "彼得在炉口前擦去手上的煤灰，开口前先看了看你身后的影子。"},
	"enc_steelworks_day_shift": {"title": "白班钟", "text": "白班钟响起，所有锤声同时停住，厂房底下却还有东西在敲。"},
	"enc_steelworks_coal_dust": {"title": "煤尘小包", "text": "一包封好的煤尘躺在破木箱下，封口压着陌生人的指印。"},
	"enc_steelworks_rail_whistle": {"title": "铁轨长哨", "text": "没有电车排班，轨道尽头却吹来一声长哨。"},
	"enc_misty_port_seabreeze": {"title": "码头海风", "text": "码头海风从雾里吹来，潮湿的盐味盖过了街边煤烟。"},
	"enc_misty_port_gull_rain": {"title": "雨中海鸥", "text": "海鸥拍打雨线，银白水痕悬在码头上方迟迟不落。"},
	"enc_misty_port_dock_fish": {"title": "码头盐包", "text": "鱼贩撞落一小包粗盐，盐粒沿着栏杆缝滚到你脚边。"},
	"enc_misty_port_xiao_ran_mist": {"title": "雾中的小染", "text": "小染的身影出现在两叠货箱之间，雾气替她遮住了半张脸。"},
	"enc_misty_port_evening_shanty": {"title": "黄昏船歌", "text": "黄昏落下时，码头工唱起一首没有终句的船歌。"},
	"enc_misty_port_casino_leave_echo": {"title": "赌窟门外的回声", "text": "你刚离开赌窟，一个醉汉便重复出你方才掷出的点数。"},
	"enc_sacred_seven_temple_bells": {"title": "七口钟", "text": "七口钟隔着教堂屋脊彼此应答，最后一声总像晚了半拍。"},
	"enc_sacred_seven_incense_ash": {"title": "净香灰", "text": "一只纸角包着干净香灰，被人放在低墙最显眼的地方。"},
	"enc_sacred_seven_brendan_temple": {"title": "布伦丹的告示", "text": "布伦丹停在公共告示牌旁，像是在等你先读完某一行。"},
	"enc_sacred_seven_evening_choir": {"title": "晚祷唱班", "text": "晚祷唱班练着低了半音的一句，烛火跟着声音轻颤。"},
	"enc_sacred_seven_prayer_tag": {"title": "折好的祈签", "text": "一枚折好的祈签压在石杯下，纸边干净得不像被人碰过。"},
	"enc_sacred_seven_stone_steps": {"title": "七级石阶", "text": "一名朝圣者反复数着同样七级台阶，数到第八时立刻从头开始。"},
	"enc_stone_tower_crest_wind": {"title": "纹章上的风", "text": "风掠过塔顶纹章，却没有碰动任何一面旗帜。"},
	"enc_stone_tower_tower_dust": {"title": "塔尘小瓶", "text": "细塔尘聚在一只裂口小瓶的封蜡里，像被刻意保存。"},
	"enc_stone_tower_marquis_eng": {"title": "英格侯爵的马车", "text": "英格侯爵的马车短暂停下，车帘后只留给你一个问题的时间。"},
	"enc_stone_tower_night_watch": {"title": "夜巡礼", "text": "夜巡卫向一扇背后没有房间的窗行礼，动作端正得近乎虔诚。"},
	"enc_stone_tower_old_relic": {"title": "旧铜徽", "text": "一枚旧铜徽卡在两块阶石之间，纹路被多年鞋底磨亮。"},
	"enc_stone_tower_echo_stairs": {"title": "回声楼梯", "text": "楼梯间先响起脚步声，随后才有人真正踏上台阶。"},
	"enc_ascetic_mountain_bitter_path": {"title": "苦叶石径", "text": "石路明明干净，脚下却响起枯苦叶被踩碎的声音。"},
	"enc_ascetic_mountain_dawn_mist": {"title": "晨雾门", "text": "黎明时分，山雾折叠成一扇门的形状，门缝只够影子通过。"},
	"enc_ascetic_mountain_herbal_water": {"title": "草药水", "text": "一只陶杯盛着草药水，静静等在山路旁的石头上。"},
	"enc_ascetic_mountain_peak_cold": {"title": "峰前寒意", "text": "山路还没转弯，峰顶的寒意已经先一步按上你的肩。"},
	"enc_ascetic_mountain_moss_roots": {"title": "苔根", "text": "干净苔根缠在裂开的祈祷石上，像刚从更深处拔出。"},
	"enc_ascetic_mountain_xuming_recluse": {"title": "许明留下的刀痕", "text": "一道新鲜刀痕指向许明常走的静路，刀口还带着湿亮的木屑。"},
	"enc_widow_child_first": {"title": "寡妇与孩子", "text": "一名寡妇拦住你，问有没有见过那个总叫错父亲的孩子。"},
	"enc_widow_child_resemble": {"title": "孩子的脸", "text": "孩子的脸短暂地像极了某个别人叮嘱你必须忘掉的人。"},
	"enc_reflection_first": {"title": "倒影先开口", "text": "暗玻璃里的倒影先开口说话，旁边真正的人却还没有动。"},
	"enc_reflection_secret": {"title": "倒影的秘密", "text": "倒影交给你一个秘密，又问秘密是否也会有主人。"},
	"enc_red_hand_first": {"title": "红手会接头", "text": "红手卡尔在炉厂告示上留下红色拇指印，像一枚无声的邀请。"},
	"enc_red_hand_proof_1": {"title": "第一份证明", "text": "红手会索要第一份证明：一个没有被神父写进册子的名字。"},
	"enc_pendulum_dialog_0": {"title": "钟摆的问题", "text": "钟摆问你，一个名字被锁进房间三十年后，是否还算活着。"},
	"enc_pendulum_dialog_1": {"title": "钟摆的旧称号", "text": "钟摆说出一个旧称号，随后观察你是否会下意识退半步。"},
}

const CHOICE_LABELS := {
	"give_food": "给它一点吃的（-1 灵石）",
	"watch": "停下观察",
	"ignore": "继续前行",
	"continue": "继续前行",
	"take": "拾起",
	"leave": "留在原处",
	"listen": "倾听",
	"nod": "点头示意",
	"wait": "等一等",
	"walk": "离开",
	"greet": "上前招呼",
	"pause": "停一停",
	"move_on": "继续走",
	"observe": "观察",
	"bow": "行礼",
	"follow": "跟上",
	"answer": "回应",
	"burn": "烧掉",
	"accept": "接下",
	"stall": "拖延",
	"approach": "靠近",
	"keep": "收下秘密",
	"deny": "否认",
	"refuse": "拒绝",
	"silence": "保持沉默",
	"remember": "记住",
	"forget": "忘掉",
	"drink": "喝一口",
	"gather": "采集",
}

var id: String = ""
var encounter_type: String = ""
var display_name: String = ""
var districts: Array[String] = []
var time_of_day: Array[String] = []
var weight: int = 10
var preconditions: Array[String] = []
var step_count: int = 1
var dialogue_tree: String = ""
var scene_payload: Dictionary = {}
var pollution_variant: Dictionary = {}
var max_per_cycle: int = -1
var cooldown_days: int = 0
var chain_id: String = ""
var chain_step: int = 0
var resolutions: Array = []


func from_dict(data: Dictionary):
	id = str(data.get("id", ""))
	encounter_type = str(data.get("encounter_type", ""))
	display_name = str(data.get("display_name", id))
	districts = _string_array(data.get("districts", []))
	time_of_day = _string_array(data.get("time_of_day", []))
	weight = int(data.get("weight", 10))
	preconditions = _string_array(data.get("preconditions", []))
	step_count = int(data.get("step_count", 1))
	dialogue_tree = str(data.get("dialogue_tree", ""))
	scene_payload = _dict(data.get("scene_payload", {}))
	pollution_variant = _dict(data.get("pollution_variant", {}))
	max_per_cycle = int(data.get("max_per_cycle", -1))
	cooldown_days = int(data.get("cooldown_days", 0))
	chain_id = str(data.get("chain_id", ""))
	chain_step = int(data.get("chain_step", 0))
	resolutions = _array(data.get("resolutions", []))
	_localize_player_copy()
	return self


func to_dict() -> Dictionary:
	return {
		"id": id,
		"encounter_type": encounter_type,
		"display_name": display_name,
		"districts": districts.duplicate(),
		"time_of_day": time_of_day.duplicate(),
		"weight": weight,
		"preconditions": preconditions.duplicate(),
		"step_count": step_count,
		"dialogue_tree": dialogue_tree,
		"scene_payload": scene_payload.duplicate(true),
		"pollution_variant": pollution_variant.duplicate(true),
		"max_per_cycle": max_per_cycle,
		"cooldown_days": cooldown_days,
		"chain_id": chain_id,
		"chain_step": chain_step,
		"resolutions": resolutions.duplicate(true),
	}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


static func _array(value: Variant) -> Array:
	if value is Array:
		return value.duplicate(true)
	return []


static func _dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}


func _localize_player_copy() -> void:
	var copy := _dict(LOCALIZED_COPY.get(id, {}))
	if copy.is_empty():
		return
	if copy.has("title"):
		display_name = str(copy.get("title", display_name))
	elif not _has_cjk(display_name):
		display_name = _fallback_title()

	if not scene_payload.is_empty():
		var text := str(scene_payload.get("text", ""))
		if copy.has("text"):
			scene_payload["text"] = str(copy.get("text", text))
		elif not _has_cjk(text):
			scene_payload["text"] = _fallback_scene_text()
		_localize_choices()
	_localize_pollution_variants()


func _localize_choices() -> void:
	var raw_choices: Variant = scene_payload.get("choices", [])
	if not raw_choices is Array:
		return
	var choices: Array = []
	for raw_choice in raw_choices:
		if not raw_choice is Dictionary:
			choices.append(raw_choice)
			continue
		var choice: Dictionary = (raw_choice as Dictionary).duplicate(true)
		var label := str(choice.get("label", ""))
		if not _has_cjk(label):
			choice["label"] = _localized_choice_label(str(choice.get("id", "")), _dict(choice.get("outcome", {})))
		choices.append(choice)
	scene_payload["choices"] = choices


func _localized_choice_label(choice_id: String, outcome: Dictionary) -> String:
	var label := str(CHOICE_LABELS.get(choice_id, "继续"))
	if outcome.has("lingstones_delta") and not label.contains("灵石"):
		var delta := int(outcome.get("lingstones_delta", 0))
		if delta != 0:
			var sign := "+" if delta > 0 else ""
			label = "%s（%s%d 灵石）" % [label, sign, delta]
	return label


func _localize_pollution_variants() -> void:
	if pollution_variant.is_empty():
		return
	var base_text := str(scene_payload.get("text", display_name))
	var variants := {}
	for raw_key in pollution_variant.keys():
		var key := str(raw_key)
		var variant := _dict(pollution_variant.get(raw_key, {}))
		var text := str(variant.get("text", ""))
		if not _has_cjk(text):
			variant["text"] = _pollution_variant_text(base_text, key)
		variants[raw_key] = variant
	pollution_variant = variants


func _pollution_variant_text(base_text: String, stage_key: String) -> String:
	match int(stage_key):
		0:
			return base_text
		1:
			return "%s 只是影子比刚才慢了一拍。" % base_text
		2:
			return "%s 空气里多了墨、铁锈和旧血混在一起的味道。" % base_text
		3:
			return "%s 你听见很近的地方叫出了你的名字。" % base_text
		_:
			return base_text


func _fallback_title() -> String:
	var district_label := ""
	if not districts.is_empty():
		district_label = str(DISTRICT_LABELS.get(districts[0], districts[0]))
	var type_label := str(TYPE_LABELS.get(encounter_type, "邂逅"))
	return "%s%s" % [district_label, type_label] if district_label != "" else type_label


func _fallback_scene_text() -> String:
	var district_label := ""
	if not districts.is_empty():
		district_label = str(DISTRICT_LABELS.get(districts[0], districts[0]))
	if district_label == "":
		district_label = "街角"
	return "%s的风声带来一段短促的插曲，你停下脚步确认它不是错觉。" % district_label


static func _has_cjk(value: String) -> bool:
	for i in range(value.length()):
		var code := value.unicode_at(i)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false
