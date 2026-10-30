extends RefCounted

const EnemyStageSlotScript = preload("res://scripts/ui/battle/enemy_stage_slot.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const BattleSceneScript = preload("res://scripts/ui/battle_scene.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_enemy_stage_slot.gd --")
	await test_enemy_stage_slot_renders_hp_def_status_and_intent()
	await test_enemy_stage_handles_obscured_intent_without_raw_payload()
	return {"passed": _passed, "failed": _failed}


func test_enemy_stage_slot_renders_hp_def_status_and_intent() -> void:
	var slot = EnemyStageSlotScript.new()
	Engine.get_main_loop().root.add_child(slot)
	var enemy = _enemy("enemy_stage_slot_probe", "Enemy Stage Slot Probe", 18, 30, 4)
	enemy.add_status("weak", {"duration": 2})
	var intent := {
		"action": "use_skill",
		"intent_type": "attack_debuff",
		"skill_name": "Revealed Slash",
		"damage": 9,
		"target": "single",
		"status_effects": [{"id": "fear", "duration": 1}],
		"revealed_by_card": true,
	}
	var helper = BattleSceneScript.new()
	var intent_text := str(helper.call("_intent_text", intent, enemy))
	slot.bind_enemy(enemy, intent_text, "Status: weak 2", 4, false, "Pick target", intent, false, false)
	await Engine.get_main_loop().process_frame
	for node_name in ["EnemyNameLabel", "EnemyHpBar", "EnemyDefLabel", "EnemyStatusRow", "IntentBadge", "TargetButton"]:
		var node = slot.find_child(node_name, true, false)
		assert_true(node is Control, "%s exists on EnemyStageSlot" % node_name)
		if node is Control:
			assert_true((node as Control).visible, "%s is visible on EnemyStageSlot" % node_name)
	var name_label = slot.find_child("EnemyNameLabel", true, false)
	var hp_bar = slot.find_child("EnemyHpBar", true, false)
	var def_label = slot.find_child("EnemyDefLabel", true, false)
	var status_text = slot.find_child("EnemyStatusTextLabel", true, false)
	var intent_badge = slot.find_child("IntentBadge", true, false)
	var target_button = slot.find_child("TargetButton", true, false)
	assert_true(name_label is Label and (name_label as Label).text.contains("Enemy Stage Slot Probe"), "EnemyStageSlot renders enemy name")
	assert_true(hp_bar is ProgressBar and int((hp_bar as ProgressBar).value) == 18 and int((hp_bar as ProgressBar).max_value) == 30, "EnemyStageSlot renders HP bar values")
	assert_true(def_label is Label and (def_label as Label).text.contains("4"), "EnemyStageSlot renders defense")
	assert_true(status_text is Label and (status_text as Label).text.contains("weak"), "EnemyStageSlot renders statuses")
	assert_true(intent_badge is Label and (intent_badge as Label).text.contains("9"), "EnemyStageSlot renders revealed damage preview")
	assert_true(target_button is Button and not (target_button as Button).disabled, "EnemyStageSlot keeps target button actionable")
	slot.queue_free()


func test_enemy_stage_handles_obscured_intent_without_raw_payload() -> void:
	var slot = EnemyStageSlotScript.new()
	Engine.get_main_loop().root.add_child(slot)
	var enemy = _enemy("enemy_stage_obscured_probe", "Obscured Intent Probe", 22, 22, 1)
	enemy.add_status("obscure_intent", {"duration": 1})
	var intent := {
		"action": "use_skill",
		"intent_type": "attack_debuff",
		"skill": "raw_hidden_skill_id",
		"skill_name": "Hidden Killing Move",
		"damage": 99,
		"target": "single",
		"status_effects": [{"id": "raw_hidden_status", "duration": 3}],
		"revealed_by_card": true,
	}
	slot.bind_enemy(enemy, "意图：被遮蔽", "Status: obscure", 1, true, "Locked", intent, true, false)
	await Engine.get_main_loop().process_frame
	var text := _collect_label_text(slot)
	assert_true(text.contains("???") or text.contains("遮蔽"), "EnemyStageSlot says intent is obscured")
	for raw in ["raw_hidden_skill_id", "Hidden Killing Move", "raw_hidden_status", "attack_debuff", "damage", "status_effects", "{", "}"]:
		assert_true(not text.contains(raw), "obscured EnemyStageSlot hides raw intent payload token %s" % raw)
	slot.queue_free()


func _enemy(id: String, display_name: String, hp: int, max_hp: int, defense: int):
	return EnemyScript.from_json({
		"id": id,
		"display_name": display_name,
		"stats": {"hp": hp, "max_hp": max_hp, "atk": 1, "def": defense, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func _collect_label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)
