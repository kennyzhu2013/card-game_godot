class_name AIGMProvider
extends RefCounted

const CLAUDE_HAIKU := "claude_haiku"
const CLAUDE_SONNET := "claude_sonnet"
const DEEPSEEK := "deepseek"
const GEMINI := "gemini"
const QWEN := "qwen"

var id: String = CLAUDE_HAIKU
var provider_name: String = "Anthropic"
var model: String = "claude-haiku"
var tier: String = "haiku"
var estimated_cost: float = 0.00002


static func provider(provider_id: String):
	var p = new()
	p.id = provider_id
	match provider_id:
		CLAUDE_SONNET:
			p.provider_name = "Anthropic"
			p.model = "claude-sonnet"
			p.tier = "sonnet"
			p.estimated_cost = 0.001
		DEEPSEEK:
			p.provider_name = "DeepSeek"
			p.model = "deepseek-chat"
			p.tier = "haiku"
			p.estimated_cost = 0.00002
		GEMINI:
			p.provider_name = "Google"
			p.model = "gemini-flash"
			p.tier = "haiku"
			p.estimated_cost = 0.00002
		QWEN:
			p.provider_name = "Alibaba"
			p.model = "qwen-plus"
			p.tier = "haiku"
			p.estimated_cost = 0.00002
		_:
			p.id = CLAUDE_HAIKU
			p.provider_name = "Anthropic"
			p.model = "claude-haiku"
			p.tier = "haiku"
			p.estimated_cost = 0.00002
	return p


static func default_chain() -> Array:
	return [
		provider(CLAUDE_HAIKU),
		provider(DEEPSEEK),
		provider(GEMINI),
		provider(QWEN),
	]


func is_sonnet() -> bool:
	return tier == "sonnet" or id == CLAUDE_SONNET
