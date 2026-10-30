extends RefCounted

const CardScript = preload("res://scripts/combat/card.gd")
const CardLibraryScript = preload("res://scripts/combat/card_library.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const NpcKnowledgeStateScript = preload("res://scripts/npc/npc_knowledge_state.gd")
const EncounterScript = preload("res://scripts/world/encounter.gd")
const EncounterRunnerScript = preload("res://scripts/world/encounter_runner.gd")
const ChantButtonFactoryScript = preload("res://scripts/world/chant_button_factory.gd")

const R20_ENGINE_PATH := "res://scripts/world/r20_effect_engine.gd"
const HUB_SCENE := "res://scenes/hub/hub.tscn"
const CITY_SCENE := "res://scenes/world/city_scene.tscn"

const EXPECTED_R20_CARDS := {
	"shadow_jester": {"display_name": "影代之诡", "social": "identity_mask", "world": "create_residual_identity"},
	"jester_name": {"display_name": "夺名之诡", "social": "borrow_name", "world": "reveal_hidden_lore"},
	"shadow_name": {"display_name": "无名之影", "social": "forget_event", "world": "alter_npc_state"},
	"inquiry_mirror": {"display_name": "镜中问", "social": "read_truth", "world": "reveal_hidden_lore"},
	"fortune_thread": {"display_name": "命运牵引", "social": "modify_suspicion", "world": "spawn_event"},
	"mirror_face": {"display_name": "易容", "social": "identity_mask", "world": "create_residual_identity"},
	"inquiry_fortune": {"display_name": "占卜", "social": "extract_memory", "world": "spawn_event"},
	"shadow_thread": {"display_name": "影线牵引", "social": "extract_secret", "world": "reveal_npc_relationships"},
	"jester_face": {"display_name": "蠢面", "social": "forget_event", "world": ""},
	"inquiry_name": {"display_name": "审名", "social": "extract_secret", "world": "reveal_hidden_lore"},
	"mirror_shadow": {"display_name": "镜影", "social": "identity_mask", "world": "spawn_event"},
	"jester_fortune": {"display_name": "蠢运", "social": "influence_behavior", "world": ""},
}

const EXPECTED_FOOL_SKILL_R20_CARDS := {
	"fool_s9_spirit_vision": {"social": "extract_secret", "world": "reveal_hidden_lore"},
	"fool_s9_star_chart_divination": {"social": "extract_memory", "world": "spawn_event"},
	"fool_s9_pendulum_query": {"social": "read_truth", "world": "reveal_hidden_lore"},
	"fool_s9_ritual_chant": {"social": "influence_behavior", "world": "modify_node_atmosphere"},
	"fool_s9_arcane_lore": {"social": "extract_secret", "world": "reveal_hidden_lore"},
	"fool_s9_premonition": {"social": "modify_suspicion", "world": "spawn_event"},
	"fool_s8_microexpression_read": {"social": "read_truth", "world": "reveal_hidden_lore"},
	"fool_s8_predator_instinct": {"social": "modify_suspicion", "world": ""},
	"fool_s7_paper_doll_substitute": {"social": "identity_mask", "world": "create_residual_identity"},
	"fool_s7_illusion_weave": {"social": "forget_event", "world": "alter_npc_state"},
	"fool_s7_bone_softening": {"social": "identity_mask", "world": "create_residual_identity"},
	"fool_s7_minor_trick": {"social": "influence_behavior", "world": ""},
}

var _passed := 0
var _failed := 0


class FakeAIGMService:
	extends RefCounted

	var calls: Array = []

	func call_ai_gm(ctx) -> String:
		calls.append(ctx)
		return "city r20 ai gm visible text"


func run() -> Dictionary:
	print("\n-- test_r20_dual_effect.gd --")
	test_card_social_world_fields_roundtrip()
	test_12_fool_skill_cards_have_r20_social_or_world_effects()
	test_card_library_loads_12_r20_triple_effect_cards_without_losing_legacy_cards()
	test_r20_engine_dispatches_social_and_world_once_cost()
	test_r20_player_feedback_summarizes_disguise_residual_and_risk()
	test_r20_engine_rolls_back_when_hub_mana_short()
	test_chant_button_surfaces_cost_effects_and_shortage_reason()
	await test_inventory_only_r20_cards_do_not_expose_npc_chant_buttons()
	await test_hub_city_npc_dialogue_keeps_r20_chant_off_npc_surface()
	await test_city_scene_and_encounter_runner_expose_chant_buttons()
	await test_encounter_r20_chant_displays_field_hook_feedback()
	await test_city_scene_chant_displays_ai_gm_feedback()
	return {"passed": _passed, "failed": _failed}


func test_card_social_world_fields_roundtrip() -> void:
	var data := {
		"id": "r20_probe",
		"template_id": "r20_probe",
		"display_name": "R20 Probe",
		"energy_cost": 2,
		"combat_effect": {"damage": 4, "target": "single"},
		"social_effect": {"type": "identity_mask", "duration_days": 3, "suspicion_delta": -20},
		"world_effect": {"type": "create_residual_identity", "identity_id": "probe_identity", "duration_days": 3},
	}
	var card = CardScript.from_json(data)
	assert_true(_has_property(card, "social_effect"), "Card exposes structured social_effect field")
	assert_true(_has_property(card, "world_effect"), "Card exposes structured world_effect field")
	if not _has_property(card, "social_effect") or not _has_property(card, "world_effect"):
		return
	var social_effect: Variant = card.get("social_effect")
	var world_effect: Variant = card.get("world_effect")
	assert_true(social_effect is Dictionary, "Card.from_json stores social_effect as Dictionary")
	assert_true(world_effect is Dictionary, "Card.from_json stores world_effect as Dictionary")
	if not (social_effect is Dictionary) or not (world_effect is Dictionary):
		return
	assert_eq((social_effect as Dictionary).get("type", ""), "identity_mask", "Card.from_json imports social_effect by key")
	assert_eq((world_effect as Dictionary).get("type", ""), "create_residual_identity", "Card.from_json imports world_effect by key")
	assert_true(card.has_method("can_use_socially"), "Card exposes can_use_socially()")
	assert_true(card.has_method("has_world_effect"), "Card exposes has_world_effect()")
	if card.has_method("can_use_socially"):
		assert_true(bool(card.call("can_use_socially")), "can_use_socially returns true for social cards")
	if card.has_method("has_world_effect"):
		assert_true(bool(card.call("has_world_effect")), "has_world_effect returns true for world cards")
	var roundtrip = CardScript.from_json(card.to_dict())
	assert_eq(roundtrip.get("social_effect").get("type", ""), "identity_mask", "Card.to_dict roundtrips social_effect")
	assert_eq(roundtrip.get("world_effect").get("type", ""), "create_residual_identity", "Card.to_dict roundtrips world_effect")


func test_12_fool_skill_cards_have_r20_social_or_world_effects() -> void:
	var found_with_r20 := 0
	for file_name in _fool_skill_file_names():
		var data := _json_dict("res://data/skills/%s" % file_name)
		if data.is_empty():
			continue
		var card_id := str(data.get("id", ""))
		var social: Dictionary = data.get("social_effect", {}) if data.get("social_effect", {}) is Dictionary else {}
		var world: Dictionary = data.get("world_effect", {}) if data.get("world_effect", {}) is Dictionary else {}
		if str(social.get("type", "")) != "" or str(world.get("type", "")) != "":
			found_with_r20 += 1
		if not EXPECTED_FOOL_SKILL_R20_CARDS.has(card_id):
			continue
		var expected: Dictionary = EXPECTED_FOOL_SKILL_R20_CARDS[card_id]
		assert_eq(str(data.get("pathway", "")), "fool", "%s remains a Fool-pathway card" % card_id)
		var card = CardScript.from_skill_json(data)
		var expected_social := str(expected.get("social", ""))
		var expected_world := str(expected.get("world", ""))
		if expected_social != "":
			assert_true(card.can_use_socially(), "%s has usable social_effect" % card_id)
			assert_eq(str(card.social_effect.get("type", "")), expected_social, "%s social_effect follows R20 mapping" % card_id)
		if expected_world != "":
			assert_true(card.has_world_effect(), "%s has usable world_effect" % card_id)
			assert_eq(str(card.world_effect.get("type", "")), expected_world, "%s world_effect follows R20 mapping" % card_id)
		assert_true(card.can_use_socially() or card.has_world_effect(), "%s is a dual-effect R20 Fool skill card" % card_id)
	assert_eq(EXPECTED_FOOL_SKILL_R20_CARDS.size(), 12, "test covers exactly 12 planned Fool skill R20 cards")
	assert_eq(found_with_r20, 12, "exactly 12 client/data/skills/fool_*.json cards have social/world fields")


func test_card_library_loads_12_r20_triple_effect_cards_without_losing_legacy_cards() -> void:
	assert_true(FileAccess.file_exists("res://data/cards/fool_triple_effect.json"), "R20 fool_triple_effect data file exists")
	var library = CardLibraryScript.new()
	library.load_all()
	assert_true(library.get_card("shadow_arrow") != null, "CardLibrary still loads legacy data/skills cards after data/cards is present")
	for card_id in EXPECTED_R20_CARDS.keys():
		var expected: Dictionary = EXPECTED_R20_CARDS[card_id]
		var card = library.get_card(str(card_id))
		assert_true(card != null, "R20 card exists: %s" % card_id)
		if card == null:
			continue
		assert_eq(card.get_display_name(), str(expected.get("display_name", "")), "R20 display_name matches spec for %s" % card_id)
		var social_effect: Variant = card.get("social_effect")
		var world_effect: Variant = card.get("world_effect")
		assert_true(social_effect is Dictionary, "R20 social_effect stored as Dictionary for %s" % card_id)
		assert_true(world_effect is Dictionary, "R20 world_effect stored as Dictionary for %s" % card_id)
		if social_effect is Dictionary:
			assert_eq(str((social_effect as Dictionary).get("type", "")), str(expected.get("social", "")), "R20 social type matches spec for %s" % card_id)
		if world_effect is Dictionary:
			assert_eq(str((world_effect as Dictionary).get("type", "")), str(expected.get("world", "")), "R20 world type matches spec for %s" % card_id)


func test_r20_engine_dispatches_social_and_world_once_cost() -> void:
	var engine = _new_script_instance(R20_ENGINE_PATH, "R20EffectEngine")
	if engine == null:
		return
	var gs = _state()
	if not _has_property(gs, "hub_mana") or not _has_property(gs, "residual_identities"):
		assert_true(false, "GameState exposes hub_mana and residual_identities for R20")
		return
	gs.hub_mana = 10
	gs.pollution = 0
	gs.church_awareness = 0
	var state = NpcKnowledgeStateScript.new()
	state.suspicion = 40
	gs.npc_relations["old_li"] = state
	var card = CardScript.from_json({
		"id": "r20_cast_probe",
		"display_name": "影代之诡",
		"energy_cost": 2,
		"combat_effect": {"damage": 12, "target": "single"},
		"social_effect": {"type": "identity_mask", "duration_days": 3, "npc_perception": "dead_brother", "suspicion_delta": -20},
		"world_effect": {"type": "create_residual_identity", "identity_id": "borrowed_face_old_li", "duration_days": 3, "allowed_locations": ["old_li", "shadow_alley"]},
	})

	var result: Dictionary = engine.call("dispatch_card", card, "old_li", {"game_state": gs, "source": "unit_test"})
	assert_true(bool(result.get("success", false)), "dispatch_card succeeds")
	assert_eq(int(gs.hub_mana), 8, "dispatch_card charges hub_mana once for social+world")
	assert_eq(int(gs.pollution), 5, "dispatch_card applies social+world pollution deltas")
	assert_eq(int(gs.church_awareness), 4, "dispatch_card applies social+world church awareness deltas")
	assert_eq(str(state.active_perception), "dead_brother", "identity_mask applies the requested npc_perception")
	assert_eq(int(state.perception_expires_at), 4, "identity_mask expires at day + duration")
	assert_eq(int(state.suspicion), 20, "identity_mask applies suspicion_delta")
	assert_eq(gs.residual_identities.size(), 1, "world create_residual_identity adds one residual identity")
	var ai_payload: Variant = result.get("ai_gm_payload", {})
	assert_true(ai_payload is Dictionary, "dispatch_card returns ai_gm_payload Dictionary")
	if ai_payload is Dictionary:
		assert_eq(str((ai_payload as Dictionary).get("scene", "")), "social_resolve", "dispatch_card returns R09 social payload stub")


func test_r20_player_feedback_summarizes_disguise_residual_and_risk() -> void:
	var engine = _new_script_instance(R20_ENGINE_PATH, "R20EffectEngine")
	if engine == null:
		return
	var gs = _state()
	gs.day = 2
	gs.hub_mana = 10
	gs.pollution = 10
	gs.church_awareness = 5
	var state = NpcKnowledgeStateScript.new()
	state.suspicion = 40
	gs.npc_relations["old_li"] = state
	var card = CardScript.from_json({
		"id": "r20_visible_feedback_probe",
		"template_id": "r20_visible_feedback_probe",
		"display_name": "\u53ef\u89c1\u4f2a\u88c5\u6d4b\u8bd5",
		"energy_cost": 2,
		"combat_effect": {"damage": 0, "target": "self"},
		"social_effect": {"type": "identity_mask", "duration_days": 3, "npc_perception": "dead_brother", "suspicion_delta": -15},
		"world_effect": {"type": "create_residual_identity", "identity_id": "borrowed_face_old_li", "name": "\u501f\u6765\u7684\u8001\u674e\u8138", "duration_days": 3, "allowed_locations": ["old_li", "shadow_alley"], "uses_remaining": 2},
	})
	var result: Dictionary = engine.dispatch_card(card, "old_li", {"game_state": gs})
	assert_true(bool(result.get("ok", false)), "R20 feedback probe dispatch succeeds")
	assert_eq(str(state.active_perception), "dead_brother", "R20 feedback probe stores a concrete disguise perception")
	assert_true(engine.has_method("player_feedback_lines"), "R20EffectEngine exposes player feedback lines")
	if engine.has_method("player_feedback_lines"):
		var text := "\n".join(engine.call("player_feedback_lines", result))
		assert_true(text.contains("\u4f2a\u88c5") and text.contains("\u4ea1\u5144"), "R20 feedback names the applied disguise")
		assert_true(text.contains("\u6000\u7591") and text.contains("-15"), "R20 feedback names suspicion delta")
		assert_true(text.contains("\u6b8b\u7559\u8eab\u4efd") and text.contains("\u501f\u6765\u7684\u8001\u674e\u8138"), "R20 feedback names created residual identity")
		assert_true(text.contains("\u6559\u4f1a") and text.contains("\u6c61\u67d3"), "R20 feedback names church awareness and pollution deltas")
		assert_true(text.find("identity_mask") < 0 and text.find("create_residual_identity") < 0, "R20 feedback hides raw effect ids")


func test_r20_engine_rolls_back_when_hub_mana_short() -> void:
	var engine = _new_script_instance(R20_ENGINE_PATH, "R20EffectEngine")
	if engine == null:
		return
	var gs = _state()
	if not _has_property(gs, "hub_mana") or not _has_property(gs, "residual_identities"):
		assert_true(false, "GameState exposes hub_mana and residual_identities for rollback")
		return
	gs.hub_mana = 1
	gs.pollution = 0
	gs.church_awareness = 0
	var state = NpcKnowledgeStateScript.new()
	state.suspicion = 40
	gs.npc_relations["old_li"] = state
	var card = CardScript.from_json({
		"id": "r20_short_probe",
		"energy_cost": 3,
		"social_effect": {"type": "modify_suspicion", "suspicion_delta": -10},
	})

	var result: Dictionary = engine.call("dispatch_card", card, "old_li", {"game_state": gs})
	assert_true(not bool(result.get("success", true)), "dispatch_card fails when hub_mana is short")
	assert_eq(str(result.get("reason", "")), "hub_mana_short", "hub_mana_short reason returned")
	assert_eq(int(gs.hub_mana), 1, "failed dispatch does not spend hub_mana")
	assert_eq(int(gs.pollution), 0, "failed dispatch does not add pollution")
	assert_eq(int(gs.church_awareness), 0, "failed dispatch does not add church awareness")
	assert_eq(int(state.suspicion), 40, "failed dispatch does not mutate NPC suspicion")


func test_chant_button_surfaces_cost_effects_and_shortage_reason() -> void:
	var gs = _state()
	gs.hub_mana = 1
	gs.hub_mana_max = 10
	var card = CardScript.from_json({
		"id": "r20_ui_probe",
		"template_id": "r20_ui_probe",
		"display_name": "\u5f71\u4ee3\u4e4b\u8c0e",
		"energy_cost": 2,
		"combat_effect": {"damage": 12, "target": "single"},
		"social_effect": {"type": "identity_mask", "duration_days": 3, "suspicion_delta": -20},
		"world_effect": {"type": "create_residual_identity", "identity_id": "borrowed_face_old_li", "duration_days": 3, "allowed_locations": ["old_li"]},
	})
	gs.add_card(card)
	var active_deck: Array[String] = ["r20_ui_probe"]
	gs.active_deck = active_deck
	var parent := VBoxContainer.new()
	var buttons: Array = ChantButtonFactoryScript.add_chant_buttons(parent, gs, "old_li")
	assert_eq(buttons.size(), 1, "chant factory creates one active-deck R20 button")
	if buttons.size() > 0 and buttons[0] is Button:
		var button: Button = buttons[0]
		var tooltip := str(button.tooltip_text)
		assert_true(button.disabled, "chant button is disabled when hub_mana is short")
		assert_true(str(button.text).contains("\u5492\u5ff5") and str(button.text).contains("\u6d1e\u5e9c") and str(button.text).contains("2"), "chant button text surfaces the hub_mana cost")
		assert_true(tooltip.contains("\u793e\u4ea4") and tooltip.contains("\u4f2a\u88c5"), "chant tooltip summarizes the social effect")
		assert_true(tooltip.contains("\u4e16\u754c") and tooltip.contains("\u6b8b\u7559"), "chant tooltip summarizes the world effect")
		assert_true(tooltip.contains("\u6c61\u67d3") and tooltip.contains("\u6559\u4f1a"), "chant tooltip names pollution and church-awareness side effects")
		assert_true(tooltip.contains("\u6d1e\u5e9c") and tooltip.contains("\u4e0d\u8db3"), "disabled chant tooltip explains hub_mana shortage")
		assert_true(tooltip.find("identity_mask") < 0 and tooltip.find("create_residual_identity") < 0, "chant tooltip hides raw R20 effect ids")
	parent.queue_free()
	gs.queue_free()


func test_inventory_only_r20_cards_do_not_expose_npc_chant_buttons() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state_for_hub_path()
	GameState.hub_mana = 10
	var inventory_only_card = CardScript.from_json({
		"id": "shadow_jester",
		"template_id": "shadow_jester",
		"display_name": "影代之诡",
		"energy_cost": 2,
		"combat_effect": {"damage": 12, "target": "single"},
		"social_effect": {"type": "identity_mask", "duration_days": 3, "npc_perception": "dead_brother", "suspicion_delta": -20},
		"world_effect": {"type": "create_residual_identity", "identity_id": "borrowed_face_old_li", "duration_days": 3, "allowed_locations": ["old_li"]},
	})
	GameState.add_card(inventory_only_card)
	GameState.active_deck = []
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "shadow_alley", "morning")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var old_li_button = city.find_child("Hotspot_npc_old_li", true, false) if city != null else null
	assert_true(old_li_button is Button, "Hub path reaches Old Li hotspot for inventory-only chant test")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue opens for inventory-only chant test")
	assert_true(not _has_visible_button(dialog, "NpcServiceMenuButton_old_li"), "NPC dialogue does not expose a service menu for inventory-only chant test")
	var chant_button = dialog.find_child("R20ChantButton_shadow_jester", true, false) if dialog != null else null
	assert_true(not (chant_button is Button), "owned but unequipped R20 card does not expose a NPC chant button")
	hub.queue_free()
	GameState.from_dict(previous)


func test_hub_city_npc_dialogue_keeps_r20_chant_off_npc_surface() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state_for_hub_path()
	if not _has_property(GameState, "hub_mana"):
		assert_true(false, "GameState exposes hub_mana for Hub chant path")
		GameState.from_dict(previous)
		return
	GameState.hub_mana = 10
	var chant_card = CardScript.from_json({
		"id": "shadow_jester",
		"template_id": "shadow_jester",
		"display_name": "影代之诡",
		"energy_cost": 2,
		"combat_effect": {"damage": 12, "target": "single"},
		"social_effect": {"type": "identity_mask", "duration_days": 3, "npc_perception": "dead_brother", "suspicion_delta": -20},
		"world_effect": {"type": "create_residual_identity", "identity_id": "borrowed_face_old_li", "duration_days": 3, "allowed_locations": ["old_li"]},
	})
	GameState.add_card(chant_card)
	GameState.active_deck = ["shadow_jester"]
	var hub = await _hub()
	if hub == null:
		GameState.from_dict(previous)
		return
	hub.call("open_city_for_debug", "shadow_alley", "morning")
	await Engine.get_main_loop().process_frame
	var city = hub.get_node_or_null("CityScene")
	var old_li_button = city.find_child("Hotspot_npc_old_li", true, false) if city != null else null
	assert_true(old_li_button is Button, "Hub path reaches Old Li hotspot")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var dialog = hub.get_node_or_null("NpcDialogueDialog")
	assert_true(dialog != null and dialog.visible, "NPC dialogue dialog opens from Hub city path")
	assert_true(not _has_visible_button(dialog, "NpcServiceMenuButton_old_li"), "NPC dialogue does not expose service menu before R20 chant buttons")
	var chant_button = dialog.find_child("R20ChantButton_shadow_jester", true, false) if dialog != null else null
	assert_true(not (chant_button is Button), "NPC dialogue keeps R20 chant buttons off the ordinary NPC surface")
	var state = GameState.npc_relations.get("old_li", null)
	assert_true(state != null, "chant path keeps Old Li relation state")
	if state != null:
		assert_true(str(state.active_perception) != "dead_brother", "NPC dialogue surface does not apply identity_mask without the CityScene chant path")
	assert_eq(int(GameState.hub_mana), 10, "NPC dialogue surface does not spend hub_mana")
	hub.queue_free()
	GameState.from_dict(previous)


func test_city_scene_and_encounter_runner_expose_chant_buttons() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state_for_hub_path()
	GameState.hub_mana = 10
	var chant_card = CardScript.from_json({
		"id": "fool_s7_paper_doll_substitute",
		"template_id": "fool_s7_paper_doll_substitute",
		"display_name": "纸人替身",
		"energy_cost": 1,
		"combat_effect": {"damage": 0, "target": "self"},
		"social_effect": {"type": "identity_mask", "duration_days": 1, "npc_perception": "shadow_double", "suspicion_delta": -10},
		"world_effect": {"type": "create_residual_identity", "identity_id": "paper_doll_old_li", "duration_days": 1, "allowed_locations": ["old_li"]},
	})
	GameState.add_card(chant_card)
	GameState.active_deck = ["fool_s7_paper_doll_substitute"]
	var city = await _city_scene()
	if city == null:
		GameState.from_dict(previous)
		return
	city.open_district("shadow_alley", GameState)
	await Engine.get_main_loop().process_frame
	var old_li_button = city.find_child("Hotspot_npc_old_li", true, false)
	assert_true(old_li_button is Button, "CityScene exposes Old Li hotspot for chant UI integration")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var city_chant = city.find_child("R20ChantButton_fool_s7_paper_doll_substitute", true, false)
	assert_true(city_chant is Button, "CityScene NPC entry exposes reusable R20 chant button")
	city.queue_free()

	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	var encounter = EncounterScript.new().from_dict({
		"id": "enc_r20_chant_probe",
		"display_name": "R20 Chant Probe",
		"districts": ["shadow_alley"],
		"time_of_day": ["morning"],
		"scene_payload": {
			"text": "Old Li waits at the alley corner.",
			"target_npc_id": "old_li",
			"choices": [{"id": "leave", "label": "Leave", "outcome": {}}],
		},
	})
	runner.start(encounter, GameState)
	await Engine.get_main_loop().process_frame
	var encounter_chant = runner.find_child("R20ChantButton_fool_s7_paper_doll_substitute", true, false)
	assert_true(encounter_chant is Button, "EncounterRunner option row exposes reusable R20 chant button")
	runner.queue_free()
	GameState.from_dict(previous)


func test_encounter_r20_chant_displays_field_hook_feedback() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state_for_hub_path()
	GameState.hub_mana = 10
	var chant_card = CardScript.from_json({
		"id": "encounter_read_truth_probe",
		"template_id": "encounter_read_truth_probe",
		"display_name": "Encounter Read Truth",
		"energy_cost": 1,
		"combat_effect": {"damage": 0, "target": "self"},
		"social_effect": {"type": "read_truth"},
		"world_effect": {"type": "reveal_hidden_lore"},
	})
	GameState.add_card(chant_card)
	GameState.active_deck = ["encounter_read_truth_probe"]
	var runner = EncounterRunnerScript.new()
	Engine.get_main_loop().root.add_child(runner)
	await Engine.get_main_loop().process_frame
	var encounter = EncounterScript.new().from_dict({
		"id": "enc_r20_feedback_probe",
		"display_name": "R20 Feedback Probe",
		"districts": ["shadow_alley"],
		"time_of_day": ["morning"],
		"scene_payload": {
			"text": "Old Li waits at the alley corner.",
			"target_npc_id": "old_li",
			"choices": [{"id": "leave", "label": "Leave", "outcome": {}}],
		},
	})
	runner.start(encounter, GameState)
	await Engine.get_main_loop().process_frame
	var chant_button = runner.find_child("R20ChantButton_encounter_read_truth_probe", true, false)
	assert_true(chant_button is Button, "EncounterRunner exposes read_truth R20 chant button")
	if chant_button is Button:
		chant_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var feedback = runner.find_child("EncounterR20FeedbackLabel", true, false)
	assert_true(feedback is Label and feedback.visible, "EncounterRunner shows visible R20 field hook feedback")
	if feedback is Label:
		var feedback_text := str(feedback.text)
		assert_true(feedback_text.strip_edges() != "" and feedback_text != "R20 effect applied.", "EncounterRunner feedback includes specific field hook result text")
	runner.queue_free()
	GameState.from_dict(previous)


func test_city_scene_chant_displays_ai_gm_feedback() -> void:
	var previous: Dictionary = GameState.to_dict()
	_setup_global_state_for_hub_path()
	GameState.time_of_day = "night"
	GameState.hub_mana = 10
	var chant_card = CardScript.from_json({
		"id": "city_r20_ai_probe",
		"template_id": "city_r20_ai_probe",
		"display_name": "City R20 AI Probe",
		"energy_cost": 1,
		"combat_effect": {"damage": 0, "target": "self"},
		"social_effect": {"type": "modify_suspicion", "suspicion_delta": -5},
	})
	GameState.add_card(chant_card)
	GameState.active_deck = ["city_r20_ai_probe"]
	var city = await _city_scene()
	if city == null:
		GameState.from_dict(previous)
		return
	assert_true(city.has_method("set_ai_gm_service"), "CityScene can receive an injected AI GM service for chant feedback")
	var fake := FakeAIGMService.new()
	if city.has_method("set_ai_gm_service"):
		city.call("set_ai_gm_service", fake)
	city.open_district("shadow_alley", GameState)
	await Engine.get_main_loop().process_frame
	var old_li_button = city.find_child("Hotspot_npc_old_li", true, false)
	assert_true(old_li_button is Button, "CityScene exposes Old Li hotspot for visible AI GM chant feedback")
	if old_li_button is Button:
		old_li_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	var chant_button = city.find_child("R20ChantButton_city_r20_ai_probe", true, false)
	assert_true(chant_button is Button, "CityScene topbar exposes the test R20 chant button")
	if chant_button is Button:
		chant_button.pressed.emit()
		await Engine.get_main_loop().process_frame
	assert_eq(fake.calls.size(), 1, "CityScene chant uses the injected AI GM service once")
	var dialog = city.find_child("CityR20FeedbackDialog", true, false)
	assert_true(dialog != null and dialog.visible, "CityScene chant opens visible feedback instead of only updating state")
	if dialog != null:
		assert_true(str(dialog.dialog_text).contains("city r20 ai gm visible text"), "CityScene chant feedback displays AI GM narration")
		assert_true(str(dialog.dialog_text).contains("\u6000\u7591") and str(dialog.dialog_text).contains("\u6c61\u67d3"), "CityScene chant feedback also displays structured R20 side effects")
	city.queue_free()
	GameState.from_dict(previous)


