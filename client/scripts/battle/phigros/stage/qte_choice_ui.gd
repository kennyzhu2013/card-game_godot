class_name QteChoiceUi
extends Control

signal primary_chosen(result: String)
signal secondary_chosen(result: String)

const TIMEOUT_S := 8.0
const KEY_PRIMARY_DUEL := KEY_1
const KEY_PRIMARY_EXECUTE := KEY_2
const KEY_SECONDARY_PUNISH := KEY_A
const KEY_SECONDARY_CHALLENGE := KEY_B
const VIEWPORT := Vector2(960, 540)

var current_stage: String = "idle"
var _allow_execute_branch: bool = true


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = VIEWPORT
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_execute_allowed(allowed: bool) -> void:
	_allow_execute_branch = allowed


func prompt_primary() -> String:
	current_stage = "primary"
	var label := _make_label(_primary_text())
	add_child(label)
	var tree := get_tree()
	if tree == null:
		current_stage = "idle"
		label.queue_free()
		return "DUEL"
	var picked := ""
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_S * 1000)
	while picked == "" and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if Input.is_key_pressed(KEY_PRIMARY_DUEL):
			picked = "DUEL"
		elif _allow_execute_branch and Input.is_key_pressed(KEY_PRIMARY_EXECUTE):
			picked = "EXECUTE"
	if picked == "":
		picked = "DUEL"
	label.queue_free()
	current_stage = "idle"
	primary_chosen.emit(picked)
	return picked


func prompt_secondary() -> String:
	current_stage = "secondary"
	var label := _make_label(_secondary_text())
	add_child(label)
	var tree := get_tree()
	if tree == null:
		current_stage = "idle"
		label.queue_free()
		return "EXECUTE_A"
	var picked := ""
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_S * 1000)
	while picked == "" and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if Input.is_key_pressed(KEY_SECONDARY_PUNISH):
			picked = "EXECUTE_A"
		elif Input.is_key_pressed(KEY_SECONDARY_CHALLENGE):
			picked = "EXECUTE_B"
	if picked == "":
		picked = "EXECUTE_A"
	label.queue_free()
	current_stage = "idle"
	secondary_chosen.emit(picked)
	return picked


func _primary_text() -> String:
	if _allow_execute_branch:
		return "[势满]\n[1] 决斗模式\n[2] 处决 QTE\n（8 秒后默认决斗）"
	return "[敌方势满]\n[1] 决斗反击\n（8 秒后默认决斗）"


func _secondary_text() -> String:
	return "[处决]\n[A] 惩罚对面\n[B] 挑战自己\n（8 秒后默认惩罚对面）"


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	lbl.position = Vector2(VIEWPORT.x * 0.5 - 200, VIEWPORT.y * 0.5 - 80)
	lbl.size = Vector2(400, 160)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl
