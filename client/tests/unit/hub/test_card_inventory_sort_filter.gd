extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const PanelScript = preload("res://scripts/hub/card_inventory_panel.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_card_inventory_sort_filter.gd --")
	test_sort_pathway_fool_first()
	test_sort_sequence_ascending()
	test_filter_pathway_fool_only()
	test_filter_brand_mounted()
	test_filter_brand_unmounted()
	test_filter_combined_pathway_and_brand()
	test_inventory_entry_and_detail_show_effect_summary()
	test_inventory_detail_uses_clean_player_facing_labels()
	test_inventory_detail_shows_mounted_brand_effects()
	return {"passed": _passed, "failed": _failed}


func _make_card(id: String, pathway: String, seq: int, brands: Array = []) -> Card:
	var d: Dictionary = {"id": id, "pathway": pathway, "sequence": seq, "brands": brands}
	return CardScript.from_json(d)


# === 排序测试 ===

func test_sort_pathway_fool_first() -> void:
	var cards := [
		_make_card("a", "priestess", 9),
		_make_card("b", "fool", 9),
		_make_card("c", "emperor", 9),
	]
	cards.sort_custom(PanelScript._cmp_pathway)
	assert_eq(cards[0].id, "b", "fool first in pathway sort")
	assert_eq(cards[1].id, "c", "emperor after fool")
	assert_eq(cards[2].id, "a", "priestess last")


func test_sort_sequence_ascending() -> void:
	var cards := [
		_make_card("a", "fool", 7),
		_make_card("b", "fool", 9),
		_make_card("c", "fool", 8),
	]
	cards.sort_custom(PanelScript._cmp_sequence)
	assert_eq(cards[0].sequence, 7, "seq 7 first")
	assert_eq(cards[1].sequence, 8, "seq 8 second")
	assert_eq(cards[2].sequence, 9, "seq 9 last")


# === 筛选测试 ===

func test_filter_pathway_fool_only() -> void:
	var cards := [
		_make_card("a", "fool", 9),
		_make_card("b", "priestess", 9),
		_make_card("c", "fool", 8),
	]
	var result = PanelScript.filter_cards(cards, "fool", PanelScript.FilterBrand.ALL)
	assert_eq(result.size(), 2, "filter fool: 2 cards")
	assert_eq(result[0].id, "a", "filter fool: first = a")
	assert_eq(result[1].id, "c", "filter fool: second = c")


func test_filter_brand_mounted() -> void:
	var cards := [
		_make_card("a", "fool", 9, ["brand_x"]),
		_make_card("b", "fool", 9, []),
		_make_card("c", "fool", 8, ["brand_y"]),
	]
	var result = PanelScript.filter_cards(cards, "", PanelScript.FilterBrand.MOUNTED)
	assert_eq(result.size(), 2, "filter mounted: 2 cards")
	assert_eq(result[0].id, "a", "filter mounted: a")
	assert_eq(result[1].id, "c", "filter mounted: c")


func test_filter_brand_unmounted() -> void:
	var cards := [
		_make_card("a", "fool", 9, ["brand_x"]),
		_make_card("b", "fool", 9, []),
	]
	var result = PanelScript.filter_cards(cards, "", PanelScript.FilterBrand.UNMOUNTED)
	assert_eq(result.size(), 1, "filter unmounted: 1 card")
	assert_eq(result[0].id, "b", "filter unmounted: b")


func test_filter_combined_pathway_and_brand() -> void:
	var cards := [
		_make_card("a", "fool", 9, ["brand_x"]),
		_make_card("b", "fool", 9, []),
		_make_card("c", "priestess", 9, ["brand_y"]),
	]
	var result = PanelScript.filter_cards(cards, "fool", PanelScript.FilterBrand.MOUNTED)
	assert_eq(result.size(), 1, "combined filter: 1 card")
	assert_eq(result[0].id, "a", "combined filter: a")


