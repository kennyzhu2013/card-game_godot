extends RefCounted

const SERVICE_PATH := "res://scripts/ai_gm/ai_gm_service.gd"
const NETWORK_PATH := "res://scripts/ai_gm/ai_gm_network.gd"
const CACHE_PATH := "res://scripts/ai_gm/ai_gm_cache.gd"
const BUDGET_PATH := "res://scripts/ai_gm/ai_gm_budget.gd"
const PROVIDER_PATH := "res://scripts/ai_gm/ai_gm_provider.gd"
const PROMPT_CONTEXT_PATH := "res://scripts/ai_gm/prompt_context.gd"

const CACHE_TEST_PATH := "user://slice4_t1_ai_gm_cache_test.json"
const CACHE_HASH_TEST_PATH := "user://slice4_t1_ai_gm_cache_hash_test.json"

var _passed := 0
var _failed := 0


class FakeNetwork:
	extends RefCounted

	var online := true
	var responses: Array = []
	var calls: Array = []

	func is_online() -> bool:
		return online

	func request(ctx, provider, _system_prompt: String = "", _api_key: String = "") -> Dictionary:
		calls.append({"scene": ctx.scene, "provider": provider.id})
		if responses.is_empty():
			return {"success": false, "error": "no fake response"}
		return responses.pop_front()


class FakeFallback:
	extends RefCounted

	var calls: Array = []

	func render(ctx) -> String:
		calls.append(ctx.scene)
		return "fallback:%s:%s" % [ctx.scene, ctx.fallback_template_pool]


func run() -> Dictionary:
	print("\n-- test_ai_gm_service.gd --")
	test_t1_scripts_exist_and_load()
	test_service_returns_cache_hit_before_network()
	test_service_falls_back_when_network_offline()
	test_service_tries_next_provider_after_failure()
	test_budget_downgrades_sonnet_after_daily_cap()
	test_service_downgrades_sonnet_and_still_calls_network_after_daily_cap()
	test_cache_persists_only_cacheable_scenes()
	test_cache_keys_hash_payload_identifiers()
	return {"passed": _passed, "failed": _failed}


func test_t1_scripts_exist_and_load() -> void:
	for path in [SERVICE_PATH, NETWORK_PATH, CACHE_PATH, BUDGET_PATH, PROVIDER_PATH]:
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var script = load(path)
		assert_true(script != null and script.can_instantiate(), "%s loads" % path)


func test_service_returns_cache_hit_before_network() -> void:
	var service_script = _load_required(SERVICE_PATH)
	var cache_script = _load_required(CACHE_PATH)
	var ctx = _unknown_reaction_context()
	if service_script == null or cache_script == null or ctx == null:
		return

	var cache = cache_script.new()
	cache.path = CACHE_TEST_PATH
	cache.set_text(ctx, "cached unknown reaction")

	var fake_network := FakeNetwork.new()
	fake_network.responses = [{"success": true, "text": "network should not be used"}]
	var service = service_script.new()
	service.cache = cache
	service.network = fake_network
	service.fallback_renderer = FakeFallback.new()

	var text: String = service.call_ai_gm(ctx)

	assert_eq(text, "cached unknown reaction", "service returns cached text")
	assert_eq(fake_network.calls.size(), 0, "cache hit bypasses network")


func test_service_falls_back_when_network_offline() -> void:
	var service_script = _load_required(SERVICE_PATH)
	var ctx = _context("tower_floor_transition", "TOWER_TRANSITION_TEMPLATES")
	if service_script == null or ctx == null:
		return

	var fake_network := FakeNetwork.new()
	fake_network.online = false
	var fallback := FakeFallback.new()
	var service = service_script.new()
	service.network = fake_network
	service.fallback_renderer = fallback

	var text: String = service.call_ai_gm(ctx)

	assert_eq(text, "fallback:tower_floor_transition:TOWER_TRANSITION_TEMPLATES", "offline service uses fallback renderer")
	assert_eq(fake_network.calls.size(), 0, "offline service does not call network")
	assert_eq(fallback.calls.size(), 1, "fallback called once")


func test_service_tries_next_provider_after_failure() -> void:
	var service_script = _load_required(SERVICE_PATH)
	var provider_script = _load_required(PROVIDER_PATH)
	var ctx = _context("combat_resolve_critical", "COMBAT_RESOLVE_TEMPLATES")
	if service_script == null or provider_script == null or ctx == null:
		return

	var fake_network := FakeNetwork.new()
	fake_network.responses = [
		{"success": false, "error": "first provider failed"},
		{"success": true, "text": "second provider text"},
	]
	var service = service_script.new()
	service.network = fake_network
	service.provider_chain = [
		provider_script.provider("claude_haiku"),
		provider_script.provider("deepseek"),
	]
	service.fallback_renderer = FakeFallback.new()

	var text: String = service.call_ai_gm(ctx)

	assert_eq(text, "second provider text", "service returns next provider success")
	assert_eq(fake_network.calls.size(), 2, "service tries failing provider then next provider")
	assert_eq(fake_network.calls[0].get("provider", ""), "claude_haiku", "first provider is haiku")
	assert_eq(fake_network.calls[1].get("provider", ""), "deepseek", "second provider is deepseek")


func test_budget_downgrades_sonnet_after_daily_cap() -> void:
	var budget_script = _load_required(BUDGET_PATH)
	var provider_script = _load_required(PROVIDER_PATH)
	if budget_script == null or provider_script == null:
		return

	var budget = budget_script.new()
	budget.daily_call_cap = 1
	budget.calls_today = 1
	var sonnet = provider_script.provider("claude_sonnet")
	var chosen = budget.provider_for_budget(sonnet, provider_script.provider("claude_haiku"))

	assert_eq(chosen.id, "claude_haiku", "budget downgrades Sonnet to Haiku after daily cap")


