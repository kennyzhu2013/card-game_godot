extends RefCounted

const SCRIPT_PATH := "res://scripts/ui/battle/player_standee.gd"
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_player_standee.gd --")
	await test_player_standee_renders_portrait_hp_def_and_feet_status_strip()
	await test_player_standee_hover_exposes_full_status_detail_text()
	await test_player_standee_status_strip_renders_human_description_not_raw_id()
	await test_player_standee_compose_detail_text_uses_human_descriptions()
	await test_player_standee_tooltip_text_is_full_humanized_detail()
	return {"passed": _passed, "failed": _failed}


func test_player_standee_renders_portrait_hp_def_and_feet_status_strip() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var player = _player()
	standee.call("bind_player", player, "扮演契约：使用一张削弱牌", "已领悟规则：不要连续攻击")
	await Engine.get_main_loop().process_frame
	var portrait = standee.find_child("PortraitSlot", true, false)
	var hp_bar = standee.find_child("HpBar", true, false)
	var hp_text = standee.find_child("HpText", true, false)
	var def_chip = standee.find_child("DefChip", true, false)
	var status_strip = standee.find_child("StatusFeetStrip", true, false)
	assert_true(portrait is TextureRect, "PlayerStandee renders PortraitSlot")
	assert_true(hp_bar is ProgressBar and int((hp_bar as ProgressBar).value) == 37 and int((hp_bar as ProgressBar).max_value) == 55, "PlayerStandee HpBar reflects HP and max_hp")
	assert_true(hp_text is Label and (hp_text as Label).text.contains("37") and (hp_text as Label).text.contains("55"), "PlayerStandee HpText reflects HP and max_hp")
	assert_true(hp_text is Label and (hp_text as Label).text.contains("生命"), "PlayerStandee HpText uses Chinese attribute text")
	assert_true(def_chip is Label and (def_chip as Label).text.contains("6"), "PlayerStandee DefChip reflects DEF")
	assert_true(def_chip is Label and (def_chip as Label).text.contains("防御"), "PlayerStandee DefChip uses Chinese attribute text")
	assert_true(status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() == 3, "PlayerStandee StatusFeetStrip renders one icon per status")
	if status_strip is HBoxContainer:
		var ids := _status_ids(status_strip as HBoxContainer)
		assert_eq(ids, ["burn", "paper_doll_marker", "weak"], "PlayerStandee status feet are sorted by status id")
	standee.queue_free()


func test_player_standee_hover_exposes_full_status_detail_text() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var contract_text := "扮演契约：结束回合前使用一张削弱牌"
	var rules_text := "已领悟规则：削弱牌满足当前契约 / 不连续攻击"
	var player = _player()
	standee.call("bind_player", player, contract_text, rules_text)
	await Engine.get_main_loop().process_frame
	var detail := str(standee.call("compose_detail_text")) if standee.has_method("compose_detail_text") else ""
	assert_true(detail.contains("生命") and detail.contains("37") and detail.contains("55"), "PlayerStandee detail text includes localized HP")
	assert_true(detail.contains("防御") and detail.contains("6"), "PlayerStandee detail text includes localized DEF")
	for expected in ["燃烧", "纸人", "虚弱"]:
		assert_true(detail.contains(expected), "PlayerStandee detail text includes localized status %s" % expected)
	for raw in ["burn", "paper_doll_marker", "weak", "HP", "DEF", "Statuses:"]:
		assert_true(not detail.contains(raw), "PlayerStandee detail text hides code-like token %s" % raw)
	assert_true(detail.contains(contract_text), "PlayerStandee detail text includes active contract text")
	assert_true(detail.contains(rules_text), "PlayerStandee detail text includes learned rules text")
	assert_true(standee.tooltip_text == detail, "PlayerStandee tooltip_text mirrors compose_detail_text()")
	standee.queue_free()


func test_player_standee_status_strip_renders_human_description_not_raw_id() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var player = CombatActorScript.new()
	player.display_name = "Status Human Probe"
	player.hp = 30
	player.max_hp = 30
	player.add_status("flame_wound", {"duration": 2, "magnitude": 5})
	standee.call("bind_player", player, "", "")
	await Engine.get_main_loop().process_frame
	var status_strip = standee.find_child("StatusFeetStrip", true, false)
	assert_true(status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() == 1, "PlayerStandee renders the flame_wound status icon")
	var tooltip := ""
	if status_strip is HBoxContainer and (status_strip as HBoxContainer).get_child_count() > 0:
		tooltip = str((status_strip as HBoxContainer).get_child(0).tooltip_text)
	assert_true(tooltip.contains("火焰伤口") and tooltip.contains("5") and tooltip.contains("2"), "PlayerStandee status tooltip uses Chinese Flame Wound copy with payload numbers")
	for raw in ["flame_wound", "magnitude", "duration 2", "duration X"]:
		assert_true(not tooltip.contains(raw), "PlayerStandee status tooltip hides raw payload token %s" % raw)
	standee.queue_free()


func test_player_standee_compose_detail_text_uses_human_descriptions() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var player = CombatActorScript.new()
	player.display_name = "Status Detail Probe"
	player.hp = 30
	player.max_hp = 30
	player.add_status("flame_wound", {"duration": 2, "magnitude": 5})
	player.add_status("defense_break", {"duration": 1, "magnitude": 3})
	player.add_status("ward", {"duration": 3, "stacks": 2})
	standee.call("bind_player", player, "扮演契约：保持专注", "已领悟规则：不重复攻击")
	await Engine.get_main_loop().process_frame
	var detail := str(standee.call("compose_detail_text")) if standee.has_method("compose_detail_text") else ""
	for expected in ["火焰伤口", "破防", "守护"]:
		assert_true(detail.contains(expected), "PlayerStandee compose_detail_text includes human status %s" % expected)
	for raw in ["flame_wound", "defense_break", "duration 2", "magnitude 5", "duration 1", "magnitude 3", "stacks 2", "duration 2 magnitude 5 stacks 0"]:
		assert_true(not detail.contains(raw), "PlayerStandee compose_detail_text hides raw payload phrase %s" % raw)
	for line in _status_bullet_lines(detail):
		var stripped := line.strip_edges()
		assert_true(stripped.length() >= 8 and (stripped.contains("：") or stripped.contains(":")), "PlayerStandee status line reads as localized prose: %s" % stripped)
	standee.queue_free()


func test_player_standee_tooltip_text_is_full_humanized_detail() -> void:
	var standee = _new_standee()
	if standee == null:
		return
	Engine.get_main_loop().root.add_child(standee)
	var player = CombatActorScript.new()
	player.display_name = "Full Tooltip Player"
	player.hp = 24
	player.max_hp = 42
	player.def = 7
	player.add_status("flame_wound", {"duration": 2, "magnitude": 5})
	player.add_status("ward", {"duration": 3, "stacks": 2})
	var contract_text := "规则A：结束回合前使用一张削弱牌"
	var learned_rules_text := "削弱牌会满足当前契约"
	standee.call("bind_player", player, contract_text, learned_rules_text)
	await Engine.get_main_loop().process_frame
	var tooltip := str(standee.tooltip_text)
	assert_true(tooltip == str(standee.call("compose_detail_text")), "PlayerStandee tooltip_text uses compose_detail_text as the source of truth")
	assert_true(tooltip.contains("生命") and tooltip.contains("24") and tooltip.contains("42"), "PlayerStandee tooltip includes localized HP detail")
	assert_true(tooltip.contains("防御") and tooltip.contains("7"), "PlayerStandee tooltip includes localized DEF detail")
	assert_true(tooltip.contains("火焰伤口") and tooltip.contains("5") and tooltip.contains("2"), "PlayerStandee tooltip includes localized Flame Wound detail")
	assert_true(tooltip.contains("守护") and tooltip.contains("2") and tooltip.contains("3"), "PlayerStandee tooltip includes localized Ward detail")
	assert_true(tooltip.contains("扮演契约：") and tooltip.contains(contract_text), "PlayerStandee tooltip includes the localized contract section")
	assert_true(tooltip.contains("已领悟规则：") and tooltip.contains(learned_rules_text), "PlayerStandee tooltip includes the localized learned rules section")
	for raw in ["HP", "DEF", "Contract:", "Learned Rules:", "flame_wound", "duration 2", "magnitude 5", "stacks 2"]:
		assert_true(not tooltip.contains(raw), "PlayerStandee tooltip hides raw payload token %s" % raw)
	standee.queue_free()


func _new_standee():
	var script = load(SCRIPT_PATH)
	if script == null or not script.can_instantiate():
		assert_true(false, "player_standee.gd loads and can instantiate")
		return null
	return script.new()


func _player():
	var player = CombatActorScript.new()
	player.display_name = "Standee Probe Player"
	player.hp = 37
	player.max_hp = 55
	player.def = 6
	player.add_status("weak", {"duration": 2, "description": "Weak reduces outgoing attack damage."})
	player.add_status("burn", {"duration": 3, "magnitude": 4, "description": "Burn deals damage each turn."})
	player.add_status("paper_doll_marker", {"stacks": 2, "description": "Paper doll marker redirects a hit."})
	return player


func _status_ids(status_strip: HBoxContainer) -> Array[String]:
	var ids: Array[String] = []
	for child in status_strip.get_children():
		ids.append(str(child.get_meta("status_id", child.name)))
	return ids


func _status_bullet_lines(detail: String) -> Array[String]:
	var lines: Array[String] = []
	for raw_line in detail.split("\n"):
		var line := str(raw_line)
		if line.strip_edges().begins_with("- "):
			lines.append(line)
	return lines


func assert_eq(actual, expected, message: String) -> void:
	assert_true(actual == expected, "%s - expected '%s', got '%s'" % [message, str(expected), str(actual)])


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
