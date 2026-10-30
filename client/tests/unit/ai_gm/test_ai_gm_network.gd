extends RefCounted

const NetworkScript = preload("res://scripts/ai_gm/ai_gm_network.gd")
const ProviderScript = preload("res://scripts/ai_gm/ai_gm_provider.gd")
const PromptContextScript = preload("res://scripts/ai_gm/prompt_context.gd")
const MockClientScript = preload("res://tests/unit/ai_gm/helpers/mock_http_client.gd")

var _passed := 0
var _failed := 0


func run() -> Dictionary:
	print("\n-- test_ai_gm_network.gd --")
	test_offline_returns_offline_error()
	test_online_without_api_key_returns_missing_api_key()
	test_online_without_provider_returns_missing_provider()
	test_online_without_context_returns_missing_context()
	test_non_anthropic_provider_returns_provider_not_implemented()
	test_anthropic_success_returns_text_and_usage()
	test_anthropic_5xx_retries_and_eventually_succeeds()
	test_anthropic_4xx_does_not_retry()
	test_request_includes_api_key_and_anthropic_version_headers()
	test_payload_includes_system_prompt_and_serialized_context()
	return {"passed": _passed, "failed": _failed}


# --- offline / guard paths ---

func test_offline_returns_offline_error() -> void:
	var net = NetworkScript.new()
	# default force_offline=true
	var ctx = _ctx()
	var provider = ProviderScript.provider(ProviderScript.CLAUDE_HAIKU)
	var result: Dictionary = net.request(ctx, provider, "system", "key")
	assert_false(bool(result.get("success", false)), "offline → success=false")
	assert_eq(str(result.get("error", "")), "offline", "offline → error=offline")


func test_online_without_api_key_returns_missing_api_key() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	var ctx = _ctx()
	var provider = ProviderScript.provider(ProviderScript.CLAUDE_HAIKU)
	var result: Dictionary = net.request(ctx, provider, "system", "")
	assert_false(bool(result.get("success", false)), "no key → success=false")
	assert_eq(str(result.get("error", "")), "missing_api_key", "no key → error=missing_api_key")


func test_online_without_provider_returns_missing_provider() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	var ctx = _ctx()
	var result: Dictionary = net.request(ctx, null, "system", "key")
	assert_eq(str(result.get("error", "")), "missing_provider", "no provider → error=missing_provider")


func test_online_without_context_returns_missing_context() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	var provider = ProviderScript.provider(ProviderScript.CLAUDE_HAIKU)
	var result: Dictionary = net.request(null, provider, "system", "key")
	assert_eq(str(result.get("error", "")), "missing_context", "no ctx → error=missing_context")


func test_non_anthropic_provider_returns_provider_not_implemented() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	var ctx = _ctx()
	var provider = ProviderScript.provider(ProviderScript.DEEPSEEK)
	var result: Dictionary = net.request(ctx, provider, "system", "key")
	assert_false(bool(result.get("success", false)), "non-anthropic → success=false")
	var error_text := str(result.get("error", ""))
	assert_true(error_text.begins_with("provider_not_implemented"), "non-anthropic → provider_not_implemented (got %s)" % error_text)


# --- anthropic transport paths via mock client ---

func test_anthropic_success_returns_text_and_usage() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	net.timeout_sec = 1.0
	var mock_log: Array = []
	var success_body := JSON.stringify({
		"content": [{"type": "text", "text": "hello world"}],
		"usage": {"input_tokens": 10, "output_tokens": 4},
	})
	net._client_factory = func():
		var client = MockClientScript.new()
		client.scripted_status_code = 200
		client.scripted_body = success_body
		client.shared_log = mock_log
		return client
	var ctx = _ctx()
	var provider = ProviderScript.provider(ProviderScript.CLAUDE_HAIKU)
	var result: Dictionary = net.request(ctx, provider, "you are a GM", "test-key")
	assert_true(bool(result.get("success", false)), "anthropic 200 → success=true")
	assert_eq(str(result.get("text", "")), "hello world", "anthropic 200 → text extracted")
	assert_eq(int(result.get("status_code", 0)), 200, "anthropic 200 → status_code=200")
	assert_true(result.has("latency_ms"), "anthropic 200 → latency_ms recorded")
	assert_true(result.get("usage", {}) is Dictionary, "anthropic 200 → usage dict present")


