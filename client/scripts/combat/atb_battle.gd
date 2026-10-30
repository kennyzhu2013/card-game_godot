extends Node2D

const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyLibraryScript = preload("res://scripts/combat/enemy_library.gd")
const EnemyAiScript = preload("res://scripts/combat/enemy_ai.gd")
const SkillLibraryScript = preload("res://scripts/combat/skill_library.gd")
const ElementTableScript = preload("res://scripts/combat/element_table.gd")
const SkillExecutorScript = preload("res://scripts/combat/skill_executor.gd")

const DEFAULT_SKILL_SLOTS := ["shadow_arrow", "flame_arrow", "water_touch", "inquiry_mirror"]

var player
var enemy
var turn_count: int = 0
var state: String = "running"
var enemy_defending: bool = false

var _skill_library
var _element_table
var _selected_skill
var _game_state
var _slot_skills: Array = []

signal actor_ready(actor)
signal battle_ended(result: String)

@onready var _player_atb_bar: ProgressBar = get_node_or_null("UiLayer/PlayerAtbBar")
@onready var _enemy_atb_bar: ProgressBar = get_node_or_null("UiLayer/EnemyAtbBar")
@onready var _player_hp_label: Label = get_node_or_null("UiLayer/PlayerHpLabel")
@onready var _enemy_hp_label: Label = get_node_or_null("UiLayer/EnemyHpLabel")
@onready var _skill_panel: PanelContainer = get_node_or_null("UiLayer/SkillPanel")
@onready var _skill_slots: HBoxContainer = get_node_or_null("UiLayer/SkillPanel/SkillSlots")
@onready var _qte_bar = get_node_or_null("UiLayer/QteBar")
@onready var _message_label: Label = get_node_or_null("UiLayer/MessageLabel")
@onready var _player_sprite: ColorRect = get_node_or_null("UiLayer/PlayerSprite")
@onready var _enemy_sprite: ColorRect = get_node_or_null("UiLayer/EnemySprite")


func _ready() -> void:
	_skill_library = SkillLibraryScript.new()
	_skill_library._load_all()
	_element_table = ElementTableScript.new()
	_element_table.load_table()
	if _game_state == null:
		_game_state = _resolve_game_state()
	if player == null:
		player = CombatActorScript.new()
		player.display_name = "玩家"
		player.hp = 100
		player.max_hp = 100
		player.atk = 12
		player.def = 5
		player.spd = 30
	if enemy == null:
		var enemy_library = EnemyLibraryScript.new()
		enemy = enemy_library.load_enemy("drunkard")
	_bind_skill_slots()
	_update_ui()


func _process(delta: float) -> void:
	if state != "running":
		return
	if _qte_bar != null and _qte_bar.running:
		_update_ui()
		return
	player.atb_tick(delta)
	enemy.atb_tick(delta)
	if player.ready:
		actor_ready.emit(player)
	if enemy.ready:
		actor_ready.emit(enemy)
		_perform_enemy_turn()
	_update_ui()
	_check_end()


func _input(event: InputEvent) -> void:
	if state != "running":
		return
	if _qte_bar == null or not _qte_bar.running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_resolve_player_qte()


func _check_end() -> void:
	if enemy.is_dead():
		state = "win"
		battle_ended.emit("win")
	elif player.is_dead():
		state = "lose"
		battle_ended.emit("lose")


func _update_ui() -> void:
	if _player_atb_bar != null:
		_player_atb_bar.value = player.atb
	if _enemy_atb_bar != null:
		_enemy_atb_bar.value = enemy.atb
	if _player_hp_label != null:
		_player_hp_label.text = "%s HP %d/%d" % [player.display_name, player.hp, player.max_hp]
	if _enemy_hp_label != null:
		_enemy_hp_label.text = "%s HP %d/%d" % [enemy.display_name, enemy.hp, enemy.max_hp]
	if _skill_panel != null:
		var qte_running: bool = _qte_bar != null and _qte_bar.running
		_skill_panel.visible = player.ready and state == "running" and not qte_running
	if _message_label != null and state != "running":
		_message_label.text = "战斗结束：%s" % state


func _bind_skill_slots() -> void:
	if _skill_slots == null:
		return
	_slot_skills = _game_state_slot_skills()
	if _slot_skills.is_empty():
		_slot_skills = _default_slot_skills()
	for i in range(_skill_slots.get_child_count()):
		var button := _skill_slots.get_child(i) as Button
		if button == null:
			continue
		var skill = _slot_skills[i] if i < _slot_skills.size() else null
		_bind_skill_slot_button(button, i, skill)


func _game_state_slot_skills() -> Array:
	var result: Array = []
	if _game_state == null:
		return result
	var equipped = _game_state.get("equipped_skills")
	if typeof(equipped) != TYPE_ARRAY:
		return result
	var has_equipped := false
	for i in range(DEFAULT_SKILL_SLOTS.size()):
		var skill = equipped[i] if i < equipped.size() else null
		result.append(skill)
		if skill != null:
			has_equipped = true
	return result if has_equipped else []


