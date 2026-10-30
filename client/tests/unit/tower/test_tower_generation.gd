extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_tower_generation.gd --")
	test_small_tower_generates_three_or_four_floors_with_top_boss()
	test_medium_tower_generates_six_to_eight_floors()
	test_r03_tower_json_data_counts()
	test_event_builders_cover_required_node_types()
	test_event_builders_read_external_json_data()
	test_current_district_aliases_use_commission_ready_tower_data()
	test_first_floor_failure_respawns_and_penalizes()
	test_second_floor_failure_collapses_without_touching_permanent_cards()
	test_spawn_tower_writes_auto_save_before_generation()
	return {"passed": _passed, "failed": _failed}


func test_small_tower_generates_three_or_four_floors_with_top_boss() -> void:
	var generator = _generator()
	assert_true(generator != null, "TowerGenerator script loads")
	if generator == null:
		return
	var tower = generator.generate_tower("small", "shadow_alley", 17)
	assert_true(tower != null, "small tower generated")
	assert_true(tower.floors.size() >= 3 and tower.floors.size() <= 4, "small tower has 3-4 floors")
	assert_eq(tower.floors.back().event_type, "boss", "small tower top floor is boss")
	assert_true(tower.floors[0].event_type != "boss", "small tower first floor is not boss")


func test_medium_tower_generates_six_to_eight_floors() -> void:
	var generator = _generator()
	if generator == null:
		assert_true(false, "TowerGenerator script loads")
		return
	var tower = generator.generate_tower("medium", "misty_port", 23)
	assert_true(tower.floors.size() >= 6 and tower.floors.size() <= 8, "medium tower has 6-8 floors")
	assert_eq(tower.floors.back().event_type, "boss", "medium tower top floor is boss")
	assert_eq(tower.size, "medium", "tower records requested size")


func test_event_builders_cover_required_node_types() -> void:
	var generator = _generator()
	if generator == null:
		assert_true(false, "TowerGenerator script loads")
		return
	for event_type in ["battle", "elite", "event", "merchant", "shrine", "boss"]:
		var data: Dictionary = generator.build_event_data(event_type, 0, "shadow_alley")
		assert_true(not data.is_empty(), "%s event_data is not empty" % event_type)
	assert_true(generator.build_event_data("battle", 0, "shadow_alley").has("enemy_ids"), "battle has enemy_ids")
	assert_true(generator.build_event_data("elite", 0, "shadow_alley").has("drop_table"), "elite has drop_table")
	assert_true(generator.build_event_data("event", 0, "shadow_alley").has("choices"), "event has choices")
	assert_true(generator.build_event_data("merchant", 0, "shadow_alley").has("shop_id"), "merchant has shop_id")
	assert_true(generator.build_event_data("shrine", 0, "shadow_alley").has("shrine_type"), "shrine has shrine_type")
	assert_true(generator.build_event_data("boss", 0, "shadow_alley").has("victory_drops"), "boss has victory_drops")


func test_r03_tower_json_data_counts() -> void:
	assert_eq(_json_count("res://data/combat/enemy_packs/"), 15, "R03 §9.2 enemy_packs has 15 JSON files")
	var event_count: int = _json_count("res://data/events/")
	assert_true(event_count >= 12 and event_count <= 15, "R03 §9.2 events has 12-15 JSON files")
	assert_eq(_json_count("res://data/shrines/"), 3, "R03 §9.2 shrines has 3 JSON files")
	assert_true(FileAccess.file_exists("res://data/towers/boss_table.json"), "R03 §9.2 boss_table.json exists")
	var boss_table: Dictionary = _json("res://data/towers/boss_table.json")
	assert_eq((boss_table.get("bosses", {}) as Dictionary).size(), 5, "R03 §9.2 boss table has 5 district bosses")


func test_event_builders_read_external_json_data() -> void:
	var generator = _generator()
	if generator == null:
		assert_true(false, "TowerGenerator script loads")
		return
	var battle: Dictionary = generator.build_event_data("battle", 0, "shadow_alley")
	assert_eq(str(battle.get("enemy_pack_id", "")), "shadow_alley_t1", "battle uses district+tier enemy pack id")
	assert_eq(Array(battle.get("enemy_ids", [])), ["drunkard", "vagrant"], "battle expands enemy_ids from enemy_packs JSON")
	var elite: Dictionary = generator.build_event_data("elite", 0, "shadow_alley")
	assert_eq(Array(elite.get("enemy_ids", [])), ["inquisitor", "shadow_wraith"], "elite expands elite pack from JSON")
	var event_data: Dictionary = generator.build_event_data("event", 0, "shadow_alley")
	assert_eq(str(event_data.get("event_id", "")), "shadow_alley_well_face", "event builder reads first event template JSON")
	var shrine: Dictionary = generator.build_event_data("shrine", 0, "shadow_alley")
	assert_eq(str(shrine.get("shrine_type", "")), "heal", "shrine builder reads heal shrine JSON")
	assert_eq(int((shrine.get("service_payload", {}) as Dictionary).get("heal_amount", 0)), 25, "heal shrine payload comes from JSON")
	var boss: Dictionary = generator.build_event_data("boss", 0, "misty_port")
	assert_eq(str(boss.get("boss_id", "")), "smuggler_captain", "boss builder reads district boss table")
	assert_eq(Array(boss.get("boss_pack", [])), ["vagrant"], "boss builder reads boss_pack from table")


