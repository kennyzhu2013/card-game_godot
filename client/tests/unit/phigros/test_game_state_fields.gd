extends RefCounted

const GameStateScript = preload("res://scripts/state/game_state.gd")
const CardScript = preload("res://scripts/combat/card.gd")
const AccountStoreScript = preload("res://scripts/state/account_store.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_game_state_fields.gd --")
	test_default_fields_8_1_identity()
	test_default_fields_8_3_forge()
	test_default_fields_8_4_brands()
	test_default_fields_8_5_contract()
	test_default_fields_8_6_pollution()
	test_default_fields_8_7_time_ap()
	test_default_fields_8_8_currency()
	test_default_fields_8_9_npc()
	test_default_fields_8_10_commissions()
	test_default_fields_8_11_daodian()
	test_sequence_active_deck_capacity()
	test_inventory_unlimited_capacity()
	test_temp_cards_max_5()
	test_temp_cards_clear()
	test_serialization_round_trip()
	test_reset_preserves_character_fields()
	test_reset_increments_cycle()
	test_reset_clears_cycle_fields()
	test_reset_reloads_account_store_from_user_saves()
	return {"passed": _passed, "failed": _failed}


func _new_state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


# === §8.1 玩家身份与序列 ===
func test_default_fields_8_1_identity() -> void:
	var gs = _new_state()
	assert_eq(gs.character_id, "harvey_mors", "character_id default")
	assert_eq(gs.pathway, "fool", "pathway default")
	assert_eq(gs.sequence, 9, "sequence default = 9")
	assert_eq(gs.sequence_exp, 0, "sequence_exp default = 0")


# === §8.3 锻造与符号 ===
func test_default_fields_8_3_forge() -> void:
	var gs = _new_state()
	assert_eq(gs.forge_materials, {}, "forge_materials default empty dict")
	assert_eq(gs.unlocked_symbols.size(), 6, "unlocked_symbols has 6 defaults")
	assert_true("shadow" in gs.unlocked_symbols, "shadow in unlocked_symbols")
	assert_true("blood" in gs.unlocked_symbols, "blood in unlocked_symbols")
	assert_eq(gs.known_reactions, [], "known_reactions default empty")


# === §8.4 烙印 ===
func test_default_fields_8_4_brands() -> void:
	var gs = _new_state()
	assert_eq(gs.brands_inventory, [], "brands_inventory default empty")


# === §8.5 扮演契约 ===
func test_default_fields_8_5_contract() -> void:
	var gs = _new_state()
	assert_eq(gs.learned_rules.size(), 5, "5 default Fool rules")
	assert_true("永远多一个面具" in gs.learned_rules, "rule 01 present")
	assert_true("不直呼神名" in gs.learned_rules, "rule 11 present")
	assert_eq(gs.active_contract, [], "active_contract default empty")


# === §8.6 污染与失控 ===
func test_default_fields_8_6_pollution() -> void:
	var gs = _new_state()
	assert_eq(gs.pollution, 0, "pollution default 0")
	assert_eq(gs.pollution_stage, 0, "pollution_stage default 0")
	assert_eq(gs.is_lost_control, false, "is_lost_control default false")


# === §8.7 时间与 AP ===
func test_default_fields_8_7_time_ap() -> void:
	var gs = _new_state()
	assert_eq(gs.cycle, 1, "cycle default 1")
	assert_eq(gs.day, 1, "day default 1")
	assert_eq(gs.time_of_day, "morning", "time_of_day default morning")
	assert_eq(gs.ap, 12, "ap default 12")
	assert_eq(gs.ap_max, 12, "ap_max default 12")
	assert_eq(gs.current_weather, "", "current_weather default empty string")


# === §8.8 货币与材料 ===
func test_default_fields_8_8_currency() -> void:
	var gs = _new_state()
	assert_eq(gs.lingstones, 10, "lingstones default 10")
	assert_eq(gs.dao_pages, 0, "dao_pages default 0")


