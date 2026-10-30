extends RefCounted

const BattleSceneScript = preload("res://scripts/ui/battle_scene.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_battle_scene_tower_background.gd --")
	await test_tower_context_mounts_shadow_alley_evening_background()
	await test_default_battle_context_keeps_arena_background_blank()
	await test_unavailable_tower_background_does_not_crash_or_mount_texture()
	await test_tower_background_stays_below_existing_arena_layers()
	return {"passed": _passed, "failed": _failed}


func test_tower_context_mounts_shadow_alley_evening_background() -> void:
	var scene := await _battle_scene()
	if scene == null:
		return
	_start_battle_with_optional_context(scene, {"tower_district": "shadow_alley", "time_of_day": "evening"})
	await Engine.get_main_loop().process_frame
	var background := _find_control(scene, "BattleArenaBackground")
	assert_true(background is TextureRect, "tower battle context creates BattleArenaBackground TextureRect")
	if background is TextureRect:
		assert_true((background as TextureRect).texture is Texture2D, "BattleArenaBackground receives a tower texture")
		assert_true(str((background as TextureRect).texture.resource_path).find("tower_shadow_alley_evening.png") >= 0, "BattleArenaBackground uses tower_shadow_alley_evening.png")
	scene.queue_free()


func test_default_battle_context_keeps_arena_background_blank() -> void:
	var scene := await _battle_scene()
	if scene == null:
		return
	scene.call("start_battle", [_card("default_context_card")], [], [_enemy("default_context_enemy")], [] as Array[String], null, _state())
	await Engine.get_main_loop().process_frame
	var background := _find_control(scene, "BattleArenaBackground")
	assert_true(background == null, "default BattleScene start_battle call keeps arena background blank for debug-panel compatibility")
	scene.queue_free()


func test_unavailable_tower_background_does_not_crash_or_mount_texture() -> void:
	var scene := await _battle_scene()
	if scene == null:
		return
	_start_battle_with_optional_context(scene, {"tower_district": "sacred_seven", "time_of_day": "morning"})
	await Engine.get_main_loop().process_frame
	var background := _find_control(scene, "BattleArenaBackground")
	assert_true(background == null or (background is TextureRect and (background as TextureRect).texture == null), "unavailable tower background leaves the arena without a texture")
	scene.queue_free()


func test_tower_background_stays_below_existing_arena_layers() -> void:
	var scene := await _battle_scene()
	if scene == null:
		return
	_start_battle_with_optional_context(scene, {"tower_district": "shadow_alley", "time_of_day": "morning"})
	await Engine.get_main_loop().process_frame
	var background := _find_control(scene, "BattleArenaBackground")
	var layer := _find_control(scene, "BattleArenaLayerStack")
	var surface := _find_control(scene, "BattleAoeDropSurface")
	var arena_root := _find_control(scene, "BattleArenaRoot")
	assert_true(background is TextureRect, "tower background exists for layering checks")
	assert_true(layer != null and surface != null and arena_root != null, "existing arena layer, drop surface, and BattleArenaRoot still exist")
	if background is TextureRect and layer != null and surface != null and arena_root != null:
		var bg := background as TextureRect
		assert_true(bg.get_parent() == layer, "BattleArenaBackground is parented to BattleArenaLayerStack")
		assert_true(surface.get_parent() == layer and arena_root.get_parent() == layer, "existing AOE surface and BattleArenaRoot remain in the arena layer stack")
		assert_true(bg.get_index() < surface.get_index() and bg.get_index() < arena_root.get_index(), "BattleArenaBackground is the first arena layer so it renders below drop routing and BattleArenaRoot")
		assert_true(surface.get_index() < arena_root.get_index(), "existing AOE surface still stays below BattleArenaRoot in child order")
		assert_true(layer.z_index + bg.z_index > 0, "BattleArenaBackground effective z_index stays above the full-scene background while remaining below arena content")
		assert_eq(bg.z_index, -10, "BattleArenaBackground z_index stays below arena content")
		assert_eq(bg.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "BattleArenaBackground ignores source size")
		assert_eq(bg.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "BattleArenaBackground cover-crops the tower art")
		assert_true(abs(bg.modulate.a - 0.55) <= 0.001, "BattleArenaBackground alpha is 0.55 to avoid blocking standees and numbers")
	scene.queue_free()


func _battle_scene() -> Control:
	var scene = BattleSceneScript.new()
	scene.size = Vector2(1280, 720)
	Engine.get_main_loop().root.add_child(scene)
	await Engine.get_main_loop().process_frame
	return scene


func _start_battle_with_optional_context(scene: Control, battle_context: Dictionary) -> void:
	if _start_battle_arg_count(scene) >= 8:
		scene.call("start_battle", [_card("tower_background_card")], [], [_enemy("tower_background_enemy")], [] as Array[String], null, _state(), {}, battle_context)
	else:
		assert_true(false, "BattleScene.start_battle accepts optional battle_context")
		scene.call("start_battle", [_card("tower_background_card")], [], [_enemy("tower_background_enemy")], [] as Array[String], null, _state())


func _start_battle_arg_count(scene: Control) -> int:
	for method in scene.get_method_list():
		if str(method.get("name", "")) != "start_battle":
			continue
		var args: Variant = method.get("args", [])
		if args is Array:
			return (args as Array).size()
	return 0


func _card(id: String) -> Card:
	return CardScript.from_json({
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
	return EnemyScript.from_json({
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


func _find_control(root: Node, node_name: String) -> Control:
	if root == null:
		return null
	var found := root.find_child(node_name, true, false)
	if found is Control:
		return found as Control
	return null


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