func _default_slot_skills() -> Array:
	var result: Array = []
	for skill_id in DEFAULT_SKILL_SLOTS:
		result.append(_skill_library.get_skill(skill_id))
	return result


func _bind_skill_slot_button(button: Button, slot_index: int, skill) -> void:
	button.disabled = skill == null
	if skill == null:
		button.text = "[空]"
		button.remove_theme_color_override("font_color")
		return
	button.text = skill.display_name
	button.add_theme_color_override("font_color", _element_color(skill.element))
	var slot_callable := _on_skill_slot_pressed.bind(slot_index)
	if not button.pressed.is_connected(slot_callable):
		button.pressed.connect(slot_callable)


func _on_skill_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_skills.size():
		return
	_select_player_skill(_slot_skills[slot_index])


func _select_player_skill(skill) -> void:
	if state != "running" or not player.ready:
		return
	_selected_skill = skill
	if _selected_skill == null:
		return
	if _qte_bar != null:
		_qte_bar.start()
	_update_message("按空格判定")
	_update_ui()


func _element_color(element: String) -> Color:
	match element:
		"影":
			return Color(0.4, 0.2, 0.6)
		"离":
			return Color(0.9, 0.4, 0.2)
		"坎":
			return Color(0.2, 0.5, 0.9)
		"灵":
			return Color(0.3, 0.8, 0.7)
		_:
			return Color.WHITE


func _on_skill_pressed(skill_id: String) -> void:
	if state != "running" or not player.ready:
		return
	_selected_skill = _skill_library.get_skill(skill_id)
	if _selected_skill == null:
		return
	if _qte_bar != null:
		_qte_bar.start()
	_update_message("按空格判定")
	_update_ui()


func _resolve_player_qte() -> void:
	var result: Dictionary = _qte_bar.resolve()
	_apply_skill_to_player(_selected_skill, float(result.get("mult", 1.0)), result.get("grade", "Bad"))
	_record_selected_skill_symbol_use()
	player.consume_atb()
	_check_end()
	_update_ui()


func _record_selected_skill_symbol_use() -> void:
	if _selected_skill == null:
		return
	var state = _game_state if _game_state != null else _resolve_game_state()
	if state == null:
		return
	for symbol_id in _selected_skill.source_symbol_ids:
		state.record_symbol_use(symbol_id, true)


func _apply_skill_to_player(skill, qte_mult: float, grade: String = "Good") -> void:
	if skill.heal > 0:
		player.hp = min(player.max_hp, player.hp + skill.heal)
		_update_message("%s 治疗 +%d" % [skill.display_name, skill.heal])
		_flash(_player_sprite, Color(0.6, 1.4, 0.6))
		return
	var damage: int = SkillExecutorScript.calculate_damage(skill, player, enemy, qte_mult, _element_table)
	if enemy_defending:
		damage = max(1, int(damage * 0.5))
		enemy_defending = false
	enemy.hp = max(0, enemy.hp - damage)
	var message := "%s %s：造成 %d 伤害" % [skill.display_name, grade, damage]
	if skill.id == "inquiry_mirror":
		message += " 揭示下回合"
	_update_message(message)
	_flash(_enemy_sprite, Color(1.4, 0.6, 0.6))


func _perform_enemy_turn() -> void:
	var action: Dictionary = EnemyAiScript.decide_action(enemy, turn_count)
	if action.get("action") == "use_skill":
		_apply_enemy_skill(action.get("skill", ""))
	elif action.get("action") == "defend":
		enemy_defending = true
		_update_message("%s 防御" % enemy.display_name)
	enemy.consume_atb()
	turn_count += 1
	_check_end()


func _apply_enemy_skill(skill_id: String) -> void:
	for skill in enemy.skills:
		if skill.get("id", "") == skill_id:
			var damage: int = max(1, int(skill.get("damage", 0)) - player.def)
			player.hp = max(0, player.hp - damage)
			_update_message("%s 使用 %s：造成 %d 伤害" % [enemy.display_name, skill.get("name", skill_id), damage])
			_flash(_player_sprite, Color(1.4, 0.6, 0.6))
			return


func _flash(rect: ColorRect, color: Color, duration := 0.15) -> void:
	if rect == null:
		return
	rect.modulate = color
	var tween := create_tween()
	tween.tween_property(rect, "modulate", Color(1, 1, 1, 1), duration)


func _update_message(text: String) -> void:
	if _message_label != null:
		_message_label.text = text


func _resolve_game_state():
	var loop := Engine.get_main_loop()
	if loop == null:
		return null
	return loop.root.get_node_or_null("GameState")