func test_service_downgrades_sonnet_and_still_calls_network_after_daily_cap() -> void:
	var service_script = _load_required(SERVICE_PATH)
	var budget_script = _load_required(BUDGET_PATH)
	var provider_script = _load_required(PROVIDER_PATH)
	var ctx = _context("combat_resolve_critical", "COMBAT_RESOLVE_TEMPLATES")
	if service_script == null or budget_script == null or provider_script == null or ctx == null:
		return

	var budget = budget_script.new()
	budget.daily_call_cap = 1
	budget.calls_today = 1
	var fake_network := FakeNetwork.new()
	fake_network.responses = [{"success": true, "text": "haiku after sonnet cap"}]
	var service = service_script.new()
	service.budget = budget
	service.network = fake_network
	service.provider_chain = [provider_script.provider("claude_sonnet")]
	service.fallback_renderer = FakeFallback.new()

	var text: String = service.call_ai_gm(ctx)

	assert_eq(text, "haiku after sonnet cap", "service still calls network after Sonnet downgrades to Haiku")
	assert_eq(fake_network.calls.size(), 1, "downgraded provider path calls network once")
	assert_eq(fake_network.calls[0].get("provider", ""), "claude_haiku", "service sends downgraded Haiku provider")
	assert_eq(service.last_result.get("source", ""), "network", "downgraded service result records network source")


func test_cache_persists_only_cacheable_scenes() -> void:
	var cache_script = _load_required(CACHE_PATH)
	var cacheable_ctx = _unknown_reaction_context()
	var non_cacheable_ctx = _context("tower_floor_transition", "TOWER_TRANSITION_TEMPLATES")
	if cache_script == null or cacheable_ctx == null or non_cacheable_ctx == null:
		return

	var cache = cache_script.new()
	cache.path = CACHE_TEST_PATH
	cache.set_text(cacheable_ctx, "persist me")
	cache.set_text(non_cacheable_ctx, "do not persist me")

	var loaded = cache_script.new()
	loaded.path = CACHE_TEST_PATH
	loaded.load_cache()

	assert_eq(loaded.get_text(cacheable_ctx), "persist me", "unknown_reaction cache persists")
	assert_eq(loaded.get_text(non_cacheable_ctx), "", "non-cacheable scene is not persisted")


func test_cache_keys_hash_payload_identifiers() -> void:
	var cache_script = _load_required(CACHE_PATH)
	var unknown_ctx = _unknown_reaction_context()
	var brand_ctx = _context("brand_naming", "BRAND_NAMING_TEMPLATES")
	if cache_script == null or unknown_ctx == null or brand_ctx == null:
		return
	brand_ctx.scene_payload = {
		"brand_id_a": "brand_shadow",
		"brand_id_b": "brand_radiance",
		"card_template_id": "card_template_alpha",
	}

	var cache = cache_script.new()
	cache.path = CACHE_HASH_TEST_PATH
	var unknown_key: String = cache.cache_key(unknown_ctx)
	var brand_key: String = cache.cache_key(brand_ctx)

	assert_true(unknown_key.begins_with("unknown_reaction:"), "unknown_reaction key keeps scene namespace")
	assert_true(unknown_key.find("shadow") == -1, "unknown_reaction key omits raw glyph id")
	assert_true(unknown_key.find("radiance") == -1, "unknown_reaction key omits raw glyph id 2")
	assert_true(brand_key.begins_with("brand_naming:"), "brand_naming key keeps scene namespace")
	assert_true(brand_key.find("brand_shadow") == -1, "brand_naming key omits raw brand a")
	assert_true(brand_key.find("brand_radiance") == -1, "brand_naming key omits raw brand b")
	assert_true(brand_key.find("card_template_alpha") == -1, "brand_naming key omits raw card template")

	cache.set_text(unknown_ctx, "unknown text")
	cache.set_text(brand_ctx, "brand text")
	var file_text := FileAccess.get_file_as_string(CACHE_HASH_TEST_PATH)
	for raw in ["shadow", "radiance", "brand_shadow", "brand_radiance", "card_template_alpha"]:
		assert_true(file_text.find(raw) == -1, "cache file omits raw payload '%s'" % raw)


func _unknown_reaction_context():
	var ctx = _context("unknown_reaction", "UNKNOWN_REACTION_TEMPLATES")
	if ctx == null:
		return null
	ctx.scene_payload = {"glyph_arrangement": ["shadow", "radiance"], "base_damage": 7}
	return ctx


func _context(scene: String, pool: String):
	var context_script = _load_required(PROMPT_CONTEXT_PATH)
	if context_script == null:
		return null
	var ctx = context_script.new()
	if not _has_property(ctx, "fallback_template_pool"):
		assert_true(false, "PromptContext exposes fallback_template_pool")
		return null
	ctx.scene = scene
	ctx.player_state = {"sequence": 9, "pollution": 10, "day": 1}
	ctx.scene_payload = {"probe": scene}
	ctx.set("fallback_template_pool", pool)
	return ctx


func _has_property(obj, prop_name: String) -> bool:
	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == prop_name:
			return true
	return false


func _load_required(path: String):
	if not ResourceLoader.exists(path):
		assert_true(false, "%s exists" % path)
		return null
	var script = load(path)
	if script == null or not script.can_instantiate():
		assert_true(false, "%s loads" % path)
		return null
	return script


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