func test_current_district_aliases_use_commission_ready_tower_data() -> void:
	var generator = _generator()
	if generator == null:
		assert_true(false, "TowerGenerator script loads")
		return
	var steel_battle: Dictionary = generator.build_event_data("battle", 0, "steelworks")
	assert_eq(str(steel_battle.get("enemy_pack_id", "")), "steel_district_t1", "steelworks tower reads existing steel enemy pack data")
	assert_eq(Array(steel_battle.get("enemy_ids", [])), ["vagrant", "drunkard"], "steelworks tower uses steel enemy ids")
	var steel_boss: Dictionary = generator.build_event_data("boss", 0, "steelworks")
	assert_eq(str(steel_boss.get("boss_id", "")), "slag_golem", "steelworks default boss matches live commission target")
	var sacred_boss: Dictionary = generator.build_event_data("boss", 0, "sacred_seven")
	assert_eq(str(sacred_boss.get("boss_id", "")), "church_inquisitor", "sacred_seven current id reads boss table")


func test_first_floor_failure_respawns_and_penalizes() -> void:
	var generator = _generator()
	if generator == null:
		assert_true(false, "TowerGenerator script loads")
		return
	var tower = generator.generate_tower("small", "shadow_alley", 31)
	var gs = _state_with_temp_cards(2)
	gs.pollution = 10
	var result: String = tower.on_floor_failed(0, gs)
	assert_eq(result, "respawn", "first floor failure returns respawn")
	assert_eq(tower.floors[0].fail_count, 1, "first failure increments fail_count")
	assert_eq(gs.temp_picked_cards.size(), 1, "first failure removes one temp card")
	assert_eq(gs.pollution, 15, "first failure adds 5 pollution")


func test_second_floor_failure_collapses_without_touching_permanent_cards() -> void:
	var generator = _generator()
	if generator == null:
		assert_true(false, "TowerGenerator script loads")
		return
	var tower = generator.generate_tower("small", "shadow_alley", 37)
	var gs = _state_with_temp_cards(2)
	gs.cards_inventory.append(_card("permanent_card"))
	gs.pollution = 76
	tower.on_floor_failed(0, gs)
	var result: String = tower.on_floor_failed(0, gs)
	assert_eq(result, "collapsed", "second floor failure collapses tower")
	assert_eq(tower.floors[0].fail_count, 2, "second failure increments fail_count")
	assert_eq(tower.resolution, "collapsed", "tower resolution is collapsed")
	assert_eq(tower.floors[0].resolution, "collapsed", "floor resolution is collapsed")
	assert_eq(gs.temp_picked_cards.size(), 0, "collapse clears temp picked cards")
	assert_eq(gs.cards_inventory.size(), 1, "collapse preserves permanent cards")
	assert_eq(gs.pollution, 101, "first failure +5 and collapse +20 pollution")
	assert_eq(gs.pollution_stage, 5, "collapse recalculates pollution stage")


func test_spawn_tower_writes_auto_save_before_generation() -> void:
	var generator = _generator()
	if generator == null:
		assert_true(false, "TowerGenerator script loads")
		return
	var source := FileAccess.get_file_as_string("res://scripts/tower/tower_generator.gd")
	var save_idx := source.find("last_auto_save_ok = SaveStoreScript.save_auto")
	var generate_idx := source.find("return generate_tower(size, district, seed)")
	assert_true(save_idx >= 0 and generate_idx >= 0 and save_idx < generate_idx, "spawn_tower source calls save_auto before generate_tower")
	var path := "user://tower_auto_test.json"
	var gs = GameStateScript.new()
	gs._ready()
	gs.character_id = "tower_tester"
	gs.day = 4
	gs.cards_inventory.append(_card("saved_card"))
	var tower = generator.spawn_tower("small", "shadow_alley", gs, 41, path)
	assert_true(tower != null, "spawn_tower returns generated tower")
	assert_true(FileAccess.file_exists(path), "spawn_tower writes auto save")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "auto save parses as Dictionary")
	assert_eq(int(parsed.get("save_version", 0)), 1, "auto save version = 1")
	assert_eq(int(parsed.get("summary", {}).get("card_count", -1)), 1, "auto save summary card_count")
	assert_eq(int(parsed.get("game_state", {}).get("day", -1)), 4, "auto save includes GameState.to_dict")


func _generator():
	var script = load("res://scripts/tower/tower_generator.gd")
	if script == null or not script.can_instantiate():
		return null
	return script.new()


func _state_with_temp_cards(count: int):
	var gs = GameStateScript.new()
	gs._ready()
	for i in range(count):
		gs.temp_picked_cards.append(_card("temp_%d" % i))
	return gs


func _card(id: String):
	return CardScript.from_json({
		"id": id,
		"template_id": id,
		"quality": 3,
		"damage": 4,
	})


func _json_count(path: String) -> int:
	var dir = DirAccess.open(path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return count


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


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