# === §8.9 NPC 与势力 ===
func test_default_fields_8_9_npc() -> void:
	var gs = _new_state()
	assert_eq(gs.npc_relations, {}, "npc_relations default empty dict")
	assert_eq(gs.church_awareness, 0, "church_awareness default 0")
	assert_eq(gs.halfmoon_trust, 30, "halfmoon_trust default 30")


# === §8.10 委托 ===
func test_default_fields_8_10_commissions() -> void:
	var gs = _new_state()
	assert_eq(gs.available_commissions, [], "available_commissions default empty")
	assert_eq(gs.accepted_commissions, [], "accepted_commissions default empty")
	assert_eq(gs.completed_commissions, [], "completed_commissions default empty")


# === §8.11 道典 ===
func test_default_fields_8_11_daodian() -> void:
	var gs = _new_state()
	assert_true(gs.daodian is Dictionary, "daodian is Dictionary")
	assert_true(gs.daodian.has("discovered_cards"), "daodian.discovered_cards exists")
	assert_true(gs.daodian.has("discovered_brands"), "daodian.discovered_brands exists")
	assert_true(gs.daodian.has("unique_artifacts_seen"), "daodian.unique_artifacts_seen exists")
	assert_true(gs.daodian.has("dao_fragments"), "daodian.dao_fragments exists")


# === 序列联动容量 ===
func test_sequence_active_deck_capacity() -> void:
	var gs = _new_state()
	gs.sequence = 9
	assert_eq(gs.get_active_deck_capacity(), 12, "seq 9 = 12 cards")
	gs.sequence = 8
	assert_eq(gs.get_active_deck_capacity(), 13, "seq 8 = 13 cards")
	gs.sequence = 7
	assert_eq(gs.get_active_deck_capacity(), 15, "seq 7 = 15 cards")
	gs.sequence = 0
	assert_eq(gs.get_active_deck_capacity(), 25, "seq 0 = 25 cards")


func test_inventory_unlimited_capacity() -> void:
	# 卡库无容量限制 (R01 §3.1 / R07 §2)：可以无限 add_card
	var gs = _new_state()
	for i in 200:
		var c = CardScript.from_json({"id": "inv_%d" % i})
		assert_true(gs.add_card(c), "add_card #%d should succeed (no capacity limit)" % i)
	assert_eq(gs.cards_inventory.size(), 200, "200 cards stored without rejection")


# === 临时卡 ===
func test_temp_cards_max_5() -> void:
	var gs = _new_state()
	for i in 5:
		var c = CardScript.from_json({"id": "temp_%d" % i})
		assert_true(gs.add_temp_card(c), "temp card %d added" % i)
	var c6 = CardScript.from_json({"id": "temp_overflow"})
	assert_true(not gs.add_temp_card(c6), "6th temp card rejected")


func test_temp_cards_clear() -> void:
	var gs = _new_state()
	var c = CardScript.from_json({"id": "temp_clear_test"})
	gs.add_temp_card(c)
	assert_eq(gs.temp_picked_cards.size(), 1, "one temp card before clear")
	gs.clear_temp_cards()
	assert_eq(gs.temp_picked_cards.size(), 0, "temp cards cleared")


