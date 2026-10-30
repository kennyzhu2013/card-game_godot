extends RefCounted

const SCRIPT_PATH := "res://scripts/ui/battle/enemy_standee.gd"
const EnemyScript = preload("res://scripts/combat/enemy.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_enemy_standee.gd --")
	await test_enemy_standee_renders_portrait_intent_floater_hp_and_feet_status_strip()
	await test_enemy_standee_obscured_intent_renders_question_marks()
	await test_enemy_standee_intent_floater_anchored_above_portrait()
	await test_enemy_standee_intent_text_categorizes_attack_defend_buff_debuff()
	await test_enemy_standee_status_strip_renders_human_description_not_raw_id()
	await test_enemy_standee_tooltip_text_is_full_humanized_detail()
	return {"passed": _passed, "failed": _failed}


func test_enemy_standee_renders_portrait_intent_floater_hp_and_feet_status_strip() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var enemy = _enemy("enemy_standee_probe", "Enemy Standee Probe", 19, 44, 5)
	enemy.add_status("weak", {"duration": 2, "description": "Weak enemy detail."})
	enemy.add_status("vulnerable", {"duration": 1, "description": "Vulnerable enemy detail."})
	var intent := {
		"action": "use_skill",
		"intent_type": "attack_debuff",
		"skill_name": "Revealed Slash",
		"damage": 11,
		"target": "single",
		"revealed_by_card": true,
	}
	standee.call("bind_enemy", enemy, intent, "Revealed Slash 11 damage", false, false, false)
	await Engine.get_main_loop().process_frame
	var portrait = standee.find_child("PortraitSlot", true, false)
	var intent_floater = standee.find_child("IntentFloater", true, false)
	var hp_bar = standee.find_child("HpBar", true, false)
	var hp_text = standee.find_child("HpText", true, false)
	var def_chip = standee.find_child("DefChip", true, false)
	var status_strip = standee.find_child("StatusFeetStrip", true, false)
	assert_true(portrait is TextureRect, "EnemyStandee renders PortraitSlot")
	assert_true(intent_floater is Label and (intent_floater as Label).text.contains("Revealed Slash") and (intent_floater as Label).text.contains("11"), "EnemyStandee renders IntentFloater with intent text")
	assert_true(hp_bar is ProgressBar and int((hp_bar as ProgressBar).value) == 19 and int((hp_bar as ProgressBar).max_value) == 44, "EnemyStandee HpBar reflects HP and max_hp")
	assert_true(hp_text is Label and (hp_text as Label).text.contains("19") and (hp_text as Label).text.contains("44"), "EnemyStandee HpText reflects HP and max_hp")
	assert_true(hp_text is Label and (hp_text as Label).text.contains("生命"), "EnemyStandee HpText uses Chinese attribute text")
	assert_true(def_chip is Label and (def_chip as Label).text.contains("5"), "EnemyStandee DefChip reflects DEF")
	assert_true(def_chip is Label and (def_chip as Label).text.contains("防御"), "EnemyStandee DefChip uses Chinese attribute text")
	assert_true(status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() == 2, "EnemyStandee StatusFeetStrip renders one icon per status")
	standee.queue_free()


func test_enemy_standee_obscured_intent_renders_question_marks() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var enemy = _enemy("enemy_standee_obscured", "Enemy Standee Obscured", 20, 20, 2)
	var intent := {
		"action": "use_skill",
		"intent_type": "attack_debuff",
		"skill_name": "Hidden Killing Move",
		"damage": 99,
		"amount": 99,
		"target": "single",
		"revealed_by_card": true,
	}
	standee.call("bind_enemy", enemy, intent, "Hidden Killing Move 99 damage", true, true, false)
	await Engine.get_main_loop().process_frame
	var intent_floater = standee.find_child("IntentFloater", true, false)
	var text := (intent_floater as Label).text if intent_floater is Label else ""
	assert_true(text.begins_with("???"), "EnemyStandee obscured IntentFloater starts with question marks")
	for raw in ["use_skill", "Hidden Killing Move", "99", "attack_debuff"]:
		assert_true(not text.contains(raw), "EnemyStandee obscured intent hides raw token %s" % raw)
	standee.queue_free()


func test_enemy_standee_intent_floater_anchored_above_portrait() -> void:
	for portrait_height in [72, 132]:
		var standee = _new_standee()
		if standee == null:
			return
		standee.custom_minimum_size = Vector2(220, portrait_height + 150)
		standee.size = standee.custom_minimum_size
		var portrait = standee.find_child("PortraitSlot", true, false)
		if portrait is TextureRect:
			(portrait as TextureRect).custom_minimum_size = Vector2(0, portrait_height)
		Engine.get_main_loop().root.add_child(standee)
		var enemy = _enemy("enemy_standee_anchor_%d" % portrait_height, "Anchor Probe %d" % portrait_height, 20, 20, 1)
		standee.call("bind_enemy", enemy, {"intent_type": "attack", "damage": 8}, "", false, true, false)
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
		var intent_floater = standee.find_child("IntentFloater", true, false)
		portrait = standee.find_child("PortraitSlot", true, false)
		assert_true(intent_floater is Label and portrait is TextureRect, "EnemyStandee has IntentFloater and PortraitSlot for %dpx portrait" % portrait_height)
		if intent_floater is Label and portrait is TextureRect:
			var floater_center_y := (intent_floater as Label).get_global_rect().get_center().y
			var portrait_center_y := (portrait as TextureRect).get_global_rect().get_center().y
			assert_true(floater_center_y < portrait_center_y, "IntentFloater center stays above PortraitSlot center for %dpx portrait" % portrait_height)
		standee.queue_free()