func test_inventory_entry_and_detail_show_effect_summary() -> void:
	var panel = PanelScript.new()
	panel._build_ui()
	var card = CardScript.from_json({
		"id": "inventory_summary_probe",
		"display_name": "卡库说明探针",
		"description": "让目标吐露一句真话",
		"pathway": "fool",
		"sequence": 9,
		"energy_cost": 1,
		"combat_effect": {"damage": 6, "heal": 0, "target": "single", "range": 2, "status_effects": []},
		"social_effect": {"type": "read_truth"},
	})
	var entry = panel.call("_make_card_entry", 0, card)
	assert_true(_collect_label_text(entry).contains("让目标吐露一句真话"), "card inventory row includes readable effect summary")
	panel.call("_show_detail", card, panel._destroy_button)
	var detail_text := _collect_label_text(panel._detail_panel)
	assert_true(detail_text.contains("效果解读"), "card detail has an effect summary field")
	assert_true(detail_text.contains("战斗") and detail_text.contains("造成 6 伤害"), "card detail explains combat effect")
	assert_true(detail_text.contains("社交") and detail_text.contains("读取真话"), "card detail explains social effect")
	panel.queue_free()


func test_inventory_detail_uses_clean_player_facing_labels() -> void:
	var panel = PanelScript.new()
	panel._build_ui()
	var card = CardScript.from_json({
		"id": "inventory_clean_probe",
		"display_name": "纸偶契约",
		"description": "让纸张替你承受一次灾厄。",
		"pathway": "fool",
		"sequence": 7,
		"rarity": "rare",
		"energy_cost": 2,
		"combat_effect": {
			"damage": 12,
			"heal": 0,
			"target": "single",
			"range": 3,
			"status_effects": [{"id": "paper_doll_marker", "max_stacks": 3}],
		},
		"acting_rules": ["不连续 2 回合主动攻击"],
		"rule_violation_penalty": {"pollution_delta": 2},
		"social_effect": {"type": "identity_mask", "suspicion_delta": -10, "church_awareness_delta": 2},
		"world_effect": {"type": "create_residual_identity", "identity_id": "borrowed_face_inventory_clean_probe", "allowed_locations": ["shadow_alley"], "uses_remaining": 3},
	})
	panel.call("_show_detail", card, panel._destroy_button)
	var detail_text := _collect_label_text(panel._detail_panel)
	assert_true(detail_text.contains("稀有度: 稀有"), "inventory detail shows a clean rarity label")
	assert_true(detail_text.contains("目标: 单体") and detail_text.contains("范围 3"), "inventory detail shows a clean target label")
	assert_true(detail_text.contains("状态: 纸人替身"), "inventory detail shows a clean status label")
	assert_true(detail_text.contains("场外·社交"), "inventory detail shows clean social label")
	assert_true(detail_text.contains("场外·世界"), "inventory detail shows clean world label")
	for raw in [
		"rare",
		"single",
		"paper_doll_marker",
		"identity_mask",
		"create_residual_identity",
		"{",
		"}",
		"[",
		"]",
	]:
		assert_true(not detail_text.contains(raw), "inventory detail hides raw token %s" % raw)
	panel.queue_free()


func test_inventory_detail_shows_mounted_brand_effects() -> void:
	var panel = PanelScript.new()
	panel._build_ui()
	var card = CardScript.from_json({
		"id": "inventory_brand_summary_probe",
		"display_name": "烙印卡库探针",
		"description": "用于验证卡库详情展示挂载烙印效果。",
		"brand_slots": 3,
		"brands": ["damage_plus_low", "pierce"],
		"combat_effect": {"damage": 8, "heal": 0, "target": "single", "range": 2, "status_effects": []},
	})
	panel.call("_show_detail", card, panel._destroy_button)
	var detail_text := _collect_label_text(panel._detail_panel)
	assert_true(detail_text.contains("烙印: 已挂载 2/3"), "inventory detail keeps brand slot count")
	assert_true(detail_text.contains("锐利之纹") and detail_text.contains("该卡伤害增加3"), "inventory detail explains damage brand")
	assert_true(detail_text.contains("破甲之纹") and detail_text.contains("忽视3点防御"), "inventory detail explains pierce brand")
	for raw in ["damage_plus_low", "pierce", "effect_payload", "{", "}"]:
		assert_true(not detail_text.contains(raw), "inventory brand detail hides raw token %s" % raw)
	panel.queue_free()


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


func _collect_label_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += str(node.text) + "\n"
	for child in node.get_children():
		text += _collect_label_text(child)
	return text