# === 序列化 ===
func test_serialization_round_trip() -> void:
	var gs = _new_state()
	gs.character_id = "test_char"
	gs.pathway = "fool"
	gs.sequence = 8
	gs.ap = 6
	gs.lingstones = 50
	gs.church_awareness = 10
	gs.current_weather = "fool_fog"
	gs.npc_relations = {"npc_01": _make_npc_state(5, 15)}
	var c = CardScript.from_json({"id": "ser_test", "quality": 3, "pathway": "fool"})
	gs.add_card(c)
	gs.temp_picked_cards.append(CardScript.from_json({"id": "ser_temp"}))

	var d = gs.to_dict()
	var gs2 = _new_state()
	gs2.from_dict(d)

	assert_eq(gs2.character_id, "test_char", "serialize: character_id")
	assert_eq(gs2.sequence, 8, "serialize: sequence")
	assert_eq(gs2.ap, 6, "serialize: ap")
	assert_eq(gs2.lingstones, 50, "serialize: lingstones")
	assert_eq(gs2.church_awareness, 10, "serialize: church_awareness")
	assert_eq(gs2.current_weather, "fool_fog", "serialize: current_weather")
	var npc_state = gs2.npc_relations.get("npc_01", null)
	assert_true(npc_state != null, "serialize: npc_01 exists")
	assert_eq(npc_state.trust, 5, "serialize: npc_relations trust")
	assert_eq(npc_state.suspicion, 15, "serialize: npc_relations suspicion")
	assert_eq(gs2.cards_inventory.size(), 1, "serialize: cards_inventory count")
	assert_eq(gs2.temp_picked_cards.size(), 1, "serialize: temp_picked_cards count")


# === reset ===
func test_reset_preserves_character_fields() -> void:
	# 角色级字段跨周目不动 (R10 §8.13)
	var gs = _new_state()
	gs.character_id = "elara_veis"
	gs.pathway = "priestess"
	gs.sequence = 6
	gs.reset()
	assert_eq(gs.character_id, "elara_veis", "reset: character_id preserved")
	assert_eq(gs.pathway, "priestess", "reset: pathway preserved")
	assert_eq(gs.sequence, 6, "reset: sequence preserved")


func test_reset_increments_cycle() -> void:
	# cycle 自增而非归 1 (R10 §8.13.1)
	var gs = _new_state()
	gs.cycle = 5
	gs.reset()
	assert_eq(gs.cycle, 6, "reset: cycle incremented 5→6")


func test_reset_clears_cycle_fields() -> void:
	# 周目级字段清零 (R10 §8.13)
	var gs = _new_state()
	gs.character_id = "changed"
	gs.sequence = 7
	gs.sequence_exp = 100
	gs.forge_materials = {"iron": 5}
	var unlocked_symbols: Array[String] = ["shadow"]
	gs.unlocked_symbols = unlocked_symbols
	var known_reactions: Array[String] = ["shadow_arrow"]
	gs.known_reactions = known_reactions
	var learned_rules: Array[String] = ["only_one"]
	gs.learned_rules = learned_rules
	var active_contract: Array[String] = ["rule_a"]
	gs.active_contract = active_contract
	gs.pollution = 42
	gs.is_lost_control = true
	gs.cycle = 3
	gs.day = 10
	gs.ap = 1
	gs.lingstones = 999
	gs.dao_pages = 5
	gs.npc_relations = {"npc_x": _make_npc_state(10, 0)}
	gs.church_awareness = 50
	gs.current_weather = "thunderstorm"
	gs.halfmoon_trust = 10
	var accepted_commissions: Array[String] = ["com_1"]
	gs.accepted_commissions = accepted_commissions
	var completed_commissions: Array[String] = ["com_2"]
	gs.completed_commissions = completed_commissions
	gs.daodian["discovered_cards"] = ["card_a"]

	gs.reset()

	# 角色级不动
	assert_eq(gs.character_id, "changed", "reset: character_id preserved (not restored)")
	assert_eq(gs.sequence, 7, "reset: sequence preserved (not restored)")
	# cycle 递增
	assert_eq(gs.cycle, 4, "reset: cycle incremented 3→4")
	# 周目级清零
	assert_eq(gs.sequence_exp, 0, "reset: sequence_exp cleared")
	assert_eq(gs.forge_materials, {}, "reset: forge_materials cleared")
	assert_eq(gs.unlocked_symbols.size(), 6, "reset: unlocked_symbols restored to 6")
	assert_eq(gs.known_reactions, [], "reset: known_reactions cleared")
	assert_eq(gs.learned_rules.size(), 5, "reset: learned_rules restored to 5")
	assert_eq(gs.active_contract, ["rule_a"], "reset: active_contract preserved for next cycle")
	assert_eq(gs.pollution, 0, "reset: pollution cleared")
	assert_eq(gs.is_lost_control, false, "reset: is_lost_control cleared")
	assert_eq(gs.day, 1, "reset: day reset to 1")
	assert_eq(gs.ap, 12, "reset: ap restored")
	assert_eq(gs.lingstones, 10, "reset: lingstones restored")
	assert_eq(gs.dao_pages, 0, "reset: dao_pages cleared")
	assert_eq(gs.npc_relations, {}, "reset: npc_relations cleared")
	assert_eq(gs.church_awareness, 0, "reset: church_awareness cleared")
	assert_eq(gs.current_weather, "", "reset: current_weather cleared")
	assert_eq(gs.halfmoon_trust, 30, "reset: halfmoon_trust restored")
	assert_eq(gs.accepted_commissions, [], "reset: accepted_commissions cleared")
	# 账号级从 account.json 加载（文件不存在时回退默认值）
	assert_eq(gs.completed_commissions, [], "reset: completed_commissions from account (default [])")
	assert_eq(gs.daodian["discovered_cards"], [], "reset: daodian from account (default [])")