func test_enemy_standee_intent_text_categorizes_attack_defend_buff_debuff() -> void:
	var cases := [
		[{"intent_type": "attack", "damage": 8, "hits": 2}, "意图：攻击", "8"],
		[{"action": "defend", "armor": 6}, "意图：防御", "6"],
		[{"intent_type": "self_buff", "armor": 4, "amount": 4}, "意图：强化", "4"],
		[{"intent_type": "status", "status_id": "poison", "stacks": 2, "amount": 2}, "意图：负面", "2"],
	]
	for i in range(cases.size()):
		var standee = _new_standee()
		if standee == null:
			return
		Engine.get_main_loop().root.add_child(standee)
		var enemy = _enemy("enemy_standee_intent_case_%d" % i, "Intent Case %d" % i, 20, 20, 1)
		var intent: Dictionary = cases[i][0]
		standee.call("bind_enemy", enemy, intent, "", false, true, false)
		await Engine.get_main_loop().process_frame
		var intent_floater = standee.find_child("IntentFloater", true, false)
		var text := (intent_floater as Label).text if intent_floater is Label else ""
		assert_true(text.begins_with(str(cases[i][1])), "EnemyStandee intent text uses prefix %s" % str(cases[i][1]))
		assert_true(text.contains(str(cases[i][2])), "EnemyStandee intent text includes numeric preview %s" % str(cases[i][2]))
		standee.queue_free()


func test_enemy_standee_status_strip_renders_human_description_not_raw_id() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var enemy = _enemy("enemy_human_status_probe", "Enemy Human Status Probe", 30, 30, 0)
	enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
	standee.call("bind_enemy", enemy, {"intent_type": "attack", "damage": 4}, "", false, true, false)
	await Engine.get_main_loop().process_frame
	var status_strip = standee.find_child("StatusFeetStrip", true, false)
	assert_true(status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() == 1, "EnemyStandee renders the flame_wound status icon")
	var tooltip := ""
	if status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() > 0:
		tooltip = str((status_strip as HBoxContainer).get_child(0).tooltip_text)
	assert_true(tooltip.contains("火焰伤口") and tooltip.contains("5") and tooltip.contains("2"), "EnemyStandee status tooltip uses Chinese Flame Wound copy with payload numbers")
	for raw in ["flame_wound", "magnitude", "duration 2", "duration X"]:
		assert_true(not tooltip.contains(raw), "EnemyStandee status tooltip hides raw payload token %s" % raw)
	standee.queue_free()


func test_enemy_standee_tooltip_text_is_full_humanized_detail() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var enemy = _enemy("enemy_full_tooltip_probe", "Enemy Full Tooltip Probe", 18, 36, 4)
	enemy.add_status("flame_wound", {"duration": 2, "magnitude": 5})
	enemy.add_status("bleed", {"duration": 1, "magnitude": 3})
	var intent := {
		"action": "use_skill",
		"intent_type": "attack_debuff",
		"skill_name": "Exposed Strike",
		"damage": 12,
		"target": "single",
		"revealed_by_card": true,
	}
	standee.call("bind_enemy", enemy, intent, "", false, true, false)
	await Engine.get_main_loop().process_frame
	var tooltip := str(standee.tooltip_text)
	assert_true(tooltip.contains("Enemy Full Tooltip Probe"), "EnemyStandee tooltip includes enemy name")
	assert_true(tooltip.contains("生命") and tooltip.contains("18") and tooltip.contains("36"), "EnemyStandee tooltip includes localized HP detail")
	assert_true(tooltip.contains("防御") and tooltip.contains("4"), "EnemyStandee tooltip includes localized DEF detail")
	assert_true(tooltip.contains("火焰伤口") and tooltip.contains("5") and tooltip.contains("2"), "EnemyStandee tooltip includes localized Flame Wound detail")
	assert_true(tooltip.contains("流血") and tooltip.contains("3") and tooltip.contains("1"), "EnemyStandee tooltip includes localized Bleed detail")
	assert_true(tooltip.contains("意图：") and tooltip.contains("Exposed Strike") and tooltip.contains("12"), "EnemyStandee tooltip includes current localized intent")
	for raw in ["HP", "DEF", "Intent:", "flame_wound", "bleed", "duration 2", "magnitude 5", "intent_type", "use_skill"]:
		assert_true(not tooltip.contains(raw), "EnemyStandee tooltip hides raw token %s" % raw)
	standee.queue_free()


func _new_standee():
	var script = load(SCRIPT_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "enemy_standee.gd loads and can instantiate")
		return null
	return script.new()


func _enemy(id: String, display_name: String, hp: int, max_hp: int, defense: int):
	return EnemyScript.from_json({
		"id": id,
		"display_name": display_name,
		"stats": {"hp": hp, "max_hp": max_hp, "atk": 1, "def": defense, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
