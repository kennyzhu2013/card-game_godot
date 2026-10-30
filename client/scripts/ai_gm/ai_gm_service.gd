class_name AIGMService
extends RefCounted

const ProviderScript = preload("res://scripts/ai_gm/ai_gm_provider.gd")
const NetworkScript = preload("res://scripts/ai_gm/ai_gm_network.gd")
const CacheScript = preload("res://scripts/ai_gm/ai_gm_cache.gd")
const BudgetScript = preload("res://scripts/ai_gm/ai_gm_budget.gd")
const TemplatePoolsScript = preload("res://scripts/ai_gm/template_pools.gd")
const TemplateFillScript = preload("res://scripts/ai_gm/template_fill.gd")

const DEFAULT_SYSTEM_PROMPT_PATH := "res://data/ai_gm/system_prompt.md"

var cache = CacheScript.new()
var network = NetworkScript.new()
var budget = BudgetScript.new()
var template_pools = TemplatePoolsScript.new()
var fallback_renderer = null
var provider_chain: Array = ProviderScript.default_chain()
var system_prompt: String = ""
var api_key: String = ""
var last_result: Dictionary = {}


func _init() -> void:
	load_system_prompt(DEFAULT_SYSTEM_PROMPT_PATH)


func load_system_prompt(path: String = DEFAULT_SYSTEM_PROMPT_PATH) -> String:
	if not FileAccess.file_exists(path):
		system_prompt = ""
		return ""
	system_prompt = FileAccess.get_file_as_string(path)
	return system_prompt


func call_ai_gm(ctx) -> String:
	last_result = {"source": "", "provider": "", "error": ""}
	if ctx == null:
		last_result = {"source": "fallback", "provider": "", "error": "missing_context"}
		return _fallback_text(ctx)

	var cached := cache.get_text(ctx)
	if cached != "":
		last_result = {"source": "cache", "provider": "", "error": ""}
		return cached

	if network == null or not network.is_online():
		last_result = {"source": "fallback", "provider": "", "error": "offline"}
		return _fallback_text(ctx)

	var haiku = ProviderScript.provider(ProviderScript.CLAUDE_HAIKU)
	for provider in provider_chain:
		var chosen = budget.provider_for_budget(provider, haiku)
		if chosen == null:
			continue
		if not budget.can_call(chosen):
			last_result = {"source": "fallback", "provider": chosen.id, "error": "budget_exceeded"}
			return _fallback_text(ctx)
		var result: Dictionary = network.request(ctx, chosen, system_prompt, api_key)
		budget.record_call(chosen)
		if bool(result.get("success", false)):
			var text := str(result.get("text", ""))
			if cache.is_cacheable(ctx):
				cache.set_text(ctx, text)
			last_result = {"source": "network", "provider": chosen.id, "error": ""}
			return text
		last_result = {"source": "network", "provider": chosen.id, "error": str(result.get("error", ""))}

	last_result["source"] = "fallback"
	return _fallback_text(ctx)


func _fallback_text(ctx) -> String:
	if fallback_renderer != null and fallback_renderer.has_method("render"):
		return str(fallback_renderer.render(ctx))
	if ctx == null:
		return ""
	if template_pools != null and template_pools.has_method("template_for_context"):
		var template := str(template_pools.template_for_context(ctx))
		if template != "":
			return TemplateFillScript.render(template, ctx)
	return "fallback:%s:%s" % [str(ctx.scene), str(ctx.fallback_template_pool)]