func test_reset_reloads_account_store_from_user_saves() -> void:
	var snapshot := _snapshot_account_file()
	var global_path := ProjectSettings.globalize_path(AccountStoreScript.PATH)
	assert_true(global_path.begins_with(OS.get_user_data_dir()), "account.json resolves under OS user data dir")
	var divinity_card := {
		"id": "divinity_seed",
		"template_id": "divinity_seed",
		"name": "divinity seed",
		"quality": 3,
		"pathway": "fool",
	}
	AccountStoreScript.save({
		"daodian": {
			"discovered_cards": ["fool_s9_spirit_vision"],
			"discovered_brands": ["moonlit_mask"],
			"unique_artifacts_seen": ["first_mask"],
			"dao_fragments": ["frag_a"],
		},
		"completed_commissions": ["commission_intro"],
		"divinity_cards": [divinity_card],
	})
	var gs = _new_state()
	gs.cards_inventory.append(CardScript.from_json({"id": "cycle_card", "template_id": "cycle_card"}))
	gs.completed_commissions = ["local_only"] as Array[String]
	gs.daodian["discovered_cards"] = ["local_card"]
	gs.reset()
	assert_eq(gs.daodian["discovered_cards"], ["fool_s9_spirit_vision"], "reset reloads account daodian.discovered_cards")
	assert_eq(gs.completed_commissions, ["commission_intro"], "reset reloads account completed_commissions")
	assert_eq(gs.cards_inventory.size(), 1, "reset clears cycle cards and restores divinity cards")
	assert_eq(gs.cards_inventory[0].id, "divinity_seed", "reset restores divinity card from account")
	_restore_account_file(snapshot)


func _snapshot_account_file() -> Dictionary:
	if not FileAccess.file_exists(AccountStoreScript.PATH):
		return {"exists": false, "text": ""}
	var f := FileAccess.open(AccountStoreScript.PATH, FileAccess.READ)
	if f == null:
		return {"exists": false, "text": ""}
	var text := f.get_as_text()
	f.close()
	return {"exists": true, "text": text}


func _restore_account_file(snapshot: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(AccountStoreScript.PATH)
	if bool(snapshot.get("exists", false)):
		DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
		var f := FileAccess.open(AccountStoreScript.PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(str(snapshot.get("text", "")))
			f.close()
		return
	if FileAccess.file_exists(AccountStoreScript.PATH):
		var dir := DirAccess.open(global_path.get_base_dir())
		if dir != null:
			dir.remove(global_path.get_file())


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")


func _make_npc_state(trust_val: int, suspicion_val: int):
	var state = NpcKnowledgeStateScript.new()
	state.trust = trust_val
	state.suspicion = suspicion_val
	return state


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
