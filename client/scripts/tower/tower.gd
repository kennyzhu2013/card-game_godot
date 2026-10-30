class_name Tower
extends RefCounted

var tower_id: String = ""
var tower_name: String = ""
var size: String = "small"
var floor_count: int = 0
var district: String = ""
var theme_modifiers: Dictionary = {}
var is_ritual_tower: bool = false
var promotion_gate_id: String = ""
var promotion_from_sequence: int = -1
var promotion_to_sequence: int = -1
var floors: Array = []
var resolution: String = "pending"


func on_floor_failed(floor_index: int, game_state) -> String:
	if floor_index < 0 or floor_index >= floors.size():
		return "invalid_floor"
	var floor = floors[floor_index]
	floor.fail_count += 1
	if floor.fail_count == 1:
		_pop_temp_card(game_state)
		_add_pollution(game_state, 5)
		return "respawn"
	floor.resolution = "collapsed"
	return on_tower_collapse(game_state)


func on_tower_collapse(game_state) -> String:
	resolution = "collapsed"
	if game_state != null:
		game_state.temp_picked_cards.clear()
		_add_pollution(game_state, 20)
	return "collapsed"


func _pop_temp_card(game_state) -> void:
	if game_state == null or game_state.temp_picked_cards.is_empty():
		return
	game_state.temp_picked_cards.pop_back()


func _add_pollution(game_state, amount: int) -> void:
	if game_state == null:
		return
	game_state.pollution += amount
	game_state.pollution_stage = _pollution_stage(game_state.pollution)


func _pollution_stage(value: int) -> int:
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
