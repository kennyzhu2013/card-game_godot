extends SceneTree

const BgmScript = preload("res://scripts/audio/bgm_player.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const BATTLE_SCENE_SCRIPT_PATH := "res://scripts/ui/battle_scene.gd"
const CARD_SCRIPT_PATH := "res://scripts/combat/card.gd"
const ENEMY_SCRIPT_PATH := "res://scripts/combat/enemy.gd"


func _init() -> void:
	await process_frame
	var bgm := await _ensure_bgm()
	await _smoke_hub_enter(bgm)
	await _smoke_battle_enter(bgm)
	await _smoke_city_district_switch(bgm)
	quit(0)


func _ensure_bgm() -> Node:
	var node := root.get_node_or_null("Bgm")
	if node == null:
		node = BgmScript.new()
		node.name = "Bgm"
		root.add_child(node)
		await process_frame
	return node


func _smoke_hub_enter(bgm: Node) -> void:
	var packed := load("res://scenes/hub/hub.tscn")
	var hub = packed.instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	print("SMOKE hub_enter current=%s expected=hub_sanctuary" % str(bgm.call("current_track")))
	hub.queue_free()
	await process_frame


func _smoke_battle_enter(bgm: Node) -> void:
	var battle_scene_script = load(BATTLE_SCENE_SCRIPT_PATH)
	var scene = battle_scene_script.new()
	scene.size = Vector2(1280, 720)
	root.add_child(scene)
	await process_frame
	scene.start_battle([_card("bgm_smoke_card")], [], [_enemy("bgm_smoke_enemy")], [] as Array[String], null, _state(), {})
	await process_frame
	print("SMOKE battle_enter current=%s expected=tower_combat" % str(bgm.call("current_track")))
	scene.queue_free()
	await process_frame


func _smoke_city_district_switch(bgm: Node) -> void:
	var packed := load("res://scenes/world/city_scene.tscn")
	var city = packed.instantiate()
	root.add_child(city)
	await process_frame
	var gs = _state()
	gs.time_of_day = "morning"
	city.open_district("misty_port", gs)
	await process_frame
	print("SMOKE city_misty_port current=%s expected=foghorn_harbor" % str(bgm.call("current_track")))
	city.queue_free()
	await process_frame


func _card(id: String):
	var card_script = load(CARD_SCRIPT_PATH)
	return card_script.from_json({
		"id": id,
		"template_id": id,
		"display_name": id,
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 0,
		"combat_effect": {
			"damage": 6,
			"heal": 0,
			"target": "single",
			"range": 1,
			"status_effects": [],
		},
		"tags": ["attack"],
	})


func _enemy(id: String):
	var enemy_script = load(ENEMY_SCRIPT_PATH)
	return enemy_script.from_json({
		"id": id,
		"display_name": id,
		"stats": {"hp": 30, "max_hp": 30, "atk": 1, "def": 0, "spd": 1},
		"skills": [],
		"ai_pattern": [{"condition": "default", "action": "defend"}],
	})


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs
