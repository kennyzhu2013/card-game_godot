extends RefCounted

const AtbBattleScript = preload("res://scripts/combat/atb_battle.gd")
const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")
const EnemyScript = preload("res://scripts/combat/enemy.gd")
const ElementTableScript = preload("res://scripts/combat/element_table.gd")
const ForgeResultCalculatorScript = preload("res://scripts/ritual/forge_result_calculator.gd")
const GameStateScript = preload("res://scripts/state/game_state.gd")
const GlyphArrangementScript = preload("res://scripts/ritual/glyph_arrangement.gd")
const SkillLibraryScript = preload("res://scripts/combat/skill_library.gd")
const SkillScript = preload("res://scripts/combat/skill.gd")
const SymbolInstanceScript = preload("res://scripts/ritual/symbol_instance.gd")

var _passed := 0
var _failed := 0


class FakeQteBar:
	extends RefCounted

	var running := true

	func resolve() -> Dictionary:
		running = false
		return {"mult": 1.0, "grade": "Perfect"}


func run() -> Dictionary:
	print("\n-- test_symbol_use_tracking.gd --")
	test_skill_to_dict_roundtrips_source_symbol_ids()
	test_forge_populates_source_symbol_ids_from_arrangement()
	test_forge_increments_each_symbol_use_count()
	test_battle_skill_use_increments_battles_witnessed()
	test_5_uses_triggers_cultivation_level_up()
	return {"passed": _passed, "failed": _failed}


func test_skill_to_dict_roundtrips_source_symbol_ids() -> void:
	var skill = SkillScript.new()
	if not _object_has_property(skill, "source_symbol_ids"):
		assert_true(false, "Skill exposes source_symbol_ids")
		return
	skill.id = "shadow_arrow"
	skill.source_symbol_ids = _string_array(["shadow", "arrow"])
	var copy = SkillScript.from_json(skill.to_dict())
	assert_eq(Array(copy.source_symbol_ids), ["shadow", "arrow"], "roundtrip source_symbol_ids")


func test_forge_populates_source_symbol_ids_from_arrangement() -> void:
	var result := _forge("shadow_arrow", 0.95, _arrangement(["shadow", "arrow", ""]), _library())
	var forged = result.get("forged_skill", null)
	assert_true(forged != null, "forge returns forged skill")
	if forged == null:
		return
	if not _object_has_property(forged, "source_symbol_ids"):
		assert_true(false, "forged skill exposes source_symbol_ids")
		return
	assert_eq(Array(forged.source_symbol_ids), ["shadow", "arrow"], "forge stores source symbol ids")


func test_forge_increments_each_symbol_use_count() -> void:
	if not _forge_accepts_game_state():
		assert_true(false, "ForgeResultCalculator.forge accepts game_state")
		return
	var state := _state_with_symbols(["shadow", "arrow"])
	_forge_with_state("shadow_arrow", 0.95, _arrangement(["shadow", "arrow", ""]), _library(), state)
	var shadow = state.get_symbol_instance("shadow")
	var arrow = state.get_symbol_instance("arrow")
	assert_eq(shadow.use_count, 1, "forge increments shadow use_count")
	assert_eq(arrow.use_count, 1, "forge increments arrow use_count")
	assert_eq(shadow.battles_witnessed, 0, "forge does not increment shadow battles_witnessed")
	assert_eq(arrow.battles_witnessed, 0, "forge does not increment arrow battles_witnessed")


func test_battle_skill_use_increments_battles_witnessed() -> void:
	var state := _state_with_symbols(["shadow", "arrow"])
	var skill = _library().get_skill("shadow_arrow")
	assert_true(skill != null, "shadow_arrow exists")
	if skill == null:
		return
	if not _object_has_property(skill, "source_symbol_ids"):
		assert_true(false, "Skill exposes source_symbol_ids for battle use")
		return
	var battle = _battle_with_qte()
	if not _object_has_property(battle, "_game_state"):
		assert_true(false, "AtbBattle exposes _game_state")
		return
	battle._game_state = state
	skill.source_symbol_ids = _string_array(["shadow", "arrow"])
	battle._selected_skill = skill
	battle._resolve_player_qte()
	var shadow = state.get_symbol_instance("shadow")
	var arrow = state.get_symbol_instance("arrow")
	assert_eq(shadow.use_count, 1, "battle use increments shadow use_count")
	assert_eq(arrow.use_count, 1, "battle use increments arrow use_count")
	assert_eq(shadow.battles_witnessed, 1, "battle use increments shadow battles_witnessed")
	assert_eq(arrow.battles_witnessed, 1, "battle use increments arrow battles_witnessed")


func test_5_uses_triggers_cultivation_level_up() -> void:
	if not _forge_accepts_game_state():
		assert_true(false, "ForgeResultCalculator.forge accepts game_state for repeated forge")
		return
	var state := _state_with_symbols(["shadow", "arrow"])
	var arrangement := _arrangement(["shadow", "arrow", ""])
	var library = _library()
	for i in range(5):
		_forge_with_state("shadow_arrow", 0.95, arrangement, library, state)
	var shadow = state.get_symbol_instance("shadow")
	var arrow = state.get_symbol_instance("arrow")
	assert_eq(shadow.use_count, 5, "five forge uses count on shadow")
	assert_eq(arrow.use_count, 5, "five forge uses count on arrow")
	assert_eq(shadow.cultivation_level, 1, "five uses level up shadow")
	assert_eq(arrow.cultivation_level, 1, "five uses level up arrow")


func _arrangement(symbol_ids: Array) -> GlyphArrangement:
	var arrangement = GlyphArrangementScript.new(3, GlyphArrangementScript.SHAPE_LINE)
	for i in range(symbol_ids.size()):
		arrangement.place(i, String(symbol_ids[i]))
	return arrangement


func _battle_with_qte():
	var battle = AtbBattleScript.new()
	battle.player = CombatActorScript.new()
	battle.player.crit_rate = 0.0
	battle.enemy = EnemyScript.new()
	battle.enemy.hp = 100
	battle.enemy.max_hp = 100
	battle.enemy.def = 0
	battle._element_table = ElementTableScript.new()
	battle._element_table.load_table()
	battle._qte_bar = FakeQteBar.new()
	return battle


func _forge(reaction_id: String, perfect_rate: float, arrangement, library) -> Dictionary:
	return ForgeResultCalculatorScript.forge(reaction_id, perfect_rate, arrangement, library)


func _forge_with_state(reaction_id: String, perfect_rate: float, arrangement, library, state) -> Dictionary:
	return Callable(ForgeResultCalculatorScript, "forge").call(reaction_id, perfect_rate, arrangement, library, state)


func _forge_accepts_game_state() -> bool:
	var calculator = ForgeResultCalculatorScript.new()
	for method in calculator.get_method_list():
		if method.get("name", "") == "forge":
			return method.get("args", []).size() >= 5
	return false


func _library():
	var library = SkillLibraryScript.new()
	library._load_all()
	return library


func _state_with_symbols(symbol_ids: Array) -> Node:
	var state = GameStateScript.new()
	state._ready()
	for id in symbol_ids:
		var inst = SymbolInstanceScript.new()
		inst.template_id = String(id)
		inst.display_name = String(id)
		inst.pathway = "fool"
		state.register_symbol_instance(inst)
	return state


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	result.assign(values)
	return result


func _object_has_property(obj, property_name: String) -> bool:
	for info in obj.get_property_list():
		if info.get("name", "") == property_name:
			return true
	return false


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