func _setup_global_state_for_hub_path() -> void:
	GameState.reset()
	GameState.day = 5
	GameState.time_of_day = "morning"
	GameState.ap = 12
	GameState.sequence = 8
	GameState.current_district = "shadow_alley"


func _hub() -> Control:
	var scene = load(HUB_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "hub scene loads")
		return null
	var hub = scene.instantiate()
	Engine.get_main_loop().root.add_child(hub)
	await Engine.get_main_loop().process_frame
	return hub


func _city_scene() -> Control:
	var scene = load(CITY_SCENE)
	if scene == null or not scene.can_instantiate():
		assert_true(false, "city scene loads")
		return null
	var city = scene.instantiate()
	Engine.get_main_loop().root.add_child(city)
	await Engine.get_main_loop().process_frame
	return city


func _press_dialog_button(dialog, button_name: String) -> bool:
	if dialog == null:
		return false
	var button = dialog.find_child(button_name, true, false)
	if button is Button:
		button.pressed.emit()
		return true
	return false


func _has_visible_button(dialog, button_name: String) -> bool:
	if dialog == null:
		return false
	var button = dialog.find_child(button_name, true, false)
	return button is Button and button.visible


func _new_script_instance(path: String, label: String):
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s script loads and can instantiate" % label)
		return null
	var instance = script.new()
	assert_true(instance != null, "%s instance creates" % label)
	return instance


func _state():
	var gs = GameStateScript.new()
	gs._ready()
	return gs


func _has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false
	for entry in obj.get_property_list():
		if str(entry.get("name", "")) == property_name:
			return true
	return false


func _fool_skill_file_names() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://data/skills")
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if not dir.current_is_dir() and name.begins_with("fool_") and name.ends_with(".json"):
			result.append(name)
	dir.list_dir_end()
	result.sort()
	return result


func _json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


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