func test_anthropic_5xx_retries_and_eventually_succeeds() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	net.timeout_sec = 1.0
	net.retry_count = 2
	var attempt_counter := [0]
	var success_body := JSON.stringify({
		"content": [{"type": "text", "text": "after retry"}],
	})
	net._client_factory = func():
		var client = MockClientScript.new()
		# 第一次给 503，之后给 200
		if attempt_counter[0] == 0:
			client.scripted_status_code = 503
			client.scripted_body = "service unavailable"
		else:
			client.scripted_status_code = 200
			client.scripted_body = success_body
		attempt_counter[0] += 1
		return client
	var result: Dictionary = net.request(_ctx(), ProviderScript.provider(ProviderScript.CLAUDE_HAIKU), "sys", "key")
	assert_true(bool(result.get("success", false)), "5xx then 200 → success=true")
	assert_eq(str(result.get("text", "")), "after retry", "5xx then 200 → text from second attempt")
	assert_eq(attempt_counter[0], 2, "5xx then 200 → exactly 2 attempts")


func test_anthropic_4xx_does_not_retry() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	net.timeout_sec = 1.0
	net.retry_count = 3
	var attempt_counter := [0]
	net._client_factory = func():
		attempt_counter[0] += 1
		var client = MockClientScript.new()
		client.scripted_status_code = 401
		client.scripted_body = "unauthorized"
		return client
	var result: Dictionary = net.request(_ctx(), ProviderScript.provider(ProviderScript.CLAUDE_HAIKU), "sys", "bad-key")
	assert_false(bool(result.get("success", false)), "4xx → success=false")
	assert_eq(int(result.get("status_code", 0)), 401, "4xx → status_code=401")
	assert_eq(attempt_counter[0], 1, "4xx → exactly 1 attempt (no retry)")


func test_request_includes_api_key_and_anthropic_version_headers() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	net.timeout_sec = 1.0
	var captured := {"client": null}
	net._client_factory = func():
		var client = MockClientScript.new()
		client.scripted_status_code = 200
		client.scripted_body = JSON.stringify({"content": [{"type": "text", "text": "ok"}]})
		captured["client"] = client
		return client
	net.request(_ctx(), ProviderScript.provider(ProviderScript.CLAUDE_HAIKU), "sys", "secret-key-123")
	var client = captured["client"]
	assert_true(client != null, "captured mock client")
	if client == null:
		return
	var headers: Array = []
	for h in client.last_headers:
		headers.append(str(h))
	assert_true(_headers_have(headers, "x-api-key: secret-key-123"), "x-api-key header present")
	assert_true(_headers_have(headers, "anthropic-version: 2023-06-01"), "anthropic-version header present")
	assert_true(_headers_have_prefix(headers, "Content-Type:"), "Content-Type header present")


func test_payload_includes_system_prompt_and_serialized_context() -> void:
	var net = NetworkScript.new()
	net.force_offline = false
	net.timeout_sec = 1.0
	var captured := {"client": null}
	net._client_factory = func():
		var client = MockClientScript.new()
		client.scripted_status_code = 200
		client.scripted_body = JSON.stringify({"content": [{"type": "text", "text": "ok"}]})
		captured["client"] = client
		return client
	var ctx = _ctx()
	ctx.scene_payload = {"primary_glyph": "影"}
	net.request(ctx, ProviderScript.provider(ProviderScript.CLAUDE_SONNET), "system role text", "key")
	var client = captured["client"]
	assert_true(client != null, "captured mock client")
	if client == null:
		return
	var body = JSON.parse_string(client.last_body)
	assert_true(body is Dictionary, "request body is JSON dict")
	if not body is Dictionary:
		return
	var body_dict: Dictionary = body
	assert_eq(str(body_dict.get("system", "")), "system role text", "system prompt forwarded")
	assert_eq(str(body_dict.get("model", "")), "claude-sonnet", "provider model forwarded")
	var messages_value: Variant = body_dict.get("messages", [])
	assert_true(messages_value is Array and (messages_value as Array).size() == 1, "messages has one entry")
	if messages_value is Array and (messages_value as Array).size() == 1:
		var first: Dictionary = (messages_value as Array)[0]
		assert_eq(str(first.get("role", "")), "user", "user role")
		var content_text := str(first.get("content", ""))
		assert_true(content_text.find("primary_glyph") >= 0, "ctx scene_payload serialized into user content")
		assert_true(content_text.find("forge_resolve") >= 0, "ctx.scene serialized into user content")


# --- helpers ---

func _ctx():
	var ctx = PromptContextScript.new()
	ctx.scene = "forge_resolve"
	ctx.fallback_template_pool = "FORGE_RESULT_TEMPLATES"
	return ctx


func _headers_have(headers: Array, expected: String) -> bool:
	for h in headers:
		if str(h) == expected:
			return true
	return false


func _headers_have_prefix(headers: Array, prefix: String) -> bool:
	for h in headers:
		if str(h).begins_with(prefix):
			return true
	return false


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s" % message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		_passed += 1
		print("  PASS: %s" % message)
	else:
		_failed += 1
		print("  FAIL: %s - expected '%s', got '%s'" % [message, str(expected), str(actual)])
